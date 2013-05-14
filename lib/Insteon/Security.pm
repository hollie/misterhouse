
package Insteon::MotionSensor;

use strict;
use Insteon::BaseInsteon;

@Insteon::MotionSensor::ISA = ('Insteon::DeviceController','Insteon::BaseDevice');

sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::BaseDevice($p_deviceid,$p_interface);
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
	::print_log("[Insteon::MotionSensor] Set battery timer to ".
		$$root{query_timer}." minutes");
	return;
}

=item C<set_low_battery_level([0.0])>

Only available for Motion Sensor Version 2 models.

If the battery level falls below this voltage, the C<battery_low_event()> 
command is run.  The theoretical maximum voltage of the battery is 9.0 volts.
Although practical experience shows it to be closer to 8.5 volts. The 
recommended low battery setting is (7.0??) volts.

Setting to 0 will prevent any low battery events from occuring.  

This setting will be saved between MisterHouse reboots.

=cut

sub set_low_battery_level {
	my ($self, $level) = @_;
	my $root = $self->get_root();
	$$root{low_battery_level} = sprintf("%.2f", $level);
	::print_log("[Insteon::MotionSensor] Set low battery level to ".
		$$root{low_battery_level}." volts.");
	return;
}

=item C<battery_low_event([cmd_to_eval])>

Only available for Motion Sensor Version 2 models.

If the battery level falls below the voltage defined by C<set_low_battery_level()> 
this command is evaluated.  Works very similar to a C<Generic_Item::tie_event()>
eval.

Example:

   $motion->battery_low_event('speak "Warning, Motion battery is low."');

See C<test_tie.pl> for more examples.

This setting will be saved between MisterHouse reboots.

=cut

sub battery_low_event {
	my ($self, $eval) = @_;
	my $root = $self->get_root();
	$$root{low_battery_event} = $eval;
	::print_log("[Insteon::MotionSensor] Set low battery event.");
	return;
}

=item C<set_low_light_level([0-255])>

Only available for Motion Sensor Version 2 models.

If the light level falls below this level, the C<light_low_event()> 
command is run.  The light level can range between 1 and 255.

Setting to 0 will prevent any low light level events from occuring.  

This setting will be saved between MisterHouse reboots.

=cut

sub set_low_light_level {
	my ($self, $level) = @_;
	my $root = $self->get_root();
	$$root{low_light_level} = sprintf("%02d", $level);
	::print_log("[Insteon::MotionSensor] Set low light level to ".
		$$root{low_light_level}.".");
	return;
}

=item C<light_low_event([cmd_to_eval])>

Only available for Motion Sensor Version 2 models.

If the light level falls below the level defined by C<set_low_light_level()> 
this command is evaluated.  Works very similar to a C<Generic_Item::tie_event()>
eval.

Example:

   $motion->light_low_event('speak "Warning, Light level is low."');

See C<test_tie.pl> for more examples.

This setting will be saved between MisterHouse reboots.

=cut

sub light_low_event {
	my ($self, $eval) = @_;
	my $root = $self->get_root();
	$$root{light_low_event} = $eval;
	::print_log("[Insteon::MotionSensor] Set low light event.");
	return;
}

=item C<set_high_light_level([0-255])>

Only available for Motion Sensor Version 2 models.

If the light level falls above this level, the C<light_high_event()> 
command is run.  The light level can range between 1 and 255.

Setting to 0 will prevent any high light level events from occuring.  

This setting will be saved between MisterHouse reboots.

=cut

sub set_high_light_level {
	my ($self, $level) = @_;
	my $root = $self->get_root();
	$$root{high_light_level} = sprintf("%02d", $level);
	::print_log("[Insteon::MotionSensor] Set high light level to ".
		$$root{high_light_level}.".");
	return;
}

=item C<light_high_event([cmd_to_eval])>

Only available for Motion Sensor Version 2 models.

If the light level falls above the level defined by C<set_high_light_level()> 
this command is evaluated.  Works very similar to a C<Generic_Item::tie_event()>
eval.

Example:

   $motion->light_high_event('speak "Warning, Light level is high."');

See C<test_tie.pl> for more examples.

This setting will be saved between MisterHouse reboots.

=cut

sub light_high_event {
	my ($self, $eval) = @_;
	my $root = $self->get_root();
	$$root{light_high_event} = $eval;
	::print_log("[Insteon::MotionSensor] Set high light event.");
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

sub _is_battery_low {
	my ($self, $voltage) = @_;
	my $root = $self->get_root();
	if ($$root{low_battery_level} > 0 && 
		($$root{low_battery_level} > $voltage)) {
		return 1;
	}
	return 0;
}

sub _is_light_level_low {
	my ($self, $level) = @_;
	my $root = $self->get_root();
	if ($$root{low_light_level} > 0 && 
		($$root{low_light_level} > $level)) {
		return 1;
	}
	return 0;
}

sub _is_light_level_high {
	my ($self, $level) = @_;
	my $root = $self->get_root();
	if ($$root{low_light_level} > 0 && 
		($$root{low_light_level} > $level)) {
		return 1;
	}
	return 0;
}

sub _process_message {
	my ($self,$p_setby,%msg) = @_;
	my $clear_message = 0;
	my $root = $self->get_root();
	if ($msg{command} eq 'link_cleanup_report' && $self->_is_query_time_expired){
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
				$voltage . " of 9.0 volts and the light level is".
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
			if ($self->_is_battery_low($voltage)){
				main::print_log("[Insteon::MotionSensor] The battery level ".
					"is below the set threshold running low battery event.");
				package main;
					eval $$root{low_battery_event};
					::print_log("[Insteon::MotionSensor] " . $self->{device}->get_object_name . ": error during low battery event eval $@")
						if $@;
				package Insteon::MotionSensor;
			}
			if ($self->_is_light_level_low($light_level)){
				main::print_log("[Insteon::MotionSensor] The light level ".
					"is below the set threshold running low light event.");
				package main;
					eval $$root{low_light_event};
					::print_log("[Insteon::MotionSensor] " . $self->{device}->get_object_name . ": error during low light level event eval $@")
						if $@;
				package Insteon::MotionSensor;
			}
			if ($self->_is_light_level_high($light_level)){
				main::print_log("[Insteon::MotionSensor] The light level ".
					"is above the set threshold running high light event.");
				package main;
					eval $$root{high_light_event};
					::print_log("[Insteon::MotionSensor] " . $self->{device}->get_object_name . ": error during high light level event eval $@")
						if $@;
				package Insteon::MotionSensor;
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
