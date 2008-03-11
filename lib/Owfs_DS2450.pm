=begin comment

Owfs_DS2450.pm 

03/10/2007 Created by Jim Duda (jim@duda.tzo.com)

Use this module to interface with the OWFS (one-wire filesystem) software.
The OWFS software handles all the real-time processing of the one-wire itself,
offering a simple PERL API interface.

This module interfaces specifically with DS2450 A/D device.

Requirements:

 Download and install OWFS
 http://www.owfs.org

Setup:

In your code module, instantation the Owfs_Item class to interface with some
one-wire element.  The one-wire device can be found using the OWFS html interface.

Usage:

# noloop=start      This directive allows this code to be run on startup/reload
OW::init ( 3030 );  # Initialize the OWFS perl interface ( server tcp port )
# noloop=stop

 $sensor = new Owfs_DS2450 ( "<device_id>", <location>, <channel>, <interval> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <channel>   - "A", "B", "C", or "D"
 <interval>  - seconds between acquisitions

=cut

use strict;

package Owfs_DS2450;

@Owfs_DS2450::ISA = ('Generic_Item');

use OW;
use Owfs_Item;

sub new {
    my ($class, $sensor, $location, $channel, $interval) = @_;
    my %myhash;
    my $self = \%myhash;
    bless $self,$class;

    $interval = 10 unless $interval;
    $interval = 10 if ($interval < 10);
    $self->{interval} = $interval;

    $self->{timer} = new Timer;
    $self->{timer}->set($self->{interval}, sub {&Owfs_DS2450::run_loop($self)});

    $self->{channel} = $channel;
    $self->{sensor} = new Owfs_Item ( $sensor, $location );
    $self->{sensor}->set ( "set_alarm/voltlow.$channel", "1.0" );
    $self->{sensor}->set ( "set_alarm/low.$channel", "1" );
    $self->{sensor}->set ( "power", "1" );
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
  &::print_log ( "Owfs_DS2450:: channel: $channel index: $index") if $::Debug{owfs};

  # issue simultaneous to start a conversion
  if ($self->{index} == 0) {
    $self->{sensor}->set_root ( "simultaneous/voltage", "1" );
  } else {
    my $token = "alarm/volt.$channel";
    my $voltage = $self->{sensor}->get ( "volt.$channel");
    $self->{voltage} = $voltage;
#    $self->set ( $voltage );
    &::print_log ("Owfs_DS2450 $channel $token volt: $voltage") if $::Debug{owfs};
    my $token = "alarm/low.$channel";
    my $trigger = $self->{sensor}->get ( $token );
    &::print_log ("Owfs_DS2450 $channel $token alarm low: $trigger") if $::Debug{owfs};
  }

  # udpate the index
  $self->{index} += 1;
  if ($self->{index} >= 2) {
    $self->{index} = 0;
  }

  # reschedule the timer for next pass
  $self->{timer}->set($self->{interval}, sub {&Owfs_DS2450::run_loop($self)});
}

sub dump {
  my $self = shift;
  print "\n";
  for my $key (sort keys %$self) {
    print "$key:\t\t$$self{$key}\n";
  }
  print "\n";
}

1;

