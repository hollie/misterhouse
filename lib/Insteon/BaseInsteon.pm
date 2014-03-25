=head1 B<Insteon::BaseObject>

=head2 SYNOPSIS

Usage

In user code:

    $ip_patio_light = new Insteon_Device($myPLM,"33.44.55");
    $ip_patio_light->set("ON");

=head2 DESCRIPTION

Generic class implementation of an Insteon Device.

=head2 INHERITS

L<Generic_Item|Generic_Item>

=head2 METHODS

=over

=cut

package Insteon::BaseObject;

use strict;
use Insteon::AllLinkDatabase;

@Insteon::BaseObject::ISA = ('Generic_Item');

our %message_types = (
						on => 0x11,
						off => 0x13
);

our %nack_messages = (
   fb => 'illegal_value_in_cmd',
   fc => 'pre_nak_long_db_search',
   fd => 'bad_checksum_or_unknown_cmd',
   fe => 'load_sense_detects_no_load',
   ff => 'sender_id_not_in_responder_aldb',
);

=item C<derive_link_state([state])>

Takes the various states available to insteon devices and returns a derived 
state of either ON or OFF.

=cut

sub derive_link_state
{
	my ($self, $p_state) = @_;
	$p_state = $self if !(ref $self); #Old code made direct calls
	#Convert Relative State to Absolute State
	if ($p_state =~ /^([+-])(\d+)/) {
		my $rel_state = $1 . $2;
		my $curr_state = '100';
		$curr_state = '0' if ($self->state eq 'off');
		$curr_state = $1 if $self->state =~ /(\d{1,3})/;
		$p_state = $curr_state + $rel_state;
		$p_state = 'on' if ($p_state > 0);
		$p_state = 'off' if ($p_state <= 0);
	}
	
	my $link_state = 'on';
	if ($p_state eq 'off' or $p_state eq 'off_fast')
	{
		$link_state = 'off';
	}
	elsif ($p_state =~ /\d+%?/)
	{
		my ($dim_state) = $p_state =~ /(\d+)%?/;
		$link_state = 'off' if $dim_state == 0;
	}

	return $link_state;
}

=item C<new()>

Instantiates a new object.

=cut

sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;
	my $self={};
	bless $self,$class;

        $$self{message_types} = \%message_types;

	if (defined $p_deviceid) {
		my ($deviceid, $group) = $p_deviceid =~ /(\w\w\.\w\w\.\w\w):?(.+)?/;
		# if a group is passed in, then assume it can be a controller
		$$self{is_controller} = ($group) ? 1 : 0;
		$self->device_id($deviceid);
		$group = '01' unless $group;
		$group = '0' . $group if length($group) == 1;
		$self->group(uc $group);
	}

        if ($p_interface) {
        	$self->interface($p_interface);
        } else {
        	$self->interface(&Insteon::active_interface());
        }

	$self->restore_data('default_hop_count', 'engine_version');

	$self->initialize();
	$$self{max_hops} = 3;
	$$self{min_hops} = 0;
	$$self{level} = undef;
	$$self{flag} = "0F";
	$$self{ackMode} = "1";
	$$self{awaiting_ack} = 0;
	$$self{is_acknowledged} = 0;
	$$self{max_queue_time} = $::config_parms{'Insteon_PLM_max_queue_time'};
	$$self{max_queue_time} = 10 unless $$self{max_queue_time}; # 10 seconds is max time allowed in command stack
	@{$$self{command_stack}} = ();
	$$self{_onlevel} = undef;
	$$self{is_responder} = 1;
        $$self{default_hop_count} = 0;
	$$self{timeout_factor} = 1.0;
	$$self{is_deaf} = 0;

	&Insteon::add($self);
	return $self;
}

=item C<initialize()>

A former holdover from when MisterHouse used to ping devices to get their device
category.  May not be needed anymore.

=cut

sub initialize
{
	my ($self) = @_;
	$$self{m_write} = 1;
	$$self{m_is_locally_set} = 0;
	# persist local, simple attribs
}

=item C<interface([interface])>

Used to store and return the associated interface of a device.

If provided, stores interface as the device's interface.

=cut

sub interface
{
	my ($self,$p_interface) = @_;
        if (defined $p_interface) {
		$$self{interface} = $p_interface;
        }
        elsif (!($$self{interface}))
        {
        	$$self{interface} = &Insteon::active_interface;
        }
	return $$self{interface};
}

=item C<device_id([id])>

Used to store and return the associated device_id of a device.

If provided, stores id as the device's id.

Returns device id without any delimiters.

=cut

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

=item C<group([group])>

Used to store and return the associated group of a device.

If provided, stores group as the device group.

=cut

sub group
{
	my ($self, $p_group) = @_;
	$$self{m_group} = $p_group if $p_group;
	return $$self{m_group};
}

=item C<timeout_factor($float)>

Changes the amount of time MH will wait to receive a response from a device before
resending the message.  The value set will be multiplied by the predefined value
in MH.  $float can be set to any positive decimal number.  For example using 1.0
will not change the preset values; 1.1 will increase the time MH waits by 10%; and
0.9 will force MH to wait for only 90% of the predefined time.

This value is NOT saved on reboot, as such likely should be called in a $Reload loop.

=cut

sub timeout_factor {
	my ($self, $factor) = @_;
	$$self{timeout_factor} = $factor if $factor;
	return $$self{timeout_factor};
}

=item C<max_hops($int)>

Sets the maximum number of hops that may be used in a message sent to the device.
The default and maximum number is 3.  $int is an integer between 0-3.

This value is NOT saved on reboot, as such likely should be called in a $Reload loop.

=cut

sub max_hops {
	my ($self, $hops) = @_;
	$$self{max_hops} = $hops if $hops;
	return $$self{max_hops};
}

=item C<min_hops($int)>

Sets the minimum number of hops that may be used in a message sent to the device.
The default and minimum number is 0.  $int is an integer between 0-3.

This value is NOT saved on reboot, as such likely should be called in a $Reload loop.

=cut

sub min_hops {
	my ($self, $hops) = @_;
	$$self{min_hops} = $hops if $hops;
	return $$self{min_hops};
}

=item C<default_hop_count([hops])>

Used to track the number of hops needed to reach a device.  Will store the past
20 hop counts for the device.  Hop counts are added based on the number of hops
needed for an incomming message to arrive.  Additionally, any time a message is
resent, a hop count equal to the prior default_hop_count + 1 is added.

If provided, stores hop as a new hop count for the device.  If more than 20 hop
counts have been stored, will drop the oldest hop count until only 20 exist.

Returns the highest hop count of the past 20 hop counts

=cut

sub default_hop_count
{
	my ($self, $hop_count) = @_;
	if (defined($hop_count)){
		::print_log("[Insteon::BaseObject] DEBUG3: Adding hop count of " . $hop_count . " to hop_array of "
			. $self->get_object_name) if $self->debuglevel(3, 'insteon');
		if (!defined(@{$$self{hop_array}})) {
			unshift(@{$$self{hop_array}}, $$self{default_hop_count});
			$$self{hop_sum} = $$self{default_hop_count};
		}
		#Calculate a simple moving average
		unshift(@{$$self{hop_array}}, $hop_count); 
		$$self{hop_sum} += ${$$self{hop_array}}[0];
		$$self{hop_sum} -= pop(@{$$self{hop_array}}) if (scalar(@{$$self{hop_array}}) >10);
		$$self{default_hop_count} = int(($$self{hop_sum} / scalar(@{$$self{hop_array}})) + 0.5);

		::print_log("[Insteon::BaseObject] DEBUG4: ".$self->get_object_name
			."->default_hop_count()=".$$self{default_hop_count}
			." :: hop_array[]=". join("",@{$$self{hop_array}})) 
			if $self->debuglevel(4, 'insteon');
	}

	#Allow for per-device settings
	$$self{default_hop_count} = $$self{max_hops} if ($$self{max_hops} &&
		$$self{default_hop_count} > $$self{max_hops});
	$$self{default_hop_count} = $$self{min_hops} if ($$self{min_hops} &&
		$$self{default_hop_count} < $$self{min_hops});	
	
        return $$self{default_hop_count};
}

=item C<engine_version([i1|i2|i2cs])>

Used to store and return the associated engine version of a device.

If provided, stores the engine version of the device.

=cut

sub engine_version
{
        my ($self, $p_engine_version) = @_;
        $$self{engine_version} = $p_engine_version if $p_engine_version;
        return $$self{engine_version};
}

=item C<equals([object])>

Returns 1 if object is the same as $self, otherwise returns 0.

=cut

sub equals
{
	my ($self, $compare_object) = @_;
        # make sure that the compare_object is legitimate
        return 0 unless $compare_object && ref $compare_object && $compare_object->isa('Insteon::BaseObject');
        return 1 if $compare_object eq $self;
        # self and compare_object need to have device_ids and groups to be equal
        return 0 unless $self->device_id && $self->group && $compare_object->device_id && $compare_object->group;
        return 1 if (($compare_object->device_id eq $self->device_id)
        	&& ($compare_object->group eq $self->group));
	# default to false;
        return 0;
}

=item C<set(state[,setby,response])>

Used to set the device state.  If called by device or a device linked to device, 
calls C<set_receive()>.  If called by something 
else, will send the command to the device.

=cut

sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;
	return if &main::check_for_tied_filters($self, $p_state);

	# Override any set_with_timer requests
	if ($$self{set_timer}) {
		&Timer::unset($$self{set_timer});
		delete $$self{set_timer};
	}

	if ($self->_is_valid_state($p_state)) {
		# always reset the is_locally_set property unless set_by is the device
		$$self{m_is_locally_set} = 0 unless ref $p_setby and $p_setby eq $self;

		if ($p_state eq 'toggle')
		{
			$p_state = ($self->state eq 'on')? 'off' : 'on';
		}

		my $setby_name = $p_setby;
		$setby_name = $p_setby->get_object_name() if (ref $p_setby and $p_setby->can('get_object_name'));
		if (ref $p_setby and $p_setby eq $self)
		{ #If set by device, update MH state,
			my $derived_state = $self->derive_link_state($p_state);
			&::print_log("[Insteon::BaseObject] " . $self->get_object_name()
				. "::set_receive($derived_state, $setby_name)") if $self->debuglevel(1, 'insteon');
			$self->set_receive($derived_state,$p_setby,$p_response);
			$self->set_linked_devices($p_state);
		} 
		elsif (ref $p_setby and $p_setby eq $self->interface) 
		{ #If set by interface, this was a manual status_request response
			&::print_log("[Insteon::BaseObject] " . $self->get_object_name()
				. "::set_receive($p_state, $setby_name)") if $self->debuglevel(1, 'insteon');
			$self->set_receive($p_state,$p_setby,$p_response);
		}
		else { # Not called by device, send set command
			if ($self->is_responder){
				my $message = $self->derive_message($p_state);
				$self->_send_cmd($message);
				&::print_log("[Insteon::BaseObject] " . $self->get_object_name() . "::set($p_state, $setby_name)")
					if $self->debuglevel(1, 'insteon');
				$self->is_acknowledged(0);
				$$self{pending_state} = $p_state;
				$$self{pending_setby} = $p_setby;
				$$self{pending_response} = $p_response;
			} 
			else {
				::print_log("[Insteon::BaseObject] " . $self->get_object_name()
					. " is not a responder and cannot be set to a state.");	
			}
		}
		$self->level($p_state) if $self->can('level'); # update the level value
	} else {
		&::print_log("[Insteon::BaseObject] failed state validation with state=$p_state");
	}
}

=item C<is_acknowledged([ack])>

If ack is true, calls C<set_receive()>.  If ack is false, clears awaiting_ack flag.

=cut

sub is_acknowledged
{
	my ($self, $p_ack) = @_;
        if (defined $p_ack)
        {
       		if ($p_ack)
                {
			$self->set_receive($$self{pending_state},$$self{pending_setby}, $$self{pending_response}) if defined $$self{pending_state};
		}
                else
                {
                	# if we are not acknowledged, then clear the awaiting acknowledgement flag
                        #   we won't do the converse as it is set in _process_command_stack
                	$$self{awaiting_ack} = 0;
                }
		$$self{is_acknowledged} = $p_ack;
		$$self{pending_state} = undef;
		$$self{pending_setby} = undef;
		$$self{pending_response} = undef;
        }
	return $$self{is_acknowledged};
}

=item C<set_receive(state[,setby,response])>

Updates the device state in MisterHouse.  Triggers state_now, state_changed, and
state_final variables to update accordingly.  Which causes tie_events to occur.

If state was set to the same state within the last 1 second, then this is ignored.
This prevents the accidental calling of state_now if duplicate messages are received.

=cut

sub set_receive
{
	my ($self, $p_state, $p_setby, $p_response) = @_;
	my $curr_milli = sprintf('%.0f', &main::get_tickcount);
	my $window = 1000;
	$p_state = $self->derive_link_state($p_state);
	if (($p_state eq $self->state || $p_state eq $self->state_final)
		&& ($curr_milli - $$self{set_milliseconds} < $window)){
		::print_log("[Insteon::BaseObject] Ignoring duplicate set " . $p_state .
			" state command for " . $self->get_object_name . " received in " .
			"less than $window milliseconds") if $self->debuglevel(1, 'insteon'); 
	} else {
		$$self{set_milliseconds} = $curr_milli;
		$self->level($p_state) if $self->can('level'); # update the level value
		$self->SUPER::set($p_state, $p_setby, $p_response);
	}
}

=item C<set_with_timer(state, time, return_state, additional_return_states)>

NOTE - This routine appears to be nearly identical, if not identical to the
C<Generic_Item::set_with_timer()> routine, it is not clear why this routine is
needed here.

See full description of this routine in C<Generic_Item>

=cut

