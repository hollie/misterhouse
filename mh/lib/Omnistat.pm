=begin comment


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
#programmable (run internal program)
Omnistat_run_program=[0,1]
#Real Time Pricing mode
Omnistat_rtp_mode=[0,1]
#show clock on thermostat
Omnistat_show_clock=[0,1]

Todo:
 Need to work on getting information from thermostat


########################################################
=cut

use strict;

package Omnistat;

@Omnistat::ISA = ('Serial_Item');

sub serial_startup {
    &main::serial_port_create('Omnistat', $main::config_parms{Omnistat_serial_port}, 300, '','raw');
    &::MainLoop_pre_add_hook(  \&Omnistat::check_for_data, 1 );
	&Omnistat::display;
	&Omnistat::set_time;
}

sub check_for_data {
    &main::check_for_generic_serial_data('Omnistat');
}


#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!
#Temperature Array
#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!#!
my @temp;

$temp[51]="0x65";
$temp[52]="0x66";
$temp[53]="0x67";
$temp[54]="0x68";
$temp[55]="0x69";
$temp[56]="0x6b";
$temp[57]="0x6c";
$temp[58]="0x6d";
$temp[59]="0x6e";
$temp[60]="0x6f";
$temp[61]="0x70";
$temp[62]="0x71";
$temp[63]="0x72";
$temp[64]="0x74";
$temp[65]="0x75";
$temp[66]="0x76";
$temp[67]="0x77";
$temp[68]="0x78";
$temp[69]="0x79";
$temp[70]="0x7a";
$temp[71]="0x7b";
$temp[72]="0x7c";
$temp[73]="0x7d";
$temp[74]="0x7f";
$temp[75]="0x80";
$temp[76]="0x81";
$temp[77]="0x82";
$temp[78]="0x83";
$temp[79]="0x84";
$temp[80]="0x85";
$temp[81]="0x86";
$temp[82]="0x87";
$temp[83]="0x89";
$temp[84]="0x8a";
$temp[85]="0x8b";
$temp[86]="0x8c";
$temp[87]="0x8d";
$temp[88]="0x8e";
$temp[89]="0x8f";
$temp[90]="0x90";
$temp[91]="0x91";
$temp[92]="0x93";
$temp[93]="0x94";
$temp[94]="0x95";
$temp[95]="0x96";


# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

sub hold{
	my ($self,$state)=@_;
	$state=lc($state);
	print "$::Time_Date: Omnistat -> Hold $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @hold;
	if ($state eq "off") {
		@hold=add_checksum(qw(0x01 0x21 0x3f 0x00));
	}elsif ($state eq "on") {
		@hold=add_checksum(qw(0x01 0x21 0x3f 0xff));
	}else {
		print "Omnistat: Invalid Hold state: $state\n";
	}
	$main::Serial_Ports{Omnistat}{object}->write(@hold);
}

sub mode{
	my ($self,$state)=@_;
	$state=lc($state);
	print "$::Time_Date: Omnistat -> Mode $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
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
	$main::Serial_Ports{Omnistat}{object}->write(@mode);
}

sub fan{
	my ($self,$state)=@_;
	$state=lc($state);
	print "$::Time_Date: Omnistat -> Fan $state\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @fan;
	if ($state eq "on") {
		@fan=add_checksum(qw(0x01 0x21 0x3e 0x01));
	}elsif ($state eq "auto") {
		@fan=add_checksum(qw(0x01 0x21 0x3e 0x00));
	}else {
		print "Omnistat: Invalid Fan state: $state\n";
	}
	$main::Serial_Ports{Omnistat}{object}->write(@fan);
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
	if ($main::config_parms{Omnistat_run_program}) {
		$DISPLAY_BITS=$DISPLAY_BITS+4;
	}
	##Bit 3
	if ($main::config_parms{Omnistat_rtp_mode}) {
		$DISPLAY_BITS=$DISPLAY_BITS+8;
	}
	##Bit 4
	if ($main::config_parms{Omnistat_show_clock}) {
		$DISPLAY_BITS=$DISPLAY_BITS+16;
	}
	$display_options[3]=$DISPLAY_BITS;
	@display_options=add_checksum(@display_options);
	$main::Serial_Ports{Omnistat}{object}->write(@display_options);

}

