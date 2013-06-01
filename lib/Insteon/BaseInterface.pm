
package Insteon::BaseInterface;

use strict;
use Insteon::Message;
@Insteon::BaseInterface::ISA = ('Class::Singleton');

sub check_for_data
{
   my $interface = &Insteon::active_interface();
   $interface->check_for_data();
}

sub poll_all
{
   my $scan_at_startup = $main::config_parms{Insteon_PLM_scan_at_startup};
   $scan_at_startup = 1 unless defined $scan_at_startup;
   $scan_at_startup = 0 unless $main::Save{mh_exit} eq 'normal';
      my $plm = &Insteon::active_interface();
      if (defined $plm)
      {
         if (!($plm->device_id) and !($$plm{_id_check}))
         {
		$$plm{_id_check} = 1;
		$plm->queue_message(new Insteon::InsteonMessage('plm_info', $plm));
         }
         if ($scan_at_startup)
         {

         	for my $insteon_device (&Insteon::find_members('Insteon::BaseDevice'))
                {
            		if ($insteon_device and $insteon_device->is_root and $insteon_device->is_responder)
            		{
               		# don't request status for objects associated w/ other than the primary group
               		#    as they are psuedo links
                                $insteon_device->get_engine_version();
               			$insteon_device->request_status();
            		}
               		if ($insteon_device->devcat) {
              		 # reset devcat so as to trigger any device specific properties
               			$insteon_device->devcat($insteon_device->devcat);
            		}
         	}
         }
      }
}

sub new
{
	my ($class) = @_;

	my $self = {};
	@{$$self{command_stack2}} = ();
	@{$$self{command_history}} = ();
	$$self{received_commands} = {};
	bless $self, $class;
        $self->transmit_in_progress(0);
#   	$self->debug(0) unless $self->debug;
	return $self;
}

sub equals
{
	my ($self, $compare_object) = @_;
        # make sure that the compare_object is legitimate
        return 0 unless $compare_object && ref $compare_object && $compare_object->isa('Insteon::BaseInterface');
        return 1 if $compare_object eq $self;
        # if they don't both have device_ids then treat them as identical
        return 1 unless $compare_object->device_id && $self->device_id;
        if ($compare_object->device_id eq $self->device_id)
        {
        	return 1;
        }
        else
        {
        	return 0;
        }
}

sub _is_duplicate
{
	my ($self, $cmd) = @_;
        return 1 if ($self->active_message && $self->active_message->interface_data eq $cmd);
	my $duplicate_detected = 0;
	# check for duplicates of $cmd already in command_stack and ignore if they exist
	foreach my $message (@{$$self{command_stack2}})
        {
		if ($message->interface_data eq $cmd)
                {
			$duplicate_detected = 1;
			last;
		}
	}
	return $duplicate_detected;
}

sub has_link
{
	my ($self, $insteon_object, $group, $is_controller, $subaddress) = @_;
        if ($self->_aldb)
        {
           return $self->_aldb->has_link($insteon_object, $group, $is_controller, $subaddress);
        }
	return 0;
}

sub add_link
{
	my ($self, $parms_text) = @_;
        if ($self->_aldb)
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
           	$self->_aldb->add_link(%link_parms);
        }
}

sub delete_link
{
	my ($self, $parms_text) = @_;
        if ($self->_aldb)
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
           	$self->_aldb->delete_link(%link_parms);
        }
}

sub active_message
{
	my ($self, $message) = @_;
        if (defined $message)
        {
        	$$self{active_message} = $message;
        }
        return $$self{active_message};
}

sub clear_active_message
{
	my ($self) = @_;
        $$self{active_message} = undef;
	$self->transmit_in_progress(0);
}

sub retry_active_message
{
	my ($self) = @_;
	$self->transmit_in_progress(0);
}

sub transmit_in_progress
{
	my ($self, $xmit_flag) = @_;
        if (defined $xmit_flag)
        {
        	$$self{xmit_in_progress} = $xmit_flag;
        }
        # also factor in xmit timer since this must be honored to allow
        #   adequate time to elapse
        return $$self{xmit_in_progress} || ($self->_check_timeout('xmit')==0);
}

