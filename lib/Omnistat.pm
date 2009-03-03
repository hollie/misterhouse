=begin comment

Dan Arnold February 2009
Added function to set registers
Added time translation for thermostat programming (12h or 24h format based on Omnistat_24hr config param)
Added ability to set outside temp to display on thermostat
Added the ability to translate to/from Celcius (depends on the Omnistat_celcius config param)
Modified set procedures to use reg_set
Modified temp translation to use math rather than a lookup table (needed to cover possible outside temps)
Fixed a bug in read_reg
TODO: Modify reg_set to accept muliple registers

Below is a list of registers for reference:

INTERNAL REGISTERS (RO = READ ONLY)
0 (00) - Thermostat address (ro) (1 - 127)
1 (01) - Communications mode (ro) (0, 1, 8 or 24)
2 (02) - System options (ro)
3 (03) - Display options
4 (04) - Calibration offset (1 to 59, 30=no change - ½ C units)
5 (05) - Cool setpoint low limit (Omnitemp units)
6 (06) - Heat setpoint high limit (Omnitemp units)
7 (07) - Reserved
8 (08) - Reserved
9 (09) - Cooling anticipator (0 to 30) (RC-80, -81, -90, -91 only)
10 (0A) - Heating anticipator (0 to 30) (RC-80, -81, -90, -91 only), Stage 2 differential (RC-112)
11 (0B) - Cooling cycle time (2 - 30 minutes)
12 (0C) - Heating cycle time (2 - 30 minutes)
13 (0D) - Aux heat differential, (RC-100, -101, -112), Stage 2 differential (RC-120, -121, -122)  (Omnitemp units)
14 (0E) - Clock adjust (seconds/day) 1=-29, 30=0, 59=+29
15 (0F) - Days remaining until filter reminder
16 (10) - System run time, current week - hours
17 (11) - System run time, last week - hours

Registers 18 - 20 are used only in models with real time pricing.
18 (12) - Real time pricing setback - Mid (Omnitemp units)
19 (13) - High
20 (14) - Critical

Programming registers
21 (15) - weekday morning time
22 (16) - cool setpoint
23 (17) - heat setpoint
24 (18) - weekday day     time
25 (19) - cool setpoint
26 (1A) - heat setpoint
27 (1B) - weekday evening time
28 (1C) - cool setpoint
29 (1D) - heat setpoint
30 (1E) - weekday night   time
31 (1F) - cool setpoint
32 (20) - heat setpoint
33 (21) - Saturday morning time
34 (22) - cool setpoint
35 (23) - heat setpoint
36 (24)  - Saturday day time
37 (25)  - cool setpoint
38 (26) - heat setpoint
39 (27) - Saturday evening time
40 (28) - cool setpoint
41 (29) - heat setpoint
42 (2A) - Saturday night time
43 (2B) - cool setpoint
44 (2C) - heat setpoint
45 (2D) - Sunday morning time
46 (2E) - cool setpoint
47 (2F) - heat setpoint
48 (30) - Sunday day time
49 (31) - cool setpoint
50 (32) - heat setpoint
51 (33) - Sunday evening time
52 (34) - cool setpoint
53 (35) - heat setpoint
54 (36) - Sunday night time
55 (37) - cool setpoint
56 (38) - heat setpoint
57 (39) - Reserved - do not write
58 (3A) - Day of week (0=Monday - 6=Sunday)
59 (3B) - Cool setpoint
60 (3C) - Heat setpoint
61 (3D) - Thermostat mode (0=off, 1=heat, 2=cool, 3=auto) (4=Emerg heat: RC-100, -101, -112 only)
62 (3E) - Fan status (0=auto 1=on)
63 (3F) - Hold (0=off 255=on)
64 (40) - Actual temperature in Omni format
65 (41) - Seconds 0 - 59
66 (42) - Minutes 0 - 59
67 (43) - Hours    0 - 23
68 (44) - Outside temperature
69 (45) - Reserved
70 (46) - Real time pricing mode (0=lo, 1=mid, 2=high, 3=critical) (RC-81, -91, -101, -121 only)
71 (47) - (ro) current mode (0=off 1=heat 2=cool)
72 (48) - (ro) output status
73 (49) - (ro) model of thermostat