sub set_with_timer {
	my ($self, $state, $time, $return_state, $additional_return_states) = @_;
	return if &main::check_for_tied_filters($self, $state);

	$self->set($state) unless $state eq '';

	return unless $time;

	my $state_change = ($state eq 'off') ? 'on' : 'off';
	$state_change = $return_state if defined $return_state;
	$state_change = $self->{state} if $return_state and lc $return_state eq 'previous';

	$state_change .= ';' . $additional_return_states if $additional_return_states;

	$$self{set_timer} = &Timer::new() unless $$self{set_timer};
	my $object_name = $self->{object_name};
	my $action = "$object_name->set('$state_change')";
	$$self{set_timer}->set($time, $action);
}

sub _send_cmd
{
	my ($self, $message) = @_;
#	$msg{type} = 'standard' unless $msg{type};

#        my $message = $self->derive_message($msg{command},$msg{type},$msg{extra});

        if ($message->command eq 'peek'
              	or $message->command eq 'poke'
               	or $message->command eq 'status_request'
                or $message->command eq 'do_read_ee'
                or $message->command eq 'set_address_msb'
                or $message->command eq 'read_write_aldb'
            )
	{
        	push(@{$$self{command_stack}}, $message);
	}
        else
        {
		unshift(@{$$self{command_stack}},$message);
	}
	$self->_process_command_stack();
}

=item C<derive_message([command,extra])>

Generates and returns a basic on/off message from a command.

=cut

sub derive_message
{
	my ($self, $p_command, $p_extra) = @_;
	my @args;
	my $level;

	#msg id
	my ($command, $subcommand) = split(/:/, $p_command, 2);
	$command=lc($command);
#	&::print_log("XLATE:$msg:$substate:$p_state:");

        my $message;

        if ($self->isa("Insteon::BaseController"))
        {
	# only send out as all-link if the link originates from the plm
		if ($self->isa("Insteon::InterfaceController"))
                { # return the size of the command stack
                        $message = new Insteon::InsteonMessage('all_link_send', $self);
		}
                elsif ($self->is_root)
                { # return the size of the command stack
			$message = new Insteon::InsteonMessage('insteon_send', $self);
		} else {
			# silently ignore as this is now permitted if via "surrogate"
		}
	} elsif ($self->isa("Insteon::BaseObject")) {
		$message = new Insteon::InsteonMessage('insteon_send', $self);
        }

	if (!(defined $p_extra)) {
		if ($command eq 'on')
		{
			if ($self->can('local_onlevel') && defined $self->local_onlevel) {
				$level = 2.55 * $self->local_onlevel;
				$command = 'on_fast';
			} else {
				$level=255;
			}
		} elsif ($command eq 'off')
		{
			$level = 0;
		} elsif ($command=~/^([1]?[0-9]?[0-9])/)
		{
			if ($1 < 1) {
				$command='off';
				$level = 0;
			} else {
				$level = ($self->isa('Insteon::DimmableLight')) ? $1 * 2.55 : 255;
				$command='on';
			}
		}
	}

	# confirm that the resulting $msg is legitimate
	if (!(defined($self->message_type_code($command)))) {
		&::print_log("[Insteon::BaseInsteon] invalid state=$command") if $self->debuglevel(1, 'insteon');
		return undef;
	}

	if ($self->isa("Insteon::InterfaceController")) 
	{
		$message->extra('00') #All PLM Scenes are Cmd2=00;
	} elsif ($p_extra)
	{       $message->extra($p_extra);

	} elsif ($subcommand) {
		$message->extra($subcommand);
	} else {
		if ($command eq 'on')
		{
			$message->extra(sprintf("%02X",int($level+.5)));
		} else {
			$message->extra('00');
		}
	}

        $message->command($command);
	return $message;
}

=item C<message_type_code(msg)>

Takes msg, a text based msg type, and returns the corresponding text version of
the hexadecimal message type.

=cut

sub message_type_code
{
    my ($self, $msg) = @_;
    return $$self{message_types}->{$msg};
}

=item C<message_type_hex(msg)>

Takes msg, a text based msg type, and returns the corresponding message type as
a hex.

=cut

sub message_type_hex
{
    my ($self, $msg) = @_;
    return unpack( 'H*', pack( 'c', $self->message_type_code($msg)));
}

=item C<message_type(cmd)>

Takes cmd, text based hexadecimal code, and returns the text based description
of the message code.

=cut

sub message_type
{
    my ($self, $cmd1) = @_;
    my $msg_type;
    my $msg_type_ptr = $$self{message_types};
    my %msg_types = %$msg_type_ptr;
    for my $key (keys %msg_types){
    	if (pack("C",$msg_types{$key}) eq pack("H*",$cmd1))
    	{
#    		&::print_log("[Insteon::BaseObject] found: $key");
		$msg_type=$key;
		last;
	}
    }
    return $msg_type;
}

=item C<_is_info_request()>

Used to process messages from the device which lack a command code.  Currently
the only known message like this is a response to a (19) Light Status Request.
In these responses, C1 is the ALDB Delta of the device.

The get_engine_version check is out of place here, should be moved to
C<_process_message>

=cut

