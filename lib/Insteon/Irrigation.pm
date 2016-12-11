
=head1 B<Insteon::Irrigation>

=head2 SYNOPSIS

In user code:

   use Insteon::Irrigation;
   $irrigation = new Insteon::Irrigation('12.34.56', $myPLM);

In items.mht:

    INSTEON_IRRIGATION, 12.34.56, irrigation, Irrigation

Creating the object:
	
    use Insteon::Irrigation;
    $irrigation = new Insteon::Irrigation('12.34.56', $myPLM);

Turning on a valve:
	
    $v_valve_on = new Voice_Cmd "Turn on valve [1,2,3,4,5,6,7,8]";
    if (my $valve = state_now $v_valve_on) {
    	set_valve $irrigation "$valve", "on";
    }

Turning off a valve:
	
    $v_valve_off = new Voice_Cmd "Turn off valve [1,2,3,4,5,6,7,8]";
    if (my $valve = state_now $v_valve_off) {
    	set_valve $irrigation "$valve", "off";
    }

Requesting valve status:
	
    $v_valve_status = new Voice_Cmd "Request valve status";
    if (state_now $v_valve_status) {
    	request_status $irrigation;
    }

=head2 DESCRIPTION

Provides basic support for the EzFlora (aka EzRain) sprinkler controller.

=head2 INHERITS

L<Insteon::BaseDevice|Insteon::BaseInsteon/Insteon::BaseDevice>

=head2 METHODS

=over

=cut

use strict;
use Insteon::BaseInsteon;

package Insteon::Irrigation;

@Insteon::Irrigation::ISA = ('Insteon::BaseDevice');

our %message_types = (
    %Insteon::BaseDevice::message_types,
    sprinkler_status         => 0x27,
    sprinkler_control        => 0x44,
    sprinkler_valve_on       => 0x40,
    sprinkler_valve_off      => 0x41,
    sprinkler_program_on     => 0x42,
    sprinkler_program_off    => 0x43,
    sprinkler_timers_request => 0x45
);

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::BaseDevice( $p_deviceid, $p_interface );
    bless $self, $class;
    $$self{active_valve_id}       = undef;
    $$self{active_program_number} = undef;
    $$self{program_is_running}    = undef;
    $$self{pump_enabled}          = undef;
    $$self{valve_is_running}      = undef;
    $self->restore_data(
        'active_valve_id',    'active_program_number',
        'program_is_running', 'pump_enabled',
        'valve_is_running',   'timer_0',
        'timer_1',            'timer_2',
        'timer_3',            'timer_4'
    );
    $$self{message_types} = \%message_types;
    $$self{status_timer}  = new Timer;
    return $self;
}

=item C<request_status()>

Sends a message to the device requesting the valve status.  The response from the
device is printed to the log and stores the result in memory. 

=cut

sub request_status {
    my ( $self, $requestor ) = @_;
    my $subcmd = '02';
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, 'sprinkler_control',
        $subcmd );
    $self->_send_cmd($message);
    return;
}

#Deprecated Routine Name
sub poll_valve_status {
    my ($self) = @_;
    $self->request_status();
}

=item C<set_valve(valve_id, valve_state)>

Used to directly control valves.  Valve_id may be 1-8, valve_state may be on 
or off.

=cut

sub set_valve {
    my ( $self, $valve_id, $state ) = @_;
    my $subcmd = sprintf( "%02X", $valve_id - 1 );
    my $cmd = undef;
    if ( lc($state) eq 'on' ) {
        $cmd = 'sprinkler_valve_on';
    }
    elsif ( lc($state) eq 'off' ) {
        $cmd = 'sprinkler_valve_off';
    }
    unless ( $cmd and $subcmd ) {
        &::print_log(
            "Insteon::Irrigation] ERROR: You must specify a valve number and a valid state (ON or OFF)"
        ) if $self->debuglevel( 1, 'insteon' );
        return;
    }
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, $cmd, $subcmd );
    $self->_send_cmd($message);
    return;
}