Output status register: reflects the positions of the control relays on the thermostat.
bit 0: heat/cool bit - set for heat, clear for cool
bit 1: auxiliary heat bit - set for on, clear for off (RC-100, -101, -112 only)
bit 2: stage 1 run bit - set for on, clear for off
bit 3: fan bit - set for on, clear for off
bit 4: stage 2 run bit: set for on, clear for off (RC-112, 120, 121, 122 only)

Model register: indicates thermostat model
Thermostat model Model register
RC-80 0
RC-81 1
RC-90 8
RC-91 9
RC-100 16
RC-101 17
RC-112 34
RC-120 48
RC-121 49
RC-122 50

Outside Temperature: writing to the outside temperature register will cause the thermostat to display the 
outside temperature every 4 seconds. The thermostat will stop displaying the outside temperature if this
register is not refreshed at least every 5 minutes.

Display Options:
bit 0: set for Fahrenheit, clear for Celsius
bit 1: set for 24 hour time display, clear for AM/PM
bit 2: set for non-programmable, clear for programmable (disables internal programs in thermostat)
bit 3: set for real time pricing (RTP) mode, clear for no RTP (RC-81, -91, -101, -121 only)
bit 4: set to hide clock, RTP and filter display, clear to show them.

Joel Davidson  February 2009
Corrected bad syntax in mode comparison logic in read_group1.

Joel Davidson  December 2005

Re-ordered routines to avoid run-time error from prototyped subroutines.
Modified comparison values in read_group1 tests to fix users problem with
incorrect compare results.  Added additional comments.  Added addressing
mods to support multiple thermostats.  Removed calls to set_time and
display in serial_startup since they cause a funky runtime error.


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

# ********************************************************
# * Get address for this thermostat from the argument.
# * Address defaults to 1 if no argument.
# ********************************************************
sub new {
  my ($class, $address) = @_;
  $address = 1 unless $address;
  my $self = {};
  $$self{address} = $address;
  bless $self;
  return $self;
  }

# *************************************
# * Add the checksum to the cmd array.
# *************************************
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

# **************************************
# * Send the command to the thermostat.
# **************************************
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

# ******************************
# * check for returned data.
# ******************************
sub check_for_data {
  &main::check_for_generic_serial_data('Omnistat');
  }

# *************************************************
# * Set the thermostat clock to the current time.
# *************************************************
sub set_time {
  my ($self) = @_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Setting time/day of week\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my @cmd = qw(0x01 0x41 0x41);
  
  #set the time
  $cmd[0] = sprintf("0x%02x", $addr);
  @cmd[3] = sprintf("0x%02x",$::Second);
  @cmd[4] = sprintf("0x%02x",$::Minute);
  @cmd[5] = sprintf("0x%02x",$::Hour);
  @cmd=add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);

  #set the weekday
  $self->set_reg("0x3a",$::Wday?$::Wday-1:6);

  }

# *******************************************
# * Set the display mode of the thermostat.
# *******************************************
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
    
  $self->set_reg("0x03",sprintf("0x%02x",$DISPLAY_BITS));
  }

# *********************************************
# * Create the Omnistat device on serial port.
# *********************************************
sub serial_startup {
  &main::serial_port_create('Omnistat', $main::config_parms{Omnistat_serial_port}, 300, 'none','raw');
  &::MainLoop_pre_add_hook( \&Omnistat::check_for_data, 1 );
  }

# ********************************
# * Set the hold mode on or off.
# ********************************
sub hold {
  my ($self,$state) = @_;
  my ($value);
  $state = lc($state);
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Hold $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my @cmd;
  if ($state eq "off") {
    $self->set_reg("0x3f","0x00");
  } elsif ($state eq "on") {
    $self->set_reg("0x3f","0xff");
  } else {
    print "Omnistat: Invalid Hold state: $state\n";
  }
  
  }

