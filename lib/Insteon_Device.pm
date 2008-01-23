=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Insteon_Device.pm

Description:
	Generic class implementation of an Insteon Device.

Author(s):
	Jason Sharpee / jason@sharpee.com
	Gregg Liming / gregg@limings.net

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
						set_led_status => 0x27,
						set_address_msb => 0x28,
						poke => 0x29,
						poke_extended => 0x2a,
						peek => 0x2b,
						peek_internal => 0x2c,
						poke_internal => 0x2d,
						on_at_ramp_rate => 0x2e,
						off_at_ramp_rate => 0x2f
);

my %ramp_h2n = (
						'00' => 540,
						'01' => 480,
						'02' => 420,
						'03' => 360,
						'04' => 300,
						'05' => 270,
						'06' => 240,
						'07' => 210,
						'08' => 180,
						'09' => 150,
						'0a' => 120,
						'0b' =>  90,
						'0c' =>  60,
						'0d' =>  47,
						'0e' =>  43,
						'0f' =>  39,
						'10' =>  34,
						'11' =>  32,
						'12' =>  30,
						'13' =>  28,
						'14' =>  26,
						'15' =>  23.5,
						'16' =>  21.5,
						'17' =>  19,
						'18' =>   8.5,
						'19' =>   6.5,
						'1a' =>   4.5,
						'1b' =>   2,
						'1c' =>    .5,
						'1d' =>    .3,
						'1e' =>    .2,
						'1f' =>    .1
);

sub convert_ramp
{
	my ($ramp_in_seconds) = @_;
	if ($ramp_in_seconds) {
		foreach my $rampkey (sort keys %ramp_h2n) {
			return $rampkey if $ramp_in_seconds >= $ramp_h2n{$rampkey};
		}
	} else {
		return '1f';
	}
}

sub new
{
	my ($class,$p_interface,$p_deviceid) = @_;
	my $self={};
	bless $self,$class;

	$self->interface($p_interface) if defined $p_interface;
	if (defined $p_deviceid) {
		my ($deviceid, $group) = $p_deviceid =~ /(\w\w\.\w\w\.\w\w):?(.+)?/;
		# if a group is passed in, then assume it can be a controller
		$$self{is_controller} = ($group) ? 1 : 0;
		$self->device_id($deviceid);
		$group = '01' unless $group;
		$group = '0' . $group if length($group) == 1;
		$self->group(uc $group);
	}
	$self->initialize();
	$self->rate(undef);
	$$self{flag} = "0F";
	$$self{ackMode} = "1";
	$$self{awaiting_ack} = 0;
	$$self{is_acknowledged} = 0;
	$$self{queue_timer} = new Timer();
	$$self{max_queue_time} = $::config_parms{'Insteon_PLM_max_queue_time'};
	$$self{max_queue_time} = 15 unless $$self{max_queue_time}; # 15 seconds is max time allowed in command stack
	@{$$self{command_stack}} = ();
	$$self{_retry_count} = 0; # num times that a command has been resent
	$self->interface()->add($self);
	return $self;
}

sub initialize
{
	my ($self) = @_;
	$$self{m_write} = 1;
	$$self{m_is_locally_set} = 0;
	# persist local, simple attribs
	$self->restore_data('devcat');
	$$self{ping_timer} = new Timer();
	$$self{ping_timerTime} = 300;
	$$self{ping_timer}->set($$self{ping_timerTime} + (rand() * $$self{ping_timerTime}), $self) 
		unless $self->group eq '01' and defined $$self{devcat};
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

sub is_acknowledged
{
	my ($self, $p_ack) = @_;
	$$self{is_acknowledged} = $p_ack if defined $p_ack;
	return $$self{is_acknowledged};
}

sub is_controller
{
	my ($self) = @_;
	return $$self{is_controller};
}

sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;

    # prevent reciprocal sets that can occur because of this method's state
    # propogation
#    return if (ref $p_setby and $p_setby->can('get_set_by') and
#        $p_setby->{set_by} eq $self);

	# did the queue timer go off?
	if (ref $p_setby and $p_setby eq $$self{queue_timer}) {
		$self->_process_command_stack();
	} elsif (ref $p_setby and $p_setby eq $$self{ping_timer}) {
		if (! (defined($$self{devcat}))) {
			$self->ping();
			# set the timer again in case nothing occurs
			$$self{ping_timer}->set($$self{ping_timerTime} + (rand() * $$self{ping_timerTime}), $self);
		}
	} else {
		# always reset the is_locally_set property
		$$self{m_is_locally_set} = 0;

		if (ref $p_setby and (($p_setby eq $self->interface()) 
			or ($p_setby->isa('Insteon_Device') and &main::set_by_to_target($p_setby) eq $self->interface)))
		{
				# don't reset the object w/ the same state if set from the interface
				return if (lc $p_state eq lc $self->state) and $self->is_acknowledged;
				&::print_log("[Insteon_Device] " . $self->get_object_name() 
					. "::set($p_state, $p_setby)") if $main::Debug{insteon};
		} else {
			$self->_send_cmd(command => $p_state, 
				type => (($self->isa('Insteon_Link') and ($self->group ne '01')) ? 'alllink' : 'standard'));
			&::print_log("[Insteon_Device] " . $self->get_object_name() . "::set($p_state, $p_setby)")
				if $main::Debug{insteon};
			$self->is_acknowledged(0);
		}
		$self->SUPER::set($p_state,$p_setby,$p_response) if defined $p_state;
	}
}

