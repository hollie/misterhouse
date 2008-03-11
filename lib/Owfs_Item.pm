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

Example:

# noloop=start      This directive allows this code to be run on startup/reload
OW::init ( 3030 );  # Initialize the OWFS perl interface ( server tcp port )
# noloop=stop

 $item = new Owfs_Item ( "<device_id>", <location>, <port>, <channel> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <port>      - used for devices with multiple ports
 <channel>   - used for devices with multiple channels 

$frontDoorBell = new Owfs_Item ( "12.487344000000", "Front DoorBell", undef, "A");
$sensor        = new Owfs_Item ( "05.4D212A000000");

 Owfs_Item can be used as a baseclass and extended for specific one wire devices.
 For example, refer to Owfs_DS2450.pm which describes a one wire A/D device.

Usage:

  Any of the fields in the one-wire device can be access via the set and get methods.

  $sensor->set ("power", 1 );
  $sensor->get ("alarm");

=cut

use strict;

package Owfs_Item;

@Owfs::ISA = ('Generic_Item');

use OW;

my (%objects_by_id);

sub new {
    my ($class, $device, $location, $port, $channel) = @_;
    my %myhash;
    my $self = \%myhash;
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

    &dump ( $self ) if ($::Debug{owfs});
    return $self;
}

sub set {
     my ($self, $token, $data) = @_;
     my $path = $self->{path} . $token;
     &::print_log ("Owfw_Item::set $path $data") if $::Debug{owfs};
     my $result = OW::put($path, $data) or return ;
     return $result;
}

sub set_root {
     my ($self, $token, $data) = @_;
     my $path = $self->{root} . $token;
     &::print_log ("Owfw_Item::set_root $path $data") if $::Debug{owfs};
     my $result = OW::put($path, $data ) or return ;
     return $result;
}

sub get {
     my ($self, $token) = @_;
     my $path = $self->{path} . $token;
     my $result = OW::get($path) or return ;
     &::print_log ("Owfw_Item::get $path $result") if $::Debug{owfs};
     return $result;
}

sub get_root {
     my ($self, $token) = @_;
     my $path = $self->{root} . $token;
     my $result = OW::get($path) or return ;
     &::print_log ("Owfw_Item::get_root $path $result") if $::Debug{owfs};
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

sub alarm_check {
#    my ($self) = @_;
#    my $address = $self->{address};
#    &::print_log("Network_Item alarm on ip=$address") if $::Debug{owfs};

#    $self->{process}->stop();

#    my $alarm_test_file  = "$::config_parms{data_dir}/alarm_results.$address.txt";
#    if (-e $alarm_test_file) {
#        my $alarm_results = &::file_read($alarm_test_file);
#       print "db alarm_results for $address f=$alarm_test_file: $alarm_results\n";
#        my $state = ($alarm_results =~ /ttl=/i) ? 'up' : 'down';
#        $self->set($state);
#    }

#    $self->{process}->start();

}

sub dump {
  my $self = shift;
  &main::print_log ( "\n") if $main::Debug{owfs};
  &::print_log ( "root: \t\t$$self{root}\n") if $::Debug{owfs};
  &::print_log ( "path: \t\t$$self{path}\n") if $::Debug{owfs};
  &::print_log ( "family: \t$$self{family}\n") if $::Debug{owfs};
  &::print_log ( "id: \t\t$$self{id}\n") if $::Debug{owfs};
  &::print_log ( "type: \t\t$$self{type}\n") if $::Debug{owfs};

  for my $key (sort keys %$self) {
    next if ($key eq "root");
    next if ($key eq "path");
    next if ($key eq "family");
    next if ($key eq "id");
    next if ($key eq "type");
    &::print_log ( "$key:\t\t$$self{$key}\n") if $::Debug{owfs};
  }
  &::print_log ( "\n") if $::Debug{owfs};
}

sub _find {
  my ($family, $id,$lev,$path) = @_;
  my $result = OW::get($path) or return ;
#  &::print_log ( "_find:: family: $family id: $id lev: $lev path: $path\n") if $::Debug{owfs};
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
#  &::print_log ( "_load:: path: $path\n") if $::Debug{owfs};
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