=item C<set_program(program_id, proggram_state)>

Used to directly control programs.  Program_id may be 1-4, program_state may be 
on or off.

=cut

sub set_program {
    my ( $self, $program_id, $state ) = @_;
    my $subcmd = sprintf( "%02X", $program_id - 1 );
    my $cmd = undef;
    if ( lc($state) eq 'on' ) {
        $cmd = 'sprinkler_program_on';
    }
    elsif ( lc($state) eq 'off' ) {
        $cmd = 'sprinkler_program_off';
    }
    unless ( $cmd and $subcmd ) {
        &::print_log(
            "Insteon::Irrigation] ERROR: You must specify a program number and a valid state (ON or OFF)"
        ) if $self->debuglevel( 1, 'insteon' );
        return;
    }
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, $cmd, $subcmd );
    $self->_send_cmd($message);
    return;
}

=item C<get_active_valve_id()>

Returns the active valve number identified by the device in response to the last 
C<poll_valve_status()> request.

=cut

sub get_active_valve_id() {
    my ($self) = @_;
    return $$self{'active_valve_id'};
}

=item C<get_valve_is_running()>

Returns true if the active valve identified by the device in response to the last 
C<poll_valve_status()> request is running.

=cut

sub get_valve_is_running() {
    my ($self) = @_;
    return $$self{'valve_is_running'};
}

=item C<get_active_program_number()>

Returns the active program number identified by the device in response to the last 
C<poll_valve_status()> request.

=cut

sub get_active_program_number() {
    my ($self) = @_;
    return $$self{'active_program_number'};
}

=item C<get_program_is_running()>

Returns true if the active program identified by the device in response to the last 
C<poll_valve_status()> request is running.

=cut

sub get_program_is_running() {
    my ($self) = @_;
    return $$self{'program_is_running'};
}

=item C<get_pump_enabled()>

Returns true if valve 8 is set to be a pump.  In this setup, valve 8 will also 
turn on when any other valve is enabled.  Generally used if you have some sort
of water pump that runs to provide water to your sprinklers.

=cut

sub get_pump_enabled() {
    my ($self) = @_;
    return $$self{'pump_enabled'};
}

=item C<get_timers()>

Sends a request to the device asking for it to respond with the times for the
all programs.  The times are then cached in MisterHouse.

The EZFlora does not update MisterHouse when a timer has expired.  As a result,
MisterHouse has to query the device to periodically determine what is going on.
If MisterHouse has an understanding of the timers, it can query the device at
the proper times.

=cut

sub get_timers() {
    my ( $self, $program ) = @_;
    $program = 0 unless ( defined $program );
    my $cmd = 'sprinkler_timers_request';
    my $subcmd = sprintf( "%02X", $program );
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, $cmd, $subcmd );
    $self->_send_cmd($message);
    return;
}

=item C<set_timers(program, valve1, valve2, valve3, valve4, valve5, valve6, 
    valve7, valve8)>

Sets the timers for the program.  Program 0 is the manual/default timers that
are used if you just turn on a single timer.  It is HIGHLY recommented that you
set the manual/default timer to the most number of minutes that you would ever
need for that zone.  This will prevent accidental overwatering or flooding
should something happen to MisterHouse.

Each valve time is specified in minutes with 255 being the maximum.

By default, each valve is set to 30 minutes for each program.

=cut

sub set_timers() {
    my ( $self, $program, @time_array ) = @_;

    #Command is reused in different format for EXT msgs
    my $cmd = 'sprinkler_valve_on';
    my $extra = sprintf( "%02X", $program );
    foreach my $time (@time_array) {

        #Store values in MH Cache
        $self->_valve_timer( $program, $time );

        #compose message data
        $extra .= sprintf( "%02X", $time );
    }
    $extra .= '0' x ( 30 - length $extra );
    my $message =
      new Insteon::InsteonMessage( 'insteon_ext_send', $self, $cmd, $extra );
    $self->_send_cmd($message);
    return;
}

