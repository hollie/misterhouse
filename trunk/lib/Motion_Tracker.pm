=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

  File:
    Motion_Tracker.pm

  Description:
    This tracks a X10_Sensor and provides information on the last time motion
    was seen by the sensor.

  Author:
    John Dillenburg
    john@dillenburg.org

  License:
    Free software.

  Usage:
    In .mht file:
      X10MS, C10, room1_sensor, Sensors

    In .pl file:
      my $room1_tracker = new Motion_Tracker(room1_sensor, 2*60);
      print_log "Last motion was " . $room1_tracker->age();

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;
use Timer;

package Motion_Tracker;

@Motion_Tracker::ISA = ('Generic_Item');

sub new {
  my ($class,$sensor,$expire_timeout) = @_;
  my $self = {};
  bless $self,$class;
  $$self{sensor} = $sensor;
  # Default expire_timeout to 2 minutes
  if ($expire_timeout == undef) {
    $$self{expire_timeout} = 2*60;
  }
  else {
    $$self{expire_timeout} = $expire_timeout;
  }
  # Create a timer...defaults to calling set() method when it expires
  $$self{expire_timer} = new Timer();
  # Set the sensor to call set() when it's state changes
  $sensor->tie_items($self);
  # Doesn't actually restore anything! Marks last_motion as being restorable.
  $self->restore_data('last_motion');
  # Track reads/writes to last_motion...why does perl allow access to 
  # internal member variables?
  tie $$self{last_motion}, 'Motion_Tracker', $self;
  # TODO: Battery timer?
  return $self;
}

# Part of tie mechanism to track last_motion variable
sub TIESCALAR {
  my ($class, $self) = @_;
  return $self;
}

# Part of tie mechanism to track last_motion variable
sub FETCH {
  my ($self) = @_;
  return $self->last_motion();
}

# Part of tie mechanism to track last_motion variable
sub STORE {
  my ($self, $val) = @_;
  #print 'Setting last_motion to ' . $val . '\n';
  $self->last_motion($val);
}

#
# Set the state of this tracker.  Valid states input states are
# 'motion', 'on', 'occupied' or 'vacant'.  All other states are ignored.
# Output states are 'occupied' or 'vacant'.
#
sub set {
  my ($self, $p_state, $p_setby) = @_;

  if ($p_setby eq $$self{expire_timer}) {
    $p_state = 'vacant';
  }
  elsif (($p_state eq 'dark') or ($p_state eq 'light') or ($p_state eq 'off') 
         or ($p_state eq 'still')) {
    # TODO: reset battery alarm timer
    return;
  }
  elsif ($p_state eq 'on' or $p_state eq 'motion') {
    $p_state = 'occupied';
    $self->last_motion($::Time);
  }
  $self->SUPER::set($p_state, $p_setby);
}

#
# Get/set the expire timeout.  This controls how long after the last motion
# is seen until when the tracker will be set to 'vacant'.  Will not take
# effect until next motion is detected (fix?).
#
sub expire_timeout {
  my ($self, $expire_timeout) = @_;
  if ($expire_timeout == undef) {
    return $$self{expire_timeout};
  }
  $$self{expire_timeout} = $expire_timeout;
  return $expire_timeout;
}

#
# Return number of seconds since last motion was detected
#
sub age {
  my ($self) = @_;
  return $::Time - $self->last_motion();
}

#
# Get/set the last motion time.
# Call with one argument to set last_motion, call with no arguments to
# return last_motion time.  If last_motion was more than expire_timeout
# seconds ago, then the state will be set to 'vacant'.  Otherwise, a 
# timer will be started to set the state to 'vacant' after expire_timeout
# seconds have elapsed.
#
sub last_motion {
  my ($self, $last_motion) = @_;
  if ($last_motion == undef) {
    return $$self{last_motion};
  }
  $$self{last_motion} = $last_motion;
  # Has the traker expired?  If so, then set state to vacant
  if ($self->age() >= $self->expire_timeout()) {
    $self->set('vacant');
  }
  else {
    # Haven't expired yet, so setup timer to set state later on
    # Note that I subtract the age() as time served :)
    $$self{expire_timer}->set($self->expire_timeout() - $self->age(), $self);
  }
  return $last_motion;
}

#
# Return vacant/occupied state and time since last motion as a string
#
sub print_state {
  my ($self) = @_;
  return $self->state() . " last motion " . $self->age() . " sec ago";
}

1;