# *************************************************************
# * Translate Temperature between Fahrenheit/Celcius and Omni values.
# *************************************************************
sub translate_temp {
  my ($settemp) = @_;
  my ($omnitemp);

  #Calculate conversion mathmatically rather than using a table so all temps will work (needed for outside temperature
  if (substr($settemp,0,2) eq '0x') {	# if it starts with 0x, reverse xlate
    $omnitemp = hex ($settemp);
    $omnitemp = -40 + .5 * $omnitemp; #degrees Celcius
    if (!($main::config_parms{Omnistat_celcius})) {
      $omnitemp = 32 + 1.8 * $omnitemp; # degrees Fahrenheit
      $omnitemp = int($omnitemp + .5 * ($omnitemp <=> 0)); #round
    }
  } else {				# xlate from Fahrenheit/Celcius
    if (!($main::config_parms{Omnistat_celcius})) {
      $omnitemp = ($settemp - 32) / 1.8; #Fahrenheit to Celcius
    }
    $omnitemp = ($omnitemp + 40 ) / .5; #omnistat degrees
    $omnitemp = int($omnitemp + .5 * ($omnitemp <=> 0)); #round
    $omnitemp = sprintf("0x%x", $omnitemp);
  }
  
  return $omnitemp;
  }


# *************************************************************
# * Translate Time between readable and Omni values.
# *************************************************************
sub translate_time {
  my ($settime) = @_;
  my ($hours,$minutes,$ampm);
  my ($omnitime);
  
  if (substr($settime,0,2) eq '0x') { #Translate omnitime to readable time
      if ($settime eq '0x60') { #if it's set to 24hrs past midnight, time is blank
        $omnitime = ''; 
      } else { 
        $minutes = hex($settime) * 15; #Omnistat is stored as 15 minute time periods pas midnight
        $hours = int($minutes / 60);
        $minutes = $minutes % 60; #minutes past hour
        if ($main::config_parms{Omnistat_24hr}) {
          #Translate to 24hr time
          $omnitime =  sprintf ('%02s:%02s',$hours,$minutes);
        } else {
          #Translate omni to AM/PM
          if ($hours == 0) {
            $hours = 12;
            $ampm = 'PM';
          } elsif ($hours > 12) {
            $ampm = 'PM';
            $hours -= 12;
          } else {
            $ampm = 'AM';
          }
          $omnitime =  sprintf ('%02s:%02s %s',$hours,$minutes,$ampm);
        }
       }
  } else { #Translate readable to omnistat time
    if ($settime eq '0') {#set to 0 to clear time, or 24:00 if using 24h time
      $omnitime = '0x60';
    } elsif ($main::config_parms{Omnistat_24hr}) {
      #convert 24h time
      if ($settime =~ /^([0-1][0-9]|[2][0-4]):([0-5][0-9])$/) {
        #valid time
        $hours = $1;
        $minutes = $2;
        $minutes = $minutes + $hours * 60;
        $omnitime = $minutes / 15;
        $omnitime = sprintf("0x%x", $omnitime);
      } else {
        #invalid time
        $omnitime = '';
      }
    } else {
      #convert am/pm time
      if ($settime =~ /^(1[0-2]|[1-9]):([0-5][0-9]) *(AM|PM)$/) {
        #valid time
        $hours = $1;
        $minutes = $2;
        $ampm = $3;
        
        #PM we may need to add 12 hours (unless it's midnight), AM is already right
        if ($ampm == 'PM') {        
          if ($hours == 12) { 
            $hours = 0;
          } else {
            $hours = $hours + 12;
          }
        }
          
        $minutes = $minutes + $hours * 60;
        $omnitime = $minutes / 15;
        $omnitime = sprintf("0x%x", $omnitime);
      } else {
        #invalid time
        $omnitime = '';
      }
    }
    
  }
  
  return $omnitime;
  }

# *****************************************************************
# * Change the mode of the thermostat between off/auto/heat/cool.
# *****************************************************************
sub mode{
  my ($self,$state) = @_;
  $state = lc($state);
  #print "$::Time_Date: Omnistat -> Mode $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  my $addr = $$self{address};
  my @cmd;
  if ($state eq "off") {
    $self->set_reg("0x3d","0x00");
    } elsif ($state eq "heat") {
    $self->set_reg("0x3d","0x01");
    } elsif ($state eq "cool") {
    $self->set_reg("0x3d","0x02");
    } elsif ($state eq "auto") {
    $self->set_reg("0x3d","0x03");
    } else {
    print "Omnistat: Invalid Mode state: $state\n";
  }
  
  }

