
=head1 B<Insteon::MotionSensor>

=head2 SYNOPSIS

In user code:

   use Insteon::MotionSensor;
   $motion = new Insteon::MotionSensor('12.34.56:01',$myPLM);
   $motion_light_level = new Insteon::MotionSensor('12.34.56:02',$myPLM);
   $motion_battery_level = new Insteon::MotionSensor('12.34.56:03',$myPLM);

In items.mht:

   INSTEON_MOTIONSENSOR, 12.34.56:01, $motion, $motion_group
   INSTEON_MOTIONSENSOR, 12.34.56:02, $motion_light_level, $motion_group
   INSTEON_MOTIONSENSOR, 12.34.56:03, $motion_battery_level, $motion_group

=head2 DESCRIPTION

Provides support for Insteon Motion Sensor versions 1 and 2.  Support includes
the ability to link the device to other devices, setting the various parameters
on the device (timeout, light level, LED brightness), receive motion commands, 
monitor the light level, and monitor the battery level.

MisterHouse is only able to communicate with a Motion Sensor when it is in "awake
mode."  The device is in "awake mode" while in its linking state.  To put the 
Motion Sensor into "awake mode", follow the instructions for placing the device into
linking mode.  In short, the instructions are to hold down the set button for 4-10
seconds until you hear a beep and/or see the LED flash.  The Motion Sensor will now
remain in "awake mode" for approximately 4 minutes.

To scan the link table, sync links, or set settings on the device, the Motion Sensor
must first be put into "awake mode."

=head3 Link Management

For version 2 devices, MH can manage the links of the device if it has been put
into awake mode.  To link other devices directly to the motion sensor, first 
create the necessary link entries in your mht file.  Then restart MisterHouse, 
and put the motion sensor into awake mode.  Then run sync_links to add the necessary
entries to the device and linked devices.

Version 1 devices do not respond even when in awake mode, all link management for
these devices must be done manually.

=head3 Battery and Light Level Monitoring Options:

For version 2 devices, there are two ways in which you can monitor the battery 
and light level.  For simplicity, these are referred to as the GROUP and QUERY
method.  Both, either, or neither method may be used.  

=head4 The GROUP Method

The Motion Sensor can send regular AllLink messages to signal changes in the
light or battery level.  As a result, the device has 3 groups.  Group 1 is used
for sending motion events, group 2 for sending light level events, and group 3 
for sending battery level events.  

When using the GROUP Method, the lighting and battery level events are binary, 
that is the event is either on or off.  The threshold for determining whether 
the light level is on or off must be set before hand.  The battery threshold is 
present and not modifiable.

When using this method, two additional motion objects will be created.  The state
of these objects is set by the group messages sent from the device.  Currently,
there is no known way to poll the device to request the current status of these
objects.  As such, if MisterHouse fails to receive the group message from the 
device, these objects may be out of sync.

To use this method, simply define objects for groups 2 & 3 in your user code
or mht file as described above.

=head4 The QUERY Method

Version 2 Motion Sensors can be queried to obtain the current light and voltage
level.  However, these query messages can only be sent while the device is awake.
Luckily, a Motion Sensor remains awake for a few seconds after it sends
a message.

If this method is used, MisterHouse will periodically send a query message to
the device after MisterHouse sees activity from the device.  The interval between
when these messages can be set by the user.  The response from the device 
contains a specific light and voltage level, as opposed to the simple binary
states provided by the GROUP method.

To use this method, set the C<set_query_time()> routine.

You can further create child objects that automatically track the state of the 
light and voltage levels.  These objects allow you to display the state of the
light and voltage levels on the MisterHouse webpage.  The child objects are 
described below.  You can then tie an event to the state of the child objects
with C<tie_event> for example to alert you when the battery level falls below a 
certain threshold.

=head2 INHERITS

L<Insteon::BaseDevice|Insteon::BaseInsteon/Insteon::BaseDevice>, 

=head2 METHODS

=over

=cut

package Insteon::MotionSensor;

use strict;
use Insteon::BaseInsteon;

