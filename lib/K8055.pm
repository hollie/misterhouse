
=head1 B<K8055>

=head2 SYNOPSIS

This is the mh client interface for my K8055 interface board daemon.
Once you have created a K8055 object, you must tell it which input ports you are interested in using the doUpdate... methods.

  $k8055 = new K8055;
  if ($Reload) {
    $k8055->doUpdateDigital(4);
    $k8055->doUpdateAnalogue(2);
  }

Whenever the value of these ports change, $k8055->state_now will return the name of the port that has changed (i.e. 'digital 4').  The state of each port is checked every 10 seconds (by default, can be changed).

Use the write... methods to change the value of the output ports.

=head2 DESCRIPTION

K8055 daemon MisterHouse Interface  http://www.velleman.be/ot/en/product/view/?id=351346

=head2 INHERITS

B<>

=head2 METHODS

=over

=cut

=item B<state_now>

For one pass, will return the name of the input port that has just changed.

  if ($state=$k8055->state_now()) {
    if ($state eq 'digital 5') {
      speak "The digital 5 port just changed value";
    }
    if ($state eq 'counter 1') {
      speak "Counter number 1 just changed";
    }
    if ($state eq 'analogue 2') {
      speak ("Analogue port 2 now reads ".$k8055->readAnalogue(2));
    }
  }

=cut

use strict;
use Socket_Item;

package K8055;

@K8055::ISA = ('Generic_Item');

my $numDigitalInputPorts  = 5;
my $numAnalogueInputPorts = 2;
my $numCounters           = 2;
my $idNumber              = 0;

sub new {
    my ( $class, $hostname, $port ) = @_;
    my $self = {};
    bless $self, $class;

    $self->{state}          = undef;
    $self->{state_now}      = undef;
    $self->{said}           = undef;
    $self->{state_changed}  = undef;
    $self->{last_event}     = undef;
    $self->{digital}        = [ -1, -1, -1, -1, -1 ];
    $self->{analogue}       = [ -1, -1 ];
    $self->{counter}        = [ -1, -1 ];
    $self->{updateDigital}  = [ 0, 0, 0, 0, 0 ];
    $self->{updateAnalogue} = [ 0, 0 ];
    $self->{updateCounter}  = [ 0, 0 ];
    $self->{updatePeriod}   = 10;
    $self->{idNumber}       = $idNumber;
    $idNumber++;

    $self->initialize( $hostname, $port );

    return $self;
}

sub printDebug {
    my ( $self, $message ) = @_;

    if ( !$main::Debug{k8055} ) {
        return;
    }

    $self->printMessage($message);
}

sub printMessage {
    my ( $self, $message ) = @_;

    &main::print_log( "K8055 (" . $self->{idNumber} . "): $message" );
}

sub initialize {
    my ( $self, $hostname, $port ) = @_;

    $self->{startUpRun} = 1;
    $self->printMessage("initializing");

    $hostname = $::config_parms{k8055_host} unless $hostname;
    $port     = $::config_parms{k8055_port} unless $port;

    $self->{socket} =
      new Socket_Item( undef, undef, "$hostname:$port",
        'k8055-' . $self->{idNumber},
        'tcp', 'record', "\n" );
    $self->{socket}->start();
    &main::MainLoop_pre_add_hook( \&checkForData, undef, $self )
      ;    # not persistent
}

sub checkForData {
    my ($self) = @_;
    my $data;

    if ( &::new_second( $self->{updatePeriod} ) ) {
        if ( $self->{socket}->active() ) {
            $self->requestUpdates();
        }
        else {
            $self->{socket}->start();
        }
    }

    if ( $self->{socket}->inactive_now() ) {
        $self->printMessage("can't talk to daemon");
    }

    if ( $data = $self->{socket}->said() ) {
        $self->parseResponse($data);
    }
}

sub parseResponse {
    my ( $self, $data ) = @_;

    $data =~ s/\x00//g;
    $data =~ s/\n//g;
    my ( $success, $command, $porttype, $portnumber, $value ) =
      split( /\s+/, $data );
    if ( $success eq 'error' ) {
        $self->printDebug("received error message ($data)");
        return;
    }
    if ( $success ne 'ok' ) {
        $self->printMessage(
            "received unknown message success=$success ($data)");
        return;
    }
    if ( $command eq 'value' ) {
        $self->printDebug("received value update ($data)");
        if ( $porttype eq 'digital' ) {
            if ( $self->{digital}[ $portnumber - 1 ] != $value ) {
                $self->set("digital $portnumber");
            }
            $self->{digital}[ $portnumber - 1 ] = $value;
            return;
        }
        if ( $porttype eq 'analogue' ) {
            if ( $self->{analogue}[ $portnumber - 1 ] != $value ) {
                $self->set("analogue $portnumber");
            }
            $self->{analogue}[ $portnumber - 1 ] = $value;
            return;
        }
        if ( $porttype eq 'counter' ) {
            if ( $self->{counter}[ $portnumber - 1 ] != $value ) {
                $self->set("counter $portnumber");
            }
            $self->{counter}[ $portnumber - 1 ] = $value;
            return;
        }
    }
    if ( $command eq 'confirmation' ) {
        $self->printDebug("confirmation message received ($data)");
        return;
    }
    $self->printMessage("received unknown command=$command ($data)");
}

