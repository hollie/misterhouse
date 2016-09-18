
=head1 B<Insteon::IOLinc>

=head2 SYNOPSIS

In user code:

    use Insteon::IOLinc;
    $io_device = new Insteon::IOLinc('12.34.56',$myPLM);

In items.mht:

    INSTEON_IOLINC, 12.34.56, io_device, io_group

Turning on a relay:

    $io_device->set('on');

Turning off a relay:

    $io_device->set('off');

Requesting sensor status: 

    $io_device->request_sensor_status();

Print the Current Device Settings to the log:

    $io_device->get_operating_flag();

=head2 DESCRIPTION

Support for the Insteon IOLinc.

The IOLinc is a strange device in that commands sent to it control one aspect
of the device, but commands received from it are from another aspect of the
device.

=head3 LINKING

As a result of the IOLinc's oddities, when the IOLinc is set as a controller
of another device, that other device will be controlled by the sensor state.
However, when the IOLinc is set as a responder in a link, the relay of the
IOLinc will change with the commands sent by the controller.

=head3 STATE REPORTED IN MisterHouse

MisterHouse objects are only designed to hold the state of a single aspect.  As a 
result of the IOLinc's oddities, the $io_device defined using the examples above
will track the state of the relay only.  The state of the sensor can be obtained
using the C<request_sensor_status()> command.

One more oddity is that using the "set" button on the side of the device to 
change the state of the relay, will cause MH to perceive this as a change in 
the state of the sensor, thus placing the sensor and relay objects out of sync.

=head3 SENSOR STATE CHILD OBJECT

To create a device that directly tracks the state of the sensor, you can use 
C<Insteon::IOLinc_sensor>.  The state of the child object will reflect the state 
of the sensor and it will be automatically updated as long as the IOLinc is 
linked to the 

However, if you want to directly link an obect to the sensor 
be sure to use the normal SCENE_MEMBER code in your mht file with the IOLinc
defined as the controller.

Instructions for this object are contained in C<Insteon::IOLinc_sensor>.

=head3 DOOR CHILD OBJECT

IOLinc devices are often used to monitor/control doors such as garage doors (Smarthome
has a full kit for this). The Insteon::IOLinc_door simplifies this use case by creating
an object that has open/closed states, as well as sets the device to the proper
Momentary_B mode.

However, if you want to directly link an obect to the sensor 
be sure to use the normal SCENE_MEMBER code in your mht file with the IOLinc
defined as the controller.

Instructions for this object are contained in C<Insteon::IOLinc_door>.


=head2 NOTES

This module works with the Insteon IOLinc device from Smarthome.  The EZIO device
uses a different set of commands and this code will offer only limited, if any
support at all, for EZIO devices.

The state that the relay is in when the device is linked to the PLM matters if
you are using relay mode Momentary_A (I think).

=head2 BUGS

The implementation of Momentary_A needs work.  It can be properly set on the
device, however it isn't clear how the preference for ON of OFF is selected.
This is likely done in D1-D3 in the responder link.  Setting the link to OFF
in the definition may be enough to make it work, I don't yet know.

=head2 INHERITS

L<Insteon::BaseDevice|Insteon::BaseInsteon/Insteon::BaseDevice>, 

=head2 METHODS

=over

=cut

use strict;
use Insteon::BaseInsteon;

package Insteon::IOLinc;

@Insteon::IOLinc::ISA = ('Insteon::BaseDevice');

