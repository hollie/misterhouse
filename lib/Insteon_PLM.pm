=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Insteon_PLM.pm

Description:

	This is the base interface class for Insteon Power Line Modem (PLM)

	For more information regarding the technical details of the PLM:
		http://www.smarthome.com/manuals/2412sdevguide.pdf

Author(s):
    Jason Sharpee
    jason@sharpee.com

License:
    This free software is licensed under the terms of the GNU public license. GPLv2

Usage:
	Use these mh.ini parameters to enable this code:

	Insteon_PLM_serial_port=/dev/ttyS4

    Example initialization:

		$myPLM = new Insteon_PLM("Insteon_PLM");

		#Turn Light Module ID L5 On
		$myPLM->send_plm_cmd(0x0263b900);
		$myPLM->send_plm_cmd(0x0263b280);
	
Notes:

Special Thanks to:
    Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


=cut

use strict;

package Insteon_PLM;

@Insteon_PLM::ISA = ('Serial_Item');

my %Insteon_PLM_Data;

my %plm_commands = (
#PLM Serial Commands
                        plm_info => 0x60,
						plm_reset => 0x67,
                        user_user_reset => 0x55,
						plm_get_config => 0x73,
						plm_set_config => 0x6B,
						plm_led_on => 0x6D,
						plm_led_off => 0x6E,
                        plm_button_event => 0x54,
                        insteon_send => 0x62,
                        insteon_received => 0x50,
                        insteon_ext_received => 0x51,
						insteon_nak => 0x70,
						insteon_ack => 0x71,
                        x10_send => 0x63,
                        x10_received => 0x52,
                        all_link_complete => 0x53,
                        all_link_clean_failed => 0x56,
                        all_link_record => 0x57,
                        all_link_clean_status => 0x58,
                        all_link_send => 0x61,
                        all_link_start => 0x64,
						rf_sleep => 0x72
);

my %x10_house_codes = (
						a => 0x6,
						b => 0xE,
						c => 0x2,
						d => 0xA,
						e => 0x1,
						f => 0x9,
						g => 0x5,
						h => 0xD,
						i => 0x7,
						j => 0xF,
						k => 0x3,
						l => 0xB,
						m => 0x0,
						n => 0x8,
						o => 0x4,
						p => 0xC
);

my %mh_house_codes = (
						'6' => 'a',
						'e' => 'b',
						'2' => 'c',
						'a' => 'd',
						'1' => 'e',
						'9' => 'f',
						'5' => 'g',
						'd' => 'h',
						'7' => 'i',
						'f' => 'j',
						'3' => 'k',
						'b' => 'l',
						'0' => 'm',
						'8' => 'n',
						'4' => 'o',
						'c' => 'p'
);

my %x10_unit_codes = (
						1 => 0x6,
						2 => 0xE,
						3 => 0x2,
						4 => 0xA,
						5 => 0x1,
						6 => 0x9,
						7 => 0x5,
						8 => 0xD,
						9 => 0x7,
						10 => 0xF,
						a => 0xF,
						11 => 0x3,
						b => 0x3,
						12 => 0xB,
						c => 0xB,
						13 => 0x0,
						d => 0x0,
						14 => 0x8,
						e => 0x8,
						15 => 0x4,
						f => 0x4,
						16 => 0xC,
						g => 0xC
						
);

my %mh_unit_codes = (
						'6' => '1',
						'e' => '2',
						'2' => '3',
						'a' => '4',
						'1' => '5',
						'9' => '6',
						'5' => '7',
						'd' => '8',
						'7' => '9',
						'f' => 'a',
						'3' => 'b',
						'b' => 'c',
						'0' => 'd',
						'8' => 'e',
						'4' => 'f',
						'c' => 'g'
);

my %x10_commands = (
						on => 0x2,
						j => 0x2,
						off => 0x3,
						k => 0x3,
						bright => 0x5,
						l => 0x5,
						dim => 0x4,
						m => 0x4,
						preset_dim1 => 0xA,
						preset_dim2 => 0xB,
						all_off => 0x0,
						all_lights_on => 0x1,
						all_lights_off => 0x6,
						status => 0xF,
						status_on => 0xD,
						status_off => 0xE,
						hail_ack => 0x9,
						ext_code => 0x7,
						ext_data => 0xC,
						hail_request => 0x8
);

