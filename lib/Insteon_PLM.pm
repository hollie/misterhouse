=head1 B<Insteon_PLM>

=head2 SYNOPSIS

---Example Code and Usage---

=head2 DESCRIPTION

This is the base interface class for Insteon Power Line Modem (PLM)

=head2 INHERITS

L<Serial_Item|Serial_Item>,
L<Insteon::BaseInterface|Insteon::BaseInterface>

=head2 METHODS

=over

=cut

package Insteon_PLM;

use strict;
use Insteon;
use Insteon::BaseInterface;
use Insteon::BaseInsteon;
use Insteon::AllLinkDatabase;
use Insteon::MessageDecoder;

#@Insteon_PLM::ISA = ('Serial_Item','Socket_Item','Insteon::BaseInterface');
my $PLM_socket = undef;


my %prefix = (
#PLM Serial Commands
                        insteon_received 	=> '0250',
                        insteon_ext_received 	=> '0251',
                        x10_received 		=> '0252',
                        all_link_complete 	=> '0253',
                        plm_button_event 	=> '0254',
                        plm_user_reset		=> '0255',
                        all_link_clean_failed 	=> '0256',
                        all_link_record 	=> '0257',
                        all_link_clean_status 	=> '0258',
                        plm_info 		=> '0260',
                        all_link_send 		=> '0261',
                        insteon_send 		=> '0262',
                        insteon_ext_send	=> '0262',
                        all_link_direct_cleanup => '0262',
                        x10_send 		=> '0263',
                        all_link_start 		=> '0264',
                        all_link_cancel		=> '0265',
			plm_reset 		=> '0267',
                        all_link_first_rec	=> '0269',
                        all_link_next_rec	=> '026a',
			plm_set_config 		=> '026b',
			plm_led_on 		=> '026d',
			plm_led_off 		=> '026e',
                        all_link_manage_rec	=> '026f',
			insteon_nak 		=> '0270',
			insteon_ack 		=> '0271',
			rf_sleep 		=> '0272',
			plm_get_config 		=> '0273'
);

=item C<serial_startup()>

Creates a new serial port connection.

=cut

sub serial_startup {
   my ($instance) = @_;
   my $PLM_use_tcp =0;
   $PLM_use_tcp    = $::config_parms{$instance . "_use_TCP"};
   if ($PLM_use_tcp == 1) {return;}

   my $port       = $::config_parms{$instance . "_serial_port"};
   if (!defined($port)) {
      main::print_log("WARN: ".$instance."_serial_port missing from INI params!");
   }
   my $speed = 19200;

   &::print_log("[Insteon_PLM] serial:$port:$speed");
   &::serial_port_create($instance, $port, $speed,'none','raw');

}

=item C<new()>

Instantiates a new object.

=cut

sub new {
   my ($class, $port_name, $p_deviceid) = @_;
   $port_name = 'Insteon_PLM' if !$port_name;
   my $port       = $::config_parms{$port_name . "_serial_port"};
   my $PLM_use_tcp =0;
   $PLM_use_tcp    = $::config_parms{$port_name . "_use_TCP"};
   my $PLM_tcp_host       = 0;
   my $PLM_tcp_port       = 0;


   if ($PLM_use_tcp == 1)
   {
	@Insteon_PLM::ISA = ('Socket_Item','Insteon::BaseInterface');
    	$PLM_tcp_host       = $::config_parms{$port_name . "_TCP_host"};
    	$PLM_tcp_port       = $::config_parms{$port_name . "_TCP_port"};
    	&::print_log("[Insteon_PLM] 2412N using TCP,  tcp_host=$PLM_tcp_host,  tcp_port=$PLM_tcp_port");
   }
   else
   {
    	if (!defined($port)) {
    		main::print_log("WARN: ".$port_name."_serial_port missing from INI params!");
    	}
    	@Insteon_PLM::ISA = ('Serial_Item','Insteon::BaseInterface');
    	$PLM_use_tcp =0;
    	&::print_log("[Insteon_PLM] 2412[US] using serial,  serial_port=$port");
   }

   my $self = new Insteon::BaseInterface();
   $$self{state}     = '';
   $$self{said}      = '';
   $$self{state_now} = '';
   $$self{port_name} = $port_name;
   $$self{port} = $port;
   $$self{use_tcp} = $PLM_use_tcp;
   $$self{tcp_host} = $PLM_tcp_host;
   $$self{tcp_port} = $PLM_tcp_port;
	$$self{last_command} = '';
	$$self{_prior_data_fragment} = '';
   bless $self, $class;
   $self->restore_data('debug', 'corrupt_count_log');
   $$self{corrupt_count_log} = 0;
   $$self{aldb} = new Insteon::ALDB_PLM($self);
   if ($PLM_use_tcp == 1)
   {
   	my $tcp_hostport = "$PLM_tcp_host:$PLM_tcp_port";
      
   	$PLM_socket = new Socket_Item(undef, undef, $tcp_hostport, 'Insteon PLM 2412N', 'tcp', 'raw');
      	start $PLM_socket;
      	$$self{socket} = $PLM_socket;
   }

   &Insteon::add($self);

   $self->device_id($p_deviceid) if defined $p_deviceid;

	$$self{xmit_delay} = $::config_parms{Insteon_PLM_xmit_delay};
	$$self{xmit_delay} = 0.25 unless defined $$self{xmit_delay}; # and $$self{xmit_delay} > 0.125;
	&::print_log("[Insteon_PLM] setting default xmit delay to: $$self{xmit_delay}");
	$$self{xmit_x10_delay} = $::config_parms{Insteon_PLM_xmit_x10_delay};
	$$self{xmit_x10_delay} = 0.5 unless defined $$self{xmit_x10_delay} and $$self{xmit_x10_delay} > 0.5;
	&::print_log("[Insteon_PLM] setting x10 xmit delay to: $$self{xmit_x10_delay}");
	$self->_clear_timeout('xmit');
	$self->_clear_timeout('command');

   return $self;
}