# ************************************
# * Set the fan mode to on/off/auto.
# ************************************
sub fan{
  my ($self,$state) = @_;
  $state = lc($state);
  my $addr = $$self{address};
  my @cmd;
  #print "$::Time_Date: Omnistat -> Fan $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  if ($state eq "on") {
    $self->set_reg("0x3e","0x01");
    } elsif ($state eq "auto") {
    $self->set_reg("0x3e","0x00");
    } else {
    print "Omnistat: Invalid Fan state: $state\n";
    }
  }

# **************************
# * Set the cool setpoint.
# **************************
sub cool_setpoint{
  my ($self,$settemp) = @_;
  $self->set_reg("0x3b",&Omnistat::translate_temp($settemp));
  }

# **************************
# * Set the heat setpoint.
# **************************
sub heat_setpoint{
  my ($self,$settemp) = @_;
  $self->set_reg("0x3c",&Omnistat::translate_temp($settemp));
  }

# **************************************
# * Set the outdoor temperature
# **************************************
sub outdoor_temp{
  my ($self,$settemp)=@_;
  my $addr = $$self{address};
  $self->set_reg("0x44",&Omnistat::translate_temp($settemp));
  }

# *******************************
# * Set the heating cycle time.
# *******************************
sub heating_cycle_time{
  my ($self,$time) = @_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Heat cycle time $time\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  $self->set_reg("0x0c",sprintf("0x%02x",$time));
  }

# *******************************
# * Set the cooling cycle time.
# *******************************
sub cooling_cycle_time{
  my ($self,$time) = @_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Cool cycle time $time\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  $self->set_reg("0x0b",sprintf("0x%02x",$time));
  }

# **************************************
# * Set the cooling anticipator time.
# **************************************
sub cooling_anticipator{
  my ($self,$value)=@_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Cooling Anticipator $value\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  $self->set_reg("0x09",sprintf("0x%02x",$value));
  }

# **************************************
# * Set the heating anticipator time.
# **************************************
sub heating_anticipator{
  my ($self,$value)=@_;
  my $addr = $$self{address};
  #print "$::Time_Date: Omnistat -> Heating Anticipator $value\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  $self->set_reg("0x0a",sprintf("0x%02x",$value));
  }

# *********************************************
# * Read specified register(s) from Omnistat.
# *********************************************
sub read_reg{
  my ($self, $register, $count) = @_;
  my $addr = $$self{address};
  my (@cmd,$regraw,$reg,$byte,$cnt);
  if ($count == '') {
    $count = 1;
    }
    
  $cmd[0] = sprintf("0x%02x", $addr);
  $cmd[1] = "0x20";
  $cmd[2] = $register;
  $cmd[3] = sprintf("0x%02x",$count);
  @cmd=add_checksum(@cmd);
  $regraw = &Omnistat::send_cmd(@cmd);
  $reg = substr ($regraw, 15, $count * 5);
  #print "$::Time_Date: Omnistat->read_reg: reg=$reg\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  return $reg;
  }

# *********************************************
# * Write specified register to Omnistat.
# *********************************************
#TODO: add ability to set multiple registers at once
sub set_reg{
  my ($self, $register, $value) = @_;
  my $addr = $$self{address};
  my (@cmd);
  $cmd[0] = sprintf("0x%02x", $addr);
  $cmd[1] = "0x21";
  $cmd[2] = $register;
  $cmd[3] = $value;
  @cmd=add_checksum(@cmd);
  &Omnistat::send_cmd(@cmd);  
  }

# ************************************
# * Read Group 1 data from Omnistat.
# ************************************
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
  if ($mode eq "0x00") { $mode = 'off'; }
  if ($mode eq "0x01") { $mode = 'heat';}
  if ($mode eq "0x02") { $mode = 'cool';}
  if ($mode eq "0x03") { $mode = 'auto';}
  if ($fan  eq "0x00") { $fan = 'auto';}
  if ($fan  eq "0x01") { $fan = 'on';}
  if ($hold eq "0x00") { $hold = 'off';}
  if ($hold eq "0xff") { $hold = 'on';}
  $current = &Omnistat::translate_temp($current);
  #print "$::Time_Date: Omnistat->read_group1:$cool_set,$heat_set,$mode,$fan,$hold,$current\n" unless $main::config_parms{no_log} =~/omnistat/ ;
  return ($cool_set,$heat_set,$mode,$fan,$hold,$current);
  }

1;