my %mh_commands = (
						'2' => 'J',
						'3' => 'K',
						'5' => 'L',
						'4' => 'M',
						'a' => 'preset_dim1',
						'b' => 'preset_dim2',
						'0' => 'all_off',
						'1' => 'all_lights_on',
						'6' => 'all_lights_off',
						'f' => 'status',
						'd' => 'status_on',
						'e' => 'status_off',
						'9' => 'hail_ack',
						'7' => 'ext_code',
						'c' => 'ext_data',
						'8' => 'hail_request'
);

sub serial_startup {
   my ($instance) = @_;

   my $port       = $::config_parms{$instance . "_serial_port"};
#   my $speed      = $::config_parms{$instance . "_baudrate"};
	my $speed = 19200;

   $Insteon_PLM_Data{$instance}{'serial_port'} = $port;    
	&::print_log("[Insteon_PLM] serial:$port:$speed");
   &::serial_port_create($instance, $port, $speed,'none','raw');

  if (1==scalar(keys %Insteon_PLM_Data)) {  # Add hooks on first call only
      &::MainLoop_pre_add_hook(\&Insteon_PLM::check_for_data, 1);
  }
}

sub poll_all {

}


sub check_for_data {

   for my $port_name (keys %Insteon_PLM_Data) {
      my $plm = $Insteon_PLM_Data{$port_name}{'obj'};
      &::check_for_generic_serial_data($port_name) if $::Serial_Ports{$port_name}{object};
      my $data = $::Serial_Ports{$port_name}{data};
      # always check for data first; if it exists, then process; otherwise check if pending commands exist
      if ($data) {
         #lets turn this into Hex. I hate perl binary funcs
         my $data = unpack "H*", $data;

#	$::Serial_Ports{$port_name}{data} = undef;
#      main::print_log("PLM $port_name got:$data: [$::Serial_Ports{$port_name}{data}]");
         my $processedNibs;
         $processedNibs = $plm->_parse_data($data);

#		&::print_log("PLM Proc:$processedNibs:" . length($data));
         $main::Serial_Ports{$port_name}{data}=pack("H*",substr($data,$processedNibs,length($data)-$processedNibs));

      # if no data being received, then check if any timeouts have expired
      } elsif ($plm->_check_timeout('command') == 1) {
         $plm->_clear_timeout('command');
         if ($$plm{xmit_in_progress}) {
            &::print_log("[Insteon_PLM] WARN: No acknowledgement from PLM to last command requires forced abort of current command."
               . " This may reflect a problem with your environment.");
            $$plm{xmit_in_progress} = 0;
            pop(@{$$plm{command_stack2}}); # pop the active command off the queue
            $plm->send_plm_cmd();
         } else {
            &::print_log("[Insteon_PLM] PLM xmit timer expired but no transmission in place.  Moving on...") if $main::Debug{insteon};
         }
      } elsif ($plm->_check_timeout('xmit') == 1) {
         $plm->_clear_timeout('xmit');
         $plm->send_plm_cmd();
      }
   }
}

sub new {
   my ($class, $port_name, $p_deviceid) = @_;
   $port_name = 'Insteon_PLM' if !$port_name;

   my $self = {};
   $$self{state}     = '';
   $$self{said}      = '';
   $$self{state_now} = '';
   $$self{port_name} = $port_name;
	$$self{last_command} = '';
	$$self{xmit_in_progress} = 0;
	@{$$self{command_stack2}} = ();
	@{$$self{command_history}} = ();
	$$self{_prior_data_fragment} = '';
	$$self{retry_count} = 0;
   bless $self, $class;
   $Insteon_PLM_Data{$port_name}{'obj'} = $self;
   $self->device_id($p_deviceid) if defined $p_deviceid;

	$$self{xmit_delay} = $::config_parms{Insteon_PLM_xmit_delay};
	$$self{xmit_delay} = 0.25 unless defined $$self{xmit_delay} and $$self{xmit_delay} > 0.25;
	&::print_log("[Insteon_PLM] setting default xmit delay to: $$self{xmit_delay}");
	$$self{xmit_x10_delay} = $::config_parms{Insteon_PLM_xmit_x10_delay};
	$$self{xmit_x10_delay} = 0.5 unless defined $$self{xmit_x10_delay} and $$self{xmit_x10_delay} > 0.5;
	&::print_log("[Insteon_PLM] setting x10 xmit delay to: $$self{xmit_x10_delay}");
	$self->_clear_timeout('xmit');
	$self->_clear_timeout('command');

#   $Insteon_PLM_Data{$port_name}{'send_count'} = 0;
#   push(@{$$self{states}}, 'on', 'off');

   return $self;
}

sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;

	my ($package, $filename, $line) = caller;