=item C<corrupt_count_log([type]>

Sets or gets the number of corrupt message that have arrived that could not be
associated with any device since the last time C<reset_message_stats> was called.
These are generally instances in which the from device ID is corrupt.

If type is set, to any value, will increment corrupt count by one.

Returns: current corrupt count.

=cut 

sub corrupt_count_log
{
    my ($self, $corrupt_count_log) = @_;
    $$self{corrupt_count_log}++ if $corrupt_count_log;
    return $$self{corrupt_count_log};
}

=item C<reset_message_stats>

Resets the retry, fail, outgoing, incoming, and corrupt message counters.

=cut 

sub reset_message_stats
{
    my ($self) = @_;
    $$self{corrupt_count_log} = 0;
}

=item C<restore_string()>

This is called by mh on exit to save the cached ALDB of a device to persistant data.

=cut

sub restore_string
{
	my ($self) = @_;
	my $restore_string = $self->SUPER::restore_string();
	if ($self->_aldb) {
		$restore_string .= $self->_aldb->restore_string();
        }
	return $restore_string;
}

=item C<check_for_data()>

Called once per loop.  This checks for any data waiting on the serial port, if
data exists it is sent to C<_parse_data>.  If there is no data waiting, then
this checks to see if the timers for any previous commands have expired, if they
have, it calls C<retry_active_message()>.  Else, this checks to see if there
is any timeout preventing a transmission right now, if there is no timeout it
calles C<process_queue()>.

=cut

sub check_for_data {

	my ($self) = @_;
	my $PLM_use_tcp =0;
	#$PLM_use_tcp    = $::config_parms{$self . "_use_TCP"};
	$PLM_use_tcp    = $$self{use_tcp};
      	my $port_name = $$self{port_name};
	my $data = undef;
	if ($PLM_use_tcp == 1) 
	{
		if ((not active $PLM_socket) and (($main::Second % 6) == 0) and $::New_Second) 
		{
			&::print_log("[Insteon PLM] resetting socket connection");		      
			start $PLM_socket;
		}
		$data = said $PLM_socket;
      		#&::print_log("[Insteon PLM] data recieved $data") if $data;
		
	}
	else
	{      	
      		&::check_for_generic_serial_data($port_name) if $::Serial_Ports{$port_name}{object};
      		$data = $::Serial_Ports{$port_name}{data};
      	}

      	# always check for data first; if it exists, then process; otherwise check if pending commands exist
      	if ($data)
        {
        	# now, clear the serial port data so that any subsequent command processing doesn't result in an immediate filling/overwriting
	        if (length($$self{_data_fragment}))
        	{
#        		$main::Serial_Ports{$port_name}{data}=pack("H*",$$self{_data_fragment});
			# always clear the buffer since we're maintaining the fragment separately
               		$main::Serial_Ports{$port_name}{data} = '';
       		}
       		else
        	{
        		$main::Serial_Ports{$port_name}{data} = '';
        	}

         	#lets turn this into Hex. I hate perl binary funcs
        	my $data = unpack "H*", $data;

         	$self->_parse_data($data);
      	}
        elsif (defined $self)
      	{
      	# if no data being received, then check if any timeouts have expired
        	if ($self->_check_timeout('command') == 1)
                {
            		$self->_clear_timeout('command');
            		if ($self->transmit_in_progress) {
#               &::print_log("[Insteon_PLM] WARN: No acknowledgement from PLM to last command requires forced abort of current command."
#                  . " This may reflect a problem with your environment.");
#               pop(@{$$self{command_stack2}}); # pop the active command off the queue
	       			$self->retry_active_message();
               			$self->process_queue();
            		}
                	else
                	{
               			&::print_log("[Insteon_PLM] DEBUG2: PLM command timer expired but no transmission in place.  Moving on...") if $self->debuglevel(2, 'insteon');
	       			$self->clear_active_message();
               			$self->process_queue();
            		}
		}
                elsif ($self->_check_timeout('xmit') == 1)
                {
           		$self->_clear_timeout('xmit');
         		if (!($self->transmit_in_progress))
                        {
            			$self->process_queue();
               		}
            	}
	}
}

=item C<set()>

Used to send X10 messages, generates an X10 command and queues it.

=cut

sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;

        my @x10_commands = &Insteon::X10Message::generate_commands($p_state, $p_setby);
        foreach my $command (@x10_commands)
        {
	    $self->queue_message(new Insteon::X10Message($command));
        }
}

=item C<complete_linking_as_responder()>

Puts the PLM into linking mode as a responder.

=cut

