
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
	::print_log("[Insteon::RemoteLinc] Set low battery level to ".
		$$root{low_battery_level}." volts.");
	return;
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