#	&::print_log("PLM xmit:" , $p_setby->{object_name} . ":$p_state:$p_setby");
	
	#identify the type of device that sent the request
	if (
		$p_setby->isa("X10_Item") or 
		$p_setby->isa("X10_Switchlinc") or
		$p_setby->isa("X10_Appliance")
		)
	{
		$self->_xlate_mh_x10($p_state,$p_setby);
	} elsif ($p_setby->isa("Insteon_Link")) {
		# return the size of the command stack
		return $self->send_plm_cmd('0261' . $p_state);
		# return the size of the command stack
	} elsif ($p_setby->isa("Insteon_Device")) {
		return $self->send_plm_cmd('0262' . $p_state);
	} else {
		$self->_xlate_mh_x10($p_state,$p_setby);
	}
}

sub initiate_linking_as_responder
{
	my ($self, $group) = @_;

	# it is not clear that group should be anything as the group will be taken from the controller
	$group = '01' unless $group;
	# set up the PLM as the responder
	my $cmd = '0264'; # start all linking
	$cmd .= '00'; # responder code
	$cmd .= $group; # WARN - must be 2 digits and in hex!!
	$self->send_plm_cmd($cmd)
}

sub scan_link_table
{
	my ($self,$callback) = @_;
	$$self{_mem_activity} = 'scan';
        $$self{_mem_callback} = ($callback) ? $callback : undef;
	$self->get_first_alllink();
}

sub initiate_linking_as_controller
{
	my ($self, $group) = @_;

	$group = 'FF' unless $group;
	# set up the PLM as the responder
	my $cmd = '0264'; # start all linking
	$cmd .= '01'; # controller code
	$cmd .= $group; # WARN - must be 2 digits and in hex!!
	$self->send_plm_cmd($cmd);
}

sub initiate_unlinking_as_controller
{
	my ($self, $group) = @_;

	$group = 'FF' unless $group;
	# set up the PLM as the responder
	my $cmd = '0264'; # start all linking
	$cmd .= 'FF'; # controller code
	$cmd .= $group; # WARN - must be 2 digits and in hex!!
	$self->send_plm_cmd($cmd);
}

sub get_first_alllink
{
	my ($self) = @_;
	$self->send_plm_cmd('0269');
}

sub get_next_alllink
{
	my ($self) = @_;
	$self->send_plm_cmd('026A');
}

sub cancel_linking
{
	my ($self) = @_;
	$self->send_plm_cmd('0265');
}

sub send_plm_cmd
{
	my ($self, $cmd) = @_;

	return unless $cmd or !($$self{xmit_in_progress});

	# get pending command record
	my $cmdptr = pop(@{$$self{command_stack2}});
	my %cmd_record = {};
	my $pending_cmd = '';
	if ($cmdptr) {
		%cmd_record = %$cmdptr;
		$pending_cmd = $cmd_record{cmd};
		#put the command back into the stack.. Its not our job to tamper with this array
		push(@{$$self{command_stack2}},\%cmd_record) if %cmd_record;
	}

	#queue any new command ($cmd)
	if (defined $cmd and $cmd ne '')
	{
		my $duplicate_detected = 0;
		# check for duplicates of $cmd already in command_stack and ignore if they exist
		foreach my $cmdrec (@{$$self{command_stack2}}) {
			if ($cmdrec->{cmd} eq $cmd) {
				$duplicate_detected = 1;
				last;
			}
		}
		if ($duplicate_detected) {
			&main::print_log("[Insteon_PLM] Attempt to queue command already in queue; skipping ...") if $main::Debug{insteon};
		} else {
			my $queue_size = @{$$self{command_stack2}};
			&main::print_log("[Insteon_PLM] Command stack size: $queue_size") if $queue_size > 0 and $main::Debug{insteon};
	#		&::print_log("PLM Add Command:" . $cmd . ":XmitInProgress:" . $$self{xmit_in_progress} . ":" );
			my %cmd_record = {};
			$cmd_record{cmd} = $cmd;
			$cmd_record{queue_time} = $::Time;
			# pending command becomes the newest queued command if stack is empty
			$pending_cmd = $cmd unless $pending_cmd;
			unshift(@{$$self{command_stack2}},\%cmd_record);
		}
	}
	#we dont transmit on top of another xmit
	if (!($$self{xmit_in_progress})) {
		#always send the oldest command first
		if (defined $pending_cmd and $pending_cmd ne '') 
		{
		my $prior_cmd_time = pop(@{$$self{command_history}});
			while ($prior_cmd_time) {
				if ($::Time - $prior_cmd_time > 1) {
					$prior_cmd_time = pop(@{$$self{command_history}});
				} else {
					# put it back on the queue; we're done
					push(@{$$self{command_history}}, $prior_cmd_time);
					$prior_cmd_time = 0;
				}
			}
			my $past_cmds_in_history = @{$$self{command_history}};
			# need logic to change based upon whether the command is x10 or not
#			&::print_log("[Insteon_PLM] num commands in past 1 seconds: $past_cmds_in_history") if $main::Debug{insteon};
			if ($past_cmds_in_history > 3) {
				&::print_log("[Insteon_PLM] num commands in 1 second exceeded threshold. Now delaying additional transmission for 1 second") if $main::Debug{insteon};
				$self->_set_timeout('xmit',1000);
				return;
			}
			if (!($self->_check_timeout('xmit')==0)) {
				return $self->_send_cmd($pending_cmd);
			} else {
				return;
			}
		}
	} else {
#		&::print_log("[Insteon_PLM] active transmission; moving on...") if $main::Debug{insteon};
		return;
	}
	my $command_queue_size = @{$$self{command_stack2}};
	return $command_queue_size;
}

