=begin comment

INITIAL CONFIGURATION
In user code:

   use Insteon::IOLinc;
   $io_device = new Insteon::IOLinc('12.34.56',$myPLM);

In items.mht:

INSTEON_IOLINC, 12.34.56, io_device, io

BUGS


EXAMPLE USAGE

Creating the object:
   use Insteon::IOLinc;
   $io_device = new Insteon::IOLinc('12.34.56',$myPLM);

Turning on a relay:
   $v_relay_on = new Voice_Cmd "Turn on relay [1,2]";
   if (my $relay = state_now $v_relay_on) {
   	$relay--;
	set_relay $io_device "0$relay", "on";
   }

Turning off a relay:
   $v_relay_on = new Voice_Cmd "Turn off relay [1,2]";
   if (my $relay = state_now $v_relay_off) {
   	$relay--;
	set_relay $io_device "0$relay", "off";
   }

Requesting sensor status:
   $v_sensor_status = new Voice_Cmd "Request sensor [1,2,3,4] status";
   if (state_now $v_sensor_status) {
	poll_sensor_status $io_device;
   }

NOTES

This module works with the Insteon IOLinc device from Smarthome

#TODO
 - Should be able to intitialize programs.
=cut

use strict;
use Insteon::BaseInsteon;

package Insteon::IOLinc;

@Insteon::IOLinc::ISA = ('Insteon::DeviceController','Insteon::BaseDevice');

our %message_types = (
	%Insteon::BaseDevice::message_types,
	relay_on => 0x45,
	relay_off => 0x46,
	sensor_status => 0x4A,
);

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

sub new {
   my ($class, $p_deviceid, $p_interface) = @_;

   my $self = new Insteon::BaseDevice($p_deviceid, $p_interface);
   bless $self, $class;
   $$self{sensor_status} = undef;
   $self->restore_data('sensor_status');
   $$self{message_types} = \%message_types;
   return $self;
}

sub poll_sensor_status {
   my ($self) = @_;
   my $subcmd = '01';
   my $message = new Insteon::InsteonMessage('insteon_send', $self, 'sensor_status', $subcmd);
   $self->_send_cmd($message);
   return;
}

sub set_relay {
   my ($self, $relay_id, $state) = @_;
   my $subcmd = $relay_id;
   my $cmd = undef;
   if ($state eq 'on') {
      $cmd = 'relay_on';
   } elsif ($state eq 'off') {
      $cmd = 'relay_off';
   }
   unless ($cmd and $subcmd) {
      &::print_log("Insteon::IOLinc] ERROR: You must specify a relay number and a valid state (ON or OFF)")
          if $main::Debug{insteon};
      return;
   }
   my $message = new Insteon::InsteonMessage('insteon_send', $self, $cmd, $subcmd);
   $self->_send_cmd($message);
   return;
}

sub get_sensor_status() {
   my ($self) = @_;
   return $$self{'sensor_status'};
}

sub _is_info_request {
   my ($self, $cmd, $ack_setby, %msg) = @_;
   my $is_info_request = 0;
   if ($cmd eq 'sensor_status') {
      $is_info_request = 1;
      my $val = hex($msg{extra});
      &::print_log("[Insteon::IOLinc] Processing data for $cmd with value: $val") if $main::Debug{insteon};
      $$self{'sensor_status'} = $val;
      &::print_log("[Insteon::IOLinc] sensor_status: $$self{'sensor_status'}") if $main::Debug{insteon};
   }
   else {
      #Check if this was a generic info_request
      $is_info_request = $self->SUPER::_is_info_request($cmd, $ack_setby, %msg);
   }
   return $is_info_request;

}


# Overload methods we don't use, but would otherwise cause Insteon traffic.
sub request_status { return 0 }

1;
