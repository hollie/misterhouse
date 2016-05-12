
=head1 B<Pushover>

=head2 SYNOPSIS

This module allows MisterHouse to send notification messages to Pushover.net clients.  See http://pushover.net/ for details of the service and API.

=head2 CONFIGURATION

Configure the required pushover settings in your mh.private.ini file:

  Pushover_token = <API token from Pushover.net registration> 
  Pushover_user =  <User or Group ID from Pushover.net registraton>
  Pushover_priority = [-1 | 0 | 1 | 2]  Default message priority,  defaults to 0.
  Pushover_title = "MisterHouse" Default title for messages if none provided 
  Pushover_disable = 1  Disable notifications.  Messages will still be logged

Create a pushover instance in the .mht file, or in user code:

.mht file:

  CODE, require Pushover; #noloop 
  CODE, my $push = new Pushover(); #noloop

A user code file overriding parameters normally specified in mh.private.ini.   All of the parameters are optional if properly configured in the ini file.

    use Pushover;
    my $push = new Pushover( {token => '1234qwer1234qewr1234qwer',
                              user =>  '2345wert2345wert2345qwer',
			      title => 'Home Notification',
			      priority => -1,
		             });


In user code send a message.  The only required parameter is the first, the message text.
Any of the parameters provided when initializing the Pushover instance may also be 
provided on the message send.  They will be merged with and override the default
values provided on initialization.   See the method documentation for below more details.

  $push->notify( "Some important message", { title => 'Security Alert', priority => 2 });

=head2 DESCRIPTION

The Pushover instance establishes the defaults for messages and acts as a rudimentary rate limiter for notifications.

The rate limiting kicks in if an identical message is sent within a 60 second threshold.  (Identical meaning
the same user, message, priority and title.)  Identical messages will be logged but not sent to the pushover service.
This will minimize excessive use of message credits if a configuration error causes looping notifications.

It's important to exclude the Pushover initialization from the loop, so that rate limiting thresholds can be detected
and pending acknowledgments are not lost.

=head2 INHERITS

NONE

=cut

package Pushover;

use strict;
use warnings;

=head2 DEPENDENCIES

  Data::Dumper:     Used for error reporting and debugging
  LWP::UserAgent:   Implements HTTPS for interaction with Pushover.net
  Digest::MD5:      Calculates hash for rate limiting duplicate messages
  JSON:             Decodes responses from Pushover.net

=cut

use Data::Dumper;
use LWP::UserAgent;
use Digest::MD5;
use JSON;

use constant TRACE => 0;    # enable for verbose tracing
use constant DUPWINDOW =>
  60;    # Time period in seconds to check for a duplicate message

=head2 METHODS

=over

=item C<new(p_self, p_parameter_hash)>

Creates a new Pushover object. The parameter hash is optional.  Defaults will be taken from the mh.private.ini file or are hardcoded. 

B<This must be excluded from the primary misterhouse loop, or the acknowledgment checking and duplicate message rate limiting will be lost>

  my $push = Pushover->new( {   priority  => 0,            # Set default Message priority,  -1, 0, 1, 2
  				retry     => 60,           # Set default retry priority 2 notification every 60 seconds
				expire    => 3600,         # Set default expration of the retry timer 
				title     => "Some title", # Set default title for messages
			 	token     => "xxxx...",    # Set the API Token 
				user      => "xxxx...",    # Set the target user or group id
				device    => "droid4",     # Set the target device (leaving this unset goes to all devices)
				url       => "http://x..", # Set the URL
				url_title => "A url",      # Set the title for the URL
				timestamp => "1331249662", # Set the timestamp
				sound     => "incoming",   # Set the sound to be played
				speak	  => 1,		   # Enable or disable speak of notifications and acknowledgment
				server    => "...",        # Override the Pushover server URL.  Defaults to the public pushover server
				       });

Any of these parameters may be specified in mh.private.ini by prefixing them with "Pushover_"

=cut