sub _send_cmd {
	my ($self, $cmd) = @_;
	unshift(@{$$self{command_history}},$::Time);
	$$self{xmit_in_progress} = 1;
	$self->_set_timeout('command',3000); # a commmand needs to be PLM ack'd w/i 3 seconds or it gets dropped
	my $instance = $$self{port_name};

#	&::print_log("PLM: Executing command:$cmd:") unless $main::config_parms{no_log} =~/Insteon_PLM/;
	my $data = pack("H*",$cmd);
	$main::Serial_Ports{$instance}{object}->write($data);
### Dont overrun the controller.. Its easy, so lets wait a bit
#	select(undef,undef,undef,0.15);
    #X10 is sloooooow
	# however, the ack/nack processing seems to allow some comms (notably insteon) to proceed
	# much faster--hence the ability to overide the slow default of 0.5 seconds
	my $delay = $$self{xmit_delay};
	if (substr($cmd,0,4) eq '0263') { # is x10; so, be slow
		$delay = $$self{xmit_x10_delay};
	}
	if ($delay) {
		$self->_set_timeout('xmit',$delay * 1000);
#		select(undef,undef,undef,$delay);
	}
   	$$self{'last_change'} = $main::Time;
}


sub _parse_data {
	my ($self, $data) = @_;
   my ($name, $val);

	my $processedNibs=0;

	# it is possible that a fragment exists from a previous attempt; so, if it exists, prepend it
	if ($$self{_data_fragment}) {
		&::print_log("[Insteon_PLM] Prepending prior data fragment: $$self{_data_fragment}");
		$$self{_prior_data_fragment} = $$self{_data_fragment};
		$data = $$self{_data_fragment} . $data;
		$$self{_data_fragment} = '';
	}
	&::print_log( "[Insteon_PLM] Parsing serial data: $data") if $main::Debug{insteon};

	# begin by pulling out any PLM ack/nacks
	my $prev_cmd = '';
	my $cmdptr = pop(@{$$self{command_stack2}});
	my %cmd_record = {};
	if ($cmdptr) {
		%cmd_record = %$cmdptr;
		$prev_cmd = lc $cmd_record{cmd};
	}
	my $residue_data = '';
	my $process_next_command = 0;
	my $nack_count = 0;
	if (defined $prev_cmd and $prev_cmd ne '') 
	{
#		&::print_log("PLM: Defined:$prev_cmd");
		my $ackcmd = $prev_cmd . '06';
		my $nackcmd = $prev_cmd . '15';
		my $entered_ack_loop = 0;
		foreach my $data_1 (split(/($ackcmd)|($nackcmd)|(0260\w{12}06)|(0260\w{12}15)/,$data))
		{
			$entered_ack_loop = 1;
			#ignore blanks.. the split does odd things
			next if $data_1 eq '';

			if ($data_1 =~ /^($ackcmd)|($nackcmd)|(0260\w{12}06)|(0260\w{12}15)$/) {
				$processedNibs+=length($data_1);
				my $ret_code = substr($data_1,length($data_1)-2,2);
#				&::print_log("PLM: Return code $ret_code");
				if ($ret_code eq '06') {
					my $record_type = substr($data_1,0,4);
					if ($record_type eq '0260') {
						$self->device_id(substr($data_1,4,6));
						$self->firmware(substr($data_1,14,2));
						&::print_log("[Insteon_PLM] PLM id: " . $self->device_id . 
							" firmware: " . $self->firmware)
							if $main::Debug{insteon};
					} elsif ($record_type eq '0269' or $record_type eq '026a') {
						$$self{_next_link_ok} = 1;
					}
					# command succeeded
#					&::print_log("PLM: Command succeeded: $data_1.");
					$$self{xmit_in_progress} = 0;
					# check to see if it is an all-link and if so, then remember for "cleanup"
					if ($data_1 =~ /0261\w{6}06/) {
						$$self{pending_alllink} = $prev_cmd;
					}
					$self->_clear_timeout('command');
					$process_next_command = 1;
					$$self{retry_count} = 0;
				} elsif ($ret_code eq '15') { #NAK Received
					my $record_type = substr($data_1,0,4);
					if ($record_type eq '0269' or $record_type eq '026a') {
						$$self{_next_link_ok} = 0;
						$$self{_mem_activity} = undef;
						eval ($$self{_mem_callback}) if defined $$self{_mem_callback};
					} else {
						&::print_log("[Insteon_PLM] Prior cmd failed");
					}
					$$self{xmit_in_progress} = 0;
					$self->_clear_timeout('command');
					$process_next_command = 1;
				} else {
					# We have a problem (Usually we stepped on another X10 command)
					&::print_log("[Insteon_PLM] Command error: $data_1.");
					$$self{xmit_in_progress} = 0;
					$self->_clear_timeout('command');
					#move it off the top of the stack and re-transmit later!
					#TODO: We should keep track of an errored command and kill it if it fails twice.  prevent an infinite loop here
					$process_next_command = 1;
				}
			} else {
				$residue_data .= $data_1;
			}			
		}
		if (!($process_next_command)) {
			# then, didn't get a match and need to push the command back on the stack
			push(@{$$self{command_stack2}}, \%cmd_record);
		}
		$residue_data = $data unless $entered_ack_loop;
	} else {
		$residue_data = $data;
	}

	my $entered_rcv_loop = 0;

	foreach my $data_1 (split(/(0263\w{6})|(0252\w{4})|(0250\w{18})|(0251\w{46})|(0261\w{6})|(0253\w{16})|(0256\w{8})|(0257\w{16})|(0258\w{2})/,$residue_data))
	{
		$entered_rcv_loop = 1;
		#ignore blanks.. the split does odd things
		next if $data_1 eq '';
		#we found a matching command in stream, add to processed bytes
		$processedNibs+=length($data_1);

		if (substr($data_1,0,4) eq '0250') { #Insteon Standard Received
			$$self{_data_fragment} .= $data_1 unless $self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0251') { #Insteon Extended Received
			$$self{_data_fragment} .= $data_1 unless $self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0252') { #X10 Received
			&::process_serial_data($self->_xlate_x10_mh($data_1));	
		} elsif (substr($data_1,0,4) eq '0253') { #ALL-Linking Completed
			&::print_log("[Insteon_PLM] ALL-Linking Completed:$data_1") if $main::Debug{insteon};
		} elsif (substr($data_1,0,4) eq '0256') { #ALL-Link Cleanup Failure Report
			&::print_log("[Insteon_PLM] ALL-Link Cleanup Failure Report:$data_1") if $main::Debug{insteon};
		} elsif (substr($data_1,0,4) eq '0257') { #ALL-Link Record Response
			&::print_log("[Insteon_PLM] ALL-Link Record Response:$data_1") if $main::Debug{insteon};
			$self->parse_alllink($data_1);
		} elsif (substr($data_1,0,4) eq '0258') { #ALL-Link Cleanup Status Report
			my $cleanup_ack = substr($data_1,4,2);
			if ($cleanup_ack eq '15') {
				&::print_log("[Insteon_PLM] All-Link Cleanup reports failure.  Attempting resend")
					if $main::Debug{insteon};
				$self->send_plm_cmd($$self{pending_alllink}) if $$self{pending_alllink};
			} else {
				&::print_log("[Insteon_PLM] ALL-Link Cleanup reports success") if $main::Debug{insteon};
				# TO-DO: set validation flag on device
			}
		} elsif (substr($data_1,0,4) eq '0261') { #ALL-Link Broadcast 
			&::print_log("[Insteon_PLM] ALL-Link Broadcast:$data_1") if $main::Debug{insteon};
#			$$self{_data_fragment} = $data_1 unless $self->delegate($data_1);
		} elsif (substr($data_1,0,2) eq '15') { #NAK Received
			if (!($nack_count)) {
				&::print_log("[Insteon_PLM] Interface extremely busy. Resending command"
					. " after delaying for 1 second") if $main::Debug{insteon};
				$self->_set_timeout('xmit',1000);
				$$self{retry_count} += 1;
				if ($$self{retry_count} < 3) {
					push(@{$$self{command_stack2}}, \%cmd_record);
				}
				$$self{xmit_in_progress} = 0;
				$self->_clear_timeout('command');
				$process_next_command = 0;
				$nack_count++;
			}
		} else {
			# it's probably a fragment; so, handle it
			$$self{_data_fragment} .= $data_1 unless $data_1 eq $$self{_prior_data_fragment};
		}
	}

	$$self{_data_fragment} = $residue_data unless $entered_rcv_loop or $$self{_data_fragment};

	if ($process_next_command) {
		$self->process_command_stack();
	} else {
#		my $queued_command_count = @{$$self{command_stack2}};
#		&::print_log("### Remaining queued commands: $queued_command_count");
	}

	return $processedNibs;
}

