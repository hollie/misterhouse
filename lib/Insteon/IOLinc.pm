=begin comment

INITIAL CONFIGURATION
In user code:

   use Insteon::IOLinc;
   $io_device = new Insteon::IOLinc('12.34.56:01',$myPLM);
   $io_device_sensor = new Insteon::IOLinc('12.34.56:02',$myPLM);

In items.mht:

INSTEON_IOLINC, 12.34.56:01, io_device, io_group
INSTEON_IOLINC, 12.34.56:02, io_device_sensor, io_group

Where io_device is the relay and io_device_sensor is the sensor.

EXAMPLE USAGE

Turning on a relay:

   $io_device->set('on');

Turning off a relay:

   $io_device->set('off');

Requesting sensor status: 

   $io_device_sensor->request_status();

If the sensor is defined in the user code or mht file as described above, and
linked to MH using the sync_links voice command, the sensor will automatically 
send state changes to MisterHouse whenever its state changes.  In that instance
the request_status command should not be needed.

Print the Current Device Settings to the log:
   $io_device->get_operating_flag();

NOTES

This module works with the Insteon IOLinc device from Smarthome.  The EZIO device
uses a different set of commands and this code will offer only limited, if any
support at all, for EZIO devices.

The state that the relay is in when the device is linked to the PLM matters if
you are using relay mode Momentary_A.  

=over
=cut

use strict;
use Insteon::BaseInsteon;

package Insteon::IOLinc;

@Insteon::IOLinc::ISA = ('Insteon::BaseDevice', 'Insteon::DeviceController');

my %operating_flags = (
   'program_lock_on' => '00',
   'program_lock_off' => '01',
   'led_on_during_tx' => '02',
   'led_off_during_tx' => '03',
   'relay_follows_input_on' => '04',
   'relay_follows_input_off' => '05',
   'momentary_a_on' => '06',
   'momentary_a_off' => '07',
   'led_off' => '08',
   'led_enabled' => '09',
   'key_beep_enabled' => '0a',
   'key_beep_off' => '0b',
   'x10_tx_on_when_off' => '0c',
   'x10_tx_on_when_on' => '0d',
   'invert_sensor_on' => '0e',
   'invert_sensor_off' => '0f',
   'x10_rx_on_is_off' => '10',
   'x10_rx_on_is_on' => '11',
   'momentary_b_on' => '12',
   'momentary_b_off' => '13',
   'momentary_c_on' => '14',
   'momentary_c_off' => '15',
);

my %message_types = (
	%Insteon::BaseDevice::message_types,
	extended_set_get => 0x2e
);

sub new 
{
	my ($class, $p_deviceid, $p_interface) = @_;
	my $self = new Insteon::BaseDevice($p_deviceid, $p_interface);
	$$self{operating_flags} = \%operating_flags;
	$$self{message_types} = \%message_types;
	bless $self, $class;
	if ($self->group ne '02' && !$self->is_root){
		::print_log("[Insteon::IOLinc] Warning IOLincs with more than "
			. " 1 input and 1 output are not yet supported by this code.");
	}
	if ($self->is_root){
		$$self{momentary_time} = 20;
		$$self{relay_linked} = 0;
		$$self{trigger_reverse} = 0;
		$$self{relay_mode} = 'Latching';
	}
	return $self;
}

sub set
{
	my ($self, $p_state, $p_setby, $p_respond) = @_;
	my $link_state = &Insteon::BaseObject::derive_link_state($p_state);
	return $self->Insteon::BaseDevice::set($link_state, $p_setby, $p_respond);
}

sub request_status 
{
	my ($self, $requestor) = @_;
	if (!($self->is_root)) {
		my $parent = $self->get_root();
		$$parent{child_status_request_pending} = $self->group;
		$$self{m_status_request_pending} = ($requestor) ? $requestor : 1;
		my $message = new Insteon::InsteonMessage('insteon_send', $parent, 'status_request', '01');
		$parent->_send_cmd($message);
	} else {
		$self->SUPER::request_status($requestor);
	}
}