my %operating_flags = (
    'program_lock_on'         => '00',
    'program_lock_off'        => '01',
    'led_on_during_tx'        => '02',
    'led_off_during_tx'       => '03',
    'relay_follows_input_on'  => '04',
    'relay_follows_input_off' => '05',
    'momentary_a_on'          => '06',
    'momentary_a_off'         => '07',
    'led_off'                 => '08',
    'led_enabled'             => '09',
    'key_beep_enabled'        => '0a',
    'key_beep_off'            => '0b',
    'x10_tx_on_when_off'      => '0c',
    'x10_tx_on_when_on'       => '0d',
    'invert_sensor_on'        => '0e',
    'invert_sensor_off'       => '0f',
    'x10_rx_on_is_off'        => '10',
    'x10_rx_on_is_on'         => '11',
    'momentary_b_on'          => '12',
    'momentary_b_off'         => '13',
    'momentary_c_on'          => '14',
    'momentary_c_off'         => '15',
);

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;
    my $self = new Insteon::BaseDevice( $p_deviceid, $p_interface );
    $$self{operating_flags} = \%operating_flags;
    bless $self, $class;
    $self->restore_data( 'momentary_time', 'relay_mode' );
    $$self{momentary_time} = 20 unless defined( $$self{momentary_time} );
    $$self{relay_mode} = 'latching' unless defined( $$self{relay_mode} );
    $$self{momentary_timer} = new Timer;
    return $self;
}

=item C<set(state[,setby,response])>

Handles setting and receiving states from the device.

If the set command originates from the device, it represents the sensor state 
and is processed accordingly.  All other set commands are sent to the device
and control the relay state.

=cut

sub set {
    my ( $self, $p_state, $p_setby, $p_respond ) = @_;
    if ( ref $p_setby && $p_setby->can('equals') && $p_setby->equals($self) ) {
        my $curr_milli = sprintf( '%.0f', &main::get_tickcount );
        my $window = 1000;
        if ( $p_state eq $$self{child_state}
            && ( $curr_milli - $$self{child_set_milliseconds} < $window ) )
        {
            ::print_log( "[Insteon::IOLinc] Received duplicate "
                  . $self->get_object_name
                  . " sensor "
                  . $p_state
                  . " message, ignoring." )
              if $self->debuglevel( 1, 'insteon' );
            $self->dupe_count_log(1) if $self->can('dupe_count_log');
        }
        else {
            ::print_log( "[Insteon::IOLinc] Received "
                  . $self->get_object_name
                  . " sensor "
                  . $p_state
                  . " message." )
              if $self->debuglevel( 1, 'insteon' );
            $$self{child_state}            = $p_state;
            $$self{child_set_milliseconds} = $curr_milli;
            if ( ref $$self{child_sensor} ) {
                $$self{child_sensor}
                  ->set_receive( $p_state, $p_setby, $p_respond );
            }
            if ( ref $$self{child_door} ) {
                $$self{child_door}
                  ->set_receive( $p_state, $p_setby, $p_respond );
            }
        }
    }
    else {
        $self->SUPER::set( $p_state, $p_setby, $p_respond );
    }
    return;
}

=item C<request_sensor_status()>

Works just like C<request_status()> but it requests the status of the sensor.  
Will cause the sensor status to be printed to the log.

As an alternative to calling the function repeatedly, you can define an 
L<Insteon::IOLinc_sensor|Insteon::IOLincf/Insteon::IOLinc_sensor> object.

=cut

sub request_sensor_status {
    my ( $self, $requestor ) = @_;
    $$self{child_status_request_pending} = $self->group;
    $$self{m_status_request_pending} = ($requestor) ? $requestor : 1;
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, 'status_request',
        '01' );
    $self->_send_cmd($message);
}

=item C<_is_info_request()>

Checks to see if an incomming message contains the sensor state or the operating
flags for the device.  If not the message is passed on to 
L<Insteon::BaseObject::_is_info_requested()|Insteon::BaseInsteon/Insteon::BaseObject>.

=cut