@Insteon::MotionSensor::ISA = ('Insteon::BaseDevice');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::BaseDevice( $p_deviceid, $p_interface );
    if ( $self->is_root ) {
        $self->restore_data( 'query_timer', 'last_query_time' );
        $$self{queue_timer} = new Timer;
    }
    bless $self, $class;
    $$self{is_responder} = 0;
    $$self{is_deaf}      = 1;
    return $self;
}

=item C<get_extended_info()>

Only available for Motion Sensor Version 2 models.

Requests the status of various settings on the device.  Currently this is only
used to obtain the battery and light level.  If the device is awake, the battery
level and light level will be printed to the log.

You likely do not need to directly call this message, rather MisterHouse will issue
this request when it sees activity from the device and the C<set_query_timer()> has 
expired.

=cut

sub get_extended_info {
    my ( $self, $no_retry ) = @_;
    my $root  = $self->get_root();
    my $extra = '000000000000000000000000000000';
    $$root{_ext_set_get_action} = "get";
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $root,
        'extended_set_get', $extra );
    if ($no_retry) {
        $message->retry_count(1);
    }
    $root->_send_cmd($message);
    return;
}

=item C<set_query_timer([minutes])>

Only available for Motion Sensor Version 2 models.

Sets the minimum amount of time between battery and light level requests.  When 
the time elapsed since last receiving a battery and light level update from the device
exceeds this value, Misterhouse will request the battery and light level from 
the device the next time MisterHouse sees activity from the device.  Misterhouse 
will continue to request the battery and light level until it gets a response 
from the device.

Setting to 0 will disable automatic battery and light level requests.  1440 minutes
equals a day.

This setting will be saved between MisterHouse reboots.

=cut

sub set_query_timer {
    my ( $self, $minutes ) = @_;
    my $root = $self->get_root();
    $$root{query_timer} = sprintf( "%u", $minutes );
    ::print_log( "[Insteon::MotionSensor] Set query timer to "
          . $$root{query_timer}
          . " minutes" );
    return;
}

=item C<set_led_brightness([0-255])>

Sets the brightness of the LED light with 0 being off and 255 being full
brightness.  Factory default value is 100.

The device will only obey this setting if Jumper 5, the Remote Software
Management switch, is enabled.  To enable this, make sure jumper 5 is connected
to both pins.  Enabling the Software Mangement Switch will disable the light 
sensitivity and timeout dials on the device and require them to be set through
MisterHouse.

=cut

sub set_led_brightness {
    my ( $self, $value ) = @_;
    my $root = $self->get_root();
    ::print_log(
        "[Insteon::MotionSensor] Setting LED Brightness to $value of 255");
    $value = sprintf( "%02x", $value );
    my $extra = '000002' . $value;
    $extra .= '0' x ( 30 - length $extra );
    $$root{_ext_set_get_action} = "set";
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $root,
        'extended_set_get', $extra );
    $root->_send_cmd($message);
    return;
}

=item C<set_timeout([30-7680]seconds)>

Sets the number of seconds between the on and off messages sent by the device.  
If the device is set to on only, sets the amount of time between when on messages
can be sent.  If on only mode is enabled, on messages can be sent as frequent
as once every 10 seconds if C<all_motion_events()> is enabled.

The number of seconds must be in increments of 30 seconds.  Improper settings 
will be rounded down to nearest multiple of 30. The factory default value is 60. 
The lowest value is 30.  

The device will only obey this setting if Jumper 5, the Remote Software
Management switch, is enabled.  To enable this, make sure jumper 5 is connected
to both pins.  Enabling the Software Mangement Switch will disable the light 
sensitivity and timeout dials on the device and require them to be set through
MisterHouse.

=cut

sub set_timeout {
    my ( $self, $value ) = @_;
    my $root = $self->get_root();
    $value = ( sprintf( "%d", ( $value / 30 ) ) - 1 );
    my $readable_value = ( $value + 1 ) * 30;
    ::print_log(
        "[Insteon::MotionSensor] Setting timeout to $readable_value seconds.");
    $value = sprintf( "%02x", $value );
    my $extra = '000003' . $value;
    $extra .= '0' x ( 30 - length $extra );
    $$root{_ext_set_get_action} = "set";
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $root,
        'extended_set_get', $extra );
    $root->_send_cmd($message);
    return;
}

