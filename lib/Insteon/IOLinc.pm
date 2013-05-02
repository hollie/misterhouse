=begin comment

INITIAL CONFIGURATION
In user code:

   use Insteon::IOLinc;
   $io_device = new Insteon::IOLinc('12.34.56',$myPLM);

In items.mht:

INSTEON_IOLINC, 12.34.56:01, io_device, io_group
INSTEON_IOLINC, 12.34.56:02, io_device_sensor, io_group

Where io_device is the relay and io_device_sensor is the sensor

BUGS


EXAMPLE USAGE

Creating the object:
   use Insteon::IOLinc;
   $io_device = new Insteon::IOLinc('12.34.56:01',$myPLM);
   $io_device_sensor = new Insteon::IOLinc('12.34.56:02',$myPLM);

Turning on a relay:


Turning off a relay:


Requesting sensor status:


NOTES

This module works with the Insteon IOLinc device from Smarthome

=over
=cut

use strict;
use Insteon::BaseInsteon;

package Insteon::IOLinc;

@Insteon::IOLinc::ISA = ('Insteon::BaseDevice', 'Insteon::DeviceController');

sub new {
	my ($class, $p_deviceid, $p_interface) = @_;
	my $self = new Insteon::BaseDevice($p_deviceid, $p_interface);
	bless $self, $class;
	if ($self->group ne '02' && !$self->is_root){
		::print_log("[Insteon::IOLinc] Warning IOLincs with more than "
			. " 1 input and 1 output are not yet supported by this code.");
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
	else {
		$is_info_request = $self->SUPER::_is_info_request($cmd, $ack_setby, %msg);
	}
	return $is_info_request;
}


1;
=back
=cut
