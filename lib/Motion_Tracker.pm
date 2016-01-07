
=head1 B<Motion_Tracker>

=head2 SYNOPSIS

In .mht file:

  X10MS, C10, room1_sensor, Sensors

In .pl file:

  my $room1_tracker = new Motion_Tracker(room1_sensor, 2*60);
  print_log "Last motion was " . $room1_tracker->age();


=head2 DESCRIPTION

This tracks a X10_Sensor and provides information on the last time motion
was seen by the sensor.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

use strict;
use Timer;

package Motion_Tracker;

@Motion_Tracker::ISA = ('Generic_Item');

sub new {
    my ( $class, $sensor, $expire_timeout ) = @_;
    my $self = {};
    bless $self, $class;
    $$self{sensor} = $sensor;

    # Default expire_timeout to 2 minutes
    if ( $expire_timeout == undef ) {
        $$self{expire_timeout} = 2 * 60;
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

=item C<TIESCALAR>

Part of tie mechanism to track last_motion variable

=cut

sub TIESCALAR {
    my ( $class, $self ) = @_;
    return $self;
}

=item C<FETCH>

Part of tie mechanism to track last_motion variable

=cut

sub FETCH {
    my ($self) = @_;
    return $self->last_motion();
}

=item C<STORE>

Part of tie mechanism to track last_motion variable

=cut

sub STORE {
    my ( $self, $val ) = @_;

    #print 'Setting last_motion to ' . $val . '\n';
    $self->last_motion($val);
}

=item C<set>

Set the state of this tracker.  Valid states input states are 'motion', 'on', 'occupied' or 'vacant'.  All other states are ignored.  Output states are 'occupied' or 'vacant'.

=cut

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq $$self{expire_timer} ) {
        $p_state = 'vacant';
    }
    elsif (( $p_state eq 'dark' )
        or ( $p_state eq 'light' )
        or ( $p_state eq 'off' )
        or ( $p_state eq 'still' ) )
    {
        # TODO: reset battery alarm timer
        return;
    }
    elsif ( $p_state eq 'on' or $p_state eq 'motion' ) {
        $p_state = 'occupied';
        $self->last_motion($::Time);
    }
    $self->SUPER::set( $p_state, $p_setby );
}

=item C<expire_timeout>

Get/set the expire timeout.  This controls how long after the last motion is seen until when the tracker will be set to 'vacant'.  Will not take effect until next motion is detected (fix?).

=cut

sub expire_timeout {
    my ( $self, $expire_timeout ) = @_;
    if ( $expire_timeout == undef ) {
        return $$self{expire_timeout};
    }
    $$self{expire_timeout} = $expire_timeout;
    return $expire_timeout;
}

=item C<age>

Return number of seconds since last motion was detected

=cut

sub age {
    my ($self) = @_;
    return $::Time - $self->last_motion();
}

=item C<last_motion>

Get/set the last motion time.  Call with one argument to set last_motion, call with no arguments to return last_motion time.  If last_motion was more than expire_timeout seconds ago, then the state will be set to 'vacant'.  Otherwise, a  timer will be started to set the state to 'vacant' after expire_timeout seconds have elapsed.

=cut

sub last_motion {
    my ( $self, $last_motion ) = @_;
    if ( $last_motion == undef ) {
        return $$self{last_motion};
    }
    $$self{last_motion} = $last_motion;

    # Has the traker expired?  If so, then set state to vacant
    if ( $self->age() >= $self->expire_timeout() ) {
        $self->set('vacant');
    }
    else {
        # Haven't expired yet, so setup timer to set state later on
        # Note that I subtract the age() as time served :)
        $$self{expire_timer}
          ->set( $self->expire_timeout() - $self->age(), $self );
    }
    return $last_motion;
}

=item C<print_state>

Return vacant/occupied state and time since last motion as a string

=cut

sub print_state {
    my ($self) = @_;
    return $self->state() . " last motion " . $self->age() . " sec ago";
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

John Dillenburg  john@dillenburg.org

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

