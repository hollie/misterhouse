
=head1 B<Insteon::SynchroLinc>

=head2 SYNOPSIS

In user code:

   use Insteon::SynchroLinc;

In items.mht:

    INSTEON_SYNCHROLINC, AA.BB.CC, Washing_Machine, Appliances

=head2 DESCRIPTION

Provides support for the SynchroLinc Controller.  The SynchroLinc allows MH to
know the state of a non-insteon device.  The state of this device is determined
by monitoring the wattage used by the device.  In order to trigger an ON state
the wattage usage must be above a defined trigger wattage.  The device will
continue to be reported as ON as long as the wattage remains above this trigger.
Once the wattage drops below the trigger, the device is reported as OFF.

The trigger wattage can be set programatically using C<set_trigger>.  
Alternatively, if you are unsure about how much wattage the device in question
uses, you can use the manual calibration routine outlined in the user manual for
the SynchroLinc.  After completing this calibration, you can retreive the
calibrated trigger setting by calling C<request_parameters>.  Do pay attention
to the notes in the manual concerning how the calibration is performed and the
resulting 25% correction performed.

In order to prevent rapid oscillations between ON and OFF, the Synchrolinc
includes two parameters, the threshold and delay, which can be programmed using
C<set_threshold> and <set_delay>.  See the notes concerning these two routines 
below for a description of how the threshold and delay parameters work.

It is recommended that you link the Synchrolinc to MH first and perform all of 
the necessary calibration and testing before attempting to link the device
directly to other Insteon devices.

=head3 Group 2 Objects

The Synchrolinc contains a feature which allows you to link devices seperately
to the ON and OFF commands.  Normally, when only the group 1 device is defined,
the Synchrolinc will send ON and OFF commands for this device.  However, if a
group 2 :02 device is defined and linked, the device will only send ON commands.
An ON command on group 1 signifies that the high state is active and an ON
command on group 2 signifies that the low state is active.

I would recommend using this feature with caution.  Without a device to test
with, I can't be sure how the device will handle link requests.  Nor am I sure
how to reset the device back to the default arrangement.  Deleting the group
2 definition and running C<delete_orphans> may achieve the desired result, or
it may require a factory reset.

=head2 INHERITS

L<Insteon::BaseDevice|Insteon::BaseInsteon/Insteon::BaseDevice>

=head2 METHODS

=over

=cut

use strict;
use Insteon::BaseInsteon;

package Insteon::SynchroLinc;

@Insteon::SynchroLinc::ISA = ('Insteon::BaseDevice');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;
    my $self = new Insteon::BaseDevice( $p_deviceid, $p_interface );
    bless $self, $class;
    $self->restore_data( 'trigger_watts', 'delay_seconds', 'threshold_watts' );
    return $self;
}

=item C<_set_parameters($trigger_bytes,$threshold_byte,$delay_byte)>

An internal routine which writes the trigger, threshold, and delay values to the
device. If a value is not specified, the cached value in MH will be used.

=cut

sub _set_parameters {
    my ( $self, $trigger_watts, $threshold_watts, $delay_seconds ) = @_;

    #Set values from cache if not passed
    $threshold_watts = $$self{threshold_watts} if $threshold_watts eq '';
    $trigger_watts   = $$self{trigger_watts}   if $trigger_watts eq '';
    $delay_seconds   = $$self{delay_seconds}   if $delay_seconds eq '';

    #Convert to bytes
    my $trigger_bytes  = sprintf( '%04X', ( $trigger_watts * 2 ) );
    my $delay_byte     = sprintf( '%02X', ( $delay_seconds / .15 ) );
    my $threshold_byte = sprintf( '%02X', ( $threshold_watts * 2 ) );

    #Send the set command
    $$self{_ext_set_get_action} = 'set';
    my $extra = "000002" . $trigger_bytes . $delay_byte . $threshold_byte;
    $extra .= '0' x ( 30 - length $extra );
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $self,
        'extended_set_get', $extra );
    $self->_send_cmd($message);
}

=item C<request_parameters()>

Queries the device for the current trigger, threshold, and delay parameters.
These reported parameters are printed to the log and cached in MH.

=cut

sub request_parameters {
    my ($self) = @_;
    $$self{_ext_set_get_success_callback} =
      $self->get_object_name . "->print_parameters();";
    $self->_get_parameters();
}

=item C<print_parameters()>

Prints the current cached parameters from the device to the print log.

=cut

sub print_parameters {
    my ($self) = @_;
    ::print_log( "[Insteon::SynchroLinc] Parameters obtained from "
          . $self->get_object_name
          . ". Trigger = $$self{trigger_watts} watts, "
          . "Delay = $$self{delay_seconds} seconds, Threshold = "
          . "$$self{threshold_watts} watts." );
}

