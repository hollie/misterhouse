=begin comment

INITIAL CONFIGURATION
In user code:

   use Insteon::IOLinc;
   $io_device = new Insteon::IOLinc('12.34.56',$myPLM);

In items.mht:

INSTEON_IOLINC, 12.34.56, io_device, io_group

Where commands sent to io_device control the relay, however commands received
from io_device represent the sensor state..

EXAMPLE USAGE

Turning on a relay:

   $io_device->set('on');

Turning off a relay:

   $io_device->set('off');

Requesting sensor status: 

   $io_device->request_sensor_status();

The IOLinc is a strange device in that commands sent to it control one aspect
of the device, but commands received from it are from another aspect of the
device.

Print the Current Device Settings to the log:
   $io_device->get_operating_flag();

LINKING

As a result of the IOLinc's oddities, when the IOLinc is set as a controller
of another device, that other device will be controlled by the sensor state.
However, when the IOLinc is set as a responder in a link, the relay of the
IOLinc will change with the commands sent by the controller.

STATE REPORTED IN MisterHouse

MisterHouse objects are only designed to hold the state of a single aspect.  As a 
result of the IOLinc's oddities, the $io_device defined using the examples above
will track the state of the relay only.  The state of the sensor can be obtained
using the C<request_sensor_status()> command.

One more oddity is that using the "set" button on the side of the device to 
change the state of the relay, will cause MH to perceive this as a change in 
the state of the sensor, thus placing the sensor and relay objects out of sync.

SENSOR STATE CHILD OBJECT

To create a device that directly tracks the state of the sensor, you can use 
the following code to create a generic child object.  The state of the child
object will reflect the state of the sensor and it will be automatically updated
as long as the IOLinc is linked to the PLM.  Tie_events can be used on this
child object.  However, if you want to directly link an obect to the sensor
be sure to use the normal SCENE_MEMBER code in your mht file with the IOLinc
defined as the controller.

User Code:

   $io_device_sensor = new Insteon::IOLinc_sensor($io_device);

Where $io_device is the parent device defined above.

NOTES

This module works with the Insteon IOLinc device from Smarthome.  The EZIO device
uses a different set of commands and this code will offer only limited, if any
support at all, for EZIO devices.

The state that the relay is in when the device is linked to the PLM matters if
you are using relay mode Momentary_A.

BUGS

The relay state will not be accurate if you are using a momentary mode.

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
	$self->restore_data('momentary_time');
	$$self{momentary_timer} = new Timer;
	return $self;
}

sub set
{
	my ($self, $p_state, $p_setby, $p_respond) = @_;
	#Commands sent by the IOLinc itself represent the sensor
	#Commands sent by MH to IOLinc represent the relay
	if (ref $p_setby && $p_setby->isa('Insteon::BaseObject') && $p_setby->equals($self)){
		::print_log("[Insteon::IOLinc] Received ". $self->get_object_name
			. " sensor " . $p_state . " message.");
		if (ref $$self{child_sensor}){
			$$self{child_sensor}->set_receive($p_state, $p_setby, $p_respond);
		}
	}
	else {
		my $link_state = &Insteon::BaseObject::derive_link_state($p_state);
		$self->Insteon::BaseDevice::set($link_state, $p_setby, $p_respond);
		#$$self{momentary_timer}->set(int($$self{momentary_time/10), '$self->Generic_Item::set('off')');
	}
	return;
}

sub request_sensor_status 
{
	my ($self, $requestor) = @_;
	$$self{child_status_request_pending} = $self->group;
	$$self{m_status_request_pending} = ($requestor) ? $requestor : 1;
	my $message = new Insteon::InsteonMessage('insteon_send', $self, 'status_request', '01');
	$self->_send_cmd($message);
}

sub _is_info_request
{
	my ($self, $cmd, $ack_setby, %msg) = @_;
	my $is_info_request = 0;
	my $parent = $self->get_root();
	if ($$parent{child_status_request_pending}) {
		$is_info_request++;
		my $child_state = &Insteon::BaseObject::derive_link_state(hex($msg{extra}));
		&::print_log("[Insteon::IOLinc] received status for " .
			$self->get_object_name . "sensor of: $child_state "
			. "hops left: $msg{hopsleft}") if $main::Debug{insteon};
		$ack_setby = $$self{child_sensor} if ref $$self{child_sensor};
		if (ref $$self{child_sensor}){
			$$self{child_sensor}->set_receive($child_state, $ack_setby);
		}
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
	my $pending_cmd = ($$self{_prior_msg}) ? $$self{_prior_msg}->command : $msg{command};
	my $ack_setby = (ref $$self{m_status_request_pending}) ? $$self{m_status_request_pending} : $p_setby;
	if ($msg{is_ack} && $self->_is_info_request($pending_cmd,$ack_setby,%msg)) {
		$clear_message = 1;
		$$self{m_status_request_pending} = 0;
		$self->_process_command_stack(%msg);
	}	
	elsif ($msg{command} eq "extended_set_get" && $msg{is_ack}){
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
	$$self{momentary_time} = $momentary_time;
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
		$$self{momentary_time} = 0;
	}
	#Momentary A must be on for any Momentary setting
	elsif (lc($relay_mode) eq 'momentary_a'){
		$parent->set_operating_flag('momentary_b_off');
		$parent->set_operating_flag('momentary_c_off');
		$parent->set_operating_flag('momentary_a_on');
	}
	elsif (lc($relay_mode) eq 'momentary_b'){
		$parent->set_operating_flag('momentary_a_on');
		$parent->set_operating_flag('momentary_c_off');
		$parent->set_operating_flag('momentary_b_on');
	}
	elsif (lc($relay_mode) eq 'momentary_c'){
		$parent->set_operating_flag('momentary_a_on');
		$parent->set_operating_flag('momentary_b_off');
		$parent->set_operating_flag('momentary_c_on');
	}
	return;
}

package Insteon::IOLinc_sensor;
use strict;

@Insteon::IOLinc_sensor::ISA = ('Generic_Item');

sub new {
	my ($class, $parent) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	$$self{parent} = $parent;
	$$self{parent}{child_sensor} = $self;
	return $self;
}

sub set_receive {
	my ($self, $p_state, $p_setby, $p_respond) = @_;
	$self->SUPER::set($p_state, $p_setby, $p_respond);
}


1;
=back
=cut