sub _is_info_request {
    my ( $self, $cmd, $ack_setby, %msg ) = @_;
    my $is_info_request = 0;
    my $parent          = $self->get_root();
    if ( $$parent{child_status_request_pending} ) {
        $is_info_request++;
        my $child_state =
          &Insteon::BaseObject::derive_link_state( hex( $msg{extra} ) );
        &::print_log( "[Insteon::IOLinc] received status for "
              . $self->get_object_name
              . "sensor of: $child_state "
              . "hops left: $msg{hopsleft}" )
          if $self->debuglevel( 1, 'insteon' );
        $ack_setby = $$self{child_sensor} if ref $$self{child_sensor};
        if ( ref $$self{child_sensor} ) {
            $$self{child_sensor}->set_receive( $child_state, $ack_setby );
        }
        $ack_setby = $$self{child_door} if ref $$self{child_door};
        if ( ref $$self{child_door} ) {
            $$self{child_door}->set_receive( $child_state, $ack_setby );
        }
        delete( $$parent{child_status_request_pending} );
    }
    elsif ( $cmd eq 'get_operating_flags' ) {
        $is_info_request++;
        my $output = "";
        my $flags  = hex( $msg{extra} );
        $output .=
          ( $flags & 0x01 ) ? "Program Lock: On; " : "Program Lock: Off; ";
        $output .=
          ( $flags & 0x02 ) ? "Transmit Led: On; " : "Transmit Led: Off; ";
        $output .=
          ( $flags & 0x04 ) ? "Relay Linked: On; " : "Relay Linked: Off; ";
        $output .=
          ( $flags & 0x20 ) ? "X10 Reverse: On; " : "X10 Reverse: Off; ";
        $output .=
          ( $flags & 0x40 )
          ? "Trigger Reverse: On; "
          : "Trigger Reverse: Off; ";

        if ( !( $flags & 0x08 ) ) {
            $output .= "Latching: On.";
            $$self{relay_mode} = 'latching';
        }
        else {
            my $momentary_state = '';
            if ( $flags & 0x10 ) {
                $$self{relay_mode} = 'momentary_b';
                $momentary_state .= "Momentary_B: On.";
            }
            elsif ( $flags & 0x80 ) {
                $$self{relay_mode} = 'momentary_c';
                $momentary_state .= "Momentary_C: On.";
            }
            else {
                $$self{relay_mode} = 'momentary_a';
                $momentary_state .= "Momentary_A: On.";
            }
            $output .= $momentary_state;
        }
        ::print_log("[Insteon::IOLinc] Device Settings are: $output");
    }
    else {
        $is_info_request =
          $self->SUPER::_is_info_request( $cmd, $ack_setby, %msg );
    }
    return $is_info_request;
}

=item C<_process_message()>

Checks for and handles unique IOLinc messages such as the momentary time settings. 
All other messages are transferred to C<Insteon::BaseObject::_process_message()|Insteon::BaseInsteon/Insteon::BaseObject>.

=cut

sub _process_message {
    my ( $self, $p_setby, %msg ) = @_;
    my $clear_message = 0;
    my $pending_cmd =
      ( $$self{_prior_msg} ) ? $$self{_prior_msg}->command : $msg{command};
    my $ack_setby =
      ( ref $$self{m_status_request_pending} )
      ? $$self{m_status_request_pending}
      : $p_setby;
    if (   $msg{is_ack}
        && $self->_is_info_request( $pending_cmd, $ack_setby, %msg ) )
    {
        $clear_message = 1;
        $$self{m_status_request_pending} = 0;
        $self->_process_command_stack(%msg);
    }
    elsif ( $msg{command} eq "extended_set_get" && $msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );

        #If this was a get request don't clear until data packet received
        main::print_log( "[Insteon::IOLinc] Extended Set/Get ACK Received for "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        if ( $$self{_ext_set_get_action} eq 'set' ) {
            main::print_log("[Insteon::IOLinc] Clearing active message")
              if $self->debuglevel( 1, 'insteon' );
            $clear_message = 1;
            $$self{_ext_set_get_action} = undef;
            $self->_process_command_stack(%msg);
        }
    }
    elsif ( $msg{command} eq "extended_set_get" && $msg{is_extended} ) {
        if ( substr( $msg{extra}, 0, 6 ) eq "000101" ) {
            $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );

            #D4 = Time;
            $$self{momentary_time} = hex( substr( $msg{extra}, 8, 2 ) );
            main::print_log( "[Insteon::IOLinc] The Momentary Time Setting "
                  . "on device "
                  . $self->get_object_name
                  . " is set to: "
                  . $$self{momentary_time}
                  . " tenths of a second." );
            $clear_message = 1;
            $self->_process_command_stack(%msg);
        }
        else {
            main::print_log( "[Insteon::IOLinc] WARN: Corrupt Extended "
                  . "Set/Get Data Received for "
                  . $self->get_object_name )
              if $self->debuglevel( 1, 'insteon' );
        }
    }
    elsif ( $msg{command} eq "set_operating_flags" && $msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );
        main::print_log( "[Insteon::IOLinc] Acknowledged flag set for "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        $clear_message = 1;
        $self->_process_command_stack(%msg);
    }
    else {
        $clear_message = $self->SUPER::_process_message( $p_setby, %msg );
    }
    return $clear_message;
}

