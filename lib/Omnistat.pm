=begin comment

# 132 columns max
123456789112345678921234567893123456789412345678951234567896123456789712345678981234567899123456789012345678911234567892123456789312

# this file, if distributed separately, replaces misterhouse/lib/Omnistat.pm

Module for HAI RC-Series Electronic Communicating Thermostats (Omnistat)
Specifically written with/for RC-80 but should work with any of them.
http://www.homeauto.com/Products/HAIAccessories/Omnistat/rc80.htm

Newer Omnistat2 thermostats have a slightly different protocol and may need
some work. They look nicer, but they are pricier (vs $50 for an RC-80 on ebay)
and don't offer functionality that's useful to most people -- merlin


###################

Use these mh.ini parameters to enable this code:
Omnistat_serial_port=/dev/ttyUSB0

There are optional settings for the Omnistat for mh.private.ini:
If these settings aren't in mh.private.ini the default is 0 (false)

# use celcius for temperatures
Omnistat_celcius=[0,1]
# use 24hour clock for times
Omnistat_24hr=[0,1]
# disable internal program
Omnistat_non_program=[0,1]
# Real Time Pricing mode
Omnistat_rtp_mode=[0,1]
# hide clock on thermostat
Omnistat_hide_clock=[0,1]
# You can set how much gets logged 
Omnistat_no_stat_log=[0,1,2,3]

# For debugging, add omnistat to debug in mh.private.ini, as in
debug=insteon,omnistat
# instead of debug=insteon

This module is used 2 ways
1) from a web interface
2) from mh/code/public/omnistat.pl which you need to install in your code directory


================================================================================
TODOs
================================================================================

