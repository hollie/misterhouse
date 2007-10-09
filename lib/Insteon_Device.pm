=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Insteon_Device.pm

Description:
	Generic class implementation of an Insteon Device.

Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	$ip_patio_light = new Insteon_Device($myPLM,"33.44.55");

	$ip_patio_light->set("ON");

Special Thanks to:
	Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Insteon_Device;

@Insteon_Device::ISA = ('Generic_Item');

my %message_types = (
						assign_to_group => 0x01,
						delete_from_group => 0x02,
						linking_mode => 0x09,
						unlinking_mode => 0x0A,
						ping => 0x10,
						on => 0x11,
						off => 0x13,
						bright => 0x15,
						dim => 0x16,
						start_manual_change => 0x17,
						stop_manual_change => 0x18,
						status_request => 0x19,
						do_read_ee => 0x24,
						remote_set_button_tap => 0x25,
						set_address_msb => 0x28,
						poke => 0x29,
						poke_extended => 0x2a,
						peek => 0x2b,
						peek_internal => 0x2c,
						poke_internal => 0x2d,
						on_at_ramp_rate => 0x2e,
						off_at_ramp_rate => 0x2f
);

sub new
{
	my ($class,$p_interface,$p_deviceid) = @_;
	my $self={};
	bless $self,$class;

	$self->interface($p_interface) if defined $p_interface;
	if (defined $p_deviceid) {
		my ($deviceid, $group) = $p_deviceid =~ /(\w\w\.\w\w\.\w\w):?(.+)?/;
		$self->device_id($deviceid);
		$group = '01' unless $group;
		$group = '0' . $group if length($group) == 1;
		$self->group(uc $group);
	}
	$self->initialize();
	$self->rate(undef);
	$$self{flag} = "0F";
	$$self{ackMode} = "1";
	$self->interface()->add($self);
	return $self;
}

sub initialize
{
	my ($self) = @_;
	$$self{m_write} = 1;
	$$self{m_is_locally_set} = 0;
}

sub interface
{
	my ($self,$p_interface) = @_;
        if (defined $p_interface) {
		$$self{interface} = $p_interface;
		# be sure to add the object to the interface
		$$self{interface}->add_item_if_not_present($self);
	}
	return $$self{interface};
}

sub device_id
{
	my ($self,$p_device_id) = @_;

	if (defined $p_device_id)
	{
		$p_device_id =~ /(\w\w)\W?(\w\w)\W?(\w\w)/;
		$$self{device_id}=$1 . $2 . $3;
	}
	return $$self{device_id};
}

sub rate
{
	my ($self,$p_rate) = @_;
	$$self{rate} = $p_rate if defined $p_rate;
	return $$self{rate};
}

sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;

    # prevent reciprocal sets that can occur because of this method's state
    # propogation
    return if (ref $p_setby and $p_setby->can('get_set_by') and
        $p_setby->{set_by} eq $self);


	# always reset the is_locally_set property
	$$self{m_is_locally_set} = 0;

	if ($p_setby eq $self->interface())
	{
			# don't reset the object w/ the same state if set from the interface
			return if lc $p_state eq lc $self->state;
			&::print_log("Insteon_Device: " . $self->get_object_name() 
				. "::set($p_state, $p_setby)") if $main::Debug{insteon};
	} else {
		$self->interface()->set($self->_xlate_mh_insteon($p_state),$self);
		&::print_log("Insteon_Device: " . $self->get_object_name() . "::set($p_state, $p_setby)")
			if $main::Debug{insteon};
	}
	$self->SUPER::set($p_state,$p_setby,$p_response) if defined $p_state;
}

sub writable {
	my ($self, $p_write) = @_;
	if (defined $p_write) {
		if ($p_write =~ /r/i or $p_write =~/^0/) {
			$$self{m_write} = 0;
		} else {
			$$self{m_write} = 1;
		}
	}
	return $$self{m_write};
}

