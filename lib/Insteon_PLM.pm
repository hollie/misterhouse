=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Insteon_PLM.pm

Description:

	This is the base interface class for Insteon Power Line Modem (PLM)

	For more information regarding the technical details of the PLM:
		http://www.smarthome.com/manuals/2412sdevguide.pdf

Author(s):
    Jason Sharpee / jason@sharpee.com
    Gregg Liming / gregg@limings.net

License:
    This free software is licensed under the terms of the GNU public license. GPLv2

Usage:
	Use these mh.ini parameters to enable this code:

	Insteon_PLM_serial_port=/dev/ttyS4

    Example initialization:


Notes:

Special Thanks to:
    Brian Warren for significant testing and patches
    Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


=cut


package Insteon_PLM;

use strict;
use Insteon::BaseInterface;
use Insteon::BaseInsteon;
use Insteon::AllLinkDatabase;

@Insteon_PLM::ISA = ('Serial_Item','Insteon::BaseInterface');


my %prefix = (
#PLM Serial Commands
                        insteon_received 	=> '0250',
                        insteon_ext_received 	=> '0251',
                        x10_received 		=> '0252',
                        all_link_complete 	=> '0253',
                        plm_button_event 	=> '0254',
                        user_user_reset 	=> '0255',
                        all_link_clean_failed 	=> '0256',
                        all_link_record 	=> '0257',
                        all_link_clean_status 	=> '0258',
                        plm_info 		=> '0260',
                        all_link_send 		=> '0261',
                        insteon_send 		=> '0262',
                        insteon_ext_send	=> '0262',
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


sub serial_startup {
   my ($instance) = @_;
   my $port       = $::config_parms{$instance . "_serial_port"};
   my $speed = 19200;

   &::print_log("[Insteon_PLM] serial:$port:$speed");
   &::serial_port_create($instance, $port, $speed,'none','raw');

}

sub new {
   my ($class, $port_name, $p_deviceid) = @_;
   $port_name = 'Insteon_PLM' if !$port_name;
   my $port       = $::config_parms{$port_name . "_serial_port"};

   my $self = new Insteon::BaseInterface();
   $$self{state}     = '';
   $$self{said}      = '';
   $$self{state_now} = '';
   $$self{port_name} = $port_name;
   $$self{port} = $port;
	$$self{last_command} = '';
	$$self{xmit_in_progress} = 0;
	$$self{_prior_data_fragment} = '';
   bless $self, $class;
   $$self{aldb} = new Insteon::ALDB_PLM($self);
   $self->debug(0);

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

sub debug
{
	my ($self, $debug) = @_;
        if (defined $debug)
        {
        	$$self{debug} = $debug;
        }
        return $$self{debug};
}

sub restore_string
{
	my ($self) = @_;
	my $restore_string = $self->SUPER::restore_string();
	if ($self->_aldb) {
		$restore_string .= $self->_aldb->restore_string();
        }
	return $restore_string;
}

sub check_for_data {

	my ($self) = @_;
      	my $port_name = $$self{port_name};
      	&::check_for_generic_serial_data($port_name) if $::Serial_Ports{$port_name}{object};
      	my $data = $::Serial_Ports{$port_name}{data};
      	# always check for data first; if it exists, then process; otherwise check if pending commands exist
      	if ($data)
        {
         	#lets turn this into Hex. I hate perl binary funcs
        	my $data = unpack "H*", $data;

        	my $processedNibs;
         	$processedNibs = $self->_parse_data($data);
         	$processedNibs = 0 unless $processedNibs;
#		&::print_log("PLM Proc:$processedNibs:" . length($data));
         	if (length($data) > $processedNibs)
                {
            		$main::Serial_Ports{$port_name}{data}=pack("H*",substr($data,$processedNibs,length($data)-$processedNibs));
         	}
                else
                {
            		$main::Serial_Ports{$port_name}{data} = '';
         	}

      	# if no data being received, then check if any timeouts have expired
      	}
        elsif (defined $self)
      	{
        	if ($self->_check_timeout('command') == 1)
                {
            		$self->_clear_timeout('command');
            		if ($$self{xmit_in_progress}) {
#               &::print_log("[Insteon_PLM] WARN: No acknowledgement from PLM to last command requires forced abort of current command."
#                  . " This may reflect a problem with your environment.");
               			$$self{xmit_in_progress} = 0;
#               pop(@{$$self{command_stack2}}); # pop the active command off the queue
	       			$self->retry_active_message();
               			$self->process_queue();
            		}
                	else
                	{
               			&::print_log("[Insteon_PLM] PLM command timer expired but no transmission in place.  Moving on...") if $main::Debug{insteon};
	       			$self->clear_active_message();
               			$self->process_queue();
            		}
		}
                elsif ($self->_check_timeout('xmit') == 1)
                {
           		$self->_clear_timeout('xmit');
         		if (!($$self{xmit_in_progress}))
                        {
            			$self->process_queue();
               		}
            	}
	}
}


sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;

        my @x10_commands = &Insteon::X10Message::generate_commands($p_state, $p_setby);
        foreach my $command (@x10_commands)
        {
	    $self->queue_message(new Insteon::X10Message($command));
        }
}

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

sub log_alllink_table
{
	my ($self) = @_;
        $self->_aldb->log_alllink_table if $self->_aldb;
}

sub scan_link_table
{
	my ($self,$callback) = @_;
	#$$self{links} = undef; # clear out the old
        $$self{adlb} = undef;
        $$self{aldb} = new Insteon::ALDB_PLM($self);
	$$self{_mem_activity} = 'scan';
        $$self{_mem_callback} = ($callback) ? $callback : undef;
	$self->_aldb->get_first_alllink();
}

sub initiate_linking_as_controller
{
	my ($self, $group) = @_;

	$group = 'FF' unless $group;
	# set up the PLM as the responder
	my $cmd = '01'; # controller code
	$cmd .= $group; # WARN - must be 2 digits and in hex!!
        my $message = new Insteon::InsteonMessage('all_link_start', $self);
        $message->interface_data($cmd);
	$self->queue_message($message);
}

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


sub cancel_linking
{
	my ($self) = @_;
	$self->queue_message(new Insteon::InsteonMessage('all_link_cancel', $self));
}

sub _aldb
{
   my ($self) = @_;
   return $$self{aldb};
}



sub _send_cmd {
	my ($self, $message, $cmd_timeout) = @_;
	my $instance = $$self{port_name};
	if (!(ref $main::Serial_Ports{$instance}{object})) {
		print "WARN: Insteon_PLM serial port not initialized!\n";
		return;
	}
	unshift(@{$$self{command_history}},$::Time);
	$$self{xmit_in_progress} = 1;

        my $command = $message->interface_data;
	my $delay = $$self{xmit_delay};
	if ($message->isa('Insteon::X10Message')) { # is x10; so, be slow
        	$command = $prefix{x10_send} . $command;
		$delay = $$self{xmit_x10_delay};
                # clear command timeout so that we don't wait for an insteon ack before sending the next command
	} else {
                my $command_type = $message->command_type;
                $command = $prefix{$command_type} . $command;
         	$self->_set_timeout('command', $cmd_timeout); # a commmand needs to be PLM ack'd w/i 3 seconds or it gets dropped
        }

        my $data = pack("H*",$command);
#	&::print_log("PLM: Executing command:$command:") unless $main::config_parms{no_log} =~/Insteon_PLM/;
	$main::Serial_Ports{$instance}{object}->write($data) if $main::Serial_Ports{$instance};


	if ($delay) {
		$self->_set_timeout('xmit',$delay * 1000);
	}
   	$$self{'last_change'} = $main::Time;
}


sub _parse_data {
	my ($self, $data) = @_;
   my ($name, $val);

	my $processedNibs=0;

	# it is possible that a fragment exists from a previous attempt; so, if it exists, prepend it
	if ($$self{_data_fragment}) {
		&::print_log("[Insteon_PLM] Prepending prior data fragment: $$self{_data_fragment}") if $self->debug or $main::Debug{insteon};
		$$self{_prior_data_fragment} = $$self{_data_fragment};
		$data = $$self{_data_fragment} . $data;
		$$self{_data_fragment} = '';
	}
	&::print_log( "[Insteon_PLM] Parsing serial data: $data") if $self->debug;

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
	if (defined $prev_cmd and $prev_cmd ne '')
	{
		my $ackcmd = $prev_cmd . '06';
		my $nackcmd = $prev_cmd . '15';
		my $badcmd = $prev_cmd . '0f';
		foreach my $data_1 (split(/($ackcmd)|($nackcmd)|($prefix{plm_info}\w{12}06)|($prefix{plm_info}\w{12}15)|($badcmd)/,$data))
		{
			#ignore blanks.. the split does odd things
			next if $data_1 eq '';
                        $entered_ack_loop = 1;
			if ($data_1 =~ /^($ackcmd)|($nackcmd)|($prefix{plm_info}\w{12}06)|($prefix{plm_info}\w{12}15)|($badcmd)$/)
                        {
				$processedNibs+=length($data_1);
				my $ret_code = substr($data_1,length($data_1)-2,2);
				my $record_type = substr($data_1,0,4);
                                my $message_data = substr($data_1,4,length($data_1)-4);
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
                                        else
                                        {
                                        	&::print_log("[Insteon_PLM] DEBUG: received interface acknowledge: "
                                                	. $pending_message->to_string) if $self->debug;
                                        }

					if ($data_1 =~ /$prefix{x10_send}\w{4}06/)
                                        {
                				$self->clear_active_message();
					}

					if (($record_type eq $prefix{all_link_manage_rec}) and $$self{_mem_callback})
                                        {
						my $callback = $$self{_mem_callback};
						$$self{_mem_callback} = undef;
						package main;
						eval ($callback);
						&::print_log("[Insteon_PLM] error encountered during ack callback: " . $@)
							if $@ and $main::Debug{insteon};
						package Insteon_PLM;
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
						if ($$self{_mem_callback})
                                        	{
							my $callback = $$self{_mem_callback};
							$$self{_mem_callback} = undef;
							package main;
							eval ($callback);
							&::print_log("[Insteon_PLM] error encountered during nack callback: " . $@)
							if $@ and $main::Debug{insteon};
							package Insteon_PLM;
						}
					} else {
						&::print_log("[Insteon_PLM] WARN: received NACK for "
                                                	. $pending_message->to_string()
                                                        . ". If this is a light fixture, check bulb");
					}
				}
                                else
                                {
					# We have a problem (Usually we stepped on another X10 command)
					&::print_log("[Insteon_PLM] ERROR: encountered $data_1. "
                                        	. $pending_message->to_string());
#					$$self{xmit_in_progress} = 0;
					$self->retry_active_message();
					#move it off the top of the stack and re-transmit later!
					#TODO: We should keep track of an errored command and kill it if it fails twice.  prevent an infinite loop here
				}
			}
                        else
                        {
				$residue_data .= $data_1;
			}
		}

		$residue_data = $data unless $entered_ack_loop or $residue_data;
	}
        else
        {
		$residue_data = $data unless $residue_data;
	}

        my $entered_rcv_loop = 0;

	foreach my $data_1 (split(/($prefix{x10_received}\w{4})|($prefix{insteon_received}\w{18})|($prefix{insteon_ext_received}\w{46})|($prefix{all_link_complete}\w{16})|($prefix{all_link_clean_failed}\w{8})|($prefix{all_link_record}\w{16})|($prefix{all_link_clean_status}\w{2})/,$residue_data))
	{
		#ignore blanks.. the split does odd things
		next if $data_1 eq '';

                $entered_rcv_loop = 1;

		#we found a matching command in stream, add to processed bytes
		$processedNibs+=length($data_1);

                my $parsed_prefix = substr($data_1,0,4);
                my $message_length = length($data_1);

        	my $message_data = substr($data_1,4,length($data_1)-4);

		if ($parsed_prefix eq $prefix{insteon_received} and ($message_length == 22))
                { #Insteon Standard Received
                        $self->on_standard_insteon_received($message_data);
		}
                elsif ($parsed_prefix eq $prefix{insteon_ext_received} and ($message_length == 50))
                { #Insteon Extended Received
                	$self->on_extended_insteon_received($message_data);
		}
                elsif($parsed_prefix eq $prefix{x10_received} and ($message_length == 8))
                { #X10 Received
                       	my $x10_message = new Insteon::X10Message($message_data);
                        my $x10_data = $x10_message->get_formatted_data();
			&::print_log("[Insteon_PLM] received x10 data: $x10_data") if $main::Debug{insteon}
			&::process_serial_data($x10_data,undef,$self);
		}
                elsif ($parsed_prefix eq $prefix{all_link_complete} and ($message_length == 20))
                { #ALL-Linking Completed
			my $link_address = substr($message_data,4,6);
			&::print_log("[Insteon_PLM] ALL-Linking Completed with $link_address ($message_data)") if $main::Debug{insteon};
                        $self->clear_active_message();
		}
                elsif ($parsed_prefix eq $prefix{all_link_clean_failed} and ($message_length == 14))
                { #ALL-Link Cleanup Failure Report
                        $self->retry_active_message();
                        # extract out the pertinent parts of the message for display purposes
                        # bytes 0-1 - ignore; 2-3 - group; 4-9 device address
                        my $failure_group = substr($message_data,2,2);
                        my $failure_device = substr($message_data,4,6);

			&::print_log("[Insteon_PLM] Recieved all-link cleanup failure from device: "
                        	. "$failure_device and group: failure_group") if $main::Debug{insteon};
		}
                elsif ($parsed_prefix eq $prefix{all_link_record} and ($message_length == 20))
                { #ALL-Link Record Response
			&::print_log("[Insteon_PLM] ALL-Link Record Response:$message_data") if $main::Debug{insteon};
			$self->_aldb->parse_alllink($message_data);
        		# before doing the next, make sure that the pending command
                        #   (if it sitll exists) is pulled from the queue
                        $self->clear_active_message();

			$self->_aldb->get_next_alllink();
		}
                elsif ($parsed_prefix eq $prefix{all_link_clean_status} and ($message_length == 6))
                { #ALL-Link Cleanup Status Report
			my $cleanup_ack = substr($message_data,0,2);
			if ($cleanup_ack eq '15')
                        {
                        	my $delay_in_seconds = 1.0;  # this may need to be tweaked
				&::print_log("[Insteon_PLM] Received all-link cleanup failure for current message."
                                	. "  Attempting resend in " . $delay_in_seconds . " seconds.")
					if $main::Debug{insteon};
                                $self->retry_active_message();
                                # except that we should cause a bit of a delay to let things settle out
				$self->_set_timeout('xmit',$delay_in_seconds * 1000);
				$process_next_command = 0;
			}
                        else
                        {
                        	my $message_to_string = ($self->active_message) ? $self->active_message->to_string() : "";
				&::print_log("[Insteon_PLM] Received all-link cleanup success: $message_to_string")
                                	if $main::Debug{insteon};

				# attempt to process the message by the link object; this acknowledgement will reset
				#   the auto-retry timer
				if ($self->active_message && ($self->active_message->command_type == 'all_link_send'))
                                {
					my $group = substr($self->active_message->interface_data,0,2);
					my $link = &Insteon::get_object('000000',$group);
					if ($link)
                                        {
						my %msg = ('type' => 'cleanup',
								'group' => $group,
								'is_ack' => 1,
								'command' => 'cleanup'
							);
						$link->_process_message($self, %msg);
					}
				}
                                $self->clear_active_message();
			}
		}
                elsif (substr($data_1,0,2) eq '15')
                { #NAK Received
			if (!($nack_count))
                        {
				my $nack_delay = ($::config_parms{Insteon_PLM_disable_throttling}) ? 0.3 : 1.0;
				&::print_log("[Insteon_PLM] Interface extremely busy. Resending command"
					. " after delaying for $nack_delay second") if $main::Debug{insteon};
				$self->_set_timeout('xmit',$nack_delay * 1000);
                                $self->retry_active_message();
#				$$self{xmit_in_progress} = 0;
				$process_next_command = 0;
				$nack_count++;
			}
		}
                else
                {
			# it's probably a fragment; so, handle it
                        # it it's the same as last time, then drop it as we can't recover
			$$self{_data_fragment} .= $data_1 unless $data_1 eq $$self{_prior_data_fragment};
		}
	}

	$$self{_data_fragment} = $residue_data unless $entered_rcv_loop or $$self{_data_fragment};

	if ($process_next_command) {
 		$self->process_queue();
	}

	return $processedNibs;
}

# dummy sub required to support the X10 integrtion

sub add_id_state {
   # do nothing
}

sub firmware {
	my ($self, $p_firmware) = @_;
	$$self{firmware} = $p_firmware if defined $p_firmware;
	return $$self{firmware};
}


1;
