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
	Brian Warren for significant testing and patches
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
						on_fast => 0x12,
						off => 0x13,
						off_fast => 0x14,
						bright => 0x15,
						dim => 0x16,
						start_manual_change => 0x17,
						stop_manual_change => 0x18,
						status_request => 0x19,
						get_operating_flags => 0x1f,
						set_operating_flags => 0x20,
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
						off_at_ramp_rate => 0x2f,
						sprinkler_valve_on => 0x40,
						sprinkler_valve_off => 0x41,
						sprinkler_program_on => 0x42,
						sprinkler_program_off => 0x43,
						sprinkler_control => 0x44,
						sprinkler_timers_request => 0x45,
						thermostat_temp_up => 0x68,
						thermostat_temp_down => 0x69,
						thermostat_get_zone_temp => 0x6a,
						thermostat_get_zone_setpoint => 0x6a,
						thermostat_get_zone_humidity => 0x6a,
						thermostat_control => 0x6b,
						thermostat_get_mode => 0x6b,
						thermostat_get_temp => 0x6b,
						thermostat_setpoint_cool => 0x6c,
						thermostat_setpoint_heat => 0x6d
);

my %operating_flags = (
						'program_lock_on' => '00',
						'program_lock_off' => '01',
						'led_on_during_tx' => '02',
						'led_off_during_tx' => '03',
						'resume_dim_on' => '04',
						'beeper_enabled' => '04',
						'resume_dim_off' => '05',
						'beeper_off' => '05',
						'eight_key_kpl' => '06',
						'load_sense_on' => '06',
						'six_key_kpl' => '07',
						'load_sense_off' => '07',
						'led_backlight_off' => '08',
						'led_off' => '08',
						'led_backlight_on' => '09',
						'led_enabled' => '09',
						'key_beep_enabled' => '0a',
						'one_minute_warn_disabled' => '0a',
						'key_beep_off' => '0b',
						'one_minute_warn_enabled' => '0b'
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

sub get_ramp_from_code
{
	my ($ramp_code) = @_;
	if ($ramp_code) {
		return $ramp_h2n{$ramp_code};
	} else {
		return 0;
	}
}

sub convert_level
{
	my ($on_level) = @_;
	my $level = 'ff';
	if (defined ($on_level)) {
		if ($on_level eq '100') {
			$level = 'ff';
		} elsif ($on_level eq '0') {
			$level = '00';
		} else {
			$level = sprintf('%02X',$on_level * 2.55);
		}
	}
	return $level;
}

sub new
{
	my ($class,$p_interface,$p_deviceid,$p_devcat) = @_;
	my $self={};
	bless $self,$class;

	if (defined $p_deviceid) {
		my ($deviceid, $group) = $p_deviceid =~ /(\w\w\.\w\w\.\w\w):?(.+)?/;
		# if a group is passed in, then assume it can be a controller
		$$self{is_controller} = ($group) ? 1 : 0;
		$self->device_id($deviceid);
		$group = '01' unless $group;
		$group = '0' . $group if length($group) == 1;
		$self->group(uc $group);
	}
	if ($p_devcat) {
		$self->devcat($p_devcat);
	} else {
		$self->restore_data('devcat','level');
	}
	$self->initialize();
	$self->rate(undef);
	$$self{level} = undef;
	$$self{flag} = "0F";
	$$self{ackMode} = "1";
	$$self{awaiting_ack} = 0;
	$$self{is_acknowledged} = 0;
	$$self{queue_timer} = new Timer();
	$$self{max_queue_time} = $::config_parms{'Insteon_PLM_max_queue_time'};
	$$self{max_queue_time} = 15 unless $$self{max_queue_time}; # 15 seconds is max time allowed in command stack
	@{$$self{command_stack}} = ();
	$$self{_retry_count} = 0; # num times that a command has been resent
	$$self{_onlevel} = undef;
	if ($p_devcat and (($p_devcat eq '0005') or ($p_devcat eq '1001'))) {
		$$self{is_responder} = 0;
	} else {
		$$self{is_responder} = 1;
	}
	$self->interface($p_interface) if defined $p_interface;
#	$self->interface()->add_item_if_not_present($self);
	return $self;
}

sub initialize
{
	my ($self) = @_;
	$$self{m_write} = 1;
	$$self{m_is_locally_set} = 0;
	# persist local, simple attribs
	$$self{ping_timer} = new Timer();
	$$self{ping_timerTime} = 300;
	$$self{ping_timer}->set($$self{ping_timerTime} + (rand() * $$self{ping_timerTime}), $self) 
		unless $self->group eq '01' and defined $self->devcat;
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

sub is_responder
{
	my ($self,$is_responder) = @_;
	$$self{is_responder} = $is_responder if defined $is_responder;
	return $$self{is_responder};
}

sub is_keypadlinc
{
	my ($self) = @_;
	my $obj = $self->get_root;
	if (($$obj{devcat} eq '0109') or ($$obj{devcat} =~ /010c/i) or ($$obj{devcat} =~ /020f/i)) {
		return 1;
	} else {
		return 0;
	}
}

sub level
{
	my ($self, $p_level) = @_;
	if (defined $p_level) {
		my $level = undef;
		if ($p_level eq 'on')
		{
			# set the level based on any locally defined on level
			$level = &Insteon_Device::local_onlevel;
			# set to 100 if a local on level is not defined
			$level=100 unless defined($level);
		} elsif ($p_level eq 'off')
		{
			$level = 0;
		} elsif ($p_level =~ /^([1]?[0-9]?[0-9])%?$/)
		{
			if ($1 < 1) {
				$level = 0;
			} else {
				$level = ($self->is_dimmable) ? $1 : 100;
			}
		}
		$$self{level} = $level if defined $level;
	}
	return $$self{level};

}

sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;

	if (!($self->is_responder)) {
		# if it can't be controlled (i.e., a responder), then don't send out any signals
		$self->set_receive($p_state,$p_setby);
		return;
	}

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
	} elsif ($self->_is_valid_state($p_state)) {
		# always reset the is_locally_set property
		$$self{m_is_locally_set} = 0;

		# handle invalid state for non-dimmable devices
		if (($p_state eq 'dim' or $p_state eq 'bright') and !($self->is_dimmable)) {
			$p_state = 'on';
		}

		if (ref $p_setby and (($p_setby eq $self->interface()) 
			or ($p_setby->isa('Insteon_Device') and (($p_setby eq $self)
			or (&main::set_by_to_target($p_setby) eq $self->interface)))))
		{
				# don't reset the object w/ the same state if set from the interface
				return if (lc $p_state eq lc $self->state) and $self->is_acknowledged;
				&::print_log("[Insteon_Device] " . $self->get_object_name() 
					. "::set($p_state, $p_setby)") if $main::Debug{insteon};
		} else {
			$self->_send_cmd(command => $p_state, 
				type => (($self->isa('Insteon_Link') and !($self->is_root)) ? 'alllink' : 'standard'));
			&::print_log("[Insteon_Device] " . $self->get_object_name() . "::set($p_state, $p_setby)")
				if $main::Debug{insteon};
			$self->is_acknowledged(0);
		}
		$self->level($p_state); # update the level value
		$self->SUPER::set($p_state,$p_setby,$p_response) if defined $p_state;
	}
}