sub is_locally_set {
	my ($self) = @_;
	return $$self{m_is_locally_set};
}

sub group
{
	my ($self, $p_group) = @_;
	$$self{m_group} = $p_group if $p_group;
	return $$self{m_group};
}

### WARN: Testing using the following does not produce results as expected.  Use at your own risk. [GL]
sub remote_set_button_tap
{
	my ($self,$p_number_taps) = @_;
	my $taps = ($p_number_taps =~ /2/) ? '02' : '01';
	$self->interface()->set($self->_xlate_mh_insteon('remote_set_button_tap','standard',$taps),$self);
}

sub request_status
{
	my ($self) = @_;
	$$self{m_status_request_pending} = 1;
	$self->interface()->set($self->_xlate_mh_insteon('status_request'),$self);
}


sub _process_message
{
	my ($self,$p_setby,%msg) = @_;
	my $p_state = undef;

	# the current approach assumes that links from other controllers to some responder
	# would be seen by the plm by also direct linking the controller as a responder
	# and not putting the plm into monitor mode.  This means that updating the state
	# of the responder based upon the link controller's request is handled
	# by Insteon_Link.
	$$self{m_is_locally_set} = 1 if $msg{source} eq lc $self->device_id;
	if ($msg{is_ack}) {
		if ($$self{m_status_request_pending}) {
			my $ack_on_level = hex($msg{extra});
			## convert on level from hex to numerical
			&::print_log("Insteon_Device: received status request report for " .
				$self->{object_name} . " with on-level: $ack_on_level") if $main::Debug{insteon};
			$self->_on_status_request($ack_on_level, $p_setby);
		} elsif ($msg{command} eq 'peek') {
			$self->_on_peek(%msg);
		} else {
		## should really consider not ignoring but rather using to confirm receipt
			&::print_log("Insteon_Device: is an ack message for " . $self->{object_name} 
				. " ... skipping") if $main::Debug{insteon};
		}
	} elsif ($msg{is_nack}) {
		&::print_log("Insteon_Device: WARN!! ia a nack message for " . $self->{object_name} 
			. " ... skipping");
	} elsif ($msg{command} eq 'start_manual_change') {
		# do nothing; although, maybe anticipate change? we should always get a stop
	} elsif ($msg{command} eq 'stop_manual_change') {
		$self->request_status();
	} else {
		## TO-DO: make sure that the state passed by command is something that is reasonable to set
		$p_state = $msg{command};
		$self->set($p_state, $p_setby);
	}
}

sub _xlate_insteon_mh
{
	my ($p_state) = @_;
	my %msg = {};
	my $hopflag = hex(uc substr($p_state,13,1));
	$msg{hopsleft} = $hopflag >> 2;
	$msg{hopsmax} = $hopflag << 2;
	my $msgflag = hex(uc substr($p_state,12,1));
	$msg{is_extended} = 0x01 & $msgflag;
	if ($msg{is_extended}) {
		$msg{source} = substr($p_state,0,6);
		$msg{destination} = substr($p_state,6,6);
		$msg{extra} = substr($p_state,16,16);
	} else {
		$msg{source} = substr($p_state,0,6);
		$msgflag = $msgflag >> 1;
		if ($msgflag == 4) {
			$msg{type} = 'broadcast';
		} elsif ($msgflag ==6) {
			$msg{type} = 'alllink';
			$msg{group} = substr($p_state,10,2);
		} else {
			$msg{destination} = substr($p_state,6,6);
			if ($msgflag == 2) {
				$msg{type} = 'cleanup';
				$msg{group} = substr($p_state,16,2);
			} elsif ($msgflag == 3) {
				$msg{type} = 'cleanup';
				$msg{is_ack} = 1;
			} elsif ($msgflag == 7) {
				$msg{type} = 'cleanup';
				$msg{is_nack} = 1;
			} elsif ($msgflag == 0) {
				$msg{type} = 'direct';
				$msg{extra} = substr($p_state,16,2);
			} elsif ($msgflag == 1) {
				$msg{type} = 'direct';
				$msg{is_ack} = 1;
				$msg{extra} = substr($p_state,16,2);
			} elsif ($msgflag == 5) {
				$msg{type} = 'direct';
				$msg{is_nack} = 1;
			}
		}
	}
	my $cmd1 = substr($p_state,14,2);

	&::print_log("Insteon_Device: XLATE:$cmd1:") if (!($msg{is_ack} or $msg{is_nack}))
			and $main::Debug{insteon};
	for my $key (keys %message_types){
		if (pack("C",$message_types{$key}) eq pack("H*",$cmd1))
		{
			&::print_log("Insteon_Device: FOUND: $key") 
				if (!($msg{is_ack} or $msg{is_nack})) and $main::Debug{insteon};
			$msg{command}=$key;
			last;
		}
	}
return %msg;
}