sub process_command_stack
{
	my ($self) = @_;
	## send any remaining commands in stack
	my $stack_count = @{$$self{command_stack2}};
#			&::print_log("UPB Command stack2:$stack_count:@{$$self{command_stack2}}:");
	if ($stack_count> 0 ) 
	{
		#send any remaining commands.
		$self->send_plm_cmd();
	}			
}

sub _xlate_mh_x10
{
        my ($self,$p_state,$p_setby) = @_;

	my $msg;
	my $cmd=$p_state;
        $cmd=~ s/\:.*$//;
        $cmd=lc($cmd);

	my $id=lc($p_setby->{id_by_state}{$cmd});

	my $hc = lc(substr($p_setby->{x10_id},1,1));
	my $uc = lc(substr($p_setby->{x10_id},2,1));

	if ($hc eq undef) {
		&::print_log("[Insteon_PLM] Object:$p_setby Doesnt have an x10 id (yet)");
		return undef;
	}

	#Every X10 message starts with the House and unit code
	$msg = "02";
	$msg.= unpack("H*",pack("C",$plm_commands{x10_send}));
	$msg.= substr(unpack("H*",pack("C",$x10_house_codes{substr($id,1,1)})),1,1);
	$msg.= substr(unpack("H*",pack("C",$x10_unit_codes{substr($id,2,1)})),1,1);
	$msg.= "00";
	$self->send_plm_cmd($msg);

	my $ecmd;
	#Iterate through the rest of the pairs of nibbles
	for (my $pos = 3; $pos<length($id); $pos++) {
		$msg= "02";
		$msg.= unpack("H*",pack("C",$plm_commands{x10_send}));
		$msg.= substr(unpack("H*",pack("C",$x10_house_codes{substr($id,$pos,1)})),1,1);
		$pos++;

		#look for an explicit command
		$ecmd = substr($id,$pos,length($id)-$pos);
#		&::print_log("PLM:PAIR:$id:$pos:$ecmd:");
		if (defined $x10_commands{$ecmd} )
		{
			$msg.= substr(unpack("H*",pack("C",$x10_commands{$ecmd})),1,1);
			$pos+=length($id)-$pos-1;
		} else {
			$msg.= substr(unpack("H*",pack("C",$x10_commands{substr($id,$pos,1)})),1,1);			
		}
		$msg.= "80";
		$self->send_plm_cmd($msg);
	}
}