sub _is_info_request
{
	my ($self, $cmd, $ack_setby, %msg) = @_;
	my $is_info_request = 0;
	if ($cmd eq 'status_request') {
		$is_info_request++;
		my $ack_on_level = sprintf("%d", int((hex($msg{extra}) * 100 / 255)+.5));
		&::print_log("[Insteon::BaseObject] received status for " .
			$self->{object_name} . " with on-level: $ack_on_level%, "
			. "hops left: $msg{hopsleft}") if $self->debuglevel(1, 'insteon');
		$self->level($ack_on_level) if $self->can('level'); # update the level value
		if ($ack_on_level == 0) {
			$self->set('off', $ack_setby);
		} elsif ($ack_on_level > 0 and !($self->isa('Insteon::DimmableLight'))) {
			$self->set('on', $ack_setby);
		} else {
			$self->set($ack_on_level . '%', $ack_setby);
		}
		# if this were a scene controller, then also propogate the result to all members
		my $callback;
		if ($self->_aldb->{aldb_delta_action} eq 'set'){
			if ($msg{cmd_code} eq "00") {
				$self->_aldb->{_mem_activity} = 'delete';
				$self->_aldb->{pending_aldb}{address} = $self->_aldb->get_first_empty_address();
				if($self->_aldb->isa('Insteon::ALDB_i1')) {
					$self->_aldb->_peek($self->_aldb->{pending_aldb}{address},0);
				} else {
					$self->_aldb->_write_delete($self->_aldb->{pending_aldb}{address});
				}
			} else {
				$self->_aldb->aldb_delta($msg{cmd_code});
				$self->_aldb->scandatetime(&main::get_tickcount);
				&::print_log("[Insteon::BaseObject] The Link Table Version for "
					. $self->{object_name} . " has been updated to version number " . $self->_aldb->aldb_delta());
				if (defined $self->_aldb->{_success_callback}) {
					$callback = $self->_aldb->{_success_callback};
					$self->_aldb->{_success_callback} = undef;
				}
			}
		}
		elsif ($self->_aldb->{aldb_delta_action} eq 'check')
		{
			if ($self->_aldb->aldb_delta() eq $msg{cmd_code}){
				&::print_log("[Insteon::BaseObject] The link table for "
					. $self->{object_name} . " is in sync.");
				#Link Table Scan Successful, Record Current Time
				$self->_aldb->scandatetime(&main::get_tickcount);
				if (defined $self->_aldb->{_aldb_unchanged_callback}) {
					$callback = $self->_aldb->{_aldb_unchanged_callback};
					$self->_aldb->{_aldb_unchanged_callback} = undef;
				}
			} else {
				&::print_log("[Insteon::BaseObject] WARN The link table for "
					. $self->{object_name} . " is out-of-sync.");
				$self->_aldb->health('out-of-sync');
				if (defined $self->_aldb->{_aldb_changed_callback}) {
					$callback = $self->_aldb->{_aldb_changed_callback};
					$self->_aldb->{_aldb_changed_callback} = undef;
				}
			}
		}
		$self->_aldb->{aldb_delta_action} = undef;
		$self->_aldb->health('out-of-sync') if($self->_aldb->aldb_delta() ne $msg{cmd_code});
		if ($callback){
			package main;
			eval ($callback);
			&::print_log("[Insteon::BaseObject] " . $self->get_object_name . ": error during scan callback $@")
				if $@ and $self->debuglevel(1, 'insteon');
			package Insteon::BaseObject;                		
		}
	}
	elsif ( $cmd eq 'get_engine_version' ) {
		$is_info_request++;
		my @engine_types = (qw/I1 I2 I2CS/);
		my $version = $engine_types[$msg{extra}];
		$self->engine_version($version);
		&::print_log("[Insteon::BaseObject] received engine version for " 
			. $self->{object_name} . " of $version. "
			. "hops left: $msg{hopsleft}") if $self->debuglevel(1, 'insteon');
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

	main::print_log("[Insteon::BaseObject] WARN: Message has invalid checksum")
		if ($self->debuglevel(1, 'insteon') && !($msg{crc_valid}) 
		&& $msg{is_extended} && $self->engine_version() eq 'I2CS');

	my $clear_message = 0;
	$$self{m_is_locally_set} = 1 if $msg{source} eq lc $self->device_id;
	$self->default_hop_count($msg{maxhops}-$msg{hopsleft}) if (!$self->isa('Insteon::InterfaceController'));
	if ($msg{is_ack}) {
		#Default to clearing message transaction for ACK
		$clear_message = 1;
		my $corrupt_cmd = 0;
		my $pending_cmd = ($$self{_prior_msg}) ? $$self{_prior_msg}->command : $msg{command};
		if ($$self{awaiting_ack})
                {
			my $ack_setby = (ref $$self{m_status_request_pending})
				? $$self{m_status_request_pending} : $p_setby;
			if ($self->_is_info_request($pending_cmd,$ack_setby,%msg))
                        {
				$self->is_acknowledged(1);
				$$self{m_status_request_pending} = 0;
				$self->_process_command_stack(%msg);
			}
                        elsif ($pending_cmd eq 'peek')
                        {
                        	if ($msg{cmd_code} eq $self->message_type_hex($pending_cmd)) {
					$self->_aldb->_on_peek(%msg) if $self->_aldb;
					$self->_process_command_stack(%msg);
                        	} else {
                        		$corrupt_cmd = 1;
                        		$clear_message = 0;
                        	}
			}
                        elsif ($pending_cmd eq 'set_address_msb')
                        {
                        	if ($msg{cmd_code} eq $self->message_type_hex($pending_cmd)) {
					$self->_aldb->_on_peek(%msg) if $self->_aldb;
					$self->_process_command_stack(%msg);
                        	} else {
                        		$corrupt_cmd = 1;
                        		$clear_message = 0;
                        	}
			}
                        elsif (($pending_cmd eq 'poke'))
                        {
                        	if ($msg{cmd_code} eq $self->message_type_hex($pending_cmd)) {
					$self->_aldb->_on_poke(%msg) if $self->_aldb;
					$self->_process_command_stack(%msg);
                        	} else {
                        		$corrupt_cmd = 1;
                        		$clear_message = 0;
                        	}
			}
			elsif ($pending_cmd eq 'read_write_aldb') {
                        	if ($msg{cmd_code} eq $self->message_type_hex($pending_cmd)) {
					$clear_message = $self->_aldb->on_read_write_aldb(%msg) if $self->_aldb;
					$self->_process_command_stack(%msg) if ($clear_message);
                        	} else {
                        		$corrupt_cmd = 1;
                        		$clear_message = 0;
                        	}
			}
			elsif ($pending_cmd eq 'ping'){
				$corrupt_cmd = 1 if ($msg{cmd_code} ne $self->message_type_hex($pending_cmd));
				$corrupt_cmd = 1 if ($msg{extra} ne sprintf ("%02d", $$self{ping_count}));
				if (!$corrupt_cmd){
					$self->_process_command_stack(%msg);
					&::print_log("[Insteon::BaseObject] received ping acknowledgement from " . $self->{object_name})
						if $self->debuglevel(1, 'insteon');
					$self->ping();
					$clear_message = 1;
				}
			}
			elsif ($pending_cmd eq 'linking_mode'){
				$corrupt_cmd = 1 if ($msg{cmd_code} ne $self->message_type_hex($pending_cmd));
				if (!$corrupt_cmd){
					&::print_log("[Insteon::BaseObject] received linking mode ACK from " . $self->{object_name})
						if $self->debuglevel(1, 'insteon');
					$self->interface->_set_timeout('xmit', 2000);
					$clear_message = 0;
				}
			}
			else
                        {
				if (($pending_cmd eq 'do_read_ee') && 
					($self->_aldb->health eq "good" || $self->_aldb->health eq "empty") &&
					($self->isa('Insteon::KeyPadLincRelay') || $self->isa('Insteon::KeyPadLinc'))){
					## Update_Flags ends up here, set aldb_delta to new value
					$self->_aldb->query_aldb_delta("set");
				}
				$self->is_acknowledged(1);
				# signal receipt of message to the command stack in case commands are queued
				$self->_process_command_stack(%msg);
				&::print_log("[Insteon::BaseObject] received command/state (awaiting) acknowledge from " . $self->{object_name}
					. ": $pending_cmd and data: $msg{extra}") if $self->debuglevel(1, 'insteon');
			}
		}
                else
                {
			# allow non-synchronous messages to also use the _is_info_request hook
			$self->_is_info_request($pending_cmd,$p_setby,%msg);
			$self->is_acknowledged(1);
			# signal receipt of message to the command stack in case commands are queued
			$self->_process_command_stack(%msg);
			&::print_log("[Insteon::BaseObject] received command/state acknowledge from " . $self->{object_name}
				. ": " . (($msg{command}) ? $msg{command} : "(unknown)")
				. " and data: $msg{extra}") if $self->debuglevel(1, 'insteon');
		}
		if ($corrupt_cmd) {
			main::print_log("[Insteon::BaseObject] WARN: received a message from "
				. $self->get_object_name . " in response to a "
				. $pending_cmd . " command, but the command code "
				. $msg{cmd_code} . " is incorrect. Ignorring received message.");
			$self->corrupt_count_log(1) if $self->can('corrupt_count_log');
			$p_setby->active_message->no_hop_increase(1);
		} 
	}
        elsif ($msg{is_nack})
        {
		#Default to clearing message transaction for NAK
		$clear_message = 1;
		if ($self->isa('Insteon::BaseLight')) {
			&::print_log("[Insteon::BaseObject] WARN!! encountered a nack message ("
			. $self->get_nack_msg_for( $msg{extra} ) .") for " . $self->{object_name}
			. ".  It may be unplugged, have a burned out bulb, or this may be a new I2CS "
			. "type device that must first be manually linked to the PLM using the set button.") 
			if $self->debuglevel(1, 'insteon');
		}
		else 
		{
			&::print_log("[Insteon::BaseObject] WARN!! encountered a nack message ("
			. $self->get_nack_msg_for( $msg{extra} ) .") for " . $self->{object_name}
			. " ... skipping");
		}
		$p_setby->active_message->no_hop_increase(1);
		$self->is_acknowledged(0);
		$self->_process_command_stack(%msg);
		if($p_setby->active_message->failure_callback)
		{
			main::print_log("[Insteon::BaseObject] WARN: Now calling message failure callback: "
				. $p_setby->active_message->failure_callback) if $self->debuglevel(1, 'insteon');
			$self->failure_reason('NAK');
			package main;
			eval $p_setby->active_message->failure_callback;
			main::print_log("[Insteon::BaseObject] problem w/ retry callback: $@") if $@;
			package Insteon::BaseObject;
		}
		$p_setby->active_message->no_hop_increase(1);
		$self->is_acknowledged(0);
		$self->_process_command_stack(%msg);
	}
        elsif ($msg{command} eq 'start_manual_change')
        {
		$$self{manual_direction} = $msg{extra};
		$$self{manual_start} = ::get_tickcount() - (($msg{maxhops}-$msg{hopsleft})*50);
	} elsif ($msg{command} eq 'stop_manual_change') {
		# Determine percent change based on time interval
		my $finish_time = &main::get_tickcount - (($msg{maxhops}-$msg{hopsleft})*50);
		my $total_time = $finish_time - $$self{manual_start};
		my $percent_change = int($total_time / 42);
		if ($$self{manual_direction} eq '00') {
			$percent_change = "-".$percent_change;
		} else {
			$percent_change = "+".$percent_change;
		}
		$self->set($percent_change, $self);
	} elsif ($msg{command} eq 'read_write_aldb') {
		if ($self->_aldb){
			$clear_message = $self->_aldb->on_read_write_aldb(%msg) if $self->_aldb;
			$self->_process_command_stack(%msg) if($clear_message);
		}
	} elsif ($msg{type} eq 'broadcast') {
		$self->devcat($msg{devcat});
		$self->firmware($msg{firmware});
		&::print_log("[Insteon::BaseObject] device category: $msg{devcat}"
			. " firmware: $msg{firmware} received for " . $self->{object_name});
	} else {
		## TO-DO: make sure that the state passed by command is something that is reasonable to set
		$p_state = $msg{command};
                if ($msg{type} eq 'alllink')
                {
			if ($msg{command} eq 'link_cleanup_report'){
				if ($msg{extra} == 0){
					::print_log("[Insteon::BaseObject] DEBUG Received AllLink Cleanup Success for "
						. $self->{object_name}) if $self->debuglevel(1, 'insteon');
				} else {
					::print_log("[Insteon::BaseObject] WARN " . $msg{extra} . " Device(s) failed to "
						. "acknowledge the command from " . $self->{object_name});
				}
			} else {
				$self->set($p_state, $self);
				$$self{_pending_cleanup} = 1;
				#Wait to avoid clobbering incomming subsequent cleanup messages
				my @links = $self->find_members('Insteon::BaseDevice');
				#Timeout is the number of linked devices multiplied by
				#the maximum hop length for a direct message and an ACK
				#PLM is the +1
				my $timeout = (scalar(@links)+1) * 300;
				::print_log("[Insteon::BaseObject] DEBUG3 Delaying any outgoing messages ". 
					"by $timeout milliseconds to avoid collision with subsequent cleanup ".
					"messages from " . $self->get_object_name) if ($self->debuglevel(3, 'insteon'));
				$self->interface->_set_timeout('xmit', $timeout);
			}
                }
                elsif ($msg{type} eq 'cleanup')
                {
                	if (($self->state eq $p_state or $self->state_final eq $p_state)
                		and $$self{_pending_cleanup}){
				::print_log("[Insteon::BaseObject] Ignoring Received Direct AllLink Cleanup Message for " 
					. $self->{object_name} . " since AllLink Broadcast Message was Received.") if $self->debuglevel(1, 'insteon');
                	} else {
				$self->set($p_state, $self);
			}
			$$self{_pending_cleanup} = 0;
		} else {
			main::print_log("[Insteon::BaseObject] Ignoring unsupported command from " 
				. $self->{object_name}) if $self->debuglevel(1, 'insteon');
			$self->corrupt_count_log(1) if $self->can('corrupt_count_log');
                }
	}
	return $clear_message;
}

sub _process_command_stack
{
	my ($self, %ackmsg) = @_;
	if (%ackmsg) { # which may also be something that can be interpretted as a "nack"
		# determine whether to unset awaiting_ack
		# for now, be "dumb" and just unset it
		$$self{awaiting_ack} = 0;
	}
	if (!($$self{awaiting_ack})) {
		my $callback = undef;
		my $message = pop(@{$$self{command_stack}});
		# convert ptr to cmd hash
		if ($message)
                {
                        my $plm_queue_size = $self->interface->queue_message($message);

			# send msg
                        if ($message->command eq 'peek'
                        	or $message->command eq 'poke'
                        	or $message->command eq 'status_request'
                                or $message->command eq 'get_engine_version'
                                or $message->command eq 'id_request'
                                or $message->command eq 'do_read_ee'
                                or $message->command eq 'set_address_msb'
                                or $message->command eq 'sensor_status'
                                or $message->command eq 'set_operating_flags'
                                or $message->command eq 'get_operating_flags'
                                or $message->command eq 'read_write_aldb'
                                or $message->command eq 'thermostat_control'
                                or $message->command eq 'thermostat_get_zone_info'
                                or $message->command eq 'extended_set_get'
                                or $message->command eq 'ping'
                                or $message->command eq 'linking_mode'
                                or $message->command eq 'imeter_query'
                                or $message->command eq 'imeter_reset'
                                )
                        {
				$$self{awaiting_ack} = 1;
			}
                        else
                        {
				$$self{awaiting_ack} = 0;
			}

			$$self{_prior_msg} = $message;
			# TO-DO: adjust timer based upon (1) type of message and (2) retry_count
			my $queue_time = $$self{max_queue_time} + $plm_queue_size;
			# if is_synchronous, then no other command can be sent until an insteon ack or nack is received
			# for this command
		} else {
			# and, always clear awaiting_ack and _prior_msg
			$$self{awaiting_ack} = 0;
			$$self{_prior_msg} = undef;
		}
		if ($callback) {
			package main;
			eval ($callback);
			&::print_log("[Insteon::BaseObject] error in queue timer callback: " . $@)
				if $@ and $self->debuglevel(1, 'insteon');
			package Insteon::BaseObject;
		}
	} else {
#		&::print_log("[Insteon_Device] " . $self->get_object_name . " command queued but not yet sent; awaiting ack from prior command") if $self->debuglevel(1, 'insteon');
	}
}

sub _is_valid_state
{
	my ($self,$state) = @_;
	if (!(defined($state)) or $state eq '') {
		return 0;
	}

	my ($msg, $substate) = split(/:/, $state, 2);
	$msg=lc($msg);

	if ($msg=~/^[+-]?([1]?[0-9]?[0-9])/)
	{
		if ($1 < 1) {
			$msg='off';
		} else {
			$msg='on';
		}
	}
        elsif ($msg eq 'toggle')
        {
        	if ($self->state eq 'on')
                {
                	$msg = 'off';
                }
                elsif ($self->state eq 'off')
                {
                	$msg = 'on';
                }
        }

	# confirm that the resulting $msg is legitimate
	if (!(defined($$self{message_types}{$msg}))) {
		return 0;
	} else {
		return 1;
	}
}

=item C<get_nack_msg_for(msg)>

Takes msg, text based hexadecimal code, and returns the text based description
of the NACK code.

=cut

sub get_nack_msg_for {
   my ($self,$msg) = @_;
   return $nack_messages{ $msg };
}

=item C<failure_reason>

Stores the resaon for the most recent message failure [NAK | timeout].  Used to 
process message callbacks after a message fails.  If called with no parameter 
returns the saved failure reason.

Parameters:
	reason: failure reason

Returns: failure reason

=cut 

sub failure_reason
{
        my ($self, $reason) = @_;
        $$self{failure_reason} = $reason if $reason;
        return $$self{failure_reason};
}

=item C<get_voice_cmds>

Returns a hash of voice commands where the key is the voice command name and the
value is the perl code to run when the voice command name is called.

Higher classes which inherit this object may add to this list of voice commands by
redefining this routine while inheriting this routine using the SUPER function.

This routine is called by L<Insteon::generate_voice_commands> to generate the
necessary voice commands.

=cut 

sub get_voice_cmds
{
    my ($self) = @_;
    my %voice_cmds = (
        #The Sync Links routine really resides in DeviceController, but that
        #class seems a little redundant as in practice all devices are controllers
        #in some sense.  As a result, that class will likely be folded into 
        #BaseObject/Device at some future date.  In order to avoid a bizarre
        #inheritance of this routine by higher classes, this command was placed
        #here
        'sync links' => $self->get_object_name . '->sync_links(0)'
    );
    return \%voice_cmds;
}

sub _aldb
{
   my ($self) = @_;
   my $root_obj = $self->get_root();
   return $$root_obj{aldb};
}

=item C<is_deaf()>

Returns true if the device must be awake in order to respond to messages.  Most
devices are not deaf, currently devices that are deaf are battery operated
devices such as the Motion Sensor, RemoteLinc and TriggerLinc.

At the BaseObject level all devices are defined as not deaf.  Objects which
inherit BaseObject should redefine is_deaf as necessary.

=cut

sub is_deaf
{
	my ($self) = @_;
	return $$self{is_deaf};
}

=item C<is_controller()>

Returns true if the device is a controller.

=cut

sub is_controller
{
	my ($self) = @_;
	return $$self{is_controller};
}

=item C<is_responder([1|0])>

Stores and returns whether a device is a responder.

=cut

sub is_responder
{
	my ($self,$is_responder) = @_;
	$$self{is_responder} = $is_responder if defined $is_responder;
	if ($self->is_root || $self->isa('Insteon::InterfaceController')) {
		return $$self{is_responder};
	}
        else
        {
		my $root_obj = $self->get_root();
		if (ref $root_obj)
                {
			return $$root_obj{is_responder};
		}
                else
                {
			return 0;
		}
	}
}

=back

=head2 INI PARAMETERS

=over 

=item Insteon_PLM_max_queue_time

Was previously used to set the maximum amount of time
a message could remain in the queue.  This parameter is no longer used in the code
but it still appears in the initialization.  It may be removed at a future date.  
This also gets set in L<Insteon::BaseDevice|Insteon::BaseInsteon/Insteon::BaseDevice>
as well for some reason, but is not used there either.

=back

=head2 AUTHOR

Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 NOTES

Special thanks to:
	Brian Warren for significant testing and patches
	Bruce Winter - MH

=head2 SEE ALSO

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

####################################
###            #####################
### BaseDevice #####################
###            #####################
####################################

=head1 B<Insteon::BaseDevice>

=head2 DESCRIPTION

Generic class implementation of a Base Insteon Device.

=head2 INHERITS

L<Insteon::BaseObject|Insteon::BaseInsteon/Insteon::BaseObject>

=head2 METHODS

=over

=cut

package Insteon::BaseDevice;

@Insteon::BaseDevice::ISA = ('Insteon::BaseObject');

our %message_types = (
   %Insteon::BaseObject::message_types,
   assign_to_group => 0x01,
   delete_from_group => 0x02,
   link_cleanup_report => 0x06,
   linking_mode => 0x09,
   unlinking_mode => 0x0A,
   get_engine_version => 0x0D,
   ping => 0x0F,
   id_request => 0x10,
   on_fast => 0x12,
   off_fast => 0x14,
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
   extended_set_get => 0x2e,
   read_write_aldb => 0x2f,
   imeter_reset => 0x80,
   imeter_query => 0x82,
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

=item C<new()>

Instantiates a new object.

=cut

sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;
	my $self= new Insteon::BaseObject($p_deviceid,$p_interface);
	bless $self,$class;

        $$self{message_types} = \%message_types;
        $$self{operating_flags} = \%operating_flags;

        if ($self->group eq '01') {
           $$self{aldb} = new Insteon::ALDB_i1($self);
        }

	$self->restore_data('devcat', 'firmware', 'level', 'retry_count_log', 'fail_count_log', 
        'outgoing_count_log', 'incoming_count_log', 'corrupt_count_log',
        'dupe_count_log', 'hops_left_count', 'max_hops_count',
        'outgoing_hop_count');

	$self->initialize();
	$self->rate(undef);
	$$self{level} = undef;
	$$self{flag} = "0F";
	$$self{ackMode} = "1";
	$$self{awaiting_ack} = 0;
	$$self{is_acknowledged} = 0;
	$$self{max_queue_time} = $::config_parms{'Insteon_PLM_max_queue_time'};
	$$self{max_queue_time} = 10 unless $$self{max_queue_time}; # 10 seconds is max time allowed in command stack
	@{$$self{command_stack}} = ();
	$$self{_onlevel} = undef;
    $$self{retry_count_log} = 0;
    $$self{fail_count_log} = 0;
    $$self{outgoing_count_log} = 0;
    $$self{incoming_count_log} = 0;
    $$self{corrupt_count_log} = 0;
    $$self{dupe_count_log} = 0;
    $$self{hops_left_count} = 0;
    $$self{max_hops_count} = 0;
    $$self{outgoing_hop_count} = 0;


	return $self;
}

=item C<initialize()>

A former holdover from when MisterHouse used to ping devices to get their device
category.  May not be needed anymore.

=cut

sub initialize
{
	my ($self) = @_;
	$$self{m_write} = 1;
	$$self{m_is_locally_set} = 0;
	# persist local, simple attribs
}

=item C<rate([rate])>

Used to store and return the associated ramp rate of a device.

If provided, stores rate as the device's ramp rate in MisterHouse.

=cut

sub rate
{
	my ($self,$p_rate) = @_;
	$$self{rate} = $p_rate if defined $p_rate;
	return $$self{rate};
}

=item C<link_to_interface([group,data3])>

If a controller link from the device to the interface does not exist, this will
create that link on the device.

Next, if a responder link from the device to the interface does not exist on the 
interface, this will create that link on the interface.

The group is the group on the device that is the controller, such as a button on
a keypad link.  It will default to 01.

Data3 is optional and is used to set the Data3 value in the controller link on 
the device.

=cut

sub link_to_interface
{
	my ($self,$p_group, $p_data3, $step) = @_;
	$p_group = $self->group unless (defined $p_group);
	$p_data3 = $self->group unless (defined $p_data3);
	my $success_callback_prefix = $self->get_object_name."->link_to_interface(\"$p_group\",\"$p_data3\",";
	my $success_callback = "";
	my $failure_callback = '::print_log("[Insteon::BaseInsteon] Error: The Link_To_Interface '.
		'routine failed for device: '.$self->get_object_name.'")';
	$step = 0 if ($step eq '');
	if ($step == 0) { #If NAK on get_engine, then this is an I2CS device
		$success_callback = $success_callback_prefix . "\"1\")";
		$failure_callback = $self->get_object_name."->link_to_interface_i2cs(\"$p_group\",\"$p_data3\")";
		$self->get_engine_version($success_callback, $failure_callback);	
	}
	elsif ($step == 1) { #Add Controller Link from object->PLM
		$success_callback = $success_callback_prefix . "\"2\")";
		my %link_info = ( object => $self->interface, group => $p_group, is_controller => 1,
			callback => "$success_callback", failure_callback=> "$failure_callback");
		$link_info{data3} = $p_data3 if $p_data3;
	        if ($self->_aldb) {
		   $self->_aldb->add_link(%link_info);
	        }
	        else
	        {
	           &main::print_log("[Insteon::BaseInsteon] Error: This item, " . $self->get_object_name .
	              ", does not have an ALDB object.  Linking is not permitted.");
	        }
	}
	elsif ($step == 2){ #Add Responder Link to PLM for object->PLM
		$success_callback = $success_callback_prefix . "\"3\")";
		my $link_info = "deviceid=" . lc ($self->device_id) . " group=$p_group is_controller=0 " .
			"callback=$success_callback failure_callback=$failure_callback";	
	        $self->interface->add_link($link_info);
	}
	elsif ($step == 3){ #Add surrogate responder link on device if surrogate exists
		if (ref $$self{surrogate}){
			$success_callback = $success_callback_prefix . "\"4\")";
			my $surrogate_group = $$self{surrogate}->group;
			my %link_info = ( object => $self->interface, 
				group => $surrogate_group, is_controller => 0,
				callback => "$success_callback", 
				failure_callback=> "$failure_callback",
				data3 => $p_group);
			$self->_aldb->add_link(%link_info);
		} else {
			::print_log('[Insteon::BaseInsteon] Link_To_Interface successfully completed'.
				' for device ' .$self->get_object_name);	
		}
	}
	elsif ($step == 4){ #Add surrogate controller link on PLM if surrogate exists
		$success_callback = $success_callback_prefix . "\"5\")";
		my $surrogate_group = $$self{surrogate}->group;
		my %link_info = ( deviceid=> lc($self->device_id), 
			group => $surrogate_group, is_controller => 1,
			callback => "$success_callback", 
			failure_callback=> "$failure_callback",
			data3 => $surrogate_group);
		$self->interface->add_link(%link_info);
	}
	elsif ($step == 5){
		::print_log('[Insteon::BaseInsteon] Link_To_Interface successfully completed'.
			' for device ' .$self->get_object_name);			
	}
}

=item C<link_to_interface_i2cs([group,data3])>

Performs the same task as C<link_to_interface> however this routine is designed
to perform the initial link to I2CS devices.  These devices cannot be initially
linked to the PLM in the normal way.  This process requires more steps than the
normal routine which will take longer to perform and therefore is more prone to
faile.  As such, this should likely only be used if necessary.

=cut

sub link_to_interface_i2cs
{
	my ($self,$p_group, $p_data3, $step) = @_;
	my $success_callback_prefix = $self->get_object_name."->link_to_interface_i2cs('$p_group','$p_data3',";
	my $success_callback = "";
	my $failure_callback = "::print_log('[Insteon::BaseInsteon] Error Link_To_Interface_I2CS ".
		"routine failed for device: ".$self->get_object_name."')";
	$step = 0 if ($step eq '');
	if ($step == 0) { #Put PLM into initiate linking mode
		$success_callback = $success_callback_prefix . "'1')";
		$self->interface()->initiate_linking_as_controller('00', $success_callback, $failure_callback);	
	}
	elsif ($step == 1) { #Ask device to respond to link request
		$success_callback = $success_callback_prefix . "'2')";
		$self->enter_linking_mode($p_group, $success_callback, $failure_callback);	
	}
	elsif ($step == 2) { #Insert Link Record in PLM, Scan Device link table
		#Insert the record into MH cache of the PLM's link table
		my $device_id = $self->device_id;
		my $data1 = substr($self->devcat, 0, 2);
		my $data2 = substr($self->devcat, 2, 2);
		my $data3 = $self->firmware;
		$self->interface()->_aldb->add_link_to_hash('E2', '00', '1', 
			$device_id, $data1, $data2, $data3);
		#Scan device to get an accurate link table
		#return to normal link_to_interface routine if successful
		$success_callback_prefix = $self->get_object_name."->link_to_interface('$p_group','$p_data3',";
		$success_callback = $success_callback_prefix . "'1')";
		$self->scan_link_table($success_callback, $failure_callback);
	}
}

=item C<unlink_to_interface([group])>

Will delete the contoller link from the device to the interface if such a link exists.

Next, will delete the responder link from the device to the interface on the 
interface, if such a link exists.

The group is the group on the device that is the controller, such as a button on
a keypad link.  It will default to 01.

=cut

sub unlink_to_interface
{
	my ($self,$p_group,$step) = @_;
	$p_group = $self->group unless $p_group;
	#It is possible to nest all of the callbacks in at once, but the quoting
	#becomes very complicated and happers readability
	my $success_callback_prefix = $self->get_object_name."->unlink_to_interface('$p_group',";
	my $success_callback = "";
	my $failure_callback = "::print_log('[Insteon::BaseInsteon] ERROR: Unlink_To_Interface ".
		"failed for device: ".$self->get_object_name."')";
	$step = 0 if ($step eq '');
	if ($step == 0) { #Delete link on the device
	        if ($self->_aldb) {
	        	$success_callback = $success_callback_prefix . "'1')";
			$self->_aldb->delete_link(object => $self->interface, 
				group => $p_group, 
				data3=> $p_group, is_controller => 1,
				callback => $success_callback,
				failure_callback=> $failure_callback);
	        }
	        else
	        {
	           &main::print_log("[BaseInsteon] This item " . $self->get_object_name .
	              " does not have an ALDB object.  Unlinking is not permitted.");
	        }
	}
	elsif ($step == 1) { #Delete link on the PLM
		$success_callback = $success_callback_prefix . "'2')";
		$self->interface->delete_link(
			deviceid => lc($self->device_id), 
			group=> $p_group, is_controller=>0,
			callback=>$success_callback,
			failure_callback=>$failure_callback);
	}
	elsif ($step == 2){ #Delete surrogate link on device if surrogate exists
		if (ref $$self{surrogate}){
			$success_callback = $success_callback_prefix . "'3')";
			my $surrogate_group = $$self{surrogate}->group;
			my %link_info = ( object => $self->interface, 
				group => $surrogate_group, is_controller => 0,
				callback => "$success_callback", 
				failure_callback=> "$failure_callback",
				data3 => $p_group);
			$self->_aldb->delete_link(%link_info);
		} else {
			::print_log("[Insteon::BaseInsteon] Unlink_To_Interface".
				" successfully completed for device "
				. $self->get_object_name);	
		}
	}
	elsif ($step == 3){ #Delete surrogate link on PLM if surrogate exists
		$success_callback = $success_callback_prefix . "'4')";
		my $surrogate_group = $$self{surrogate}->group;
		my %link_info = ( deviceid=> lc($self->device_id), 
			group => $surrogate_group, is_controller => 1,
			callback => "$success_callback", 
			failure_callback=> "$failure_callback",
			data3 => $surrogate_group);
		$self->interface->delete_link(%link_info);
	}
	elsif ($step == 4) {
		::print_log("[Insteon::BaseInsteon] Unlink_To_Interface".
			" successfully completed for device "
			. $self->get_object_name);
	}
}

=item C<enter_linking_mode(group, success_callback, failure_callback)>

Places an i2 object into linking mode as if you had held down the set button on 
the device.  i1 objects will not respond to this command.  This is needed to 
link i2CS devices that will not respond without a manual link. 

This process is included as part of the link_to_interface voice command and 
should not need to be called seperately.

Returns: nothing

=cut 

sub enter_linking_mode
{
	my ($self,$p_group, $success_callback, $failure_callback) = @_;
	my $group = $p_group;
	$group = '01' unless $group;
	my $extra = sprintf("%02x", $group);
	$extra .= '0' x (30 - length $extra);
	my $message = new Insteon::InsteonMessage('insteon_ext_send', $self, 'linking_mode', $extra);
	$message->success_callback($success_callback);
	$message->failure_callback($failure_callback);
	$self->_send_cmd($message);
}

=item C<set_operating_flag(flag)>

Sets the defined flag on the device.

=cut 

sub set_operating_flag {
	my ($self, $flag) = @_;

	if (!(exists($$self{operating_flags}{$flag})))
        {
		&::print_log("[Insteon::BaseDevice] $flag is not a support operating flag");
		return;
	}

	if ($self->is_root and !($self->isa('Insteon::InterfaceController')))
        {
        	my $message;
		if (ref $self->_aldb && $self->_aldb->isa('Insteon::ALDB_i2'))
		{
			$message = new Insteon::InsteonMessage('insteon_ext_send', $self, 'set_operating_flags');
			$message->extra($$self{operating_flags}{$flag} . "0000000000000000000000000000");
		} else {
			$message = new Insteon::InsteonMessage('insteon_send', $self, 'set_operating_flags');
			$message->extra($$self{operating_flags}{$flag});
		}
                $self->_send_cmd($message);
        }
        else
        {
		&::print_log("[Insteon::BaseDevice] " . $self->get_object_name . " is either not a root device or is a plm controlled scene");
		return;
	}
}

=item C<get_operating_flag()>

Requests the device's operating flag and prints it to the log.

=cut 

sub get_operating_flag {
	my ($self) = @_;

	if ($self->is_root and !($self->isa('Insteon::InterfaceController')))
        {
		# TO-DO: check devcat to determine if the action is supported by the device
                my $message = new Insteon::InsteonMessage('insteon_send', $self, 'get_operating_flags');
                $self->_send_cmd($message);
#		$self->_send_cmd('command' => 'get_operating_flags');
        }
        else
        {
		&::print_log("[Insteon::BaseDevice] " . $self->get_object_name . " is either not a root device or is a plm controlled scene");
		return;
	}
}

=item C<writable(cmd)>

Appears to set and or return the "writable" state.  Does not appear to be used
in the Insteon code, but may be necessary for supporting other classes?

=cut

sub writable {
	my ($self, $p_write) = @_;
	if (defined $p_write)
        {
		if ($p_write =~ /r/i or $p_write =~/^0/)
                {
			$$self{m_write} = 0;
		}
                else
                {
			$$self{m_write} = 1;
		}
	}
	return $$self{m_write};
}

=item C<is_locally_set(cmd)>

Returns the is_locally_set variable.  Doesn't appear to be used in Insteon code.
Likely was used to test whether setby was equal to the device itself.  May not
always be properly updated since it appears unused.

=cut

sub is_locally_set {
	my ($self) = @_;
	return $$self{m_is_locally_set};
}

=item C<is_root()>

Returns true if the object is the base object, generally group 01, on the device.

=cut

sub is_root {
	my ($self) = @_;
	return (($self->group eq '01') and !($self->isa('Insteon::InterfaceController'))) ? 1 : 0;
}

=item C<get_root()>

Returns the root object of a device.

=cut

sub get_root {
	my ($self) = @_;
	if ($self->is_root)
        {
		return $self;
	}
        else
        {
		my $root_obj = &Insteon::get_object($self->device_id, '01');
		::print_log ("[Insteon::BaseDevice] ERROR! Cannot find the root object for " 
			. $self->get_object_name . ". Please check your mht file to make sure "
			. "that device id " . $self->device_id . ":01 is defined.") 
			if (!defined($root_obj));
		return $root_obj;
	}
}

=item C<has_link(link_details)>

If a device has an ALDB, passes link_details onto one of the has_link() routines
within L<Insteon::AllLinkDatabase|Insteon::AllLinkDatabase>.  Generally called as part of C<delete_orphan_links()>.

=cut

sub has_link
{
	my ($self, $insteon_object, $group, $is_controller, $subaddress) = @_;
        my $aldb = $self->get_root()->_aldb;
        if ($aldb)
        {
        	return $aldb->has_link($insteon_object, $group, $is_controller, $subaddress);
        }
        else
        {
        	return 0;
        }

}

=item C<add_link(link_params)>

If a device has an ALDB, passes link_details onto one of the add_link() routines
within L<Insteon::AllLinkDatabase|Insteon::AllLinkDatabase>.  Generally called from the "sync links" or 
"link to interface" voice commands.

=cut

sub add_link
{
	my ($self, $parms_text) = @_;
        my $aldb = $self->get_root()->_aldb;
        if ($aldb)
        {
        	my %link_parms;
		if (@_ > 2)
                {
			shift @_;
			%link_parms = @_;
		}
                else
                {
			%link_parms = &main::parse_func_parms($parms_text);
		}
        	$aldb->add_link(%link_parms);
        }

}

=item C<update_link(link_params)>

If a device has an ALDB, passes link_details onto one of the update_link() routines
within L<Insteon::AllLinkDatabase|Insteon::AllLinkDatabase>. Generally called from the "sync links" 
voice command.

=cut

sub update_link
{
	my ($self, $parms_text) = @_;
        my $aldb = $self->get_root()->_aldb;
        if ($aldb)
        {
        	my %link_parms;
		if (@_ > 2)
                {
			shift @_;
			%link_parms = @_;
		}
                else
                {
			%link_parms = &main::parse_func_parms($parms_text);
		}
        	$aldb->update_link(%link_parms);
        }
}

=item C<delete_link([link details])>

If a device has an ALDB, passes link_details onto one of the delete_link() routines
within L<Insteon::AllLinkDatabase|Insteon::AllLinkDatabase>.  Generally called by C<delete_orphan_links()>.

=cut

sub delete_link
{
	my ($self, $parms_text) = @_;
        my $aldb = $self->get_root()->_aldb;
        if ($aldb)
        {
        	my %link_parms;
		if (@_ > 2)
                {
			shift @_;
			%link_parms = @_;
		}
                else
                {
			%link_parms = &main::parse_func_parms($parms_text);
		}
        	$aldb->delete_link(%link_parms);
        }
}

=item C<scan_link_table()>

Scans a device link table and caches a copy.

=cut

sub scan_link_table
{
	my ($self, $success_callback, $failure_callback) = @_;
        my $aldb = $self->get_root()->_aldb;
        if ($aldb)
        {
        	return $aldb->scan_link_table($success_callback, $failure_callback);
	}

}

=item C<log_aldb_status()>

Prints a human readable description of various settings and attributes associated 
with a device including:

Hop Count, Engine Version, ALDB Type, ALDB Health, and Last ALDB Scan Time

=cut

sub log_aldb_status
{
	my ($self) = @_;
	main::print_log( "     Device ID: ".$self->device_id());
	my $hop_array;
	$hop_array = join("",@{$$self{hop_array}}) if (defined($$self{hop_array}));
	main::print_log( "     Hop Count: ".$self->default_hop_count()." :: [$hop_array]");
	main::print_log( "Engine Version: ".$self->engine_version());
	my $aldb = $self->get_root()->_aldb;
	if ($aldb)
	{
		main::print_log( "     ALDB Type: ".ref($aldb));
		main::print_log( "   ALDB Health: ".$aldb->health());
		main::print_log( "ALDB Scan Time: ".$aldb->scandatetime());
	}
}

=item C<remote_set_button_tap([repeat])>

In theory, would have the same effect as manually tapping the set button on the 
device repeat times.

WARN: Testing using the following does not produce results as expected.  Use at 
your own risk. [GL]

=cut

sub remote_set_button_tap
{
	my ($self,$p_number_taps) = @_;
	my $taps = ($p_number_taps =~ /2/) ? '02' : '01';
        my $message = new Insteon::InsteonMessage('insteon_send', $self, 'remote_set_button_tap');
        $message->extra($taps);
        $self->_send_cmd($message);
#	$self->_send_cmd('command' => 'remote_set_button_tap', 'extra' => $taps);
}

=item C<request_status([requestor])>

Requests the current status of the device and calls C<set()> on the response.  
This will trigger tied_events.

=cut

sub request_status
{
	my ($self, $requestor) = @_;
	$$self{m_status_request_pending} = ($requestor) ? $requestor : 1;
        my $message = new Insteon::InsteonMessage('insteon_send', $self, 'status_request');
        $self->_send_cmd($message);
#	$self->_send_cmd('command' => 'status_request', 'is_synchronous' => 1);
}

=item C<get_engine_version>

Queues a get engine version insteon message using L<Insteon::BaseObject::_send_cmd> 
and sets a message failure callback to L<Insteon::BaseDevice::_get_engine_version_failure>.  
Message response is processed in L<Insteon::BaseObject::_is_info_request>  

Returns: nothing

=cut 

sub get_engine_version {
   my ($self, $success_callback, $failure_callback) = @_;

   my $message = new Insteon::InsteonMessage('insteon_send', $self, 'get_engine_version');
   my $self_object_name = $self->get_object_name;
   $message->failure_callback("$self_object_name->_get_engine_version_failure();$failure_callback");
   $message->success_callback($success_callback);
   $self->_send_cmd($message);
}

=item C<_get_engine_version_failure>

Callback failure for L<Insteon::BaseDevice::get_engine_version>; called for NAK 
and message timeout.  Will force engine_version to I2CS which will also remap 
the aldb version if the device responds with a NAK. Does nothing for timeouts 
except print a message. 

Returns: nothing

=cut 

sub _get_engine_version_failure
{
	my ($self) = @_;
	my $failure_reason = $self->failure_reason();
	
	main::print_log("[Insteon::BaseDevice::_get_engine_version_failure] DEBUG4: "
		."failure reason: $failure_reason") if $self->debuglevel(4, 'insteon');
	
	if($failure_reason eq 'NAK')
	{
		#assume I2CS because no other device will NAK this command
		main::print_log("[Insteon::BaseDevice] WARN: I2CS device (" . $self->get_object_name . ") is not "
			."linked; Please use 'link to interface' voice command");
		$self->engine_version('I2CS');
	}
	#Clear success callback, otherwise it will run when message is cleared
	$self->interface->active_message->success_callback('0') 
		if (ref $self->interface->active_message);
}

=item C<ping([count])>

Sends the number of ping messages defined by count.  A ping message is a basic 
message that simply asks the device to respond with an ACKnowledgement.  For
i1 devices this will send a standard length command, for i2 and i2cs devices
this will send an extended ping command.  In both cases, the device responds
back with a standard length ACKnowledgement only.

Much like the ping command in IP networks, this command is useful for testing the
connectivity of a device on your network.  You likely want to use this in 
conjunction with the C<print_message_log> routine.  For example, you can use 
this to compare the message stats for a device when changing settings in 
MisterHouse.

Parameters:
	count = the number of pings to send.

Returns: Nothing.

=cut

sub ping
{
	my ($self, $p_count, $p_callback) = @_;
	$$self{ping_count} = $p_count if defined($p_count);
	$$self{ping_callback} = $p_callback if defined($p_callback);
	if ($$self{ping_count}) {
		$$self{ping_count}--;
		my $message;
		my $extra = sprintf("%02d", $$self{ping_count});
		if (uc($self->engine_version) eq 'I1'){
	    	$message = new Insteon::InsteonMessage('insteon_send', $self, 
	    		'ping', $extra);
		}
		else {
			my $extra = $extra . '0' x 28;
			$message = new Insteon::InsteonMessage('insteon_ext_send', $self, 
				'ping', $extra);
		}
		::print_log("[Insteon::BaseDevice] Sending ping request to " 
			. $self->get_object_name . " " . $$self{ping_count} 
			. " more ping requests queued.");
		$message->failure_callback($self->get_object_name . '->ping()');
		$self->_send_cmd($message);
	}
	else {
		::print_log("[Insteon::BaseDevice] Completed ping queue for " 
			. $self->get_object_name);
		if (defined $$self{ping_callback}){
			my $complete_callback = $$self{ping_callback};
			package main;
			eval ($complete_callback);
			&::print_log("[Insteon::BaseDevice] error in ping callback: " . $@)
				if $@ and $self->debuglevel(1, 'insteon');
			package Insteon::BaseDevice;
			delete $$self{ping_callback};
		}
	}
}

=item C<set_led_status()>

Used to set the led staatus of SwitchLinc companion leds.

=cut 

sub set_led_status
{
	my ($self, $status_mask) = @_;
        my $message = new Insteon::InsteonMessage('insteon_send', $self, 'set_led_status');
        $message->extra($status_mask);
        $self->_send_cmd($message);
#	$self->_send_cmd('command' => 'set_led_status', 'extra' => $status_mask);
}

=item C<restore_string()>

This is called by mh on exit to save the cached ALDB of a device to persistant data.

=cut

sub restore_string
{
	my ($self) = @_;
	my $restore_string = $self->SUPER::restore_string();
	if ($self->_aldb)
        {
		$restore_string .= $self->_aldb->restore_string();
        }

	return $restore_string;
}

=item C<restore_states()>

Obsolete / do not use.

Function should remain so that upgrading users will not have issues starting 
MH from previous versions that referenced this function in the 
mh_temp.saved_states file.

=cut

sub restore_states
{
	my ($self, $states) = @_;
}

=item C<restore_aldb()>

Used to reload the aldb of a device on restart.

=cut

sub restore_aldb
{
	my ($self,$aldb) = @_;
	if ($self->_aldb and $aldb)
        {
           $self->_aldb->restore_aldb($aldb);
	}
}

=item C<devcat()>

Sets and returns the device category of a device.  Devcat can be requested by
calling C<get_devcat()>.

=cut

sub devcat
{
	my ($self, $devcat) = @_;
	if ($devcat)
        {
		$$self{devcat} = $devcat;
	}
	return $$self{devcat};
}

=item C<get_devcat()>

Requests the device category for the device.  The returned value can be obtained
by calling C<devcat()>.

=cut

sub get_devcat
{
	my ($self) = @_;
        my $message = new Insteon::InsteonMessage('insteon_send', $self, 'id_request');
        $self->_send_cmd($message);
}

=item C<firmware()>

Sets and returns the device firmware version.  Value can be obtained from the 
device by calling C<get_devcat()>.

=cut

sub firmware
{
	my ($self, $firmware) = @_;
	$$self{firmware} = $firmware if (defined $firmware);
	return $$self{firmware};
}

=item C<states()>

Sets and returns the available states for a device.

=cut

sub states
{
	my ($self, $states) = @_;
	if ($states)
        {
		@{$$self{states}} = split(/,/,$states);
	}
	if ($$self{states})
        {
		return @{$$self{states}};
	} else {
		return undef;
	}

}

=item C<delete_orphan_links(audit_mode)>

Reviews the cached version of all of the ALDBs and based on this review removes
links from this device which are not present in the mht file, not defined in the 
code, or links which are only half-links.

If audit_mode is true, prints the actions that would be taken to the log, but 
does nothing.

=cut

sub delete_orphan_links
{
	my ($self, $audit_mode, $failure_callback) = @_;
        return $self->_aldb->delete_orphan_links($audit_mode, $failure_callback) if $self->_aldb;
}

sub _process_delete_queue {
	my ($self) = @_;
        $self->_aldb->_process_delete_queue() if $self->_aldb;
}

=item C<log_alllink_table()>

Prints a human readable form of MisterHouse's cached version of a device's ALDB
to the print log.  Called as part of the "scan links" voice command
or in response to the "log links" voice command.

=cut

sub log_alllink_table
{
	my ($self) = @_;
        $self->_aldb->log_alllink_table if $self->_aldb;
}

=item C<engine_version>

Sets or gets the device object engine version.  If setting the engine version, 
will also call check_aldb_version to map the aldb correctly for I2 devices. 

Parameters:
	p_engine_version: [I1|I2|I2CS] to set engine version

Returns: engine version string [I1|I2|I2CS]

=cut 

sub engine_version
{
	my ($self, $p_engine_version) = @_;
	my $engine_version = $self->SUPER::engine_version($p_engine_version);
	$self->check_aldb_version() if $p_engine_version;
	return $engine_version;
}

=item C<retry_count_log([type]>

Sets or gets the number of message retries that have occured for this device 
since the last time C<reset_message_stats> was called.

If type is set, to any value, will increment retry log by one.

Returns: current retry count.

=cut 

sub retry_count_log
{
	my ($self, $retry_count_log) = @_;
	$self = $self->get_root;
	$$self{retry_count_log}++ if $retry_count_log;
	return $$self{retry_count_log};
} 

=item C<fail_count_log([type]>

Sets or gets the number of message failures that have occured for this device 
since the last time C<reset_message_stats> was called.

If type is set, to any value, will increment fail log by one.

Returns: current fail count.

=cut 

sub fail_count_log
{
    my ($self, $fail_count_log) = @_;
    $self = $self->get_root;
	$$self{fail_count_log}++ if $fail_count_log;
	return $$self{fail_count_log};
} 

=item C<outgoing_count_log([type]>

Sets or gets the number of outgoing message that have occured for this device 
since the last time C<reset_message_stats> was called.

If type is set, to any value, will increment output count by one.

Returns: current output count.

=cut 

sub outgoing_count_log
{
    my ($self, $outgoing_count_log) = @_;
    $self = $self->get_root;
    $$self{outgoing_count_log}++ if $outgoing_count_log;
	return $$self{outgoing_count_log};
}

=item C<stress_test(count)>

Simulates a read of a link address from the device.  Repeats this process as many
times as defined by count.  This routine is meant to be used as a diagnostic tool.
It is similar to scan_link_table, however, if a failure occurs, this process will
continue with the next iteration.  Scan link table will stop as soon as a single
failure occurs.

This is also similar to the C<ping> test, however, rather than simply requesting
an ACK, this requests a full set of data equivalent to a link entry.  Similar to
C<ping> this should be used with C<print_message_log> to diagnose issues and try
different settings.

Note: This routine can create a lot of traffic if count is set very high.  Try
setting it to 5 first and working your way up.

=cut

sub stress_test
{
	my ($self, $p_count, $complete_callback) = @_;
	$$self{stress_test_count} = $p_count if (defined ($p_count));
	$$self{stress_test_callback} = $complete_callback if (defined ($complete_callback));
	if ($$self{stress_test_count}){
		&::print_log("[Insteon::BaseDevice] " . $self->get_object_name 
			. " - Stress Test " . $$self{stress_test_count} . " iterations left");
	        my $aldb = $self->get_root()->_aldb;
	        if ($aldb)
	        {
			$$aldb{_mem_activity} = 'scan';
			$$aldb{_stress_test_act} = 1;
			$$aldb{_failure_callback} = $self->get_object_name 
				. '->stress_test()';
			if($aldb->isa('Insteon::ALDB_i1')) {
				$aldb->_peek('0FF8');
			} else {
				#Prevents duplicate commands in queue error
				#Also allows for better identification of 
				#sequential dupe incoming messages
				my $odd = $$self{stress_test_count} % 2;
				if ($odd){
					$aldb->send_read_aldb('0fff');
				} else {
					$aldb->send_read_aldb('0ff7');
				}
			}
		}
		$$self{stress_test_count}--;
	} else {
		&::print_log("[Insteon::BaseDevice] Stress Test Complete for " 
			. $self->get_object_name);	
		if (defined $$self{stress_test_callback}){
			$complete_callback = $$self{stress_test_callback};
			package main;
			eval ($complete_callback);
			&::print_log("[Insteon::BaseDevice] error in stress_test callback: " . $@)
				if $@ and $self->debuglevel(1, 'insteon');
			package Insteon::BaseDevice;
			delete $$self{stress_test_callback};
		}
	}
}

=item C<outgoing_hop_count([type]>

Sets or gets the number of hops that have been used in all outgoing messages
since the last time C<reset_message_stats> was called.

If type is set, to any value, will increment output count by that value.

Returns: current hop count.

=cut 

sub outgoing_hop_count
{
    my ($self, $outgoing_hop_count) = @_;
    $self = $self->get_root;
    $$self{outgoing_hop_count} += $outgoing_hop_count if $outgoing_hop_count;
	return $$self{outgoing_hop_count};
}

=item C<incoming_count_log([type]>

Sets or gets the number of incoming message that have occured for this device 
since the last time C<reset_message_stats> was called.

If type is set, to any value, will increment incoming count by one.

Returns: current incoming count.

=cut 

sub incoming_count_log
{
    my ($self, $incoming_count_log) = @_;
    $self = $self->get_root;
    $$self{incoming_count_log}++ if $incoming_count_log;
    return $$self{incoming_count_log};
}
        
=item C<corrupt_count_log([type]>

Sets or gets the number of currupt message that have arrived from this device 
since the last time C<reset_message_stats> was called.

If type is set, to any value, will increment corrupt count by one.

Returns: current corrupt count.

=cut 

sub corrupt_count_log
{
    my ($self, $corrupt_count_log) = @_;
    $self = $self->get_root;
    $$self{corrupt_count_log}++ if $corrupt_count_log;
    return $$self{corrupt_count_log};
}

=item C<dupe_count_log([type]>

Sets or gets the number of duplicate message that have arrived from this device 
since the last time C<reset_message_stats> was called.

If type is set, to any value, will increment corrupt count by one.

Returns: current duplicate count.

=cut 

sub dupe_count_log
{
    my ($self, $dupe_count_log) = @_;
    $self = $self->get_root;
    $$self{dupe_count_log}++ if $dupe_count_log;
    return $$self{dupe_count_log};
}

=item C<hops_left_count([type]>

Sets or gets the number of hops_left for messages that arrive from this device 
since the last time C<reset_message_stats> was called.

If type is set, to any value, will increment corrupt count by one.

Returns: current hops_left count.

=cut 

sub hops_left_count
{
    my ($self, $hops_left_count) = @_;
    $self = $self->get_root;
    $$self{hops_left_count} += $hops_left_count if $hops_left_count;
    return $$self{hops_left_count};
}

=item C<max_hops_count([type]>

Sets or gets the number of max_hops for messages that arrive from this device 
since the last time C<reset_message_stats> was called.

If type is set, to any value, will increment corrupt count by one.

Returns: current duplicate count.

=cut 

sub max_hops_count
{
    my ($self, $max_hops_count) = @_;
    $self = $self->get_root;
    $$self{max_hops_count} += $max_hops_count if $max_hops_count;
    return $$self{max_hops_count};
}


=item C<reset_message_stats>

Resets the retry, fail, outgoing, incoming, and corrupt message counters.

=cut 

sub reset_message_stats
{
    my ($self) = @_;
    $self = $self->get_root;
    $$self{retry_count_log} = 0;
    $$self{fail_count_log} = 0;
    $$self{outgoing_count_log} = 0;
    $$self{incoming_count_log} = 0;
    $$self{corrupt_count_log} = 0;
    $$self{dupe_count_log} = 0;
    $$self{hops_left_count} = 0;
    $$self{max_hops_count} = 0;
    $$self{outgoing_hop_count} = 0;
}

=item C<print_message_stats>

Prints message statistics for this device to the print log.  The output contains:

=back

=over8

=item * 

In - The number of incoming messages received

=item * 

Corrupt - The number of incoming corrupt messages received

=item * 

%Corrpt - Of the incoming messages received, the percentage that were 
corrupt

=item *

Dupe - The number of duplicate messages that have been received from this 
device.

=item *

%Dupe - The percentage of duplilicate incoming messages received.

=item *

Hops_Left - The average hops left in the messages received from this device.

=item *

Max_Hops - The average maximum hops in the messages received from this device.

=item *

Act_Hops - Max_Hops - Hops_Left, this is the average number of hops that have
been required for a message sent from the device to reach MisterHouse.

=item * 

Out - The number of unique outgoing messages, without retries, sent. 

=item * 

Fail - The number times that all retries were exhausted without a successful
delivery of a message.

=item * 

%Fail - Of the outgoing messages sent, the percentage that failed.

=item * 

Retry - The number of retry attempts that have been made to deliver a message. 
Ideally this is 0, but Sends/Msg is a better indication of this parameter.

=item * 

AvgSend - The average number of send attempts that must be made in order to 
successfully deliver a message.  Ideally this would be 1.0.  

NOTE: If the number of retries exceeds the value set in the configuration file 
for Insteon_retry_count, MisterHouse will abandon sending the message.  As a 
result, as this number approaches Insteon_retry_count it becomes a less accurate 
representation of the number of retries needed to reach a device.

=item *

Avg_Hops - The average number of hops that have been used by MisterHouse when
sending messages to this device.

=item *

Hop_Count - The current hop count being used by MH.  This count is dynamically
controlled by MH and is not reset by calling C<reset_message_stats>

=back

=over

=cut 

sub print_message_stats
{
    my ($self) = @_;
    $self = $self->get_root;
    my $object_name = $self->get_object_name;
    my $retry_average = 0; 
    $retry_average = sprintf("%.1f", ($$self{retry_count_log} / 
        $$self{outgoing_count_log}) + 1) if ($$self{outgoing_count_log} > 0);
    my $fail_percentage = 0; 
    $fail_percentage = sprintf("%.1f", ($$self{fail_count_log} / 
        $$self{outgoing_count_log}) * 100 ) if ($$self{outgoing_count_log} > 0);
    my $corrupt_percentage = 0; 
    $corrupt_percentage = sprintf("%.1f", ($$self{corrupt_count_log} / 
        $$self{incoming_count_log}) * 100 ) if ($$self{incoming_count_log} > 0);
    my $dupe_percentage = 0; 
    $dupe_percentage = sprintf("%.1f", ($$self{dupe_count_log} / 
        $$self{incoming_count_log}) * 100 ) if ($$self{incoming_count_log} > 0);
    my $avg_hops_left = 0; 
    $avg_hops_left = sprintf("%.1f", ($$self{hops_left_count} / 
        $$self{incoming_count_log})) if ($$self{incoming_count_log} > 0);
    my $avg_max_hops = 0; 
    $avg_max_hops = sprintf("%.1f", ($$self{max_hops_count} / 
        $$self{incoming_count_log})) if ($$self{incoming_count_log} > 0);
    my $avg_out_hops = 0;
    $avg_out_hops = sprintf("%.1f", ($$self{outgoing_hop_count} / 
        $$self{outgoing_count_log})) if ($$self{outgoing_count_log} > 0);
    ::print_log(
        "[Insteon::BaseDevice] Message statistics for $object_name:\n"
        . "    In Corrupt %Corrpt  Dupe   %Dupe HopsLeft Max_Hops Act_Hops\n"
        . sprintf("%6s", $$self{incoming_count_log})
        . sprintf("%8s", $$self{corrupt_count_log})
        . sprintf("%8s", $corrupt_percentage . '%')
        . sprintf("%6s", $$self{dupe_count_log})
        . sprintf("%8s", $dupe_percentage . '%')
        . sprintf("%9s", $avg_hops_left)
        . sprintf("%9s", $avg_max_hops)
        . sprintf("%9s", $avg_max_hops - $avg_hops_left)
        . "\n"
        . "   Out    Fail   %Fail Retry AvgSend Avg_Hops CurrHops\n"
        . sprintf("%6s", $$self{outgoing_count_log})
        . sprintf("%8s", $$self{fail_count_log})
        . sprintf("%8s", $fail_percentage . '%')
        . sprintf("%6s", $$self{retry_count_log})
        . sprintf("%8s", $retry_average)
        . sprintf("%9s", $avg_out_hops)
        . sprintf("%9s", $self->default_hop_count)
    );
}


=item C<check_aldb_version>

Because of the way MH saves / restores states "after" object creation
the aldb must be initially created before the engine_version is restored.
It is therefore impossible to know the device is i2 before creating
the aldb object.  The solution is to keep the existing logic which assumes
the device is peek/poke capable (i1 or i2) and then delete/recreate the 
aldb object if it is later determined to be an i2 device. 

There is a use case where a device is initially I2 but the user replaces
the device with an I1 device, reusing the same object name.  In this case
the object state restore will build an I2 aldb object.  The user must 
manually initiate the 'get engine version' voice command or stop/start
MH so the initial poll will detect the change. 

This is called anytime the engine_version is queried (initial startup poll) and
in the Reload_post_hooks once object_states_restore completes

=cut

sub check_aldb_version
{
	my ($self) = @_;

	my $engine_version = $self->SUPER::engine_version();
	my $new_version = "";
	if($engine_version and $engine_version ne 'I1' and $self->_aldb->aldb_version() ne 'I2') {
		$new_version = "I2";
	}
	elsif($engine_version eq 'I1' and $self->_aldb->aldb_version() ne 'I1') {
		$new_version = "I1";
	}
	if ($new_version) {
		main::print_log("[Insteon::BaseDevice] DEBUG4: aldb_version is "
			.$self->_aldb->aldb_version()." but device is ".$engine_version.
			".  Remapping aldb version to $new_version") if $self->debuglevel(4, 'insteon');
		my $restore_string = '';
		if ($self->_aldb) {
			$restore_string = $self->_aldb->restore_string();
		}
		undef $self->{aldb};

		if ($new_version eq "I2") {
			$self->{aldb} = new Insteon::ALDB_i2($self);
		}
		else {
			$self->{aldb} = new Insteon::ALDB_i1($self);
		} 
		
		package main;
		eval ($restore_string);
		&::print_log("[Insteon::BaseDevice] error in eval creating ALDB object: " . $@)
			if $@ and $self->debuglevel(1, 'insteon');
		package Insteon::BaseDevice;
	}
}

=item C<get_voice_cmds>

Returns a hash of voice commands where the key is the voice command name and the
value is the perl code to run when the voice command name is called.

Higher classes which inherit this object may add to this list of voice commands by
redefining this routine while inheriting this routine using the SUPER function.

This routine is called by L<Insteon::generate_voice_commands> to generate the
necessary voice commands.

=cut 

sub get_voice_cmds
{
    my ($self) = @_;
    my $object_name = $self->get_object_name;
    my %voice_cmds = (
        %{$self->SUPER::get_voice_cmds},
        'link to interface' => "$object_name->link_to_interface",
        'unlink with interface' => "$object_name->unlink_to_interface"
    );
    if ($self->is_root){
        %voice_cmds = (
            %voice_cmds,
            'status' => "$object_name->request_status",
            'get engine version' => "$object_name->get_engine_version",
            'scan link table' => "$object_name->scan_link_table(\"" . '\$self->log_alllink_table' . "\")",
            'print message stats' => "$object_name->print_message_stats",
            'reset message stats' => "$object_name->reset_message_stats",
            'run stress test' => "$object_name->stress_test(5)",
            'run ping test' => "$object_name->ping(5)",
            'log links' => "$object_name->log_alllink_table()"
        )
    }
    return \%voice_cmds;
}

=item C<link_data3>

Returns the data3 value that should be used when creating a link for this device.  
This sub provides the default for all Insteon devices.  Individual device 
definitions can override this sub to return something unique.  This sub was 
modivated by the need to return unique values for data3 on responder links for 
group 01.  Most Insteon devices will learn 00 for the data3 responder link value, 
however the In-LineLinc Relay learns 01 when manually linking and requires that 
value when creating the links programmatically.

=cut 

sub link_data3
{
	my ($self, $group, $is_controller) = @_;

	my $link_data3;

	if( $is_controller) {
		#Default to 01 if no group was supplied
		#Otherwise just return the group
		$link_data3 = ($group) ? $group : '01';
	} else { #is_responder
		#Default to 00 if no group was supplied
		$link_data3 = ($group) ? $group : '00';
		
		#Default for group 01 is data3 == 00
		#Override this in inerited classes if needed
		$link_data3 = '00' if( $group eq '01');
	}

	return $link_data3;
}

=back

=head2 INI PARAMETERS

=over 

=item Insteon_PLM_max_queue_time

Was previously used to set the maximum amount of time
a message could remain in the queue.  This parameter is no longer used in the code
but it still appears in the initialization.  It may be removed at a future date.  
This also gets set in L<Insteon::BaseObject|Insteon::BaseInsteon/Insteon::BaseObject>
as well for some reason, but is not used there either.

=back

=head2 AUTHOR

Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

####################################
###                  ###############
### MultigroupDevice ###############
###                  ###############
####################################

=head1 B<Insteon::MultigroupDevice>

=head2 DESCRIPTION

Contains functions which are unique to insteon devices which have more than
one group.  This includes, KeyPadLincs, RemoteLincs, FanLincs, Thermostats 
(i2 versions).

=head2 INHERITS

Nothing.

This package is meant to provide supplemental support and should only be added
as a secondary inheritance to an object.

=head2 METHODS

=over

=cut

package Insteon::MultigroupDevice;

=item C<sync_all_links(audit_mode)>

Syncs all links on the object, including all subgroups such as additional
buttons.

Paramter B<audit_mode> - Causes sync to walk through but not actually 
send any commands to the devices.  Useful with the insteon:3 debug setting for 
troubleshooting. 

=cut

sub sync_all_links
{
	my ($self, $audit_mode) = @_;
	$self = $self->get_root();
	@{$$self{_sync_devices}} = ();
	@{$$self{_sync_device_failures}} = ();
	my $device_id = $self->device_id();
	my ($subgroup_object, $group, $dec_group);
	
	::print_log("[Insteon::MultigroupDevice] Sync All Links on device "
		.$self->get_object_name . " starting ...");
	# Find all subgroup items check groups from 02 - FF;
	for ($dec_group = 01; $dec_group <= 255; $dec_group++) {
		$group = sprintf("%02X", $dec_group);
		$subgroup_object = Insteon::get_object($device_id, $group);
		if (ref $subgroup_object){
			my %sync_req = ('sync_object' => $subgroup_object, 
					'audit_mode' => ($audit_mode) ? 1 : 0);
			::print_log("[Insteon::MultigroupDevice] "
				."Adding " . $subgroup_object->get_object_name 
				." to sync queue.");
			push @{$$self{_sync_devices}}, \%sync_req
		}
	}
	$$self{_sync_cnt} = scalar @{$$self{_sync_devices}};
	$self->_get_next_linksync();
}

=item C<_get_next_linksync()>

Calls the sync_links() function for each device identified by sync_all_link.  
This function will be called recursively since the callback passed to sync_links() 
is this function again.  Will also ask sync_links() to call 
_get_next_linksync_failure() if sync_links() fails. 

=cut

sub _get_next_linksync
{
	my ($self) = @_;
	$self = $self->get_root();
	my $sync_req_ptr = shift(@{$$self{_sync_devices}});
	my %sync_req = ($sync_req_ptr) ? %$sync_req_ptr : undef;
	my $current_sync_device;
	if (%sync_req) {
		$current_sync_device = $sync_req{'sync_object'};
	}
	else {
		$current_sync_device = undef;
	}

	if ($current_sync_device) {
		::print_log("[Insteon::MultigroupDevice] Now syncing: "
			. $current_sync_device->get_object_name . " ("
			. ($$self{_sync_cnt} - scalar @{$$self{_sync_devices}})
			. " of ".$$self{_sync_cnt}.")");
		$current_sync_device->sync_links($sync_req{'audit_mode'}, 
			$self->get_object_name . '->_get_next_linksync()',
			$self->get_object_name . '->_get_next_linksync_failure('.$current_sync_device->get_object_name.')');
	}
	else {
		::print_log("[Insteon::MultigroupDevice] All links have completed syncing "
				. "on device " . $self->get_object_name);
		my $_sync_failure_cnt = scalar @{$$self{_sync_device_failures}};
		if ($_sync_failure_cnt) {
			::print_log("[Insteon::MultigroupDevice] However, some failures were noted:");
			for my $failed_obj (@{$$self{_sync_device_failures}}) {
				::print_log("[Insteon::MultigroupDevice] WARN: failure occurred when syncing "
				. $failed_obj->get_object_name);
			}
		}
	}
}

=item C<_get_next_linksync()>

Called by the failure callback in a device's sync_links() function.  Will add
the failed device to the module global variable @_sync_device_failures. 

=cut

sub _get_next_linksync_failure
{
	my ($self, $current_sync_device) = @_;
	$self = $self->get_root();
	push @{$$self{_sync_device_failures}}, $current_sync_device;
	::print_log("[Insteon::MultigroupDevice] WARN: failure occurred when syncing "
		. $current_sync_device->get_object_name . ".  Moving on...");
	$self->_get_next_linksync();
}

=back

=head2 AUTHOR

Kevin Robert Keegan

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

####################################
###                #################
### BaseController #################
###                #################
####################################

=head1 B<Insteon::BaseController>

=head2 DESCRIPTION

Generic class implementation of an Insteon Controller.

=head2 INHERITS

L<Generic_Item|Generic_Item>

=head2 METHODS

=over

=cut

package Insteon::BaseController;

use strict;

@Insteon::BaseController::ISA = ('Generic_Item');

=item C<new()>

Instantiates a new object.

=cut

sub new
{
	my ($class,$p_deviceid,$p_interface,$p_devcat) = @_;

	# note that $p_deviceid will be 00.00.00:<groupnum> if the link uses the interface as the controller
	my $self = {};
	bless $self,$class;
	return $self;
}

=item C<add(object[,on_level, ramp_rate])>

Adds object as a responder to the device.  If on_level and ramp_rate are specified
they will be used, otherwise 100% .1s will be used.

=cut

sub add
{
	my ($self, $obj, $on_level, $ramp_rate) = @_;
	if (ref $obj and ($obj->isa('Light_Item') or $obj->isa('Insteon::BaseDevice')))
        {
		if ($$self{members} && $$self{members}{$obj})
                {
			print "[Insteon::BaseController] An object (" . $obj->{object_name} . ") already exists "
				. "in this scene.  Aborting add request.\n";
			return;
		}
		if ($on_level =~ /^sur/i)
                {
			$on_level = '100%';
			$$obj{surrogate} = $self;
		}
                elsif (lc $on_level eq 'on')
                {
			$on_level = '100%';
		}
                elsif (lc $on_level eq 'off')
                {
			$on_level = '0%';
		}
		$on_level = '100%' unless $on_level;
		$$self{members}{$obj}{on_level} = $on_level;
		$$self{members}{$obj}{object} = $obj;
		$ramp_rate =~ s/s$//i;
		$$self{members}{$obj}{ramp_rate} = $ramp_rate if defined $ramp_rate;
	} else {
		&::print_log("[Insteon::BaseController] WARN: unable to add ".$obj->{device_id}.":".$obj->{m_group}
			." as items of type ".ref($obj)." are not supported!");
        }
}

=item C<sync_links(audit_mode)>

Causes MisterHouse to review the list of objects that should be linked to device
and to check to make sure these links are complete.  If any link is not complete
MisterHouse will add the link.

If audit_mode is true, MisterHouse will print the actions it would have taken to 
the log, but will not take any actions.

The process does the following 5 checks in order:

 1. Does a controller link exist for Device-> PLM
 2. Does a responder link exist on the PLM

it then loops through all of the links defined for a device and checks:

 3. Does the responder link exist
 4. Is the responder link accurate
 5. Does the controller link on this device exist

=cut

sub sync_links
{
	my ($self, $audit_mode, $callback, $failure_callback, $skip_deaf) = @_;
	
	# Intialize Variables
	@{$$self{sync_queue}} = (); # reset the work queue
	$$self{sync_queue_callback} = ($callback) ? $callback : undef;
	$$self{sync_queue_failure_callback} = ($failure_callback) ? $failure_callback : undef;
	$$self{sync_queue_failure} = undef;
	my $self_link_name = $self->get_object_name;
	my $interface_object = Insteon::active_interface();
	my $interface_name = $interface_object->get_object_name;
	my $insteon_object = $self->get_root;
	::print_log("[Insteon::BaseController] WARN!! A device w/ insteon address: " . $self->device_id . ":01 could not be found. "
		. "Please double check your items.mht file.") if (!(defined($insteon_object)));

	# Abort if $insteon_object doesn't exist
	$self->_process_sync_queue() unless $insteon_object;
	
	# Warn if device is deaf or ALDB out of sync
	my $insteon_object_is_syncable = 1;
	if ($insteon_object->is_deaf && $skip_deaf) {
		::print_log("[Insteon::BaseController] $self_link_name is deaf, only responder links will be added to devices "
			."controlled by this device.  To sync links on this device, put it in awake mode and run the 'Sync Links' "
			."command on this specific device.");
		$insteon_object_is_syncable = 0;
	}
	elsif ($insteon_object->_aldb->health ne 'good' && $insteon_object->_aldb->health ne 'empty'){
		::print_log("[Insteon::BaseController] WARN! The ALDB of $self_link_name is ".$insteon_object->_aldb->health
			.", links will be added to devices "
			."linked to this device, but no links will be added to $self_link_name.  Please rescan this device and attempt "
			."sync links again.");
		$insteon_object_is_syncable = 0;
		$$self{sync_queue_failure} = 1;
	}
	
	# 1. Does a controller link exist for Device-> PLM
	if (!$insteon_object->isa('Insteon_PLM') && 
	!$insteon_object->has_link($self->interface,$self->group,1,$self->group) && 
	$insteon_object_is_syncable) {
		my %link_req = ( member => $insteon_object, cmd => 'add', object => $self->interface,
			group => $self->group, is_controller => 1,
			callback => "$self_link_name->_process_sync_queue()",
			failure_callback => $failure_callback,
			data3 => $self->group);
		$link_req{cause} = "Adding controller record to $self_link_name for $interface_name";
		push @{$$self{sync_queue}}, \%link_req;
	}
		
	# 2. Does a responder link exist on the PLM
	if ((!$insteon_object->isa('Insteon_PLM') &&
	!$self->interface->has_link($insteon_object,$self->group,0,'00'))) {
		my %link_req = ( member => $self->interface, cmd => 'add', object => $insteon_object,
			group => $self->group, is_controller => 0,
			callback => "$self_link_name->_process_sync_queue()",
			failure_callback => $failure_callback,
			data3 => '00');
		$link_req{cause} = "Adding responder record to $interface_name from $self_link_name";
		push @{$$self{sync_queue}}, \%link_req;
	}

	# Loop members
	MEMBER: foreach my $member_ref (keys %{$$self{members}}) {
		my $member = $$self{members}{$member_ref}{object};
		
		# find real device if member is a Light_Item
		if ($member->isa('Light_Item')) {
			my @children = $member->find_members('Insteon::BaseDevice');
			$member = $children[0];
		}
		
		#Initialize Loop Variables
		my $member_name = $member->get_object_name;
		my $member_root = $member->get_root;
		my $requires_update = 0;
		my $has_link = 1;
		my $cause;
		my $tgt_on_level = $$self{members}{$member_ref}{on_level};
		$tgt_on_level = '100' unless defined $tgt_on_level;
		my $tgt_ramp_rate = $$self{members}{$member_ref}{ramp_rate};
		$tgt_ramp_rate = '0' unless defined $tgt_ramp_rate;
		$tgt_on_level =~ s/(\d+)%?/$1/;
		$tgt_ramp_rate =~ s/(\d)s?/$1/;
		my $resp_aldbkey = $member_root->_aldb->get_linkkey($insteon_object->device_id,
								$self->group,
								'0',
								$member->group);

		# If this is an attempt to create a link between two objects on the same
		# device, then skip.  Currently, a KPL can do this with a seperate
		# routine, but IntraDevice links are not allowed by any other known device
		if ($member_root eq $insteon_object){
		    ::print_log("[Insteon::Sync_Links] Skipping intralink to $member_name.")
			    if $insteon_object->debuglevel(2, 'insteon');
		    next MEMBER;
		}

		# 3. Does the responder link exist
		if (!$member_root->has_link($insteon_object, $self->group, 0, $member->group) &&
		($member_root->_aldb->health eq 'good' || $member_root->_aldb->health eq 'empty')){
			my %link_req = ( member => $member, cmd => 'add', object => $insteon_object,
				group => $self->group, is_controller => 0,
				on_level => $tgt_on_level, ramp_rate => $tgt_ramp_rate,
				callback => "$self_link_name->_process_sync_queue()",
				failure_callback => $failure_callback,
				data3 => $member->group);
			$link_req{cause} = "Adding responder record to $member_name from $self_link_name";
			push @{$$self{sync_queue}}, \%link_req;
			$has_link = 0;
		} 
		elsif ($member_root->_aldb->health ne 'good' && $member_root->_aldb->health ne 'empty'){
			my %link_req = ( member => $member, cmd => 'add', object => $insteon_object,
				group => $self->group, is_controller => 0,
				on_level => $tgt_on_level, ramp_rate => $tgt_ramp_rate,
				callback => "$self_link_name->_process_sync_queue()",
				failure_callback => $failure_callback,
				data3 => $member->group);
			$link_req{skip} = "Unable to add the following responder record to $member_name "
				."from $self_link_name because the aldb of $member_name is "
				. $member_root->_aldb->health;
			push @{$$self{sync_queue}}, \%link_req;
			$$self{sync_queue_failure} = 1;
		}
		
		# 4. Is the responder link accurate
		if ($member->isa('Insteon::DimmableLight') && $has_link) {
			my $member_aldb = $member_root->_aldb;
			my $data1 = $$member_aldb{aldb}{$resp_aldbkey}{data1};
			my $data2 = $$member_aldb{aldb}{$resp_aldbkey}{data2};
			my $cur_on_level = hex($data1)/2.55;
			my $raw_cur_ramp_rate = $data2;
			my $raw_tgt_ramp_rate = Insteon::DimmableLight::convert_ramp($tgt_ramp_rate);
			if ($raw_cur_ramp_rate ne $raw_tgt_ramp_rate) {
				$requires_update = 1;
				$cause .= "Ramp rate ";
			}
			elsif ($cur_on_level-1 > $tgt_on_level && $cur_on_level+1 < $tgt_on_level){
				$requires_update = 1;
				$cause .= "On level ";
			}
		}
		elsif ($has_link){
			my $member_aldb = $member->_aldb;
			my $data1 = $$member_aldb{aldb}{$resp_aldbkey}{data1};
			my $data2 = $$member_aldb{aldb}{$resp_aldbkey}{data2};
			if ($tgt_on_level >= 1 and $data1 ne 'ff') {
				$requires_update = 1;
				$tgt_on_level = 100;
				$cause .= "On level ";
			}
			elsif ($tgt_on_level == 0 and $data1 ne '00') {
				$requires_update = 1;
				$cause .= "On level ";
			}
			if ($data2 ne '00') {
				$requires_update = 1;
				$tgt_ramp_rate = 0;
				$cause .= "Ramp rate ";
			}
		}
		if ($requires_update &&
		($member_root->_aldb->health eq 'good' || $member_root->_aldb->health eq 'empty')) {
			my %link_req = ( member => $member, cmd => 'update', object => $insteon_object,
				group => $self->group, is_controller => 0,
				on_level => $tgt_on_level, ramp_rate => $tgt_ramp_rate,
				callback => "$self_link_name->_process_sync_queue()",
				failure_callback => $failure_callback,
				data3 => $member->group);
			$link_req{cause} = "Updating responder record on $member_name "
				. "to fix $cause";
			push @{$$self{sync_queue}}, \%link_req;
		}

		# 5. Does the controller link on this device exist
		if (!($insteon_object->has_link($member, $self->group, 1, $self->group)) &&
		$insteon_object_is_syncable) {
			my %link_req = ( member => $insteon_object, cmd => 'add', object => $member,
				group => $self->group, is_controller => 1,
				callback => "$self_link_name->_process_sync_queue()",
				failure_callback => $failure_callback,
				data3 => $self->group);
			$link_req{cause} = "Adding controller record to $self_link_name for $member_name";
			push @{$$self{sync_queue}}, \%link_req;
		}
	}
	
	my $num_sync_queue = @{$$self{sync_queue}};
	my $index = 0;
	if (!($num_sync_queue))
	{
		&::print_log("[Insteon::BaseController] Nothing to do when syncing links for " . $self->get_object_name)
			if $self->debuglevel(1, 'insteon');
	}
	foreach (@{$$self{sync_queue}}){
		my %sync_req = %{$_};
		my $audit_text = "(AUDIT)" if ($audit_mode);
		my $log_text = "[Insteon::BaseController] $audit_text ";
		if ($sync_req{skip}){
			$log_text .= $sync_req{skip} ."\n";
			splice @{$$self{sync_queue}}, $index, 1;
		} else {
			$index++;
			$log_text .= $sync_req{cause} . "\n";
		}
		PRINT: for (keys %sync_req) {
			next PRINT if (($_ eq 'cause') || ($_ eq 'callback') ||
				($_ eq 'member') || ($_ eq 'object') || 
				($_ eq 'skip') || ($_ eq 'failure_callback'));
			$log_text .= "$_ = $sync_req{$_}; ";
		}
		::print_log($log_text);
	}
	if ($audit_mode) {
		@{$$self{sync_queue}} = ();
	}
	
	$self->_process_sync_queue();
}

sub _process_sync_queue {
	my ($self) = @_;
	# get next in queue if it exists
	my $num_sync_queue = @{$$self{sync_queue}};
	if ($num_sync_queue) {
		my $link_req_ptr = shift(@{$$self{sync_queue}});
		my %link_req = %$link_req_ptr;
		if ($link_req{cmd} eq 'update') {
			my $link_member = $link_req{member};
			$link_member->update_link(%link_req);
		} elsif ($link_req{cmd} eq 'add') {
			my $link_member = $link_req{member};
			$link_member->add_link(%link_req);
		}
	} elsif ($$self{sync_queue_callback}) {
		my $callback = $$self{sync_queue_callback};
		if ($$self{sync_queue_failure}){
			$callback = $$self{sync_queue_failure_callback};
		}
		package main;
		eval ($callback);
		&::print_log("[Insteon::BaseController] error in sync links callback: " . $@)
			if $@ and $self->debuglevel(1, 'insteon');
		package Insteon::BaseController;
	} else {
		main::print_log($self->get_object_name." completed sync links");
	}
}

=item C<set_linked_devices(state)>

Checks each linked member of device.  If the linked member is a C<light_item>, 
then sets that item to state.  If the linked member is a C<Insteon::BaseObject>
then call C<set_receive> for the member.

=cut

sub set_linked_devices
{
	my ($self, $link_state) = @_;
	# iterate over the members
	if ($$self{members})
	{
		foreach my $member_ref (keys %{$$self{members}})
		{
			my $member = $$self{members}{$member_ref}{object};
			# If controller is on, set member to stored on_level
			# else set to controller value
			my $local_state = $$self{members}{$member_ref}{on_level};
			$local_state = '100' unless $local_state;
			
			if ($member->isa('Light_Item'))
			{
			# if they are Light_Items, then set their on_dim attrib to the member on level
			#   and then "blank" them via the manual method for a tad over the ramp rate
			#   In addition, locate the Light_Item's Insteon_Device member and do the
			#   same as if the member were an Insteon_Device
				my $ramp_rate = $$self{members}{$member_ref}{ramp_rate};
				$ramp_rate = 0 unless defined $ramp_rate;
				$ramp_rate = $ramp_rate + 2;
				my @lights = $member->find_members('Insteon::BaseDevice');
				if (@lights)
				{
					my $light = $lights[0];
					# remember the current state to support resume
					$$self{members}{$member_ref}{resume_state} = $light->state;
					$member->manual($light, $ramp_rate);
					if (lc $link_state ne 'on'){
						$local_state = $light->$link_state;
					}
					$light->set_receive($local_state,$self);
				}
				else
				{
					$member->manual(1, $ramp_rate);
				}
				$member->set_on_state($local_state) unless $link_state eq 'off';
			}
			elsif ($member->isa('Insteon::BaseDevice'))
			{
				# remember the current state to support resume
				$$self{members}{$member_ref}{resume_state} = $member->state;
				# if they are Insteon_Device objects, then simply set_receive their state to
				#   the member on level
				if (lc $link_state ne 'on'){
 					$local_state = $link_state;
				}
				$member->set_receive($local_state,$self);
			}
		}
	}
}

=item C<set_with_timer(state, time, return_state, additional_return_states)>

NOTE - This routine appears to be nearly identical, if not identical to the
C<Generic_Item::set_with_timer()> routine, it is not clear why this routine is
needed here.

See full description of this routine in C<Generic_Item>

=cut

sub set_with_timer {
	my ($self, $state, $time, $return_state, $additional_return_states) = @_;
	return if &main::check_for_tied_filters($self, $state);

	$self->set($state) unless $state eq '';

	return unless $time;

	my $state_change = ($state eq 'off') ? 'on' : 'off';
	$state_change = $return_state if defined $return_state;
	$state_change = $self->{state} if $return_state and lc $return_state eq 'previous';

	$state_change .= ';' . $additional_return_states if $additional_return_states;

	$$self{set_timer} = &Timer::new() unless $$self{set_timer};
	my $object_name = $self->{object_name};
	my $action = "$object_name->set('$state_change')";
	$$self{set_timer}->set($time, $action);
}

=item C<update_members()>

This appears to be a depricated routine that is no longer used.  At a cursory
glance, it may throw an error if called.

=cut

sub update_members
{
	my ($self) = @_;
	# iterate over the members
	if ($$self{members}) {
		foreach my $member_ref (keys %{$$self{members}}) {
			my ($device);
			my $member = $$self{members}{$member_ref}{object};
			my $on_state = $$self{members}{$member_ref}{on_level};
			$on_state = '100%' unless $on_state;
			my $ramp_rate = $$self{members}{$member_ref}{ramp_rate};
			$ramp_rate = 0 unless defined $ramp_rate;
			if ($member->isa('Light_Item')) {
			# if they are Light_Items, then locate the Light_Item's Insteon_Device member
				my @lights = $member->find_members('Insteon::BaseDevice');
				if (@lights) {
					$device = $lights[0];
				}
			} elsif ($member->isa('Insteon::BaseDevice')) {
				$device = $member;
			}
			if ($device) {
				my %current_record = $device->get_link_record($self->device_id . $self->group);
				if (%current_record) {
					&::print_log("[Insteon::BaseController] remote record: $current_record{data1}")
						if $self->debuglevel(1, 'insteon');
				}
			}
		}
	}
}

=item C<initiate_linking_as_controller()>

Places the interface in linking mode as the controller.  To complete the process
press the set button on the responder device until it beeps.  Alternatively,
you may be able to complete the process with 
C<Insteon::BaseDevice::enter_linking_mode()>.

=cut

sub initiate_linking_as_controller
{
	my ($self, $p_group, $success_callback, $failure_callback) = @_;
	# iterate over the members
	if ($$self{members}) {
		foreach my $member_ref (keys %{$$self{members}}) {
			my $member = $$self{members}{$member_ref}{object};
			if ($member->isa('Light_Item')) {
			# if they are Light_Items, then set them to manual to avoid automation
			#   while manually setting light parameters
				$member->manual(1,120,120); # 120 seconds should be enough
			}
		}
	}
	$self->interface()->initiate_linking_as_controller($p_group, $success_callback, $failure_callback);
}

=item C<find_members([type])>

Returns a list of objects that are members of device.  If type is specified, only
members of that type are returned.  Type is a package name, for example: 

    $member->find_members('Insteon::BaseDevice');

=cut

sub find_members
{
	my ($self,$p_type) = @_;

	my @l_found;
	if ($$self{members})
	{
		foreach my $member_ref (keys %{$$self{members}})
		{
			my $member = $$self{members}{$member_ref}{object};
			if ($member->isa($p_type))
			{
				push @l_found, $member;
			}
		}
	}
	return @l_found;

}

=item C<has_member(object)>

Returns true if object is a member of device, else returns false.

=cut

sub has_member
{
	my ($self, $compare_object) = @_;
	foreach my $member_ref (keys %{$$self{members}})
	{
		my $member = $$self{members}{$member_ref}{object};
		if ($member eq $compare_object)
		{
			return 1;
		}
	}
        return 0;
}

=back

=head2 AUTHOR

Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

####################################
###            #####################
### DeviceController ###############
###                  ###############
####################################

=head1 B<Insteon::DeviceController>

=head2 DESCRIPTION

Generic class implementation of an Device Controller.

=head2 INHERITS

L<Insteon::BaseController|Insteon::BaseInsteon/Insteon::BaseController>

=head2 METHODS

=over

=cut

package Insteon::DeviceController;

use strict;

@Insteon::DeviceController::ISA = ('Insteon::BaseController');

=item C<new()>

Instantiates a new object.

=cut

sub new
{
	my ($class,$p_deviceid,$p_interface,$p_devcat) = @_;

	# note that $p_deviceid will be 00.00.00:<groupnum> if the link uses the interface as the controller
	my $self = new Insteon::BaseController($p_deviceid,$p_interface);
	bless $self,$class;
	return $self;
}

=item C<request_status([requestor])>

Requests the current status of the device and calls C<set()> on the response.  
This will trigger tied_events.

=cut

sub request_status
{
	my ($self,$requestor) = @_;
#	if ($self->group ne '01') {
	if ($$self{members} and !($self->isa('Insteon::InterfaceController'))
             and (!(ref $requestor) or ($requestor eq $self))) {
		&::print_log("[Insteon::DeviceController] requesting status for members of " . $$self{object_name});
		foreach my $member (keys %{$$self{members}}) {
			next unless $member->isa('Insteon::BaseObject');
			my $member_obj = $$self{members}{$member}{object};
			next if $requestor eq $member_obj;
                        if ($member_obj->isa('Insteon::BaseDevice')) {
			   &::print_log("[Insteon::DeviceController] checking status of " . $member_obj->get_object_name()
				. " for requestor " . $requestor->get_object_name());
			   $member_obj->request_status($self);
                        }
		}
	}
        # the following has bad assumptions in that we don't always know if a device is a responder
        #    since it could be a slave
	if ($self->is_root && $self->is_responder) {
		$self->Insteon::BaseDevice::request_status($requestor);
	}
}

=back

=head2 AUTHOR

Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

####################################
###                     ############
### InterfaceController ############
###                     ############
####################################

=head1 B<Insteon::InterfaceController>

=head2 DESCRIPTION

Generic class implementation of an Interface Controller.  These are the PLM Scenes.

=head2 INHERITS

L<Insteon::BaseController|Insteon::BaseInsteon/Insteon::BaseController>, 
L<Insteon::BaseObject|Insteon::BaseInsteon/Insteon::BaseObject>

=head2 METHODS

=over

=cut

package Insteon::InterfaceController;

use strict;

@Insteon::InterfaceController::ISA = ('Insteon::BaseController','Insteon::BaseObject');

=item C<new()>

Instantiates a new object.

=cut

sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	# note that $p_deviceid will be 00.00.00:<groupnum> if the link uses the interface as the controller
	my $self = new Insteon::BaseObject($p_deviceid,$p_interface);
	bless $self,$class;

	#off=>ALL-Link Alias 1 Low, 'on'=>All-Link Recall 
	$self->set_states('off','on');

	return $self;
}


#Otherwise BaseController will call Generic_Item::Set
sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;
	$self->Insteon::BaseObject::set($p_state,$p_setby,$p_response);	
}

sub is_root
{
   return 0;
}

=item C<get_root()>

Returns the root object of a device, in this case the interface.

=cut

sub get_root {
	my ($self) = @_;
	return $self->interface;
}

# For IFaceControllers, need to call set_linked_devices
sub is_acknowledged {
	my ($self, $p_ack) = @_;
	if ($p_ack) {
		$self->set_linked_devices($$self{pending_state}) if defined $$self{pending_state};	
	}
	return $self->Insteon::BaseObject::is_acknowledged($p_ack);
}

=item C<get_voice_cmds>

Returns a hash of voice commands where the key is the voice command name and the
value is the perl code to run when the voice command name is called.

Higher classes which inherit this object may add to this list of voice commands by
redefining this routine while inheriting this routine using the SUPER function.

This routine is called by L<Insteon::generate_voice_commands> to generate the
necessary voice commands.

=cut 

sub get_voice_cmds
{
    my ($self) = @_;
    my $object_name = $self->get_object_name;
    my $group = $self->group;
    my %voice_cmds = (
        %{$self->SUPER::get_voice_cmds},
	'on' => "$object_name->set(\"on\")",
	'off' => "$object_name->set(\"off\")",
        'initiate linking as controller' => "$object_name->initiate_linking_as_controller(\"$group\")",
        'cancel linking' => "$object_name->interface()->cancel_linking"
    );
    return \%voice_cmds;
}

=back

=head2 AUTHOR

Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;