sub _xlate_mh_insteon
{
	my ($self,$p_state,$p_type, $p_extra) = @_;
	my $cmd;
	my @args;
	my $msg;
	my $level;

	#msg id
	$msg=$p_state;
	$msg=~ s/\:.*$//;
	$msg=lc($msg);
#	&::print_log("XLATE:$msg:$p_state:");

	if (!(defined $p_extra)) {
		if ($msg eq 'on')
		{
			$level=255;
		} elsif ($msg eq 'off')
		{
			$level = 0;
		} elsif ($msg=~/^([1]?[0-9]?[0-9])/)
		{
			if ($1 < 1) {
				$msg='off';
				$level = 0;
			} else {
				$level = $1 * 2.5;
				$msg='on';
			}
		}
	}

=begin
	#Fuzzy logic find message
	for my $key (keys %message_types)
	{
		if ($key=~/$msg/i)
		{
			$msg = $message_types{$key};
			last;
		}
	}
=cut

#####lets not be device specific
#	$cmd="0262";

	$cmd='';
        if ($p_type =~ /broadcast/i) {
		$cmd.=$self->group;
	} else {
		$cmd.=$self->device_id();
		if ($p_type =~ /extended/i) {
			$cmd.='1F';
		} else {
			$cmd.='0F';
		}
	}
	$cmd.= unpack("H*",pack("C",$message_types{$msg}));
	if ($p_extra)
	{
		$cmd.= $p_extra;
	} else {
		if ($msg eq 'on')
		{
			$cmd.= sprintf("%02X",$level);
		} else {
			$cmd.='00';
		}
	}
	return $cmd;
}

sub _on_status_request
{
	my ($self, $p_onlevel, $p_setby) = @_;
	if ($p_onlevel == 0) {
		$self->SUPER::set('off', $p_setby);
	} elsif ($p_onlevel == 255) {
		$self->SUPER::set('on', $p_setby);
	} else {
		$p_onlevel = $p_onlevel / 2.5;
		$self->SUPER::set(sprintf("%d",$p_onlevel) . '%', $p_setby);
	}
	$$self{m_status_request_pending} = 0;
}

