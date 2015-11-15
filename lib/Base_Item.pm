
=head1 B<Base_Item>

=head2 SYNOPSIS

Use one of the derived objects: Door_Item, Motion_Item, Presence_Item, Photocell_Item, and Light_Restriction_Item.

You can use the function delay_off() (also can be called as delay()) to set how long it takes for the derived object's effects to expire (for Door_Item, Motion_Item, and Presence_Item).  For Light_Item it sets how long until the light will turn off, unless the object that activated the light has its own value.

For example, if you have a Light_Object set with a delay_off(120), the light will turn off 2 minutes after the last event.  But, if it contains a motion detector with a delay_off(60), then the light will be turned off 60 seconds after the last motion was detected.

=head2 DESCRIPTION

The base object that Door_Item, Motion_Item, Presence_Item, Photocell_Item, and Light_Restriction_Item are derived from.  These are all used to provide predictive lighting when used along with Occupancy_Monitor.pm

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Base_Item;

@Base_Item::ISA = ('Generic_Item');

sub new {
    my ( $class, @p_objects ) = @_;
    my $self = {};
    bless $self, $class;
    $$self{m_write} = 1;
    $self->initialize();
    $self->add(@p_objects);

    return $self;
}

sub initialize {
    my ($self) = @_;
    $$self{m_presence_value} = 1;
    @{ $$self{m_objects} } = ();
}

sub add {
    my ( $self, @p_objects ) = @_;

    my @l_objects;

    for my $l_object (@p_objects) {
        if ( $l_object->isa('Group_Item') ) {
            @l_objects = $$l_object{members};
            for my $obj (@l_objects) {
                $self->add($obj);
            }
        }
        else {
            $self->add_item($l_object);
        }
    }
}

sub add_item {
    my ( $self, $p_object ) = @_;

    $p_object->tie_items($self);
    push @{ $$self{m_objects} }, $p_object;
}

sub remove_all_items {
    my ($self) = @_;

    if ( ref $$self{m_objects} ) {
        foreach ( @{ $$self{m_objects} } ) {
            $_->untie_items($self);
        }
    }
    delete $self->{m_objects};
}

sub add_item_if_not_present {
    my ( $self, $p_object ) = @_;

    if ( ref $$self{m_objects} ) {
        foreach ( @{ $$self{m_objects} } ) {
            if ( $_ eq $p_object ) {
                return 0;
            }
        }
    }
    $self->add_item($p_object);
    return 1;
}

sub remove_item {
    my ( $self, $p_object ) = @_;

    if ( ref $$self{m_objects} ) {
        for ( my $i = 0; $i < scalar( @{ $$self{m_objects} } ); $i++ ) {
            if ( $$self{m_objects}->[$i] eq $p_object ) {
                splice @{ $$self{m_objects} }, $i, 1;
                $p_object->untie_items($self);
                return 1;
            }
        }
    }
    return 0;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;

    # prevent reciprocal sets that can occur because of this method's state
    # propogation
    return
      if (  ref $p_setby
        and $p_setby->can('get_set_by')
        and $p_setby->{set_by} eq $self );

    #&::print_log($self->get_object_name() . "::set($p_state, $p_setby)");

    if ( ( defined $main::DBI ) && $::config_parms{events_table} ) {
        if ( defined $p_setby and $p_setby->isa("Generic_Item") ) {
            $main::DBI->prepare(
                "insert into Events (Object,ObjectType,State,Setby) values ('$$self{object_name}','"
                  . ref($self)
                  . "','$p_state','"
                  . $p_setby->{object_name}
                  . "');" )->execute();
        }
        else {
            $main::DBI->prepare(
                "insert into Events (Object,ObjectType,State,Setby) values ('$$self{object_name}','"
                  . ref($self)
                  . "','$p_state','"
                  . $p_setby
                  . "');" )->execute();
        }
    }

    # ensure the setting object is associated w/ the current object before
    #  iterating over the children.  At a minimum, main::set_by_to_target
    #  requires current "set_by" to properly navigate the set_by "chain"
    $self->{set_by} = $p_setby;

    # Propogate states to all member items
    if ( defined $$self{m_objects} ) {
        my @l_objects = @{ $$self{m_objects} };
        for my $obj (@l_objects) {
            if ( $obj ne $p_setby and $obj ne $self ) {    # Dont loop
                 #&::print_log($self->get_object_name() . "::checking($p_state, $p_setby) -> $$obj{object_name}") if $main::Debug{occupancy};
                if (   ( $obj->can('writable') and $obj->writable )
                    or ( !$obj->can('writable') ) )
                {    #check for "settable" objects
                    &::print_log( $self->get_object_name()
                          . "::set($p_state, $p_setby) -> $$obj{object_name}" )
                      if $main::Debug{occupancy};

                    #					$obj->set($p_state,$p_setby,$p_response);
                    # don't attempt to set sensors
                    if ( UNIVERSAL::isa( $obj, 'X10_Sensor' ) ) {
                        $obj->set_receive( $p_state, $self, $p_response );
                    }
                    else {
                        $obj->set( $p_state, $self, $p_response );
                    }
                }
            }
        }
    }
    $self->SUPER::set( $p_state, $p_setby, $p_response );
}

sub is_member {
    my ( $self, $p_object ) = @_;

    my @l_objects = @{ $$self{m_objects} };
    for my $l_object (@l_objects) {
        if ( $l_object eq $p_object ) {
            return 1;
        }
    }
    return 0;
}

sub find_members {
    my ( $self, $p_type ) = @_;

    my @l_found;
    my @l_objects = @{ $$self{m_objects} };
    for my $l_object (@l_objects) {
        if ( !$p_type or ( $l_object->isa($p_type) ) ) {
            push @l_found, $l_object;
        }
    }
    return @l_found;
}

sub presence_value {
    my ( $self, $p_value ) = @_;
    $$self{m_presence_value} = $p_value if defined $p_value;
    return $$self{m_presence_value};
}

sub writable {
    my ($self) = @_;
    return $$self{m_write};
}

sub delay_off {
    my ( $self, $p_delay ) = @_;
    $$self{m_delay_off} = $p_delay if defined $p_delay;
    return $$self{m_delay_off};
}

sub delay {
    my ( $self, $p_delay ) = @_;
    $$self{m_delay_off} = $p_delay if defined $p_delay;
    return $$self{m_delay_off};
}

=cut

sub default_getstate
{
	my ($self,$p_state) = @_;
	return $$self{m_obj}->state();
}
=cut

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee
jason@sharpee.com

Special Thanks to: Bruce Winter - MH

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