=item C<_is_info_request()>

Used to intercept and handle unique EZFlora messages, all others are passed on
to C<Insteon::BaseObject::_is_info_request()|Insteon::BaseInsteon/Insteon::BaseObject>.

=cut

sub _is_info_request {
    my ( $self, $cmd, $ack_setby, %msg ) = @_;
    my $is_info_request = 0;
    if (   $cmd eq 'sprinkler_control'
        or $cmd eq 'sprinkler_valve_on'
        or $cmd eq 'sprinkler_valve_off'
        or $cmd eq 'sprinkler_program_on'
        or $cmd eq 'sprinkler_program_off' )
    {
        $is_info_request = 1;
        $self->_process_status( $msg{extra} );
    }
    else {
        #Check if this was a generic info_request
        $is_info_request =
          $self->SUPER::_is_info_request( $cmd, $ack_setby, %msg );
    }
    return $is_info_request;

}

sub _process_status {
    my ( $self, $val ) = @_;
    $val = hex($val);
    $$self{'active_valve_id'} = ( $val & 7 ) + 1;
    $$self{'active_program_number'} = ( ( $val >> 3 ) & 3 ) + 1;
    $$self{'program_is_running'}    = ( $val >> 5 ) & 1;
    $$self{'pump_enabled'}          = ( $val >> 6 ) & 1;
    $$self{'valve_is_running'}      = ( $val >> 7 ) & 1;
    &::print_log(
            "[Insteon::Irrigation] active_valve_id: $$self{'active_valve_id'},"
          . " valve_is_running: $$self{'valve_is_running'}, active_program: $$self{'active_program_number'},"
          . " program_is_running: $$self{'program_is_running'}, pump_enabled: $$self{'pump_enabled'}"
    );

    # Set a timer to check the status of the device after we expect the timer
    # for the current valve to run out.
    if ( $$self{'valve_is_running'} ) {
        my $action  = $self->get_object_name . "->_timer_query()";
        my $program = 0;
        $program = $$self{'active_program_number'}
          if ( $$self{'program_is_running'} );
        my $time = $self->_valve_timer( $program, $$self{'active_valve_id'} );
        $time = ( $time * 60 ) + 5;    #Add 5 seconds to allow things to happen.
             #Only set the timer if it is something worthwhile ie actually set.
        $$self{status_timer}->set( $time, $action ) if $time > 5;
    }

    # Set child objects if they exist
    my $valve   = $$self{'active_valve_id'};
    my $program = $$self{'active_program_number'};

    # Loop valves, updating state of all that have changed
    for ( my $v = 1; $v <= 8; $v++ ) {
        my $valve_status = 'off';
        $valve_status = 'on' if ( $$self{'valve_is_running'} && $v == $valve );
        if ( ref $$self{ 'child_valve_' . $v }
            && ( lc( $$self{ 'child_valve_' . $v }->state ) ne $valve_status ) )
        {
            $$self{ 'child_valve_' . $v }->set_receive($valve_status);
        }
    }

    # Loop programs, updating state of all that have changed
    for ( my $p = 1; $p <= 4; $p++ ) {
        my $program_status = 'off';
        $program_status = 'on'
          if ( $$self{'program_is_running'} && $p == $program );
        if ( ref $$self{ 'child_program_' . $p }
            && (
                lc( $$self{ 'child_program_' . $p }->state ) ne
                $program_status ) )
        {
            $$self{ 'child_program_' . $p }->set_receive($program_status);
        }
    }
}

# Used by the timer to check the status of the device.  Will only run if MH
# believes that a valve is still on
sub _timer_query {
    my ($self) = @_;
    $self->request_status() if ( $$self{'valve_is_running'} );
}

=item C<_process_message()>