=item C<_get_parameters()>

An internal routine which queries the device to obtain the current parameters.
The reported parameters are cached within MH.

=cut

sub _get_parameters {
    my ($self) = @_;
    $$self{_ext_set_get_action} = 'get';
    my $extra .= '0' x 30;
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $self,
        'extended_set_get', $extra );
    $self->_send_cmd($message);
}

=item C<set_trigger(trigger_watts)>

Sets the wattage required in order to trigger the Synchrolinc.

trigger_watts = is an decimal number between 0 and 1800 in .5 increments.

If an incorrect value is selected, this routine will chose the closest valid
value.

=cut

sub set_trigger {
    my ( $self, $trigger_watts ) = @_;

    #Adjust to valid range
    $trigger_watts = 0    if $trigger_watts < 0;
    $trigger_watts = 1800 if $trigger_watts > 1800;

    #Round to nearest .5 Value
    $trigger_watts = int( ( $trigger_watts * 2 ) + 0.5 ) / 2;
    ::print_log( "[Insteon::SynchroLinc] Setting Trigger to "
          . $trigger_watts
          . " watts." );

    #Set Callback
    $$self{_ext_set_get_success_callback} =
      $self->get_object_name . "->_set_parameters($trigger_watts,'','');";
    $self->_get_parameters();
}

=item C<set_delay(delay_seconds)>

Sets the number of seconds for the delay on the Synchrolinc.  It isn't clear to
me exactly how this works.  It is meant to provide some protection against 
rapid changes between on and off states.  I that the synchrolinc continuously
monitors the wattage, and that no off or on signal will be sent unless the 
wattage has been in that state continuously for the delay period of time.  This
means that the higher this value, the longer the lag will be between the change
in state and when MH is actually informed of it.

Also see threshold for preventing rapid oscillations of the device.

delay_seconds = is an decimal number between 0.15 to 38.25 seconds in .15 
second increments.

If an incorrect value is selected, this routine will chose the closest valid
value.

=cut

sub set_delay {
    my ( $self, $delay_seconds ) = @_;

    #Adjust to valid range
    $delay_seconds = 0.15  if $delay_seconds < 0.15;
    $delay_seconds = 38.25 if $delay_seconds > 38.25;

    #Round to nearest .15 Value
    $delay_seconds = int( ( $delay_seconds / 0.15 ) + 0.5 ) * .15;
    ::print_log( "[Insteon::SynchroLinc] Setting Delay to "
          . $delay_seconds
          . " seconds." );

    #Set Callback
    $$self{_ext_set_get_success_callback} =
      $self->get_object_name . "->_set_parameters('','',$delay_seconds);";
    $self->_get_parameters();
}

=item C<set_threshold(threshold_watts)>

The threshold, in combination with delay, is a means to prevent the device from
oscillating back and forth between the on and off states.  Once trigger has been
exceeded, the wattage must drop threshold_watts below the trigger before the off
signal is sent.

threshold_watts = is an decimal number between 0 to 127.5 watts in 0.5 watt
increments.

If an incorrect value is selected, this routine will chose the closest valid
value.

=cut

sub set_threshold {
    my ( $self, $threshold_watts ) = @_;

    #Adjust to valid range
    $threshold_watts = 0     if $threshold_watts < 0;
    $threshold_watts = 127.5 if $threshold_watts > 127.5;

    #Round to nearest .5 Value
    $threshold_watts = int( ( $threshold_watts * 2 ) + 0.5 ) / 2;
    ::print_log( "[Insteon::SynchroLinc] Setting Threshold to "
          . $threshold_watts
          . " watts." );

    #Set Callback
    $$self{_ext_set_get_success_callback} =
      $self->get_object_name . "->_set_parameters('',$threshold_watts,'');";
    $self->_get_parameters();
}

=item C<_process_message()>