sub _xlate_x10_mh
{
	my ($self,$data) = @_;

	my $msg=undef;
	if (uc(substr($data,length($data)-2,2)) eq '00')
	{
		$msg = "X";
		$msg.= uc($mh_house_codes{substr($data,4,1)});
		$msg.= uc($mh_unit_codes{substr($data,5,1)});
		for (my $index =6; $index<length($data)-2; $index+=2)
		{
   	        $msg.= uc($mh_house_codes{substr($data,$index,1)});
		    $msg.= uc($mh_commands{substr($data,$index+1,1)});
		}
#		&::print_log("PLM: X10 address:$data:$msg:");
	} elsif (uc(substr($data,length($data)-2,2)) eq '80')
	{
		$msg = "X";
		$msg.= uc($mh_house_codes{substr($data,4,1)});
		$msg.= uc($mh_commands{substr($data,5,1)});
		for (my $index =6; $index<length($data)-2; $index+=2)
		{
   	        $msg.= uc($mh_house_codes{substr($data,$index,1)});
		    $msg.= uc($mh_commands{substr($data,$index+1,1)});
		}
#		&::print_log("PLM: X10 command:$data:$msg:");
	}
	
#&::print_log("PLM:2XMH:$data:$msg:");
	return $msg;
}

sub delegate
{
	my ($self,$p_data) = @_;

	my $data = substr($p_data,4,length($p_data)-4);
	my %msg = &Insteon_Device::_xlate_insteon_mh($data);
	if (%msg) {
		&::print_log ("[Insteon_PLM] DELEGATE:$msg{source}:$msg{destination}:$data:") if $main::Debug{insteon};
	
		# get the matching object
		my $object = $self->get_object($msg{source}, $msg{group});
		&::print_log("[Insteon_PLM] Warn! Unable to locate object for source: $msg{source} and group; $msg{group}")
			if (!(defined $object));
		if (defined $object) {
			&::print_log("[Insteon_PLM] Processing message for " . $object->get_object_name);
			$object->_process_message($self, %msg);
			return 1;
		} else {
			return 0;
		}
	} else {
		return 0;
	}
}

