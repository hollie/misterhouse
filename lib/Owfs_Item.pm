=head1 B<Owfs_Item>

=head2 SYNOPSIS

In your code module, instantation the Owfs_Item class to interface with some
one-wire element.  The one-wire device can be found using the OWFS html interface.

 $item = new Owfs_Item ( "<device_id>", <location> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id

 $frontDoorBell = new Owfs_Item ( "12.487344000000", "Front DoorBell");
 $sensor        = new Owfs_Item ( "05.4D212A000000");

 Owfs_Item can be used as a baseclass and extended for specific one wire devices.
 For example, refer to package Owfs_DS2450 which describes a one wire A/D device.

 Any of the fields in the one-wire device can be access via the set and get methods.

 $sensor->set ("power", 1 );
 $sensor->get ("alarm");


=head2 DESCRIPTION

Use this module to interface with the OWFS (one-wire filesystem) software.
The OWFS software handles all the real-time processing of the one-wire itself,
offering a simple PERL API interface.

Owfs_Item should handle any Owfs device, and provides access to any individual field.

Requirements:

 Download and install OWFS (tested against release owfs-2.7p21) http://www.owfs.org

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
  10,    0,   0,   0,   0,   0,   0, DS1920,DS1820,Temperature iButton with Trips
  11,    2,  32,   1,   8,   0,   2, DS1981,DS2501,512-bit EPROM
  12,    4,  32,   1,   8,   0,   4, DS2407,,Dual Addressable Switch
  13,   16,  32,  34,   8,   0,   3, DS1983,DS2503,4K-bit EPROM
  14,    1,  32,   0,   0,   0,   5, DS1971,DS2430A,256-bit EEPROM, plus 64-bit OTP
  15,    0,   0,   0,   0,   1,   0, DS87C900,,Lock Processor
  16,    0,   0,   0,   0,   0,   0, DS1954,,Crypto iButton
  18,    4,  32,   0,   0,   1,   6, DS1963S,4K-bit Transaction iButton with SHA
  1A,   16,  32,   0,   0,   1,   6, DS1963,,4K-bit Transaction iButton
  1C,    4,  32,   0,   0,   1,   6, DS2422,,1K-bit EconoRAM with Counter Input
  1D,   16,  32,   0,   0,   1,   6, DS2423,,4K-bit EconoRAM with Counter Input
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
  4 EPROM3 - EPROM (OTP). TMEX Bitmap in upper nibble of byte 0 of status memory
             Contains an onboard 16-bit CRC data check.
  5 EEPROM1 - EEPROM, one address byte
  6 MNVRAM - non-volatile rewritable RAM with read-only non rolling-over page
             write cycle counters associated with last 1/4 of pages (3 minimum)
  7 EEPROM2 - EEPROM. On board CRC16 for Write/Read memory.
              Copy Scratchpad returns an authentication byte (alternating 1/0).
  8 NVRAM2 - non-volatile RAM. Contains an onboard 16-bit CRC.
  9 NVRAM3 - non-volatile RAM with bit accessible memory.  Contains an onboard 16-bit CRC.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package Owfs_Item;

@Owfs_Item::ISA = ('Generic_Item');

use OW;

my (%objects_by_id);
my $port = undef;

sub new {
    my ($class, $device, $location) = @_;
    my $self = { };
    bless $self,$class;
    $device =~ /(.*)\.(.*)/;
    my $family = $1;
    my $id = $2;

    # Initialize the OWFS perl interface ( server tcp port )

    if (!defined $port) {
        $port = 3030;
        $port = "$main::config_parms{owfs_port}" if exists $main::config_parms{owfs_port};
        &main::print_log ("Owfs_Item:: Initializing port: $port $location") if $main::Debug{owfs};
        OW::init ( "$port" );
    }

    $self->{device}   = $device;
    $self->{location} = $location;
    $self->{present}  = undef;
    $self->{root}     = &_find ( $family, $id, 0, "/" );
    $self->{path}     = $self->{root} . $family . "." . $id . "/";
    if (defined $self->{path}) {
        $objects_by_id{path} = $self;
        &_load ( $self, $self->{path} );
    }
    $$self{state}     = '';     # Will only be listed on web page if state is defined

    &dump ( $self ) if ($main::Debug{owfs});

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

sub get_present {
     my ($self) = @_;
     $self->{present} = $self->get("present");
     return $self->{present};
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
  &main::print_log ( "root: \t\t$$self{root}") if $main::Debug{owfs};
  &main::print_log ( "path: \t\t$$self{path}") if $main::Debug{owfs};
  &main::print_log ( "family: \t$$self{family}") if $main::Debug{owfs};
  &main::print_log ( "id: \t\t$$self{id}") if $main::Debug{owfs};
  &main::print_log ( "type: \t\t$$self{type}") if $main::Debug{owfs};

  for my $key (sort keys %$self) {
    next if ($key eq "root");
    next if ($key eq "path");
    next if ($key eq "family");
    next if ($key eq "id");
    next if ($key eq "type");
    &main::print_log ( "$key:\t\t$$self{$key}") if $main::Debug{owfs};
  }
  &main::print_log ( "\n") if $main::Debug{owfs};
}

sub _find {
  my ($family, $id,$lev,$path) = @_;
  my $result = OW::get($path) or return ;
  #&main::print_log ( "_find:: family: $family id: $id lev: $lev path: $path") if $main::Debug{owfs};
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
#  &main::print_log ( "_load:: path: $path") if $main::Debug{owfs};
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

=back

=head2 INI PARAMETERS

  owfs_port = 3030    # defined port where the owfs server is listening
                      # (owserver defaults to 4304)

=head2 AUTHOR

03/10/2007 Created by Jim Duda (jim@duda.tzo.com)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut






=head1 B<Owfs_DS18S20>

=head2 SYNOPSIS

  $sensor = new Owfs_DS18S20 ( "<device_id>", <location>, <interval> );

  <device_id> - of the form family.address; identifies the one-wire device
  <location>  - ASCII string identifier providing a useful name for device_id
  <interval>  - Optional (defaults to 10).  Number of seconds between measurements.

Example:

  $ds18S20 = new Owfs_DS18S20 ( "10.DB2506000000", "Living Room", 2 );

  my $temperature = get_temperature $ds18S20;

=head2 DESCRIPTION

This package specifically handles the DS18S20 Thermometer

=head2 INHERITS

B<Owfs_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Owfs_DS18S20;

@Owfs_DS18S20::ISA = ('Owfs_Item');

my @clients = ();
my $index = 0;
my $timer = undef;

sub new {
    my ($class, $ds18S20, $location, $interval) = @_;
    my $self = new Owfs_Item ( $ds18S20, $location, $interval );
    bless $self,$class;

    $self->{interval} = 10;
    if (defined $interval && ($interval > 1)) {
        $self->{interval} = $interval;
    }
    $self->{present} = 0;
    $self->{temperature} = undef;

    if (!defined $timer) {
        &::Reload_pre_add_hook(\&Owfs_DS18S20::reload_hook, 1);
	$index = 0;
        $timer = new Timer;
        $timer->set($self->{interval}, sub {&Owfs_DS18S20::run_loop});
    }

    push (@clients,$self);

    if ($self->{interval} < $clients[0]->get_interval( )) {
	$clients[0]->set_interval($self->{interval});
    }

    return $self;
}

sub get_present {
     my ($self) = @_;
     return $self->{present};
}

sub set_interval {
    my ($self,$interval) = @_;
    $self->{interval} = $interval if defined $interval;
}

sub get_interval {
    my ($self) = @_;
    return $self->{interval};
}

sub get_temperature {
    my $self = shift;
    return ($self->{temperature});
}

sub reload_hook {
    @clients = ();
    my $num = @clients;
    &main::print_log( "Owfs_DS18S20::reload_hook $num") if $main::Debug{owfs};
    $timer->set(10, sub {&Owfs_DS18S20::run_loop});
}

sub run_loop {

  # exit if we don't have any clients.
  return unless @clients;

  # issue simultaneous to start a conversion
  if ($index == 0) {
      my $self = $clients[0];
      &main::print_log ( "Owfs_DS18S20:: $index simultaneous") if $main::Debug{owfs};
      $self->set_root ( "simultaneous/temperature", "1" );
  } else {
      my $self = $clients[$index-1];
      $self->{present} = $self->get("present");
      my $temperature = $self->get("temperature");
      $self->{temperature} = $temperature;
      if ($main::Debug{owfs}) {
	  my $device = $self->{device};
	  my $location = $self->{location};
	  &main::print_log ("Owfs_DS18S20 $index $device $location temperature: $temperature") if $main::Debug{owfs};
      }
  }

  # udpate the index
  $index += 1;
  if ($index > @clients) {
      $index = 0;
  }

  # reschedule the timer for next pass
  $timer->set($clients[0]->get_interval( ), sub {&Owfs_DS18S20::run_loop});
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

03/10/2007 Created by Jim Duda (jim@duda.tzo.com)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut






=head1 B<Owfs_DS2405>

=head2 SYNOPSIS

  $sensor = new Owfs_DS2405 ( "<device_id>", <location> );

  <device_id> - of the form family.address; identifies the one-wire device
  <location>  - ASCII string identifier providing a useful name for device_id

Examples:

  my $relay = new Owfs_DS2405 ( "20.DB2506000000", "Some Relay", "0" );

  // Turn on relay
  $relay->set_pio("1");

  // Turn off relay
  $realy->set_pio("0");

  // Detect input transition
  my $doorbell = new Owfs_DS2405 ( "20.DB2506000000", "Front Door Bell", "1", 1 );
  if ($doorbell->get_latch( )) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
  }

=head2 DESCRIPTION

This package specifically handles the DS2405 Relay / IO controller.

=head2 INHERITS

B<Owfs_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Owfs_DS2405;

@Owfs_DS2405::ISA = ('Owfs_Item');

sub new {
    my ($class, $ds2405, $location ) = @_;
    my $self = new Owfs_Item ( $ds2405, $location );
    bless $self,$class;
    return $self;
}

sub set_pio {
    my ($self,$value) = @_;
    $self->set ("PIO", $value);
}

sub get_pio {
    my ($self) = @_;
    my $channel = $self->{channel};
    return ($self->get ("PIO"));
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

03/10/2007 Created by Jim Duda (jim@duda.tzo.com)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut






=head1 B<Owfs_DS2408>

=head2 SYNOPSIS

  $sensor = new Owfs_DS2408 ( "<device_id>", <location>, <channel>, <interval> );

  <device_id> - of the form family.address; identifies the one-wire device
  <location>  - ASCII string identifier providing a useful name for device_id
  <channel>   - "0", "1", "2", "3", "4", "5", "6", "7"
  <interval>  - Optional (defaults to 10).  Number of seconds between input samples.

Examples:

  my $relay = new Owfs_DS2408 ( "20.DB2506000000", "Some Relay", "0" );

  // Turn on relay
  $relay->set_pio("1");

  // Turn off relay
  $realy->set_pio("0");

  // Detect input transition
  my $doorbell = new Owfs_DS2408 ( "20.DB2506000000", "Front Door Bell", "1", 1 );
  if ($doorbell->get_latch( )) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
  }


=head2 DESCRIPTION

This package specifically handles the DS2408 Relay / IO controller.

=head2 INHERITS

B<Owfs_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Owfs_DS2408;

@Owfs_DS2408::ISA = ('Owfs_Item');

sub new {
    my ($class, $ds2408, $location, $channel, $interval) = @_;
    my $self = new Owfs_Item ( $ds2408, $location );
    bless $self,$class;

    $self->{interval} = 10;
    if (defined $interval && ($interval >= 1)) {
        $self->{interval} = $interval;
    }
    $self->{present} = 0;
    $self->{latch} = 0;
    $self->{pass_triggered} = 0;
    $self->{sensed} = undef;
    $self->{channel} = $channel;

    $self->restore_data('latch'); 

    &::Reload_pre_add_hook(\&Owfs_DS2408::reload_hook, 1);

    $self->{timer} = new Timer;
    $self->{timer}->set($self->{interval}, sub {&Owfs_DS2408::run_loop($self)});

    return $self;
}

sub get_present {
     my ($self) = @_;
     return $self->{present};
}

sub set_interval {
    my ($self,$interval) = @_;
    $self->{interval} = $interval if defined $interval;
}

sub get_interval {
    my ($self) = @_;
    return $self->{interval};
}

sub set_pio {
    my ($self,$value) = @_;
    my $channel = $self->{channel};
    $self->set ("PIO.$channel", $value);
}

sub get_pio {
    my ($self) = @_;
    my $channel = $self->{channel};
    return ($self->get ("PIO.$channel"));
}

sub get_latch {
    my ($self) = @_;
    my $latch = $self->{latch};
    if ($latch) {
        $self->{latch} = 0;
        $self->{pass_triggered} = 0;
    }
    return ($latch);
}

sub get_sensed {
    my $self = shift;
    return ($self->{sensed} eq 1 ? 1 : 0);
}

sub reload_hook {
}

sub run_loop {
    my $self = shift;
    my $channel = $self->{channel};
    my $latch = $self->get ("latch.$channel");
    $self->{present} = $self->get("present");
    $self->{sensed} = $self->get ("sensed.$channel");
    if ($latch) {
        $self->{pass_triggered} = $main::Loop_Count;
	$self->{latch} = $latch;
	$self->set("latch.$channel", "0");
    } elsif ($self->{pass_triggered} && $self->{pass_triggered} < $main::Loop_Count) {
	$self->{latch} = 0;
        $self->{pass_triggered} = 0;
    }

    if ($main::Debug{owfs}) {
	my $device = $self->{device};
	my $location = $self->{location};
	&main::print_log ("Owfs_DS2408 $index $device $location $channel latch: $latch");
    }

    # reschedule the timer for next pass
    $self->{timer}->set($self->get_interval( ), sub {&Owfs_DS2408::run_loop($self)});
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

03/10/2007 Created by Jim Duda (jim@duda.tzo.com)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut






=head1 B<Owfs_DS2413>

=head2 SYNOPSIS

  $sensor = new Owfs_DS2413 ( "<device_id>", <location>, <channel> , <interval> );

  <device_id> - of the form family.address; identifies the one-wire device
  <location>  - ASCII string identifier providing a useful name for device_id
  <channel>   - Channel identifier, "A" or "B"
  <interval>  - Optional (defaults to 10).  Number of seconds between input samples.

Examples:

  my $switch = new Owfs_DS2413 ( "20.DB2506000000", "Some Switch", "A" );

  // Turn on switch
  $switch->set_pio("1");

  // Turn off switch
  $switch->set_pio("0");

  // Detect input transition
  my $doorbell = new Owfs_DS2413 ( "20.DB2506000000", "Front Door Bell", "A", 1 );
  if ($doorbell->get_latch( )) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
  }

=head2 DESCRIPTION

This package specifically handles the DS2413 Dual Channel Addressable Switch.

=head2 INHERITS

B<Owfs_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Owfs_DS2413;

@Owfs_DS2413::ISA = ('Owfs_Item');

sub new {
    my ($class, $ds2413, $location, $channel, $interval) = @_;
    my $self = new Owfs_Item ( $ds2413, $location );
    bless $self,$class;

    $self->{interval} = 10;
    if (defined $interval && ($interval >= 1)) {
        $self->{interval} = $interval;
    }
    $self->{present} = 0;
    $self->{sensed} = undef;
    $self->{channel} = $channel;

    &::Reload_pre_add_hook(\&Owfs_DS2413::reload_hook, 1);

    $self->{timer} = new Timer;
    $self->{timer}->set($self->{interval}, sub {&Owfs_DS2413::run_loop($self)});

    return $self;
}

sub get_present {
     my ($self) = @_;
     return $self->{present};
}

sub set_interval {
    my ($self,$interval) = @_;
    $self->{interval} = $interval if defined $interval;
}

sub get_interval {
    my ($self) = @_;
    return $self->{interval};
}

sub set_pio {
    my ($self,$value) = @_;
    my $channel = $self->{channel};
    $self->set ("PIO.$channel", $value);
}

sub get_pio {
    my ($self) = @_;
    my $channel = $self->{channel};
    return ($self->get ("PIO.$channel"));
}

sub get_sensed {
    my $self = shift;
    return ($self->{sensed} eq 1 ? 1 : 0);
}

sub reload_hook {
}

sub run_loop {
    my $self = shift;
    my $channel = $self->{channel};
    $self->{present} = $self->get("present");
    $self->{sensed} = $self->get ("sensed.$channel");

    if ($main::Debug{owfs}) {
	my $device = $self->{device};
	my $location = $self->{location};
	&main::print_log ("Owfs_DS2413 $index $device $location $channel");
    }

    # reschedule the timer for next pass
    $self->{timer}->set($self->get_interval( ), sub {&Owfs_DS2413::run_loop($self)});
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

03/10/2007 Created by Jim Duda (jim@duda.tzo.com)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut






=head1 B<Owfs_DS2450>

=head2 SYNOPSIS

  $sensor = new Owfs_DS2450 ( "<device_id>", <location>, <channel>, <interval> );

  <device_id> - of the form family.address; identifies the one-wire device
  <location>  - ASCII string identifier providing a useful name for device_id
  <channel>   - "A", "B", "C", or "D"
  <interval>  - Optional (defaults to 10).  Number of seconds between measurements.

Example:

  $ds2450 = new Owfs_DS2450 ( "20.DB2506000000", "Furnace Sensor", "A" );

  my $voltage = $ds2450->get_voltage( );

=head2 DESCRIPTION

This package specifically handles the DS2450 A/D Converter.

=head2 INHERITS

B<Owfs_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Owfs_DS2450;

@Owfs_DS2450::ISA = ('Owfs_Item');

my @clients = ();
my $index = 0;
my $timer = undef;

sub new {
    my ($class, $ds2450, $location, $channel, $interval) = @_;
    my $self = new Owfs_Item ( $ds2450, $location );
    bless $self,$class;

    $self->{interval} = 10;
    if (defined $interval && ($interval > 1)) {
        $self->{interval} = $interval if defined $interval;
    }
    $self->{present} = 0;
    $self->{voltage} = undef;
    $self->{channel} = $channel;

    if (!defined $timer) {
        &::Reload_pre_add_hook(\&Owfs_DS2450::reload_hook, 1);
	$index = 0;
        $timer = new Timer;
        $timer->set($self->{interval}, sub {&Owfs_DS2450::run_loop});
    }

    push (@clients,$self);

    if ($self->{interval} < $clients[0]->get_interval( )) {
	$clients[0]->set_interval($self->{interval});
    }

    $self->set ( "set_alarm/voltlow.$channel", "1.0" );
    $self->set ( "set_alarm/low.$channel", "1" );
    $self->set ( "power", "1" );
    $self->set ( "PIO.$channel", "1" );

    return $self;
}

sub get_present {
     my ($self) = @_;
     return $self->{present};
}

sub set_interval {
    my ($self,$interval) = @_;
    $self->{interval} = $interval if defined $interval;
}

sub get_interval {
    my ($self) = @_;
    return $self->{interval};
}

sub get_voltage {
    my $self = shift;
    return ($self->{voltage});
}

sub reload_hook {
    @clients = ();
    my $num = @clients;
    &main::print_log( "Owfs_DS2450::reload_hook $num") if $main::Debug{owfs};
    $timer->set(10, sub {&Owfs_DS2450::run_loop});
}

sub run_loop {

    # exit if we don't have any clients.
    return unless @clients;
    
    # issue simultaneous to start a conversion
    if ($index == 0) {
        my $self = $clients[0];
        my $channel = $self->{channel};
        &main::print_log ( "Owfs_DS2450:: $index simultaneous: $channel index: $index") if $main::Debug{owfs};
        $self->set_root ( "simultaneous/voltage", "1" );
    } else {
        my $self = $clients[$index-1];
        my $channel = $self->{channel};
        my $voltage = $self->get ("volt.$channel");
        $self->{present} = $self->get("present");
        $self->{voltage} = $voltage;
        if ($main::Debug{owfs}) {
    	  my $device = $self->{device};
    	  my $location = $self->{location};
    	  &main::print_log ("Owfs_DS2450 $index $device $location $channel volt: $voltage");
        }
    }
    
    # udpate the index
    $index += 1;
    if ($index > @clients) {
      $index = 0;
    }
    
    # reschedule the timer for next pass
    $timer->set($clients[0]->get_interval( ), sub {&Owfs_DS2450::run_loop});
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

03/10/2007 Created by Jim Duda (jim@duda.tzo.com)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
