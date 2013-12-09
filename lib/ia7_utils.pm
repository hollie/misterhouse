package ia7_utils;

=head1 B<ia7_utils>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Provides support for the common routines used by the ia7 interface.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

sub print_log_changes{
	my ($time) = @_;
	if (int($time) >= int(::print_log_current_time())){
		return;
	}
	return ::json('print_log','time='.$time);
}


=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Kevin Robert Keegan

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
1;