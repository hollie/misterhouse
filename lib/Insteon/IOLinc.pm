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
	poll_sensor_status $io_device, '01';
   }

NOTES

This module works with the Insteon IOLinc device from Smarthome

#TODO
 - Should be able to intitialize programs.
=over
=cut

use strict;
use Insteon::BaseInsteon;

package Insteon::IOLinc;

@Insteon::IOLinc::ISA = ('Insteon::BaseDevice','Insteon::DeviceController');

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

=item C<poll_sensor_status($sensor_id)>

Requests the status of a specific sensor which can then be read with 
C<get_sensor_status($sensor_id)>. C<$sensor_id> is the sensor id number which could be in 
the current known range of 00-07.

=cut

sub poll_sensor_status {
   my ($self, $sensor) = @_;
   $sensor = sprintf "%02s", $sensor; #Pad 0 to left if not present
   $$self{'sensor_id'} = $sensor;
   my $message = new Insteon::InsteonMessage('insteon_send', $self, 'sensor_status', $sensor);
   $self->_send_cmd($message);
   return;
}

=item C<set_relay($relay_id)>

Sets the state if the identified relay. C<$relay_id> is the relay id number which could be in 
the current known range of 00-07.

=cut

sub set_relay {
   my ($self, $relay_id, $state) = @_;
   my $cmd = undef;
   if ($state eq 'on') {
      $cmd = 'relay_on';
   } elsif ($state eq 'off') {
      $cmd = 'relay_off';
   }
   unless ($cmd and $relay_id) {
      &::print_log("Insteon::IOLinc] ERROR: You must specify a relay number and a valid state (ON or OFF)")
          if $main::Debug{insteon};
      return;
   }
   my $message = new Insteon::InsteonMessage('insteon_send', $self, $cmd, $relay_id);
   $self->_send_cmd($message);
   return;
}

=item C<get_sensor_status($sensor_id)>

Returns the current known hex value of the sensor identified by C<$sensor_id>.

=cut

sub get_sensor_status() {
   my ($self, $sensor) = @_;
   $sensor = sprintf "%02s", $sensor; #Pad 0 to left if not present
   my @sensors = split(/,/, $sensor);
   if ($sensor <= @sensors){
   	return $sensors[$sensor];
   }
   else {
   	&::print_log("[Insteon::IOLinc] Error no data for Sensor_Id: $sensor");
   }
}

sub _is_info_request {
   my ($self, $cmd, $ack_setby, %msg) = @_;
   my $is_info_request = 0;
   if ($cmd eq 'sensor_status' && $$self{'sensor_id'}) {
      $is_info_request = 1;
      my @sensors = split(/,/, $$self{'sensor_status'});
      $sensors[$$self{'sensor_id'}] = $msg{extra};
      $$self{'sensor_status'} = join(',', @sensors);
      &::print_log("[Insteon::IOLinc] Received Status: $msg{extra} for Sensor_Id: $$self{'sensor_id'}") if $main::Debug{insteon};
      $$self{'sensor_id'} = undef;
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
=back
=cut
