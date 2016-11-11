
=head1 B<Pushsafer>

=head2 SYNOPSIS

This module allows MisterHouse to send notification messages to Pushsafer.com clients.  See https://www.pushsafer.com/ for details of the service and API.

=head2 CONFIGURATION

Configure the required pushsafer settings in your mh.private.ini file:

  Pushsafer_k		= <Private or Alias key from Pushsafer.com account> 
  Pushsafer_t		= "MisterHouse" Default title for messages if none provided 
  Pushsafer_d		= <Default device or device group id to send notifications to>
  Pushsafer_i		= <Default icon>
  Pushsafer_s		= <Default sound>
  Pushsafer_v		= <Default vibration>
  Pushsafer_disable = 1  Disable notifications.  Messages will still be logged

Create a pushsafer instance in the .mht file, or in user code:

.mht file:

  CODE, require Pushsafer; #noloop 
  CODE, my $push = new Pushsafer(); #noloop

A user code file overriding parameters normally specified in mh.private.ini.   All of the parameters are optional if properly configured in the ini file.

    use Pushsafer;
    my $push = new Pushsafer({
					k => '1234qwer1234qewr1234qwer',
					t => 'Home Notification',
					d => '111',
					i => '11',
					s => '5',
					v => '1',
		      });


In user code send a message.  The only required parameter is the first, the message text.
Any of the parameters provided when initializing the Pushsafer instance may also be 
provided on the message send.  They will be merged with and override the default
values provided on initialization.   See the method documentation for below more details.

  $push->notify( "Some important message", { t => 'Security Alert', i => 11 });

=head2 DESCRIPTION

The Pushsafer instance establishes the defaults for messages and acts as a rudimentary rate limiter for notifications.

The rate limiting kicks in if an identical message is sent within a 10 second threshold.  (Identical meaning
the same message, title and device.)  Identical messages will be logged but not sent to the pushsafer service.
This will minimize excessive use of message credits if a configuration error causes looping notifications.

It's important to exclude the Pushsafer initialization from the loop, so that rate limiting thresholds can be detected
and pending acknowledgments are not lost.

=head2 INHERITS

NONE

=cut

package Pushsafer;

use strict;
use warnings;

=head2 DEPENDENCIES

  Data::Dumper:     Used for error reporting and debugging
  LWP::UserAgent:   Implements HTTPS for interaction with Pushsafer.net
  Digest::MD5:      Calculates hash for rate limiting duplicate messages
  JSON:             Decodes responses from Pushsafer.net

=cut

use Data::Dumper;
use LWP::UserAgent;
use Digest::MD5;
use JSON;

use constant TRACE => 0;    # enable for verbose tracing
use constant DUPWINDOW =>
  10;    # Time period in seconds to check for a duplicate message

=head2 METHODS

=over

=item C<new(p_self, p_parameter_hash)>

Creates a new Pushsafer object. The parameter hash is optional.  Defaults will be taken from the mh.private.ini file or are hardcoded. 

B<This must be excluded from the primary misterhouse loop, or the acknowledgment checking and duplicate message rate limiting will be lost>

  my $push = Pushsafer->new( {
			k    	=> "xxxx...",    	# Set the Private or Alias Key
			t    	=> "Some title",	# Set default title for messages
			d    	=> "111",		   	# Set the target device or device group (leaving this unset goes to all devices)
			i    	=> "5",			   	# Set the icon to be displayed
			s    	=> "3",   			# Set the sound to be played
			v    	=> "1",   			# Set the vibration to be played
			speak	=> 1,		   	  	# Enable or disable speak of notifications and acknowledgment
	});

Any of these parameters may be specified in mh.private.ini by prefixing them with "Pushsafer_"

=cut

sub new {
    my ( $class, $params ) = @_;

    if ( defined $params && ref($params) ne 'HASH' ) {
        &::print_log(
            "[Pushsafer] ERROR!  Pushsafer->new() invalid parameter hash - Pushsafer disabled"
        );
        $params = {};
        $params->{disable} = 1;
    }

    $params = {} unless defined $params;

    my $self = {};
    $self->{speak}    = 1;    # Speak notifications and acknowledgements

    # Merge the mh.private.ini defaults into the object
    foreach (qw( k t d i s v speak disable)) {
        $self->{$_} = $params->{$_};
        $self->{$_} = $::config_parms{"Pushsafer_$_"} unless defined $self->{$_};
    }
    $self->{server} ||= 'https://www.pushsafer.com/';

    # initialize rudimentary duplicate message rate limiting
    my $lastSent = {};
    $self->{_lastSent} =
      $lastSent;              # Hash of message identifiers & time last sent

    # Internal parameters, Should not be overridden
    # Initialize array to track receipts and acknowledgements
    my $receipts = {};
    $self->{_receipts} =
      $receipts;    # Ref for the array of pending acknowledgments
    $self->{_receiptTimer} =
      Timer->new();    # Ref for the Timer object for acknowledgment checking

    my $note = ( $self->{disable} ) ? '- Notifications disabled' : '';

    &::print_log("[Pushsafer] Pushsafer object initialized $note");
    &::print_log("[Pushsafer] " . Data::Dumper::Dumper( \$self ) ) if TRACE;

    return bless( $self, $class );

}