sub complete_linking_as_responder
{
	my ($self, $group) = @_;

	# it is not clear that group should be anything as the group will be taken from the controller
	$group = '01' unless $group;
	# set up the PLM as the responder
	my $cmd = '00'; # responder code
	$cmd .= $group; # WARN - must be 2 digits and in hex!!
        my $message = new Insteon::InsteonMessage('all_link_start', $self);
        $message->interface_data($cmd);
	$self->queue_message($message)
}

=item C<log_alllink_table()>

Causes MisterHouse to dump its cache of the PLM link table to the log.

=cut

sub log_alllink_table
{
	my ($self) = @_;
        $self->_aldb->log_alllink_table if $self->_aldb;
}

=item C<scan_link_table()>

Causes MisterHouse to scan the link table of the PLM only.

=cut

sub scan_link_table
{
	my ($self,$callback) = @_;
	#$$self{links} = undef; # clear out the old
        $$self{aldb} = new Insteon::ALDB_PLM($self);
	$$self{_mem_activity} = 'scan';
        $$self{_mem_callback} = ($callback) ? $callback : undef;
	$self->_aldb->get_first_alllink();
}

=item C<initiate_linking_as_controller([p_group])>

Puts the PLM into linking mode as a controller, if p_group is specified the
controller will be added for this group, otherwise it will be for group 00.

=cut

sub initiate_linking_as_controller
{
	my ($self, $group, $success_callback, $failure_callback) = @_;

	$group = '00' unless $group;
	# set up the PLM as the responder
	my $cmd = '01'; # controller code
	$cmd .= $group; # WARN - must be 2 digits and in hex!!
        my $message = new Insteon::InsteonMessage('all_link_start', $self);
        $message->interface_data($cmd);
        $message->success_callback($success_callback);
        $message->failure_callback($failure_callback);
	$self->queue_message($message);
}

=item C<initiate_unlinking_as_controller([p_group])>

Puts the PLM into unlinking mode, if p_group is specified the PLM will try
to unlink any devices linked to that group that identify themselves with a set
button press.

=cut

sub initiate_unlinking_as_controller
{
	my ($self, $group) = @_;

	$group = 'FF' unless $group;
	# set up the PLM as the responder
	my $cmd = 'FF'; # controller code
	$cmd .= $group; # WARN - must be 2 digits and in hex!!
        my $message = new Insteon::InsteonMessage('all_link_start', $self);
        $message->interface_data($cmd);
	$self->queue_message($message);
}

=item C<cancel_linking()>

Cancels any pending linking session that has not completed.

=cut

sub cancel_linking
{
	my ($self) = @_;
	$self->queue_message(new Insteon::InsteonMessage('all_link_cancel', $self));
}

=item C<_aldb()>

Returns the PLM's aldb object.

=cut

sub _aldb
{
   my ($self) = @_;
   return $$self{aldb};
}

=item C<_send_cmd()>

Causes a message to be sent to the serial port.

=cut

sub _send_cmd {
	my ($self, $message, $cmd_timeout) = @_;
	my $instance = $$self{port_name};
	my $PLM_use_tcp = $$self{use_tcp};
	if ($PLM_use_tcp == 1) 
	{
		#stop $PLM_socket;
		if (not connected $PLM_socket) 
		{
		      &::print_log("[Insteon PLM] starting socket connection ");
		      start $PLM_socket;
		}	
	}
	else
	{
	     if (!(ref $main::Serial_Ports{$instance}{object})) {
		print "WARN: Insteon_PLM serial port not initialized!\n";
		return;
		}
	}
	unshift(@{$$self{command_history}},$::Time);
	$self->transmit_in_progress(1);

        my $command = $message->interface_data;
	my $delay = $$self{xmit_delay};

        # determine the delay from the point that the message was created to
        # the point that it is queued
        my $incurred_delay_time = $message->seconds_delayed;

	if ($message->isa('Insteon::X10Message')) { # is x10; so, be slow
		&main::print_log("[Insteon_PLM] DEBUG2: Sending " . $message->to_string . " incurred delay of "
		. sprintf('%.2f',$incurred_delay_time) . " seconds") if $self->debuglevel(2, 'insteon');
        	$command = $prefix{x10_send} . $command;
		$delay = $$self{xmit_x10_delay};
                # clear command timeout so that we don't wait for an insteon ack before sending the next command
	} else {
                my $command_type = $message->command_type;
		&main::print_log("[Insteon_PLM] DEBUG2: Sending " . $message->to_string . " incurred delay of "
		. sprintf('%.2f',$incurred_delay_time) . " seconds; starting hop-count: "
		. ((ref $message->setby && $message->setby->isa('Insteon::BaseObject')) ? $message->setby->default_hop_count : "?")) if $message->setby->debuglevel(2, 'insteon');
                $command = $prefix{$command_type} . $command;
                if ($command_type eq 'all_link_send' or $command_type eq 'insteon_send' or $command_type eq 'insteon_ext_send' or $command_type eq 'all_link_direct_cleanup')
                {
         		$self->_set_timeout('command', $cmd_timeout); # a commmand needs to be PLM ack'd w/i 3 seconds or it gets dropped
                }
        }
	my $is_extended = ($message->can('command_type') && $message->command_type eq "insteon_ext_send") ? 1 : 0;
	if (length($command) != (Insteon::MessageDecoder::insteon_cmd_len(substr($command,0,4), 0, $is_extended)*2)){
		&::print_log( "[Insteon_PLM]: ERROR!! Command sent to PLM " . lc($command) 
		. " is of an incorrect length.  Message not sent.");
		$self->clear_active_message();
	} 
	else
	{
		my $debug_obj = $self;
		$debug_obj = $message->setby if ($message->can('setby') && ref $message->setby);
		&::print_log( "[Insteon_PLM] DEBUG3: Sending  PLM raw data: ".lc($command)) if $debug_obj->debuglevel(3, 'insteon');
		&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($command)) if $debug_obj->debuglevel(4, 'insteon');
		my $data = pack("H*",$command);
		if ($PLM_use_tcp == 1) 
		{
			my $port_name = $PLM_socket->{port_name};
			my $sentBytes = $main::Socket_Ports{$port_name}{sock}->send($data) if $main::Socket_Ports{$port_name}{sock};
			#print "Insteon_2412N $sentBytes bytes sent ($data)[$command]\n";
		}
		else
		{
			$main::Serial_Ports{$instance}{object}->write($data) if $main::Serial_Ports{$instance};
		}	
	
		if ($delay) {
			$self->_set_timeout('xmit',$delay * 1000);
		}
	   	$$self{'last_change'} = $main::Time;
	}
}

