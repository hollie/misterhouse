
=head1 B<Light_Switch_Item>

=head2 SYNOPSIS

Example initialization:  These are to be placed in a *.mht file in your user code directory.

First, define your actual X10 object (this is just an example):

  X10SL, H2, x10_2way_switch     # SwitchLinc 2-way switch

Then, define the Switch_Item and attach the real object:

  LTSWITCH, x10_2way_switch, 2way_switch

Then, you will usually add all your Light_Switch_Items to the occupancy monitor:

  $om->set_edges($2way_switch, 1, 2, 3;

Be sure to call only_when_set_by() as shown below if necessary.

Also, if you enable locking with this light switch, see lock_timeout() below.

Extra options:

By default, this object only cares about changes in state of the real object when it was set by 'serial'.  However, my Leviton 2-way switches send out status responses instead which give a set_by of 'status' instead.  Also, if you have a stick-on RF transmitter like I do, and it is received directly by Misterhouse with something like the W800, then the set_by will be 'rf'.  Therefore, you can change the default of 'serial' to some other type of set_by to watch for:

  $leviton_switch->only_when_set_by('status');

If you have a Smarthome SwitchLinc switch, then there is no need to make this change since it sends out normal ON/OFF commands.  For my stick-on RF keypad received by my W800, I do this:

  $rf_switch->only_when_set_by('rf');

Or, you may have a light that can be turned on by either RF or by a wired X10 controller, in which case you should do this:

  $rf_switch->only_when_set_by('rf', 'serial');

Finally, if this particular switch happens to control a light which is in turn controlled by a Light_Item, you can cause this switch to lock the light into one state or the other.  To do so, you first have to set the timeout:

  $bedroom_light_switch->lock_timeout(600);

This says that the specified switch object should lock the attached light until the room has been vacated for 600 seconds (10 minutes).  Once this is set, you need to add this object to the appropriate Light_Item:

  $bedroom_light->add($bedroom_light_switch);

Be careful to add the Light_Switch_Item and NOT the original X10 item or whatever it is!  It will cause an infinite loop!  I did this once and spent about 4 hours trying to track down the problem.

By request, you can now set different expiration times depending on whether the light is locked on or off.  Here is how this works:

  lock_timeout(): Sets/gets timeout for all states
  lock_timeout_off(): Sets/gets timeout when locking light off
  lock_timeout_on(): Sets/gets timeout when locking light on (actually
                     for any state besides 'off')

=head2 DESCRIPTION

An abstract object that represents a light switch of some sort in your house.  Switches that have been tested include:

  2-way X10 switches
  X10 control pads
  RF X10 keypads

This object can serve two purposes:

  1) When attached to the Occupancy_Monitor, it can establish presence
     in a certain room when a switch in that room is used.
  2) If lock_timeout() has been called, the object can be attached to
     a Light_Item to lock the light into an on or off state when the switch
     is used.

=head2 INHERITS

B<Base_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Light_Switch_Item;

@Light_Switch_Item::ISA = ('Base_Item');

sub initialize {
    my ($self) = @_;
    $$self{m_write}        = 0;
    $$self{m_lockable}     = 0;
    $$self{m_lock_timeout} = 0;
    @{ $$self{m_setby} } = ('serial');
}

sub only_when_set_by {
    my ( $self, @setby ) = @_;
    push( @{ $$self{m_setby} }, @setby ) if (@setby);
    return @{ $$self{m_setby} };
}

sub lockable {
    my ( $self, $lockable ) = @_;
    $$self{m_lockable} = $lockable if defined $lockable;
    return $$self{m_lockable};
}

sub lock_timeout_on {
    my ( $self, $timeout ) = @_;
    $$self{m_lock_timeout_on} = $timeout if defined $timeout;
    $$self{m_lockable} = 1;
    return $$self{m_lock_timeout_on};
}

sub lock_timeout_off {
    my ( $self, $timeout ) = @_;
    $$self{m_lock_timeout_off} = $timeout if defined $timeout;
    $$self{m_lockable} = 1;
    return $$self{m_lock_timeout_off};
}

sub lock_timeout {
    my ( $self, $timeout ) = @_;
    $$self{m_lock_timeout_on}  = $timeout if defined $timeout;
    $$self{m_lock_timeout_off} = $timeout if defined $timeout;
    $$self{m_lockable}         = 1;
    return $$self{m_lock_timeout_on};
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;
    if ( ref $p_setby ) {
        if ( $p_setby->can('get_set_by') ) {
            &::print_log(
                "Light_Switch_Item($$self{object_name})::set($p_state, $p_setby): $$p_setby{object_name} was set by "
                  . $p_setby->get_set_by )
              if $main::Debug{occupancy};
        }
        else {
            &::print_log(
                "Light_Switch_Item($$self{object_name})::set($p_state, $p_setby): $$p_setby{object_name}"
            ) if $main::Debug{occupancy};
        }
    }
    return if ( $p_state eq 'manual' );

    if ( $p_setby and $$self{m_setby} ) {
        foreach ( @{ $$self{m_setby} } ) {
            if (
                ( $p_setby->get_set_by() eq $_ )
                or (    $p_setby->get_set_by()
                    and $p_setby eq $p_setby->get_set_by() )
              )
            {
                &::print_log(
                    "Light_Switch_Item($$self{object_name}): setting state to 'pressed'"
                ) if $main::Debug{occupancy};
                $self->SUPER::set( 'pressed', $p_setby );
                last;
            }
        }
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Kirk Bauer  kirk@kaybee.org

Special Thanks to:  Jason Sharpee -- Occupancy_Monitor/Presence_Monitor/Light_Item/etc

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