sub requestUpdates {
    my ($self) = @_;

    $self->printDebug("requesting updated values");
    $self->sendCommand('update');
    for ( my $i = 1; $i <= $numDigitalInputPorts; $i++ ) {
        if ( $self->{updateDigital}[ $i - 1 ] == 1 ) {
            $self->sendCommand("read digital $i");
        }
    }
    for ( my $i = 1; $i <= $numAnalogueInputPorts; $i++ ) {
        if ( $self->{updateAnalogue}[ $i - 1 ] == 1 ) {
            $self->sendCommand("read analogue $i");
        }
    }
    for ( my $i = 1; $i <= $numCounters; $i++ ) {
        if ( $self->{updateCounter}[ $i - 1 ] == 1 ) {
            $self->sendCommand("read counter $i");
        }
    }
}

sub sendCommand {
    my ( $self, $command ) = @_;

    $self->printDebug("sending command $command");

    if ( $self->{socket}->active() ) {
        $self->{socket}->set($command);
    }
}

=item B<readAnalogue, readDigital, readCounter>

Returns the value of the given port as read on the last check.

  # returns the last read value of digital port 4
  $k8055->readDigital(4);

=cut

sub readDigital {
    my ( $self, $portNum ) = @_;

    return $self->{digital}[ $portNum - 1 ];
}

sub readAnalogue {
    my ( $self, $portNum ) = @_;

    return $self->{analogue}[ $portNum - 1 ];
}

sub readCounter {
    my ( $self, $portNum ) = @_;

    return $self->{counter}[ $portNum - 1 ];
}

=item B<writeAnalogue, writeDigital>

Sets the value of the output ports.

  # sets analogue port 2 to 143/255 x 5V (i.e. 0=0 V, 255 = 5 V).
  $k8055->writeAnalogue(2,143);

=cut

sub writeDigital {
    my ( $self, $portNum, $value ) = @_;

    $self->writePort( 'digital', $portNum, $value );
}

sub writeAnalogue {
    my ( $self, $portNum, $value ) = @_;

    $self->writePort( 'analogue', $portNum, $value );
}

sub writeCounter {
    my ( $self, $portNum, $value ) = @_;

    $self->writePort( 'counter', $portNum, $value );
}

sub writePort {
    my ( $self, $portType, $portNum, $value ) = @_;

    $self->sendCommand("write $portType $portNum, $value");
}

=item B<resetCounter>

Resets the given counter.

  # resets counter 2
  $k8055->resetCounter(2);

=cut

sub resetCounter {
    my ( $self, $portNum ) = @_;

    $self->sendCommand("reset $portNum");
}

=item B<setDebounce>

Sets the debounce of each counter in milliseconds.

  # sets the debounce of timer 1 to 350ms
  $k8055->setDebounce(1,350);

=cut

sub setDebounce {
    my ( $self, $portNum, $debounce ) = @_;

    $self->sendCommand("debounce $portNum $debounce");
}

=item B<doUpdateAnalogue, doUpdateDigital, doUpdateCounter>

Tells the object to care about the given port(s).  If this command isn't called, then the corresponding read... method will always return -1 and the state variable will never be set.

  # read and monitor digital ports 2, 3 and 5
  $k8055->doUpdateDigital(2,5,3);

=cut

sub doUpdateDigital {
    my ( $self, @ports ) = @_;

    foreach my $portNum (@ports) {
        $self->{updateDigital}[ $portNum - 1 ] = 1;
    }
}

sub doUpdateAnalogue {
    my ( $self, @ports ) = @_;

    foreach my $portNum (@ports) {
        $self->{updateAnalogue}[ $portNum - 1 ] = 1;
    }
}

sub doUpdateCounter {
    my ( $self, @ports ) = @_;

    foreach my $portNum (@ports) {
        $self->{updateCounter}[ $portNum - 1 ] = 1;
    }
}

=item B<setUpdatePeriod>

Sets how often we update the input port readings.  Defaults to 10 seconds.

  # input ports will be read every 2 seconds.
  $k8055->setUpdatePeriod(2);

=cut

sub setUpdatePeriod {
    my ( $self, $period ) = @_;

    $self->{updatePeriod} = $period;
}

=item B<getUpdatePeriod>

Gets the current auto update period in seconds.

  print "current update period is ".$k8055->getUpdatePeriod()." seconds";

=cut

sub getUpdatePeriod {
    my ($self) = @_;

    return $self->{updatePeriod};
}

=item B<update>

Immediate requests updated values from the ports that we are interested in.  Note that the data will not immediately be available on return from this method as updates are asynchronous.

  $k8055->update();

=cut

sub update {
    my ($self) = @_;

    $self->requestUpdates();
}

1;

=back

=head2 INI PARAMETERS

k8055_host - Hostname that is running k8055d.

k8055_port - Port on hostname to which daemon is listening.

=head2 AUTHOR

Matthew Williams

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