Handles incoming messages from the device which are unique to this device, 
specifically this handles the C<get_timers()> response for the device, 
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
    elsif ( $msg{type} eq 'broadcast' && $msg{cmd_code} eq '27' ) {

        #These are the broadcast status messages from the device.
        $self->_process_status( $msg{dev_attribs} );
        ::print_log("[Insteon::Irrigation] Received broadcast status update.")
          if $self->debuglevel( 2, 'insteon' );
        $self->_process_command_stack(%msg);
    }

    # The device uses cmd 0x41 differently depending on STD or EXT Msgs
    elsif ( $msg{command} eq "sprinkler_valve_off" && $msg{is_extended} ) {
        my $program = hex( substr( $msg{extra}, 0, 2 ) );
        for ( my $i; $i <= 8; $i++ ) {
            my $time = hex( substr( $msg{extra}, $i * 2, 2 ) );
            $self->_valve_timer( $program, $i, $time );
        }

        if ( $program < 4 ) {
            $self->get_timers( $program + 1 );
        }
        else {
            my $output =
                "[Insteon::Irrigation] The timers for "
              . $self->get_object_name
              . " are:\n";
            $output .= "      Program 0:      Program 1:      Program 2:      "
              . "Program 3:      Program 4:\n";
            for ( my $i_v = 1; $i_v <= 8; $i_v++ ) {
                $output .= '  ';
                for ( my $i_p = 0; $i_p <= 4; $i_p++ ) {
                    $output .= "     Valve $i_v:"
                      . sprintf( "% 3d", $self->_valve_timer( $i_p, $i_v, ) );
                }
                $output .= "\n";
            }
            ::print_log($output);
        }

        #Clear message from message queue
        $clear_message = 1;
        $self->_process_command_stack(%msg);
    }
    else {
        $clear_message = $self->SUPER::_process_message( $p_setby, %msg );
    }
    return $clear_message;
}

# Used to store and retreive the valve times from MH cache
sub _valve_timer {
    my ( $self, $program, $valve, $time ) = @_;
    if ( defined $time ) {

        # Not the ideal way to store this, but restore_data can't handle hashes
        # or arrays. So we store the times in a string similar to the msg payload.
        substr( $$self{ 'timer_' . $program }, ( ( $valve - 1 ) * 3 ), 3 ) =
          sprintf( "%03d", $time );
    }
    return
      int( substr( $$self{ 'timer_' . $program }, ( ( $valve - 1 ) * 3 ), 3 ) );
}

=item C<enable_pump(boolean)>

If set to true, this will treat valve 8 as a water pump.  This will make valve
8 turn on whenever any other valve is turned on.  Setting to false, returns
valve 8 to a normal sprinkler valve

=cut

sub enable_pump {
    my ( $self, $enable ) = @_;
    my $subcmd = '08';
    if ($enable) {
        $subcmd = '07';
        ::print_log("[Insteon::Irrigation] Enabling valve 8 pump feature.");
    }
    else {
        ::print_log(
            "[Insteon::Irrigation] Setting valve 8 to act as regular valve.");
    }
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, 'sprinkler_control',
        $subcmd );
    $self->_send_cmd($message);
    return;
}

=item C<enable_status(boolean)>

If set to true, this will cause the device to send a status message whenever
a valve changes status during a program.  If not set, MH will not be informed
of the status of each of the valves during a program.

These messages appear to only be available if you put your PLM in monitor mode.
At the moment, there does not appear to be any downside to running MH with your
PLM in monitor mode, but do this at your own risk.

=cut

sub enable_status {
    my ( $self, $enable ) = @_;
    my $subcmd = '0A';
    if ($enable) {
        $subcmd = '09';
        ::print_log("[Insteon::Irrigation] Enabling valve status messages.");
    }
    else {
        ::print_log("[Insteon::Irrigation] Disabling valve status messages.");
    }
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, 'sprinkler_control',
        $subcmd );
    $self->_send_cmd($message);
    return;
}

=back

=head2 AUTHOR

Gregg Liming <gregg@limings.net>
David Norwood <dnorwood2@yahoo.com>
Evan P. Hall <evan@netmagic.net>
Kevin Robert Keegan