sub parse_alllink
{
	my ($self, $data) = @_;
	my %link = {};
	my $flag = substr($data,4,1);
	$link{is_controller} = hex($flag) & 0x04;
	$link{flags} = substr($data,4,2);
	$link{group} = substr($data,6,2);
	$link{deviceid} = substr($data,8,6);
	$link{data1} = substr($data,14,2);
	$link{data2} = substr($data,16,2);
	$link{data3} = substr($data,18,2);
	my $key = $link{deviceid} . $link{group};
	%{$$self{links}{$key}} = %link;
	$self->get_next_alllink();
}

sub restore_string
{
	my ($self) = @_;
	my $restore_string = $self->SUPER::restore_string();
	if ($$self{links}) {
		my $link = '';
		foreach my $link_key (keys %{$$self{links}}) {
			$link .= '|' if $link; # separate sections
			my %link_record = %{$$self{links}{$link_key}};
			my $record = '';
			foreach my $record_key (keys %link_record) {
				next unless $link_record{$record_key};
				$record .= ',' if $record;
				$record .= $record_key . '=' . $link_record{$record_key};
			}
			$link .= $record;
		}
#		&::print_log("[Insteon_PLM] AllLink restore string: $link") if $main::Debug{insteon};
		$restore_string .= $self->{object_name} . "->restore_linktable(q~$link~);\n";
	}
	return $restore_string;
}

sub restore_linktable
{
	my ($self, $links) = @_;
	if ($links) {
		foreach my $link_section (split(/\|/,$links)) {
			my %link_record = {};
			my $deviceid = '';
			my $groupid = '01';
			foreach my $link_record (split(/,/,$link_section)) {
				my ($key,$value) = split(/=/,$link_record);
				$deviceid = $value if ($key eq 'deviceid');
				$groupid = $value if ($key eq 'group');
				$link_record{$key} = $value if $key and defined($value);
			}
			my $linkkey = $deviceid . $groupid;
			%{$$self{links}{$linkkey}} = %link_record;
		}
#		$self->log_alllink_table();
	}
}

sub log_alllink_table
{
	my ($self) = @_;
	foreach my $linkkey (keys %{$$self{links}}) {
		my $device = $self->get_object($$self{links}{$linkkey}{deviceid},'01');
		my $object_name = ($device) ? $device->get_object_name : $$self{links}{$linkkey}{deviceid};
		&::print_log("[Insteon_PLM] link " .
			(($$self{links}{$linkkey}{is_controller}) ? "controller($$self{links}{$linkkey}{group}) record to "
			. $object_name
			: "responder record to " . $object_name . "($$self{links}{$linkkey}{group})")
			. " data1=$$self{links}{$linkkey}{data1}, data2=$$self{links}{$linkkey}{data2}")
			if $main::Debug{insteon};
	}
}

sub delete_orphan_links
{
	my ($self) = @_;
	my $num_deleted = 0;
	foreach my $linkkey (keys %{$$self{links}}) {
		my $device = $self->get_object($$self{links}{$linkkey}{deviceid},'01');
		if (!($device)) {
			&::print_log("[Insteon_PLM] now deleting orphaned link w/ details: "
				. (($$self{links}{$linkkey}{is_controller}) ? "controller" : "responder")
				. ", deviceid=$$self{links}{$linkkey}{deviceid}, "
				. "group=$$self{links}{$linkkey}{group}");
			my $cmd = '026F' . '80'
				. $$self{links}{$linkkey}{flags}
				. $$self{links}{$linkkey}{group}
				. $$self{links}{$linkkey}{deviceid}
				. $$self{links}{$linkkey}{data1}
				. $$self{links}{$linkkey}{data2}
				. $$self{links}{$linkkey}{data3};
			$self->send_plm_cmd($cmd);
			$num_deleted++;
		}
	}
	if ($num_deleted) {
		&::print_log("A total of $num_deleted orphaned links were deleted.");
		$self->scan_link_table();
	} else {
		&::print_log("No orphaned links were found.");
	}
}


