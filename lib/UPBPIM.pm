=begin comment

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	UPBPIM.pm

Description:
	This is the base interface class for Universal Powerline Bus (UPB), Powerline
	Interface Module (PIM).  

	For more information about the UPB protocol:
		http://www.pcslighting.com/downloads.html

	For more information regarding the technical details of the PIM:
		http://www.pcslighting.com/downloads/pulseworx_specifications/PimComm1.5.pdf

Author(s):
    Jason Sharpee
    jason@sharpee.com

	Based loosely on the RCSsTR40.pm code:
	-	Initial version created by Chris Witte <cwitte@xmlhq.com>
	-	Expanded for TR40 by Kirk Bauer <kirk@kaybee.org>

License:
    This free software is licensed under the terms of the GNU public license.

Usage:
	Use these mh.ini parameters to enable this code:

	UPBPIM_serial_port=/dev/ttyS4
	UPBPIM_baudrate=4800
	UPBPIM_network=49
	UPBPIM_moduleid=30
	UPBPIM_password=34554


    Example initialization:

		$myPIM = new UPBPIM("UPBPIM",<networkid>,<networkpassword>,<pimmoduleid>);

		#Turn Light Module ID #0x66 On
		$myPIM->send_upb_cmd("09004466FF236400");
		#Turn Light Module ID #0x66 Off
		$myPIM->send_upb_cmd("09004466FF230000");
		#Turn Light Module ID #0x66 to 50% dim
		$myPIM->send_upb_cmd("09004466FF233200");
	
Notes:
    - However this code does establish communication sucessfully with the PIM,
      and adding functionality at this point will be somewhat trivial. 
      ( The exhausting hardware / serial part for me is seemingly over ;) )

Special Thanks to:
    Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


=cut

use strict;

package UPBPIM;

@UPBPIM::ISA = ('Serial_Item');

my %UPBPIM_Data;