sub queue_message
{
	my ($self, $message) = @_;

	my $command_queue_size = @{$$self{command_stack2}};
	return $command_queue_size unless $message;

	#queue any new command
	if (defined $message)
	{
        	my $setby = $message->setby;
		if ($self->_is_duplicate($message->interface_data) && !($message->isa('Insteon::X10Message')))
                {
			&main::print_log("[Insteon::BaseInterface] Attempt to queue command already in queue; skipping ...") if $main::Debug{insteon};
		}
                else
                {
			if ($setby and ref($setby) and $setby->can('set_retry_timeout')
                           and $setby->get_object_name)
                        {
				$message->callback($setby->get_object_name . "->set_retry_timeout()");
			}
			unshift(@{$$self{command_stack2}}, $message);
		}
	}
        # and, begin processing either this entry or the oldest one in the queue
        $self->process_queue();
}

sub process_queue
{
	my ($self) = @_;

	my $command_queue_size = @{$$self{command_stack2}};

	if ($self->transmit_in_progress)
        {
        	return $command_queue_size;
        }
        else
	#we dont transmit on top of another xmit
        { # no transmission is progress that has not already been acked or nacked by the PLM
		# get pending command record
       		my $pending_message = $self->active_message;

		if (!($pending_message))
        	{ # no prior message remains; so, get one from the queue
        		$pending_message = pop(@{$$self{command_stack2}});
        		$self->active_message($pending_message) if $pending_message;
		}

		if ($pending_message)
		{ # a message exists to be sent (whether previously sent or queued)

	                if ($self->active_message->send($self) == 0)
                        {  # this only occurs if the retry count has been exceeded
        	                # which also means that there wasn't a message actually sent
                               	&::print_log("[Insteon::BaseInterface] WARN: number of retries ("
                                       	. $self->active_message->send_attempts
                			. ") for " . $self->active_message->to_string()
                                        . " exceeds limit.  Now moving on...") if $main::Debug{insteon};
                                # !!!!!!!!! TO-DO - handle failure timeout ???
                                my $failed_message = $self->active_message;
                                # make sure to let the sending object know!!!
				if (defined($failed_message->setby) and $failed_message->setby->can('is_acknowledged'))
				{
                                       	$failed_message->setby->is_acknowledged(0);
				}
				else
				{
					&main::print_log("[Insteon::BaseInterface] WARN! Unable to clear acknowledge for "
						. ((defined($failed_message->setby)) ? $failed_message->setby->get_object_name : "undefined"));
				}
				# clear active message
				$self->clear_active_message();
                                # may instead want a "failure" callback separate from success callback
				if ($failed_message->failure_callback)
                                {
                                       	&::print_log("[Insteon::BaseInterface] WARN: Message Timeout:  Now calling callback: " .
                                               	$failed_message->failure_callback) if $main::Debug{insteon};
					$failed_message->setby->failure_reason('timeout') 
						if (defined($failed_message->setby) and $failed_message->setby->can('failure_reason'));
		       			package main;
					eval $failed_message->failure_callback;
					&::print_log("[Insteon::BaseInterface] problem w/ retry callback: $@") if $@;
					package Insteon::BaseInterface;
				}
                		$self->process_queue();
                        }
		}
                else # no pending message
                {
               	 	# clear the timer
                	$self->_clear_timeout('command');
                        return 0;
                }
	}
	my $command_queue_size = @{$$self{command_stack2}};
	return $command_queue_size;
}

sub device_id {
	my ($self, $p_deviceid) = @_;
	$$self{deviceid} = $p_deviceid if defined $p_deviceid;
	return $$self{deviceid};
}

sub restore_string
{
	my ($self) = @_;
	my $restore_string = $self->SUPER::restore_string();
	$restore_string .= $self->_aldb->restore_string();
	return $restore_string;
}

sub restore_linktable
{
	my ($self,$aldb) = @_;
	if ($self->_aldb and $aldb) {
           $self->_aldb->restore_linktable($aldb);
	}
}


sub log_alllink_table
{
	my ($self) = @_;
        $self->_aldb->log_alllink_table if $self->_aldb;
}

sub delete_orphan_links
{
	my ($self, $audit_mode) = @_;
        return $self->_aldb->delete_orphan_links($audit_mode) if $self->_aldb;
}

  ######################
 ### EVENT HANDLERS ###
######################

sub on_interface_info_received
{
	my ($self) = @_;
	&::print_log("[Insteon_PLM] PLM id: " . $self->device_id .
		" firmware: " . $self->firmware)
		if $main::Debug{insteon};
        $self->clear_active_message();
}