Handles incoming messages from the device which are unique to the SynchroLinc, 
specifically this handles the setting and getting of the various paramters, 
all other responses are handed off to the C<Insteon::BaseObject::_process_message()>.

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
        ::print_log( "[Insteon::SynchroLinc] Extended Set/Get ACK Received for "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        if ( $$self{_ext_set_get_action} eq 'set' ) {
            ::print_log("[Insteon::SynchroLinc] Clearing active message.")
              if $self->debuglevel( 1, 'insteon' );
            $clear_message = 1;
            $$self{_ext_set_get_action} = undef;
            $self->_process_command_stack(%msg);
        }
    }
    elsif ( $msg{command} eq "extended_set_get" && $msg{is_extended} ) {
        if ( substr( $msg{extra}, 0, 6 ) eq "000001" ) {
            $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );
            main::print_log( "[Insteon::SynchroLinc] Extended Set/Get Data "
                  . "Received for "
                  . $self->get_object_name )
              if $self->debuglevel( 1, 'insteon' );

            #D3+D4 = trigger, D5 = delay, D6 = threshold
            $$self{trigger_watts} = hex( substr( $msg{extra}, 6, 4 ) ) / 2;
            $$self{delay_seconds} =
              sprintf( "%.2f", hex( substr( $msg{extra}, 10, 2 ) ) * .15 );
            $$self{threshold_watts} = hex( substr( $msg{extra}, 12, 2 ) ) / 2;

            #All Done
            $clear_message = 1;
            $$self{_ext_set_get_action} = undef;
            $self->_process_command_stack(%msg);

            #If Callback exists, execute it
            if ( $$self{_ext_set_get_success_callback} ) {

                package main;
                eval( $$self{_ext_set_get_success_callback} );
                &::print_log(
                    "[Insteon::SynchroLinc] Error in Get/Set Callback: " . $@ )
                  if $@ and $self->debuglevel( 1, 'insteon' );

                package Insteon::SynchroLinc;
                $$self{_ext_set_get_success_callback} = undef;
            }
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
    my %voice_cmds  = ( %{ $self->SUPER::get_voice_cmds } );
    if ( $self->is_root ) {
        %voice_cmds = (
            %{ $self->SUPER::get_voice_cmds },
            'request parameters' => "$object_name->request_parameters()"
        );
    }
    return \%voice_cmds;
}

=back

=head2 AUTHOR

Kevin Robert Keegan

=head2 SEE ALSO

L<Indigo Forum Post|http://www.perceptiveautomation.com/userforum/viewtopic.php?f=7&t=7236&start=30>
- Indigo developers likely have access to Dev Notes, so code samples are likely
accurate.

L<Smart Home Forum Post|https://www.smarthome.com/forum/topic.asp?TOPIC_ID=10340>
- A post on the Smart Home user forum. Some of the conclusions here seem
incorrect, however they do provide logs of a few communications.

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=head1 B<Insteon::iMeter>

=head2 SYNOPSIS

In user code:

   use Insteon::iMeter;
   $iMeter = new Insteon::iMeter('AA.BB.CC');

In items.mht:

    INSTEON_IMETER, AA.BB.CC, iMeter, Sensors

=head2 DESCRIPTION

Provides support for the iMeter Solo power consumption monitor.  The
iMeter is the Insteon version of the Kill-o-Watt power monitor.  It can provide
readings of both instantaneous power usage and accumulated usage over time.

The iMeter is a very simple device that can really only act as a responder that
does nothing.  The iMeter will NOT broadcast changes in electricity usage.
Instead, you must query the iMeter each time you want to know the state of the
electrcity usage.  These updates can be requested by setting the state of the
device to 'refresh' or calling the 'request status' voice command. As a result, 
you really can't use the iMeter as a controller for anything, unless you are 
willing to accept long delays.

The state of this device is the last reading of the instantaneous energy usage
in watts.  You can use the C<tie_event> routine to trigger an action when the
usage is above a certain threshold.

The iMeter luckily has internal memory for storing the accumulated usage.  This
memory will log the usage continually, even if you do not query the device for
long periods of time.  This accumulated usage can be printed to the log using
the C<log_accumulated_usage> routine.  Similarly this value can be obtained
in user_code using the C<get_accumulated_usage> routine.

If you want to display the accumulated usage in the web interface, you can
create a Generic_Item object to track the accumulated usage using the following
sample code, assuming you have defined your iMeter object as $iMeter:

    $iMeter_Accum = new Generic_Item();
    $iMeter->tie_event('$iMeter_Accum->set($iMeter->get_accumulated_usage)');

You can also create items that display the cost of your electricity usage using
the following examples:

    $iMeter_Accum_Cost = new Generic_Item();
    $iMeter->tie_event('$iMeter_Accum_Cost->set("$" . $iMeter->get_accumulated_usage)*.15');

=head2 INHERITS

L<Insteon::BaseDevice|Insteon::BaseInsteon/Insteon::BaseDevice>

=head2 METHODS

=over

=cut

use strict;
use Insteon::BaseInsteon;

package Insteon::iMeter;

@Insteon::iMeter::ISA = ('Insteon::BaseDevice');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;
    my $self = new Insteon::BaseDevice( $p_deviceid, $p_interface );
    bless $self, $class;

    # include refresh as state so it appears in web interface
    $self->set_states('refresh');
    $self->restore_data('accumenergy');
    return $self;
}

=item C<set(state[,setby,response])>

The iMeter really can't be set to anything, but refreshing the power and usage
seems like the most common thing that would be done.  As such, setting the state
to refresh will cause MH to query these values.