=item C<_parse_data()>

A complex routine that parses data comming in from the serial port.  In many cases
multiple messages or fragments of messages may arrive at once.  This routine sorts
through the string of hexadecimal characters and determines what type of message 
has arrived and its full content.  Based on the type of message, it is then 
passed off to lower level message handling routines.

=cut

sub _parse_data {
	my ($self, $data) = @_;
   my ($name, $val);

	# it is possible that a fragment exists from a previous attempt; so, if it exists, prepend it
	if ($$self{_data_fragment})
        {
		&::print_log("[Insteon_PLM] DEBUG3: Prepending prior data fragment: $$self{_data_fragment}") if $self->debuglevel(3, 'insteon');
                # maintain a copy of the parsed data fragment
		$$self{_prior_data_fragment} = $$self{_data_fragment};
                # append if not a repeat
		$data = $$self{_data_fragment} . $data unless $$self{_data_fragment} eq $data;
                # and, clear it out
		$$self{_data_fragment} = '';
	}
        else
        {
        	# clear the memory of any prior data fragment
                $$self{_prior_data_fragment} = '';
        }

	&::print_log( "[Insteon_PLM] DEBUG3: Received PLM raw data: $data") if $self->debuglevel(3, 'insteon');

	# begin by pulling out any PLM ack/nacks
	my $prev_cmd = '';
	my $pending_message = $self->active_message;
	if ($pending_message) {
                $prev_cmd = lc $pending_message->interface_data;
		if ($pending_message->isa('Insteon::X10Message'))
                {
        		$prev_cmd = $prefix{x10_send} . $prev_cmd;
       		} else {
               		my $command_type = $pending_message->command_type;
                	$prev_cmd = $prefix{$command_type} . $prev_cmd;
        	}
	}

	my $residue_data = '';
	my $process_next_command = 1;
	my $nack_count = 0;
        my $entered_ack_loop;
        my $previous_parsed_data;
	if (defined $prev_cmd and $prev_cmd ne '')
	{
		my $ackcmd = $prev_cmd . '06';
		my $nackcmd = $prev_cmd . '15';
		my $badcmd = $prev_cmd . '0f';
                $previous_parsed_data = '';
		foreach my $parsed_data (split(/($ackcmd)|($nackcmd)|($prefix{plm_info}\w{12}06)|($prefix{plm_info}\w{12}15)|($badcmd)/,$data))
		{
			#ignore blanks.. the split does odd things
			next if $parsed_data eq '';
                        next if $previous_parsed_data eq $parsed_data; # guard against repeats
                        $previous_parsed_data = $parsed_data; # and, now reinitialize
                        $entered_ack_loop = 1;
			if ($parsed_data =~ /^($ackcmd)|($nackcmd)|($prefix{plm_info}\w{12}06)|($prefix{plm_info}\w{12}15)|($prefix{all_link_first_rec}15)|($prefix{all_link_next_rec}15)|($badcmd)$/)
                        {
				my $debug_obj = $self;
				$debug_obj = $self->active_message->setby if ($self->active_message->can('setby') && ref $self->active_message->setby);
				&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $debug_obj->debuglevel(4, 'insteon');
				my $ret_code = substr($parsed_data,length($parsed_data)-2,2);
				my $record_type = substr($parsed_data,0,4);
                                my $message_data = substr($parsed_data,4,length($parsed_data)-4);
				if ($ret_code eq '06')
                                {
					if ($record_type eq $prefix{plm_info})
                                        {
						$self->device_id(substr($message_data,0,6));
						$self->firmware(substr($message_data,10,2));
                                                $self->on_interface_info_received();
					}
                                        elsif ($record_type eq $prefix{all_link_first_rec}
                                        		or $record_type eq $prefix{all_link_next_rec})
                                        {
						$$self{_next_link_ok} = 1;
					}
                                        elsif ($record_type eq $prefix{all_link_start})
                                        {
                                        	if ($self->active_message->success_callback){
							package main;
							eval ($self->active_message->success_callback);
							&::print_log("[Insteon_PLM] WARN1: Error encountered during ack callback: " . $@)
								if ($@ && $self->active_message->can('setby') 
								&& ref $self->active_message->setby 
								&& $self->active_message->setby->debuglevel(1, 'insteon'));
							package Insteon_PLM;
                                        	}
                                                # clear the active message because we're done
                				$self->clear_active_message();
                                        }
                                        else
                                        {
						my $debug_obj = $self;
						$debug_obj = $self->active_message->setby if ($self->active_message->can('setby') && ref $self->active_message->setby);
                                        	&::print_log("[Insteon_PLM] DEBUG3: Received PLM acknowledge: "
                                                	. $pending_message->to_string) if $debug_obj->debuglevel(3, 'insteon');
                                        }

                                        # X10 messages don't ACK back on the powerline, so clear them if the PLM acknowledges
                                        #   AND if the current, pending message is the X10 message
					if (($parsed_data =~ /$prefix{x10_send}\w{4}06/) && ($pending_message->isa('Insteon::X10Message')))
                                        {
                				$self->clear_active_message();
					}

					if ($record_type eq $prefix{all_link_manage_rec})
                                        {
                                                # clear the active message because we're done
                				$self->clear_active_message();

						my $callback;
						if ($self->_aldb->{_success_callback}){
							$callback = $self->_aldb->{_success_callback};
							$self->_aldb->{_success_callback} = undef;
						} elsif ($$self{_mem_callback})
                                                {
							$callback = $pending_message->callback(); #$$self{_mem_callback};
							$$self{_mem_callback} = undef;
                                                } 
                                                if ($callback){
							package main;
							eval ($callback);
							&::print_log("[Insteon_PLM] WARN1: Error encountered during ack callback: " . $@)
								if ($@ && $self->active_message->can('setby') 
								&& ref $self->active_message->setby 
								&& $self->active_message->setby->debuglevel(1, 'insteon'));
							package Insteon_PLM;	
                                                }
					}
				}
                                elsif ($ret_code eq '15' or $ret_code eq '0f')
                                { #NAK or "bad" command received
                                        $self->clear_active_message(); # regardless, we're not retrying as we'll just get the same

					if ($record_type eq $prefix{all_link_first_rec}
                                        	or $record_type eq $prefix{all_link_next_rec})
                                        {
                                        	# both of these conditions are ok as it just means
                                                # we've reached the end of the memory
						$$self{_next_link_ok} = 0;
						$$self{_mem_activity} = undef;
                                                if ($record_type eq $prefix{all_link_first_rec})
                                                {
                                                	$self->_aldb->health("empty");
                                                }
                                                else
                                                {
                                                	$self->_aldb->health("good");
                                                }
                                                $self->_aldb->scandatetime(&main::get_tickcount);
						&::print_log("[Insteon_PLM] " . $self->get_object_name 
							. " completed link memory scan: status: " . $self->_aldb->health())
							if $self->debuglevel(1, 'insteon');
						if ($$self{_mem_callback})
						{
							my $callback = $$self{_mem_callback};
							$$self{_mem_callback} = undef;
							package main;
							eval ($callback);
							&::print_log("[Insteon_PLM] WARN1: Error encountered during nack callback: " . $@)
								if $@ and $self->debuglevel(1, 'insteon');
							package Insteon_PLM;
						}
                                        }
                                        elsif ($record_type eq $prefix{all_link_send})
                                        {
                                            	&::print_log("[Insteon_PLM] WARN: PLM memory does not contain link for: "
                                            		. $pending_message->to_string . $@)
                                        }
                                        elsif ($record_type eq $prefix{all_link_start})
                                        {
                                            	&::print_log("[Insteon_PLM] WARN: PLM unable to complete requested operation: "
                                            		. $pending_message->to_string . $@);
                                        }
                                        elsif ($record_type eq $prefix{all_link_manage_rec})
                                        {
                                        	# parse out the data
                                                my $failed_cmd_code = substr($pending_message->interface_data(),0,2);
                                                my $failed_cmd = 'unknown';
                                                if ($failed_cmd_code eq '40')
                                                {
                                                	$failed_cmd = 'update/add controller record';
                                                }
                                                elsif ($failed_cmd_code eq '41')
                                                {
                                                	$failed_cmd = 'update/add responder record';
                                                }
                                                elsif ($failed_cmd_code eq '80')
                                                {
                                                	$failed_cmd = 'delete record';
                                                }
                                                my $failed_group = substr($pending_message->interface_data(),4,2);
                                                my $failed_deviceid = substr($pending_message->interface_data(),6,6);
                                            	&::print_log("[Insteon_PLM] WARN: PLM unable to complete requested "
                                                	. "PLM link table update ($failed_cmd) for "
                                            		. "group: $failed_group and deviceid: $failed_deviceid" );
						my $callback;
						if ($self->_aldb->{_success_callback}){
							$callback = $self->_aldb->{_success_callback};
							$self->_aldb->{_success_callback} = undef;
						} elsif ($$self{_mem_callback})
						{
							$callback = $pending_message->callback(); #$$self{_mem_callback};
							$$self{_mem_callback} = undef;
						}
                                                if ($callback)
                                        	{
							package main;
							eval ($callback);
							&::print_log("[Insteon_PLM] WARN1: Error encountered during ack callback: " . $@)
								if $@ and $self->debuglevel(1, 'insteon');
							package Insteon_PLM;
						}
                                                # clear the active message because we're done
                				# $self->clear_active_message();
                                        }
                                        else
                                        {
						&::print_log("[Insteon_PLM] WARN: received NACK from PLM for "
							. $pending_message->to_string());
					}
				}
                                else
                                {
					# We have a problem (Usually we stepped on another X10 command)
					&::print_log("[Insteon_PLM] ERROR: encountered $parsed_data. "
                                        	. $pending_message->to_string());
                                        $self->active_message->no_hop_increase(1);
					$self->retry_active_message();
					#move it off the top of the stack and re-transmit later!
					#TODO: We should keep track of an errored command and kill it if it fails twice.  prevent an infinite loop here
				}
			}
                        else  # no match occurred--which is the "leftovers"
                        {
                        	# is $parsed_data an accidental anomoly? (there are other cases; but, this is a good start)
                                if ($parsed_data =~ /^($prefix{insteon_send}\w{12}06)|($prefix{insteon_send}\w{12}15)$/)
                                {
                                	# first, parse the content to confirm that it could be a legitimate ACK
                                        my $unknown_deviceid = substr($parsed_data,4,6);
                                        my $unknown_msg_flags = substr($parsed_data,10,2);
                                        my $unknown_command = substr($parsed_data,12,2);
                                        my $unknown_data = substr($parsed_data,14,2);
                                        my $unknown_obj = &Insteon::get_object($unknown_deviceid, '01');
                                        if ($unknown_obj)
                                        {
                                        	&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $unknown_obj->debuglevel(4, 'insteon');
                                        	&::print_log("[Insteon_PLM] WARN: encountered '$parsed_data' "
                                                	. "from " . $unknown_obj->get_object_name()
                                                        . " with command: $unknown_command, but expected '$ackcmd'.");
				       		$residue_data .= $parsed_data;
                                        }
                                        else
                                        {
                                        	&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $self->debuglevel(4, 'insteon');
                                        	&::print_log("[Insteon_PLM] ERROR: encountered '$parsed_data' "
                                                	. "that does not match any known device ID (expected '$ackcmd')."
                                                        . " Discarding received data.");
				       		#$residue_data .= $parsed_data;
                                        }
                                        $self->active_message->no_hop_increase(1);
                                }
                                else
                                {
					$residue_data .= $parsed_data;
                                }
			}
		}  #foreach - split across the incoming data

		$residue_data = $data unless $entered_ack_loop or $residue_data;
	}
        else
        {
		$residue_data = $data unless $residue_data;
	}

        my $entered_rcv_loop = 0;

        $previous_parsed_data = '';

	foreach my $parsed_data (split(/($prefix{x10_received}\w{4})|($prefix{insteon_received}\w{18})|($prefix{insteon_ext_received}\w{46})|($prefix{all_link_complete}\w{16})|($prefix{all_link_clean_failed}\w{8})|($prefix{all_link_record}\w{16})|($prefix{all_link_clean_status}\w{2})|($prefix{plm_button_event}\w{2})|($prefix{plm_user_reset})/,$residue_data))
	{
		#ignore blanks.. the split does odd things
		next if $parsed_data eq '';

		if ($previous_parsed_data eq $parsed_data){
			# guard against repeats
			::print_log("[Insteon_PLM] DEBUG3: Dropped duplicate message: $parsed_data") if $self->debuglevel(3, 'insteon'); 
			next;
		}
                $previous_parsed_data = $parsed_data; # and, now reinitialize

                $entered_rcv_loop = 1;

                my $parsed_prefix = substr($parsed_data,0,4);
                my $message_length = length($parsed_data);

        	my $message_data = substr($parsed_data,4,length($parsed_data)-4);

		if ($parsed_prefix eq $prefix{insteon_received} and ($message_length == 22))
                { #Insteon Standard Received
			my $find_obj = Insteon::get_object(substr($parsed_data,4,6), '01');
			if (ref $find_obj) {
				&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $find_obj->debuglevel(4, 'insteon');
			} 
			else {
				&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $self->debuglevel(4, 'insteon');
			}
                        $self->on_standard_insteon_received($message_data);
		}
                elsif ($parsed_prefix eq $prefix{insteon_ext_received} and ($message_length == 50))
                { #Insteon Extended Received
			my $find_obj = Insteon::get_object(substr($parsed_data,4,6), '01');
			if (ref $find_obj) {
				&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $find_obj->debuglevel(4, 'insteon');
			} 
			else {
				&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $self->debuglevel(4, 'insteon');
			}
                	$self->on_extended_insteon_received($message_data);
		}
                elsif($parsed_prefix eq $prefix{x10_received} and ($message_length == 8))
                { #X10 Received
			&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $self->debuglevel(4, 'insteon');
                       	my $x10_message = new Insteon::X10Message($parsed_data);
                        my $x10_data = $x10_message->get_formatted_data();
			&::print_log("[Insteon_PLM] DEBUG3: received x10 data: $x10_data") if $self->debuglevel(3, 'insteon');
			&::process_serial_data($x10_data,undef,$self);
		}
                elsif ($parsed_prefix eq $prefix{all_link_complete} and ($message_length == 20))
                { #ALL-Linking Completed
			&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $self->debuglevel(4, 'insteon');
			my $link_address = substr($message_data,4,6);
			&::print_log("[Insteon_PLM] DEBUG2: ALL-Linking Completed with $link_address ($message_data)") if $self->debuglevel(2, 'insteon');
			my $device_object = Insteon::get_object($link_address);
			$device_object->devcat(substr($message_data,10,4));
			$device_object->firmware(substr($message_data,14,2));
			if (ref $self->active_message && 
				$self->active_message->success_callback){
				main::print_log("[Insteon::Insteon_PLM] DEBUG4: Now calling message success callback: "
					. $self->active_message->success_callback) if $self->debuglevel(4, 'insteon');
				package main;
					eval $self->active_message->success_callback;
					::print_log("[Insteon::Insteon_PLM] problem w/ success callback: $@") if $@;
				package Insteon::BaseObject;
			}
			#Clear awaiting_ack flag
			$self->active_message->setby->_process_command_stack(0);
                        $self->clear_active_message();
		}
                elsif ($parsed_prefix eq $prefix{all_link_clean_failed} and ($message_length == 12))
                { #ALL-Link Cleanup Failure Report
			if ($self->active_message){
                        	# extract out the pertinent parts of the message for display purposes
                        	# bytes 0-1 - group; 2-7 device address
                        	my $failure_group = substr($message_data,0,2);
                        	my $failure_device = substr($message_data,2,6);
                        	my $failed_object = &Insteon::get_object($failure_device,'01');
                        	if (ref $failed_object){
					&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $failed_object->debuglevel(4, 'insteon');
					&::print_log("[Insteon_PLM] DEBUG2: Received all-link cleanup failure from " . $failed_object->get_object_name
                        		. " for all link group: $failure_group. Trying a direct cleanup.") if $failed_object->debuglevel(2, 'insteon');
	                        	my $message = new Insteon::InsteonMessage('all_link_direct_cleanup', $failed_object, 
	                        		$self->active_message->command, $failure_group);
	                        	push(@{$$failed_object{command_stack}}, $message);
	                        	$failed_object->_process_command_stack();
                        	} else {
					&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $self->debuglevel(4, 'insteon');
					&::print_log("[Insteon_PLM] Received all-link cleanup failure from an unkown device id: "
                        		. "$failure_device and for all link group: $failure_group. You may "
                        			. "want to run delete orphans to remove this link from your PLM");
                        	}
			} else {
				&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $self->debuglevel(4, 'insteon');
				&::print_log("[Insteon_PLM] DEBUG2: Received all-link cleanup failure."
                        		. " But there is no pending message.") if $self->debuglevel(2, 'insteon');
			}
                        
		}
                elsif ($parsed_prefix eq $prefix{all_link_record} and ($message_length == 20))
                { #ALL-Link Record Response
			&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $self->debuglevel(4, 'insteon');
			&::print_log("[Insteon_PLM] DEBUG2: ALL-Link Record Response:$message_data") if $self->debuglevel(2, 'insteon');
			$self->_aldb->parse_alllink($message_data);
        		# before doing the next, make sure that the pending command
                        #   (if it sitll exists) is pulled from the queue
                        $self->clear_active_message();

			$self->_aldb->get_next_alllink();
		}
		elsif ($parsed_prefix eq $prefix{plm_user_reset} and ($message_length == 4))
		{
			&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $self->debuglevel(4, 'insteon');
			main::print_log("[Insteon_PLM] Detected PLM user reset to factory defaults");
		}
                elsif ($parsed_prefix eq $prefix{all_link_clean_status} and ($message_length == 6))
                { #ALL-Link Cleanup Status Report
			&::print_log( "[Insteon_PLM] DEBUG4:\n".Insteon::MessageDecoder::plm_decode($parsed_data)) if $self->debuglevel(4, 'insteon');
			my $cleanup_ack = substr($message_data,0,2);
			if (ref $self->active_message){
				if ($cleanup_ack eq '15')
	                        {
					&::print_log("[Insteon_PLM] WARN1: All-link cleanup failure for scene: "
	                                	. $self->active_message->setby->get_object_name . ". Retrying in 1 second.")
						if $self->active_message->setby->debuglevel(1, 'insteon');
	                                $self->retry_active_message();
	                                # except that we should cause a bit of a delay to let things settle out
					$self->_set_timeout('xmit', 1000);
					$process_next_command = 0;
				}
	                        else
	                        {
	                        	my $message_to_string = ($self->active_message) ? $self->active_message->to_string() : "";
					&::print_log("[Insteon_PLM] Received all-link cleanup success: $message_to_string")
	                                	if $self->active_message->setby->debuglevel(1, 'insteon');
					if (ref $self->active_message && ref $self->active_message->setby){
						my $object = $self->active_message->setby;
						$object->is_acknowledged(1);
						$object->_process_command_stack();
					}
	                                $self->clear_active_message();
				}
			}
		}
                elsif (substr($parsed_data,0,2) eq '15')
                { # Indicates that the PLM can't receive more commands at the moment
                  # so, slow things down
			if (!($nack_count))
                        {
				if ($self->active_message){
					my $nack_delay = ($::config_parms{Insteon_PLM_disable_throttling}) ? 0.3 : 1.0;
					&::print_log("[Insteon_PLM] DEBUG3: Interface extremely busy. Resending command"
						. " after delaying for $nack_delay second") if $self->debuglevel(3, 'insteon');
					$self->_set_timeout('xmit',$nack_delay * 1000);
					$self->active_message->no_hop_increase(1);
                                	$self->retry_active_message();
					$process_next_command = 0;
				} else {
					&::print_log("[Insteon_PLM] DEBUG3: Interface extremely busy."
						. " No message to resend.") if $self->debuglevel(3, 'insteon');
				}
				$nack_count++;
			}
			#Remove the leading NACK bytes and place whatever remains into fragment for next read
			$parsed_data =~ s/^(15)*//;
			if ($parsed_data ne ''){
				$$self{_data_fragment} .= $parsed_data;
				::print_log("[Insteon_PLM] DEBUG3: Saving parsed data fragment: " 
					. $parsed_data) if( $self->debuglevel(3, 'insteon'));
			}
		}
                else
                {
			# it's probably a fragment; so, handle it
                        # it it's the same as last time, then drop it as we can't recover
			unless (($parsed_data eq $$self{_prior_data_fragment}) or ($parsed_data eq $$self{_data_fragment})) {
				$$self{_data_fragment} .= $parsed_data;
				main::print_log("[Insteon_PLM] DEBUG3: Saving parsed data fragment: " 
					. $parsed_data) if( $self->debuglevel(3, 'insteon'));
			}
		}
	}

	unless( $entered_rcv_loop or $$self{_data_fragment}) {
		$$self{_data_fragment} = $residue_data;
		main::print_log("[Insteon_PLM] DEBUG3: Saving residue data fragment: " 
			. $residue_data) if( $residue_data and $self->debuglevel(3, 'insteon'));
	}

	if ($process_next_command) {
 		$self->process_queue();
	}

	return;
}