=item C<set_light_sensitivity([0-255])>

Sets the level of light at which the device perceives it to be night.  The lower
the value, the darker it needs to be for the unit to perceive night.  In night 
only mode, the device will not send an on command unless it is darker than this
setting.  In all cases, the group 2 light_level object, will turn to on when
the light level falls below this setting for more than 3 minutes.

The factory default value is 35.

The device will only obey this setting if Jumper 5, the Remote Software
Management switch, is enabled.  To enable this, make sure jumper 5 is connected
to both pins.  Enabling the Software Mangement Switch will disable the light 
sensitivity and timeout dials on the device and require them to be set through
MisterHouse.

=cut

sub set_light_sensitivity {
    my ( $self, $value ) = @_;
    my $root = $self->get_root();
    ::print_log(
        "[Insteon::MotionSensor] Setting light sensitivity level to $value of 255."
    );
    $value = sprintf( "%02x", $value );
    my $extra = '000004' . $value;
    $extra .= '0' x ( 30 - length $extra );
    $$root{_ext_set_get_action} = "set";
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $root,
        'extended_set_get', $extra );
    $root->_send_cmd($message);
    return;
}

=item C<enable_night_only([0/1])>

Only available on Motion Sensor Version 2.

When enabled, the device will only send motion events if the current light
level is below the light sensitivity.  The light sensitivity can be set with
C<set_light_sensitivity()>.

The device will only obey this setting if Jumper 5, the Remote Software
Management switch, is enabled.  To enable this, make sure jumper 5 is connected
to both pins.  Enabling the Software Mangement Switch will disable the light 
sensitivity and timeout dials on the device and require them to be set through
MisterHouse.

=cut

sub enable_night_only {
    my ( $self, $value ) = @_;
    my $root = $self->get_root();
    $$root{_set_bit_action} = ($value) ? "night_on" : "night_off";
    $root->get_extended_info();
    return;
}

=item C<enable_on_only([0/1])>

Only available on Motion Sensor Version 2.

When enabled, the device will only send ON motion events.  No OFF motion events
will be sent.

The device will only obey this setting if Jumper 5, the Remote Software
Management switch, is enabled.  To enable this, make sure jumper 5 is connected
to both pins.  Enabling the Software Mangement Switch will disable the light 
sensitivity and timeout dials on the device and require them to be set through
MisterHouse.

=cut

sub enable_on_only {
    my ( $self, $value ) = @_;
    my $root = $self->get_root();
    $$root{_set_bit_action} = ($value) ? "on_mode_on" : "on_mode_off";
    $root->get_extended_info();
    return;
}

=item C<enable_all_motion([0/1])>

Only available on Motion Sensor Version 2.

When enabled, the device will constantly send motion events whenever motion
is seen.  The device seems to be limited to one event per 10 seconds.  If 
disabled, the device will only send an ON event once per timeout period.  The
timeout period can be set with C<set_timeout()>.

The device will only obey this setting if Jumper 5, the Remote Software
Management switch, is enabled.  To enable this, make sure jumper 5 is connected
to both pins.  Enabling the Software Mangement Switch will disable the light 
sensitivity and timeout dials on the device and require them to be set through
MisterHouse.

=cut

sub enable_all_motion {
    my ( $self, $value ) = @_;
    my $root = $self->get_root();
    $$root{_set_bit_action} = ($value) ? "all_motion_on" : "all_motion_off";
    $root->get_extended_info();
    return;
}

=item C<_is_query_time_expired()>

Returns true if the last battery level response received by MisterHouse is older
than C<set_timeout>.

=cut

sub _is_query_time_expired {
    my ($self) = @_;
    my $root = $self->get_root();
    if ( $$root{query_timer} > 0
        && ( time - $$root{last_query_time} ) > ( $$root{query_timer} * 60 ) )
    {
        return 1;
    }
    return 0;
}

=item C<_process_message()>

Processes unique messages sent to the device, notably battery level messages, and
settings messages but passes the rest of the messages off to 
L<Insteon::BaseObject|Insteon::BaseInsteon/Insteon::BaseObject>.

=cut