=head2 SEE ALSO

L<http://www.simplehomenet.com/Downloads/EZRain%20Command%20Set.pdf>,
L<http://www.simplehomenet.com/Downloads/EZFlora%20Command%20Set.pdf>

=head1 Irrigation_valve

=head1 DESCRIPTION

A child object for an irrigation valve.

=head1 SYNOPSIS

When defining the children, you need to identify who their parent is.

        $valve_1 = new Insteon::Irrigation_valve($irrigation, 1);
        $valve_1->set(ON); #Turn ON the valve for the default time
        $valve_1->set('5 min'); #Turn ON the valve for 5 minutes only
        $valve_1->set_states('off', '5 min', 'on'); #set the states to display

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Irrigation_valve;
use strict;

@Insteon::Irrigation_valve::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent, $valve ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    $$self{valve}  = $valve;
    @{ $$self{states} } = ( 'Off', '5 min', '15 min', ' 30 min', 'On' );
    $$self{parent}{ 'child_valve_' . $valve } = $self;
    $$self{state_timer} = new Timer;
    return $self;
}

=item C<set()>

Use just like the set function for any other descendant of a Generic_Item.

Accepts on and off commands and will parse the number portion out of any command
into the number of minutes.  So '5 min' will cause the valve to turn ON for 5
minutes.

NOTE: The maximum amount of time the valve can be turned on for is determined
by the default setting, contained in program 0.  Turning on the child object
for longer than the default setting will result in the valve running for the
default length and then turning off.

=cut

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( $p_state =~ /(on|off)/i ) {
        $p_state = $1;
        ::print_log( "[Insteon::Irrigation] Received request to set "
              . $self->get_object_name
              . " $p_state." );
        $$self{parent}->set_valve( $$self{valve}, $p_state );
    }
    elsif ( $p_state =~ /(\d+)/ ) {
        $p_state = $1;
        ::print_log( "[Insteon::Irrigation] Received request to set "
              . $self->get_object_name
              . " ON for $p_state minutes." );
        $$self{parent}->set_valve( $$self{valve}, 'on' );

        #Set timer to turn off
        my $action =
            $$self{parent}->get_object_name
          . "->set_valve("
          . $$self{valve}
          . ", 'off')";
        my $time = ( $p_state * 60 );
        $$self{state_timer}->set( $time, $action );
    }
    else {
        ::print_log( "[Insteon::Irrigation] Cannot set "
              . $self->get_object_name
              . " to unknown state of $p_state." );
    }
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    if ( $p_state =~ /off/i ) {

        #Clear any off timers that are outstanding
        $$self{state_timer}->set(0);
    }
    $self->SUPER::set($p_state);
}

=back

=head1 Irrigation_program

=head1 DESCRIPTION

A child object for an irrigation program.

=head1 SYNOPSIS

When defining the children, you need to identify who their parent is.

        $program_1 = new Insteon::Irrigation_program($irrigation, 1);
        $program_1->set(ON); #Turn ON the program

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Irrigation_program;
use strict;

@Insteon::Irrigation_program::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent, $program ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent}  = $parent;
    $$self{program} = $program;
    @{ $$self{states} } = ( 'Off', 'On' );
    $$self{parent}{ 'child_program_' . $program } = $self;
    $$self{state_timer} = new Timer;
    return $self;
}

=item C<set()>

Use just like the set function for any other descendant of a Generic_Item.

Accepts on and off commands.

=cut

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( $p_state =~ /(on|off)/i ) {
        $p_state = $1;
        ::print_log( "[Insteon::Irrigation] Received request to set "
              . $self->get_object_name
              . " $p_state." );
        $$self{parent}->set_program( $$self{program}, $p_state );
    }
    else {
        ::print_log( "[Insteon::Irrigation] Cannot set "
              . $self->get_object_name
              . " to unknown state of $p_state." );
    }
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;