=item C<add_id_state()>

Dummy sub required to support the X10 integrtion, does nothing.

=cut

sub add_id_state {
   # do nothing
}

=item C<firmware()>

Stores and returns the firmware version of the PLM.

=cut

sub firmware {
	my ($self, $p_firmware) = @_;
	$$self{firmware} = $p_firmware if defined $p_firmware;
	return $$self{firmware};
}

=item C<link_data3>

Returns the data3 value that should be used when creating a link for this device.  
This sub was modivated by the need to return unique values for data3 on responder 
links for group 01.  The PLM will store the responder's devcat data for controller 
entries.  That's fundamentally hard so just do the same as for other devices for 
now.  Can make this smarter in the future if needed.

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
		#Default to 01 if no group was supplied
		$link_data3 = ($group) ? $group : '01';
	}

	return $link_data3;
}
=back

=head2 INI PARAMETERS

=over 

=item Insteon_PLM_serial_port

Identifies the port on which the PLM is attached.  Example:

    Insteon_PLM_serial_port=/dev/ttyS4

=item Insteon_PLM_use_TCP

Setting this to 1, will enable MisterHouse to use a networked PLM such as the
Insteon Hub.  This functionality seems fairly stable, but has not been 
extensively tested.

You will also need to set values for C<Insteon_PLM_TCP_host> and 
C<Insteon_PLM_TCP_port>.