sub _process_message {
    my ( $self, $p_setby, %msg ) = @_;
    my $clear_message = 0;
    my $root          = $self->get_root();
    if (   $root->_is_query_time_expired
        && $msg{type} eq "cleanup"
        && $msg{command} ne "extended_set_get" )
    {
        #Don't queue if incoming msg is an ext_set_get to avoid loop
        my $no_retry = 1;
        $root->get_extended_info($no_retry);
    }
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
        main::print_log(
            "[Insteon::MotionSensor] Extended Set/Get ACK Received for "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        if ( $$self{_ext_set_get_action} eq 'set' ) {
            if ( defined( $$root{_set_bit_action} ) ) {
                ::print_log( "[Insteon::MotionSensor] Set of "
                      . $$root{_set_bit_action}
                      . " flag acknowledged by "
                      . $root->get_object_name );
                $$root{_set_bit_action} = undef;
            }
            else {
                main::print_log(
                    "[Insteon::MotionSensor] Clearing active message")
                  if $self->debuglevel( 1, 'insteon' );
            }
            $clear_message = 1;
            $$self{_ext_set_get_action} = undef;
            $self->_process_command_stack(%msg);
        }
    }
    elsif ( $msg{command} eq "extended_set_get" && $msg{is_extended} ) {
        if (   substr( $msg{extra}, 0, 6 ) eq "000001"
            || substr( $msg{extra}, 0, 6 ) eq "000101" )
        {
            $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );

            #D11 = Light; D12 = Battery;
            my $voltage = ( hex( substr( $msg{extra}, 24, 2 ) ) / 10 );
            my $light_level = hex( substr( $msg{extra}, 22, 2 ) );
            main::print_log( "[Insteon::MotionSensor] The battery level "
                  . "for device "
                  . $self->get_object_name . " is: "
                  . $voltage
                  . " of 9.0 volts and the light level is "
                  . $light_level
                  . " of 255." );
            $$root{last_query_time} = time;
            if ( ref $$root{battery_object}
                && $$root{battery_object}->can('set_receive') )
            {
                $$root{battery_object}->set_receive( $voltage, $root );
            }
            if ( ref $$root{light_level_object}
                && $$root{light_level_object}->can('set_receive') )
            {
                $$root{light_level_object}->set_receive( $light_level, $root );
            }
            if ( defined $$root{_set_bit_action} ) {

                #Take current flags and apply changes
                my $curr_flags = substr( $msg{extra}, 12, 2 );
                my $bitflags = sprintf( '%08b', hex($curr_flags) );
                substr( $bitflags, 5, 1 ) = 0
                  if ( $$root{_set_bit_action} eq "night_on" );
                substr( $bitflags, 5, 1 ) = 1
                  if ( $$root{_set_bit_action} eq "night_off" );
                substr( $bitflags, 6, 1 ) = 0
                  if ( $$root{_set_bit_action} eq "on_mode_on" );
                substr( $bitflags, 6, 1 ) = 1
                  if ( $$root{_set_bit_action} eq "on_mode_off" );
                substr( $bitflags, 3, 1 ) = 1
                  if ( $$root{_set_bit_action} eq "all_motion_on" );
                substr( $bitflags, 3, 1 ) = 0
                  if ( $$root{_set_bit_action} eq "all_motion_off" );
                $bitflags = sprintf( "%02x", oct("0b$bitflags") );

                #Send command to set bits
                if ( $curr_flags ne $bitflags ) {
                    my $extra = '000005' . $bitflags;
                    $extra .= '0' x ( 30 - length $extra );
                    $$root{_ext_set_get_action} = "set";
                    my $message = new Insteon::InsteonMessage(
                        'insteon_ext_send', $root,
                        'extended_set_get', $extra
                    );
                    $root->_send_cmd($message);
                }
                else {
                    ::print_log( "[Insteon::MotionSensor] The "
                          . $$root{_set_bit_action}
                          . " flag was already "
                          . "set on device "
                          . $root->get_object_name );
                    $$root{_set_bit_action} = undef;
                }
            }
            $clear_message = 1;
            $self->_process_command_stack(%msg);
        }
        else {
            main::print_log( "[Insteon::MotionSensor] WARN: Unknown Extended "
                  . "Set/Get Data Message Received for "
                  . $self->get_object_name )
              if $self->debuglevel( 1, 'insteon' );
        }
    }
    else {
        $clear_message = $self->SUPER::_process_message( $p_setby, %msg );
    }
    return $clear_message;
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
        'enable night only'       => "$object_name->enable_night_only(1)",
        'disable night only'      => "$object_name->enable_night_only(0)",
        'enable on only mode'     => "$object_name->enable_on_only(1)",
        'disable on only mode'    => "$object_name->enable_on_only(0)",
        'enable all motion mode'  => "$object_name->enable_all_motion(1)",
        'disable all motion mode' => "$object_name->enable_all_motion(0)",
        'enable LED'              => "$object_name->set_led_brightness(255)",
        'disable LED'             => "$object_name->set_led_brightness(0)"
    );
    return \%voice_cmds;
}