=item C<is_acknowledged([ack])>

Hijacks the routine in BaseObject.  This is used to set a timer to revert the 
relay state if a momentary state is used.

=cut

sub is_acknowledged {
    my ( $self, $p_ack ) = @_;
    if (   defined $p_ack
        && $p_ack
        && defined $$self{pending_state}
        && $$self{relay_mode} ne 'latching' )
    {
        #We are in a momentary mode, set a timer to reset the relay after the
        #defined momentary time. This seems preferable over using set_with_timer
        #as this will only trigger if the device actually acknowledges the
        #state change
        my $object_name = $self->get_object_name();
        my $action = $object_name . '->set_receive(OFF,' . $object_name . ')';

        #While the IOLinc can do momentary times down to .2 seconds, the timer
        #module can only do 1 second increments.  I figure this slight
        #difference is trivial.
        my $time = int( ( $$self{momentary_time} / 10 ) + 0.5 );
        $time = 1 unless ( $time >= 1 );
        $$self{momentary_timer}->set( $time, $action );
        ::print_log(
                "[Insteon::IOLinc] Relay in momentary mode, resetting state "
              . "of $object_name to OFF in $time second(s)" )
          if $self->debuglevel( 1, 'insteon' );
    }
    return $self->SUPER::is_acknowledged($p_ack);
}

=item C<set_momentary_time(time)>

$time in tenths of seconds (deciseconds) is the length of time the relay will close when 
a Momentary mode is is selected in C<set_relay_mode>.

Acceptable Values for time: [2-255]

Default: 20 (2 Seconds)

=cut

sub set_momentary_time {
    my ( $self, $momentary_time ) = @_;
    my $root = $self->get_root();
    if ( $momentary_time <= 255 ) {
        $momentary_time = 2 if $momentary_time <= 1;    #Can't set to 1 or 0
        ::print_log(
                "[Insteon::IOLinc] Setting Momentary Time to $momentary_time "
              . "tenths of a second for "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
    }
    else {
        ::print_log(
            "[Insteon::IOLinc] WARN Invalid Momentary Time of $momentary_time "
              . "tenths of a second for "
              . $self->get_object_name );
    }

    #D2 = 0x06, D3 = deciseconds of time from 0x02-0xFF.  0x00 = Latching?
    my $extra = '000006';
    $extra .= sprintf( "%02x", $momentary_time );
    $extra .= '0000000000000000000000';
    $$root{_ext_set_get_action} = "set";
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $root,
        'extended_set_get', $extra );
    $root->_send_cmd($message);
    $$self{momentary_time} = $momentary_time;
    return;
}

=item C<get_momentary_time()>

Prints the device's current momentary time setting to the log. And stores it in 
memory so that MH can reset the state of the relay after the appropriate amount
of time

=cut

sub get_momentary_time {
    my ($self) = @_;
    my $root   = $self->get_root();
    my $extra  = '000000000000000000000000000000';
    $$root{_ext_set_get_action} = "get";
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $root,
        'extended_set_get', $extra );
    $root->_send_cmd($message);
    return;
}

=item C<set_relay_linked([0|1])>

If set to 1 whenever the Sensor is On the Relay will be on and whenever the 
Sensor is Off the Relay will be Off.

Default 0

=cut