=cut

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( lc($p_state) eq 'refresh' ) {
        $self->request_status();
    }
    elsif ( $p_setby ne $self ) {
        ::print_log(
            "[Insteon::iMeter] failed state validation with state=$p_state");
    }
}

=item C<request_status([requestor])>

Requests the current status of the device and calls C<set()> on the response.  
This will trigger tied_events.

This is called by setting state to 'refresh' or running request status voice
command

=cut

sub request_status {
    my ( $self, $requestor ) = @_;
    my $extra = '00';
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, 'imeter_query',
        $extra );
    $self->_send_cmd($message);
    return;
}

=item C<_process_message()>

Handles incoming messages from the device which are unique to the iMeter, 
specifically this handles the C<request_status()> response for the device, 
all other responses are handed off to the C<Insteon::BaseObject::_process_message()>.

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
    elsif ( $msg{command} eq "imeter_query" && $msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );

        #Don't clear until data packet received
        ::print_log(
            "[Insteon::iMeter] ACK Received for " . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
    }
    elsif ( $msg{command} eq "imeter_query" && $msg{is_extended} ) {
        if ( substr( $msg{extra}, 0, 2 ) eq "00" ) {

            # Power is D7-D8; Accumulated Energy is D9-D12.
            # CRC16 Signature is D13-D14, we currently ignore this check
            my ( $load, $intenergy ) = $msg{extra} =~ m/^.{14}(.{4})(.{8})/;
            $$self{'power'}       = hex($load);
            $intenergy            = hex($intenergy);
            $$self{'accumenergy'} = 0;

            # Best I can tell, the highest byte is set to FF or 255 when the device
            # is reset.  So value must be less than 254*256*256*256=4261412864 in
            # order for it to be valid.
            if ( $intenergy < 4261412864 ) {

                # 1 Accumulated energy is equal to: 65535 watts/AC Cycle.
                # 65535 is the maximum value of a 16 bit number.
                $$self{'accumenergy'} = sprintf( "%.2f",
                    ( $intenergy * 65535 ) / ( 1000 * 60.0 * 60.0 * 60.0 ) );
            }
            ::print_log( "[Insteon::iMeter] received status for "
                  . $self->get_object_name
                  . ". Current Usage: $$self{'power'}/watts "
                  . "Accumulated Usage: $$self{'accumenergy'}/kWh Hops left: $msg{hopsleft}"
            );

            #Forced setby to be $Self as nothing can control iMeter
            $self->Generic_Item::set( $$self{'power'}, $self );

            #Clear message from message queue
            $clear_message = 1;
            $self->_process_command_stack(%msg);
        }
    }
    else {
        $clear_message = $self->SUPER::_process_message( $p_setby, %msg );
    }
    return $clear_message;
}

=item C<log_accumulated_usage()>

Prints the accumulated usage to the print log.  You likely want to force MH to
query the accumulated usage before printing by setting the state to 'refresh'
or calling the 'request status' voice command.

=cut

sub log_accumulated_usage {
    my ($self) = @_;
    ::print_log( "[Insteon::iMeter] Current values for "
          . $self->get_object_name
          . ". Current Usage: $$self{'power'}/watts "
          . "Accumulated Usage: $$self{'accumenergy'}/kWh" );
    return;
}

=item C<get_accumulated_usage()>

Returns the accumulated usage.  You likely want to force MH to
query the accumulated usage before printing by setting the state to 'refresh'
or calling the 'request status' voice command.

=cut

sub get_accumulated_usage {
    my ($self) = @_;
    return $$self{'accumenergy'};
}

=item C<reset_accumulated_usage()>

Resets the accumulated usage on the device to 0.

=cut

sub reset_accumulated_usage {
    my ($self) = @_;
    $$self{'accumenergy'} = 0;
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, 'imeter_reset',
        '00' );
    $self->_send_cmd($message);
    return $$self{'accumenergy'};
}

=item C<get_power()>

Returns the last read power value usage.  There is no logging function for power
because it is viewable in the state of the device.  Indeed this function is
fuplicative of simply calling $self->state.

=cut

sub get_power {
    my ($self) = @_;
    return $$self{'power'};
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
    my %voice_cmds  = ( %{ $self->SUPER::get_voice_cmds } );
    if ( $self->is_root ) {
        %voice_cmds = (
            %{ $self->SUPER::get_voice_cmds },
            'log accumulated usage' => "$object_name->log_accumulated_usage()",
            'reset accumulated usage' =>
              "$object_name->reset_accumulated_usage()",
        );
    }
    return \%voice_cmds;
}

=back

=head2 AUTHOR

Kevin Robert Keegan,
Brian Rudy

=head2 SEE ALSO

L<iMeter Dev Notes|http://www.insteon.com/pdf/2423A1_iMeter_Solo_20110211.pdf>

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;
