=begin comment

AUTHORS
Gregg Liming <gregg@limings.net>
David Norwood <dnorwood2@yahoo.com>

INITIAL CONFIGURATION
In user code:

   use Insteon_Irrigation;
   $irrigation = new Insteon_Irrigation($myPLM, '12.34.56');

In items.mht:

INSTEON_IRRIGATION, 12.34.56, irrigation, Irrigation, myPLM

BUGS


EXAMPLE USAGE

Creating the object:
   use Insteon_Irrigation;
   $irrigation = new Insteon_Irrigation($myPLM, '12.34.56');

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

NOTES

This module works with the EzFlora (aka EzRain) sprinkler controller, documented
here http://www.simplehomenet.com/Downloads/EZRain%20Command%20Set.pdf


#TODO
 - Should be able to intitialize programs.
=cut

use strict;

package Insteon_Irrigation;

@Insteon_Irrigation::ISA = ('Insteon_Device');


# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

sub new {
   my ($class, $p_interface, $p_deviceid, $p_devcat) = @_;

   my $self = $class->SUPER::new($p_interface, $p_deviceid, $p_devcat);
   bless $self, $class;
   $$self{active_valve_id} = undef;
   $$self{active_program_number} = undef;
   $$self{program_is_running} = undef;
   $$self{pump_enabled} = undef;
   $$self{valve_is_running} = undef;
   $self->restore_data('active_valve_id', 'active_program_number', 'program_is_running', 'pump_enabled', 'valve_is_running');
   return $self;
}

sub poll_valve_status {
   my ($self) = @_;
   my $subcmd = '02';
   $self->_send_cmd(command => 'sprinkler_control', type => 'standard', extra => $subcmd, 'is_synchronous' => 1);
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

sub get_active_valve_id() {
   my ($self) = @_;
   return $$self{'active_valve_id'};
}

sub get_valve_is_running() {
   my ($self) = @_;
   return $$self{'valve_is_running'};
}

sub get_active_program_number() {
   my ($self) = @_;
   return $$self{'active_program_number'};
}

sub get_program_is_running() {
   my ($self) = @_;
   return $$self{'program_is_running'};
}

sub get_pump_enabled() {
   my ($self) = @_;
   return $$self{'pump_enabled'};
}

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
      &::print_log("[Insteon_Irrigation] Processing data for $cmd with value: $val") if $main::Debug{insteon};
      $$self{'active_valve_id'} = ($val & 7) + 1;
      $$self{'active_program_number'} = (($val >> 3) & 3) + 1;
      $$self{'program_is_running'} = ($val >> 5) & 1;
      $$self{'pump_enabled'} = ($val >> 6) & 1;
      $$self{'valve_is_running'} = ($val >> 7) & 1;
      &::print_log("[Insteon_Irrigation] active_valve_id: $$self{'active_valve_id'},"
        . " valve_is_running: $$self{'valve_is_running'}, active_program: $$self{'active_program_number'},"
        . " program_is_running: $$self{'program_is_running'}, pump_enabled: $$self{'pump_enabled'}") if $main::Debug{insteon};
   }

   return $is_info_request;

}


# Overload methods we don't use, but would otherwise cause Insteon traffic.
sub request_status { return 0 }

1;