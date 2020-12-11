
=head1 B<http_server_aog>

=head2 SYNOPSIS

HTTP support for the Actions on Google Smart Home provider. Called via the
web server. Examples:

  http://localhost:8080/oauth

=head2 DESCRIPTION

Generate json for mh objects, groups, categories, and variables

TODO

  add request types for speak, print, and error logs
  add the truncate option to packages, vars, and other requests
  add more info to subs request

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use Config;
use MIME::Base64;
use JSON qw(decode_json);
use Storable;
use constant RANDBITS => $Config{randbits};
use constant RAND_MAX => 2**RANDBITS;

# Cache of OAuth authentication tokens. Persistent tokens are stored
# in $::config_parms{'aog_oauth_tokens_file'} and read on startup.
my $oauth_tokens;

sub http_server_aog_startup {
    if ( !$::config_parms{'aog_enable'}) {
	&main::print_log("[AoGSmartHome] AoG is disabled.");
	return;
    } else {
	&main::print_log("\n[AoGSmartHome] AoG is enabled; will look for AoG requests via HTTP.");
    }

    # We don't want defaults for these important parameters so we disable
    # AoG integration if one or more are missing.
    if (   !defined $::config_parms{'aog_auth_path'}
	|| !defined $::config_parms{'aog_fulfillment_url'}
	|| !defined $::config_parms{'aog_client_id'}
	|| !defined $::config_parms{'aog_project_id'} )
    {
        print STDERR "[AoGSmartHome] AoG is enabled but one or more .ini file parameters are missing; disabling AoG!\n";
        print STDERR "[AoGSmartHome] Required .ini file parameters: aog_auth_path aog_fulfillment_url aog_client_id aog_project_id\n";
        $::config_parms{'aog_enable'} = 0;
        return;
    }

    $::config_parms{'aog_oauth_tokens_file'} = "$config_parms{data_dir}/.aog_tokens"
      if !defined $::config_parms{'aog_oauth_tokens_file'};

    if ( -e $::config_parms{'aog_oauth_tokens_file'} ) {
        $oauth_tokens = retrieve( $::config_parms{'aog_oauth_tokens_file'} );
    }

    if ( $main::Debug{'aog'} ) {
	print STDERR <<EOF;
[AoGSmartHome] Debug: aog_auth_path = $::config_parms{'aog_auth_path'}
[AoGSmartHome] Debug: aog_fulfillment_url = $::config_parms{'aog_fulfillment_url'}
[AoGSmartHome] Debug: aog_oauth_tokens_file = $::config_parms{'aog_oauth_tokens_file'}
[AoGSmartHome] Debug: Dumping \$oauth_tokens...
EOF
        print STDERR Dumper $oauth_tokens;
        print STDERR "[AoGSmartHome] Debug: done.\n";
    }
}

#
# Receives an HTTP error response string and generates the HTTP
# header and HTML page to return to the HTTP client.
#
# Sample HTTP error responses:
#
# "400 Bad Request", "408 Request Timeout", "500 Internal Server Error".
#
# https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
#
# Other parts of the AoG HTTP server helper call this when some error
# condition is detected, like a missing HTTP argument.
#
sub http_error($) {
    my ($http_response) = @_;

    $style = $main::config_parms{ 'html_style' . $Http{format} }
      if $main::config_parms{ 'html_style' . $Http{format} }
      and !defined $style;

    my $html_body = <<EOF;
<HTML>
<HEAD>
$style
<TITLE>$http_response</TITLE>
</HEAD>
<BODY>
<H1>Bad Request</H1>

<P>Your browser made a request that this server does not understand.</P>
</BODY>
</HTML>
EOF

    my $html_head = "HTTP/1.1 $http_response\r\n";
    $html_head .= "Server: MisterHouse\r\n";
    $html_head .= "Content-Length: " . length($html_body) . "\r\n";
    $html_head .= "Date: @{[time2str(time)]}\r\n";
    $html_head .= "\r\n";

    return $html_head . $html_body;
}