sub on_standard_insteon_received
{
        my ($self, $message_data) = @_;
	my %msg = &Insteon::InsteonMessage::command_to_hash($message_data);
	return if $self->_is_duplicate_received($message_data, %msg);
	if (%msg)
        {
		my $wait_time;
		my $wait_message = "[Insteon::BaseInterface] DEBUG3: Message received "
			."with $msg{hopsleft} hops left, ";
		if (!$msg{is_ack} && !$msg{is_nack} && $msg{type} ne 'alllink' 
			&& $msg{type} ne 'broadcast') {
			#Wait for ACK to be delivered
			$wait_time = $msg{maxhops};
			$wait_message .= "plus ACK will take $msg{maxhops} to deliver, ";
		}
		$wait_time += $msg{hopsleft};
		#Standard msgs should only take 50 millis, but in practice additional 
		#time has been required. Extra 50 millis helps prevent dupes
		$wait_time = ($wait_time * 100) + 50;
		$wait_message .= "delaying next transmit by $wait_time milliseconds to avoid collisions.";
		::print_log($wait_message) if ($main::Debug{insteon} >= 3 && $wait_time > 50);
		$self->_set_timeout('xmit', $wait_time);			

		# get the matching object
		my $object = &Insteon::get_object($msg{source}, $msg{group});
		if (defined $object)
                {
                	if ($msg{type} ne 'broadcast')
                        {
                		$msg{command} = $object->message_type($msg{cmd_code});
		      		&::print_log("[Insteon::BaseInterface] Received message from: ". $object->get_object_name
		      			."; command: $msg{command}; type: $msg{type}; group: $msg{group}")
                        		if (!($msg{is_ack} or $msg{is_nack})) and $main::Debug{insteon};
                   	}
                   	if ($msg{is_ack} or $msg{is_nack})
                   	{
		      		main::print_log("[Insteon::BaseInterface] DEBUG3: PLM command:insteon_received; "
		      			. "Device command:$msg{command}; type:$msg{type}; group: $msg{group}")
                        		if $main::Debug{insteon} >=3;
                        	# need to confirm that this message corresponds to the current active one before clearing it
                                # TO-DO!!! This is a brute force and poor compare technique; needs to be replaced by full compare
                                if ($self->active_message && ref $self->active_message->setby)
                                {
                                        if ($self->active_message->send_attempts == 0)
                                        {
                                                &main::print_log("[Insteon::BaseInterface] WARN: received ACK/NACK message for "
                                                	. $object->get_object_name . " but cannot correlate to sent message "
                                                        . "(active but send attempts = 0).  IGNORING received message!!");
                                        }
                                        elsif ($msg{type} eq 'direct')
                                        {
                                        	if (lc $self->active_message->setby->device_id eq lc $msg{source})
                                                {
                                                	# prevent re-processing transmit queue until after clearing occurs
                                                        $self->transmit_in_progress(1);
                        		       		# ask the object to process the received message and update its state
                        		       		# Object will return true if this is the end of the send transaction
		   					if($object->_process_message($self, %msg)) {
		   						$self->clear_active_message();
		   					}
                                                }
                                                else
                                                {
                                                	&main::print_log("[Insteon::BaseInterface] WARN: deviceid of "
                                                		. "active message != received message source ("
                                                        	. $object->get_object_name() . "). IGNORING received message!!");
                                                }
                                        }
                                        elsif ($msg{type} eq 'cleanup')
                                        {
                                                $object = &Insteon::get_object('000000', $msg{extra});
                                                if ($object)
                                                {
                                                	# prevent re-processing transmit queue until after clearing occurs
                                                	$self->transmit_in_progress(1);
							# Don't clear active message as ACK is only one of many
							if (($msg{extra} == $self->active_message->setby->group)){
                                                                &main::print_log("[Insteon::BaseInterface] DEBUG3: Cleanup message received for scene "
                                                                	. $object->get_object_name . " from source " . uc($msg{source}))
                                                                	if $main::Debug{insteon} >= 3;
							} elsif ($self->active_message->command_type eq 'all_link_direct_cleanup' &&
								lc($self->active_message->setby->device_id) eq $msg{source}) 
							{
								&::print_log("[Insteon::BaseInterface] DEBUG2: ALL-Linking Direct Completed with ". $self->active_message->setby->get_object_name) if $main::Debug{insteon} >= 2;
								$self->clear_active_message();
							}
							else {
								&main::print_log("[Insteon::BaseInterface] DEBUG3: Cleanup message received from "
								. $msg{source} . " for scene "
								. $object->get_object_name . ", but group in recent message " 
								. $msg{extra}. " did not match group in "
								. "prior sent message group " . $self->active_message->setby->group) 
									if $main::Debug{insteon} >= 3;
                                			}
                                			# If ACK or NACK received then PLM is still working on the ALL Link Command
                                			# Increase the command timeout to wait for next one
                                			$self->_set_timeout('command', 3000);
                                                }
                                                else
                                                {
                                                	&main::print_log("[Insteon::BaseInterface] ERROR: received cleanup message from "
                                                             . $msg{source} . "that does not correspond to a valid PLM group. Corrupted message is assumed "
                                                             . "and will be skipped! Was group " . $msg{extra});
                                                }
                                        }
                                        else #not direct or cleanup
                                        {
                                                &main::print_log("[Insteon::BaseInterface] ERROR: received ACK/NACK message from "
                                                	. $object->get_object_name . " but unable to process $msg{type} message type."
                                                        . " IGNORING received message!!");
                                                $self->active_message->no_hop_increase(1);
                                        }
                        	}
                                else #does not correspond to current active message
                                {
                                        if ($msg{type} eq 'direct')
                                        {
                                        	&main::print_log("[Insteon::BaseInterface] WARN: received insteon ACK/NACK message from "
                                        		. $object->get_object_name . " but cannot correlate to sent message! IGNORING received message!!");
                                        }
                                        elsif ($msg{type} eq 'cleanup')
                                        {
                                                # this is just going to be ignored since there is a virtual processing done
                                                #   in the Insteon_PLM handler for cleanup messages.
                                                #   however, if the virtual handler was not invoked due to receipt of the broadcast message
                                                #   then, the above cleanup handler would be run
                                                &main::print_log("[Insteon::BaseInterface] DEBUG3: received cleanup message responding to "
                                                	. "PLM controller group: $msg{extra}. Ignoring as this has already been processed")
                                                        if $main::Debug{insteon} >= 3;
                                        }
                                        else
                                        {
                        			# ask the object to process the received message and update its state
		   				$object->_process_message($self, %msg);
                                        }
                                }
                   	}
                        else # not ACK or NAK
                        {
                        	# ask the object to process the received message and update its state
		   		$object->_process_message($self, %msg);
                        }
		}
                else 
                {
         		&::print_log("[Insteon::BaseInterface] Warn! Unable to locate object for source: $msg{source} and group: $msg{group}");
		}
		# treat the message as legitimate even if an object match did not occur
	}
}