sub _is_info_request
{
	my ($self, $cmd, $ack_setby, %msg) = @_;
	my $is_info_request = 0;
	my $parent = $self->get_root();
	if ($$parent{child_status_request_pending}) {
		$is_info_request++;
		my $child_obj = Insteon::get_object($self->device_id, '02');
		my $child_state = &Insteon::BaseObject::derive_link_state(hex($msg{extra}));
		&::print_log("[Insteon::IOLinc] received status for " .
			$child_obj->{object_name} . " of: $child_state "
			. "hops left: $msg{hopsleft}") if $main::Debug{insteon};
		$ack_setby = $$child_obj{m_status_request_pending} if ref $$child_obj{m_status_request_pending};
		$child_obj->SUPER::set($child_state, $ack_setby);
		delete($$parent{child_status_request_pending});
	} 
	elsif ($cmd eq 'get_operating_flags') {
		$is_info_request++;
		my $output = "";
		my $flags = hex($msg{extra});
		$output .= ($flags & 0x01) ? "Program Lock: On; " : "Program Lock: Off; ";
		$output .= ($flags & 0x02) ? "Transmit Led: On; " : "Transmit Led: Off; ";
		$output .= ($flags & 0x04) ? "Relay Linked: On; " : "Relay Linked: Off; ";
		$output .= ($flags & 0x20) ? "X10 Reverse: On; " : "X10 Reverse: Off; ";
		$output .= ($flags & 0x40) ? "Trigger Reverse: On; " : "Trigger Reverse: Off; ";
		if (!($flags & 0x98)){
			$output .= "Latching: On.";
		} else {
			$output .= "Momentary_A: On." if $flags & 0x08;
			$output .= "Momentary_B: On." if $flags & 0x10;
			$output .= "Momentary_C: On." if $flags & 0x80;
		}
		::print_log("[Insteon::IOLinc] Device Settings are: $output");
	} else {
		$is_info_request = $self->SUPER::_is_info_request($cmd, $ack_setby, %msg);
	}
	return $is_info_request;
}

sub _process_message {
	my ($self,$p_setby,%msg) = @_;
	my $clear_message = 0;
	if ($msg{command} eq "extended_set_get" && $msg{is_ack}){
		$self->default_hop_count($msg{maxhops}-$msg{hopsleft});
		#If this was a get request don't clear until data packet received
		main::print_log("[Insteon::IOLinc] Extended Set/Get ACK Received for " . $self->get_object_name) if $main::Debug{insteon};
		if ($$self{_ext_set_get_action} eq 'set'){
			main::print_log("[Insteon::IOLinc] Clearing active message") if $main::Debug{insteon};
			$clear_message = 1;
			$$self{_ext_set_get_action} = undef;
			$self->_process_command_stack(%msg);	
		}
	} 
	elsif ($msg{command} eq "extended_set_get" && $msg{is_extended}) {
		if (substr($msg{extra},0,6) eq "000101") {
			$self->default_hop_count($msg{maxhops}-$msg{hopsleft});
			#D4 = Time; 
			main::print_log("[Insteon::IOLinc] The Momentary Time Setting ".
				"on device ". $self->get_object_name . " is set to: ".
				hex(substr($msg{extra}, 8, 2)) . " tenths of a second.");
			$clear_message = 1;
			$self->_process_command_stack(%msg);
		} else {
			main::print_log("[Insteon::IOLinc] WARN: Corrupt Extended "
				."Set/Get Data Received for ". $self->get_object_name) if $main::Debug{insteon};
		}
	}
	elsif ($msg{command} eq "set_operating_flags" && $msg{is_ack}){
		$self->default_hop_count($msg{maxhops}-$msg{hopsleft});
		main::print_log("[Insteon::IOLinc] Acknowledged flag set for " . $self->get_object_name) if $main::Debug{insteon};
		$clear_message = 1;
		$self->_process_command_stack(%msg);
	}
	else {
		$clear_message = $self->SUPER::_process_message($p_setby,%msg);
	}
	return $clear_message;
}

=item C<set_momentary_time(time)>

$time in tenths of seconds (deciseconds) is the length of time the relay will close when 
a Momentary mode is is selected in C<set_relay_mode>.

Default 20

=cut

