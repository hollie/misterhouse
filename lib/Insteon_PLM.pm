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


# Takes a hexadecimal string and calculates the checksum in a hexadecimal string
sub get_checksumHex
{
	my ($msg) = @_;
	my $bmsg;
	$bmsg = pack("H*",$msg);
    my @bytes = unpack 'C*', $bmsg;
    my $checksum = 0;
    foreach (@bytes[0..$#bytes]) {
        $checksum += $_;
    }
    $checksum = ~$checksum;
    $checksum++;
    $checksum &= 0xff;
	$checksum = sprintf("%02X",$checksum);

	return $checksum;
}


sub check_for_data {
#	&::print_log("PLM CFD:");
#	for my $temp (keys %Insteon_PLM_Data) {
#	&::print_log("PLM ARR:$temp:" . $Insteon_PLM_Data{$temp});
#	}
   for my $port_name (keys %Insteon_PLM_Data) {
      &::check_for_generic_serial_data($port_name) if $::Serial_Ports{$port_name}{object};
#      my $data = $::Serial_Ports{$port_name}{data_record};
      my $data = $::Serial_Ports{$port_name}{data};
      next if !$data;

	#lets turn this into Hex. I hate perl binary funcs
    my $data = unpack "H*", $data;

#	$::Serial_Ports{$port_name}{data} = undef;
      main::print_log("PLM $port_name got:$data: [$::Serial_Ports{$port_name}{data}]");
      my $processedNibs;
		$processedNibs = $Insteon_PLM_Data{$port_name}{'obj'}->_parse_data($data);
		
		&::print_log("PLM Proc:$processedNibs:" . length($data));
      $main::Serial_Ports{$port_name}{data}=pack("H*",substr($data,$processedNibs,length($data)-$processedNibs));
   }
}

sub new {
   my ($class, $port_name) = @_;
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
	&::print_log("PLM xmit:" , $p_setby->{object_name} . ":$p_setby:$p_state:$package:$filename:$line");
	
	#identify the type of device that sent the request
	if ($p_setby->isa("X10_Item") or $p_setby->isa("X10_Switchlinc"))
	{
		&::print_log("PLM: XSW");
		$self->_xlate_mh_x10($p_state,$p_setby);
	} elsif ($p_setby->isa("Insteon_Device")) {
		&::print_log("PLM: IPLD:$p_state");
		$self->send_plm_cmd(pack("H*",'0262' . $p_state));
	}
}

sub send_plm_cmd
{
	my ($self, $cmd) = @_;
	#queue any new commands
	unshift(@{$$self{command_stack}},$cmd) if defined $cmd;

	&::print_log("PLM Add Command:" . unpack("H*",$cmd) . ":XmitInProgress:" . $$self{xmit_in_progress} . ":" );
	#we dont transmit on top of another xmit
	if ($$self{xmit_in_progress} != 1) {
		$$self{xmit_in_progress} = 1;
		#TODO: Should start a timer just in case PLM is not responding and we need to clear xmit_in_progress after a while.
		#always send the oldest command first
		$cmd = pop(@{$$self{command_stack}});
		if (defined $cmd) 
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
	    my $hex = unpack "H*", $cmd;

	&::print_log("PLM: Executing command:$hex:") unless $main::config_parms{no_log} =~/Insteon_PLM/;
	my $data = $cmd;
	$main::Serial_Ports{$instance}{object}->write($data);
### Dont overrun the controller.. Its easy, so lets wait a bit
#	select(undef,undef,undef,0.15);
    #X10 is sloooooow
	select(undef,undef,undef,0.5);
   	$$self{'last_change'} = $main::Time;
#	$self->_poll();
}


sub _parse_data {
	my ($self, $data) = @_;
##   return if (($$self{'last_change'} + 5) > $main::Time);
   my ($name, $val);
#   $data =~ s/^\s*//;
#   $data =~ s/\s*$//;
	my $processedNibs=0;

	&::print_log( "PLM: Parsing serial data: $data\n") unless $main::config_parms{no_log} =~/Insteon_PLM/;
	
	foreach my $data_1 (split(/(0263\w{6})|(0252\w{4})|(0250\w{18})|(0251\w{46})|(0262\w{14})/,$data))
	{
		#we found a matching command in stream, add to processed bytes
		$processedNibs+=length($data_1);

		#get the command on the stack that was last sent (it should be echo'd back to us for an ack/err)
		my $prev_cmd = pop(@{$$self{command_stack}});
		if (defined $prev_cmd) 
		{
			#put the command back into the stack.. Its not our job to tamper with this array
			push(@{$$self{command_stack}},$prev_cmd);
		}
		$prev_cmd = unpack("H*",$prev_cmd);
		&::print_log("PLM: Prev command:$prev_cmd:");		

		#check to see if this is a ack/err from a previous command
		if ($prev_cmd ne '' and substr($data_1,0,length($prev_cmd)) eq $prev_cmd) 
		{
			#it is
			my $ret_code = substr($data_1,length($prev_cmd),2);
			&::print_log("PLM: Return code $ret_code");
			if ($ret_code eq '06') {
				# command succeeded
				&::print_log("PLM: Command succeeded: $data_1.");
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
			&::print_log("Insteon Received:$data_1");
			$self->delegate($data_1);
		} elsif (substr($data_1,0,4) eq '0251') { #Insteon Extended Received
			&::print_log("Insteon Received:$data_1");
#			&::process_serial_data($self->_xlate_x10_mh($data_1));	
		} elsif (substr($data_1,0,4) eq '0252') { #X10 Received
			&::print_log("X10 Received:$data_1");
			&::process_serial_data($self->_xlate_x10_mh($data_1));	
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
    &::print_log("PLM: XLATE IDbyState:$cmd:$id:");

#	if ($x10_commands{$cmd} eq undef) 
#	{
#		&::print_log("PLM: Object:$p_setby, Command $cmd not found.");
#		return undef;
#	}

	my $hc = lc(substr($p_setby->{x10_id},1,1));
	my $uc = lc(substr($p_setby->{x10_id},2,1));

	if ($hc eq undef) {
		&::print_log("PLM: Object:$p_setby Doesnt have an x10 id (yet)");
		return undef;
	}
#   &::print_log("XLATE:$cmd:$p_state:psb:$p_setby:id:" . $p_setby->{x10_id} . ":" . $p_setby->{id} . ":");
#	$cmd=substr(unpack("H*",$x10_commands{$cmd}),2,1);

	#Every X10 message starts with the House and unit code
	$msg = "02";
	$msg.= unpack("H*",pack("C",$plm_commands{x10_send}));
	$msg.= substr(unpack("H*",pack("C",$x10_house_codes{substr($id,1,1)})),1,1);
	$msg.= substr(unpack("H*",pack("C",$x10_unit_codes{substr($id,2,1)})),1,1);
	$msg.= "00";
	$msg=pack("H*",$msg);
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
		&::print_log("PLM:PAIR:$id:$pos:$ecmd:");
		if (defined $x10_commands{$ecmd} )
		{
			$msg.= substr(unpack("H*",pack("C",$x10_commands{$ecmd})),1,1);
			$pos+=length($id)-$pos-1;
		} else {
			$msg.= substr(unpack("H*",pack("C",$x10_commands{substr($id,$pos,1)})),1,1);			
		}
		$msg.= "80";
		$msg=pack("H*",$msg);
		$self->send_plm_cmd($msg);
	}
}

sub _xlate_x10_mh
{
	my ($self,$data) = @_;

	my $msg;
	$msg = "X";
	$msg.= uc($mh_house_codes{substr($data,4,1)});
	$msg.= uc($mh_unit_codes{substr($data,5,1)});
&::print_log("PLM: XMH:$data:$msg:");
	
	for (my $index =6; $index<length($data)-2; $index++)
	{
	    $msg.= uc($mh_house_codes{substr($data,$index,1)});
	}

&::print_log("PLM:2XMH:$data:$msg:");
	return $msg;
}

#Not used currently.. For direct object back delagation. Instead we are using process serial data
sub delegate
{
	my ($self,$p_data) = @_;
	my $source=substr($p_data,4,6);
	my $destination=substr($p_data,10,6);

	&::print_log ("DELEGATE:$source:$destination:$p_data:");
	for my $obj (@{$$self{objects}})
	{
		#Match on Insteon objects only
		if ($obj->isa("Insteon_Device"))
		{
			if ($source eq 'FFFFFF' or $obj->device_id() eq $source)
			{
				$obj->set(substr($p_data,4,length($p_data)-4),$self);
			}
		}
	}
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

=begin
sub default_getstate
{
	my ($self,$p_state) = @_;
	return $$self{m_obj}->state();
}
=cut
1;

