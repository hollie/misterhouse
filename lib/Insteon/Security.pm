=head1 B<Insteon::MotionSensor>

=head2 SYNOPSIS

Configuration:

In user code:

   use Insteon::MotionSensor;
   $motion_1 = new Insteon::MotionSensor('12.34.56:01',$myPLM);
   $motion_2_light_level = new Insteon::MotionSensor('12.34.56:02',$myPLM);
   $motion_3_battery_level = new Insteon::MotionSensor('12.34.56:03',$myPLM);

In items.mht:

   INSTEON_MOTIONSENSOR, 12.34.56:01, $motion_1, $motion_group
   INSTEON_MOTIONSENSOR, 12.34.56:02, $motion_2_light_level, $motion_group
   INSTEON_MOTIONSENSOR, 12.34.56:03, $motion_3_battery_level, $motion_group

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

=head3 Battery and Light Level Monitoring Options:

For version 2 devices, there are two ways in which you can monitor the battery 
and light level.  For simplicity, these are referred to as the GROUP and QUERY
method.  Both, either, or neither method may be used.  

For version 1 devices, the GROUP method is the only option.

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
Luckily, a Motion Sensor remains awake for approximatly 4 seconds after it sends
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
with C<tie_event>.

=head2 INHERITS

B<Insteon::BaseDevice>, B<Insteon::DeviceController>

=head2 METHODS

=over

=cut

package Insteon::MotionSensor;

use strict;
use Insteon::BaseInsteon;

@Insteon::MotionSensor::ISA = ('Insteon::DeviceController','Insteon::BaseDevice');

my %message_types = (
	%Insteon::BaseDevice::message_types,
	extended_set_get => 0x2e
);

sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::BaseDevice($p_deviceid,$p_interface);
	$$self{message_types} = \%message_types;
	if ($self->is_root){ 
		$self->restore_data('query_timer', 'last_query_time', 
		'low_battery_level', 'low_battery_event', 'low_light_level',
		'high_light_level', 'low_light_level_event', 'high_light_level_event');
	}
	bless $self,$class;
	return $self;
}

sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;
	return if &main::check_for_tied_filters($self, $p_state);

	# Override any set_with_timer requests
	if ($$self{set_timer}) {
		&Timer::unset($$self{set_timer});
		delete $$self{set_timer};
	}

	# if it can't be controlled (i.e., a responder), then don't send out any signals
	# motion sensors seem to get multiple fast reports; don't trigger on both
        my $setby_name = $p_setby;
        $setby_name = $p_setby->get_object_name() if (ref $p_setby and $p_setby->can('get_object_name'));
	if (not defined($self->get_idle_time) or $self->get_idle_time > 1 or $self->state ne $p_state) {
		&::print_log("[Insteon::MotionSensor] " . $self->get_object_name()
			. "::set_receive($p_state, $setby_name)") if $main::Debug{insteon};
		$self->set_receive($p_state,$p_setby);
	} else {
		&::print_log("[Insteon::MotionSensor] " . $self->get_object_name()
			. "::set_receive($p_state, $setby_name) deferred due to repeat within 1 second")
			if $main::Debug{insteon};
	}
	return;
}

=item C<get_extended_info()>

Only available for Motion Sensor Verion 2 models.

Requests the status of various settings on the device.  Currently this is only
used to obtain the battery and light level.  If the device is awake, the battery
level and light level will be printed to the log.

You likely do not need to directly call this message, rather MisterHouse will issue
this request when it sees activity from the device and the C<set_query_timer()> has 
expired.

=cut

sub get_extended_info {
	my ($self) = @_;
	my $root = $self->get_root();
	my $extra = '000100000000000000000000000000';
	$$root{_ext_set_get_action} = "get";
	my $message = new Insteon::InsteonMessage('insteon_ext_send', $root, 'extended_set_get', $extra);
	$root->_send_cmd($message);
	return;
}

=item C<set_query_timer([minutes])>

Only available for Motion Sensor Version 2 models.

Sets the minimum amount of time between battery and light level requests.  When 
this time expires, Misterhouse will request the battery and light level from 
the device the next time MisterHouse sees activity from the device.  Misterhouse 
will continue to request the battery and light level until it gets a response 
from the device.

Setting to 0 will disable automatic battery and light level requests.  1440 
equals a day.

This setting will be saved between MisterHouse reboots.

=cut

sub set_query_timer {
	my ($self, $minutes) = @_;
	my $root = $self->get_root();
	$$root{query_timer} = sprintf("%u", $minutes);
	::print_log("[Insteon::MotionSensor] Set query timer to ".
		$$root{query_timer}." minutes");
	return;
}