sub new {
    my ( $class, $params ) = @_;

    if ( defined $params && ref($params) ne 'HASH' ) {
        &::print_log(
            "[Pushover] ERROR!  Pushover->new() invalid parameter hash - Pushover disabled"
        );
        $params = {};
        $params->{disable} = 1;
    }

    $params = {} unless defined $params;

    my $self = {};
    $self->{priority} = 0;    # Priority zero - honor quite times
    $self->{speak}    = 1;    # Speak notifications and acknowledgments

    # Merge the mh.private.ini defaults into the object
    foreach (qw( token user priority title server retry expire speak disable)) {
        $self->{$_} = $params->{$_};
        $self->{$_} = $::config_parms{"Pushover_$_"} unless defined $self->{$_};
    }
    $self->{server} ||= 'https://api.pushover.net/';

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

    &::print_log("[Pushover] Pushover object initialized $note");
    &::print_log( "[Pushover] " . Data::Dumper::Dumper( \$self ) ) if TRACE;

    return bless( $self, $class );

}

=item C<notify(p_self, p_message, p_paramater_hash)>

This is the primary method of the Pushover object.  The message text is the only mandatory parameter.  

The optional parameter hash can be used to override defaults, or specify additional
information for the notification.  The list is not exclusive.  Additional parameters will be passed
in the POST to Pushover.net.  This allows support of any API parameter as defined at https://pushover.net/api

  $push->notify("Some urgent message", {  priority => 2,            # Message priority,  -1, 0, 1, 2
  				          retry    => 60,           # Retry priority 2 notification every 60 seconds
					  expire   => 3600,         # Give up if not ack of priority 2 notify after 1 hour
					  title    => "Some title", # Override title of message
					  token    => "xxxx...",    # Override the API Token - probably not useful
					  user     => "xxxx...",    # Override the target user/group
				       });

Notify will record the last message sent along with a timestamp.   If the duplicate message is sent within
a 60 second window,  the message will be logged and dropped.  A duplicate message is one with identical
user ID, message text, title and priority.   Although this permits a message to be sent to multiple users using
repeated notify commands, it is preferable to define a group ID on the Pushover.net site to minimize
traffic.

=cut

sub notify {
    my ( $self, $message, $params ) = @_;

    my $callparms = {};
    $callparms->{message} = $message || " ";

    # Allow notify parameter to override global disable parameter
    my $disable = $self->{disable};

    if ( defined $params && ref($params) ne 'HASH' ) {
        &::print_log(
            "[Pushover] ERROR!  notify called with invalid parameter hash - parameters ignored"
        );
        &::print_log(
            "[Pushover] Usage: ->push(\"Message\", { priority => 1, title => \"Some title\"})"
        );
    }
    else {
        $disable = $params->{disable} if ( defined $params->{disable} );
    }

    my $note = ($disable) ? '- Notifications disabled' : '';

    # Copy the calling hash since we need to modify it.
    if ( defined $params && ref($params) eq 'HASH' ) {
        foreach ( keys %{$params} ) {
            next if ( $_ eq 'disable' );   # internal override, not for pushover
            $callparms->{$_} = $params->{$_};
        }
    }

    # Merge in the message defaults, They can be overridden
    foreach (qw( token user priority title url url_title sound retry expire )) {
        next unless ( defined $self->{$_} );
        $callparms->{$_} = $self->{$_} unless defined $callparms->{$_};
    }

    #Priority 2 messages require a retry and expire timer, make sure they are valid
    if ( $callparms->{priority} == 2 ) {

        $callparms->{retry} ||= 30;
        $callparms->{retry} = 30 if ( $callparms->{retry} < 30 );

        $callparms->{expire} ||= 3600;
        $callparms->{expire} = 86400 if ( $callparms->{expire} > 86400 );
    }

    &::print_log(
        "[Pushover] Notify parameters: " . Data::Dumper::Dumper( \$callparms ) )
      if TRACE;

    my $msgsig =
      Digest::MD5::md5_base64( $callparms->{message}
          . $callparms->{user}
          . $callparms->{priority}
          . $callparms->{title} );

    if ( my $lasttime = $self->{_lastSent}{$msgsig} ) {
        if ( time() < $lasttime + DUPWINDOW ) {
            &::print_log(
                "[Pushover] Skipped duplicate notification: $callparms->{message} within "
                  . DUPWINDOW
                  . " seconds." );
            return;
        }
    }

    $self->{_lastSent}{$msgsig} = time();

    my $resp;
    $resp =
      LWP::UserAgent->new()
      ->post( $self->{server} . '1/messages.json', $callparms, )
      unless $disable;
    &::print_log("[Pushover] message: $callparms->{message} $note");
    &::speak("Pushover notification $callparms->{message} $note")
      if $self->{speak};

    return if $disable;    # Don't check the response if posting is disabled

    &::print_log(
        "[Pushover] Notify results: " . Data::Dumper::Dumper( \$resp ) )
      if TRACE;

    my $decoded_json = JSON::decode_json( $resp->content() );
    if ( $resp->is_success() ) {

        # For priority 2 messages, queue a receipt for subsequent checking
        if ( $callparms->{priority} == 2 ) {
            my $rcpt = $decoded_json->{receipt};
            $self->{_receipts}{$rcpt} = $callparms->{message};
            my $timer = $self->{_receiptTimer};
            $timer->set( 30, sub { &Pushover::_checkReceipt($self) }, -1 );

        }

    }
    else {
        &::print_log(
            "[Pushover] ERROR: POST Failed: Status: $decoded_json->{status} - $decoded_json->{errors} "
        );
    }

    &::print_log( "[Pushover] " . Data::Dumper::Dumper( \$self ) ) if TRACE;

    return;
}