=item C<notify(p_self, p_message, p_paramater_hash)>

This is the primary method of the Pushsafer object.  The message text is the only mandatory parameter.  

The optional parameter hash can be used to override defaults, or specify additional
information for the notification.  The list is not exclusive.  Additional parameters will be passed
in the POST to Pushsafer.com.  This allows support of any API parameter as defined at https://pushsafer.net/api

	$push->notify("Some urgent message", {
			k   => "xxxx...",      # Override the Private or Alias Key
            t   => "Some title",   # Override title of message
            d   => "1111"			# Device or device-group id 
	});

Notify will record the last message sent along with a timestamp.   If the duplicate message is sent within
a 10 second window,  the message will be logged and dropped.  A duplicate message is one with identical
message text, title and device.   Although this permits a message to be sent to multiple users using
repeated notify commands, it is preferable to define a group ID on the Pushsafer.com site to minimize
traffic.

=cut

sub notify {
    my ( $self, $message, $params ) = @_;

    my $callparms = {};
    $callparms->{m} = $message || " ";

    # Allow notify parameter to override global disable parameter
    my $disable = $self->{disable};

    if ( defined $params && ref($params) ne 'HASH' ) {
        &::print_log(
            "[Pushsafer] ERROR!  notify called with invalid parameter hash - parameters ignored"
        );
        &::print_log(
            "[Pushsafer] Usage: ->push(\"Message\", { title => \"Some title\", device => \"111\"})"
        );
    }
    else {
        $disable = $params->{disable} if ( defined $params->{disable} );
    }

    my $note = ($disable) ? '- Notifications disabled' : '';

    # Copy the calling hash since we need to modify it.
    if ( defined $params && ref($params) eq 'HASH' ) {
        foreach ( keys %{$params} ) {
            next if ( $_ eq 'disable' );   # internal override, not for pushsafer
            $callparms->{$_} = $params->{$_};
        }
    }

    # Merge in the message defaults, They can be overridden
    foreach (qw( k t d i s v )) {
        next unless ( defined $self->{$_} );
        $callparms->{$_} = $self->{$_} unless defined $callparms->{$_};
    }

    
    &::print_log(
        "[Pushsafer] Notify parameters: " . Data::Dumper::Dumper( \$callparms ) )
      if TRACE;

    my $msgsig =
      Digest::MD5::md5_base64( $callparms->{m}
          . $callparms->{t}
          . $callparms->{d} );

    if ( my $lasttime = $self->{_lastSent}{$msgsig} ) {
        if ( time() < $lasttime + DUPWINDOW ) {
            &::print_log(
                "[Pushsafer] Skipped duplicate notification: $callparms->{m} within "
                  . DUPWINDOW . " seconds." );
            return;
        }
    }

    $self->{_lastSent}{$msgsig} = time();

    my $resp;
    $resp =
      LWP::UserAgent->new()
      ->post( $self->{server} . 'api', $callparms, )
      unless $disable;
    &::print_log("[Pushsafer] message: $callparms->{m} $note");
    &::speak("Pushsafer notification $callparms->{m} $note")
      if $self->{speak};

    return if $disable;    # Don't check the response if posting is disabled

    &::print_log(
        "[Pushsafer] Notify results: " . Data::Dumper::Dumper( \$resp ) )
      if TRACE;

    my $decoded_json = JSON::decode_json( $resp->content() );
    if ( $resp->is_success() ) {

        &::print_log(
            "[Pushsafer] SUCCESS: Status: $decoded_json->{status} - $decoded_json->{errors} "
        );

    }
    else {
        &::print_log(
            "[Pushsafer] ERROR: POST Failed: Status: $decoded_json->{status} - $decoded_json->{errors} "
        );
    }

    &::print_log( "[Pushsafer] " . Data::Dumper::Dumper( \$self ) ) if TRACE;

    return;
}

1;

=back

=head2 AUTHOR

George Clark

=head2 MODIFICATIONS

2016/09/30 Kevin Siml Pushsafer.com

=head2 SEE ALSO

http://www.pushsafer.com/

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut