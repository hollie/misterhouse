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
	my ($self,$state)=@_;
	$state=lc($state);
	#print "$::Time_Date: Omnistat -> Hold $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @hold;
	if ($state eq "off") {
		@hold=add_checksum(qw(0x01 0x21 0x3f 0x00));
	}elsif ($state eq "on") {
		@hold=add_checksum(qw(0x01 0x21 0x3f 0xff));
	}else {
		print "Omnistat: Invalid Hold state: $state\n";
	}
        &Omnistat::send_cmd(@hold);
	#$main::Serial_Ports{Omnistat}{object}->write(@hold);
}

# Translate Temperature between Fahrenheit and Omni values
sub translate_temp {
  my ($settemp)=@_;
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
	my ($self,$state)=@_;
	$state=lc($state);
	#print "$::Time_Date: Omnistat -> Mode $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @mode;
	if ($state eq "off") {
		@mode=add_checksum(qw(0x01 0x21 0x3d 0x00));
	}elsif ($state eq "heat") {
		@mode=add_checksum(qw(0x01 0x21 0x3d 0x01));
	}elsif ($state eq "cool") {
		@mode=add_checksum(qw(0x01 0x21 0x3d 0x02));
	}elsif ($state eq "auto") {
		@mode=add_checksum(qw(0x01 0x21 0x3d 0x03));
	}else {
		print "Omnistat: Invalid Mode state: $state\n";
	}
        &Omnistat::send_cmd(@mode);
}

sub fan{
	my ($self,$state)=@_;
	$state=lc($state);
	#print "$::Time_Date: Omnistat -> Fan $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @fan;
	if ($state eq "on") {
		@fan=add_checksum(qw(0x01 0x21 0x3e 0x01));
	}elsif ($state eq "auto") {
		@fan=add_checksum(qw(0x01 0x21 0x3e 0x00));
	}else {
		print "Omnistat: Invalid Fan state: $state\n";
	}
        &Omnistat::send_cmd(@fan);
}

sub display{
	#$main::config_parms{Omnistat_serial_port}
	my $DISPLAY_BITS;
	my @display_options=qw(0x01 0x21 0x03); 
	##Bit 0
	if ($main::config_parms{Omnistat_celcius}) {
		$DISPLAY_BITS=0;
	} else {
		$DISPLAY_BITS=1;
	}
	##Bit 1
	if ($main::config_parms{Omnistat_24hr}) {
		$DISPLAY_BITS=$DISPLAY_BITS+2;
	}
	##Bit 2
	if ($main::config_parms{Omnistat_non_program}) {
		$DISPLAY_BITS=$DISPLAY_BITS+4;
	}
	##Bit 3
	if ($main::config_parms{Omnistat_rtp_mode}) {
		$DISPLAY_BITS=$DISPLAY_BITS+8;
	}
	##Bit 4
	if ($main::config_parms{Omnistat_hide_clock}) {
		$DISPLAY_BITS=$DISPLAY_BITS+16;
	}
	$DISPLAY_BITS = sprintf("0x%02x",$DISPLAY_BITS);
	@display_options[3]=$DISPLAY_BITS;
	@display_options=add_checksum(@display_options);
        &Omnistat::send_cmd(@display_options);
}

sub cool_setpoint{
	my ($self,$settemp)=@_;
	#print "$::Time_Date: Omnistat -> Cool setpoint $settemp\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @cool_setpoint=qw(0x01 0x21 0x3b);
	@cool_setpoint[3]=&Omnistat::translate_temp($settemp);
	@cool_setpoint=add_checksum(@cool_setpoint);
        &Omnistat::send_cmd(@cool_setpoint);
}

sub heat_setpoint{
	my ($self,$settemp)=@_;
	#print "$::Time_Date: Omnistat -> Heat setpoint $settemp\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @heat_setpoint=qw(0x01 0x21 0x3c);
	@heat_setpoint[3]=&Omnistat::translate_temp($settemp);
	@heat_setpoint=add_checksum(@heat_setpoint);
        &Omnistat::send_cmd(@heat_setpoint);
}

