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
	UPBPIM_network=
	UPBPIM_moduleid=
	UPBPIM_password=


    Example initialization:

	use UPBPIM;
	$myPIM = new UPBPIM();

Notes:
    - This code does not yet support sending messages and is very incomplete 
	  code so far.  The only working method of the class is get_firmwareVersion()
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
   my ($class, $port_name) = @_;
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
	$self->set_dtr(1);
	$self->updateRegisters();
   return $self;
}


sub updateRegisters
{
	my ($self, $start, $end) = @_;
	my $cmd;
	$start = 0 if not defined $start;
	$end = 255 if not defined $end;
	$cmd= sprintf("%02X%02X",$start,$end);
	$cmd.= get_checksumHex($cmd);
	return $self->_send_cmd("\x12" . $cmd . "\x0D");
}

sub get_firwareVersion
{
	my ($self, $cmd) = @_;
	my $hiByte;
	my $lowByte;
	$hiByte = sprintf("%02X",@{$$self{'registers'}}->[10]);
	$lowByte = sprintf("%02X",@{$$self{'registers'}}->[11]);
#	print "REG:@{@$self{'registers'}}";
	return $hiByte . $lowByte;
}

sub _send_cmd {
	my ($self, $cmd) = @_;
	my $instance = $$self{port_name};
	print "$::Time_Date: UPBPIM: Executing command $cmd\n" unless $main::config_parms{no_log} =~/UPBPIM/;
	my $data = $cmd;
	$main::Serial_Ports{$instance}{object}->write($data);
#   select(undef,undef,undef,0.15);
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
		}
	}
}

1;