sub on_extended_insteon_received
{
        my ($self, $message_data) = @_;
	my %msg = &Insteon::InsteonMessage::command_to_hash($message_data);
	return if $self->_is_duplicate_received($message_data, %msg);
	if (%msg)
        {
		my $wait_time;
		my $wait_message = "[Insteon::BaseInterface] DEBUG3: Message received "
			."with $msg{hopsleft} hops left, ";
		if (!$msg{is_ack} && !$msg{is_nack} && $msg{type} ne 'alllink' 
			&& $msg{type} ne 'broadcast') {
			#Wait for ACK to be delivered
			$wait_time = $msg{maxhops};
			$wait_message .= "plus ACK will take $msg{maxhops} to deliver, ";
		}
		$wait_time += $msg{hopsleft};
		#Standard msgs should only take 108 millis, but in practice additional 
		#time has been required. Extra 50 millis helps prevent dupes
		$wait_time = ($wait_time * 200) + 50;
		$wait_message .= "delaying next transmit by $wait_time milliseconds to avoid collisions.";
		::print_log($wait_message) if ($main::Debug{insteon} >= 3 && $wait_time > 50);
		$self->_set_timeout('xmit', $wait_time);

		# get the matching object
		my $object = &Insteon::get_object($msg{source}, $msg{group});
		if (defined $object)
                {
                	if ($msg{type} ne 'broadcast')
                        {
                		$msg{command} = $object->message_type($msg{cmd_code});
		      		main::print_log("[Insteon::BaseInterface] DEBUG: PLM command:insteon_ext_received; "
		      			. "Device command:$msg{command}; type:$msg{type}; group: $msg{group}")
                        		if( (!($msg{is_ack} or $msg{is_nack}) and $main::Debug{insteon}) 
                        		or $main::Debug{insteon} >= 3);
                   	}
		   	&::print_log("[Insteon::BaseInterface] Processing message for " . $object->get_object_name) if $main::Debug{insteon} >=3;
			if($object->_process_message($self, %msg)) {
				$self->clear_active_message();
			}
		}
                else
                {
         		&::print_log("[Insteon::BaseInterface] Warn! Unable to locate object for source: $msg{source} and group: $msg{group}");
		}
		# treat the message as legitimate even if an object match did not occur
	}

}

  #################################
 ### INTERNAL METHODS/FUNCTION ###
