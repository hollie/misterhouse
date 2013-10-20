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
    	$valve--;
    	set_valve $irrigation "0$valve", "on";
    }

Turning off a valve:
	
    $v_valve_off = new Voice_Cmd "Turn off valve [1,2,3,4,5,6,7,8]";
    if (my $valve = state_now $v_valve_off) {
    	$valve--;
    	set_valve $irrigation "0$valve", "off";
    }

Requesting valve status:
	
    $v_valve_status = new Voice_Cmd "Request valve status";
    if (state_now $v_valve_status) {
    	poll_valve_status $irrigation;
    }

=head2 DESCRIPTION

Provides basic support for the EzFlora (aka EzRain) sprinkler controller.

=head2 INHERITS

L<Insteon::BaseDevice|Insteon::BaseInsteon/Insteon::BaseDevice>, 
L<Insteon::DeviceController|Insteon::BaseInsteon/Insteon::DeviceController>

=head2 METHODS

=over

=cut

use strict;
use Insteon::BaseInsteon;

package Insteon::Irrigation;

@Insteon::Irrigation::ISA = ('Insteon::BaseDevice','Insteon::DeviceController');

our %message_types = (
	%Insteon::BaseDevice::message_types,
	sprinkler_control => 0x44,
	sprinkler_valve_on => 0x40,
	sprinkler_valve_off => 0x41,
	sprinkler_program_on => 0x42,
	sprinkler_program_off => 0x43,
	sprinkler_timers_request => 0x45
);

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

=item C<new()>

Instantiates a new object.

=cut

sub new {
   my ($class, $p_deviceid, $p_interface) = @_;

   my $self = new Insteon::BaseDevice($p_deviceid,$p_interface);
   bless $self, $class;
   $$self{active_valve_id} = undef;
   $$self{active_program_number} = undef;
   $$self{program_is_running} = undef;
   $$self{pump_enabled} = undef;
   $$self{valve_is_running} = undef;
   $self->restore_data('active_valve_id', 'active_program_number', 'program_is_running', 'pump_enabled', 'valve_is_running');
   $$self{message_types} = \%message_types;
   return $self;
}

=item C<poll_valve_status()>

Sends a message to the device requesting the valve status.  The response from the
device is printed to the log and stores the result in memory. 

=cut

sub poll_valve_status {
   my ($self) = @_;
   my $subcmd = '02';
   my $message = new Insteon::InsteonMessage('insteon_send', $self, 'sprinkler_control', $subcmd);
   $self->_send_cmd($message);
   return;
}

=item C<set_valve(valve_id, valve_state)>

Used to directly control valves.  Valve_id is a two digit number 00-07, 
valve_state may be on or off.

=cut

sub set_valve {
   my ($self, $valve_id, $state) = @_;
   my $subcmd = $valve_id;
   my $cmd = undef;
   if ($state eq 'on') {
      $cmd = 'sprinkler_valve_on';
   } elsif ($state eq 'off') {
      $cmd = 'sprinkler_valve_off';
   }
   unless ($cmd and $subcmd) {
      &::print_log("Insteon::Irrigation] ERROR: You must specify a valve number and a valid state (ON or OFF)")
          if $self->debuglevel();
      return;
   }
   my $message = new Insteon::InsteonMessage('insteon_send', $self, $cmd, $subcmd);
   $self->_send_cmd($message);
   return;
}

=item C<set_program(program_id, proggram_state)>

Used to directly control programs.  Program_id is a two digit number 00-03, 
valve_state may be on or off.

=cut

sub set_program {
   my ($self, $program_id, $state) = @_;
   my $subcmd = $program_id;
   my $cmd = undef;
   if ($state eq 'on') {
      $cmd = 'sprinkler_program_on';
   } elsif ($state eq 'off') {
      $cmd = 'sprinkler_program_off';
   }
   unless ($cmd and $subcmd) {
      &::print_log("Insteon::Irrigation] ERROR: You must specify a program number and a valid state (ON or OFF)")
          if $self->debuglevel();
      return;
   }
   my $message = new Insteon::InsteonMessage('insteon_send', $self, $cmd, $subcmd);
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

Sends a request to the device asking for it to respond with the current timers. 
It does not appear that there is code to interpret the response provided by the 
device.

=cut

sub get_timers() {
   my ($self) = @_;
   my $cmd = 'sprinkler_timers_request';
   my $subcmd = 0x1;
   my $message = new Insteon::InsteonMessage('insteon_ext_send', $self, $cmd, $subcmd);
   $self->_send_cmd($message);
   return;
}

=item C<_is_info_request()>

Used to intercept and handle unique EZFlora messages, all others are passed on
to C<Insteon::BaseObject::_is_info_request()|Insteon::BaseInsteon/Insteon::BaseObject>.

=cut

sub _is_info_request {
   my ($self, $cmd, $ack_setby, %msg) = @_;
   my $is_info_request = 0;
   if ($cmd eq 'sprinkler_control'
        or $cmd eq 'sprinkler_valve_on'
        or $cmd eq 'sprinkler_valve_off'
        or $cmd eq 'sprinkler_program_on'
        or $cmd eq 'sprinkler_program_off') {
      $is_info_request = 1;
      my $val = hex($msg{extra});
      &::print_log("[Insteon::Irrigation] Processing data for $cmd with value: $val") if $self->debuglevel();
      $$self{'active_valve_id'} = ($val & 7) + 1;
      $$self{'active_program_number'} = (($val >> 3) & 3) + 1;
      $$self{'program_is_running'} = ($val >> 5) & 1;
      $$self{'pump_enabled'} = ($val >> 6) & 1;
      $$self{'valve_is_running'} = ($val >> 7) & 1;
      &::print_log("[Insteon::Irrigation] active_valve_id: $$self{'active_valve_id'},"
        . " valve_is_running: $$self{'valve_is_running'}, active_program: $$self{'active_program_number'},"
        . " program_is_running: $$self{'program_is_running'}, pump_enabled: $$self{'pump_enabled'}") if $self->debuglevel();
   }
   else {
      #Check if this was a generic info_request
      $is_info_request = $self->SUPER::_is_info_request($cmd, $ack_setby, %msg);
   }
   return $is_info_request;

}

=item C<request_status()>

This does nothing and returns 0, it prevents a request_status message, which the
device does not support, from being sent to the device.

=cut

# Overload methods we don't use, but would otherwise cause Insteon traffic.
sub request_status { return 0 }

=back

=head2 AUTHOR

Gregg Liming <gregg@limings.net>
David Norwood <dnorwood2@yahoo.com>
Evan P. Hall <evan@netmagic.net>
Kevin Robert Keegan

=head2 SEE ALSO

L<http://www.simplehomenet.com/Downloads/EZRain%20Command%20Set.pdf>,
L<http://www.simplehomenet.com/Downloads/EZFlora%20Command%20Set.pdf>

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;