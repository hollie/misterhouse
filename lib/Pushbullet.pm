
=head1 B<Pushbullet>

=head2 SYNOPSIS

This module allows MisterHouse to push notification to Pushbullet.com devices.  See http://pushbullet.com/ for details of the service and API.

Pushbullet is similar to, but slightly simpler than Pushover.  The Pushbullet clients are free.

=head2 CONFIGURATION

Configure the required pushbullet settings in your mh.private.ini file:

  Pushbullet_token = <API token from Pushbullet.net registration> 
  Pushbullet_title = "MisterHouse" Default title for notes if none provided 
  Pushbullet_disable = 1  Disable notifications.  Messages will still be logged

Create a pushbullet instance in the .mht file, or in user code:

.mht file:

  CODE, require Pushbullet; #noloop 
  CODE, my $push = new Pushbullet(); #noloop

A user code file overriding parameters normally specified in mh.private.ini.   All of the parameters are optional if properly configured in the ini file.

    my $push = new Pushbullet( {token => '1234qwer1234qewr1234qwer',
			      title => 'Home Notification',
		             });


The following example shows how to push a note in the user code.  The only 
required parameter is the first, the note text. Any of the parameters provided 
when initializing the Pushbullet instance may also be provided on the note 
push.  They will be merged with and override the default values provided on 
initialization.   See the method documentation for below more details.

  my $iden = $push->push_note( "Some important message", { title => 'Security Alert' });
  
The returned $iden is the pushed message identification hash.  In the future 
this can be used to delete and possibly modify a push.

=head2 DESCRIPTION

The Pushbullet instance establishes the defaults for pushes.

=head2 INHERITS

NONE

=cut

package Pushbullet;

use strict;
use warnings;

=head2 DEPENDENCIES

  Data::Dumper:     Used for error reporting and debugging
  LWP::UserAgent:   Implements HTTPS for interaction with Pushbullet.com
  JSON:             Decodes responses from Pushbullet.com

=cut

use Data::Dumper;
use LWP::UserAgent;
use JSON;

use constant TRACE => 0;    # enable for verbose tracing

=head2 METHODS

=over

=item C<new(p_self, p_parameter_hash)>

Creates a new Pushbullet object. The parameter hash is optional.  Defaults will be taken from the mh.private.ini file or are hardcoded. 

  my $push = Pushbullet->new( {   
				title    => "Some title", # Set default title for messages
			 	token    => "xxxx...",    # Set the API Token 
				server   => "...",        # Override the Pushbullet server URL.  Defaults to the public pushbullet server
				speak    => 0             # Speak acknowledgments
				       });

Any of these parameters may be specified in mh.private.ini by prefixing them with "Pushbullet_"

=cut

sub new {
    my ( $class, $params ) = @_;

    if ( defined $params && ref($params) ne 'HASH' ) {
        &::print_log(
"[Pushbullet] ERROR!  Pushbullet->new() invalid parameter hash - Pushbullet disabled"
        );
        $params = {};
        $params->{disable} = 1;
    }

    $params = {} unless defined $params;

    my $self = {};
    # Set configuration defaults
    $self->{config}{speak}    = 1;    # Speak notifications and acknowledgments
    $self->{config}{server}   = 'https://api.pushbullet.com/';

    # mh.private.ini settings override the defaults
    foreach my $mkey (keys(%::config_parms)) {
        next if $mkey =~ /_MHINTERNAL_/;
        # Only look for pushbullet settings
        if ($mkey =~ /^Pushbullet_(.*$)/) {
            # Drop the prefix
            $self->{config}{$1} = $::config_parms{$1};
        }
    }
    
    # Passed parameters overriding the ini settings
    for (keys %{$params}){
        $self->{config}{$_} = $params->{$_};
    }

    my $note = ( $self->{config}{disable} ) ? '- Notifications disabled' : '';

    &::print_log("[Pushbullet] Pushbullet object initialized $note");
    &::print_log( "[Pushbullet] " . Data::Dumper::Dumper( \$self ) ) if TRACE;

    return bless( $self, $class );

}

=item C<push_note(p_self, p_note, p_paramater_hash)>

A user friendly interface to push a note.  The note text, p_note, is the only mandatory parameter.  

