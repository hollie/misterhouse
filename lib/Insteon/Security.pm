
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
	if (not defined($self->get_idle_time) or $self->get_idle_time > 1) {
		&::print_log("[Insteon_Device] " . $self->get_object_name()
			. "::set_receive($p_state, $p_setby)") if $main::Debug{insteon};
		$self->set_receive($p_state,$p_setby);
	} else {
		&::print_log("[Insteon_Device] " . $self->get_object_name()
			. "::set_receive($p_state, $p_setby) deferred due to repeat within 1 second")
			if $main::Debug{insteon};
	}
	return;
}

sub is_responder
{
   return 0;
}

1