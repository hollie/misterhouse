
package Insteon::BaseInterface;

use strict;
use Insteon::Message;
@Insteon::BaseInterface::ISA = ('Class::Singleton');

sub check_for_data
{
   my $interface = &Insteon::active_interface();
   $interface->check_for_data();
}

sub poll_all {
   my $scan_at_startup = $main::config_parms{Insteon_PLM_scan_at_startup};
   $scan_at_startup = 1 unless defined $scan_at_startup;
   $scan_at_startup = 0 unless $main::Save{mh_exit} eq 'normal';
      my $plm = &Insteon::active_interface();
      if (defined $plm) {
         if (!($plm->device_id) and !($$plm{_id_check})) {
		$$plm{_id_check} = 1;
		$plm->queue_message(new Insteon::InsteonMessage('plm_info', $plm));
         }
         if ($scan_at_startup) {

         for my $insteon_device (&Insteon::find_members('Insteon::BaseDevice')) {
            if ($insteon_device and $insteon_device->is_root and $insteon_device->is_responder)
            {
               # don't request status for objects associated w/ other than the primary group
               #    as they are psuedo links
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
	bless $self, $class;
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

sub debug
{
	my ($self, $debug) = @_;
        if (defined $debug)
        {
        	$$self{debug} = $debug;
        }
        return $$self{debug};
}

sub _is_duplicate
{
	my ($self, $cmd) = @_;
        return 1 if ($self->active_message && $self->active_message->interface_data eq $cmd);
	my $duplicate_detected = 0;
	# check for duplicates of $cmd already in command_stack and ignore if they exist
	foreach my $message (@{$$self{command_stack2}}) {
		if ($message->interface_data eq $cmd) {
			$duplicate_detected = 1;
			last;
		}
	}
	return $duplicate_detected;
}

sub has_link
{
	my ($self, $insteon_object, $group, $is_controller, $subaddress) = @_;
	my $key = lc $insteon_object->device_id . $group . $is_controller;
	return (defined $$self{links}{$key}) ? 1 : 0;
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
#        $self->_clear_timeout('command');
	$$self{xmit_in_progress} = 0;
}

sub retry_active_message
{
	my ($self) = @_;
#        $self->_clear_timeout('command');
	$$self{xmit_in_progress} = 0;
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
		if ($self->_is_duplicate($message->interface_data) && !($message->isa('Insteon::X10Message'))) {
			&main::print_log("[Insteon_PLM] Attempt to queue command already in queue; skipping ...") if $main::Debug{insteon};
		} else {
			my $queue_size = @{$$self{command_stack2}};
#			&main::print_log("[Insteon_PLM] Command stack size: $queue_size") if $queue_size > 0 and $main::Debug{insteon};
                        $message->queue_time($::Time);
			if ($setby and ref($setby) and $setby->can('set_retry_timeout')
                           and $setby->get_object_name) {
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
	return $command_queue_size unless !($$self{xmit_in_progress});

	# get pending command record
	my $pending_message = $self->active_message;

	if (!($pending_message)) {
        	$pending_message = pop(@{$$self{command_stack2}});
        	$self->active_message($pending_message) if $pending_message;
		#put the command back into the stack.. Its not our job to tamper with this array
	#	push(@{$$self{command_stack2}},$pending_message) if $pending_message;
	}

	#we dont transmit on top of another xmit
	if (!($$self{xmit_in_progress})) { # && ($self->_check_timeout('command')!=0)) {
		#always send the oldest command first
		if ($pending_message)
		{
			if (!($self->_check_timeout('xmit')==0)) {

                                if ($self->active_message->send($self) == 0)
                                {
                                	&::print_log("[Insteon_PLM] WARN: number of retries ("
                                        	. $self->active_message->send_attempts
                       				. ") for " . $self->active_message->to_string()
                                                . " exceeds limit.  Now moving on...") if $main::Debug{insteon};
                                        # !!!!!!!!! TO-DO - handle failure timeout ???
                                        my $failed_message = $self->active_message;
                			# clear active message
                			$self->clear_active_message();

                                        # may instead want a "failure" callback separate from success callback
					if ($failed_message->callback) {
		       				package main;
						eval $failed_message->callback;
						&::print_log("[Insteon::BaseInterface] problem w/ retry callback: $@") if $@;
						package Insteon::BaseInterface;
					}

                			$self->process_queue();
                                }
                                else
                                {
                                	# may want to move "success" callback handling from message to here
                                }
			}
			my $command_queue_size = @{$$self{command_stack2}};
			return $command_queue_size;
		}
                else
                {
               	 	# clear the timer
                	$self->_clear_timeout('command');
                        return 0;
                }
	} else {
#		&::print_log("[Insteon_PLM] active transmission; moving on...") if $main::Debug{insteon};
		my $command_queue_size = @{$$self{command_stack2}};
		return $command_queue_size;
	}
	my $command_queue_size = @{$$self{command_stack2}};
	return $command_queue_size;
}

sub device_id {
	my ($self, $p_deviceid) = @_;
	$$self{deviceid} = $p_deviceid if defined $p_deviceid;
	return $$self{deviceid};
}

sub get_device
{
	my ($self, $p_deviceid, $p_group) = @_;
	foreach my $device (&Insteon::find_members('Insteon::BaseDevice')) {
		if (lc $device->device_id eq lc $p_deviceid and lc $device->group eq lc $p_group) {
			return $device;
		}
	}
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
	my ($self) = @_;
        return $self->_aldb->delete_orphan_links if $self->_aldb;
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
	if (%msg)
        {
		# get the matching object
		my $object = &Insteon::get_object($msg{source}, $msg{group});
		if (defined $object)
                {
                	if ($msg{type} ne 'broadcast')
                        {
                		$msg{command} = $object->message_type($msg{cmd_code});
		      		&::print_log("[Insteon::Message] command:$msg{command}; type:$msg{type}; group: $msg{group}")
                        		if (!($msg{is_ack} or $msg{is_nack})) and $main::Debug{insteon};
                   	}
#		   	&::print_log("[Insteon_PLM] Processing message for " . $object->get_object_name) if $main::Debug{insteon};
		   	$object->_process_message($self, %msg);
                   	if ($msg{is_ack} or $msg{is_nack})
                   	{
                   		$self->clear_active_message();
                   	}
		}
                else
                {
         		&::print_log("[Insteon_PLM] Warn! Unable to locate object for source: $msg{source} and group: $msg{group}");
		}
		# treat the message as legitimate even if an object match did not occur
	}
}

sub on_extended_insteon_received
{
        my ($self, $message_data) = @_;
	my %msg = &Insteon::InsteonMessage::command_to_hash($message_data);
	if (%msg)
        {
		# get the matching object
		my $object = &Insteon::get_object($msg{source}, $msg{group});
		if (defined $object)
                {
                	if ($msg{type} ne 'broadcast')
                        {
                		$msg{command} = $object->message_type($msg{cmd_code});
		      		&::print_log("[Insteon::Message] command:$msg{command}; type:$msg{type}; group: $msg{group}")
                        		if (!($msg{is_ack} or $msg{is_nack})) and $main::Debug{insteon};
                   	}
		   	&::print_log("[Insteon_PLM] Processing message for " . $object->get_object_name) if $main::Debug{insteon};
		   	$object->_process_message($self, %msg);
                   	if ($msg{is_ack} or $msg{is_nack})
                   	{
                   		$self->clear_active_message();
                   	}
		}
                else
                {
         		&::print_log("[Insteon_PLM] Warn! Unable to locate object for source: $msg{source} and group: $msg{group}");
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


1