sub _is_query_time_expired {
	my ($self) = @_;
	my $root = $self->get_root();
	if ($$root{query_timer} > 0 && 
		(time - $$root{last_query_time}) > ($$root{query_timer} * 60)) {
		return 1;
	}
	return 0;
}

sub _process_message {
	my ($self,$p_setby,%msg) = @_;
	my $clear_message = 0;
	my $root = $self->get_root();
	if ($msg{type} eq 'cleanup' && $self->_is_query_time_expired){
		#Queue an get_extended_info request
		$self->get_extended_info();
	}
	if ($msg{command} eq "extended_set_get" && $msg{is_ack}){
		$self->default_hop_count($msg{maxhops}-$msg{hopsleft});
		#If this was a get request don't clear until data packet received
		main::print_log("[Insteon::MotionSensor] Extended Set/Get ACK Received for " . $self->get_object_name) if $main::Debug{insteon};
		if ($$self{_ext_set_get_action} eq 'set'){
			main::print_log("[Insteon::MotionSensor] Clearing active message") if $main::Debug{insteon};
			$clear_message = 1;
			$$self{_ext_set_get_action} = undef;
			$self->_process_command_stack(%msg);	
		}
	}
	elsif ($msg{command} eq "extended_set_get" && $msg{is_extended}) {
		if (substr($msg{extra},0,6) eq "000001") {
			$self->default_hop_count($msg{maxhops}-$msg{hopsleft});
			#D11 = Light; D12 = Battery;
			my $voltage = (hex(substr($msg{extra}, 24, 2))/10);
			my $light_level = hex(substr($msg{extra}, 22, 2));
			main::print_log("[Insteon::MotionSensor] The battery level ".
				"for device ". $self->get_object_name . " is: ".
				$voltage . " of 9.0 volts and the light level is ".
				$light_level . " of 255.");
			$$root{last_query_time} = time;
			if (ref $$root{battery_object} && $$root{battery_object}->can('set_receive'))
			{
				$$root{battery_object}->set_receive($voltage, $root);
			}
			if (ref $$root{light_level_object} && $$root{light_level_object}->can('set_receive'))
			{
				$$root{light_level_object}->set_receive($light_level, $root);
			}
			$clear_message = 1;
			$self->_process_command_stack(%msg);
		} else {
			main::print_log("[Insteon::MotionSensor] WARN: Corrupt Extended "
				."Set/Get Data Received for ". $self->get_object_name) if $main::Debug{insteon};
		}
	}
	else {
		$clear_message = $self->SUPER::_process_message($p_setby,%msg);
	}
	return $clear_message;
}

sub is_responder
{
   return 0;
}

=back

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

B<Generic_Item>

=head2 METHODS

=over

=cut

package Insteon::MotionSensor_Battery;
use strict;

@Insteon::MotionSensor_Battery::ISA = ('Generic_Item');

sub new {
	my ($class, $parent) = @_;
	my $self = new Generic_Item();
	my $root = $parent->get_root();
	bless $self, $class;
	$$root{battery_object} = $self;
	return $self;
}

sub set_receive {
	my ($self, $p_state) = @_;
	$self->SUPER::set($p_state);
}

=back

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

B<Generic_Item>

=head2 METHODS

=over

=cut

package Insteon::MotionSensor_Light_Level;
use strict;

@Insteon::MotionSensor_Light_Level::ISA = ('Generic_Item');

sub new {
	my ($class, $parent) = @_;
	my $self = new Generic_Item();
	my $root = $parent->get_root();
	bless $self, $class;
	$$root{light_level_object} = $self;
	return $self;
}

sub set_receive {
	my ($self, $p_state) = @_;
	$self->SUPER::set($p_state);
}

=back

=head2 INI PARAMETERS

Only available for Motion Sensor Verion 2 models.

Requests the status of various settings on the device.  Currently this is only
used to obtain the battery and light level.  If the device is awake, the battery
level and light level will be printed to the log.

You likely do not need to directly call this message, rather MisterHouse will issue
this request when it sees activity from the device and the C<set_query_timer()> has 
expired.

=cut

sub get_extended_info {
	my ($self) = @_;
	my $root = $self->get_root();
	my $extra = '000100000000000000000000000000';
	$$root{_ext_set_get_action} = "get";
	my $message = new Insteon::InsteonMessage('insteon_ext_send', $root, 'extended_set_get', $extra);
	$root->_send_cmd($message);
	return;
}

sub is_responder
{
   return 0;
}

1