sub set_with_timer {
	my ($self, $state, $time, $return_state, $additional_return_states) = @_;
	return if &main::check_for_tied_filters($self, $state);

	$self->set($state) unless $state eq '';

	return unless $time;

	my $state_change = ($state eq 'off') ? 'on' : 'off';
	$state_change = $return_state if defined $return_state;
	$state_change = $self->{state} if $return_state and lc $return_state eq 'previous';

	$state_change .= ';' . $additional_return_states if $additional_return_states;

	$$self{timer} = &Timer::new() unless $$self{timer};
	my $object = $self->{object_name};
	my $action = "set $object '$state_change'";
	&Timer::set($$self{timer}, $time, $action);
}

sub link_to_interface
{
	my ($self,$p_group, $p_data3) = @_;
	my $group = $p_group;
	$group = '01' unless $group;
	# add a link first to this device back to interface
	# and, add a reference to creating a link from interface back to device via hook
	my $callback_instance = $self->interface->get_object_name;
	my $callback_info = "deviceid=" . lc $self->device_id . " group=$group is_controller=0";
	my %link_info = ( object => $self->interface, group => $group, is_controller => 1,
		on_level => '100%', ramp_rate => '0.1s', 
		callback => "$callback_instance->add_link('$callback_info')");
	$link_info{data3} = $p_data3 if $p_data3;
	$self->add_link(%link_info);
}

sub unlink_to_interface
{
	my ($self,$p_group) = @_;
	my $group = $p_group;
	$group = '01' unless $group;
	my $callback_instance = $self->interface->get_object_name;
	my $callback_info = "deviceid=" . lc $self->device_id . " group=$group is_controller=0";
	$self->delete_link(object => $self->interface, group => $group, is_controller => 1,
		callback => "$callback_instance->delete_link('$callback_info')");
}

sub queue_timer_callback
{
	my ($self, $callback) = @_;
	$$self{queue_timer_callback} = $callback if defined $callback;
	return $$self{queue_timer_callback};
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
		# for now, be "dumb" and just unset it
		$$self{awaiting_ack} = 0;
		# is there an "on_ack" command to now be performed?  if so, queue it
		if ($ackmsg{on_ack}) {
			# process the on_ack command
			# any new command needs to be pushed on to the queue in front of other pending cmds
		}
	}
	if ($$self{queue_timer}->expired or !($$self{awaiting_ack})) {
		my $callback = undef;
		if ($$self{queue_timer}->expired) {
			if ($$self{_prior_msg} and $$self{_retry_count} < 2) {
				# first check to see if type is an alllink; if so, then don't keep retrying until
				#   proper handling of alllink cleanup status is implemented in Insteon_PLM
				if ($$self{_prior_msg}{type} eq 'alllink' and (!($self->is_plm_controlled))) {
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
				if ($self->queue_timer_callback) {
					if ($$self{_prior_msg} and ($$self{_prior_msg}{is_synchronous})) {
						# get rid of any pending next command as we need to abort
						pop(@{$$self{command_stack}});
					}
					$callback = $self->queue_timer_callback;
					$self->queue_timer_callback(''); # reset to prevent repeat callbacks
				}
			}
		}
		my $cmdptr = pop(@{$$self{command_stack}});
		# convert ptr to cmd hash
		if ($cmdptr) {
			my %cmd = %$cmdptr;
			# convert cmd to insteon message
			my $insteonmsg = $self->_xlate_mh_insteon($cmd{command},$cmd{type},$cmd{extra});
			if (!(defined($insteonmsg))) {
				return;
			}
			my $plm_queue_size = $self->interface()->set($insteonmsg, $self);
			# send msg
			if ($cmd{is_synchronous}) {
				$$self{awaiting_ack} = 1;
			} else {
				$$self{awaiting_ack} = 0;
			}
			# check to see if we are resending the same command; if so, then assume it is a retry and bump the counter
			if ($$self{_prior_msg} and $$self{_prior_msg}{command} eq $cmd{command}) {
				$$self{_retry_count} = ($$self{_retry_count}) ? $$self{_retry_count} + 1 : 1;
				# unless there is a difference in the "extra" field which would be useful for something like repeat peeks
				if (exists($$self{_prior_msg}{extra}) and exists($cmd{extra}) and ($$self{_prior_msg}{extra} ne $cmd{extra})) {
					$$self{_retry_count} = 0;
				}
			} else {
				$$self{_retry_count} = 0;
			}
			%{$$self{_prior_msg}} = %cmd;
			# TO-DO: adjust timer based upon (1) type of message and (2) retry_count
			my $queue_time = $$self{max_queue_time} + $plm_queue_size;
			unless ($self->get_object_name) {
				# needed because the initial startup scan occurs before names are assigned
				$self->set_retry_timeout($queue_time);
			}
#			$$self{queue_timer}->set($queue_time,$self);
			# if is_synchronous, then no other command can be sent until an insteon ack or nack is received
			# for this command
		} else {
			# always unset the timer if no more commands
			$$self{queue_timer}->unset();
			# and, always clear awaiting_ack and _prior_msg
			$$self{awaiting_ack} = 0;
			$$self{_prior_msg} = undef;
		}
		if ($callback) {
			package main;
			eval ($callback);
			&::print_log("[Insteon_Device] error in queue timer callback: " . $@)
				if $@ and $main::Debug{insteon};
			package Insteon_Device;
		}
	} else {
		&::print_log("[Insteon_Device] " . $self->get_object_name . " command queued but not yet sent; awaiting ack from prior command") if $main::Debug{insteon};
	}
}

sub set_operating_flag {
	my ($self, $flag) = @_;

	if (!(exists($operating_flags{$flag}))) {
		&::print_log("[Insteon_Device] $flag is not a support operating flag");
		return;
	}

	if ($self->is_root and !($self->is_plm_controlled)) {
		# TO-DO: check devcat to determine if the action is supported by the device
		$self->_send_cmd('command' => 'set_operating_flags', 'extra' => $operating_flags{$flag});
        } else {
		&::print_log("[Insteon_Device] " . $self->get_object_name . " is either not a root device or is a plm controlled scene");
		return;
	}
}

