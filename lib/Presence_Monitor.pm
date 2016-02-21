
=head1 B<Presence_Monitor>

=head2 SYNOPSIS

Example initialization:

These are to be placed in a *.mht file in your user code directory.

First, make sure you have an occupancy monitor:

  OCCUPANCY, om

Then, create your presence objects:

  PRESENCE, sensor_X, om, presence_X

This creates a new Presence_Monitor object of name 'presence_X'
and attaches it to both the occupancy monitor and 'sensor_X'.  The
'sensor_X' object must already have been defined and needs to be
either a Door_Item or a Motion_Item.

Optional settings:

You can have occupancy automatically expire after X seconds of
no activity (no doors opened or motion in the room):

  $presence_X->occupancy_expire(3600);  # Expire after 1 hour

When using this feature, consider how long a person might remain
in the room without creating any motion.  This will depend on
the room and the motion detector coverage.  Obviously a room
with motion detector coverage only on the entrances/exits would
need a longer expiration time.  A hallway could have a pretty short
expiration time, but a room in which you might sit and read a book
for two hours needs a longer expiration time.

The purpose of this feature is to cause an errant occupancy to
eventually expire.  This is especially useful for rooms like a
closet that might get false-positive presence and nobody else
goes near it for a long time.  Also for a room like a hallway
that basically nobody ever stays in... yet there is lots of activity 
in and out and one of the outs might be missed.

Automating timers:

You can now add arbitrary commands to a presence object that will be
run after a room has been vacant or occupied for the specified amount
of time.  Here are examples:

  $om_presence_master_bedroom->add_presence_timer(15, 'speak("bedroom presence")');
  $om_presence_master_bedroom->add_vacancy_timer(15, 'speak("bedroom vacant")');

These examples cause the specified text to be spoken after a room has been
continuously occupied for 15 seconds or continuously vacant for 15 seconds.

Setting occupancy:

  set_count(): This function can be used to set the number of people
      in a specific room.  Set to 0 to vacate the room, or a positive number
      to set the number of people in the room.

Output states:

  vacant: Nobody is in the room
  predict: Somebody may be entering the room
  occupied: Somebody is in the room

=head2 DESCRIPTION

This is an object that is attached to the Occupancy Monitor (usually $om)
as well as one Door_Item or Motion_Item.  It maintains whether or not there
is presence (or predicted presence) within a given room.  You should have one
per room in your house, even if the room has multiple motion detectors.  Not
only will this object show up on floorplan.pl, but it can also be attached
to a Light_Object to make sure the light remains on when somebody is present.
If the light has prediction enabled it will also cause the light to turn on
when somebody may be entering the room.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

use strict;

package Presence_Monitor;

@Presence_Monitor::ISA = ('Generic_Item');

sub new {
    my ( $class, $p_object, $p_OM ) = @_;
    my $self = {};
    bless $self, $class;
    $$self{m_obj} = $p_object;
    $$self{m_OM}  = $p_OM;
    $p_OM->tie_items($self);
    $$self{m_timerCancelPredict}   = new Timer();
    $$self{m_timerOccupancyExpire} = new Timer();
    $$self{state}                  = 0;
    $$self{m_occupancy_expire}     = 0;
    $$self{wdog_interval}          = 60;
    $$self{m_timer_wdog}           = new Timer;
    $$self{m_timer_wdog}->set( $self->{wdog_interval},
        sub { &Presence_Monitor::watch_dog($self) } );
    $$self{debug} = $main::Debug{presence};
    return $self;
}

sub set_debug {
    my ( $self, $debug ) = @_;
    $self->{debug} = $debug;
}

=item C<watch_dog>

This watch_dog timer method will look for conditions where the room is occupied but no
occupancy expiration timer is in play. 

=cut

sub watch_dog {
    my ($self) = @_;
    if ( $self->state eq 'occupied' ) {
        if ( !$self->{m_timerOccupancyExpire}->active() ) {
            &::print_log(
                "$$self{object_name}: watch_dog, occupied without timer!")
              if $self->{debug};
            if ( defined $self->{m_occupancy_expire} ) {
                &::print_log(
                    "$$self{object_name}: occupancy timer set $$self{m_occupancy_expire}, watchdog condition!"
                ) if $self->{debug};
                $self->{m_timerOccupancyExpire}
                  ->set( $self->{m_occupancy_expire}, $self );
                $self->{wdog_interval} = $self->{m_occupancy_expire} + 2;
            }
        }
    }

    # reload the timer
    $self->{m_timer_wdog}->set( $self->{wdog_interval},
        sub { &Presence_Monitor::watch_dog($self) } );
}

