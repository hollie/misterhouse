=begin comment

AUTHORS
Gregg Liming <gregg@limings.net>

INITIAL CONFIGURATION
In user code:
   $irrigation = new Insteon_Irrigation($myPLM, '12.34.56');

In items.mht:

INSTEON_IRRIGATION, 12.34.56, irr_gateway, Irrigation, plm

BUGS


EXAMPLE USAGE
see TBD for more.

Creating the object:

   $irrigation = new Insteon_Irrigation($myPLM, '12.34.56');


Poll for temperature changes.

   if ( new_minute 5 && $Hour != 2 ) { # Skip the ALDB scanning hour
         $thermostat->poll_temp();
   }


Watch for temperature changes.

   if (state_now $thermostat eq 'temp_change') {
      my $temp = $thermostat->get_temp();
      print "Got new thermostat temperature: $temp\n";
   }

And, you can set the temperature and mode at will...

   if (state_changed $mode_vacation eq 'all') {
      $thermostat->mode('auto');
      $thermostat->heat_setpoint(60);
      $thermostat->cool_setpoint(89);
   }

All of the states that may be set:
   temp_change: Inside temperature changed
      (call get_temp() to get value)
   heat_sp_change: Heat setpoint was changed
      (call get_heat_sp() to get value).
   cool_sp_change: Cool setpoint was changed
      (call get_cool_sp() to get value).
   mode_change: System mode changed
      (call get_mode() to get value).
   fan_mode_change: Fan mode changed
      (call get_fan_mode() to get value).

All of the functions available:
   mode():
      Sets system mode to argument: 'off', 'heat', 'cool', 'auto',
      'program_heat', 'program_cool', 'program_auto'
   poll_mode():
      Causes thermostat to return mode; detected as state change if mode changes
   get_mode():
      Returns the last mode returned by poll_mode().
   fan():
      Sets fan to 'on' or 'auto'
   get_fan_mode():
      Returns the current fan mode (fan_on or fan_auto)
   poll_setpoint():
      Causes thermostat to return setpoint(s); detected as state change if setpoint changes
      Returns setpoint based on mode, auto modes return both heat and cool.
   cool_setpoint():
      Sets a new cool setpoint.
   get_cool_sp():
      Returns the current cool setpoint.
   heat_setpoint():
      Sets a new heat setpoint.
   get_heat_sp():
      Returns the current heat setpoint.
   poll_temp():
      Causes thermostat to return temp; detected as state change
   get_temp():
      Returns the current temperature at the thermostat.


#TODO
 - Manage aldb - should be able to intitialize programs. <- may be overkill
=cut

use strict;

package Insteon_Irrigation;

@Insteon_Irrigation::ISA = ('Insteon_Device');

# override Insteon_Device's message_types

my %message_types = (
   %SUPER::message_types,
   sprinkler_get_valve_status => 0x44
);

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

sub new {
   my ($class, $p_interface, $p_deviceid, $p_devcat) = @_;

   my $self = $class->SUPER::new($p_interface, $p_deviceid, $p_devcat);
   bless $self, $class;
#   $self->restore_data('stuff');
   return $self;
}

sub poll_valve_status {
   my ($self) = @_;
   my $subcmd = '02';
   $self->_send_cmd(command => 'sprinkler_get_valve_status', type => 'standard', extra => $subcmd, 'is_synchronous' => 1);
   return;
}

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
      &::print_log("Insteon_Irrigation] ERROR: You must specify a valve number and a valid state (ON or OFF)")
          if $main::Debug{insteon};
      return;
   }
   $self->_send_cmd(command => $cmd, type => 'standard', extra => $subcmd, 'is_synchronous' => 1);
   return;
}

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
      &::print_log("Insteon_Irrigation] ERROR: You must specify a program number and a valid state (ON or OFF)")
          if $main::Debug{insteon};
      return;
   }
   $self->_send_cmd(command => $cmd, type => 'standard', extra => $subcmd, 'is_synchronous' => 1);
   return;
}

sub _is_info_request {
   my ($self, $cmd, $ack_setby, %msg) = @_;
   my $is_info_request = 0;
   if ($cmd eq 'sprinkler_get_valve_status'
        or $cmd eq 'sprinkler_valve_on'
        or $cmd eq 'sprinkler_valve_off'
        or $cmd eq 'sprinkler_program_on'
        or $cmd eq 'sprinkler_program_off') {
      $is_info_request = 1;
      my $val = $msg{extra};
      &::print_log("[Insteon_Irrigation] Processing data for $cmd with value: $val") if $main::Debug{insteon};
      my $active_valve_id = $val >> 3;
      my $active_program_number = $val >> 2;
      my $program_is_running = $val >> 1;
      my $pump_enabled = $val >> 1;
      my $valve_is_running = $val >> 1;
      &::print_log("[Insteon_Irrigation] active_valve_id: $active_valve_id,"
        . " valve_is_running: $valve_is_running, active_program: $active_program_number,"
        . " program_is_running: $program_is_running, pump_enabled: $pump_enabled") if $main::Debug{insteon};
      # now, do something w/ the above vars--likely putting them into item properties, like:

   }

   return $is_info_request;

}


# Overload methods we don't use, but would otherwise cause Insteon traffic.
sub request_status { return 0 }

1;