sub link_to_interface
{
	my ($self,$p_group) = @_;
	my $group = $p_group;
	$group = '01' unless $group;
	# add a link first to this device back to interface
	# and, add a reference to creating a link from interface back to device via hook
	$self->add_link(object => $self->interface, group => $group, is_controller => 1,
			on_level => '100%', ramp_rate => '0.1s', 
			callback => \$self->interface->add_link(object => $self, group => $group, is_controller => 0));
}

sub unlink_to_interface
{
	my ($self,$p_group) = @_;
	my $group = $p_group;
	$group = '01' unless $group;
	$self->delete_link(object => $self->interface, group => $group, is_controller => 1,
		callback => \$self->interface->delete_link(object => $self, group => $group, is_controller => 0));
}

sub _send_cmd
{
	my ($self, %msg) = @_;
	$msg{type} = 'standard' unless $msg{type};
	if ($msg{is_synchronous}) {
		push(@{$$self{command_stack}}, \%msg);
	} else {
		unshift(@{$$self{command_stack}}, \%msg);
	}
	$self->_process_command_stack();
}

sub _process_command_stack
{
	my ($self, %ackmsg) = @_;
	if (%ackmsg) { # which may also be something that can be interpretted as a "nack"
		# determine whether to unset awaiting_ack
		# for now, by "dumb" and just unset it
		$$self{awaiting_ack} = 0;
		# is there an "on_ack" command to now be performed?  if so, queue it
		if ($ackmsg{on_ack}) {
			# process the on_ack command
			# any new command needs to be pushed on to the queue in front of other pending cmds
		}
	}
	if ($$self{queue_timer}->expired or !($$self{awaiting_ack})) {
		if ($$self{queue_timer}->expired) {
			if ($$self{_prior_msg} and $$self{_retry_count} < 2) {
				# first check to see if type is an alllink; if so, then don't keep retrying until
				#   proper handling of alllink cleanup status is implemented in Insteon_PLM
				if ($$self{_prior_msg}{type} eq 'alllink') {
					# do nothing
				} else {
					push(@{$$self{command_stack}}, \%{$$self{_prior_msg}});
					&::print_log("[Insteon_Device] WARN: queue timer on " . $self->get_object_name . 
					" expired. Attempting resend: $$self{_prior_msg}{command}");
				}
			} else {
				&::print_log("[Insteon_Device] WARN: queue timer on " . $self->get_object_name . 
				" expired. Trying next command if queued.");
				$$self{m_status_request_pending} = 0; # hack--need a better way
			}
		}
		my $cmdptr = pop(@{$$self{command_stack}});
		# convert ptr to cmd hash
		if ($cmdptr) {
			my %cmd = %$cmdptr;
			# convert cmd to insteon message
			my $insteonmsg = $self->_xlate_mh_insteon($cmd{command},$cmd{type},$cmd{extra});
			my $plm_queue_size = $self->interface()->set($insteonmsg, $self);
			# send msg
			if ($cmd{is_synchronous}) {
				$$self{awaiting_ack} = 1;
			} else {
				$$self{awaiting_ack} = 0;
			}
			if ($$self{_prior_msg} and $$self{_prior_msg}{command} eq $cmd{command}) {
				$$self{_retry_count} = ($$self{_retry_count}) ? $$self{_retry_count} + 1 : 1;
			} else {
				$$self{_retry_count} = 0;
			}
			%{$$self{_prior_msg}} = %cmd;
			# TO-DO: adjust timer based upon (1) type of message, (2) plm_queue_size and (3) retry_count
			$$self{queue_timer}->set($$self{max_queue_time},$self);
			# if is_synchronous, then no other command can be sent until an insteon ack or nack is received
			# for this command
		} else {
			# always unset the timer if no more commands
			$$self{queue_timer}->unset();
			# and, always clear awaiting_ack and _prior_msg
			$$self{awaiting_ack} = 0;
			$$self{_prior_msg} = undef;
		}
	} else {
		&::print_log("[Insteon_Device] " . $self->get_object_name . " command queued but not yet sent; awaiting ack from prior command");
	}
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
	$self->_send_cmd('command' => 'remote_set_button_tap', 'extra' => $taps);
}