sub get_object
{
	my ($self, $p_deviceid, $p_group) = @_;

	my $retObj = undef;

	for my $obj (@{$$self{objects}})
	{
		#Match on Insteon objects only
		if ($obj->isa("Insteon_Device"))
		{
			if (lc $obj->device_id() eq $p_deviceid)
			{
				if ($p_group)
				{
					if ($p_group eq $obj->group)
					{
						$retObj = $obj;
						last;
					}
				} else {
					$retObj = $obj;
					last;
				}
			}
		}
	}

	return $retObj;
}


sub add_id_state
{
	my ($self,$id,$state) = @_;
#	&::print_log("PLM: AddIDSTATE:$id:$state");
}

sub add
{
	my ($self,@p_objects) = @_;

	my @l_objects;

	for my $l_object (@p_objects) {
		if ($l_object->isa('Group_Item') ) {
			@l_objects = $$l_object{members};
			for my $obj (@l_objects) {
				$self->add($obj);
			}
		} else {
		    $self->add_item($l_object);
		}
	}
}

sub add_item
{
    my ($self,$p_object) = @_;

	push @{$$self{objects}}, $p_object;

	if (!($self->device_id) and !($$self{_id_check})) {
		$$self{_id_check} = 1;
		$self->send_plm_cmd('0260');
	}
 
	if (!($p_object->isa('Insteon_Link')) and $p_object->isa('Insteon_Device')) 
	{
		# don't request status for objects associated w/ other than the primary group 
		#    as they are psuedo links	
		my $scan_at_startup = $::config_parms{Insteon_PLM_scan_at_startup};
		$scan_at_startup = 1 unless defined $scan_at_startup;
		$scan_at_startup = 0 unless $main::Save{mh_exit} eq 'normal';
		$p_object->request_status($p_object) if $p_object->group eq '01' and $scan_at_startup;
	}
	return $p_object;
}

sub remove_all_items {
   my ($self) = @_;

   if (ref $$self{objects}) {
      foreach (@{$$self{objects}}) {
 #        $_->untie_items($self);
      }
   }
   delete $self->{objects};
}

sub add_item_if_not_present {
   my ($self, $p_object) = @_;

   if (ref $$self{objects}) {
      foreach (@{$$self{objects}}) {
         if ($_ eq $p_object) {
            return 0;
         }
      }
   }
   $self->add_item($p_object);
   return 1;
}

sub remove_item {
   my ($self, $p_object) = @_;

   if (ref $$self{objects}) {
      for (my $i = 0; $i < scalar(@{$$self{objects}}); $i++) {
         if ($$self{objects}->[$i] eq $p_object) {
            splice @{$$self{objects}}, $i, 1;
 #           $p_object->untie_items($self);
            return 1;
         }
      }
   }
   return 0;
}


sub is_member {
    my ($self, $p_object) = @_;

    my @l_objects = @{$$self{objects}};
    for my $l_object (@l_objects) {
	if ($l_object eq $p_object) {
	    return 1;
	}
    }
    return 0;
}

sub find_members {
	my ($self,$p_type) = @_;

	my @l_found;
	my @l_objects = @{$$self{objects}};
	for my $l_object (@l_objects) {
		if ($l_object->isa($p_type)) {
			push @l_found, $l_object;
		}
	}
	return @l_found;
}

sub device_id {
	my ($self, $p_deviceid) = @_;
	$$self{deviceid} = $p_deviceid if defined $p_deviceid;
	return $$self{deviceid};
}

sub get_device 
{
	my ($self, $p_deviceid, $p_group) = @_;
	foreach my $device ($self->find_members('Insteon_Device')) {
		if ($device->device_id eq $p_deviceid and $device->group eq $p_group) {
			return $device;
		}
	}
}

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
	return 0 if (($current_tickcount >= 2**7) and ($$self{"_timeout_$timeout_name"} < 2**7));
	return ($current_tickcount > $$self{"_timeout_$timeout_name"}) ? 1 : 0;
}

sub _clear_timeout
{
	my ($self, $timeout_name) = @_;
	$$self{"_timeout_$timeout_name"} = undef;
}

sub firmware {
	my ($self, $p_firmware) = @_;
	$$self{firmware} = $p_firmware if defined $p_firmware;
	return $$self{firmware};
}

=begin
sub default_getstate
{
	my ($self,$p_state) = @_;
	return $$self{m_obj}->state();
}
=cut
1;

