
=head1 B<Photocell_Item>

=head2 SYNOPSIS

Example initialization:

These are to be placed in a *.mht file in your user code directory.

  # First, define your actual motion detector:
  X10MS, B7, x10_motion_master_bedroom, Sensors, MS13

  # Then define the Photocell_Item and attach to the real object:
  PHOTOCELL, x10_motion_master_bedroom, photocell_master_bedroom

Input states:

  on/dark  : room is dark
  off/light: room is light

Output states:

  dark  : room is dark
  light: room is light
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

  # To disable the checking of this object, call:
  $motion_master_bedroom->check(0);

=head2 DESCRIPTION

An abstract object that represents a photocell that you can add to a
Light_Item.  Currently I have only used this with the Hawkeye motion
detector.  It will also indicate the light level of the room on
floorplan.pl if given proper coordinates.

=head2 INHERITS

B<Base_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;
use Base_Item;

package Photocell_Item;

@Photocell_Item::ISA = ('Base_Item');

sub initialize {
    my ($self) = @_;
    $$self{m_timerCheck} = new Timer() if !defined $$self{m_timerCheck};
    $$self{m_timerCheck}->set( 24 * 60 * 60, $self );
    $$self{state}             = 'dark';
    $$self{m_write}           = 0;
    $$self{m_blnCheck}        = 1;
    $$self{'inactivity_time'} = 24 * 3600;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $l_state;

    # Ignore the motion/still states
    if ( ( $p_state eq 'motion' ) or ( $p_state eq 'still' ) ) {
        return;
    }

    if ( ref $p_setby and $p_setby->can('get_set_by') ) {
        &::print_log(
            "Photocell_Item($$self{object_name})::set($p_state, $p_setby): $$p_setby{object_name} was set by "
              . $p_setby->get_set_by )
          if $main::Debug{occupancy};
    }
    else {
        &::print_log(
            "Photocell_Item($$self{object_name})::set($p_state, $p_setby)")
          if $main::Debug{occupancy};
    }

    if ( $p_state eq 'on' ) {
        $l_state = 'dark';
    }
    elsif ( $p_state eq 'off'
        and $p_setby eq $$self{m_timerCheck}
        and $$self{m_blnCheck} == 1 )
    {
        if ( $$self{'inactivity_action'} ) {

            package main;
            eval $$self{'inactivity_action'};

            package Photocell_Item;
        }
        else {
            &::print_log( $$self{object_name} . "->No state change in 24hrs." );
        }
        $l_state = 'check';
    }
    elsif ( $p_state eq 'off' ) {
        $l_state = 'light';
    }
    else {
        $l_state = $p_state;
    }
    if ( $$self{m_blnCheck} ) {
        $$self{m_timerCheck}->set( 24 * 60 * 60, $self );
    }
    $self->SUPER::set( $l_state, $p_setby, $p_response ) if defined $l_state;

}

sub check() {
    my ( $self, $p_blnCheck ) = @_;
    $$self{m_blnCheck} = $p_blnCheck if defined $p_blnCheck;
    if ( !$$self{m_blnCheck} ) {
        $$self{m_timerCheck}->stop();
    }
    return $$self{m_blnCheck};

}

# If an inactivity alarm is set, the specified action is executed
# if no notification of a lighting change has occured for X hours
sub set_inactivity_alarm($$$) {
    my ( $self, $time, $action ) = @_;
    $$self{'inactivity_action'} = $action;
    $$self{'inactivity_time'}   = $time * 3600;
    $$self{m_timerCheck}->set( $time * 3600, $self ) if $$self{m_blnCheck};
}

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