sub set_relay_linked {
    my ( $self, $relay_linked ) = @_;
    my $parent = $self->get_root();
    if ($relay_linked) {
        $parent->set_operating_flag('relay_follows_input_on');
    }
    elsif ( defined $relay_linked ) {
        $parent->set_operating_flag('relay_follows_input_off');
    }
    return;
}

=item C<set_trigger_reverse([0|1])>

If set to 1, it reverses the sensor value so that a closed sensor switch reports its 
state as OFF and an open sensor switch reports its state as ON. 

Default 0

=cut

sub set_trigger_reverse {
    my ( $self, $trigger_reverse ) = @_;
    my $parent = $self->get_root();
    if ($trigger_reverse) {
        $parent->set_operating_flag('invert_sensor_on');
    }
    elsif ( defined $trigger_reverse ) {
        $parent->set_operating_flag('invert_sensor_off');
    }
    return;
}

=item C<set_relay_mode([Latching|Momentary_A|Momentary_B|Momentary_C])>

Latching: The relay will remain open or closed until another command is received. 
Momentary time is ignored.

Momentary_A: The relay will close momentarily. If it is Linked while On it will 
respond to On. If it is Linked while Off it will respond to Off. (This setting
is likely not implemented properly by MH, if you need this setting you will have
to be a guinea pig and test it out for us. Questions: Can this be achieved by 
defining links as off? When this is used, how does the IOLinc respond to direct
ON and OFF commands rather than All-Link Commands?)

Momentary_B: Both - On and Off both cause the relay to close momentarily.

Momentary_C: Look at Sensor - If the sensor is On the relay will close momentarily 
when an On command is received. If the sensor is Off the relay will close momentarily 
when an Off command is received.

Default Latching

=cut

sub set_relay_mode {
    my ( $self, $relay_mode ) = @_;
    my $parent = $self->get_root();
    if ( lc($relay_mode) eq 'latching' ) {
        $parent->set_operating_flag('momentary_a_off');
        $parent->set_operating_flag('momentary_b_off');
        $parent->set_operating_flag('momentary_c_off');
        $$self{relay_mode} = 'latching';
    }

    #Momentary A must be on for any Momentary setting
    elsif ( lc($relay_mode) eq 'momentary_a' ) {
        $parent->set_operating_flag('momentary_b_off');
        $parent->set_operating_flag('momentary_c_off');
        $parent->set_operating_flag('momentary_a_on');
        $$self{relay_mode} = 'momentary_a';
    }
    elsif ( lc($relay_mode) eq 'momentary_b' ) {
        $parent->set_operating_flag('momentary_a_on');
        $parent->set_operating_flag('momentary_c_off');
        $parent->set_operating_flag('momentary_b_on');
        $$self{relay_mode} = 'momentary_b';
    }
    elsif ( lc($relay_mode) eq 'momentary_c' ) {
        $parent->set_operating_flag('momentary_a_on');
        $parent->set_operating_flag('momentary_b_off');
        $parent->set_operating_flag('momentary_c_on');
        $$self{relay_mode} = 'momentary_c';
    }
    return;
}

=item C<get_voice_cmds>

Returns a hash of voice commands where the key is the voice command name and the
value is the perl code to run when the voice command name is called.

Higher classes which inherit this object may add to this list of voice commands by
redefining this routine while inheriting this routine using the SUPER function.

This routine is called by L<Insteon::generate_voice_commands> to generate the
necessary voice commands.

=cut 