There are a few quirks when using a networked PLM, they include:

The communication may be slightly slower with the network PLM.  In order to
prevent MisterHouse from clobbering the device it is recommended that you
set the C<Insteon_PLM_xmit_delay> to 1 second.  Testing may reveal that slightly
lower delays are also acceptable.

Changes made using the hub's web interface will not be understood by MisterHouse.
Device states may become out of sync. (It is possible that future coding may
be able to overcome this limiation)

=item Insteon_PLM_TCP_host

If using a network PLM, set this to the IP address of the PLM.  See 
C<Insteon_PLM_use_TCP>.

=item Insteon_PLM_TCP_port

If using a network PLM, set this to the port address of the PLM.  Generally, the
port number is 9761.  See C<Insteon_PLM_use_TCP>.

=item Insteon_PLM_xmit_delay

Sets the minimum amount of seconds that must elapse between sending Insteon messages 
to the PLM.  Defaults to 0.25.

=item Insteon_PLM_xmit_x10_delay

Sets the minimum amount of seconds that must elapse between sending X10 messages 
to the PLM.  Defaults to 0.50.

=item Insteon_PLM_disable_throttling

Periodically, the PLM will report that it is too busy to accept a message from
MisterHouse.  When this happens, MisterHouse will wait 1 second before trying
to send a message to the PLM.  If this is set to 1, downgrades the delay to only
.3 seconds.  Most of the issues which caused the PLM to overload have been handled
it is unlikely that you would need to set this.

=back

=head2 NOTES

Special Thanks to:

Brian Warren for significant testing and patches

Bruce Winter - MH

=head2 AUTHOR

Jason Sharpee / jason@sharpee.com, Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 SEE ALSO

For more information regarding the technical details of the PLM:
L<Insteon PLM Dev Guide|http://www.smarthome.com/manuals/2412sdevguide.pdf>

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut


1;