=item C<_checkReceipt(p_self)>

Private callback routine used by the Timer to check if any pending receipts
have been acknowledged.  Once acknowledged, the receipt is deleted
from the queue, and the acknowledgement is logged.

=cut

sub _checkReceipt {
    my $self  = shift;
    my $timer = $self->{_receiptTimer};

    unless ( scalar %{ $self->{_receipts} } ) {
        &::print_log("[Pushover] No receipts Found - killing timer") if TRACE;
        $timer->set(0);
        return;
    }

    foreach ( keys %{ $self->{_receipts} } ) {
        my $resp =
          LWP::UserAgent->new()
          ->get(
            "$self->{server}" . "1/receipts/$_.json?token=$self->{token}" );
        if ( $resp->is_success() ) {
            &::print_log( "[Pushover] Get for Receipt check succeeded:"
                  . Data::Dumper::Dumper( \$resp ) )
              if TRACE;
            my $decoded_json = JSON::decode_json( $resp->content() );
            if ( $decoded_json->{acknowledged} ) {
                &::print_log( "[Pushover] "
                      . $self->{_receipts}{$_}
                      . ": Message has been acknowledged" );
                &::speak(
                    "Pushover message acknowledged: $self->{_receipts}{$_}")
                  if $self->{speak};
                delete $self->{_receipts}{$_};
            }
            elsif ( $decoded_json->{expired} ) {
                &::speak(
                    "Pushover message expired without acknowledment: $self->{_receipts}{$_}"
                ) if $self->{speak};
                &::print_log( "[Pushover] "
                      . $self->{_receipts}{$_}
                      . ": Message has expired without acknowledgment" );
                delete $self->{_receipts}{$_};
            }

            # else - still waiting for an ack or expiration.
        }
        else {
            &::print_log( "[Pushover] ERROR: Get for receipt check failed:"
                  . Data::Dumper::Dumper( \$resp ) );
            delete $self->{_receipts}{$_};
        }
    }

    $timer->set(0) unless ( scalar %{ $self->{_receipts} } );
    return;
}

1;

=back

=head2 AUTHOR

George Clark

=head2 SEE ALSO

http://Pushover.net/

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

