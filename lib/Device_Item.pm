
=head1 B<Device_Item>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

# $Date$
# $Revision$

use strict;
use warnings;

package Device_Item;

use Generic_Item;

@Device_Item::ISA = ('Generic_Item');
my @supported_interfaces = ();
our $mainHash = \%::Generic_Devices;

my %items_by_id;

sub reset {
    undef %items_by_id;
}

sub items_by_id {
    my ($id) = @_;

    return unless $items_by_id{$id};
    return @{ $items_by_id{$id} };
}

sub item_by_id {
    my ($id) = @_;
    my @refs = &items_by_id($id);
    return $refs[0];
}

sub new {
    my ( $class, $id, $state, $device_name ) = @_;

    my $self = Generic_Item->new;

    bless $self, $class;
    $self->{device_name} = $device_name;

    # default setup is that devices are read/write
    $self->{readable}  = 1;
    $self->{writeable} = 1;

    $self->{mainHash} = $mainHash;
    $self->set_standard_config;

    $self->add( $id, $state );

    return $self;
}

sub set_standard_config {
    my ($self) = @_;

    my $device_name = $self->{device_name};

    # if we don't have a device name, then nothing to look for in the mainHash
    if ( !defined($device_name) ) {
        return;
    }

    # return if we don't have any settings available in the main hash
    if ( !defined( $self->{mainHash}->{$device_name} ) ) {
        return;
    }

    # copy settings locally from the main hash
    grep ( {
            $self->{$_} = $self->{mainHash}->{$device_name}{$_}
              if defined( $self->{mainHash}->{$device_name}{$_} )
    } qw(readable writeable prefix datatype break) );
}

sub said {
    my ($self) = @_;

    return undef if !$self->{readable};

    my $device_name = $self->{device_name};
    my $data;
    my $key      = 'data_record';
    my $mainHash = $self->{mainHash};

    $key = 'data' if $self->{datatype} and $self->{datatype} eq 'raw';
    $data = $mainHash->{$device_name}{$key};

    $mainHash->{$device_name}{$key} = undef;

    return $data;
}

sub set {
    my ( $self, $state, $set_by ) = @_;

    return if &main::check_for_tied_filters( $self, $state, $set_by );

    return unless defined $state;

    my $id = '';
    if ( defined $self->{id_by_state}{$state} ) {
        $id = $self->{id_by_state}{$state};
    }
    elsif ( defined $self->{id_by_state}{ lc $state } ) {
        $id = $self->{id_by_state}{ lc $state };
    }
    else {
        $id = $state;
    }

    my $data = $id;

    # $data = uc ($data) unless $self->{states_casesensitive};

    return if &set_prev_pass_check( $self, $id );

    $self->set_states_for_next_pass( $state, $set_by );

    if ( $self->can('processData') ) {
        $data = $self->processData($data);
        return;
    }

    $state = $self->{prefix} . $state
      if defined( $self->{prefix} )
      and $self->{prefix} ne '';
    $state .= $self->{break} if $self->{datatype} ne 'raw';
    $self->write_data($state);
}

sub set_data {
    my ( $self, $data ) = @_;
    my $device_name = $self->{device_name};
    my $datatype    = $self->{datatype};
    my $mainHash    = $self->{mainHash};

    if ( $datatype eq 'raw' ) {
        $mainHash->{$device_name}{data} = $data;
    }
    else {
        $mainHash->{$device_name}{data_record} = $data;
    }
}

sub set_receive {
    my ( $self, $state, $set_by ) = @_;

    return if &main::check_for_tied_filters( $self, $state, $set_by );
    return if &set_prev_pass_check( $self, $state );
    $self->set_states_for_next_pass( $state, $set_by );
}

sub write_data {
    my ( $self, $data ) = @_;

    return if !$self->{writeable};

    my $handle = $::Generic_Devices{ $self->{device_name} }{handle};

    return unless $handle;

    my $name = $self->{name};

    if ( !$handle->syswrite($data) ) {
        &print_log("error writing to generic device $name: $!");
    }
}

sub add {
    my ( $self, $id, $state ) = @_;

    $state = $id unless defined $state;

    $$self{state_by_id}{$id}    = $state if defined $id;
    $$self{id_by_state}{$state} = $id    if defined $state;

    push( @{ $$self{states} }, $state );
    push( @{ $items_by_id{$id} }, $self ) if $id;
}

sub is_started {
    my ($self) = @_;
    my $device_name = $self->{device_name};
    return ( $self->{mainHash}->{$device_name}{object} ) ? 1 : 0;
}

sub is_stopped {
    my ($self) = @_;
    return !$self->is_started;
}

sub start {
    my ($self)      = @_;
    my $device_name = $self->{device_name};
    my $mainHash    = $self->{mainHash};

    if ( !$device_name ) {
        &print_log("Error in Device_Item start, no device_name specified");
        return;
    }

    if ( $self->is_started ) {
        &print_log("Device $device_name is already started");
        return;
    }

    if ( $self->do_start ) {
        &print_log("Device $device_name was re-opened");
    }
    else {
        &print_log("Unable to open device $device_name");
    }
}

# hook to allow preventing the same data being sent on consecutive loops
sub set_prev_pass_check {
    my ( $self, $state );

    return 0;
}

sub do_start {
    my ($self) = @_;

    return &::generic_device_open( $self->{device_name} );
}

sub set_interface {
    my ( $self, $interface ) = @_;

    $self->{interface} = $self->lookup_interface($interface);
}

sub lookup_interface {
    my ( $self, $interface ) = @_;

    # if an interface is specified, just use it
    # note: we could check to make sure that the interface is actually supported
    #       by the current library at this point.  Not sure how to handle it if
    #       it isn't supported.
    if ( $interface and $interface ne '' ) {
        return lc $interface;
    }

    my $mainHash = undef;
    my $supported_interfaces;

    # $self can either be an object reference or an object class name (string)
    if ( ref $self ) {
        $mainHash             = $self->{mainHash};
        $supported_interfaces = $self->get_supported_interfaces;
    }
    else {
        eval "\$mainHash=\$${self}::mainHash";
        warn $@ if $@;
        eval "\$supported_interfaces=\\\@${self}::supported_interfaces";
        warn $@ if $@;
    }

    # go through each interface supported by the current library
    foreach my $possibleInterface (@$supported_interfaces) {

        # if there is an interface object associated with this interface
        # then the interface does exist and is usable, so use it
        if ( $mainHash->{$possibleInterface}{object} ) {
            return lc $possibleInterface;
        }
    }

    $interface = '' unless defined $interface;

    return lc($interface);
}

sub get_supported_interfaces {
    my ($self) = @_;

    # if we are called via an object, then get the class name through ref
    my $className = ref $self;

    # if we are called via a class name, then $self is the class name
    $className = $self unless $className;

    my $supported_interfaces;
    eval "\$supported_interfaces=\\\@${className}::supported_interfaces";
    warn $@ if $@;

    return $supported_interfaces;
}

sub supports {
    my ( $self, $interface ) = @_;

    if (
        grep ( { lc $interface eq lc $_ } @{ $self->get_supported_interfaces } )
        > 0 )
    {
        return 1;
    }
    return 0;
}

# do not remove the following line, packages must return a true value
1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