sub serial_startup {
   my ($instance) = @_;

   my $port       = $::config_parms{$instance . "_serial_port"};
   my $speed      = $::config_parms{$instance . "_baudrate"};
   $UPBPIM_Data{$instance}{'serial_port'} = $port;    

   &::serial_port_create($instance, $port, $speed);
  if (1==scalar(keys %UPBPIM_Data)) {  # Add hooks on first call only
#      &::MainLoop_post_add_hook(\&UPBPIM::poll_all, 1);
      &::MainLoop_pre_add_hook(\&UPBPIM::check_for_data, 1);
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
   for my $port_name (keys %UPBPIM_Data) {
      &::check_for_generic_serial_data($port_name) if $::Serial_Ports{$port_name}{object};
      my $data = $::Serial_Ports{$port_name}{data_record};
      next if !$data;
#      main::print_log("$port_name got: [$::Serial_Ports{$port_name}{data_record}]");
      $UPBPIM_Data{$port_name}{'obj'}->_parse_data($data);

      $main::Serial_Ports{$port_name}{data_record}='';
=begin
      if (($UPBPIM_Data{$port_name}{'obj'}->{'last_change'} + 5) == $main::Time) {
         $UPBPIM_Data{$port_name}{'obj'}->{'last_change'} = 0;
         $UPBPIM_Data{$port_name}{'obj'}->_poll();
      }
=cut
   }
}

sub new {
   my ($class, $port_name,$network_id,$network_password,$module_id) = @_;
   $port_name = 'UPBPIM' if !$port_name;

   my $self = {};
   $$self{state}     = '';
   $$self{said}      = '';
   $$self{state_now} = '';
   $$self{port_name} = $port_name;
   bless $self, $class;
   $UPBPIM_Data{$port_name}{'obj'} = $self;

#   $UPBPIM_Data{$port_name}{'send_count'} = 0;
#   push(@{$$self{states}}, 'on', 'off');
#   $self->_poll();

#we just turned on the device, lets wait a bit
	$self->set_dtr(1);
   select(undef,undef,undef,0.15);
	
	$self->set_message_mode();
	$self->set_network_id($network_id) if defined $network_id;
	$self->set_network_password($network_password) if defined $network_password;
	$self->set_module_id($module_id) if defined $module_id;
	$self->update_registers();
   return $self;
}

sub set_message_mode
{
	my ($self) = @_;
	return $self->_send_cmd("\x1770028E\x0D");
	
}
sub update_registers
{
	my ($self, $start, $end) = @_;
	my $cmd;
	$start = 0 if not defined $start;
	$end = 255 if not defined $end;
	$cmd= sprintf("%02X%02X",$start,$end);
	$cmd.= get_checksumHex($cmd);
	return $self->_send_cmd("\x12" . $cmd . "\x0D");
}

sub get_register
{
	my ($self, $start,$end) = @_;
	$start=0 if !defined $start;
	$end=1 if !defined $end;

	my $response;
	for (my $index=$start;$index<$start+$end;$index++)
	{
		$response.=sprintf("%02X",@{$$self{'registers'}}->[$index]);		
	}
	return $response;
}

sub get_firware_version
{
	my ($self) = @_;
	return $self->get_register(10) . $self->get_register(11);
}

sub send_upb_cmd
{
	my ($self, $cmd) = @_;
	$cmd.= get_checksumHex($cmd);
	return $self->_send_cmd("\x14" . $cmd . "\x0D");
}


sub set_register
{
	my ($self, $start, $val) = @_;
	my $cmd;
	return if !defined $start;

	$cmd= sprintf("%02X%02X",$start,$val);
	$cmd.= get_checksumHex($cmd);
	return $self->_send_cmd("\x17" . $cmd . "\x0D");
}

sub set_network_id
{
	my ($self, $val) = @_;
	return if !defined $val;
	$self->set_register(0,$val);	
}

sub get_network_id
{
	my ($self) = @_;

	return $self->get_register(0);	
}

sub set_module_id
{
	my ($self, $val) = @_;
	return if !defined $val;
	$self->set_register(1,$val);	
}

sub get_module_id
{
	my ($self) = @_;

	return $self->get_register(1);	
}

sub set_network_password
{
	my ($self, $val) = @_;
	return if !defined $val;
	$self->set_register(2,$val);	
}

sub get_network_password
{
	my ($self) = @_;

	return $self->get_register(2) . $self->get_register(3);	
}


sub _send_cmd {
	my ($self, $cmd) = @_;
	my $instance = $$self{port_name};
	print "$::Time_Date: UPBPIM: Executing command $cmd\n" unless $main::config_parms{no_log} =~/UPBPIM/;
	my $data = $cmd;
print "PN:$instance:";
	$main::Serial_Ports{$instance}{object}->write($data);
### Dont overrun the controller.. Its easy, so lets wait a bit
   select(undef,undef,undef,0.15);
   $$self{'last_change'} = $main::Time;
#	$self->_poll();
}

sub _poll{
	my ($self) = @_;
	my $instance = $self->{port_name};
}

sub _parse_data {
	my ($self, $data) = @_;
##   return if (($$self{'last_change'} + 5) > $main::Time);
   my ($name, $val);
   $data =~ s/^\s*//;
   $data =~ s/\s*$//;
   print "UPBPIM: Parsing serial data: $data\n" unless $main::config_parms{no_log} =~/UPBPIM/;

	#PIM to Host Message
	if (uc(substr($data,0,1)) eq 'P')
	{
		#Confirm that the PIM message has more parts to it
		if (length($data) >=2)
		{
			#Register Dump
			if (uc(substr($data,1,1)) eq 'R')
			{
				#get offset
				my $offset;
				my $bRegisters;
				my @Registers;
				$offset = substr($data,2,2);
				$offset = hex($offset);
				if ($offset != 0)
				{	
					# Im too lazy to store this at an offset instead of replacing it entirely
					&::print_log("Partial Register update not supported");
				} else {
					#Convert to a binary quantity
					$bRegisters = pack("H*",substr($data,4,length($data)-4));
					#Convert to a byte array and replace whole register array
					@Registers = unpack("C*",$bRegisters);
					@{$$self{'registers'}} = @Registers;
				}
			}
			#UPB Incoming Message 
			elsif (uc(substr($data,1,1)) eq 'U') {
			}				

		}
	}
}

1;
