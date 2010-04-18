=begin comment

Owfs_Item.pm 

03/10/2007 Created by Jim Duda (jim@duda.tzo.com)

Use this module to interface with the OWFS (one-wire filesystem) software.
The OWFS software handles all the real-time processing of the one-wire itself,
offering a simple PERL API interface.

Requirements:

 Download and install OWFS
 http://www.owfs.org

Setup:

In your code module, instantation the Owfs_Item class to interface with some
one-wire element.  The one-wire device can be found using the OWFS html interface.

configure mh.privite.ini

owfs_port = 3030    # defined port where the owfs server is listening

Example Usage:

 $item = new Owfs_Item ( "<device_id>", <location>, <port>, <channel> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <port>      - used for devices with multiple ports
 <channel>   - used for devices with multiple channels 

 $frontDoorBell = new Owfs_Item ( "12.487344000000", "Front DoorBell", undef, "A");
 $sensor        = new Owfs_Item ( "05.4D212A000000");

 Owfs_Item can be used as a baseclass and extended for specific one wire devices.
 For example, refer to Owfs_DS2450.pm which describes a one wire A/D device.

 Any of the fields in the one-wire device can be access via the set and get methods.

 $sensor->set ("power", 1 );
 $sensor->get ("alarm");

=cut

#=======================================================================================
#
# Generic Owfs_Item
#
# Owfs_Item should handle any Owfs device, and provides access to any individual field.
#
#=======================================================================================

package Owfs_Item;

@Owfs::ISA = ('Generic_Item');

use OW;

my (%objects_by_id);

sub new {
    my ($class, $device, $location, $port, $channel) = @_;
    my $self = { };
    bless $self,$class;
    $device =~ /(.*)\.(.*)/;
    my $family = $1;
    my $id = $2;
    $self->{device}   = $device;
    $self->{location} = $location;
    $self->{port}     = $port;
    $self->{channel}  = $channel;
    $self->{root}     = &_find ( $family, $id, 0, "/" );
    $self->{path}     = $self->{root} . $family . "." . $id . "/";
    if (defined $self->{path}) {
      $objects_by_id{path} = $self;
      &_load ( $self, $self->{path} );
    }
    $$self{state}     = '';     # Will only be listed on web page if state is defined
    if ($self->{type} eq 'DS2405' ) {
        push(@{$$self{states}}, 'on', 'off');
    }

    &dump ( $self ) if ($main::Debug{owfs});

    # Initialize the OWFS perl interface ( server tcp port )
    my $port = 3030;
    $port = "$main::config_parms{owfs_port}" if exists $main::config_parms{owfs_port};
    &main::print_log ("Owfs_Item:: Initializing port: $port $location") if $main::Debug{owfs};
    OW::init ( "$port" );

    return $self;
}

sub set {
     my ($self, $token, $data) = @_;
     my $path = $self->{path} . $token;
     &main::print_log ("Owfs_Item::set $path $data") if $main::Debug{owfs};
     my $result = OW::put($path, "$data") or return ;
     return $result;
}

sub set_root {
     my ($self, $token, $data) = @_;
     my $path = $self->{root} . $token;
     &main::print_log ("Owfs_Item::set_root $path $data") if $main::Debug{owfs};
     my $result = OW::put($path, "$data" ) or return ;
     return $result;
}

sub get {
     my ($self, $token) = @_;
     my $path = $self->{path} . $token;
     my $result = OW::get($path) or return ;
     &main::print_log ("Owfs_Item::get $path $result") if $main::Debug{owfs};
     return $result;
}

sub get_root {
     my ($self, $token) = @_;
     my $path = $self->{root} . $token;
     my $result = OW::get($path) or return ;
     &main::print_log ("Owfs_Item::get_root $path $result") if $main::Debug{owfs};
     return $result;
}

sub set_key {
     my ($self, $key, $data) = @_;
     $self->{$key} = $data;
}

sub get_key {
     my ($self, $key) = @_;
     return ($self->{$key});
}

sub get_device {
     my ($self) = @_;
     return $self->{device};
}

sub get_location {
     my ($self) = @_;
     return $self->{location};
}

sub dump {
  my $self = shift;
  &main::print_log ( "\n") if $main::Debug{owfs};
  &main::print_log ( "root: \t\t$$self{root}\n") if $main::Debug{owfs};
  &main::print_log ( "path: \t\t$$self{path}\n") if $main::Debug{owfs};
  &main::print_log ( "family: \t$$self{family}\n") if $main::Debug{owfs};
  &main::print_log ( "id: \t\t$$self{id}\n") if $main::Debug{owfs};
  &main::print_log ( "type: \t\t$$self{type}\n") if $main::Debug{owfs};

  for my $key (sort keys %$self) {
    next if ($key eq "root");
    next if ($key eq "path");
    next if ($key eq "family");
    next if ($key eq "id");
    next if ($key eq "type");
    &main::print_log ( "$key:\t\t$$self{$key}\n") if $main::Debug{owfs};
  }
  &main::print_log ( "\n") if $main::Debug{owfs};
}

sub _find {
  my ($family, $id,$lev,$path) = @_;
  my $result = OW::get($path) or return ;
#  &main::print_log ( "_find:: family: $family id: $id lev: $lev path: $path\n") if $main::Debug{owfs};
  my @tokens = split(',',$result);
  foreach my $token (@tokens) {
    if ( $token =~ /\/$/ ) {
      $token =~ /(.+)\.(.+)\/$/;
      if (($family eq $1) && ($id eq $2)) {
        return ( $path );
      } elsif (($1 eq "1F") || ($token =~ /aux\/$/) || ($token =~ /main\/$/)) {
        my $val = &_find ($family, $id, $lev+1, $path.$token);
        if ( defined $val ) {
          return ( $val );
        }
      }
    }
  }
  return undef;
}

sub _load {
  my ($self, $path) = @_;
#  &main::print_log ( "_load:: path: $path\n") if $main::Debug{owfs};
  my $result = OW::get($path) or return ;
  my @tokens = split(',',$result);
  foreach my $token (@tokens) {
    $self->{$token} = OW::get($path.$token);
  }
}

sub _remove {
  my $self = shift;
  for my $key (keys %$self) {
    delete $$self{$key};
  }
}

#=======================================================================================
#
# Owfs_DS18S20
#
# This package specifically handles the DS18S20 Thermometer
#
#=======================================================================================

=begin comment

Usage:

 $sensor = new Owfs_DS18S20 ( "<device_id>", <location>, <interval> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <interval>  - seconds between acquisitions

 Example:

 $ds18S20 = new Owfs_DS18S20 ( "10.DB2506000000", "Living Room", 2 );
 
 my $temperature = get_temperature $ds18S20;

=cut

use strict;

package Owfs_DS18S20;

@Owfs_DS18S20::ISA = ('Owfs_Item');

sub new {
    my ($class, $ds18S20, $location, $interval) = @_;
    my $self = new Owfs_Item ( $ds18S20, $location );
    bless $self,$class;

    $interval = 10 unless $interval;
    $interval = 10 if ($interval < 10);
    $self->{interval} = $interval;

    $self->{timer} = new Timer;
    $self->{timer}->set($self->{interval}, sub {&Owfs_DS18S20::run_loop($self)});
    $self->{temperature} = 0;
    $self->{index} = 0;
    return $self;
}

sub get_temperature {
  my $self = shift;
  return ($self->{temperature});
}

sub state {
  my $self = shift;
  return ($self->{temperature});
}

sub run_loop {
  my $self = shift;
  my $index = $self->{index};
  &main::print_log ( "Owfs_DS18S20:: index: $index") if $main::Debug{owfs};

  # issue simultaneous to start a conversion
  if ($self->{index} == 0) {
    $self->set_root ( "simultaneous/temperature", "1" );
  } else {
    $self->{temperature} = $self->get ( "temperature");
    $self->SUPER::set($$self{temperature});
    &main::print_log ("Owfs_DS18S20 temperature: $$self{temperature}") if $main::Debug{owfs};
  }

  # udpate the index
  $self->{index} += 1;
  if ($self->{index} >= 2) {
    $self->{index} = 0;
  }

  # reschedule the timer for next pass
  $self->{timer}->set($self->{interval}, sub {&Owfs_DS18S20::run_loop($self)});
}

#=======================================================================================
#
# Owfs_DS2450
#
# This package specifically handles the DS2450 A/D Converter.
#
#=======================================================================================

=begin comment

Usage:

 $sensor = new Owfs_DS2450 ( "<device_id>", <location>, <channel>, <interval> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <channel>   - "A", "B", "C", or "D"
 <interval>  - seconds between acquisitions

 Example:

 $ds2350 = new Owfs_DS2350 ( "20.DB2506000000", "Furnace Sensor", "A", 2 );
 
 my $voltage = get_voltage $ds2350;

=cut

use strict;

package Owfs_DS2450;

@Owfs_DS2450::ISA = ('Owfs_Item');

sub new {
    my ($class, $ds2450, $location, $channel, $interval) = @_;
    my $self = new Owfs_Item ( $ds2450, $location );
    bless $self,$class;

    $interval = 10 unless $interval;
    $interval = 10 if ($interval < 10);
    $self->{interval} = $interval;

    $self->{timer} = new Timer;
    $self->{timer}->set($self->{interval}, sub {&Owfs_DS2450::run_loop($self)});

    $self->{channel} = $channel;

    $self->set ( "set_alarm/voltlow.$channel", "1.0" );
    $self->set ( "set_alarm/low.$channel", "1" );
    $self->set ( "power", "1" );
    $self->{voltage} = 0;

    $self->{index} = 0;

    return $self;
}

sub get_voltage {
  my $self = shift;
  return ($self->{voltage});
}

sub run_loop {
  my $self = shift;
  my $channel = $self->{channel};
  my $index = $self->{index};
  &main::print_log ( "Owfs_DS2450:: channel: $channel index: $index") if $main::Debug{owfs};

  # issue simultaneous to start a conversion
  if ($self->{index} == 0) {
    $self->set_root ( "simultaneous/voltage", "1" );
  } else {
    my $token = "alarm/volt.$channel";
    my $voltage = $self->get ( "volt.$channel");
    $self->{voltage} = $voltage;
    &main::print_log ("Owfs_DS2450 $channel $token volt: $voltage") if $main::Debug{owfs};
    my $token = "alarm/low.$channel";
    my $trigger = $self->get ( $token );
    &main::print_log ("Owfs_DS2450 $channel $token alarm low: $trigger") if $main::Debug{owfs};
  }

  # udpate the index
  $self->{index} += 1;
  if ($self->{index} >= 2) {
    $self->{index} = 0;
  }

  # reschedule the timer for next pass
  $self->{timer}->set($self->{interval}, sub {&Owfs_DS2450::run_loop($self)});
}

1;

__END__

Got this from the tini@ibutton.com list on 3/00:

Field Index:
------------
(1) Family code in hex
(2) Number of regular memory pages
(3) Length of regular memory page in bytes
(4) Number of status memory pages
(5) Length of status memory page in bytes
(6) Max communication speed (0 regular, 1 Overdrive)
(7) Memory type (see below)
(8) Part number in iButton package
(9) Part number in non-iButton package
(10) Brief descriptions

(1)   (2)  (3)  (4)  (5)  (6)  (7)   (8)   (9)   (10)
-------------------------------------------------------
01,    0,   0,   0,   0,   1,   0, DS1990A,DS2401,Unique Serial Number
02,    0,   0,   0,   0,   0,   0, DS1991,DS1205, MultiKey iButton
04,   16,  32,   0,   0,   0,   1, DS1994,DS2404,4K-bit NVRAM with Clock
05,    0,   0,   0,   0,   0,   0, DS2405,,Single Addressable Switch
06,   16,  32,   0,   0,   0,   1, DS1993,DS2403,4K-bit NVRAM
08,    4,  32,   0,   0,   0,   1, DS1992,DS2402,1K-bit NVRAM
09,    4,  32,   1,   8,   1,   2, DS1982,DS2502,1K-bit EPROM
0A,   64,  32,   0,   0,   1,   1, DS1995,DS2416,16K-bit NVRAM
0B,   64,  32,  40,   8,   1,   3, DS1985,DS2505,16K-bit EPROM
0C,  256,  32,   0,   0,   1,   1, DS1996,DS2464,64K-bit NVRAM
0F,  256,  32,  64,   8,   1,   3, DS1986,DS2506,64K-bit EPROM
10,    0,   0,   0,   0,   0,   0, DS1920,DS1820,Temperature iButton with
Trips
11,    2,  32,   1,   8,   0,   2, DS1981,DS2501,512-bit EPROM
12,    4,  32,   1,   8,   0,   4, DS2407,,Dual Addressable Switch
13,   16,  32,  34,   8,   0,   3, DS1983,DS2503,4K-bit EPROM
14,    1,  32,   0,   0,   0,   5, DS1971,DS2430A,256-bit EEPROM, plus
64-bit
OTP
15,    0,   0,   0,   0,   1,   0, DS87C900,,Lock Processor
16,    0,   0,   0,   0,   0,   0, DS1954,,Crypto iButton
18,    4,  32,   0,   0,   1,   6, DS1963S,4K-bit Transaction iButton with
SHA
1A,   16,  32,   0,   0,   1,   6, DS1963,,4K-bit Transaction iButton
1C,    4,  32,   0,   0,   1,   6, DS2422,,1K-bit EconoRAM with Counter
Input
1D,   16,  32,   0,   0,   1,   6, DS2423,,4K-bit EconoRAM with Counter
Input
1F,    0,  32,   0,   0,   0,   0, DS2409,,One-Wire Net Coupler
20,    3,   8,   0,   0,   1,   9, DS2450,,Quad A-D Converter
21,   16,  32,   0,   0,   1,   8, DS1921,,Temperature Recorder iButton
23,   16,  32,   0,   0,   1,   7, DS1973,DS2433,4K-bit EEPROM
40,   16,  32,   0,   0,   0,   1, DS1608,,Battery Pack Clock


Memory Types:
--------------
0 NOMEM - no user storage space or with
          non-standard structure.
1 NVRAM - non-volatile rewritable RAM.
2 EPROM1- EPROM (OTP).
          Contains an onboard 8-bit CRC data check.
3 EPROM2 - EPROM (OTP). TMEX Bitmap starting on status page 8
           Contains an onboard 16-bit CRC.
4 EPROM3 - EPROM (OTP). TMEX Bitmap in upper nibble of byte 0 of status
memory
           Contains an onboard 16-bit CRC data check.
5 EEPROM1 - EEPROM, one address byte
6 MNVRAM - non-volatile rewritable RAM with read-only non rolling-over page
           write cycle counters associated with last 1/4 of pages
           (3 minimum)
7 EEPROM2 - EEPROM. On board CRC16 for Write/Read memory.
            Copy Scratchpad returns an authentication byte (alternating
1/0).
8 NVRAM2 - non-volatile RAM. Contains an onboard 16-bit CRC.
9 NVRAM3 - non-volatile RAM with bit accessible memory.  Contains an onboard

           16-bit CRC.
----------------------------------------------------------------------------