sub set_time {
	my @set_time=qw(0x01 0x41 0x41);
	my @dow;
	#print "$::Time_Date: Omnistat -> Setting time/day of week\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	@set_time[3] = sprintf("0x%02x",$::Second);
	@set_time[4] = sprintf("0x%02x",$::Minute);
	@set_time[5] = sprintf("0x%02x",$::Hour);
	@set_time=add_checksum(@set_time);
        &Omnistat::send_cmd(@set_time);
	@dow=qw(0x01 0x21 0x3a);
	@dow[3] = sprintf("0x%02x", $::Wday?$::Wday-1:6);
	@dow = add_checksum(@dow);
        &Omnistat::send_cmd(@dow);
        }

sub heating_cycle_time{
	my ($self,$time)=@_;
	#print "$::Time_Date: Omnistat -> Heat cycle time $time\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @heating_cycle_time=qw(0x01 0x21 0x0c);
	$heating_cycle_time[3]=sprintf("0x%02x",$time);
	@heating_cycle_time=add_checksum(@heating_cycle_time);
        &Omnistat::send_cmd(@heating_cycle_time);
}

sub cooling_cycle_time{
	my ($self,$time)=@_;
	#print "$::Time_Date: Omnistat -> Cool cycle time $time\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @cooling_cycle_time=qw(0x01 0x21 0x0c);
	$cooling_cycle_time[3]=sprintf("0x%02x",$time);
	@cooling_cycle_time=add_checksum(@cooling_cycle_time);
        &Omnistat::send_cmd(@cooling_cycle_time);
}

sub cooling_anticipator{
	my ($self,$value)=@_;
	#print "$::Time_Date: Omnistat -> Cooling Anticipator $value\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @cooling_anticipator=qw(0x01 0x21 0x09);
	$cooling_anticipator[3]=sprintf("0x%02x",$value);
	@cooling_anticipator=add_checksum(@cooling_anticipator);
        &Omnistat::send_cmd(@cooling_anticipator);
}
sub heating_anticipator{
	my ($self,$value)=@_;
	#print "$::Time_Date: Omnistat -> Heating Anticipator $value\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @heating_anticipator=qw(0x01 0x21 0x0a);
	$heating_anticipator[3]=sprintf("0x%02x",$value);
	@heating_anticipator=add_checksum(@heating_anticipator);
        &Omnistat::send_cmd(@heating_anticipator);
}

# read specified register(s) from Omnistat
sub read_reg{
  my ($self, $register, $count) = @_;
  my ($regraw,$reg);
  if ($count == '') {
    $count = 1;
    }
  $count = sprintf("0x%02x",$count);
  my ($reg,$reg_req,$byte,$cmd,$cnt);
  my @reg_req=qw(0x01 0x20);
  @reg_req[2] = $register;
  @reg_req[3] = $count;
  @reg_req=add_checksum(@reg_req);
  $regraw = &Omnistat::send_cmd(@reg_req);
  $reg = substr ($regraw, 15, $count * 5);
  #print "$::Time_Date: Omnistat->read_reg: reg=$reg\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  return $reg;
  }

# read Group 1 data from Omnistat
sub read_group1{
  my ($group1raw,$c,$r,$cool_set,$heat_set,$mode,$fan,$hold,$current);
  my @group1_req=qw(0x01 0x02);
  @group1_req=add_checksum(@group1_req);
  $group1raw = &Omnistat::send_cmd(@group1_req);
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
  #print "$::Time_Date: Omnistat->read_group1:$cool_set,$heat_set,$mode,$fan,$hold,$current\n" unless $main::config_parms{no_log} =~/omnistat/ ;
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
  sleep 2;
  # read response
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