sub request_status
{
	my ($self) = @_;
	$$self{m_status_request_pending} = 1;
	$self->_send_cmd('command' => 'status_request', 'is_synchronous' => 1);
}

sub ping
{
	my ($self) = @_;
	$self->_send_cmd('command' => 'ping');
}

sub set_led_status
{
	my ($self, $status_mask) = @_;
	$self->_send_cmd('command' => 'set_led_status', 'extra' => $status_mask);
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
			my $ack_on_level = hex($msg{extra}) * 100 / 255;
			&::print_log("[Insteon_Device] received status request report for " .
				$self->{object_name} . " with on-level: " . 
				sprintf("%d",$ack_on_level) . '%'
				. ", hops left: $msg{hopsleft}") if $main::Debug{insteon};
			$self->_on_status_request(hex($msg{extra}), $p_setby);
			$self->_process_command_stack(%msg);
		} elsif (($msg{command} eq 'peek') or ($msg{command} eq 'set_address_msb')) {
			$self->_on_peek(%msg);
			$self->_process_command_stack(%msg);
		} elsif (($msg{command} eq 'poke') or ($msg{command} eq 'set_address_msb')) {
			$self->_on_poke(%msg);
			$self->_process_command_stack(%msg);
		} else {
			$self->is_acknowledged(1);
			# signal receipt of message to the command stack in case commands are queued
			$self->_process_command_stack(%msg);
			&::print_log("[Insteon_Device] received command/state acknowledge from " . $self->{object_name} 
				. ": $msg{command} and data: $msg{extra}") if $main::Debug{insteon};
		}
	} elsif ($msg{is_nack}) {
		&::print_log("[Insteon_Device] WARN!! ia a nack message for " . $self->{object_name} 
			. " ... skipping");
	} elsif ($msg{command} eq 'start_manual_change') {
		# do nothing; although, maybe anticipate change? we should always get a stop
	} elsif ($msg{command} eq 'stop_manual_change') {
		$self->request_status();
	} elsif ($msg{type} eq 'broadcast') {
		$$self{devcat} = $msg{devcat};
		&::print_log("[Insteon_Device] device category: $msg{devcat} received for " . $self->{object_name});
		# stop ping timer now that we have a devcat; possibly may want to change this behavior to allow recurring pings
		$$self{ping_timer}->stop();
	} else {
		## TO-DO: make sure that the state passed by command is something that is reasonable to set
		$p_state = $msg{command};
		$$self{_pending_cleanup} = 1 if $msg{type} eq 'alllink';
		$self->set($p_state, $p_setby) unless (lc($self->state) eq lc($p_state)) and 
			($msg{type} eq 'cleanup' and $$self{_pending_cleanup});
		$$self{_pending_cleanup} = 0 if $msg{type} eq 'cleanup';
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
	$msg{is_extended} = (0x01 & $msgflag) ? 1 : 0;
	if ($msg{is_extended}) {
		$msg{source} = substr($p_state,0,6);
		$msg{destination} = substr($p_state,6,6);
		$msg{extra} = substr($p_state,16,16);
	} else {
		$msg{source} = substr($p_state,0,6);
		$msgflag = $msgflag >> 1;
		if ($msgflag == 4) {
			$msg{type} = 'broadcast';
			$msg{devcat} = substr($p_state,6,4);
			$msg{firmware} = substr($p_state,10,2);
			$msg{is_master} = substr($p_state,16,2);
			$msg{dev_attribs} = substr($p_state,18,2);
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

	if ($msg{type} ne 'broadcast') {
		&::print_log("[Insteon_Device] command:$cmd1; type:$msg{type}; group: $msg{group}") if (!($msg{is_ack} or $msg{is_nack}))
				and $main::Debug{insteon};
		for my $key (keys %message_types){
			if (pack("C",$message_types{$key}) eq pack("H*",$cmd1))
			{
				&::print_log("[Insteon_Device] found: $key") 
					if (!($msg{is_ack} or $msg{is_nack})) and $main::Debug{insteon};
				$msg{command}=$key;
				last;
			}
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
				$level = $1 * 2.55;
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
		$p_onlevel = $p_onlevel / 2.55;
		$p_onlevel = 100 if $p_onlevel >= 99;
		$self->SUPER::set(sprintf("%d",$p_onlevel) . '%', $p_setby);
	}
	$self->is_acknowledged(1);
	$$self{m_status_request_pending} = 0;
}

sub _on_poke
{
	my ($self,%msg) = @_;
	if (($$self{_mem_activity} eq 'update') or ($$self{_mem_activity} eq 'add')) {
		if ($$self{_mem_action} eq 'adlb_flag') {
			$$self{_mem_action} = 'adlb_group';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'adlb_group') {
			$$self{_mem_action} = 'adlb_devhi';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'adlb_devhi') {
			$$self{_mem_action} = 'adlb_devmid';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'adlb_devmid') {
			$$self{_mem_action} = 'adlb_devlo';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'adlb_devlo') {
			$$self{_mem_action} = 'adlb_data1';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'adlb_data1') {
			$$self{_mem_action} = 'adlb_data2';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'adlb_data2') {
			$$self{_mem_action} = 'adlb_data3';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'adlb_data3') {
			## update the adlb records w/ the changes that were made
			my $adlbkey = $$self{pending_adlb}{deviceid} . $$self{pending_adlb}{group} . $$self{pending_adlb}{is_controller};
			$$self{adlb}{$adlbkey}{data1} = $$self{pending_adlb}{data1};
			$$self{adlb}{$adlbkey}{data2} = $$self{pending_adlb}{data2};
			$$self{adlb}{$adlbkey}{data3} = $$self{pending_adlb}{data3};
			if ($$self{_mem_activity} eq 'add') {
				$$self{adlb}{$adlbkey}{is_controller} = $$self{pending_adlb}{is_controller};
				$$self{adlb}{$adlbkey}{deviceid} = $$self{pending_adlb}{deviceid};
				$$self{adlb}{$adlbkey}{group} = $$self{pending_adlb}{group};
				$$self{adlb}{$adlbkey}{address} = $$self{pending_adlb}{address};
				# on completion, check to see if the empty links list is now empty; if so, 
				# then decrement the current address and add it to the list
				if (!(@{$$self{adlb}{empty}})) {
					my $address = $$self{adlb}{$adlbkey}{address};
					$address = sprintf('%04X', hex($address) - 8);
					unshift @{$$self{adlb}{empty}}, $address;
				}
			}
			# clear out mem_activity flag
			$$self{_mem_activity} = undef;
			if (defined $$self{_mem_callback}) {
				eval ($$self{_mem_callback});
				$$self{_mem_callback} = undef;
			}
		}
	} elsif ($$self{_mem_activity} eq 'update_local') {
		if ($$self{_mem_action} eq 'local_onlevel') {
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
			$$self{_mem_action} = 'local_ramprate';
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		}
	} elsif ($$self{_mem_activity} eq 'delete') {
		# clear out mem_activity flag
		$$self{_mem_activity} = undef;
		# add the address of the deleted link to the empty list
		unshift @{$$self{adlb}{empty}}, $$self{pending_adlb}{address};
		my $key = lc $$self{pending_adlb}{deviceid} . $$self{pending_adlb}{group} . $$self{pending_adlb}{is_controller};
		delete $$self{adlb}{$key};
	
		if (defined $$self{_mem_callback}) {
			eval ($$self{_mem_callback});
			$$self{_mem_callback} = undef;
		}
	}
#
}

sub _on_peek
{
	my ($self,%msg) = @_;
	if ($msg{is_extended}) {
		&::print_log("Insteon_Device: extended peek for " . $self->{object_name} 
		. " is " . $msg{extra}) if $main::Debug{insteon};
	} else {
		if ($$self{_mem_action} eq 'adlb_peek') {
			if ($$self{_mem_activity} eq 'scan') {
				$$self{_mem_action} = 'adlb_flag';
			} elsif ($$self{_mem_activity} eq 'update') {
				$$self{_mem_action} = 'adlb_data1';
			} elsif ($$self{_mem_activity} eq 'update_local') {
				$$self{_mem_action} = 'local_onlevel';
			} elsif ($$self{_mem_activity} eq 'delete') {
				$$self{_mem_action} = 'adlb_flag';
			} elsif ($$self{_mem_activity} eq 'add') {
				$$self{_mem_action} = 'adlb_flag';
			}
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'adlb_flag') {
			if ($$self{_mem_activity} eq 'scan') {
				my $flag = hex($msg{extra});
				$$self{pending_adlb}{inuse} = 1 if $flag & 0x80;
				$$self{pending_adlb}{is_controller} = ($flag & 0x40) ? 1 : 0;
				$$self{pending_adlb}{highwater} = 1 if $flag & 0x02;
				if (!($$self{pending_adlb}{highwater})) {
					# since this is the last unused memory location, then add it to the empty list
					unshift @{$$self{adlb}{empty}}, $$self{_mem_msb} . $$self{_mem_lsb};
					$$self{_mem_action} = undef;
					# clear out mem_activity flag
					$$self{_mem_activity} = undef;
					if (defined $$self{_mem_callback}) {
						eval ($$self{_mem_callback});
						$$self{_mem_callback} = undef;
					}
				} else {
					$$self{pending_adlb}{flag} = $msg{extra};
					## confirm that we have a high-water mark; otherwise stop
					$$self{pending_adlb}{address} = $$self{_mem_msb} . $$self{_mem_lsb};
					$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
					$$self{_mem_action} = 'adlb_group';
					$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
				}
			} elsif ($$self{_mem_activity} eq 'add') {
				my $flag = ($$self{pending_adlb}{is_controller}) ? 'E2' : 'A2';
				$$self{pending_adlb}{flag} = $flag;
				$self->_send_cmd('command' => 'poke', 'extra' => $flag, 'is_synchronous' => 1);
			} elsif ($$self{_mem_activity} eq 'delete') {
				$self->_send_cmd('command' => 'poke', 'extra' => '02', 'is_synchronous' => 1);
			}
		} elsif ($$self{_mem_action} eq 'adlb_group') {
			if ($$self{_mem_activity} eq 'scan') {
				$$self{pending_adlb}{group} = $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'adlb_devhi';
				$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 
						'is_synchronous' => 1);
			} else {
				$self->_send_cmd('command' => 'poke', 'extra' => $$self{pending_adlb}{group},
						'is_synchronous' => 1);
			}
		} elsif ($$self{_mem_action} eq 'adlb_devhi') {
			if ($$self{_mem_activity} eq 'scan') {
				$$self{pending_adlb}{deviceid} = $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'adlb_devmid';
				$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
			} elsif ($$self{_mem_activity} eq 'add') {
				my $devid = substr($$self{pending_adlb}{deviceid},0,2);
				$self->_send_cmd('command' => 'poke', 'extra' => $devid, 'is_synchronous' => 1);
			}
		} elsif ($$self{_mem_action} eq 'adlb_devmid') {
			if ($$self{_mem_activity} eq 'scan') {
				$$self{pending_adlb}{deviceid} .= $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'adlb_devlo';
				$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
			} elsif ($$self{_mem_activity} eq 'add') {
				my $devid = substr($$self{pending_adlb}{deviceid},2,2);
				$self->_send_cmd('command' => 'poke', 'extra' => $devid, 'is_synchronous' => 1);
			}
		} elsif ($$self{_mem_action} eq 'adlb_devlo') {
			if ($$self{_mem_activity} eq 'scan') {
				$$self{pending_adlb}{deviceid} .= $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'adlb_data1';
				$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
			} elsif ($$self{_mem_activity} eq 'add') {
				my $devid = substr($$self{pending_adlb}{deviceid},4,2);
				$self->_send_cmd('command' => 'poke', 'extra' => $devid, 'is_synchronous' => 1);
			}
		} elsif ($$self{_mem_action} eq 'adlb_data1') {
			if ($$self{_mem_activity} eq 'scan') {
				$$self{_mem_action} = 'adlb_data2';
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{pending_adlb}{data1} = $msg{extra};
				$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
			} elsif ($$self{_mem_activity} eq 'update' or $$self{_mem_activity} eq 'add') {
				# poke the new value
				$self->_send_cmd('command' => 'poke', 'extra' => $$self{pending_adlb}{data1}, 'is_synchronous' => 1);
			}
		} elsif ($$self{_mem_action} eq 'adlb_data2') {
			if ($$self{_mem_activity} eq 'scan') {
				$$self{pending_adlb}{data2} = $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'adlb_data3';
				$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
			} elsif ($$self{_mem_activity} eq 'update' or $$self{_mem_activity} eq 'add') {
				# poke the new value
				$self->_send_cmd('command' => 'poke', 'extra' => $$self{pending_adlb}{data2}, 'is_synchronous' => 1);
			}
		} elsif ($$self{_mem_action} eq 'adlb_data3') {
			if ($$self{_mem_activity} eq 'scan') {
				$$self{pending_adlb}{data3} = $msg{extra};
				# check the previous record if highwater is set
				if ($$self{pending_adlb}{highwater}) {
					if ($$self{pending_adlb}{inuse}) {
					# save pending_adlb and then clear it out
						my $adlbkey = $$self{pending_adlb}{deviceid} 
							. $$self{pending_adlb}{group}
							. $$self{pending_adlb}{is_controller};
						%{$$self{adlb}{$adlbkey}} = %{$$self{pending_adlb}};
					} else {
						# TO-DO: record the locations of deleted ADLB records for subsequent reuse
						unshift @{$$self{adlb}{empty}}, $$self{pending_adlb}{address};
					}
					my $newaddress = sprintf("%04X", hex($$self{pending_adlb}{address}) - 8);
					$$self{pending_adlb} = undef;
					$self->_peek($newaddress);
				}
			} elsif ($$self{_mem_activity} eq 'update' or $$self{_mem_activity} eq 'add') {
				# poke the new value
				$self->_send_cmd('command' => 'poke', 'extra' => $$self{pending_adlb}{data3}, 'is_synchronous' => 1);
			}
		} elsif ($$self{_mem_action} eq 'local_onlevel') {
			my $on_level = $$self{_onlevel};
			$on_level = 'ff' unless $on_level;
			$self->_send_cmd('command' => 'poke', 'extra' => $on_level, 'is_synchronous' => 1);
#			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
#			$$self{_mem_action} = 'local_ramprate';
#			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'local_ramprate') {
			my $ramp_rate = $$self{_ramprate};
			$ramp_rate = '1f' unless $ramp_rate;
			$self->_send_cmd('command' => 'poke', 'extra' => $ramp_rate, 'is_synchronous' => 1);
		}
#
#			&::print_log("Insteon_Device: peek for " . $self->{object_name} 
#		. " is " . $msg{extra}) if $main::Debug{insteon};
	}	
}

sub restore_string
{
	my ($self) = @_;
	my $restore_string = $self->SUPER::restore_string();
	if ($$self{adlb}) {
		my $adlb = '';
		foreach my $adlb_key (keys %{$$self{adlb}}) {
			next unless $adlb_key eq 'empty' || $$self{adlb}{$adlb_key}{inuse};
			$adlb .= '|' if $adlb; # separate sections
			my $record = '';
			if ($adlb_key eq 'empty') {
				foreach my $address (@{$$self{adlb}{empty}}) {
					$record .= ';' if $record;
					$record .= $address;
				}
				$record = 'empty=' . $record;
			} else {
				my %adlb_record = %{$$self{adlb}{$adlb_key}};
				foreach my $record_key (keys %adlb_record) {
					next unless $adlb_record{$record_key};
					$record .= ',' if $record;
					$record .= $record_key . '=' . $adlb_record{$record_key};
				}
			}
			$adlb .= $record;
		}
#		&::print_log("[Insteon_Device] ADLB restore string: $adlb") if $main::Debug{insteon};
		$restore_string .= $self->{object_name} . "->restore_adlb(q~$adlb~);\n";
        }
	return $restore_string;
}

sub restore_adlb
{
	my ($self,$adlb) = @_;
	if ($adlb) {
		foreach my $adlb_section (split(/\|/,$adlb)) {
			my %adlb_record = {};
			my @adlb_empty = ();
			my $deviceid = '';
			my $groupid = '01';
			my $is_controller = 0;
			foreach my $adlb_record (split(/,/,$adlb_section)) {
				my ($key,$value) = split(/=/,$adlb_record);
				if ($key eq 'empty') {
					@adlb_empty = split(/;/,$value);
				} else {
					$deviceid = $value if ($key eq 'deviceid');
					$groupid = $value if ($key eq 'group');
					$is_controller = $value if ($key eq 'is_controller');
					$adlb_record{$key} = $value if $key and defined($value);
				}
			}
			if (@adlb_empty) {
				@{$$self{adlb}{empty}} = @adlb_empty;
			} else {
				my $adlbkey = $deviceid . $groupid . $is_controller;
				%{$$self{adlb}{$adlbkey}} = %adlb_record;
			}
		}
#		$self->log_alllink_table();
	}
}

sub set_receive
{
	my ($self, $p_state, $p_setby, $p_response) = @_;
	$self->SUPER::set($p_state, $p_setby, $p_response);
}

sub scan_link_table
{
	my ($self,$callback) = @_;
	# always reset the current cache in case memory changes
	$$self{adlb} = undef;
	$$self{_mem_activity} = 'scan';
	# reinit the empty address list
	@{$$self{adlb}{empty}} = ();
	$$self{_mem_callback} = ($callback) ? $callback : undef;
	$self->_peek('0FF8',0);
}

sub delete_link
{
	my ($self, %link_parms) = @_;
	my $insteon_object = $link_parms{object};
	my $deviceid = ($insteon_object) ? $insteon_object->device_id : $link_parms{deviceid};
	my $groupid = $link_parms{group};
	$groupid = '01' unless $groupid;
	my $is_controller = ($link_parms{is_controller}) ? 1 : 0;
	# get the address via lookup into the hash
	my $key = $deviceid . $groupid . $is_controller;
	my $address = $$self{adlb}{$key}{address};
	if ($address) {
		&main::print_log("[Insteon_Device] Now deleting link [0x$address] with the following data"
			. " deviceid=$deviceid, groupid=$groupid, is_controller=$is_controller");
		# now, alter the flags byte such that the in_use flag is set to 0
		$$self{_mem_callback} = ($link_parms{callback}) ? $link_parms{callback} : undef;
		$$self{_mem_activity} = 'delete';
		$$self{pending_adlb}{deviceid} = $deviceid;
		$$self{pending_adlb}{group} = $groupid;
		$$self{pending_adlb}{is_controller} = $is_controller;
		$$self{pending_adlb}{address} = $address;
		$self->_peek($address,0);
	} else {
		&main::print_log('[Insteon_Device] WARN: attempt to delete link that does not exist!'
			. " deviceid=$deviceid, groupid=$groupid, is_controller=$is_controller");
		eval($link_parms{callback}) if $link_parms{callback};
	}
}

sub delete_orphan_links
{
	my ($self) = @_;
	my $num_deleted = 0;
	foreach my $linkkey(keys %{$$self{adlb}}) {
		my $deviceid = $$self{adlb}{$linkkey}{deviceid};
		my $device = ($deviceid eq '000000') ? $self->interface
				: $self->interface->get_object($deviceid,'01');
		if (!($device)) {
			&::print_log("[Insteon_Device] now deleting orphaned link w/ details: "
				. (($$self{adlb}{$linkkey}{is_controller}) ? "controller" : "responder")
				. ", deviceid=$$self{adlb}{$linkkey}{deviceid}, "
				. "group=$$self{adlb}{$linkkey}{group}");
#			$self->delete_link(deviceid => $deviceid, group => $$self{adlb}{$linkkey}{group},
#				is_controller => $$self{adlb}{$linkkey}{is_controller});
#			$num_deleted++;
		} elsif ($device->isa("Insteon_PLM") and $$self{adlb}{$linkkey}{is_controller}) {
			# ignore for now since this is just a link back to the PLM
		} elsif ($device->isa("Insteon_PLM")) {
			# TO-DO: check to see if there is a defined link back to this device
		} else {

		}
	}
}

sub add_link
{
	my ($self, %link_parms) = @_;
	my $insteon_object = $link_parms{object};
	my $group = $link_parms{group};
	my $is_controller = ($link_parms{is_controller}) ? 1 : 0;
	# check whether the link already exists
	my $key = $insteon_object->device_id . $group . $is_controller;
	if (defined $$self{adlb}{$key}) {
		&::print_log("[Insteon_Device] WARN: attempt to add link to " . $self->get_object_name . " that already exists! "
			. "object=" . $insteon_object->get_object_name . ", group=$group, is_controller=$is_controller");
		eval($link_parms{callback}) if $link_parms{callback};
	} else {
		# strip optional % sign to append on_level
		my $on_level = $link_parms{on_level};
		$on_level =~ s/(\d)%?/$1/;
		$on_level = '100'; # 100% == on is the default
		# strip optional s (seconds) to append ramp_rate
		my $ramp_rate = $link_parms{ramp_rate};
		$ramp_rate =~ s/(\d)s?/$1/;
		$ramp_rate = '0.1' unless $ramp_rate; # 0.1s is the default
		&::print_log("[Insteon_Device] adding link record " . $self->get_object_name 
			. " light level controlled by " . $insteon_object->get_object_name
			. " and group: $group with on level: $on_level and ramp rate: $ramp_rate") if $main::Debug{insteon};
		my $data1 = sprintf('%02X',$on_level * 2.55);
		my $data2 = &Insteon_Device::convert_ramp($ramp_rate);
		my $data3 = ($link_parms{data3}) ? $link_parms{data3} : '00';
		# get the first available memory location
		my $address = pop @{$$self{adlb}{empty}};
		# TO-DO: ensure that pop'd address is restored back to queue if the transaction fails
		$$self{_mem_activity} = 'add';
		$$self{_mem_callback} = ($link_parms{callback}) ? $link_parms{callback} : undef;
		$self->_write_link($address, $insteon_object->device_id, $group, $is_controller, $data1, $data2, $data3);
	}
}

sub update_link
{
	my ($self, %link_parms) = @_;
	my $insteon_object = $link_parms{object};
	my $group = $link_parms{group};
	my $is_controller = ($link_parms{is_controller}) ? 1 : 0;
	# strip optional % sign to append on_level
	my $on_level = $link_parms{on_level};
	$on_level =~ s/(\d)%?/$1/;
	# strip optional s (seconds) to append ramp_rate
	my $ramp_rate = $link_parms{ramp_rate};
	$ramp_rate =~ s/(\d)s?/$1/;
	&::print_log("[Insteon_Device] updating " . $self->get_object_name . " light level controlled by " . $insteon_object->get_object_name
		. " and group: $group with on level: $on_level and ramp rate: $ramp_rate") if $main::Debug{insteon};
	my $data1 = sprintf('%02X',$on_level * 2.55);
	my $data2 = &Insteon_Device::convert_ramp($ramp_rate);
	my $data3 = ($link_parms{data3}) ? $link_parms{data3} : '00';
	my $deviceid = $insteon_object->device_id;
	my $address = $$self{adlb}{$deviceid . $group . $is_controller}{address};
	$$self{_mem_activity} = 'update';
	$self->_write_link($address, $deviceid, $group, $is_controller, $data1, $data2, $data3);
}


sub log_alllink_table
{
	my ($self) = @_;
	&::print_log("[Insteon_Device] link table for " . $self->get_object_name . " (devcat: $$self{devcat}):");

	foreach my $adlbkey (keys %{$$self{adlb}}) {
		next if $adlbkey eq 'empty';
		my ($device);
		if ($self->interface()->device_id() and ($self->interface()->device_id() eq $$self{adlb}{$adlbkey}{deviceid})) {
			$device = $self->interface;
		} else {
			$device = $self->interface()->get_object($$self{adlb}{$adlbkey}{deviceid},'01');
#				$$self{adlb}{$adlbkey}{group});
		}
		my $object_name = ($device) ? $device->get_object_name : $$self{adlb}{$adlbkey}{deviceid};

		my $on_level = 'unknown';
		if (defined $$self{adlb}{$adlbkey}{data1}) {
			if ($$self{adlb}{$adlbkey}{data1}) {
				$on_level = int((hex($$self{adlb}{$adlbkey}{data1})*100/255) + .5) . "%";
			} else {
				$on_level = '0%';
			}
		}

		my $ramp_rate = 'unknown';
		if ($$self{adlb}{$adlbkey}{data2}) {
			$ramp_rate = $ramp_h2n{$$self{adlb}{$adlbkey}{data2}} . "s";
		}

		&::print_log("[Insteon_Device] " . $self->get_object_name . " adlb [0x" . $$self{adlb}{$adlbkey}{address} . "] " .
			(($$self{adlb}{$adlbkey}{is_controller}) ? "controller($$self{adlb}{$adlbkey}{group}) record to "
			. $object_name
			: "responder record to " . $object_name . "($$self{adlb}{$adlbkey}{group})"
			. ": onlevel=$on_level and ramp=$ramp_rate")) if $main::Debug{insteon};
	}
	foreach my $address (@{$$self{adlb}{empty}}) {
		&::print_log("[Insteon_Device] " . $self->get_object_name . " adlb [0x$address] is empty");
	}
	
}

sub get_link_record
{
	my ($self,$link_key) = @_;
	my %link_record = {};
	%link_record = %{$$self{adlb}{$link_key}} if $$self{adlb}{$link_key};
	return %link_record;
}

sub update_local_properties
{
	my ($self) = @_;
	$$self{_mem_activity} = 'update_local';
	$self->_peek('0320'); # 0320 is the address for the onlevel
}

sub has_link
{
	my ($self, $insteon_object, $group, $is_controller) = @_;
	my $key = $insteon_object->device_id . $group . $is_controller;
	return (defined $$self{adlb}{$key}) ? 1 : 0;
}

sub _write_link
{
	my ($self, $address, $deviceid, $group, $is_controller, $data1, $data2, $data3) = @_;
	if ($address) {
		&::print_log("[Insteon_Device] " . $self->get_object_name . " address: $address found for device: $deviceid and group: $group");
		# change address for start of change to be address + offset
		if ($$self{_mem_activity} eq 'update') {
			$address = sprintf('%04X',hex($address) + 5);
		}
		$$self{pending_adlb}{address} = $address;
		$$self{pending_adlb}{deviceid} = $deviceid;
		$$self{pending_adlb}{group} = $group;
		$$self{pending_adlb}{is_controller} = $is_controller;
		$$self{pending_adlb}{data1} = (defined $data1) ? $data1 : '00';
		$$self{pending_adlb}{data2} = (defined $data2) ? $data2 : '00';
		# Note: if device is a KeypadLinc, then $data3 must be assigned the value of the applicable button (01)
		if ($$self{devcat} eq '0109') {
			&::print_log("[Insteon_Device] setting data3 to " . $self->group . " for this keypadlinc")
				if $main::Debug{insteon};
			$data3 = $self->group;
		}
		$$self{pending_adlb}{data3} = (defined $data3) ? $data3 : '00';
		$self->_peek($address);
	} else {
		&::print_log("[Insteon_Device] WARN: " . $self->get_object_name 
			. " write_link failure: no address could be found for device: $deviceid and group: $group" .
				" and is_controller: $is_controller");;
	}
}

sub _peek
{
	my ($self, $address, $extended) = @_;
	my $msb = substr($address,0,2);
	my $lsb = substr($address,2,2);
	$self->_send_cmd('command' => 'set_address_msb', 'extra' => $msb, 'is_synchronous' => 1);
	if ($extended) {
		$$self{interface}->set($self->_xlate_mh_insteon('peek','extended',
			$lsb . "0000000000000000000000000000"),$self);
	} else {
		$$self{_mem_lsb} = $lsb;
		$$self{_mem_msb} = $msb;
		$$self{_mem_action} = 'adlb_peek';
	}
}


1;