sub get_voice_cmds {
    my ($self)      = @_;
    my $object_name = $self->get_object_name;
    my %voice_cmds  = (
        %{ $self->SUPER::get_voice_cmds },

        #Rename status command to note that it will request status of the
        #relay
        'on'                       => "$object_name->set(\"on\")",
        'off'                      => "$object_name->set(\"off\")",
        'status - relay'           => "$object_name->request_status",
        'status - sensor'          => "$object_name->request_sensor_status",
        'print momentary time'     => "$object_name->get_momentary_time",
        'link relay to sensor'     => "$object_name->set_relay_linked(1)",
        'unlink relay from sensor' => "$object_name->set_relay_linked(0)",
        'reverse sensor output'    => "$object_name->set_trigger_reverse(1)",
        'unreverse sensor output'  => "$object_name->set_trigger_reverse(0)",
        'set relay to latching' => "$object_name->set_relay_mode(\"Latching\")",
        'set relay to momentary a' =>
          "$object_name->set_relay_mode(\"Momentary_A\")",
        'set relay to momentary b' =>
          "$object_name->set_relay_mode(\"Momentary_B\")",
        'set relay to momentary c' =>
          "$object_name->set_relay_mode(\"Momentary_C\")",
        'print settings to log' => "$object_name->get_operating_flag"
    );

    #Remove generic status command
    delete $voice_cmds{status};
    return \%voice_cmds;
}

=back

=head2 AUTHOR

Kevin Robert Keegan

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::IOLinc_sensor>

=head2 SYNOPSIS

User Code:

    $io_device_sensor = new Insteon::IOLinc_sensor($io_device);

Where $io_device is the parent device defined above.

=head2 DESCRIPTION

Creates a device that directly tracks the state of the IOLinc sensor.  The state 
of this object will reflect the state of the sensor and it will be automatically 
updated as long as the IOLinc is linked to the PLM.  

Tie_events can be used on this child object.  However, if you want to directly 
link an obect to the sensor be sure to use the normal SCENE_MEMBER code in your 
mht file with the main IOLinc device defined as the controller.

=head2 INHERITS

L<Generic_Item|Generic_Item>

=head2 METHODS

=over

=cut

package Insteon::IOLinc_sensor;
use strict;

@Insteon::IOLinc_sensor::ISA = ('Generic_Item');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    $$self{parent}{child_sensor} = $self;
    return $self;
}

=item C<set_receive()>

Receives sensor state messages from the parent object and sets the state of this 
device accordingly.

=cut

sub set_receive {
    my ( $self, $p_state, $p_setby, $p_respond ) = @_;
    $self->SUPER::set( $p_state, $p_setby, $p_respond );
}

=back

=head2 AUTHOR

Kevin Robert Keegan

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::IOLinc_door>

=head2 SYNOPSIS

User Code:

    $io_device_door = new Insteon::IOLinc_door($io_device);

Where $io_device is the parent device defined above.

=head2 DESCRIPTION

Creates a door_item like device when the IOLinc is used to track/control a door, such
as the garage door kit. Provides and open and closed state, and a set will trigger a
relay close.  Adding this object will place the parent device into Momentary B mode. 

Tie_events can be used on this child object.  However, if you want to directly 
link an obect to the sensor be sure to use the normal SCENE_MEMBER code in your 
mht file with the main IOLinc device defined as the controller.

=head2 INHERITS

L<Generic_Item|Generic_Item>

=head2 METHODS

=over

=cut

package Insteon::IOLinc_door;
use strict;

@Insteon::IOLinc_door::ISA = ('Generic_Item');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    $$self{parent}{child_door} = $self;
    @{ $$self{states} } = ( 'open', 'closed', 'error' );
    $parent->set_relay_mode("Momentary_B");
    return $self;
}

=item C<set_receive()>

Receives sensor state messages from the parent object and sets the state of this 
device accordingly.

=cut

sub set_receive {
    my ( $self, $p_state, $p_setby, $p_respond ) = @_;
    my $n_state;
    if ( $p_state eq "on" ) {
        $n_state = "open";
    }
    elsif ( $p_state eq "off" ) {
        $n_state = "closed";
    }
    else {
        $n_state = "error";
    }
    $self->SUPER::set( $n_state, $p_setby, $p_respond );
}

=item C<set_receive()>

Triggers the relay if the set request state differs from the current state. 

=cut

sub set {
    my ( $self, $p_state, $p_setby, $p_respond ) = @_;
    main::print_log( "[Insteon::IOlinc_door] set method called. current state: "
          . $self->state
          . " set to state: "
          . $p_state )
      if $self->debuglevel( 1, 'insteon' );

    $$self{parent}->set("on") if ( $p_state ne $self->state );
}

1;
