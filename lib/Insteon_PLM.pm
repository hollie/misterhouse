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
	&::print_log("PLM:serial:$port:$speed");
   &::serial_port_create($instance, $port, $speed,'none','raw');

  if (1==scalar(keys %Insteon_PLM_Data)) {  # Add hooks on first call only
      &::MainLoop_pre_add_hook(\&Insteon_PLM::check_for_data, 1);
   }
}

sub poll_all {

}


sub check_for_data {

   for my $port_name (keys %Insteon_PLM_Data) {
      &::check_for_generic_serial_data($port_name) if $::Serial_Ports{$port_name}{object};
      my $data = $::Serial_Ports{$port_name}{data};
      next if !$data;

	#lets turn this into Hex. I hate perl binary funcs
    my $data = unpack "H*", $data;

#	$::Serial_Ports{$port_name}{data} = undef;
#      main::print_log("PLM $port_name got:$data: [$::Serial_Ports{$port_name}{data}]");
      my $processedNibs;
		$processedNibs = $Insteon_PLM_Data{$port_name}{'obj'}->_parse_data($data);
		
#		&::print_log("PLM Proc:$processedNibs:" . length($data));
      $main::Serial_Ports{$port_name}{data}=pack("H*",substr($data,$processedNibs,length($data)-$processedNibs));
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
	@{$$self{command_stack}} = ();
   bless $self, $class;
   $Insteon_PLM_Data{$port_name}{'obj'} = $self;
   $self->device_id($p_deviceid) if defined $p_deviceid;

	$$self{xmit_delay} = $::config_parms{Insteon_PLM_xmit_delay};
	$$self{xmit_delay} = 0.125 unless defined $$self{xmit_delay};
	&::print_log("Insteon_PLM: setting default xmit delay to: $$self{xmit_delay}");
	$$self{xmit_x10_delay} = $::config_parms{Insteon_PLM_xmit_x10_delay};
	$$self{xmit_x10_delay} = 0.5 unless defined $$self{xmit_x10_delay};
	&::print_log("Insteon_PLM: setting x10 xmit delay to: $$self{xmit_x10_delay}");
	
#   $Insteon_PLM_Data{$port_name}{'send_count'} = 0;
#   push(@{$$self{states}}, 'on', 'off');
#   $self->_poll();

#we just turned on the device, lets wait a bit
#	$self->set_dtr(1);
#   select(undef,undef,undef,0.15);
	
   return $self;
}

sub get_firwmare_version
{
	my ($self) = @_;
	return $self->get_register(10) . $self->get_register(11);
}

sub get_im_configuration
{
	my ($self) = @_;
	return;
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
	} elsif ($p_setby->isa("Insteon_Device")) {
		$self->send_plm_cmd('0262' . $p_state);
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
	$self->send_plm_cmd($cmd);
}

sub cancel_linking
{
	my ($self) = @_;
	$self->send_plm_cmd('0265');
}

sub send_plm_cmd
{
	my ($self, $cmd) = @_;
	#queue any new commands
	if (defined $cmd and $cmd ne '')
	{
#		&::print_log("PLM Add Command:" . $cmd . ":XmitInProgress:" . $$self{xmit_in_progress} . ":" );
		unshift(@{$$self{command_stack}},$cmd);

	}
	#we dont transmit on top of another xmit
	if ($$self{xmit_in_progress} != 1) {
		$$self{xmit_in_progress} = 1;
		#TODO: Should start a timer just in case PLM is not responding and we need to clear xmit_in_progress after a while.
		#always send the oldest command first
		$cmd = pop(@{$$self{command_stack}});
		if (defined $cmd and $cmd ne '') 
		{
			#put the command back into the stack.. Its not our job to tamper with this array
			push(@{$$self{command_stack}},$cmd);
			return $self->_send_cmd($cmd);
		}
	} else {
		return;
	}
}

sub _send_cmd {
	my ($self, $cmd) = @_;
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
		select(undef,undef,undef,$delay);
	}
   	$$self{'last_change'} = $main::Time;
}