sub _on_peek
{
	my ($self,%msg) = @_;
	if ($msg{is_extended}) {
		&::print_log("Insteon_Device: extended peek for " . $self->{object_name} 
		. " is " . $msg{extra}) if $main::Debug{insteon};
	} else {
		if ($$self{m_peek_action} eq 'adlb_flag') {
			$$self{pending_adlb}{flag} = $msg{extra};
			## confirm that we have a high-water mark; otherwise stop
			$$self{pending_adlb}{address} = $$self{m_peek_msb} . $$self{m_peek_lsb};
			$$self{m_peek_lsb} = sprintf("%02X", hex($$self{m_peek_lsb}) + 1);
			$$self{m_peek_action} = 'adlb_group';
			$$self{interface}->set($self->_xlate_mh_insteon('peek','standard',$$self{m_peek_lsb}),$self);
		} elsif ($$self{m_peek_action} eq 'adlb_group') {
			$$self{pending_adlb}{group} = $msg{extra};
			$$self{m_peek_lsb} = sprintf("%02X", hex($$self{m_peek_lsb}) + 1);
			$$self{m_peek_action} = 'adlb_devhi';
			$$self{interface}->set($self->_xlate_mh_insteon('peek','standard',$$self{m_peek_lsb}),$self);
		} elsif ($$self{m_peek_action} eq 'adlb_devhi') {
			$$self{pending_adlb}{deviceid} = $msg{extra};
			$$self{m_peek_lsb} = sprintf("%02X", hex($$self{m_peek_lsb}) + 1);
			$$self{m_peek_action} = 'adlb_devmid';
			$$self{interface}->set($self->_xlate_mh_insteon('peek','standard',$$self{m_peek_lsb}),$self);
		} elsif ($$self{m_peek_action} eq 'adlb_devmid') {
			$$self{pending_adlb}{deviceid} .= $msg{extra};
			$$self{m_peek_lsb} = sprintf("%02X", hex($$self{m_peek_lsb}) + 1);
			$$self{m_peek_action} = 'adlb_devlo';
			$$self{interface}->set($self->_xlate_mh_insteon('peek','standard',$$self{m_peek_lsb}),$self);
		} elsif ($$self{m_peek_action} eq 'adlb_devlo') {
			$$self{pending_adlb}{deviceid} .= $msg{extra};
			$$self{m_peek_lsb} = sprintf("%02X", hex($$self{m_peek_lsb}) + 1);
			$$self{m_peek_action} = 'adlb_data1';
			$$self{interface}->set($self->_xlate_mh_insteon('peek','standard',$$self{m_peek_lsb}),$self);
		} elsif ($$self{m_peek_action} eq 'adlb_data1') {
			$$self{pending_adlb}{data1} .= $msg{extra};
			$$self{m_peek_lsb} = sprintf("%02X", hex($$self{m_peek_lsb}) + 1);
			$$self{m_peek_action} = 'adlb_data2';
			$$self{interface}->set($self->_xlate_mh_insteon('peek','standard',$$self{m_peek_lsb}),$self);
		} elsif ($$self{m_peek_action} eq 'adlb_data2') {
			$$self{pending_adlb}{data2} .= $msg{extra};
			$$self{m_peek_lsb} = sprintf("%02X", hex($$self{m_peek_lsb}) + 1);
			$$self{m_peek_action} = 'adlb_data3';
			$$self{interface}->set($self->_xlate_mh_insteon('peek','standard',$$self{m_peek_lsb}),$self);
		} elsif ($$self{m_peek_action} eq 'adlb_data3') {
			$$self{pending_adlb}{data3} .= $msg{extra};
		}
		&::print_log("Insteon_Device: peek for " . $self->{object_name} 
		. " is " . $msg{extra}) if $main::Debug{insteon};
	}	
}

sub set_receive
{
	my ($self, $p_state, $p_setby, $p_response) = @_;
	$self->SUPER::set($p_state, $p_setby, $p_response);
}

sub _peek
{
	my ($self, $address, $extended) = @_;
	my $msb = substr($address,0,2);
	my $lsb = substr($address,2,2);
	$$self{interface}->set($self->_xlate_mh_insteon('set_address_msb','standard',$msb),$self);
	if ($extended) {
		$$self{interface}->set($self->_xlate_mh_insteon('peek','extended',
			$lsb . "0000000000000000000000000000"),$self);
	} else {
		$$self{m_peek_lsb} = $lsb;
		$$self{m_peek_msb} = $msb;
		$$self{m_peek_action} = 'adlb_flag';
		$$self{interface}->set($self->_xlate_mh_insteon('peek','standard',$lsb),$self);
	}
}


1;