TODO: Add hooks for caching instead of relying on pl file
TODO: ini parameter for range of registers to read (default to temp)
TODO: Adjust clock speed? Not sure if possible (reg 14), may need to be done in pl
TODO: Modify set_reg to accept muliple registers (hasn't been really needed so far)
TODO: Ini Parameter to turn on/off set outdoor temp (may be in pl)
TODO: The sleep situation has been much improved, but if someone smart could replace
      the sleep with a proper callback so as not to stall mh, that would rule

================================================================================
Changelog
================================================================================

2009/08/03 - Marc MERLIN
========================
- send_cmd is now a method too so that we can compare the return value against $$self{addr}
- improved command ack parsing failure error reporting
- oops, got omnistat_log function to actually respect log_level
- added omnistat_debug function
- hold function now only sets hold if it's different from cached value, this is because we get
  frequent calls to hold off and want to avoid actually sending them if hold was already off
- restore|cool|heat_setpoints now unhold the that before programming it (or it won't work) and
  then put it back on hold depending on the Omnistat_set_does_not_hold setting in mh.private.ini


2009/07/25 - Marc MERLIN
========================
- optimized sleep/wait in send_cmd to be as little as needed. It is now as cheap to
  read 2 registers separately as 10 registers in a row: 0.666s
  (before, reading 2 registers separately took 4 seconds)
- NOTE: if you were calling send_cmd, you need to change your call to prepend the number
  of characters you expect back (this is needed by the timing improvements)
- fixed get_stat_type method
- A lot more error handling and status reporting, including making sure that you get all
  the data back that you're supposed to get, and that set_reg actually gets some kind of ack
- omnistat.pl allows for temporarily changing setpoints until the next schedule change with
  Omnistat_set_does_not_hold=1 in mh.private.ini
- omnistat_log allows for logging stat data with Omnistat_no_stat_log which defaults to 1
- fixed an insidious bug in set_time that sent an integer for the week instead of an hex string
  perl helpfully converted that and then tried to H2 pack "5" which is invalid and sent a short command
- added checks for set_reg and friends to make sure registers and values are hex strings
- auto convertions in perl are too helpful and can bite you in the butt, so all register values are now
  required to be passed as 0xXX whether they might have worked before, or not


2009/07/22 - Marc MERLIN
========================
- ripped out old one register update per minute cache
- added on demand cache and cache prefetching for setpoints and temperature
- fixed bugs / cleanups
- merged read_group1 with read_reg
- fixed state change messages on multi reg fetches
- made use of caching functions strongly encouraged :)
- added important get_stat_output method to actually know what the stat is telling
  your HVAC system to do
- get_stat_model function


Dan Arnold May 2009
===================
Added state processing

NOTE:  State changes will not take effect until all registers have been cached
-> no more -- merlin
All of the states that may be set:
   all_registers_cached: All of the registers have been read into the cache, you can read any register without penalty
   filter_reminder: Filter reminder has expired
-> obsolete -- merlin
   temp_change: Inside temperature changed
      (call get_temp() to get value)
   heat_sp_change: Heat setpoint was changed
      (call get_heat_sp() to get value).
   cool_sp_change: Cool setpoint was changed
      (call get_cool_sp() to get value).
   mode_change: System mode changed
      (call get_mode() to get value).
   fan_mode_change: Fan mode changed
      (call get_fan_mode() to get value).

New/modified functions available:
   mode():
      Sets system mode to argument: 'off', 'heat', 'cool', 'auto',
      'program_heat', 'program_cool', 'program_auto' (program_ implies hold=off)
   get_mode():
      Returns the last mode returned by poll_mode().
   fan():
      Sets fan to 'on' or 'auto'
   get_fan_mode():
      Returns the current fan mode (fan_on or fan_auto)
   cool_setpoint():
      Sets a new cool setpoint.
   get_cool_sp():
      Returns the current cool setpoint.
   heat_setpoint():
      Sets a new heat setpoint.
   get_heat_sp():
      Returns the current heat setpoint.
   get_temp():
      Returns the current temperature at the thermostat.
   get_filter_reminder():
      Returns the number of days until the furnace filter needs to be replaced
   restore_setpoints():
      Returns the heat/cool setpoints to what they would have been if the thermostat were running on schedule


Dan Arnold March 2009
======================
Added caching of registers


Dan Arnold February 2009
=========================
Added function to set registers
Added time translation for thermostat programming (12h or 24h format based on Omnistat_24hr config param)
Added ability to set outside temp to display on thermostat
Added the ability to translate to/from Celcius (depends on the Omnistat_celcius config param)
Modified set procedures to use set_reg
Modified temp translation to use math rather than a lookup table (needed to cover possible outside temps)
Fixed a bug in read_reg


Joel Davidson  February 2009
=========================
Corrected bad syntax in mode comparison logic in read_group1.


Joel Davidson  December 2005
=========================
Re-ordered routines to avoid run-time error from prototyped subroutines.
Modified comparison values in read_group1 tests to fix users problem with
incorrect compare results.  Added additional comments.  Added addressing
mods to support multiple thermostats.  Removed calls to set_time and
display in serial_startup since they cause a funky runtime error.


Joel Davidson  June 2004
=========================
Modified checksum() to return 8 bit checksum.  Fixed set_time.
Added read_group1 to return register group 1 values (setpoints,
modes, current temperature).  Added generic function to read any
specified register(s), read_register(address, [# of regs]).
Changed Omnistat_run_program config option to Omnistat_non_program.
Setting to a 1 disables thermostat internal program.  Changed
Omnistat_show_clock to Omnistat_hide_clock.  1 hides clock and filter
display.


Kent Noonan  Jan 2002
=====================
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





########################################################

Below is a list of registers for reference:

# INTERNAL REGISTERS (RO = READ ONLY)
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

# Registers 18 - 20 are used only in models with real time pricing.
18 (12) - Real time pricing setback - Mid (Omnitemp units)
19 (13) - High
20 (14) - Critical

# Programming registers
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
36 (24) - Saturday day time
37 (25) - cool setpoint
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

# this one is lost, it kind of belongs with 0x41 below
58 (3A) - Day of week (0=Monday - 6=Sunday)

# group1 data start
59 (3B) - Cool setpoint (current)
60 (3C) - Heat setpoint (current)
61 (3D) - Thermostat mode (0=off, 1=heat, 2=cool, 3=auto) (4=Emerg heat: RC-100, -101, -112 only)
62 (3E) - Fan status (0=auto 1=on)
63 (3F) - Hold (0=off 255=on)
64 (40) - Actual temperature in Omni format
# group1 data stop.
# Would have been so very nice is 0x48 were in group1 since you typically want to query that often too
# to know what commands your stat is sending to your HVAC system :-/

65 (41) - Seconds 0 - 59
66 (42) - Minutes 0 - 59
67 (43) - Hours   0 - 23
68 (44) - Outside temperature (see below)
69 (45) - Reserved
70 (46) - Real time pricing mode (0=lo, 1=mid, 2=high, 3=critical) (RC-81, -91, -101, -121 only)
71 (47) - (ro) current mode (0=off 1=heat 2=cool)
72 (48) - (ro) output status
73 (49) - (ro) model of thermostat

# 0x48: reflects the positions of the control relays on the thermostat.
bit 0: heat/cool bit - set for heat, clear for cool
bit 1: auxiliary heat bit - set for on, clear for off (RC-100, -101, -112 only)
bit 2: stage 1 run bit - set for on, clear for off
bit 3: fan bit - set for on, clear for off
bit 4: stage 2 run bit: set for on, clear for off (RC-112, 120, 121, 122 only)

# 0x49: thermostat model
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

=cut

use strict;

package Omnistat;

sub omnistat_debug {
  my ($mesg) = @_;

  print "$::Time_Date: $mesg\n" if $::Debug{omnistat};
}

# Load Time::HiRes if it's available
use vars qw($USLEEP);
eval { require Time::HiRes };
if (not $@) {
  Time::HiRes->import( qw(usleep) );
  omnistat_debug("Omnistat found Time::Hires, will use usleep in omni_sleep");
  $USLEEP=1;
} else {
  omnistat_debug("Omnistat did NOT find Time::Hires, will NOT use usleep in omni_sleep");
  warn("Omnistat works much better with Time::HiRes, install it if you can");
  $USLEEP=0;
}

# --------------------------------------------------------------
# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

@Omnistat::ISA = ('Serial_Item');

sub omni_sleep() {
  $USLEEP ? usleep($_[0]) : sleep(int($_[0] + 0.99999));
}


# My guess is that most people would want to have temperature logging, but you can turn it off with
# Omnistat_stat_log=0 in mh.private.ini -- merlin
sub omnistat_log {
  my ($mesg, $level) = @_;
  my $loglevel = $main::config_parms{Omnistat_stat_log};

  $loglevel = 1 if (not defined $loglevel);
  $level = 1 if (not defined $level);

  &::print_log("log=logs/thermostat.log $mesg") if ($level <= $loglevel);
}


sub is_hex {
  # make sure we got proper hex and not a number or some other error
  return ($_[0] =~ /^0x[0-9a-fA-F][0-9a-fA-F]$/);
}

# ********************************************************
# * Get address for this thermostat from the argument.
# * Address defaults to 1 if no argument.
# ********************************************************
sub new {
  my ( $class, $address ) = @_;
  $address = 1 unless $address;
  my $self = {};
  $$self{address}            = $address;
  $$self{cache}              = {};
  # when the cache was last updated
  $$self{cache_updatetime}   = {};
  # per register override of how long we want to cache
  $$self{cache_agelimit}     = {};

  # **************************** IMPORTANT *****************************
  # Cache values can be increased by up to 10% at runtime to avoid having
  # a bunch of variables have their cache expire at the same time and cause
  # hangs due to synchronized reads.  -- merlin
  # **************************** IMPORTANT *****************************

  # by default registers are cached 1h  # CACHE_TIMEOUT_DEFAULT
  $$self{cache_defaultagelimit} = 3600;
  # These are important registers for which we don't want to cache data 1 hour
  # or registers that never change and we cache longer
  # (the rest default to $$self{cache_defaultlifetime})

  # filter reminder, or type of thermostat, and all the programming setpoints is good enough once a day
  foreach my $reg (0x15..0x38, 0x0f, 0x49) {
    $$self{cache_agelimit}{$reg} = 3600 * 24;  # CACHE_TIMEOUT_DAILY
  }
  # setpoints and modes are cached 53 secs so that they are pretty much
  # guaranteed to be updated once a minute even with the random +10% offset
  foreach my $reg (0x3b .. 0x3f) {
    $$self{cache_agelimit}{$reg} = 54;  # CACHE_TIMEOUT_SHORT
  }
  # temperatures and what the stat outputs, we only cache 9 seconds 
  # to allow for 10 sec refresh rate.
  foreach my $reg (0x40, 0x44, 0x48) {
    $$self{cache_agelimit}{$reg} = 9;   # CACHE_TIMEOUT_VERYSHORT
  }

  #The next line is an experiment with http_server.pm to allow other objects to show up in the web interface
  $$self{html_text}       = "<a href=/hai/omnistat_web.pl>Set Thermostat</a>";

  omnistat_debug("Omnistat[$$self{address}] object created");
  bless $self,$class;

  # This is to work around a timing bug where the first query doesn't get a proper ack
  # we just "prime" the device and connection by making one query to it where we ignore the answer
  # no idea why this is needed, but it works for me and things are stable afterwards -- merlin
  $self->{'PRIME'}=1;
  $self->send_cmd("0x01 0x20 0x40 0x01 0x62", 1);
  $self->{'PRIME'}=0;

  return $self;
}

# *************************************
# * Add the checksum to the cmd array.
# *************************************
sub add_checksum {
  my (@array) = @_;
  my @modarr  = @array;
  my $value   = 0;
  foreach (@modarr) {
    s/^0x//g;
    $_     = hex($_);
    $value = $value + $_;
  }
  $value = $value % 256;
  $array[ $#array + 1 ] = sprintf( "0x%02x", $value );
  return @array;
}

# **************************************
# * Send the command to the thermostat.
# **************************************
# I added very basic support of acknowledgments by just checking that we get one byte back that contains 0x80. It is totally
# incomplete, but better than nothing -- merlin
# FIXME?: the spec says we're supposed to listen to the reply, and resend messages after an inter message timeout
# of 1.25s, that said it seems to work ok with the current timings and should work without resends unless your
# serial cable wires are crap (use CAT-5) and/or very long -- merlin
#
# FIXME, 2-3 times, I had this bug right after starting mh:
# 25/07/2009 10:15:30 : Omnistat[2]->read_cached_reg: reg=0x3b not cached, fetching
# 25/07/2009 10:15:30 : Omnistat->send_cmd string=0x02 0x20 0x3b 0x0e 0x6b (with 833325,us reply delay (14 char(s) to read back))
# 25/07/2009 10:15:30 : Omnistat->send_cmd got reply "0xff 0x82 0xf2 0x3b 0x8b 0x64 0x03 0x00 0x00 0x78 0x1e 0x0f 0x0a 0x60 0x00 0x00 0x02 0x00 0xb2 "
# The 0xff in the reply didn't belong. No idea where it came from, especially because it was the first command and reply.
# for now it makes the code die, the command fail and then things restart and continue -- merlin
sub send_cmd {
  # if you want to default to a full 2sec wait, pass '-1' as reply_count
  my ($self, $reply_count, @string) = @_;
  my $addr = $$self{address};
  my $cmd = '';
  # We try to calculate how long we wait for the reply, or default to 2 sec (2M usec)
  my $reply_wait = 2000000;

  # some experimentation shows on my system that we need to wait 0.3sec + 0.1sec for each 3 registers returned --merlin
  # 300bps is 30cps, which does equate to 0.0333333s per character. From experimentation, one needs to wait an extra
  # 11 characters in addition to the payload you're expecting back to get reliable replies (10 almost works but causes
  # occasional corruption due to timings). -- merlin
  # (12+ chars wait instead of 11 might be needed for you. Please increase & let me know if this is too short for you).
  my $REPLY_BASE_DELAY = 11;

  # While we don't get as many bytes as we sent if we were to set several registers in a row (which is not currently
  # supported in this code), the spec says to wait 30ms per register set, so the wait time ends up being able the same
  # when setting data than when polling it.
  $reply_wait = (33333*($reply_count + $REPLY_BASE_DELAY)) if ($reply_count > -1);

  omnistat_debug("Omnistat[$$self{address}]->send_cmd string=@string (with $reply_wait,us reply delay ($reply_count char(s) to read back))");
  foreach my $byte (@string) {
    $byte =~ s/0x//;    # strip off the 0x
    $cmd = $cmd . pack "H2", $byte;    # pack it into 8 bits
  }

  # send it to thermostat
  #omnistat_debug("Omnistat->send_cmd will write $cmd");
  $main::Serial_Ports{Omnistat}{object}->write($cmd);

  # need to wait a bit for the reply
  # FIXME: sleep is bad, especially if you're not using usleep from Time::Hires, the only proper way to do this would be to
  # have a request queue where one command gets processed every 1-2 seconds, but that would be a big rewrite -- merlin
  &Omnistat::omni_sleep($reply_wait);

  # read response
  &main::check_for_generic_serial_data('Omnistat');
  my $temp = $main::Serial_Ports{Omnistat}{data};
  $main::Serial_Ports{Omnistat}{data} = '';
  my $len = length($temp);
  $temp = unpack( "H*", $temp );
  my ($i);
  my $rcvd = '';
  my $ack_byte = 0x80 + $addr;
  for ( $i = 0 ; $i < $len ; $i++ ) {
    $rcvd = $rcvd . sprintf( "0x%s ", substr( $temp, $i * 2, 2 ) );
  }
  my $rcvd_ack = hex(substr($rcvd, 0 , 4));

  if ($self->{'PRIME'})
  {
      omnistat_debug("Omnistat[$$self{address}]->send_cmd skipping error check and return value during prime");
      return;
  }

  # FIXME? Those two dies aren't ideal, but it happens that you get corruption or bad data on a reply.
  # Expected for 01 20 3b 0e 6a is something like
  # 0x81 0xf2 0x3b 0x7c 0x71 0x03 0x00 0x00 0x7d 0x07 0x1e 0x0f 0x00 0x00 0x00 0x02 0x0c 0x5d
  # but I have seen replies like 
  # 0x03 0xf2 0x3b 0x7c 0x71 0x03 0x00 0x00 0x7d 0x00 0x1c 0x0f 0x00 0x00 0x00 0x02 0x0c 0x54  (0x81 ack byte is wrong)
  # or sync issues like
  # 0x64 0x82 0xf2 0x3b 0x8e 0x64 0x00 0x00 0x00 0x7d 0x20 0x29 0x0f 0x60 0x00 0x00 0x00 0x00 0xd6 (0x64 shouldn't be here)
  # On my system, this error only seems to happen soon after startup and doesn't seem to happen later -- merlin
  die "$::Time_Date: Omnistat[$$self{address}]->send_cmd did not get ack reply to command @string ($rcvd)" unless (length($rcvd) > 3);
  die "$::Time_Date: Omnistat[$$self{address}]->send_cmd did not get expected first byte (".sprintf("0x%02x",$ack_byte).") in ack reply to command @string (got ".sprintf("0x%02x", $rcvd_ack)." in $rcvd)" unless ($rcvd_ack eq $ack_byte);
  omnistat_debug("Omnistat[$$self{address}]->send_cmd got reply \"$rcvd\"");

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
  my $wday;
  my $addr = $$self{address};

  omnistat_debug("Omnistat[$$self{address}] -> Setting time/day of week");
  my @cmd = qw(0x01 0x41 0x41);

  #set the time
  $cmd[0] = sprintf( "0x%02x", $addr );
  $cmd[3] = sprintf( "0x%02x", $::Second );
  $cmd[4] = sprintf( "0x%02x", $::Minute );
  $cmd[5] = sprintf( "0x%02x", $::Hour );
  @cmd    = add_checksum(@cmd);
  $self->send_cmd(0, @cmd);

  #set the weekday
  $wday = $::Wday ? $::Wday - 1 : 6;
  $self->set_reg( "0x3a", sprintf( "0x%02x", $wday) );
}

# *******************************************
# * Set the display mode of the thermostat.
# *******************************************
sub display {
  my ($self) = @_;
  my $addr = $$self{address};

  #$main::config_parms{Omnistat_serial_port}
  my $DISPLAY_BITS;
  # Bit 0
  if ( $main::config_parms{Omnistat_celcius} ) {
    $DISPLAY_BITS = 0;
  } else {
    $DISPLAY_BITS = 1;
  }
  # Bit 1
  if ( $main::config_parms{Omnistat_24hr} ) {
    $DISPLAY_BITS = $DISPLAY_BITS + 2;
  }
  # Bit 2
  if ( $main::config_parms{Omnistat_non_program} ) {
    $DISPLAY_BITS = $DISPLAY_BITS + 4;
  }
  # Bit 3
  if ( $main::config_parms{Omnistat_rtp_mode} ) {
    $DISPLAY_BITS = $DISPLAY_BITS + 8;
  }
  # Bit 4
  if ( $main::config_parms{Omnistat_hide_clock} ) {
    $DISPLAY_BITS = $DISPLAY_BITS + 16;
  }

  $self->set_reg( "0x03", sprintf( "0x%02x", $DISPLAY_BITS ) );
}

# *********************************************
# * Create the Omnistat device on serial port.
# *********************************************
sub serial_startup {
  &main::serial_port_create( 'Omnistat', $main::config_parms{Omnistat_serial_port}, 300, 'none', 'raw' );
  &::MainLoop_pre_add_hook( \&Omnistat::check_for_data, 1 );
}

# ********************************
# * Set the hold mode on or off.
# ********************************
sub hold {
  my ( $self, $state ) = @_;
  my $new_hold;
  my $cur_hold = $self->read_cached_reg("0x3f",1);
  $state = lc($state);

  if ( $state eq "off" ) {
    $new_hold = "0x00";
  } elsif ( $state eq "on" ) {
    $new_hold = "0xff";
  } else {
    print "$::Time_Date: Omnistat[$$self{address}]: Invalid Hold state: $state\n";
    return;
  }

  # obviously there is a small race condition here, if hold was changed in the last minute from the panel, 
  # we could fail to set it when it needs to be, but that should be quite rare, and avoiding all the repeated
  # hold set to off before changing other values is worth it -- merlin
  if ($cur_hold ne $new_hold) {
    $self->set_reg( "0x3f", $new_hold );
    omnistat_debug("Omnistat[$$self{address}]->hold: Hold set to $state");
  } else {
    omnistat_debug("Omnistat[$$self{address}]->hold: Hold stays at $state");
  }
}

# *************************************************************
# * Translate Temperature between Fahrenheit/Celcius and Omni values.
# *************************************************************
sub translate_temp {
  my ($settemp) = @_;
  my ($omnitemp);

  # this is a good place to catch a 14 reg read that happens in read_group1 extended, being off by one character, or returning
  # bogus 0's.
  die "$::Time_Date: Omnistat->translate_temp got an input temperature of 0 = -40F/C, this typically means serial port corruption, bad... You may want to increase REPLY_BASE_DELAY" if (not $settemp or $settemp eq "0x00");

  # Calculate conversion mathematically rather than using a table so all temps will work (needed for outside temperature)
  if ( substr( $settemp, 0, 2 ) eq '0x' )
  {    # if it starts with 0x, reverse xlate
    $omnitemp = hex($settemp);
    $omnitemp = -40 + .5 * $omnitemp;    #degrees Celcius
    if ( !( $main::config_parms{Omnistat_celcius} ) ) {
      $omnitemp = 32 + 1.8 * $omnitemp;    # degrees Fahrenheit
      $omnitemp = int( $omnitemp + .5 * ( $omnitemp <=> 0 ) );    #round
    }
  } else {    # xlate from Fahrenheit/Celcius
    if ( !( $main::config_parms{Omnistat_celcius} ) ) {
      $omnitemp = ( $settemp - 32 ) / 1.8;    #Fahrenheit to Celcius
    }
    $omnitemp = ( $omnitemp + 40 ) / .5;                       #omnistat degrees
    $omnitemp = int( $omnitemp + .5 * ( $omnitemp <=> 0 ) );   #round
    $omnitemp = sprintf( "0x%02x", $omnitemp );
  }

  omnistat_debug("Omnistat: Converted $settemp to $omnitemp");
  return $omnitemp;
}

# *************************************************************
# * Translate Time between readable and Omni values.
# *************************************************************
sub translate_time {
  my ($settime) = @_;
  my ( $hours, $minutes, $ampm );
  my ($omnitime);

  if ( substr( $settime, 0, 2 ) eq '0x' ) { #Translate omnitime to readable time
    if ( $settime eq '0x60' )
    {    #if it's set to 24hrs past midnight, time is blank
      $omnitime = '';
    } else {
      $minutes =
        hex($settime) *
        15;    #Omnistat is stored as 15 minute time periods pas midnight
      $hours   = int( $minutes / 60 );
      $minutes = $minutes % 60;          #minutes past hour
      if ( $main::config_parms{Omnistat_24hr} ) {

        #Translate to 24hr time
        $omnitime = sprintf( '%02s:%02s', $hours, $minutes );
      } else {

        #Translate omni to AM/PM
        if ( $hours == 0 ) {
          $hours = 12;
          $ampm  = 'PM';
        } elsif ( $hours > 12 ) {
          $ampm = 'PM';
          $hours -= 12;
        } else {
          $ampm = 'AM';
        }
        $omnitime = sprintf( '%02s:%02s %s', $hours, $minutes, $ampm );
      }
    }
  } else {    #Translate readable to omnistat time
    if ( $settime eq '0' ) { #set to 0 to clear time, or 24:00 if using 24h time
      $omnitime = '0x60';
    } elsif ( $main::config_parms{Omnistat_24hr} ) {
      #convert 24h time
      if ( $settime =~ /^([0-1][0-9]|[2][0-4]):([0-5][0-9])$/ ) {

        #valid time
        $hours    = $1;
        $minutes  = $2;
        $minutes  = $minutes + $hours * 60;
        $omnitime = $minutes / 15;
        $omnitime = sprintf( "0x%02x", $omnitime );
      } else {
        #invalid time
        $omnitime = '';
      }
    } else {
      #convert am/pm time
      if ( $settime =~ /^(1[0-2]|0?[1-9]):([0-5][0-9]) *(AM|PM)$/ ) {

        #valid time
        $hours   = $1;
        $minutes = $2;
        $ampm    = $3;

        #PM we may need to add 12 hours (unless it's midnight), AM is already right
        if ( $ampm eq 'PM' ) {
          if ( $hours == 12 ) {
            $hours = 0;
          } else {
            $hours = $hours + 12;
          }
        }

        $minutes  = $minutes + $hours * 60;
        $omnitime = $minutes / 15;

        $omnitime = sprintf( "0x%02x", $omnitime );
      } else {
        #invalid time
        $omnitime = '';
      }
    }
  }

  return $omnitime;
}

# *****************************************************
# * Read and convert the bits in reg 0x48 (HVAC output)
# *****************************************************
sub translate_stat_output {
  my ( $self, $reg48 ) = @_;

  die "Omnistat::translate_stat_output got non hex value in $reg48" unless (is_hex($reg48));
  # see reg 0x48 / output register at the top of this file
  my $output = "off";
  $output = "fan" if (hex($reg48) & 8);

  # if stage 1 and stage 2 heat/cool are off, return here
  #&::print_log("pass1: reg48: $reg48, $output");
  return $output if (not hex($reg48) & (4+16));

  $output .= "/auxheat" if (hex($reg48) & 2);

  $output .= (hex($reg48) & 1) ? "/heat" : "/cool";
  $output .= "/stage2" if (hex($reg48) & 16);
  #&::print_log("pass2: reg48: $reg48, $output");
  return $output;
}


# *****************************************************************
# * Change the mode of the thermostat between off/auto/heat/cool.
# *****************************************************************
sub mode {
  my ( $self, $state ) = @_;
  $state = lc($state);

  #TODO: Should heat/cool/auto turn on hold?

  omnistat_debug("Omnistat[$$self{address}] -> Mode $state");
  my $addr = $$self{address};
  my @cmd;
  if ( $state eq "off" ) {
    $self->set_reg( "0x3d", "0x00" );
  } elsif ( $state eq "heat" ) {
    $self->set_reg( "0x3d", "0x01" );
  } elsif ( $state eq "cool" ) {
    $self->set_reg( "0x3d", "0x02" );
  } elsif ( $state eq "auto" ) {
    $self->set_reg( "0x3d", "0x03" );
  } elsif ( $state eq "program_heat" ) {
    $self->set_reg( "0x3d", "0x03" );
    $self->set_reg( "0x3f", "0x00" );
  } elsif ( $state eq "program_cool" ) {
    $self->set_reg( "0x3d", "0x03" );
    $self->set_reg( "0x3f", "0x00" );
  } elsif ( $state eq "program_auto" ) {
    $self->set_reg( "0x3d", "0x03" );
    $self->set_reg( "0x3f", "0x00" );
  } else {
    print "$::Time_Date: Omnistat: Invalid Mode state: $state\n";
  }
}

# **************************
# * Restore the heat and cool setpoints to what they would be if the schedule were in effect
# **************************
sub restore_setpoints {
  my ($self) = @_;
  my $point = 0;
  my $time;
  my $day;
  my $register;
  my $setpointnum;
  my $daynum;

  # this does not work if the stat is in hold mode, and we assume that calling this means we want
  # to un-hold
  $self->hold("off");

  # This touches a lot of registers, so it's quicker to cache them all once.
  # Unfortunately, we can only read 14 registers at a time, so we'll read 3x12
  # We don't store the result, this is just to prime the cache in case it wasn't.
  $self->read_cached_reg("0x15", 12);
  $self->read_cached_reg("0x21", 12);
  $self->read_cached_reg("0x2d", 12);

  #Determine the day (weekday,sat,sun)
  $day = $::Wday ? $::Wday - 1 : 6;

  #Determine the time
  $time =
    ( $::Hour * 4 ) + ( $::Minute / 15 ) + ( $::Second / 60 );  #Omnistat time

  #Determine the day
  if ( $day == 6 ) {	    # Sunday
    $register = 0x36;	    # Sunday night time
  } elsif ( $day == 5 ) {   # Saturday
    $register = 0x2a;	    # Saturday night time
  } else {		    # Weekday
    $register = 0x1e;	    # Weekday night time
  }
  
  # Check for setpoints for that day, need to consider what time it is
  for ( $setpointnum = 0 ; $setpointnum < 4 ; $setpointnum++ ) {
    # FIXME: make sure I didn't break this (test it) and remove my FIXME -- merlin
    if ( hex($self->read_cached_reg( sprintf( "0x%02x", $register - 3 * $setpointnum))) < $time ) {
      $point = $register - 3 * $setpointnum;
      last;
    }
  }
  
  #Check for setpoints on previous days, don't need to consider the time, any setpoint will do
  if ( $point == 0 ) {

    #Loop days
    for ( $daynum = 0 ; $daynum < 3 ; $daynum++ ) {
      if ($day > 0 && $day < 5 && $daynum == 0) { 
        #Weekday, previous day is also a weekday for first loop          
      }
      else {
        #Get the previous day
        $register = $register - 12;    
      }
      
      if ( $register < 30 ) { $register = 54; } #Previous to weekday is sunday
      
      #Loop setpoints
      for ( $setpointnum = 0 ; $setpointnum < 4 ; $setpointnum++ ) {
        # FIXME: make sure I didn't break this (test it) and remove my FIXME -- merlin
        if ( hex($self->read_cached_reg( sprintf( "0x%02x", $register - 3 * $setpointnum))) != 96 )
        {
          #If the setpoint has a time set, use the setpoint 
          $point = $register - 3 * $setpointnum;
          last;
        }
      }
    }
  }
  
  if ( $point != 0 ) {
    my $heat_sp = $self->read_cached_reg( sprintf( "0x%02x", $point + 2));
    my $cool_sp = $self->read_cached_reg( sprintf( "0x%02x", $point + 1));

    # FIXME: make sure I didn't break this (test it) and remove my FIXME -- merlin
    # Set the setpoints (setting the registers avoids converting the temp only to convert it back)
    print "$::Time_Date: Omnistat: Heat Set to " . &Omnistat::translate_temp($heat_sp) . "\n";
    print "$::Time_Date: Omnistat: Cool Set to " . &Omnistat::translate_temp($cool_sp) . "\n";
    $self->set_reg( "0x3c", $heat_sp );
    $self->set_reg( "0x3b", $cool_sp );
  }
}



# ************************************
# * Set the fan mode to on/off/auto.
# ************************************
sub fan {
  my ( $self, $state ) = @_;
  $state = lc($state);
  my $addr = $$self{address};
  my @cmd;

  omnistat_debug("Omnistat[$$self{address}] -> Fan $state");
  if ( $state eq "on" ) {
    $self->set_reg( "0x3e", "0x01" );
  } elsif ( $state eq "auto" ) {
    $self->set_reg( "0x3e", "0x00" );
  } else {
    print "$::Time_Date: Omnistat: Invalid Fan state: $state\n";
  }
}

# **************************
# * Set the cool setpoint.
# **************************
sub cool_setpoint {
  my ( $self, $settemp ) = @_;
  # hold has to be removed for this command to go through.
  $self->hold('off');
  $self->set_reg( "0x3b", &Omnistat::translate_temp($settemp) );
  $self->hold('on') unless $main::config_parms{Omnistat_set_does_not_hold};
}

# **************************
# * Set the heat setpoint.
# **************************
sub heat_setpoint {
  my ( $self, $settemp ) = @_;
  # hold has to be removed for this command to go through.
  $self->hold('off');
  $self->set_reg( "0x3c", &Omnistat::translate_temp($settemp) );
  $self->hold('on') unless $main::config_parms{Omnistat_set_does_not_hold};
}

# **************************************
# * Set the outdoor temperature
# **************************************
sub outdoor_temp {
  my ( $self, $settemp ) = @_;
  $self->set_reg( "0x44", &Omnistat::translate_temp($settemp) );
}

# *******************************
# * Set the heating cycle time.
# *******************************
sub heating_cycle_time {
  my ( $self, $time ) = @_;
  omnistat_debug("Omnistat[$$self{address}] -> Heat cycle time $time");
  $self->set_reg( "0x0c", sprintf( "0x%02x", $time ) );
}

# *******************************
# * Set the cooling cycle time.
# *******************************
sub cooling_cycle_time {
  my ( $self, $time ) = @_;
  omnistat_debug("Omnistat[$$self{address}] -> Cool cycle time $time");
  $self->set_reg( "0x0b", sprintf( "0x%02x", $time ) );
}

# **************************************
# * Set the cooling anticipator time.
# **************************************
sub cooling_anticipator {
  my ( $self, $value ) = @_;
  omnistat_debug("Omnistat[$$self{address}] -> Cooling Anticipator $value");
  $self->set_reg( "0x09", sprintf( "0x%02x", $value ) );
}

# **************************************
# * Set the heating anticipator time.
# **************************************
sub heating_anticipator {
  my ( $self, $value ) = @_;
  omnistat_debug("Omnistat[$$self{address}] -> Heating Anticipator $value");
  $self->set_reg( "0x0a", sprintf( "0x%02x", $value ) );
}

# **************************************
# * Get the indoor temperature
# **************************************
sub get_temp {
  my ( $self) = @_;
  my $temp = $self->read_cached_reg("0x40",1);
  my $translated = translate_temp($temp);
  return translate_temp($temp);
}

# ********************************************************
# * Get the current command output by the stat to the HVAC
# ********************************************************
sub get_stat_output {
  my ( $self ) = @_;
  my $reg48 = hex( $self->read_cached_reg("0x48",1) );

  return $self->translate_stat_output($reg48);
}

# **************************************
# * Get the heat setpoint
# **************************************
sub get_heat_sp {
  my ( $self) = @_;
  my $temp = $self->read_cached_reg("0x3c",1);
  return translate_temp($temp);
}

# **************************************
# * Get the cool setpoint
# **************************************
sub get_cool_sp {
  my ( $self) = @_;
  my $temp = $self->read_cached_reg("0x3b",1);
  return translate_temp($temp);
}

# **************************************
# * Get the mode
# **************************************
sub get_mode {

  # system mode to argument: 'off', 'heat', 'cool', 'auto','program_heat', 'program_cool', 'program_auto'
  my ( $self ) = @_;
  my $mode = $self->read_cached_reg("0x3d",1);
  my $hold = $self->read_cached_reg("0x3f",1);  

  $hold = $hold eq "0x00" ? 'off' : 'on';
  
  # if hold is off, mode is program heat/cool/auto, if hold is on, mode is heat/cool/auto
  if ($hold eq 'on') 
  {
    $mode = ['off', 'heat', 'cool', 'auto']->[hex($mode)];
  } else  {
    $mode = ['off', 'program_heat', 'program_cool', 'program_auto']->[hex($mode)];
  }
  
  return $mode;
}

# **************************************
# * Get the fan mode
# **************************************
sub get_fan_mode {
  my ( $self ) = @_;
  my $fan = $self->read_cached_reg("0x3e",1);
  if ( $fan  eq "0x00" ) { $fan  = 'auto'; }
  if ( $fan  eq "0x01" ) { $fan  = 'on'; }
  
  return $fan;
}

# **************************************
# * Get the filter reminder
# **************************************
sub get_filter_reminder {
  my ( $self ) = @_;
  my $days = $self->read_cached_reg("0x0f",1);
  return hex($days);
}

# **************************************
# * Get and translate type of thermostat
# **************************************
sub get_stat_type {
  my ( $self ) = @_;
  
  my $stat = $self->read_cached_reg("0x49",1);
  my %stat_table = ( 0  => "RC-80",
		     1  => "RC-81",
		     8  => "RC-90",
		     9  => "RC-91",
		     16 => "RC-100",
		     17 => "RC-101",
		     34 => "RC-112",
		     48 => "RC-120",
		     49 => "RC-121",
		     50 => "RC-122", );

  return $stat_table{hex($stat)} ? $stat_table{hex($stat)} : "RC-unknown";
}

# **************************************
# * Get the run time for this week (in hours)
# **************************************
sub get_run_time_this_week {
  my ( $self ) = @_;
  my $hours = $self->read_cached_reg("0x10",1);
  return hex($hours);
}

# **************************************
# * Get the run time for last week (in hours)
# **************************************
sub get_run_time_last_week {
  my ( $self) = @_;
  my $hours = $self->read_cached_reg("0x11",1);
  return hex($hours);
}

# *********************************************
# * Read specified register(s) from Omnistat.
# *********************************************
sub read_reg {
  # register MUST be an hex STRING (i.e. "0x21", not 0x21)
  # I added a $whitelisted param to strongly hint that people use the caching call instead
  # but you can force a non caching call by just adding the whitelisted flag in the caller
  # yes, $count isn't optional anymore, sorry (but it is optional in read_cached_reg) -- merlin
  my ( $self, $register, $count, $whitelisted ) = @_;
  my $addr = $$self{address};
  my ( @cmd, $regraw, $reg, $byte, $cnt );
  my $i;
  my @value;

  die "Omnistat::read_reg got non hex value in $register" unless (is_hex($register));
  warn "You should call read_cached_reg instead of read_reg to avoid hang delays. Adjust CACHE_TIMEOUT_ values in new(), and/or set debug=omnistat in mh.private.ini to adjust caching" if (not $whitelisted);
  die "You can only read 14 registers at a time, you asked for $count" if ($count >14);

  $count = 1 if (not $count);

  $cmd[0] = sprintf( "0x%02x", $addr );
  $cmd[1] = "0x20";
  $cmd[2] = $register;
  $cmd[3] = sprintf( "0x%02x", $count );
  @cmd    = add_checksum(@cmd);
  $regraw = $self->send_cmd($count, @cmd);
  $reg = substr( $regraw, 15, $count * 5 );
  die "Omnistat[$$self{address}]->read_reg: got empty response to @cmd (read $count regs from register offset $register), serial port send/read probably failed, check your configuration or you may have a timing issue and may need to increase REPLY_BASE_DELAY" if (not $reg);

  omnistat_debug("Omnistat[$$self{address}]->read_reg: reg[$register]=$reg");

  # Cache the value(s)
  @value = split ' ', $reg;
  for ( $i = 0 ; $i < $count ; $i++ ) {
    die "Omnistat[$$self{address}]->read_reg: got partial response to @cmd (read $count from $register), response truncated at byte $i. You may have a timing issue and may need to increase REPLY_BASE_DELAY" if (not $value[$i]);

    my $regoffset = sprintf( "0x%02x", hex($register) + $i);

    # see if we have it cached
    if (exists $$self{cache}{hex($regoffset)})
    {
      # see if it changed
      if ($$self{cache}{hex($regoffset)} ne $value[$i])
      {
        omnistat_debug("Omnistat[$$self{address}]->read_reg: reg[$regoffset]=$value[$i] updated in cache");
	# Update the cache
	$$self{cache}{hex($regoffset)} = $value[$i];

        # see if it's a register we care about and register state change if so
        if ($regoffset eq "0x40") {
          $self->set_receive('temp_change');
        } elsif ($regoffset eq "0x3b") {
          $self->set_receive('cool_sp_change');
        } elsif ($regoffset eq "0x3c") {
          $self->set_receive('heat_sp_change');
        } elsif ($regoffset eq "0x3d") {
          $self->set_receive('mode_change');
        } elsif ($regoffset eq "0x3f") {
          $self->set_receive('hold_change');
        } elsif ($regoffset eq "0x3e") {
          $self->set_receive('fan_mode_change');
        } elsif ($regoffset eq "0x48") {  # this one is read only
          $self->set_receive('current_output_change');
        } elsif ($regoffset eq "0x0f") {
          if ($value[$i] eq "0x00") {
            $self->set_receive('filter_reminder');
          }
        }
      } else {
        omnistat_debug("Omnistat[$$self{address}]->read_reg: reg[$regoffset]=$value[$i] current in cache");
      }
    } else {
      # Set the cache
        omnistat_debug("Omnistat[$$self{address}]->read_reg: reg[$regoffset]=$value[$i] added to cache");
      $$self{cache}{hex($regoffset)} = $value[$i];
    }

    # keep track of when the cache was updated to know how fresh it is
    $$self{cache_updatetime}{hex($regoffset)} = time;
  }

  return $reg;
}


# *********************************************
# * Write specified register to Omnistat.
# *********************************************
#TODO: add ability to set multiple registers at once
sub set_reg {
  # register MUST be an hex STRING (i.e. "0x21", not 0x21)
  my ( $self, $register, $value ) = @_;
  my $addr = $$self{address};
  my (@cmd);

  die "Omnistat::set_reg got non hex value in $register <- $value" unless (is_hex($register) and is_hex($value));
  $cmd[0] = sprintf( "0x%02x", $addr );
  $cmd[1] = "0x21";
  $cmd[2] = $register;
  $cmd[3] = $value;
  @cmd    = add_checksum(@cmd);
  $self->send_cmd(0, @cmd);

  # Check for state change
  if (exists $$self{cache}{ hex($register) })
  {
    if ($$self{cache}{ hex($register) } ne $value)
    {
      # TODO, merge with above, prevent duplication
      # register changed, check for state change
      if ($register eq "0x40") {
        $self->set_receive('temp_change');
      } elsif ($register eq "0x3b") {
        $self->set_receive('cool_sp_change');
      } elsif ($register eq "0x3c") {
        $self->set_receive('heat_sp_change');
      } elsif ($register eq "0x3d") {
        $self->set_receive('mode_change');
      } elsif ($register eq "0x3f") {
        $self->set_receive('hold_change');
      } elsif ($register eq "0x3e") {
        $self->set_receive('fan_mode_change');
      } elsif ($register eq "0x0f") {
        if ($value eq "0x00") {
          $self->set_receive('filter_reminder');
        }
      }
    }
  }

  # Update the cache
  $$self{cache}{ hex($register) } = $value;
  # keep track of when the cache was updated to know how fresh it is
  $$self{cache_updatetime}{ hex($register) } = time;
}


# *********************************************
# * Read specified register from Cache.
# * Note: there is no limit to the number of registers you can read
# *********************************************
sub read_cached_reg {
    # register MUST be an hex STRING (i.e. "0x21", not 0x21)
    # maxcachetime is optional, and lets you override the CACHE_TIMEOUT_* values on
    # how old the data can be in seconds before fresh data is fetched.
    # You can pass 1 to get fresh data every second, or 0 to get new data every time
    my ( $self, $register, $count, $maxcachetime ) = @_;
    my $value;
    my $regval;

    die "Omnistat::read_cached_reg got non hex value in $register" unless (is_hex($register));
    $count = 1 if (not $count);

    # First see if we can read from the cache
    for ( my $i = 0 ; $i < $count ; $i++ ) {
	undef $regval;
        my $regoffset = sprintf( "0x%02x", hex($register) + $i);

	# see if it exists in the cache
	if (exists $$self{cache}{hex($regoffset)}) {
	    my $cache_age = time - $$self{cache_updatetime}{hex($regoffset)};
	    my $age_limit = exists $$self{cache_agelimit}{hex($regoffset)} ? $$self{cache_agelimit}{hex($regoffset)} : $$self{cache_defaultagelimit};

	    $age_limit = $maxcachetime if (defined $maxcachetime);
	    # Raise the age_limit by a random 10% so that if you query a lot of separate non contiguous registers
	    # you don't get hit by all of their caches expiring at the same time, which would cause a lot of pauses
	    # in the same master loop pass, which would be bad.
	    $age_limit += int($age_limit * rand(0.1));

	    if ( $cache_age <= $age_limit) {
		$regval = $$self{cache}{hex($regoffset)};
		omnistat_debug("Omnistat[$$self{address}]->read_cached_reg: fetched reg=$regoffset from cache ($cache_age <= $age_limit)");
	    } else {
		omnistat_debug("Omnistat[$$self{address}]->read_cached_reg: reg=$regoffset STALE in cache ($cache_age > $age_limit), fetching");
	    }
	} else {
	    omnistat_debug("Omnistat[$$self{address}]->read_cached_reg: reg=$regoffset not cached, fetching");
	}

	# exit loop that builds from cache if any value is stale
	last if (not defined $regval);

	# don't prefix the first value with space
	if ($i > 0) {
	    $value = $value . ' ' . $regval;
	} else {
	    $value = $regval;
	}
    }

    # if one cache value was stale, retrieve the whole list now
    $value = $self->read_reg($register, $count, "true") if (not defined $regval);

    omnistat_debug("Omnistat[$$self{address}]->read_cached_reg: reg=$register count=$count value=$value");

    return $value;
}


# ************************************
# * Read Group 1 data from Omnistat.
# * Note that this only queries the cached values now but see below
# ************************************

# plus_output if true, will also fetch the output register by extending the
# query to 14 registers (adds 0.2 seconds to the reply) instead of 6.

# maxcachetime is optional, and lets you override the CACHE_TIMEOUT_* values on
# how old the data can be in seconds before fresh data is fetched.
# You can pass 1 to get fresh data every second, or 0 to get new data every time
sub read_group1 {
  my ($self, $plus_output, $maxcachetime) = @_;
  my $addr = $$self{address};
  my (
    @cmd,      $group1,   $output,
    $cool_set, $heat_set, $mode,      $fan, $hold, $cur,
  );

  # This is the official way to read group1, but it misses the processing we do
  # in read_reg while only saving 2 bytes to send, which is neglible, even at 300bps
  # (around 0.07sec), so let's gateway back to read_reg("0x3b", 6) -- merlin
  #  $cmd[0]    = sprintf( "0x%02x", $addr );
  #  $cmd[1]    = "0x02";
  #  @cmd       = add_checksum(@cmd);
  #  $group1raw = $self->send_cmd(6, @cmd);


  if ($plus_output) {
    $group1 = $self->read_cached_reg("0x3b", 14, $maxcachetime);
    ( $cool_set, $heat_set, $mode, $fan, $hold, $cur, $_, $_, $_, $_, $_, $_, $_, $output ) = split(' ', $group1);
    $output = $self->translate_stat_output($output);
  } else {
    $group1 = $self->read_cached_reg("0x3b", 6, $maxcachetime);
    ( $cool_set, $heat_set, $mode, $fan, $hold, $cur ) = split(' ', $group1);
    $output = '[not queried]';
  }

  $cool_set = &Omnistat::translate_temp($cool_set);
  $heat_set = &Omnistat::translate_temp($heat_set);

  $mode = ['off', 'heat', 'cool', 'auto']->[hex($mode)];
  $fan = $fan eq "0x00" ? 'auto' : 'on';
  $hold = $hold eq "0x00" ? 'off' : 'on';

  $cur = &Omnistat::translate_temp($cur);

  omnistat_debug("Omnistat[$$self{address}]->read_group1:$cool_set,$heat_set,$mode,$fan,$hold,$cur,$output");
  return ( $cool_set, $heat_set, $mode, $fan, $hold, $cur, $output );
}

sub read_cached_group1 {
    die "read_cached_group1 is obsolete, use read_group1 instead";
}


1;
