
=head1 B<Door_Item>

=head2 SYNOPSIS

Example initialization:  These are to be placed in a *.mht file in your user code directory.

First, define your actual door object (these are just examples):

  RF,          E1,     rf_front_door
  STARGATEDIN, 7,      sg_patio_door

Then, define the Door_Item and attach the real object:

  # Object 'front_door' attached to existing object 'rf_front_door'
  DOOR, rf_front_door, front_door

Using from your user code:

  # Attaching to a Light_Item (automatically turns light on)
  $auto_entry_light->add($front_door);

Input states:

  on/open/alert*: door opened
  off/closed/normal*: door closed
  ("*" is a wildcard here; values of "alertmin", "alertmax",
  and "alertbattlowmin" will all indicate "door opened", for example)

Output states:

  open: door opened
  closed: door closed
  check: Inactivity timeout has occurred -- batteries may be dead?

Optional Door-Open Alarm:  If you want to be alerted when the door is left open too long, you can set an alarm (time is in seconds; an optional repeat_time can force repeat actions):

  $front_door->set_alarm(300, "speak('front door left open');",120);

Optional Inactivity Alarm:

If you want to be alerted when the door hasn't been opened for a period of time (i.e. the batteries in the transmitter may be dead) then do this (time is in hours):

  $front_door->set_inactivity_alarm(
     48,                                              # hours
     "speak('front door battery may be dead');"       # command
  );


=head2 DESCRIPTION

An abstract object that represents a door that you can add to a Light_Item.  You typically associate a real door item (i.e. an RF door sensor or a digital input or the like) to this object.  It will also indicate the state of the door on the web-based floorplan.pl.

When attached to a Light_Item, it will cause the light to be turned on whenever the door is opened.  Typically you attach several objects to the same Light_Item.  See Light_Item.pm for various ways to control when the light turns on and for how long.

=head2 INHERITS

B<Base_Item>

=head2 METHODS

=over

=cut

use strict;

package Door_Item;

@Door_Item::ISA = ('Base_Item');

sub initialize {
    my ($self) = @_;
    $$self{m_write}        = 0;
    $$self{m_timerCheck}   = new Timer() unless $$self{m_timerCheck};
    $$self{m_timerAlarm}   = new Timer() unless $$self{m_timerAlarm};
    $$self{'alarm_action'} = '';
    $$self{last_open}      = 0;
    $$self{last_closed}    = 0;
    @{ $$self{states} } = ( 'open', 'closed' );
}

=item C<set_alarm($time,$action,$repeat_time)>

If an alarm is set, the specified action is executed if the door was left open for the specified amount of time

=cut

sub set_alarm($$$) {
    my ( $self, $time, $action, $repeat_time ) = @_;
    $$self{'alarm_action'}      = $action;
    $$self{'alarm_time'}        = $time;
    $$self{'alarm_repeat_time'} = $repeat_time if defined $repeat_time;
}

=item C<set_inactivity_alarm($time,$action)>

If an inactivity alarm is set, the specified action is executed if no notification of the door being opened has occured for X hours

=cut

sub set_inactivity_alarm($$$) {
    my ( $self, $time, $action ) = @_;
    $$self{'inactivity_action'} = $action;
    $$self{'inactivity_time'}   = $time * 3600;
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( ref $p_setby and $p_setby eq $$self{m_timerAlarm} ) {

        package main;
        eval $$self{'alarm_action'};

        package Door_Item;
        if ( $$self{'alarm_repeat_time'} ) {
            $$self{m_timerAlarm}->set( $$self{'alarm_repeat_time'}, $self );
        }
    }
    else {
        if ( ref $p_setby and $p_setby->can('get_set_by') ) {
            &::print_log(
                "Door_Item($$self{object_name})::set($p_state, $p_setby): $$p_setby{object_name} was set by "
                  . $p_setby->get_set_by )
              if $main::Debug{occupancy};
        }
        else {
            &::print_log(
                "Door_Item($$self{object_name})::set($p_state, $p_setby)")
              if $main::Debug{occupancy};
        }

        # X10.com door/window security sensor
        if ( $p_state =~ /^alert/ ) {
            $p_state = 'open';
        }
        elsif ( $p_state =~ /^normal/ ) {
            $p_state = 'closed';
        }

        # Other door sensors?
        if ( $p_state eq 'on' ) {
            $p_state = 'open';
        }
        elsif ( $p_state eq 'off' ) {
            $p_state = 'closed';
        }

        if ( $p_state ne $self->{state} ) {    #added this if clause
            if ( $p_state eq 'open' ) {
                if ( $$self{'alarm_action'} ) {
                    $$self{m_timerAlarm}->set( $$self{'alarm_time'}, $self );
                }
                $$self{m_timerCheck}->set( $$self{'inactivity_time'}, $self );
                $$self{last_open} = $::Time;
            }
            elsif ( $p_setby eq $$self{m_timerCheck} ) {   # Check timer expired
                if ( $$self{'inactivity_action'} ) {

                    package main;
                    eval $$self{'inactivity_action'};

                    package Door_Item;
                }
                else {
                    &::print_log(
                        "$$self{object_name} has not reported in 24 hours.");
                }
                $p_state = 'check';
            }
            elsif ( $p_state eq 'closed' ) {
                $$self{m_timerAlarm}->unset();
                $$self{last_closed} = $::Time;
            }
        }

        $self->SUPER::set( $p_state, $p_setby );
    }
}

sub get_last_close_time {
    my ($self) = @_;
    return $$self{last_closed};
}

sub get_last_open_time {
    my ($self) = @_;
    return $$self{last_open};
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee - jason@sharpee.com

Kirk Bauer - kirk@kaybee.org

Special Thanks to:
Bruce Winter - MH

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