sub cool_setpoint{
	my ($self,$temp)=@_;
	print "$::Time_Date: Omnistat -> Cool setpoint $temp\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @cool_setpoint=qw(0x01 0x21 0x3b);
	$cool_setpoint[3]=$Omnistat::temp[$temp];
	@cool_setpoint=add_checksum(@cool_setpoint);
	$main::Serial_Ports{Omnistat}{object}->write(@cool_setpoint);
}

sub heat_setpoint{
	my ($self,$temp)=@_;
	print "$::Time_Date: Omnistat -> Heat setpoint $temp\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @heat_setpoint=qw(0x01 0x21 0x3c);
	$heat_setpoint[3]=$Omnistat::temp[$temp];
	@heat_setpoint=add_checksum(@heat_setpoint);
	$main::Serial_Ports{Omnistat}{object}->write(@heat_setpoint);
}

sub set_time {
	my @dow;

	my @set_time=qw(0x01 0x21 0x41);
	$set_time[3] = sprintf("0x%x",$::Second);
	$set_time[4] = sprintf("0x%x",$::Minute);
	$set_time[5] = sprintf("0x%x",$::Hour);
	@set_time=add_checksum(@set_time);
	$main::Serial_Ports{Omnistat}{object}->write(@set_time);
	
	if ($::Wday == 0) {
		@dow=qw(0x01 0x21 0x3a 0x06);
	}elsif ($::Wday == 1) {
		@dow=qw(0x01 0x21 0x3a 0x00);
	}elsif ($::Wday == 2) {
		@dow=qw(0x01 0x21 0x3a 0x01);
	}elsif ($::Wday == 3) {
		@dow=qw(0x01 0x21 0x3a 0x02);
	}elsif ($::Wday == 4) {
		@dow=qw(0x01 0x21 0x3a 0x03);
	}elsif ($::Wday == 5) {
		@dow=qw(0x01 0x21 0x3a 0x04);
	}elsif ($::Wday == 6) {
		@dow=qw(0x01 0x21 0x3a 0x05);
	}
	$main::Serial_Ports{Omnistat}{object}->write(@dow);
}

sub heating_cycle_time{
	my ($self,$time)=@_;
	print "$::Time_Date: Omnistat -> Heat cycle time $time\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @heating_cycle_time=qw(0x01 0x21 0x0c);
	$heating_cycle_time[3]="0x$time";
	@heating_cycle_time=add_checksum(@heating_cycle_time);
	$main::Serial_Ports{Omnistat}{object}->write(@heating_cycle_time);
}

sub cooling_cycle_time{
	my ($self,$time)=@_;
	print "$::Time_Date: Omnistat -> Cool cycle time $time\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @cooling_cycle_time=qw(0x01 0x21 0x0c);
	$cooling_cycle_time[3]="0x$time";
	@cooling_cycle_time=add_checksum(@cooling_cycle_time);
	$main::Serial_Ports{Omnistat}{object}->write(@cooling_cycle_time);
}
sub cooling_anticipator{
	my ($self,$value)=@_;
	print "$::Time_Date: Omnistat -> Cooling Anticipator $value\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @cooling_anticipator=qw(0x01 0x21 0x09);
	$cooling_anticipator[3]="0x$value";
	@cooling_anticipator=add_checksum(@cooling_anticipator);
	$main::Serial_Ports{Omnistat}{object}->write(@cooling_anticipator);
}
sub heating_anticipator{
	my ($self,$value)=@_;
	print "$::Time_Date: Omnistat -> Heating Anticipator $value\n" unless $main::config_parms{no_log} =~/omnistat/ ;
	my @heating_anticipator=qw(0x01 0x21 0x0a);
	$heating_anticipator[3]="0x$value";
	@heating_anticipator=add_checksum(@heating_anticipator);
	$main::Serial_Ports{Omnistat}{object}->write(@heating_anticipator);
}


###$$$###$$$###$$$###$$$

sub add_checksum {
	my (@array) = @_;
	my @modarr = @array;
	my $value=0;
	foreach  (@modarr) {
		s/^0x//g;
		$_=hex($_);
		$value=$value+$_;
	}
	$array[$#array+1] = sprintf("0x%x",$value);
	return @array;
}


1;
