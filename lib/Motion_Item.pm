
=head1 B<Motion_Item>

=head2 SYNOPSIS

Example initialization:
These are to be placed in a *.mht file in your user code directory.

First, define your actual motion detector:

  X10MS, B7, x10_motion_master_bedroom, Sensors, MS13

Then define the Motion_Item and attach to the real object:

  MOTION, x10_motion_master_bedroom, motion_master_bedroom

Using from your user code:

  # Attaching to a Light_Item (automatically turns light on)
  $auto_master_bedroom_light->add($motion_master_bedroom);

Input states:

  on/motion: motion detected
  off/still: motion no longer detected

Output states:

  motion: motion detected
  still: motion timer expired
  check: inactivity timer has expired -- batteries may be dead?

Optional Inactivity Alarm:

If you want to be alerted when motion hasn't been detected for
a period of time (i.e. the batteries in the transmitter may be
dead) then do this (time is in hours):

  $motion_master_bedroom->set_inactivity_alarm(
     48,                                                        # hours
     "speak('master bed motion detector battery may be dead');" # command
  );

The default is to log a message in the print log after 24 hours.


=head2 DESCRIPTION

An abstract object that represents a motion detector that you can add to a
Light_Item.  You typically associate a real motion detector (i.e. a hard-
wired one or an X10 Hawkeye) to this object.  It will also indicate the
state of the motion detector on floorplan.pl if given proper coordinates.

When attached to a Light_Item, it will cause the light to be turned on
whenever motion is detected.  Typically you attach several objects to
the same Light_Item.  See Light_Item.pm for various ways to control when
the light turns on and for how long.

=head2 INHERITS

B<Base_Item>

=head2 METHODS

=over

=cut

use strict;
use Timer;

package Motion_Item;

@Motion_Item::ISA = ('Base_Item');

sub initialize {
    my ($self) = @_;
    $$self{m_write} = 0;
    $$self{m_timeout} = new Timer() unless $$self{m_timeout};
    $$self{m_timeout}->set( 2 * 60, $self );
    $$self{m_timerCheck} = new Timer() unless $$self{m_timerCheck};

    # initialize states array
    @{ $$self{states} } = ( 'motion', 'still' );
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    my $name = $$self{object_name};
    &::print_log("Motion_Item::set name: $name state: $p_state")
      if $main::Debug{occupancy};

    if ( ref $p_setby and $p_setby->can('get_set_by') ) {
        &::print_log( "Motion_Item($$self{object_name})::set($p_state, $p_setby): $$p_setby{object_name} was set by " . $p_setby->get_set_by )
          if $main::Debug{occupancy};
    }
    else {
        &::print_log("Motion_Item($$self{object_name})::set($p_state, $p_setby)")
          if $main::Debug{occupancy};
    }

    if ( $p_setby eq $$self{m_timerCheck} ) {    # Check timer expired
        &::print_log("Motion_Item:: name: $name m_timerCheck")
          if $main::Debug{occupancy};
        my $hours = $$self{'inactivity_time'} / ( 60 * 60 );
        &::print_log("$name->Has not received motion in $hours hours (battery dead?) action->$$self{'inactivity_action'}") if $main::Debug{occupancy};
        if ( $$self{'inactivity_action'} ) {

            package main;
            eval $$self{'inactivity_action'};

            package Motion_Item;
        }
        else {
            &::print_log("$$self{object_name}->Has not received motion in $hours hours")
              if $main::Debug{occupancy};
        }
        if ( $$self{'inactivity_time'} ) {
            $$self{m_timerCheck}->set( $$self{'inactivity_time'}, $self );
        }
        $p_state = 'check';
    }
    elsif ( $p_setby eq $$self{m_timeout} ) {    # Timer expired
        &::print_log("Motion_Item:: name: $name m_timeout")
          if $main::Debug{occupancy};
        $p_state = 'still';
    }
    else {
        # Hawkeye (MS13) motion detector and security sensors
        if ( ( $p_state eq 'on' ) or ( $p_state =~ /^alert/i ) ) {
            $p_state = 'motion';
        }
        elsif ( ( $p_state eq 'off' ) ) {
            $p_state = 'still';
        }

        # Ignore the dark/light/normal states
        if (   ( $p_state eq 'dark' )
            or ( $p_state eq 'light' )
            or ( $p_state =~ /^normal/i ) )
        {
            # Reset watchdog timer and return on normal event
            if ( $$self{'inactivity_time'} ) {
                $$self{m_timerCheck}->set( $$self{'inactivity_time'}, $self );
            }
            return;
        }
        elsif ( $p_state eq 'motion' ) {    # Received ON
            &::print_log("Motion_Item:: name: $name state: $p_state")
              if $main::Debug{occupancy};
            $$self{m_timeout}->set( 2 * 60, $self );
            if ( $$self{'inactivity_time'} ) {
                $$self{m_timerCheck}->set( $$self{'inactivity_time'}, $self );
            }
        }
        elsif ( $p_state eq 'still' ) {     # Motion OFF
            &::print_log("Motion_Item:: name: $name state: $p_state")
              if $main::Debug{occupancy};
            $$self{m_timeout}->unset();
            if ( $$self{'inactivity_time'} ) {
                $$self{m_timerCheck}->set( $$self{'inactivity_time'}, $self );
            }
        }
    }
    $self->SUPER::set( $p_state, $p_setby );
}

sub delay_off() {
    my ( $self, $p_time ) = @_;
    $$self{m_delay_off} = $p_time if defined $p_time;
    return $$self{m_delay_off};
}

=item C<set_inactivity_alarm($$$)>

If an inactivity alarm is set, the specified action is executed.  if no notification of motion has occured for X hours

=cut

sub set_inactivity_alarm($$$) {
    my ( $self, $time, $action ) = @_;
    $$self{'inactivity_action'} = $action;
    $$self{'inactivity_time'}   = $time * 3600;
    $$self{m_timerCheck}->set( $time * 3600, $self );
    my $name = $$self{object_name};
    &::print_log("$name->set_inactivity_alarm for $time hours action->$action")
      if $main::Debug{occupancy};
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee  jason@sharpee.com

Special Thanks to: Bruce Winter - MH

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

