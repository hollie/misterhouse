
=head1 B<StargateJTelephone>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<StargateTelephone>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package StargateJTelephone;

@StargateJTelephone::ISA = ('StargateTelephone');

sub patch() {
    my ( $self, $p_state ) = @_;
    if ( lc($p_state) eq 'on' ) {
        &::set_audio( 'ic', 'off' );
        &::set_audio( 'sg', 'on' );
    }
    else {
        &::set_audio( 'ic', 'on' );
        &::set_audio( 'sg', 'off' );
    }
    $self->SUPER::patch($p_state);
}

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