=back

=head2 AUTHOR

Kevin Robert Keegan, Gregg Limming

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=head1 B<Insteon::MotionSensor_Battery>

=head2 SYNOPSIS

Configuration:

Currently the object can only be defined in the user code.

In user code:

   use Insteon::MotionSensor_Battery;
   $motion_battery = new Insteon::MotionSensor_Battery($motion);

Where $motion is the Motion Sensor device you wish to monitor.

=head2 DESCRIPTION

This basic class creates a simple object that displays the current battery voltage
as its state.  This is helpful if you want to be able to view the battery level
through a web page.  This type of battery level tracking is only available for
Motion Sensor Version 2 devices.

This objects state will be updated based on interval defined for C<set_query_timer()>
in the parent B<Insteon::MotionSensor> object.

Once created, you can tie_events directly to this object rather than using the 
battery_low_event code in the parent B<Insteon::MotionSensor> object.

=head2 INHERITS

L<Generic_Item|Generic_Item>

=head2 METHODS

=over

=cut

package Insteon::MotionSensor_Battery;
use strict;

@Insteon::MotionSensor_Battery::ISA = ('Generic_Item');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    my $root = $parent->get_root();
    bless $self, $class;
    $$root{battery_object} = $self;
    return $self;
}

=item C<set_receive()>

Handles state updates provided by the parent object.

=cut

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head2 AUTHOR

Kevin Robert Keegan

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=head1 B<Insteon::MotionSensor_Light_level>

=head2 SYNOPSIS

Configuration:

Currently the object can only be defined in the user code.

In user code:

   use Insteon::MotionSensor_Light_Level;
   $motion_light_level = new Insteon::MotionSensor_Light_Level($motion);

Where $motion is the Motion Sensor device you wish to monitor.

=head2 DESCRIPTION

This basic class creates a simple object that displays the current light level
as its state.  This is helpful if you want to be able to view the light level
through a web page.  This type of light level tracking is only available for
Motion Sensor Version 2 devices.

This objects state will be updated based on interval defined for C<set_query_timer()>
in the parent B<Insteon::MotionSensor> object.

Once created, you can tie_events directly to this object rather than using the 
C<light_level_low_event> and C<light_level_high_event> code in the parent 
B<Insteon::MotionSensor> object.

=head2 INHERITS

L<Generic_Item|Generic_Item>

=head2 METHODS

=over

=cut

package Insteon::MotionSensor_Light_Level;
use strict;

@Insteon::MotionSensor_Light_Level::ISA = ('Generic_Item');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    my $root = $parent->get_root();
    bless $self, $class;
    $$root{light_level_object} = $self;
    return $self;
}

=item C<set_receive()>

Handles state updates provided by the parent object.

=cut

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head2 INI PARAMETERS

None.

=head2 AUTHOR

Kevin Robert Keegan

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=head1 B<Insteon::TriggerLinc>

=head2 SYNOPSIS

Configuration:
	
In user code:

   use Insteon::TriggerLinc;
   $trigger = new Insteon::TriggerLinc('12.34.56:01',$myPLM);

In items.mht:

   INSTEON_TRIGGERLINC, 12.34.56:01, $trigger, $trigger_group

=head2 DESCRIPTION

Provides support for Insteon TriggerLinc devices.  These are relatively simple
devices that provide open and closed messages but not much else. Other than the 
awake time, there are no other software configurable options.