sub get_operating_flag {
	my ($self) = @_;

	if ($self->is_root and !($self->is_plm_controlled)) {
		# TO-DO: check devcat to determine if the action is supported by the device
		$self->_send_cmd('command' => 'get_operating_flags');
        } else {
		&::print_log("[Insteon_Device] " . $self->get_object_name . " is either not a root device or is a plm controlled scene");
		return;
	}
}


sub set_retry_timeout {
	my ($self, $timeout) = @_;
#print "########## now setting " . $self->get_object_name . " retry timeout to $$self{max_queue_time} seconds\n";
	my $timer_value = $timeout;
	$timer_value = $$self{max_queue_time} unless $timer_value;
	$$self{queue_timer}->set($timer_value,$self);
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

sub is_plm_controlled {
	my ($self) = @_;
	return ($self->device_id eq '000000') ? 1 : 0;
}

sub is_root {
	my ($self) = @_;
	return (($self->group eq '01') and !($self->is_plm_controlled)) ? 1 : 0;
}

sub get_root {
	my ($self) = @_;
	if ($self->is_root) {
		return $self;
	} else {
		return $self->interface->get_object($self->device_id, '01');
	}
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
	my ($self, $requestor) = @_;
	$$self{m_status_request_pending} = ($requestor) ? $requestor : 1;
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

sub _is_valid_state
{
	my ($self,$state) = @_;
	if (!(defined($state)) or $state eq '') {
		return 0;
	}

	my ($msg, $substate) = split(/:/, $state, 2);
	$msg=lc($msg);

	if ($msg=~/^([1]?[0-9]?[0-9])/)
	{
		if ($1 < 1) {
			$msg='off';
		} else {
			$msg='on';
		}
	}

	# confirm that the resulting $msg is legitimate
	if (!(defined($message_types{$msg}))) {
		return 0;
	} else {
		return 1;
	}
}

sub _is_info_request
{
	my ($self, $cmd, $ack_setby, %msg) = @_;
	my $is_info_request = ($cmd eq 'status_request') ? 1 : 0;
#print "cmd: $cmd; is_info_request: $is_info_request\n";
	if ($is_info_request) {
		my $ack_on_level = (hex($msg{extra}) >= 254) ? 100 : sprintf("%d", hex($msg{extra}) * 100 / 255);
		&::print_log("[Insteon_Device] received status request report for " .
			$self->{object_name} . " with on-level: $ack_on_level%, "
			. "hops left: $msg{hopsleft}") if $main::Debug{insteon};
		$self->level($ack_on_level); # update the level value
		if ($ack_on_level == 0) {
			$self->SUPER::set('off', $ack_setby);
		} elsif ($ack_on_level > 0 and !($self->is_dimmable)) {
			$self->SUPER::set('on', $ack_setby);
		} else {
			$self->SUPER::set($ack_on_level . '%', $ack_setby);
		}
	}
	return $is_info_request;

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
		if ($$self{awaiting_ack}) {
			my $pending_cmd = ($$self{_prior_msg}) ? $$self{_prior_msg}{command} : $msg{command};
			my $ack_setby = (ref $$self{m_status_request_pending}) 
				? $$self{m_status_request_pending} : $p_setby;
			if ($self->_is_info_request($pending_cmd,$ack_setby,%msg)) {
				$self->is_acknowledged(1);
				$$self{m_status_request_pending} = 0;
				$self->_process_command_stack(%msg);
			} elsif (($pending_cmd eq 'peek') or ($pending_cmd eq 'set_address_msb')) {
				$self->_on_peek(%msg);
				$self->_process_command_stack(%msg);
			} elsif (($pending_cmd eq 'poke') or ($pending_cmd eq 'set_address_msb')) {
				$self->_on_poke(%msg);
				$self->_process_command_stack(%msg);
			} else {
				$self->is_acknowledged(1);
				# signal receipt of message to the command stack in case commands are queued
				$self->_process_command_stack(%msg);
				&::print_log("[Insteon_Device] received command/state (awaiting) acknowledge from " . $self->{object_name} 
					. ": $pending_cmd and data: $msg{extra}") if $main::Debug{insteon};
			} 
		} else {
			$self->is_acknowledged(1);
			# signal receipt of message to the command stack in case commands are queued
			$self->_process_command_stack(%msg);
			&::print_log("[Insteon_Device] received command/state acknowledge from " . $self->{object_name} 
				. ": " . (($msg{command}) ? $msg{command} : "(unknown)")
				. " and data: $msg{extra}") if $main::Debug{insteon};
		}
	} elsif ($msg{is_nack}) {
		if ($$self{awaiting_ack}) {
			&::print_log("[Insteon_Device] WARN!! encountered a nack message for " . $self->{object_name} 
				. " ... waiting for retry");
		} else {
			&::print_log("[Insteon_Device] WARN!! encountered a nack message for " . $self->{object_name} 
				. " ... skipping");
			$self->is_acknowledged(0);
			$self->_process_command_stack(%msg);
		}
	} elsif ($msg{command} eq 'start_manual_change') {
		# do nothing; although, maybe anticipate change? we should always get a stop
	} elsif ($msg{command} eq 'stop_manual_change') {
		$self->request_status($self);
	} elsif ($msg{type} eq 'broadcast') {
		$self->devcat($msg{devcat});
		&::print_log("[Insteon_Device] device category: $msg{devcat} received for " . $self->{object_name});
		# stop ping timer now that we have a devcat; possibly may want to change this behavior to allow recurring pings
		$$self{ping_timer}->stop();
	} else {
		## TO-DO: make sure that the state passed by command is something that is reasonable to set
		$p_state = $msg{command};
		$$self{_pending_cleanup} = 1 if $msg{type} eq 'alllink';
#		$self->set($p_state, $p_setby) unless (lc($self->state) eq lc($p_state)) and 
		$self->set($p_state, $self) unless (lc($self->state) eq lc($p_state)) and 
			($msg{type} eq 'cleanup' and $$self{_pending_cleanup});
		$$self{_pending_cleanup} = 0 if $msg{type} eq 'cleanup';
	}
}

sub _xlate_insteon_mh
{
	my ($p_state) = @_;
	my %msg = ();
	my $hopflag = hex(uc substr($p_state,13,1));
	$msg{hopsleft} = $hopflag >> 2;
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
	my $level;

	#msg id
	my ($msg, $substate) = split(/:/, $p_state, 2);
	$msg=lc($msg);
#	&::print_log("XLATE:$msg:$substate:$p_state:");

	if (!(defined $p_extra)) {
		if ($msg eq 'on')
		{
			if (defined $self->local_onlevel) {
				$level = 2.55 * $self->local_onlevel;
				$msg = 'on_fast';
			} else {
				$level=255;
			}
		} elsif ($msg eq 'off')
		{
			$level = 0;
		} elsif ($msg=~/^([1]?[0-9]?[0-9])/)
		{
			if ($1 < 1) {
				$msg='off';
				$level = 0;
			} else {
				$level = ($self->is_dimmable) ? $1 * 2.55 : 255;
				$msg='on';
			}
		}
	}

	# confirm that the resulting $msg is legitimate
	if (!(defined($message_types{$msg}))) {
		&::print_log("[Insteon_Device] invalid state=$msg") if $main::Debug{insteon};
		return undef;
	}

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
	} elsif ($substate) {
		$cmd.= $substate;
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
			# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
			my $subaddress = $$self{pending_adlb}{data3};
			if (($subaddress ne '00') and ($subaddress ne '01')) {
				$adlbkey .= $subaddress;
			}
			$$self{adlb}{$adlbkey}{data1} = $$self{pending_adlb}{data1};
			$$self{adlb}{$adlbkey}{data2} = $$self{pending_adlb}{data2};
			$$self{adlb}{$adlbkey}{data3} = $$self{pending_adlb}{data3};
			$$self{adlb}{$adlbkey}{inuse} = 1; # needed so that restore string will preserve record
			if ($$self{_mem_activity} eq 'add') {
				$$self{adlb}{$adlbkey}{is_controller} = $$self{pending_adlb}{is_controller};
				$$self{adlb}{$adlbkey}{deviceid} = lc $$self{pending_adlb}{deviceid};
				$$self{adlb}{$adlbkey}{group} = lc $$self{pending_adlb}{group};
				$$self{adlb}{$adlbkey}{address} = $$self{pending_adlb}{address};
				# on completion, check to see if the empty links list is now empty; if so, 
				# then decrement the current address and add it to the list
				my $num_empty = @{$$self{adlb}{empty}};
				if (!($num_empty)) {
					my $low_address = 0;
					for my $key (keys %{$$self{adlb}}) {
						next if $key eq 'empty' or $key eq 'duplicates';
						my $new_address = hex($$self{adlb}{$key}{address});
						if (!($low_address)) {
							$low_address = $new_address;
							next;
						} else {
							$low_address = $new_address if $new_address < $low_address;
						}
					}
					$low_address = sprintf('%04X', $low_address - 8);
					unshift @{$$self{adlb}{empty}}, $low_address;
				}
			}
			# clear out mem_activity flag
			$$self{_mem_activity} = undef;
			if (defined $$self{_mem_callback}) {
				my $callback = $$self{_mem_callback};
				# clear it out *before* the eval
				$$self{_mem_callback} = undef;
				package main;
				eval ($callback);
				package Insteon_Device;
				&::print_log("[Insteon_Device] error in link callback: " . $@) 
					if $@ and $main::Debug{insteon};
			}
		}
	} elsif ($$self{_mem_activity} eq 'update_local') {
		if ($$self{_mem_action} eq 'local_onlevel') {
			$$self{_mem_lsb} = '21';
			$$self{_mem_action} = 'local_ramprate';
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'local_ramprate') {
			if ($self->is_keypadlinc) {
				# update from eeprom--only a kpl issue
				$self->_send_cmd('command' => 'do_read_ee','is_synchronous' => 1);
			}
		}
	} elsif ($$self{_mem_activity} eq 'update_flags') {
		# update from eeprom--only a kpl issue
		$self->_send_cmd('command' => 'do_read_ee','is_synchronous' => 1);
	} elsif ($$self{_mem_activity} eq 'delete') {
		# clear out mem_activity flag
		$$self{_mem_activity} = undef;
		# add the address of the deleted link to the empty list
		push @{$$self{adlb}{empty}}, $$self{pending_adlb}{address};
		if (exists $$self{pending_adlb}{deviceid}) {
			my $key = lc $$self{pending_adlb}{deviceid} . $$self{pending_adlb}{group} . $$self{pending_adlb}{is_controller};
			# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
			my $subaddress = $$self{pending_adlb}{data3};
			if ($subaddress ne '00' and $subaddress ne '01') {
				$key .= $subaddress;
			}
			delete $$self{adlb}{$key};
		}

		if (defined $$self{_mem_callback}) {
			my $callback = $$self{_mem_callback};
			# clear it out *before* the eval
			$$self{_mem_callback} = undef;
			package main;
			eval ($callback);
			&::print_log("[Insteon_Device] error in link callback: " . $@) 
				if $@ and $main::Debug{insteon};
			package Insteon_Device;
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
				# if the device is responding to the peek, then init the link table
				#   if at the very start of a scan
				if (lc $$self{_mem_msb} eq '0f' and lc $$self{_mem_lsb} eq 'f8') {
					# reinit the adlb hash as there will be a new one
					$$self{adlb} = undef;
					# reinit the empty address list
					@{$$self{adlb}{empty}} = ();
					# and, also the duplicates list
					@{$$self{adlb}{duplicates}} = ();
				}
			} elsif ($$self{_mem_activity} eq 'update') {
				$$self{_mem_action} = 'adlb_data1';
			} elsif ($$self{_mem_activity} eq 'update_local') {
				$$self{_mem_action} = 'local_onlevel';
			} elsif ($$self{_mem_activity} eq 'update_flags') {
				$$self{_mem_action} = 'update_flags';
			} elsif ($$self{_mem_activity} eq 'delete') {
				$$self{_mem_action} = 'adlb_flag';
			} elsif ($$self{_mem_activity} eq 'add') {
				$$self{_mem_action} = 'adlb_flag';
			}
			$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'adlb_flag') {
			if ($$self{_mem_activity} eq 'scan') {
				my $flag = hex($msg{extra});
				$$self{pending_adlb}{inuse} = ($flag & 0x80) ? 1 : 0;
				$$self{pending_adlb}{is_controller} = ($flag & 0x40) ? 1 : 0;
				$$self{pending_adlb}{highwater} = ($flag & 0x02) ? 1 : 0;
				if (!($$self{pending_adlb}{highwater})) {
					# since this is the last unused memory location, then add it to the empty list
					unshift @{$$self{adlb}{empty}}, $$self{_mem_msb} . $$self{_mem_lsb};
					$$self{_mem_action} = undef;
					# clear out mem_activity flag
					$$self{_mem_activity} = undef;
					&::print_log("[Insteon_Device] " . $self->get_object_name . " completed link memory scan")
						if $main::Debug{insteon};
					if (defined $$self{_mem_callback}) {
						package main;
						eval ($$self{_mem_callback});
						&::print_log("[Insteon_Device] " . $self->get_object_name . ": error during scan callback $@")
							if $@ and $main::Debug{insteon};
						package Insteon_Device;
						$$self{_mem_callback} = undef;
					}
					# ping the device as part of the scan if we don't already have a devcat
					if (!($self->{devcat})) {
						$self->ping();
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
				$$self{pending_adlb}{group} = lc $msg{extra};
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
				$$self{pending_adlb}{deviceid} = lc $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'adlb_devmid';
				$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
			} elsif ($$self{_mem_activity} eq 'add') {
				my $devid = substr($$self{pending_adlb}{deviceid},0,2);
				$self->_send_cmd('command' => 'poke', 'extra' => $devid, 'is_synchronous' => 1);
			}
		} elsif ($$self{_mem_action} eq 'adlb_devmid') {
			if ($$self{_mem_activity} eq 'scan') {
				$$self{pending_adlb}{deviceid} .= lc $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'adlb_devlo';
				$self->_send_cmd('command' => 'peek', 'extra' => $$self{_mem_lsb}, 'is_synchronous' => 1);
			} elsif ($$self{_mem_activity} eq 'add') {
				my $devid = substr($$self{pending_adlb}{deviceid},2,2);
				$self->_send_cmd('command' => 'poke', 'extra' => $devid, 'is_synchronous' => 1);
			}
		} elsif ($$self{_mem_action} eq 'adlb_devlo') {
			if ($$self{_mem_activity} eq 'scan') {
				$$self{pending_adlb}{deviceid} .= lc $msg{extra};
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
						my $adlbkey = lc $$self{pending_adlb}{deviceid} 
							. $$self{pending_adlb}{group}
							. $$self{pending_adlb}{is_controller};
						# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
						my $subaddress = $$self{pending_adlb}{data3};
						if ($subaddress ne '00' and $subaddress ne '01') {
							$adlbkey .= $subaddress;
						}
						# check for duplicates
						if (exists $$self{adlb}{$adlbkey}) {
							unshift @{$$self{adlb}{duplicates}}, $$self{pending_adlb}{address};
						} else {
							%{$$self{adlb}{$adlbkey}} = %{$$self{pending_adlb}};
						}
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
			my $on_level = $self->local_onlevel;
			$on_level = &Insteon_Device::convert_level($on_level);
			$self->_send_cmd('command' => 'poke', 'extra' => $on_level, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'local_ramprate') {
			my $ramp_rate = $$self{_ramprate};
			$ramp_rate = '1f' unless $ramp_rate;
			$self->_send_cmd('command' => 'poke', 'extra' => $ramp_rate, 'is_synchronous' => 1);
		} elsif ($$self{_mem_action} eq 'update_flags') {
			my $flags = $$self{_operating_flags};
			$self->_send_cmd('command' => 'poke', 'extra' => $flags, 'is_synchronous' => 1);
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
			next unless $adlb_key eq 'empty' || $adlb_key eq 'duplicates' || $$self{adlb}{$adlb_key}{inuse};
			$adlb .= '|' if $adlb; # separate sections
			my $record = '';
			if ($adlb_key eq 'empty') {
				foreach my $address (@{$$self{adlb}{empty}}) {
					$record .= ';' if $record;
					$record .= $address;
				}
				$record = 'empty=' . $record;
			} elsif ($adlb_key eq 'duplicates') {
				my $duplicate_record = '';
				foreach my $address (@{$$self{adlb}{duplicates}}) {
					$duplicate_record .= ';' if $duplicate_record;
					$duplicate_record .= $address;
				}
				$record = 'duplicates=' . $duplicate_record;
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
	if ($$self{states}) {
		my $states = '';
		foreach my $state (@{$$self{states}}) {
			$states .= '|' if $states;
			$states .= $state;
		}
		$restore_string .= $self->{object_name} . "->restore_states(q~$states~);\n";
	}
	return $restore_string;
}

sub restore_states
{
	my ($self, $states) = @_;
	if ($states) {
		@{$$self{states}} = split(/\|/,$states);
	}
}

sub restore_adlb
{
	my ($self,$adlb) = @_;
	if ($adlb) {
		foreach my $adlb_section (split(/\|/,$adlb)) {
			my %adlb_record = ();
			my @adlb_empty = ();
			my @adlb_duplicates = ();
			my $deviceid = '';
			my $groupid = '01';
			my $is_controller = 0;
			my $subaddress = '00';
			foreach my $adlb_record (split(/,/,$adlb_section)) {
				my ($key,$value) = split(/=/,$adlb_record);
				next unless $key and defined($value) and $value ne '';
				if ($key eq 'empty') {
					@adlb_empty = split(/;/,$value);
				} elsif ($key eq 'duplicates') {
					@adlb_duplicates = split(/;/,$value);
				} else {
					$deviceid = lc $value if ($key eq 'deviceid');
					$groupid = lc $value if ($key eq 'group');
					$is_controller = $value if ($key eq 'is_controller');
					$subaddress = $value if ($key eq 'data3');
					$adlb_record{$key} = $value if $key and defined($value);
				}
			}
			if (@adlb_empty) {
				@{$$self{adlb}{empty}} = @adlb_empty;
			} elsif (@adlb_duplicates) {
				@{$$self{adlb}{duplicates}} = @adlb_duplicates;
			} else {
				next unless $deviceid;
				my $adlbkey = $deviceid . $groupid . $is_controller;
				# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
				if ($subaddress ne '00' and $subaddress ne '01') {
					$adlbkey .= $subaddress;
				}
				%{$$self{adlb}{$adlbkey}} = %adlb_record;
			}
		}
#		$self->log_alllink_table();
	}
}

sub devcat
{
	my ($self, $devcat) = @_;
	if ($devcat) {
		$$self{devcat} = $devcat;
		if (($$self{devcat} =~ /^01\w\w/) or ($$self{devcat} =~ /^02\w\w/) && !($self->states)) {
			$self->states( 'on,off' );
		}
	}
	return $$self{devcat};
}

sub states
{
	my ($self, $states) = @_;
	if ($states) {
		@{$$self{states}} = split(/,/,$states);
	}
	if ($$self{states}) {
		return @{$$self{states}};
	} else {
		return undef;
	}

}

sub is_dimmable
{
	my ($self) = @_;
	if (!($self->is_root)) {
		return 0;
	} else {
		if ($$self{devcat}) {
			if ($$self{devcat} =~ /^01\w\w/) {
				return 1;
			} else {
				return 0;
			}
		} else {
			&::print_log("[Insteon_Device] WARN: making assumption that " . $self->get_object_name . " is dimmable because devcat is not yet known")
				if $main::Debug{insteon};
			return 1;
		}
	}
}

sub local_onlevel
{
	my ($self, $p_onlevel) = @_;
	if (defined $p_onlevel) {
		my ($onlevel) = $p_onlevel =~ /(\d+)%?/;
		$$self{_onlevel} = $onlevel;
	}
	return $$self{_onlevel};
}

sub local_ramprate
{
	my ($self, $p_ramprate) = @_;
	if (defined $p_ramprate) {
		$$self{_ramprate} = &Insteon_Device::convert_ramp($p_ramprate);
	}
	return $$self{_ramprate};

}

sub set_receive
{
	my ($self, $p_state, $p_setby, $p_response) = @_;
	$self->level($p_state); # update the level value
	$self->SUPER::set($p_state, $p_setby, $p_response);
}

sub scan_link_table
{
	my ($self,$callback) = @_;
	$$self{_mem_activity} = 'scan';
	$$self{_mem_callback} = ($callback) ? $callback : undef;
	$self->_peek('0FF8',0);
}

sub delete_link
{
	my ($self, $parms_text) = @_;
	my %link_parms;
	if (@_ > 2) {
		shift @_;
		%link_parms = @_;
	} else {
		%link_parms = &main::parse_func_parms($parms_text);
	}
	if ($link_parms{address}) {
		$$self{_mem_callback} = ($link_parms{callback}) ? $link_parms{callback} : undef;
		$$self{_mem_activity} = 'delete';
		$$self{pending_adlb}{address} = $link_parms{address};
		$self->_peek($link_parms{address},0);
	
	} else {
		my $insteon_object = $link_parms{object};
		my $deviceid = ($insteon_object) ? $insteon_object->device_id : $link_parms{deviceid};
		my $groupid = $link_parms{group};
		$groupid = '01' unless $groupid;
		my $is_controller = ($link_parms{is_controller}) ? 1 : 0;
		my $subaddress = ($link_parms{data3}) ? $link_parms{data3} : '00';
		# get the address via lookup into the hash
		my $key = lc $deviceid . $groupid . $is_controller;
		# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
		if ($subaddress ne '00' and $subaddress ne '01') {
			$key .= $subaddress;
		}
		my $address = $$self{adlb}{$key}{address};
		if ($address) {
			&main::print_log("[Insteon_Device] Now deleting link [0x$address] with the following data"
				. " deviceid=$deviceid, groupid=$groupid, is_controller=$is_controller");
			# now, alter the flags byte such that the in_use flag is set to 0
			$$self{_mem_callback} = ($link_parms{callback}) ? $link_parms{callback} : undef;
			$$self{_mem_activity} = 'delete';
			$$self{pending_adlb}{deviceid} = lc $deviceid;
			$$self{pending_adlb}{group} = $groupid;
			$$self{pending_adlb}{is_controller} = $is_controller;
			$$self{pending_adlb}{address} = $address;
			$self->_peek($address,0);
		} else {
			&main::print_log('[Insteon_Device] WARN: (' . $self->get_object_name . ') attempt to delete link that does not exist!'
				. " deviceid=$deviceid, groupid=$groupid, is_controller=$is_controller");
			if ($link_parms{callback}) {
				package main;
				eval($link_parms{callback});
				&::print_log("[Insteon_Device] error encountered during delete_link callback: " . $@)
					if $@ and $main::Debug{insteon};
				package Insteon_Device;
			}
		}
	}
}

sub delete_orphan_links
{
	my ($self) = @_;
	@{$$self{delete_queue}} = (); # reset the work queue
	my $selfname = $self->get_object_name;
	my $num_deleted = 0;
	for my $linkkey (keys %{$$self{adlb}}) {
		if ($linkkey ne 'empty' and $linkkey ne 'duplicates') {
			my $deviceid = lc $$self{adlb}{$linkkey}{deviceid};
			next unless $deviceid;
			my $group = $$self{adlb}{$linkkey}{group};
			my $is_controller = $$self{adlb}{$linkkey}{is_controller};
			my $data3 = $$self{adlb}{$linkkey}{data3};
			my $device = ($deviceid eq lc $self->interface->device_id) ? $self->interface
					: $self->interface->get_object($deviceid,'01');
			if (!($device)) {
#				&::print_log("[Insteon_Device] " . $self->get_object_name . " now deleting orphaned link w/ details: "
#					. (($is_controller) ? "controller" : "responder")
#					. ", deviceid=$deviceid, group=$group");
				my %delete_req = (deviceid => $deviceid, group => $group, is_controller => $is_controller,
							callback => "$selfname->_process_delete_queue()", cause => "no device could be found");
				push @{$$self{delete_queue}}, \%delete_req;
			} elsif ($device->isa("Insteon_PLM") and $is_controller) {
				# ignore since this is just a link back to the PLM
			} elsif ($device->isa("Insteon_PLM")) {
				# does the PLM have a link point back?  If not, the delete this one
				if (!($device->has_link($self,$group,1))) {
					my %delete_req = (deviceid => $deviceid, group => $group, is_controller => $is_controller,
							callback => "$selfname->_process_delete_queue()", object => $device, data3 => $data3);
					push @{$$self{delete_queue}}, \%delete_req;
					$num_deleted++;
				}
				# is there an entry in the items.mht that corresponds to this link?
				if ($is_controller) {
					# TO-DO: handle this case
				} else {
					my $plm_link = $device->get_device('000000',$group);
					if ($plm_link) {
						my $is_invalid = 1;
						foreach my $member_ref (keys %{$$plm_link{members}}) {
							my $member = $$plm_link{members}{$member_ref}{object};
							if ($member->isa('Light_Item')) {
								my @lights = $member->find_members('Insteon_Device');
								if (@lights) {
									$member = @lights[0]; # pick the first
								}
							}
							if ($member->device_id eq $self->device_id) {
								if ($data3 eq '00' or (lc $data3 eq lc $member->group)) {
								$is_invalid = 0;
								last;
								}
							}
						}
						if ($is_invalid) {
							my %delete_req = (deviceid => $deviceid, group => $group, is_controller => $is_controller,
								callback => "$selfname->_process_delete_queue()", object => $device,
								cause => "no link is defined for the plm controlled scene", data3 => $data3);
							push @{$$self{delete_queue}}, \%delete_req;
							$num_deleted++;
						}
					} else {
						# delete the link since it doesn't exist
						my %delete_req = (deviceid => $deviceid, group => $group, is_controller => $is_controller,
							callback => "$selfname->_process_delete_queue()", object => $device,
							cause => "no plm link could be found", data3 => $data3);
						push @{$$self{delete_queue}}, \%delete_req;
						$num_deleted++;
					}
				}
			} else {
				if (!($device->has_link($self,$group,($is_controller) ? 0:1, $data3))) {
					my %delete_req = (deviceid => $deviceid, group => $group, is_controller => $is_controller,
							callback => "$selfname->_process_delete_queue()", object => $device,
							cause => "no link to the device could be found", data3 => $data3);
					push @{$$self{delete_queue}}, \%delete_req;
					$num_deleted++;
				} else {
					my $is_invalid = 1;
					my $link = ($is_controller) ? $self->interface->get_object($self->device_id,$group) 
						: $self->interface->get_object($device->device_id,$group);
					if ($link) {
						foreach my $member_ref (keys %{$$link{members}}) {
							my $member = $$link{members}{$member_ref}{object};
							if ($member->isa('Light_Item')) {
								my @lights = $member->find_members('Insteon_Device');
								if (@lights) {
									$member = @lights[0]; # pick the first
								}
							}
							if ($member->isa('Insteon_Device') and !($member->is_root)) {
								$member = $member->get_root;
							}
							if ($member->isa('Insteon_Device') and !($is_controller) and ($member->device_id eq $self->device_id)) {
								$is_invalid = 0;
								last;
							} elsif ($member->isa('Insteon_Device') and $is_controller and ($member->device_id eq $device->device_id)) {
								$is_invalid = 0;
								last;
							}

						}
					}
					if ($is_invalid) {
						my %delete_req = (deviceid => $deviceid, group => $group, is_controller => $is_controller,
							callback => "$selfname->_process_delete_queue()", object => $device,
							cause => "no reverse link could be found", data3 => $data3);
						push @{$$self{delete_queue}}, \%delete_req;
						$num_deleted++;
					}
				}
			}
		} elsif ($linkkey eq 'duplicates') {
			my $address = pop @{$$self{adlb}{duplicates}};
			while ($address) {
				my %delete_req = (address => $address,
					callback => "$selfname->_process_delete_queue()", 
					cause => "duplicate record found");
				push @{$$self{delete_queue}}, \%delete_req;
				$num_deleted++;
				$address = pop @{$$self{adlb}{duplicates}};
			}
		}
	}
	$$self{delete_queue_processed} = 0;
	$self->_process_delete_queue();
	return $num_deleted;
}

sub _process_delete_queue {
	my ($self) = @_;
	my $num_in_queue = @{$$self{delete_queue}};
	if ($num_in_queue) {
		my $delete_req_ptr = shift(@{$$self{delete_queue}});
		my %delete_req = %$delete_req_ptr;
		if ($delete_req{address}) {
			&::print_log("[Insteon_Device] " . $self->get_object_name . " now deleting duplicate record at address "
				. $delete_req{address});
		} else {
			&::print_log("[Insteon_Device] " . $self->get_object_name . " now deleting orphaned link w/ details: "
				. (($delete_req{is_controller}) ? "controller" : "responder")
				. ", " . (($delete_req{object}) ? "device=" . $delete_req{object}->get_object_name 
				: "deviceid=$delete_req{deviceid}") . ", group=$delete_req{group}, cause=$delete_req{cause}");
		}
		$self->delete_link(%delete_req);
		$$self{delete_queue_processed}++;
	} else {
		$self->interface->_process_delete_queue($$self{delete_queue_processed});
	}
}

sub add_link
{
	my ($self, $parms_text) = @_;
	my %link_parms;
	if (@_ > 2) {
		shift @_;
		%link_parms = @_;
	} else {
		%link_parms = &main::parse_func_parms($parms_text);
	}
	my $device_id;
	my $insteon_object = $link_parms{object};
	my $group = $link_parms{group};
	if (!(defined($insteon_object))) {
		$device_id = lc $link_parms{deviceid};
		$insteon_object = $self->interface->get_object($device_id, $group);
	} else {
		$device_id = lc $insteon_object->device_id;
	}
	my $is_controller = ($link_parms{is_controller}) ? 1 : 0;
	# check whether the link already exists
	my $subaddress = ($link_parms{data3}) ? $link_parms{data3} : '00';
	# get the address via lookup into the hash
	my $key = lc $device_id . $group . $is_controller;
	# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
	if ($subaddress ne '00' and $subaddress ne '01') {
		$key .= $subaddress;
	}
	if (defined $$self{adlb}{$key}) {
		&::print_log("[Insteon_Device] WARN: attempt to add link to " . $self->get_object_name . " that already exists! "
			. "object=" . $insteon_object->get_object_name . ", group=$group, is_controller=$is_controller");
		if ($link_parms{callback}) {
			package main;
			eval($link_parms{callback});
			&::print_log("[Insteon_Device] failure occurred in callback eval for " . $self->get_object_name . ":" . $@)
				if $@ and $main::Debug{insteon};
			package Insteon_Device;
		}
	} else {
		# strip optional % sign to append on_level
		my $on_level = $link_parms{on_level};
		$on_level =~ s/(\d)%?/$1/;
		$on_level = '100' unless defined($on_level); # 100% == on is the default
		# strip optional s (seconds) to append ramp_rate
		my $ramp_rate = $link_parms{ramp_rate};
		$ramp_rate =~ s/(\d)s?/$1/;
		$ramp_rate = '0.1' unless $ramp_rate; # 0.1s is the default
		&::print_log("[Insteon_Device] adding link record " . $self->get_object_name 
			. " light level controlled by " . $insteon_object->get_object_name
			. " and group: $group with on level: $on_level and ramp rate: $ramp_rate") if $main::Debug{insteon};
		my $data1 = &Insteon_Device::convert_level($on_level);
		my $data2 = ($self->is_dimmable) ? &Insteon_Device::convert_ramp($ramp_rate) : '00';
		my $data3 = ($link_parms{data3}) ? $link_parms{data3} : '00';
		# get the first available memory location
		my $address = pop @{$$self{adlb}{empty}};
		# TO-DO: ensure that pop'd address is restored back to queue if the transaction fails
		$$self{_mem_activity} = 'add';
		$$self{_mem_callback} = ($link_parms{callback}) ? $link_parms{callback} : undef;
		$self->_write_link($address, $device_id, $group, $is_controller, $data1, $data2, $data3);
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
	$on_level =~ s/(\d+)%?/$1/;
	# strip optional s (seconds) to append ramp_rate
	my $ramp_rate = $link_parms{ramp_rate};
	$ramp_rate =~ s/(\d)s?/$1/;
	&::print_log("[Insteon_Device] updating " . $self->get_object_name . " light level controlled by " . $insteon_object->get_object_name
		. " and group: $group with on level: $on_level and ramp rate: $ramp_rate") if $main::Debug{insteon};
	my $data1 = sprintf('%02X',$on_level * 2.55);
	$data1 = 'ff' if $on_level eq '100';
	$data1 = '00' if $on_level eq '0';
	my $data2 = ($self->is_dimmable) ? &Insteon_Device::convert_ramp($ramp_rate) : '00';
	my $data3 = ($link_parms{data3}) ? $link_parms{data3} : '00';
	my $deviceid = $insteon_object->device_id;
	my $subaddress = $data3;
	# get the address via lookup into the hash
	my $key = lc $deviceid . $group . $is_controller;
	# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
	if ($subaddress ne '00' and $subaddress ne '01') {
		$key .= $subaddress;
	}
	my $address = $$self{adlb}{$key}{address};
	$$self{_mem_activity} = 'update';
	$$self{_mem_callback} = ($link_parms{callback}) ? $link_parms{callback} : undef;
	$self->_write_link($address, $deviceid, $group, $is_controller, $data1, $data2, $data3);
}


sub log_alllink_table
{
	my ($self) = @_;
	&::print_log("[Insteon_Device] link table for " . $self->get_object_name . " (devcat: $$self{devcat}):");
	foreach my $adlbkey (sort(keys(%{$$self{adlb}}))) {
		next if $adlbkey eq 'empty' or $adlbkey eq 'duplicates';
		my ($device);
		my $is_controller = $$self{adlb}{$adlbkey}{is_controller};
		if ($self->interface()->device_id() and ($self->interface()->device_id() eq $$self{adlb}{$adlbkey}{deviceid})) {
			$device = $self->interface;
		} else {
			$device = $self->interface()->get_object($$self{adlb}{$adlbkey}{deviceid},'01');
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

		my $rspndr_group = $$self{adlb}{$adlbkey}{data3};
		$rspndr_group = '01' if $rspndr_group eq '00';
	
		my $ramp_rate = 'unknown';
		if ($$self{adlb}{$adlbkey}{data2}) {
			if (!($self->is_dimmable) or (!($is_controller) and ($rspndr_group != '01'))) {
				$ramp_rate = 'none';
				if ($on_level eq '0%') {
					$on_level = 'off';
				} else {
					$on_level = 'on';
				}
			} else {
				$ramp_rate = $ramp_h2n{$$self{adlb}{$adlbkey}{data2}} . "s";
			}
		}

		&::print_log("[Insteon_Device] aldb $adlbkey [0x" . $$self{adlb}{$adlbkey}{address} . "] " .
			(($$self{adlb}{$adlbkey}{is_controller}) ? "contlr($$self{adlb}{$adlbkey}{group}) record to "
			. $object_name . "($rspndr_group), (d1:$$self{adlb}{$adlbkey}{data1}, d2:$$self{adlb}{$adlbkey}{data2}, d3:$$self{adlb}{$adlbkey}{data3})"
			: "rspndr($rspndr_group) record to " . $object_name . "($$self{adlb}{$adlbkey}{group})"
			. ": onlevel=$on_level and ramp=$ramp_rate (d3:$$self{adlb}{$adlbkey}{data3})")) if $main::Debug{insteon};
	}
	foreach my $address (@{$$self{adlb}{empty}}) {
		&::print_log("[Insteon_Device] adlb [0x$address] is empty");
	}

	foreach my $address (@{$$self{adlb}{duplicates}}) {
		&::print_log("[Insteon_Device] adlb [0x$address] holds a duplicate entry");
	}

}

sub get_link_record
{
	my ($self,$link_key) = @_;
	my %link_record = ();
	%link_record = %{$$self{adlb}{$link_key}} if $$self{adlb}{$link_key};
	return %link_record;
}

sub update_local_properties
{
	my ($self) = @_;
	if ($self->is_dimmable) {
		$$self{_mem_activity} = 'update_local';
		$self->_peek('0032'); # 0032 is the address for the onlevel
	} else {
		&::print_log("[Insteon_Device] update_local_properties may only be applied to dimmable devices!");
	}
}

sub update_flags
{
	my ($self, $flags) = @_;
	if (!($self->is_keypadlinc)) {
		&::print_log("[Insteon_Device] Operating flags may only be revised on keypadlincs!");
		return;
	}
	return unless defined $flags;

	$$self{_mem_activity} = 'update_flags';
	$$self{_operating_flags} = $flags;
	$self->_peek('0023'); 
}


sub has_link
{
	my ($self, $insteon_object, $group, $is_controller, $subaddress) = @_;
	my $key = lc $insteon_object->device_id . $group . $is_controller;
	$subaddress = '00' unless $subaddress;
	# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
	if ($subaddress ne '00' and $subaddress ne '01') {
		$key .= $subaddress;
	}
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
		$$self{pending_adlb}{deviceid} = lc $deviceid;
		$$self{pending_adlb}{group} = lc $group;
		$$self{pending_adlb}{is_controller} = $is_controller;
		$$self{pending_adlb}{data1} = (defined $data1) ? lc $data1 : '00';
		$$self{pending_adlb}{data2} = (defined $data2) ? lc $data2 : '00';
		# Note: if device is a KeypadLinc, then $data3 must be assigned the value of the applicable button (01)
		if (($self->is_keypadlinc) and ($data3 eq '00')) {
			&::print_log("[Insteon_Device] setting data3 to " . $self->group . " for this keypadlinc")
				if $main::Debug{insteon};
			$data3 = $self->group;
		}
		$$self{pending_adlb}{data3} = (defined $data3) ? lc $data3 : '00';
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
	if ($extended) {
		$$self{interface}->set($self->_xlate_mh_insteon('peek','extended',
			$lsb . "0000000000000000000000000000"),$self);
	} else {
		$$self{_mem_lsb} = $lsb;
		$$self{_mem_msb} = $msb;
		$$self{_mem_action} = 'adlb_peek';
		&::print_log("[Insteon_Device] " . $self->get_object_name . " accessing memory at location: 0x" . $address);
		$self->_send_cmd('command' => 'set_address_msb', 'extra' => $msb, 'is_synchronous' => 1);
	}
}


1;
