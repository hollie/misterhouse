
package Insteon::RemoteLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::RemoteLinc::ISA = ('Insteon::BaseDevice','Insteon::DeviceController');

my %message_types = (
	%Insteon::BaseDevice::message_types,
	bright => 0x15,
	dim => 0x16,
	extended_set_get => 0x2e
);

sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::BaseDevice($p_deviceid,$p_interface);
        $$self{message_types} = \%message_types;
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
		&::print_log("[Insteon::RemoteLinc] " . $self->get_object_name()
			. "::set_receive($p_state, $setby_name)") if $main::Debug{insteon};
		$self->set_receive($p_state,$p_setby);
	} else {
		&::print_log("[Insteon::RemoteLinc] " . $self->get_object_name()
			. "::set_receive($p_state, $setby_name) deferred due to repeat within 1 second")
			if $main::Debug{insteon};
	}
	return;
}

sub set_awake_time {
	my ($self, $awake) = @_;
	$awake = sprintf("%02x", $awake);
	my $root = $self->get_root();
	my $extra = '000102' . $awake . '0000000000000000000000';
	$$root{_ext_set_get_action} = "set";
	my $message = new Insteon::InsteonMessage('insteon_ext_send', $root, 'extended_set_get', $extra);
	$root->_send_cmd($message);
	return;
}

sub get_extended_info {
	my ($self) = @_;
	my $root = $self->get_root();
	my $extra = '000100000000000000000000000000';
	$$root{_ext_set_get_action} = "get";
	my $message = new Insteon::InsteonMessage('insteon_ext_send', $root, 'extended_set_get', $extra);
	$root->_send_cmd($message);
	return;
}

sub _process_message {
	my ($self,$p_setby,%msg) = @_;
	my $clear_message = 0;
	if ($msg{command} eq 'link_cleanup_report'){
		#Queue an get_extended_info request
		$self->get_extended_info();
	}
	if ($msg{command} eq "extended_set_get" && $msg{is_ack}){
		$self->default_hop_count($msg{maxhops}-$msg{hopsleft});
		#If this was a get request don't clear until data packet received
		main::print_log("[Insteon::RemoteLinc] Extended Set/Get ACK Received for " . $self->get_object_name) if $main::Debug{insteon};
		if ($$self{_ext_set_get_action} eq 'set'){
			main::print_log("[Insteon::RemoteLinc] Clearing active message") if $main::Debug{insteon};
			$clear_message = 1;
			$$self{_ext_set_get_action} = undef;
			$self->_process_command_stack(%msg);	
		}
	}
	elsif ($msg{command} eq "extended_set_get" && $msg{is_extended}) {
		if (substr($msg{extra},0,6) eq "000001") {
			$self->default_hop_count($msg{maxhops}-$msg{hopsleft});
			#D10 = Battery; 
			main::print_log("[Insteon::RemoteLinc] The battery level ".
				"for device ". $self->get_object_name . " is: ".
				hex(substr($msg{extra}, 20, 2)));
			$clear_message = 1;
			$self->_process_command_stack(%msg);
		} else {
			main::print_log("[Insteon::RemoteLinc] WARN: Corrupt Extended "
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

1