NOTE: There is a hardware configurable option which allows ON messages to be sent
as group 1 and OFF messages to be sent as group 2.  If you enable this function
you will likely want to define and link the group 2 object by replacing ":01" 
with ":02" in the above examples.

=head3 Link Management

As battery operated devices, these devices are generally asleep.  If you want
MH to manage the links on these devices you need to wake them up, generally this
involves holding down the set button until the light flashes.

Alternatively, if you set the awake time sufficiently high MH will be able to 
initiate a communication with these devices for that many seconds after there
is activity (open/close) from these devices.  This of course comes at the 
expense of additional battery usage.

=head2 INHERITS

L<Insteon::BaseDevice|Insteon::BaseInsteon/Insteon::BaseDevice>

=head2 METHODS

=over

=cut

package Insteon::TriggerLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::TriggerLinc::ISA = ('Insteon::BaseDevice');

my %message_types = (%Insteon::BaseDevice::message_types);

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::BaseDevice( $p_deviceid, $p_interface );
    $$self{message_types} = \%message_types;
    bless $self, $class;
    $$self{is_responder} = 0;
    $$self{is_deaf}      = 1;
    return $self;
}

=item C<set_awake_time([0-255 seconds])>

Sets the amount of time, in seconds, that the TriggerLinc will remain "awake" 
after sending a command.  While awake, the device can be queried by MH such as 
with scan link table or sync links.

=cut

sub set_awake_time {
    my ( $self, $awake ) = @_;
    $awake = sprintf( "%02x", $awake );
    my $root  = $self->get_root();
    my $extra = '000102' . $awake . '0000000000000000000000';
    $$root{_ext_set_get_action} = "set";
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $root,
        'extended_set_get', $extra );
    $root->_send_cmd($message);
    return;
}

=item C<get_extended_info()>

Requests the status of various settings on the device.  Currently this is only
used to obtain the awake time.  If the device is awake, the awake time setting 
will be printed to the log.

=cut

sub get_extended_info {
    my ( $self, $no_retry ) = @_;
    my $root  = $self->get_root();
    my $extra = '000100000000000000000000000000';
    $$root{_ext_set_get_action} = "get";
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $root,
        'extended_set_get', $extra );
    if ($no_retry) {
        $message->retry_count(1);
    }
    $root->_send_cmd($message);
    return;
}

=item C<_process_message()>

Checks for and handles unique TriggerLinc messages. 
All other messages are transferred to L<Insteon::BaseObject::_process_message()|Insteon::BaseInsteon/Insteon::BaseObject>.

=cut

sub _process_message {
    my ( $self, $p_setby, %msg ) = @_;
    my $clear_message = 0;
    my $root          = $self->get_root();
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
        main::print_log(
            "[Insteon::TriggerLinc] Extended Set/Get ACK Received for "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        if ( $$self{_ext_set_get_action} eq 'set' ) {
            main::print_log("[Insteon::TriggerLinc] Clearing active message")
              if $self->debuglevel( 1, 'insteon' );
            $clear_message = 1;
            $$self{_ext_set_get_action} = undef;
            $self->_process_command_stack(%msg);
        }
    }
    elsif ( $msg{command} eq "extended_set_get" && $msg{is_extended} ) {
        if ( substr( $msg{extra}, 0, 6 ) eq "000001" ) {
            $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );

            #D3 = Awake Time;
            my $awake = ( hex( substr( $msg{extra}, 6, 2 ) ) );
            main::print_log( "[Insteon::TriggerLinc] The awake seconds "
                  . "for device "
                  . $self->get_object_name
                  . " is set to: "
                  . $awake );
            $clear_message = 1;
            $self->_process_command_stack(%msg);
        }
        else {
            main::print_log( "[Insteon::TriggerLinc] WARN: Corrupt Extended "
                  . "Set/Get Data Received for "
                  . $self->get_object_name )
              if $self->debuglevel( 1, 'insteon' );
        }
    }
    else {
        $clear_message = $self->SUPER::_process_message( $p_setby, %msg );
    }
    return $clear_message;
}

=back

=head2 INI PARAMETERS

None.

=head2 AUTHOR

Kevin Robert Keegan

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;