sub handle_presence {
    my ($self) = @_;

    # Return if already occupied
    return if ( $self->state eq 'occupied' );
    foreach my $action ( keys %{ $$self{'vacancy_timers'} } ) {
        foreach my $time ( keys %{ $$self{'vacancy_timers'}{$action} } ) {
            if ( $$self{'vacancy_timers'}{$action}{$time}{'timer'}->active() ) {
                $$self{'vacancy_timers'}{$action}{$time}{'timer'}->unset();
            }
        }
    }
    foreach my $action ( keys %{ $$self{'presence_timers'} } ) {
        foreach my $time ( keys %{ $$self{'presence_timers'}{$action} } ) {
            unless (
                $$self{'presence_timers'}{$action}{$time}{'timer'}->active() )
            {
                $$self{'presence_timers'}{$action}{$time}{'timer'}->set( $time,
                    $$self{'presence_timers'}{$action}{$time}{'action'} );
            }
        }
    }
}

sub handle_vacancy {
    my ($self) = @_;

    # Return if already vacant
    return unless ( $self->state eq 'occupied' );
    foreach my $action ( keys %{ $$self{'presence_timers'} } ) {
        foreach my $time ( keys %{ $$self{'presence_timers'}{$action} } ) {
            if ( $$self{'presence_timers'}{$action}{$time}{'timer'}->active() )
            {
                $$self{'presence_timers'}{$action}{$time}{'timer'}->unset();
            }
        }
    }
    foreach my $action ( keys %{ $$self{'vacancy_timers'} } ) {
        foreach my $time ( keys %{ $$self{'vacancy_timers'}{$action} } ) {
            unless (
                $$self{'vacancy_timers'}{$action}{$time}{'timer'}->active() )
            {
                $$self{'vacancy_timers'}{$action}{$time}{'timer'}->set( $time,
                    $$self{'vacancy_timers'}{$action}{$time}{'action'} );
            }
        }
    }
}

sub process_count {
    my ( $self, $l_count, $p_setby ) = @_;
    my $p_state = undef;
    if ( $l_count < 0
        and ( $self->state() eq 'occupied' or $self->state() eq 'vacant' ) )
    {
        #start the timer for prediction
        $$self{m_timerCancelPredict}->set( 60, $self );

        #    $$self{m_timerOccupancyExpire}->unset( );
        &::print_log(
            "$$self{object_name}: predict timer set 60, marking room as predict"
        ) if $self->{debug};
        $p_state = 'predict';
    }
    elsif ( $l_count >= 1 ) {
        $p_state = 'occupied';
        $$self{m_timerCancelPredict}->unset();
        my $m_state = $$self{m_obj}->state;
        my $m_name  = $$self{m_obj}->{object_name};
        &::print_log("$$self{object_name}: room occupied $m_state $m_name")
          if $self->{debug};
        if ( defined $$self{m_occupancy_expire}
            and $$self{m_obj}->state =~ /(motion|open)/i )
        {
            #            and ref $p_setby and ref $p_setby->get_set_by and $p_setby->get_set_by eq $$self{m_obj}
            $$self{m_timerOccupancyExpire}
              ->set( $$self{m_occupancy_expire}, $self );
            &::print_log(
                "$$self{object_name}: occupancy timer set $$self{m_occupancy_expire}, marking room as occupied"
            ) if $self->{debug};
        }
        elsif ( !( defined $$self{m_occupancy_expire} ) ) {
            $$self{m_timerOccupancyExpire}->unset();
        }
        $self->handle_presence();
    }
    elsif (
        (
               $l_count == 0
            or $l_count eq ''
            or ( ( $l_count > 0 ) and ( $l_count < 1 ) )
        )
        and !$$self{m_timerCancelPredict}->active
        and !$$self{m_timerOccupancyExpire}->active
      )
    {
        &::print_log(
            "$$self{object_name}: room count ($l_count) zero, marking room as vacant"
        ) if $self->{debug};
        $p_state = 'vacant';
        $self->handle_vacancy();
    }
    elsif ( $l_count == -1 ) {
        $p_state = 'predict';
        $self->handle_vacancy();
    }
    return $p_state;
}