The optional parameter hash can be used to override defaults, or specify additional
information for the notification.  The list is not exclusive.  Additional parameters will be passed
in the POST to Pushbullet.com.  This allows support of any API parameter as defined at http://docs.pushbullet.com

  $push->push_note("Some urgent message", {  
					  title       => "Some title", # Override title of message
					  token       => "xxxx...",    # Override the API Token - probably not useful
					  device_iden => "xxxx..."     # The device to which the note should be sent to
				       });

By default, the device_iden is left blank, which causes the notes to be sent to
all devices on your account.

=cut

sub push_note {
    my ( $self, $message, $params ) = @_;
    
    $params = $self->check_params_hash($params);
    $params->{type} = "note"; #Force type to note when using this function
    $params->{body} = $message || " ";
    
    return $self->push_hash($params);
}

=item C<push_hash(p_self, p_parameter_hash)>

This is routine provides direct raw access to the push process.  It is not as user
friendly as the simpler push_note .... routines.

The parameter hash is required, and the required keys must be used such as type.

Other keys can override defaults, or specify additional information for the push.  
The list is not exclusive.  Additional parameters will be passed in the POST to 
Pushbullet.com.  This allows support of any API parameter as defined at 
http://docs.pushbullet.com

  $push->push_hash( {
					  type        => "note",
					  body        => "Note text",
					  title       => "Some title", # Override title of message
					  token       => "xxxx...",    # Override the API Token - probably not useful
					  device_iden => "xxxx..."     # The device to which the note should be sent to
				       });

By default, the device_iden is left blank, which causes the pushes to be sent to
all devices on your account.

=cut

sub push_hash {
    my ( $self, $params ) = @_;

    my $callparams = {};

    # Allow passed parameter to override global disable parameter
    my $disable = $self->{config}{disable};

    # Copy the calling hash since we need to modify it.
    if ( defined $params && ref($params) eq 'HASH' ) {
        foreach ( keys %{$params} ) {
            $disable = $params->{$_} if ( $_ eq 'disable' );
            # Skip non-pushbullet parameters
            next if (grep(/$_/i, @{['disable', 'speak', 'server']}));
            $callparams->{$_} = $params->{$_};
        }
    }
    
    my $note = ($disable) ? '- Notifications disabled' : '';

    # Merge in the message defaults, They can be overridden
    foreach (keys $self->{config}) {
        $callparams->{$_} = $self->{config}{$_} unless defined $callparams->{$_};
    }

    &::print_log(
        "[Pushbullet] Push Hash parameters: " . Data::Dumper::Dumper( \$callparams ) )
      if TRACE;
    
    # Form browser and request
    my $browser = LWP::UserAgent->new;
    my $req =  HTTP::Request->new( POST => $self->{config}{server} . 'v2/pushes');
    $req->content(JSON::encode_json($callparams));
    $req->authorization_basic( $self->{config}{token}, "" );
    $req->content_type('application/json'); # Posting JSON content is preferred
    my $resp;
    # Do not perform reqest if disabled
    $resp = $browser->request( $req ) unless ($disable);
    
    # Determine best way to describe message and log it
    my $description = $callparams->{title};
    $description = $callparams->{name} if (defined $callparams->{name});
    $description = $callparams->{body} if (defined $callparams->{body});
    &::print_log("[Pushbullet] message: $description $note");
    &::speak("Pushbullet notification $description $note")
      if $self->{config}{speak};

    return if $disable;    # Don't check the response if posting is disabled

    &::print_log(
        "[Pushbullet] Notify results: " . Data::Dumper::Dumper( \$resp ) )
      if TRACE;

    my $decoded_json = JSON::decode_json( $resp->content() );
    
    &::print_log( "[Pushbullet] " . Data::Dumper::Dumper( \$decoded_json ) ) if TRACE;
    
    if ( $resp->is_success() ) {
        # Return push iden
        return $decoded_json->{'iden'};
    }
    else {
        &::print_log(
"[Pushbullet] ERROR: POST Failed: Status: $decoded_json->{status} - $decoded_json->{errors} "
        );
        return;
    }
}

sub check_params_hash {
    my ($self, $params) = @_;
    if ( defined $params && ref($params) ne 'HASH' ) {
        &::print_log(
"[Pushbullet] ERROR! called with invalid parameter hash - passed parameters ignored"
        );
        return {};
    }
    else {
        return $params;
    }
}

1;

=back

=head2 AUTHOR

Kevin Robert Keegan (based on template from Pushover.pm by George Clark)

=head2 SEE ALSO

http://Pushbullet.com/

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