sub set_momentary_time 
{
	my ($self, $momentary_time) = @_;
	my $root = $self->get_root();
	if ($momentary_time == 0){
		::print_log("[Insteon::IOLinc] Setting " . $self->get_object_name . 
			" to Latching Relay Mode." ) if $main::Debug{insteon};
	} 
	elsif ($momentary_time <= 255) {
		$momentary_time = 2 if $momentary_time == 1; #Can't set to 1
		::print_log("[Insteon::IOLinc] Setting Momentary Time to $momentary_time " .
			"tenths of a second for " . $self->get_object_name) if $main::Debug{insteon};
	}
	else {
		::print_log("[Insteon::IOLinc] WARN Invalid Momentary Time of $momentary_time " .
			"tenths of a second for " . $self->get_object_name);
	}

	#D2 = 0x06, D3 = deciseconds of time from 0x02-0xFF.  0x00 = Latching?
	my $extra = '000006';
	$extra .= sprintf("%02x", $momentary_time);
	$extra .= '0000000000000000000000';
	$$root{_ext_set_get_action} = "set";
	my $message = new Insteon::InsteonMessage('insteon_ext_send', $root, 'extended_set_get', $extra);
	$root->_send_cmd($message);
	return;
}

=item C<get_momentary_time()>

Prints the device's current momentary time setting to the log.

=cut

sub get_momentary_time 
{
	my ($self) = @_;
	my $root = $self->get_root();
	my $extra = '000000000000000000000000000000';
	$$root{_ext_set_get_action} = "get";
	my $message = new Insteon::InsteonMessage('insteon_ext_send', $root, 'extended_set_get', $extra);
	$root->_send_cmd($message);
	return;
}

=item C<set_relay_linked([0|1])>

If set to 1 whenever the Sensor is On the Relay will be on and whenever the 
Sensor is Off the Relay will be Off.

Default 0

=cut

sub set_relay_linked 
{
	my ($self, $relay_linked) = @_;
	my $parent = $self->get_root();
	if ($relay_linked){
		$parent->set_operating_flag('relay_follows_input_on');
	}
	elsif (defined $relay_linked){
		$parent->set_operating_flag('relay_follows_input_off');
	}
	return;
}

=item C<set_trigger_reverse([0|1])>

If set to 1, it reverses the sensor value so that a closed sensor switch reports its 
state as OFF and an open sensor switch reports its state as ON. 

Default 0

=cut

sub set_trigger_reverse 
{
	my ($self, $trigger_reverse) = @_;
	my $parent = $self->get_root();
	if ($trigger_reverse){
		$parent->set_operating_flag('invert_sensor_on');
	}
	elsif (defined $trigger_reverse){
		$parent->set_operating_flag('invert_sensor_off');
	}
	return;
}

=item C<set_relay_mode([Latching|Momentary_A|Momentary_B|Momentary_C])>

Latching: The relay will remain open or closed until another command is received. 
Momentary time is ignored.

The following modes act differently depending on how the relay is controlled.  
For the following modes, direct ON commands, such as those called from the devices
voice command or those sent using the set function, will close the relay but only 
for the amount of time specified by the momentary time setting.  Direct OFF 
commands can be used to shorten the momentary time, but are otherwise ignored.

However, commands issued from a PLM Scene or from another Insteon Device, through
a defined link, will follow the restrictions described below.

Momentary_A: The relay will close momentarily. If it is Linked while On it will 
respond to On. If it is Linked while Off it will respond to Off.

Momentary_B: Both - On and Off both cause the relay to close momentarily.

Momentary_C: Look at Sensor - If the sensor is On the relay will close momentarily 
when an On command is received. If the sensor is Off the relay will close momentarily 
when an Off command is received.

Default Latching

=cut

sub set_relay_mode 
{
	my ($self, $relay_mode) = @_;
	my $parent = $self->get_root();
	if (lc($relay_mode) eq 'latching'){
		$parent->set_operating_flag('momentary_a_off');
		$parent->set_operating_flag('momentary_b_off');
		$parent->set_operating_flag('momentary_c_off');
	}
	elsif (lc($relay_mode) eq 'momentary_a'){
		$parent->set_operating_flag('momentary_b_off');
		$parent->set_operating_flag('momentary_c_off');
		$parent->set_operating_flag('momentary_a_on');
	}
	elsif (lc($relay_mode) eq 'momentary_b'){
		$parent->set_operating_flag('momentary_a_off');
		$parent->set_operating_flag('momentary_c_off');
		$parent->set_operating_flag('momentary_b_on');
	}
	elsif (lc($relay_mode) eq 'momentary_c'){
		$parent->set_operating_flag('momentary_a_off');
		$parent->set_operating_flag('momentary_b_off');
		$parent->set_operating_flag('momentary_c_on');
	}
	return;
}

1;
=back
=cut