#################################

sub _set_timeout
{
	my ($self, $timeout_name, $timeout_in_millis) = @_;
	my $tickcount = &main::get_tickcount + $timeout_in_millis;
	$tickcount += 2**32 if $tickcount < 0; # force a wrap; to be handleded by check timeout
	$$self{"_timeout_$timeout_name"} = $tickcount;
}

#
# return -1 if timeout_name does not match an existing timer
# return 0 if timer has not expired
# return 1 if timer has expired
#
sub _check_timeout
{
	my ($self, $timeout_name) = @_;
	return 0 unless $timeout_name;
	return -1 unless defined $$self{"_timeout_$timeout_name"};
	my $current_tickcount = &main::get_tickcount;
	return 0 if (($current_tickcount >= 2**16) and ($$self{"_timeout_$timeout_name"} < 2**16));
	return ($current_tickcount > $$self{"_timeout_$timeout_name"}) ? 1 : 0;
}

sub _clear_timeout
{
	my ($self, $timeout_name) = @_;
	$$self{"_timeout_$timeout_name"} = undef;
}

sub _aldb
{
   my ($self) = @_;
   return $$self{aldb};
}

# This function attempts to identify erroneous duplicative incoming messages 
# while still permitting identical messages to arrive in close proximity.  For 
# example, a valid identical message is the ACK of an extended aldb read which 
# is always 2F00.
#
# Messages are deemed to be identical if, excluding the max_hops and hops_left
# bits, they are otherwise the same.  Identical messages are deemed to be 
# erroneous if they are received within a calculated message window, $delay.  
#
# The message window is calculated depending on whether the PLM is sending an ACK.
#

# Returns 1 if the received message is a duplicate message
# See discussion at: https://github.com/hollie/misterhouse/issues/169
sub _is_duplicate_received {
	my ($self, $message_data, %msg) = @_;
	my $is_duplicate;

	my $curr_milli = sprintf('%.0f', &main::get_tickcount);

	# $key will be set to $message_data with max hops and hops left set to 0
	my $key = $message_data;
	substr($key,13,1) = 0;
	
	#Standard = 50 millis; Extended = 108 millis;
	#In practice requires 75% more
	my $message_time = (length($message_data) > 18) ? 183 : 87;
	
	#Wait period before PLM can send ACK or next request
	my $max_hops = $msg{hopsleft};

	if (!$msg{is_ack} && !$msg{is_nack} && $msg{type} ne 'alllink' 
		&& $msg{type} ne 'broadcast')
	{
		#ACK sent with same max hops plus 1 for initial timeslot
		$max_hops += $msg{maxhops} + 1;
		#Subsequent Reply, arrives in same number of hops + 1 for intial timeslot
		$max_hops += ($msg{maxhops} - $msg{hopsleft}) + 1;
	} else {
		#Subsequent PLM request is sent with max hops + 1 for intial timeslot
		$max_hops += $msg{maxhops} + 1;
	}

	my $delay = ($message_time * $max_hops);

	#Clean hash of outdated entries
	for (keys %{$$self{received_commands}}){
		if ($$self{received_commands}{$_} < $curr_milli){
			delete($$self{received_commands}{$_});
		}
	}

	#Check if the message exists
	if (exists($$self{received_commands}{$key})){
		$is_duplicate = 1;
		#Reset the time in case there are multiple duplicates
		$$self{received_commands}{$key} = $curr_milli + $delay;
		#Make a nicer name
		my $source = $msg{source};
		my $object = &Insteon::get_object($msg{source}, $msg{group});
		$source = $object->get_object_name() if (defined $object);
		::print_log("[Insteon::BaseInterface] WARN! Dropped duplicate incoming message "
			. $message_data . ", from $source.") if $main::Debug{insteon};
	} else {
		#Message was not in hash, so add it
		$$self{received_commands}{$key} = $curr_milli + $delay;
	}
	return $is_duplicate;
}

1
