=begin comment

Joel Davidson  June 2004

Modified checksum() to return 8 bit checksum.  Fixed set_time.
Added read_group1 to return register group 1 values (setpoints,
modes, current temperature).  Added generic function to read any
specified register(s), read_register(address, [# of regs]).
Changed Omnistat_run_program config option to Omnistat_non_program.
Setting to a 1 disables thermostat internal program.  Changed
Omnistat_show_clock to Omnistat_hide_clock.  1 hides clock and filter
display.


From Kent Noonan on Jan 2002

I have another module for misterhouse. But it is not finished. This is a
module for controling HAI Omnistat Communicating thermostats. It was
specifically written against the RC80 but as far as I can tell it should
work with any of them. There is a problem with it. I am not finished with
it. I started working on it, then moved to a house with an older heater
that the thermostat doesn't work with. It's going to be a couple of years
before we can upgrade the heater, so I thought I'd send this incase
somebody else wanted to continue where I left off before I can get back to
it again.  Right now I can't even gaurantee that it works at all, but I
think it did.. 


See example in mh/code/public/omnistat.pl


used with HAI RC-Series Electronic Communicating Thermostats (Omnistat)
Specifically written with/for RC-80 But should work with any of them(??).
http://www.homeauto.com/Products/HAIAccessories/Omnistat/rc80.htm

###################

Use these mh.ini parameters to enable this code:

Omnistat_serial_port   = /dev/ttyR43

There are optional settings for the Omnistat for the mh.ini:
If these settings aren't in the mh.ini the default is 0 (false)

#use celcius for temperatures
Omnistat_celcius=[0,1]
#use 24hour clock for times
Omnistat_24hr=[0,1]
#disable internal program
Omnistat_non_program=[0,1]
#Real Time Pricing mode
Omnistat_rtp_mode=[0,1]
#hide clock on thermostat
Omnistat_hide_clock=[0,1]


########################################################
=cut

use strict;

package Omnistat;

# --------------------------------------------------------------
# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

@Omnistat::ISA = ('Serial_Item');

# get address for this thermostat from the argument
# address defaults to 1 if no argument
sub new {
  my ($class, $address) = @_;
  $address = 1 unless $address;
  my $self = {};
  $$self{address} = $address;
  bless $self;
  return $self;
  }

sub serial_startup {
  &main::serial_port_create('Omnistat', $main::config_parms{Omnistat_serial_port}, 300, 'none','raw');
  &::MainLoop_pre_add_hook( \&Omnistat::check_for_data, 1 );
  &Omnistat::display;
  &Omnistat::set_time;
  }

sub check_for_data {
  &main::check_for_generic_serial_data('Omnistat');
  }

sub hold{
  my ($self,$state) = @_;
  $state = lc($state);
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Hold $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my @cmd;
  if ($state eq "off") {
    @cmd = qw(0x00 0x21 0x3f 0x00);
  } elsif ($state eq "on") {
    @cmd = qw(0x00 0x21 0x3f 0xff);
  } else {
    print "Omnistat: Invalid Hold state: $state\n";
    }
  $cmd[0] = sprintf("0x%02x", $addr);
  @cmd = add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

# Translate Temperature between Fahrenheit and Omni values
sub translate_temp {
  my ($settemp) = @_;
  my ($omnitemp);
  # temp translates fahrenheit to omni
  my %temp=(51=>"0x65", 52=>"0x66", 53=>"0x67", 54=>"0x68", 55=>"0x69", 
            56=>"0x6b", 57=>"0x6c", 58=>"0x6d", 59=>"0x6e", 60=>"0x6f", 
            61=>"0x70", 62=>"0x71", 63=>"0x72", 64=>"0x74", 65=>"0x75", 
            66=>"0x76", 67=>"0x77", 68=>"0x78", 69=>"0x79", 70=>"0x7a", 
            71=>"0x7b", 72=>"0x7c", 73=>"0x7d", 74=>"0x7f", 75=>"0x80", 
            76=>"0x81", 77=>"0x82", 78=>"0x83", 79=>"0x84", 80=>"0x85", 
            81=>"0x86", 82=>"0x87", 83=>"0x89", 84=>"0x8a", 85=>"0x8b", 
            86=>"0x8c", 87=>"0x8d", 88=>"0x8e", 89=>"0x8f", 90=>"0x90", 
            91=>"0x91", 92=>"0x93", 93=>"0x94", 94=>"0x95", 95=>"0x96");
  # reversetemp translates omni to fahrenheit
  my %reversetemp = reverse %temp;
  if (substr($settemp,0,2) eq '0x') {	# if it starts with 0x, reverse xlate
    $omnitemp = $reversetemp{$settemp};
    } else {				# xlate from Fahrenheit
    $omnitemp = $temp{$settemp};
    }
  return $omnitemp;
  }

sub mode{
  my ($self,$state) = @_;
  $state = lc($state);
  #print "$::Time_Date: Omnistat -> Mode $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my $addr = $$self{address};
  my @cmd;
  if ($state eq "off") {
    @cmd = qw(0x01 0x21 0x3d 0x00);
    } elsif ($state eq "heat") {
    @cmd = qw(0x01 0x21 0x3d 0x01);
    } elsif ($state eq "cool") {
    @cmd = qw(0x01 0x21 0x3d 0x02);
    } elsif ($state eq "auto") {
    @cmd = qw(0x01 0x21 0x3d 0x03);
    } else {
    print "Omnistat: Invalid Mode state: $state\n";
  }
  $cmd[0] = sprintf("0x%02x", $addr);
  @cmd = add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

sub fan{
  my ($self,$state) = @_;
  $state = lc($state);
  my $addr = $$self{address};
  my @cmd;
  #print "$::Time_Date: Omnistat -> Fan $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  if ($state eq "on") {
    @cmd = qw(0x01 0x21 0x3e 0x01);
    } elsif ($state eq "auto") {
    @cmd = qw(0x01 0x21 0x3e 0x00);
    } else {
    print "Omnistat: Invalid Fan state: $state\n";
    }
  $cmd[0] = sprintf("0x%02x", $addr);
  @cmd = add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

sub display{
  my ($self) = @_;
  my $addr = $$self{address};
  #$main::config_parms{Omnistat_serial_port}
  my $DISPLAY_BITS;
  ##Bit 0
  if ($main::config_parms{Omnistat_celcius}) {
    $DISPLAY_BITS = 0;
  } else {
    $DISPLAY_BITS = 1;
    }
  ##Bit 1
  if ($main::config_parms{Omnistat_24hr}) {
    $DISPLAY_BITS = $DISPLAY_BITS+2;
    }
  ##Bit 2
  if ($main::config_parms{Omnistat_non_program}) {
    $DISPLAY_BITS = $DISPLAY_BITS+4;
    }
  ##Bit 3
  if ($main::config_parms{Omnistat_rtp_mode}) {
    $DISPLAY_BITS = $DISPLAY_BITS+8;
    }
  ##Bit 4
  if ($main::config_parms{Omnistat_hide_clock}) {
    $DISPLAY_BITS = $DISPLAY_BITS+16;
    }
  my @cmd = qw(0x01 0x21 0x03); 
  $cmd[0] = sprintf("0x%02x", $addr);
  @cmd[3] = sprintf("0x%02x",$DISPLAY_BITS);
  @cmd = add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

sub cool_setpoint{
  my ($self,$settemp) = @_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Cool setpoint $settemp\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my @cmd = qw(0x01 0x21 0x3b);
  $cmd[0] = sprintf("0x%02x", $addr);
  @cmd[3] = &Omnistat::translate_temp($settemp);
  @cmd = add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

sub heat_setpoint{
  my ($self,$settemp) = @_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Heat setpoint $settemp\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my @cmd=qw(0x01 0x21 0x3c);
  $cmd[0] = sprintf("0x%02x", $addr);
  @cmd[3]=&Omnistat::translate_temp($settemp);
  @cmd=add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

sub set_time {
  my ($self) = @_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Setting time/day of week\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my @cmd = qw(0x01 0x41 0x41);
  $cmd[0] = sprintf("0x%02x", $addr);
  @cmd[3] = sprintf("0x%02x",$::Second);
  @cmd[4] = sprintf("0x%02x",$::Minute);
  @cmd[5] = sprintf("0x%02x",$::Hour);
  @cmd=add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  @cmd = qw(0x01 0x21 0x3a);
  $cmd[0] = sprintf("0x%02x", $addr);
  @cmd[3] = sprintf("0x%02x", $::Wday?$::Wday-1:6);
  @cmd = add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

sub heating_cycle_time{
  my ($self,$time) = @_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Heat cycle time $time\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my @cmd = qw(0x01 0x21 0x0c);
  $cmd[0] = sprintf("0x%02x", $addr);
  $cmd[3] = sprintf("0x%02x",$time);
  @cmd = add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

sub cooling_cycle_time{
  my ($self,$time) = @_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Cool cycle time $time\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my @cmd = qw(0x01 0x21 0x0c);
  $cmd[0] = sprintf("0x%02x", $addr);
  $cmd[3] = sprintf("0x%02x",$time);
  @cmd = add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

sub cooling_anticipator{
  my ($self,$value)=@_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Cooling Anticipator $value\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my @cmd=qw(0x01 0x21 0x09);
  $cmd[0] = sprintf("0x%02x", $addr);
  $cmd[3]=sprintf("0x%02x",$value);
  @cmd=add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

sub heating_anticipator{
  my ($self,$value)=@_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Heating Anticipator $value\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my @cmd=qw(0x01 0x21 0x0a);
  $cmd[0] = sprintf("0x%02x", $addr);
  $cmd[3]=sprintf("0x%02x",$value);
  @cmd=add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);
  }

# read specified register(s) from Omnistat
sub read_reg{
  my ($self, $register, $count) = @_;
  my $addr = $$self{address};
  my (@cmd,$regraw,$reg,$byte,$cnt);
  if ($count == '') {
    $count = 1;
    }
  my $ncount=$count;    
  $count = sprintf("0x%02x",$count);
  $cmd[0] = sprintf("0x%02x", $addr);
  $cmd[1] = "0x20";
  $cmd[2] = $register;
  $cmd[3] = $count;
  @cmd=add_checksum(@cmd);
  $regraw = &Omnistat::send_cmd(@cmd);
  $reg = substr ($regraw, 15, $ncount * 5);
  #print "  $regraw , $ncount\n";
  #print "$::Time_Date: Omnistat->read_reg: reg=$reg  raw=$regraw\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  return $reg;
  }

# read Group 1 data from Omnistat
sub read_group1{
  my ($self) = @_;
  my $addr = $$self{address};
  my (@cmd,$group1raw,$c,$r,$cool_set,$heat_set,$mode,$fan,$hold,$current);
  $cmd[0] = sprintf("0x%02x", $addr);
  $cmd[1] = "0x02";
  @cmd = add_checksum(@cmd);
  $group1raw = &Omnistat::send_cmd(@cmd);
  ($c,$r,$cool_set,$heat_set,$mode,$fan,$hold,$current) = split ' ', $group1raw;
  $cool_set = &Omnistat::translate_temp($cool_set);
  $heat_set = &Omnistat::translate_temp($heat_set);
  if ($mode == 0) { $mode = 'off'; }
  if ($mode == 1) { $mode = 'heat';}
  if ($mode == 2) { $mode = 'cool';}
  if ($mode == 3) { $mode = 'auto';}
  if ($fan  == 0) { $fan = 'auto';}
  if ($fan  == 1) { $fan = 'on';}
  if ($hold == 0)   { $hold = 'off';}
  if ($hold == 255) { $hold = 'on';}
  $current = &Omnistat::translate_temp($current);
  #print "$::Time_Date: Omnistat->read_group1:$cool_set,$heat_set,$mode,Fan>>$fan,$hold,$current\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  return ($cool_set,$heat_set,$mode,$fan,$hold,$current);
  }


# *****************
# * support stuff *
# *****************

# send command to thermostat
sub send_cmd{
  
  my (@string) = @_;
  my ($byte, $cmd);
  $cmd = '';
  #print "$::Time_Date: Omnistat->send_cmd string=@string\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  foreach $byte (@string) {
    $byte =~ s/0x//;			# strip off the 0x
    $cmd = $cmd . pack "H2", $byte;	# pack it into 8 bits
    }
  # send it to thermostat
  $main::Serial_Ports{Omnistat}{object}->write($cmd);
  # need to wait a bit for the reply
  sleep 1 ; #really only 90ms
  &main::check_for_generic_serial_data('Omnistat');
  my $temp=$main::Serial_Ports{Omnistat}{data};
  $main::Serial_Ports{Omnistat}{data} = '';
  my $len = length($temp);
  $temp = unpack("H*", $temp);
  my ($i);
  my $rcvd = '';
  for ($i=0; $i < $len; $i++) {
    $rcvd = $rcvd . sprintf("0x%s ", substr($temp, $i*2, 2));
    }
  return $rcvd;
  }

sub add_checksum {
	my (@array) = @_;
	my @modarr = @array;
	my $value=0;
	foreach  (@modarr) {
		s/^0x//g;
		$_=hex($_);
		$value=$value+$_;
	}
	$value = $value % 256;
	$array[$#array+1] = sprintf("0x%02x",$value);
	return @array;
}


1;
