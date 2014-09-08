
=head1 B<Dummy_Interface>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This is the Dummy_Interface class and is used as a placeholder interface.  It's entire job is to warn users that a real, working interface couldn't be found.

If you see Dummy_Interface warnings in your log, then look back to when the Dummy_Interface was created and you'll see for which id, state and interface misterhouse couldn't find and active interface

=head2 INHERITS

B<Device_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package Dummy_Interface;

use Device_Item;
@Dummy_Interface::ISA = ('Device_Item');

our $nextInstanceId       = 0;
our @supported_interfaces = ('dummy');

sub new {
    my ( $class, $id, $state, $interface ) = @_;
    my $self = {};
    bless $self, $class;
    $self->{instanceId} = $nextInstanceId;
    $nextInstanceId++;

    $self->firstWarning();

    $self->warning(
        "Creating dummy interface for id=$id, state=$state and interface=$interface.",
        1
    );
    return $self;
}

sub firstWarning {
    my ($self) = @_;

    $self->warning(
        "This Dummy_Interface is being used because MrHouse can't find a real hardware device to support some requested functionality",
        3
    );
}

sub warning {
    my ( $self, $message, $level ) = @_;

    $level = 2 unless $level;
    return if ( $level > $::config_parms{dummy_interface_warnings} );

    $message = 'Warning: Dummy_Interface #' . $self->instanceId . ": $message";
    print "$message\n";
}

sub instanceId {
    my ($self) = @_;

    return $self->{instanceId};
}

sub set {
    my ( $self, $state ) = @_;

    $self->warning("trying to set state $state");
}

sub add {
    my ( $self, $id, $state ) = @_;

    $self->warning( "trying to add id $id state $state", 3 );
    $self->SUPER::add( $id, $state );
}

sub said {
    my ($self) = @_;

    return '';
}

sub set_data {
    my ( $self, $data ) = @_;

    $self->warning("trying to set_data $data");
}

sub set_receive {
    my ( $self, $state ) = @_;

    $self->warning("trying to set_receive $state");
}

sub write_data {
    my ( $self, $data ) = @_;

    $self->warning("trying to write_data $data");
}

sub is_started {
    my ($self) = @_;

    return 0;
}

sub start {
    my ($self) = @_;

    $self->warning("trying to start");
}

sub set_interface {
    my ( $self, $interface ) = @_;

    $self->warning("trying to set interface $interface") if $interface;
}

sub lookup_interface {
    my ( $self, $interface ) = @_;

    $self->warning("trying to lookup_interface $interface");

    if ( $interface and $interface ne '' ) {
        return lc $interface;
    }

    return 'dummy';
}

sub get_supported_interfaces {
    my ($self) = @_;

    $self->warning("trying to get_supported_interfaces");
    return \@supported_interfaces;
}

sub supports {
    my ( $self, $interface );

    $self->warning("trying to find out if we support $interface");

    return 1;
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