sub add_presence_timer {
    my ( $self, $time, $action ) = @_;
    $$self{'presence_timers'}{$action}{$time}{'timer'}  = new Timer;
    $$self{'presence_timers'}{$action}{$time}{'action'} = $action;
}

sub remove_presence_timer {
    my ( $self, $time, $action ) = @_;
    if (    $$self{'presence_timers'}
        and $$self{'presence_timers'}{$action}
        and $$self{'presence_timers'}{$action}{$time} )
    {
        $$self{'presence_timers'}{$action}{$time}{'timer'}->unset();
        delete $$self{'presence_timers'}{$action}{$time};
        unless ( keys %{ $$self{'presence_timers'}{$action} } ) {
            delete $$self{'presence_timers'}{$action};
        }
        return 1;
    }
    return 0;
}

sub add_vacancy_timer {
    my ( $self, $time, $action ) = @_;
    $$self{'vacancy_timers'}{$action}{$time}{'timer'}  = new Timer;
    $$self{'vacancy_timers'}{$action}{$time}{'action'} = $action;
}

sub remove_vacancy_timer {
    my ( $self, $time, $action ) = @_;
    if (    $$self{'vacancy_timers'}
        and $$self{'vacancy_timers'}{$action}
        and $$self{'vacancy_timers'}{$action}{$time} )
    {
        $$self{'vacancy_timers'}{$action}{$time}{'timer'}->unset();
        delete $$self{'vacancy_timers'}{$action}{$time};
        unless ( keys %{ $$self{'vacancy_timers'}{$action} } ) {
            delete $$self{'vacancy_timers'}{$action};
        }
        return 1;
    }
    return 0;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;

    #we dont care about $p_state as we derive it from the sensor count.  one way only.

    #Timer expired.  Reset predict state
    if (    $p_setby eq $$self{m_timerCancelPredict}
        and $self->state() eq 'predict' )
    {    #timer up reset
        if ( $$self{m_OM}->sensor_count( $$self{m_obj} ) eq -1 ) {
            &::print_log(
                "$$self{object_name}: prediction timer expired, marking room as vacant"
            ) if $self->{debug};
            $$self{m_OM}->sensor_count( $$self{m_obj}, 0 );
            $p_state = 'vacant';
            $self->handle_vacancy();
        }
        else {
            $p_state = undef;
        }
    }
    elsif ( $p_setby eq $$self{m_timerOccupancyExpire}
        and $self->state() eq 'occupied' )
    {    #timer up
        $p_state = 'vacant';
        $$self{m_OM}->sensor_count( $$self{m_obj}, 0 );
        &::print_log(
            "$$self{object_name}: occupancy timer expired, marking room as vacant"
        ) if $self->{debug};
        $self->handle_vacancy();
    }
    else {
        my $l_count = $$self{m_OM}->sensor_count( $$self{m_obj} );
        $p_state = $self->process_count( $l_count, $p_setby );
    }

    if ( defined $p_state and $p_state ne $self->state() ) {
        $self->SUPER::set( $p_state, $p_setby, $p_response );
    }
}

sub occupancy_expire {
    my ( $self, $p_delay ) = @_;
    $$self{m_occupancy_expire} = $p_delay if defined $p_delay;
    return $$self{m_occupancy_expire};
}

sub set_count {
    my ( $self, $count ) = @_;
    $$self{m_OM}->sensor_count( $$self{m_obj}, $count );
    my $p_state = $self->process_count($count);
    if ( defined $p_state and $p_state ne $self->state() ) {
        $self->SUPER::set($p_state);
    }
}

=item C<get_time_diff>

Returns the number of seconds since the last motion in the room

=cut

sub get_time_diff {
    my ($self) = @_;
    my $last = $$self{m_OM}->get_last_motion( $$self{m_obj} );
    $last = 0 unless defined $last;
    return ( $::Time - $last );
}

sub get_count {
    my ($self) = @_;
    return $$self{m_OM}->sensor_count( $$self{m_obj} );
}

sub writable {
    return 0;
}

#sub default_getstate
#{
#	my ($self,$p_state) = @_;
#
#	return $$self{m_OM}->sensor_count($$self{m_obj});
#}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee  jason@sharpee.com

Special Thanks to:  Bruce Winter - MH

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

