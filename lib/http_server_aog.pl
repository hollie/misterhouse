
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

use strict;

use CGI;
use Config;
use MIME::Base64;
use JSON qw(encode_json decode_json);
use Storable;
use constant RANDBITS                        => $Config{randbits};
use constant RAND_MAX                        => 2**RANDBITS;
use constant ACCESS_TOKEN_EXPIRATION_SECONDS => 24 * 60 * 60;
use constant NEVER_EXPIRES                   => eval( $Config{nv_overflows_integers_at} );

# Cache of OAuth authentication tokens. Persistent tokens are stored
# in $::config_parms{'aog_oauth_tokens_file'} and read on startup.
#
# $oauth_tokens is for implicit tokens and access tokens.
#
# $oauth_codes is for authorization_codes and refresh_tokens that cannot be
# used for fulfillment.
my $FILENAME_PARAMETER = "_FILENAME_PARAMETER";
my $oauth_tokens;
my $oauth_codes;

sub http_server_aog_startup {
    if ( !$::config_parms{'aog_enable'} ) {
        &main::print_log("[AoGSmartHome] AoG is disabled.");
        return;
    }
    else {
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
    $::config_parms{'aog_oauth_codes_file'} = "$config_parms{data_dir}/.aog_codes"
      if !defined $::config_parms{'aog_oauth_codes_file'};

    if ( -e $::config_parms{'aog_oauth_tokens_file'} ) {
        $oauth_tokens = retrieve( $::config_parms{'aog_oauth_tokens_file'} );
    }
    if ( -e $::config_parms{'aog_oauth_codes_file'} ) {
        $oauth_codes = retrieve( $::config_parms{'aog_oauth_codes_file'} );
    }
    $oauth_tokens->{$FILENAME_PARAMETER} = 'aog_oauth_tokens_file';
    $oauth_codes->{$FILENAME_PARAMETER}  = 'aog_oauth_codes_file';
    remove_expired_tokens($oauth_tokens);
    remove_expired_tokens($oauth_codes);

    if ( $main::Debug{'aog'} ) {
        print STDERR <<EOF;
[AoGSmartHome] Debug: aog_auth_path = $::config_parms{'aog_auth_path'}
[AoGSmartHome] Debug: aog_fulfillment_url = $::config_parms{'aog_fulfillment_url'}
[AoGSmartHome] Debug: Dumping \$oauth_tokens...
EOF
        print STDERR Dumper $oauth_tokens;
        print STDERR "[AoGSmartHome] Debug: Dumping \$oauth_codes...\n";
        print STDERR Dumper $oauth_codes;
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
sub http_error($;$) {
    my ( $http_response, $html_body ) = @_;

    my $style = $main::config_parms{ 'html_style' . $Http{format} }
      if $main::config_parms{ 'html_style' . $Http{format} };

    if ( !$html_body ) {
        $html_body = <<EOF;
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
    }

    my $html_head = "HTTP/1.1 $http_response\r\n";
    $html_head .= "Server: MisterHouse\r\n";
    $html_head .= "Content-Length: " . length($html_body) . "\r\n";
    $html_head .= "Date: @{[time2str(time)]}\r\n";
    $html_head .= "\r\n";

    return $html_head . $html_body;
}

sub check_token($$) {
    my ( $token, $token_map ) = @_;
    return undef if ( !exists $token_map->{$token} );
    my ( $value, $expiration ) = @{ $token_map->{$token} };
    if ( time() >= $expiration ) {
        print "[AoGSmartHome] Debug: token '$token' expired at $expiration, removing it.\n"
          if $main::Debug{'aog'};
        delete $token_map->{$token};
        store $token_map, $::config_parms{ $token_map->{$FILENAME_PARAMETER} };
        return undef;
    }
    return $value;
}

sub remove_expired_tokens($) {
    my ($token_map) = @_;
    my $now = time();
    foreach my $t ( keys %{$token_map} ) {
        next if ( $t eq $FILENAME_PARAMETER );
        my ( $value, $expiration ) = @{ $token_map->{$t} };
        if ( !$expiration ) {    # Probably a legacy token
            $expiration = NEVER_EXPIRES;
            print "[AoGSmartHome] Debug: token '$t' has no expiration, setting to $expiration.\n"
              if $main::Debug{'aog'};
            $token_map->{$t} = [ $value, $expiration ];
        }
        if ( $now >= $expiration ) {
            print "[AoGSmartHome] Debug: token '$t' expired at $expiration, removing it.\n"
              if $main::Debug{'aog'};
            delete $token_map->{$t};
        }
    }
    store $token_map, $::config_parms{ $token_map->{$FILENAME_PARAMETER} };
}

sub generate_new_token($$$) {
    my ( $value, $expiration, $token_map ) = @_;
    my $token;

    # We didn't find an existing token for the authenticated user;
    # generate a new token (making sure token is unique).
    do {
        $token = encode_base64( int rand(RAND_MAX), '' );
    } while ( exists $token_map->{$token} );

    $token_map->{$token} = [ $value, $expiration ];

    print "[AoGSmartHome] Debug: generated token '$token' for '$value' (expiration $expiration).\n"
      if $main::Debug{'aog'};

    store $token_map, $::config_parms{ $token_map->{$FILENAME_PARAMETER} };

    return $token;
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

    my $argv = \%HTTP_ARGV;
    if ( $request_type eq 'POST' ) {

        # The merging in http_server.pl uses a regular expression that excludes lots of valid parts
        # of application/x-www-form-urlencoded bodies, such as a full URL in redirect_url, or
        # slashes in the client ids or secrets. Using CGI directly is more robust;
        $argv = scalar CGI->new($body)->Vars();
    }

    if ( $uri eq $::config_parms{'aog_auth_path'} ) {
        print "[AoGSmartHome] Debug: Processing OAuth request.\n" if $main::Debug{'aog'};

        if ( $request_type eq 'POST' ) {
            print "[AoGSmartHome] Debug: Processing HTTP POST.\n" if $main::Debug{'aog'};

            if ( !exists $argv->{'password'} ) {
                &main::print_log("[AoGSmartHome] missing 'password' argument in HTTP POST");

                return http_error("400 Bad Request");
            }

            $Authorized = password_check( $argv->{'password'}, 'http' );
            if ( !$Authorized ) {
                $html = "<p>Login failed.</p>\n";
            }
        }

        if ( !exists $argv->{'client_id'} ) {
            &main::print_log("[AoGSmartHome] client_id parameter missing from OAuth request.");
            return http_error("400 Bad Request");
        }

        if ( $argv->{'client_id'} ne $::config_parms{'aog_client_id'} ) {
            &main::print_log("[AoGSmartHome] Received client_id \'$argv->{'client_id'}\' does not match our client_id \'$::config_parms{'aog_client_id'}\'.");
            return http_error("400 Bad Request");
        }

        if ( !exists $argv->{'state'} ) {
            &main::print_log("[AoGSmartHome] state parameter missing from OAuth request.");
            return http_error("400 Bad Request");
        }

        if ( !exists $argv->{'redirect_uri'} ) {
            &main::print_log("[AoGSmartHome] redirect_uri parameter missing from OAuth request.");
            return http_error("400 Bad Request");
        }

        # Verify "redirect_uri" value
        if ( $argv->{'redirect_uri'} !~ m%https://oauth-redirect.googleusercontent.com/r/$::config_parms{'project_id'}% ) {
            &main::print_log("[AoGSmartHome] invalid redirect_uri (should be \"https://oauth-redirect.googleusercontent.com/r/$::config_parms{'project_id'}\"");
            return http_error("400 Bad Request");
        }

        if ( !exists $argv->{'response_type'} ) {
            &main::print_log("[AoGSmartHome] response_type parameter missing from OAuth request.");
            return http_error("400 Bad Request");
        }

        if ( $argv->{'response_type'} ne 'token' && $argv->{'response_type'} ne 'code' ) {
            &main::print_log(
                "[AoGSmartHome] Invalid response_type \'$argv->{'response_type'}\' in OAuth request; must be 'token' or 'code' for OAuth 2.0 flow.");
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

    <INPUT type="hidden" name="redirect_uri" value="$argv->{'redirect_uri'}">
    <INPUT type="hidden" name="client_id" value="$argv->{'client_id'}">
    <INPUT type="hidden" name="response_type" value="$argv->{'response_type'}">
    <INPUT type="hidden" name="state" value="$argv->{'state'}">
</FORM>

<P>This form is used for logging into MisterHouse.<P>
EOF

            return html_page( 'MisterHouse Actions on Google Login', $html );
        }

        #
        # User is authenticated.
        #

        if ( $argv->{'response_type'} eq 'token' ) {
            my $token = generate_new_token( $Authorized, NEVER_EXPIRES, $oauth_tokens );
            return http_redirect("$argv->{'redirect_uri'}#access_token=$token&token_type=bearer&state=$argv->{'state'}");

        }
        elsif ( $argv->{'response_type'} eq 'code' ) {
            my $code = generate_new_token(
                $Authorized, time() + 600,    # initial code is valid for 10m
                $oauth_codes,
            );
            return http_redirect("$argv->{'redirect_uri'}?code=$code&token_type=bearer&state=$argv->{'state'}");

        }
        else {
            &main::print_log(
                "[AoGSmartHome] Invalid response_type \'$argv->{'response_type'}\' in OAuth finalization; must be 'token' or 'code' for OAuth 2.0 flow.");
            return http_error("400 Bad Request");
        }
    }
    elsif ( defined $::config_parms{'aog_tokens_path'} && $uri eq $::config_parms{'aog_tokens_path'} ) {
        print "[AoGSmartHome] Debug: Processing token exchange request.\n" if $main::Debug{'aog'};
        my $invalid_grant = encode_json { error => "invalid_grant" };

        if ( $request_type ne 'POST' ) {
            &main::print_log("[AoGSmartHome] request is not a POST request!");
            return http_error("400 Bad Request");
        }

        # Verify that the client_id identifies the request origin as an authorized origin, and that
        # the client_secret matches the expected value.
        if ( !exists $argv->{'client_id'} ) {
            &main::print_log("[AoGSmartHome] client_id parameter missing from OAuth request.");
            return http_error( "400 Bad Request", $invalid_grant );
        }

        if ( $argv->{'client_id'} ne $::config_parms{'aog_client_id'} ) {
            &main::print_log("[AoGSmartHome] Received client_id \'$argv->{'client_id'}\' does not match our client_id \'$::config_parms{'aog_client_id'}\'.");
            return http_error( "400 Bad Request", $invalid_grant );
        }

        if ( !exists $argv->{'client_secret'} ) {
            &main::print_log("[AoGSmartHome] client_secret parameter missing from OAuth request.");
            return http_error( "400 Bad Request", $invalid_grant );
        }

        if ( $argv->{'client_secret'} ne $::config_parms{'aog_client_secret'} ) {
            &main::print_log(
                "[AoGSmartHome] Received client_secret \'$argv->{'client_secret'}\' does not match our client_id \'$::config_parms{'aog_client_secret'}\'.");
            return http_error( "400 Bad Request", $invalid_grant );
        }

        # Verify authorization code is valid and not expired, and the client ID specified in the
        # request matches the client ID associated with the authorization code.
        if ( !exists $argv->{'code'} && !exists $argv->{'refresh_token'} ) {
            &main::print_log("[AoGSmartHome] code and refresh_token parameter missing from OAuth request.");
            return http_error( "400 Bad Request", $invalid_grant );
        }

        my $code = $argv->{'code'};
        my $refresh_token;
        if ($code) {    # grant_type=authorization_code
                        # Verify the URL specified by the redirect_uri parameter is identical to the value used in
                        # the initial authorization request.
            if ( $argv->{'redirect_uri'} !~ m%https://oauth-redirect.googleusercontent.com/r/$::config_parms{'project_id'}% ) {
                &main::print_log(
                        "[AoGSmartHome] invalid redirect_uri (got \'$argv->{'redirect_uri'}\', should be \"https://oauth-redirect.googleusercontent.com/r/"
                      . $::config_parms{'project_id'}
                      . "\"" );
                return http_error( "400 Bad Request", $invalid_grant );
            }
        }
        else {    # grant_type=refresh_token
            $code          = $argv->{'refresh_token'};
            $refresh_token = $code;                      # reuse existing refresh_token
            print "[AoGSmartHome] Debug: using refresh_token '$code'.\n" if $main::Debug{'aog'};
        }
        my $authenticated = check_token( $code, $oauth_codes );
        if ( !$authenticated ) {
            &main::print_log("[AoGSmartHome] Received code \'$argv->{'code'}\' does not exist.");
            return http_error( "400 Bad Request", $invalid_grant );
        }

        # Otherwise, using the user ID from the authorization code, generate a refresh token and an access token. These tokens can be any string value, but they must uniquely represent the user and the client the token is for, and they must not be guessable. For access tokens, also record the expiration time of the token (typically an hour after you issue the token). Refresh tokens do not expire.
        # Return the following JSON object in the body of the HTTPS response:
        my $token = generate_new_token( $authenticated, time() + ACCESS_TOKEN_EXPIRATION_SECONDS, $oauth_tokens, );

        $refresh_token = generate_new_token( $authenticated, NEVER_EXPIRES, $oauth_codes, ) if ( !$refresh_token );

        return &main::json_page(
            encode_json {
                token_type    => "Bearer",
                access_token  => $token,
                refresh_token => $refresh_token,
                expires_in    => ACCESS_TOKEN_EXPIRATION_SECONDS,
            }
        );
    }
    elsif ( $uri eq $::config_parms{'aog_fulfillment_url'} ) {
        print "[AoGSmartHome] Debug: Processing fulfillment request.\n" if $main::Debug{'aog'};

        if ( !$Http{Authorization} || $Http{Authorization} !~ /Bearer (\S+)/ ) {
            return http_error("401 Unauthorized");
        }

        my $received_token = $1;

        my $authenticated = check_token( $received_token, $oauth_tokens );
        if ($authenticated) {
            print "[AoGSmartHome] Debug: fulfillment request has correct token '$received_token' for user '$authenticated'\n"
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