sub process_http_aog {
    my ( $uri, $request_type, $body, $socket, %Http ) = @_;
    my $html;

    if ( $::config_parms{'aog_enable'}
        && !scalar list_objects_by_type('AoGSmartHome_Items') )
    {
        print STDERR "[AoGSmartHome] AoG is enabled but there are no AoG items; disabling AoG!\n";
        $::config_parms{'aog_enable'} = 0;
        return 0;
    }

    if ( $uri eq $::config_parms{'aog_auth_path'} ) {
        print "[AoGSmartHome] Debug: Processing OAuth request.\n" if $main::Debug{'aog'};

        if ( $request_type eq 'POST' ) {
            print "[AoGSmartHome] Debug: Processing HTTP POST.\n" if $main::Debug{'aog'};

            if ( !exists $HTTP_ARGV{'password'} ) {
                &main::print_log("[AoGSmartHome] missing 'password' argument in HTTP POST");

                return http_error("400 Bad Request");
            }

            $Authorized = password_check( $HTTP_ARGV{'password'}, 'http' );
            if ( !$Authorized ) {
                $html = "<p>Login failed.</p>\n";
            }
        }

        if ( !exists $HTTP_ARGV{'client_id'} ) {
            &main::print_log("[AoGSmartHome] client_id parameter missing from OAuth request.");
            return http_error("400 Bad Request");
        }

        if ( $HTTP_ARGV{'client_id'} ne $::config_parms{'aog_client_id'} ) {
            &main::print_log(
                "[AoGSmartHome] Received client_id \'$HTTP_ARGV{'client_id'}\' does not match our client_id \'$::config_parms{'aog_client_id'}\'.");
            return http_error("400 Bad Request");
        }

        if ( !exists $HTTP_ARGV{'state'} ) {
            &main::print_log("[AoGSmartHome] state parameter missing from OAuth request.");
            return http_error("400 Bad Request");
        }

        if ( !exists $HTTP_ARGV{'redirect_uri'} ) {
            &main::print_log("[AoGSmartHome] redirect_uri parameter missing from OAuth request.");
            return http_error("400 Bad Request");
        }

        # Verify "redirect_uri" value
        if ( $HTTP_ARGV{'redirect_uri'} !~ m%https://oauth-redirect.googleusercontent.com/r/$::config_parms{'project_id'}% ) {
            &main::print_log("[AoGSmartHome] invalid redirect_uri (should be \"https://oauth-redirect.googleusercontent.com/r/$::config_parms{'project_id'}\"");
            return http_error("400 Bad Request");
        }

        if ( !exists $HTTP_ARGV{'response_type'} ) {
            &main::print_log("[AoGSmartHome] response_type parameter missing from OAuth request.");
            return http_error("400 Bad Request");
        }

        if ( $HTTP_ARGV{'response_type'} ne 'token' ) {
            &main::print_log(
                "[AoGSmartHome] Invalid response_type \'$HTTP_ARGV{'response_type'}\' in OAuth request; must be 'token' for OAuth 2.0 implicit flow.");
            return http_error("400 Bad Request");
        }

        if ( !$Authorized ) {
            #
            # User is not authenticated (authorized). Present a login form.
            #

            $html .= <<EOF;
<FORM name=pw action="https://$Http{'X-Forwarded-Host'}$config_parms{'aog_auth_path'}" method="POST">
    <b>Password:</b><INPUT size=10 name='password' type='password'>
    <INPUT type="submit" value='Submit Password'>

    <INPUT type="hidden" name="redirect_uri" value="$HTTP_ARGV{'redirect_uri'}">
    <INPUT type="hidden" name="client_id" value="$HTTP_ARGV{'client_id'}">
    <INPUT type="hidden" name="response_type" value="token">
    <INPUT type="hidden" name="state" value="$HTTP_ARGV{'state'}">
</FORM>

<P>This form is used for logging into MisterHouse.<P>
EOF

            return html_page( 'MisterHouse Actions on Google Login', $html );
        }

        #
        # User is authenticated.
        #

        my $token;

        foreach my $t ( keys %{$oauth_tokens} ) {
            if ( $oauth_tokens->{$t} eq $Authorized ) {
                print "[AoGSmartHome] Debug: found token '$t' for user '$Authorized'\n"
                  if $main::Debug{'aog'};
                $token = $t;
                last;
            }
        }

        if ( !$token ) {

            # We didn't find an existing token for the authenticated user;
            # generate a new token (making sure token is unique).
            while (1) {
                $token = encode_base64( int rand(RAND_MAX), '' );

                if ( !exists $oauth_tokens->{$token} ) {
                    $oauth_tokens->{$token} = $Authorized;
                    last;
                }
            }

            print "[AoGSmartHome] Debug: token for user '$Authorized' did not exist; generated token '$token'\n"
              if $main::Debug{'aog'};

            store $oauth_tokens, $::config_parms{'aog_oauth_tokens_file'};
        }

        return http_redirect("$HTTP_ARGV{'redirect_uri'}#access_token=$token&token_type=bearer&state=$HTTP_ARGV{'state'}");
    }
    elsif ( $uri eq $::config_parms{'aog_fulfillment_url'} ) {
        print "[AoGSmartHome] Debug: Processing fulfillment request.\n" if $main::Debug{'aog'};

        if ( !$Http{Authorization} || $Http{Authorization} !~ /Bearer (\S+)/ ) {
            return http_error("401 Unauthorized");
        }

        my $received_token = $1;

        if ( exists $oauth_tokens->{$received_token} ) {
            print "[AoGSmartHome] Debug: fulfillment request has correct token '$received_token' for user '$oauth_tokens->{$received_token}'\n"
              if $main::Debug{'aog'};
        }
        else {
            &main::print_log("[AoGSmartHome] Incorrect token '$received_token' in fulfillment request!");

            print "[AoGSmartHome] Debug: Incorrect token '$received_token' in fulfillment request!\n"
              if $main::Debug{'aog'};

            return http_error("401 Unauthorized");
        }

        #
        # See here for reference on what Google will send to us:
        #
        # https://developers.google.com/actions/smarthome/create-app#build_fulfillment
        #

        my $aog_items_objname = ( &list_objects_by_type('AoGSmartHome_Items') )[0];
        my $aog_items         = get_object_by_name($aog_items_objname);

        my $body = decode_json($body);

        if ( $body->{'inputs'}->[0]->{'intent'} eq 'action.devices.SYNC' ) {
            return $aog_items->sync($body);
        }
        elsif ( $body->{'inputs'}->[0]->{'intent'} eq 'action.devices.QUERY' ) {
            return $aog_items->query($body);
        }
        elsif ( $body->{'inputs'}->[0]->{'intent'} eq 'action.devices.EXECUTE' ) {
            return $aog_items->execute($body);
        }
        else {
            # Bad boy
            return http_error("400 Bad Request");
        }
    }
}

1;    # Make "require" happy

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Eloy Paris <peloy@chapus.net>

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