sub _parse_data {
	my ($self, $data) = @_;
   my ($name, $val);

	my $processedNibs=0;

	&::print_log( "Insteon_PLM: Parsing serial data: $data") if $main::Debug{insteon};
	
	foreach my $data_1 (split(/(0263\w{6})|(0252\w{4})|(0250\w{18})|(0251\w{46})|(0261\w{6})!(0262\w{14})|(0253\w{16})|(0256\w{8})|(0257\w{16})|(0258\w{2})/,$data))
	{
		#ignore blanks.. the split does odd things
		next if $data_1 eq '';
		#we found a matching command in stream, add to processed bytes
		$processedNibs+=length($data_1);

		#get the command on the stack that was last sent (it should be echo'd back to us for an ack/err)
		my $prev_cmd = lc(pop(@{$$self{command_stack}}));
		if (defined $prev_cmd and $prev_cmd ne '') 
		{
#			&::print_log("PLM: Defined:$prev_cmd");
			#put the command back into the stack.. Its not our job to tamper with this array
			push(@{$$self{command_stack}},$prev_cmd);
		}
#		&::print_log("PLM: Current Command:$data_1: Prev command:$prev_cmd:". length($prev_cmd) . ":");		

		#check to see if this is a ack/err from a previous command
		if ($prev_cmd ne '' and substr($data_1,0,length($prev_cmd)) eq $prev_cmd) 
		{
			#it is
			my $ret_code = substr($data_1,length($prev_cmd),2);
#			&::print_log("PLM: Return code $ret_code");
			if ($ret_code eq '06') {
				# command succeeded
#				&::print_log("PLM: Command succeeded: $data_1.");
				$$self{xmit_in_progress} = 0;
				pop(@{$$self{command_stack}});				
				select(undef,undef,undef,.15);
				$self->process_command_stack();
			} else {
				# We have a problem (Usually we stepped on another X10 command)
				&::print_log("PLM: Command error: $data_1.");
				$$self{xmit_in_progress} = 0;
				#move it off the top of the stack and re-transmit later!
				#TODO: We should keep track of an errored command and kill it if it fails twice.  prevent an infinite loop here
#				$self->send_plm_cmd(pop(@{$$self{command_stack}}));
				pop(@{$$self{command_stack}});				
				$self->process_command_stack();
			}			
		} elsif (substr($data_1,0,4) eq '0250') { #Insteon Standard Received
#			&::print_log("Insteon Received:$data_1");
			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0251') { #Insteon Extended Received
#			&::print_log("Insteon Received:$data_1");
#			&::process_serial_data($self->_xlate_x10_mh($data_1));	
			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0252') { #X10 Received
#			&::print_log("X10 Received:$data_1");
			&::process_serial_data($self->_xlate_x10_mh($data_1));	
		} elsif (substr($data_1,0,4) eq '0253') { #ALL-Linking Completed
			&::print_log("ALL-Linking Completed:$data_1") if $main::Debug{insteon};
#			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0256') { #ALL-Link Cleanup Failure Report
			&::print_log("ALL-Link Cleanup Failure Report:$data_1") if $main::Debug{insteon};
#			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0257') { #ALL-Link Record Response
			&::print_log("ALL-Link Record Response:$data_1") if $main::Debug{insteon};
#			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0258') { #ALL-Link Cleanup Status Report
			&::print_log("ALL-Link Cleanup Status Report:$data_1") if $main::Debug{insteon};
#			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0261') { #ALL-Link Broadcast 
			&::print_log("ALL-Link Broadcast:$data_1") if $main::Debug{insteon};
#			$self->delegate($data_1);
		} elsif (substr($data_1,0,2) eq '15') { #NAK Received
			&::print_log("PLM Interface extremely busy.");
			#retry
			$$self{xmit_in_progress} = 0;
			$self->process_command_stack();			
		} else {
			#for now anything not recognized, kill pending xmission
			$$self{xmit_in_progress} = 0;
			#drop latest
			pop(@{$$self{command_stack}});				
			
		}
	}
	return $processedNibs;
}

sub process_command_stack
{
	my ($self) = @_;
	## send any remaining commands in stack
	my $stack_count = @{$$self{command_stack}};
#			&::print_log("UPB Command stack2:$stack_count:@{$$self{command_stack}}:");
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
		&::print_log("PLM: Object:$p_setby Doesnt have an x10 id (yet)");
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

#Not used currently.. For direct object back delagation. Instead we are using process serial data
sub delegate
{
	my ($self,$p_data) = @_;

	my $data = substr($p_data,4,length($p_data)-4);
	my %msg = &Insteon_Device::xlate_insteon_mh($data);

	&::print_log ("Insteon_PLM: DELEGATE:$msg{source}:$msg{destination}:$data:") if $main::Debug{insteon};

	# get the matching object
	my $object = $self->get_object($msg{source}, $msg{group});
	$object->process_message($self, %msg) if defined $object;

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

#    $p_object->tie_items($self);
    push @{$$self{objects}}, $p_object;
	#request an initial state from the device
	if (! $p_object->isa('UPB_Link') ) 
	{	
#		$p_object->set("status_request");
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

=begin
sub default_getstate
{
	my ($self,$p_state) = @_;
	return $$self{m_obj}->state();
}
=cut
1;

