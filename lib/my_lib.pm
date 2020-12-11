
=head1 B<my_lib>

=head2 SYNOPSIS

    use lib LIST;
    no lib LIST;

ADDING DIRECTORIES TO @INC

The parameters to C<use lib> are added to the start of the perl search
path. Saying

    use lib LIST;

is I<almost> the same as saying

    BEGIN { unshift(@INC, LIST) }

For each directory in LIST (called $dir here) the lib module also
checks to see if a directory called $dir/$archname/auto exists.
If so the $dir/$archname directory is assumed to be a corresponding
architecture specific directory and is added to @INC in front of $dir.

If LIST includes both $dir and $dir/$archname then $dir/$archname will
be added to @INC twice (if $dir/$archname/auto exists).

DELETING DIRECTORIES FROM @INC

You should normally only add directories to @INC.  If you need to
delete directories from @INC take care to only delete those which you
added yourself or which you are certain are not needed by other modules
in your script.  Other modules may have added directories which they
need for correct operation.

By default the C<no lib> statement deletes the I<first> instance of
each named directory from @INC.  To delete multiple instances of the
same name from @INC you can specify the name multiple times.

To delete I<all> instances of I<all> the specified names from @INC you can
specify ':ALL' as the first parameter of C<no lib>. For example:

    no lib qw(:ALL .);

For each directory in LIST (called $dir here) the lib module also
checks to see if a directory called $dir/$archname/auto exists.
If so the $dir/$archname directory is assumed to be a corresponding
architecture specific directory and is also deleted from @INC.

If LIST includes both $dir and $dir/$archname then $dir/$archname will
be deleted from @INC twice (if $dir/$archname/auto exists).

RESTORING ORIGINAL @INC

When the lib module is first loaded it records the current value of @INC
in an array C<@lib::ORIG_INC>. To restore @INC to that value you
can say

    @INC = @lib::ORIG_INC;

=head2 DESCRIPTION

This is a small simple module which simplifies the manipulation of @INC
at compile time.

It is typically used to add extra directories to perl's search path so
that later C<use> or C<require> statements will find modules which are
not located on perl's default search path.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package my_lib;

use vars qw(@ORIG_INC);
use Config;

my $archname = $Config{'archname'};

@ORIG_INC = @INC;    # take a handy copy of 'original' value

sub import {
    shift;
    foreach ( reverse @_ ) {
        ## Ignore this if not defined.
        next unless defined($_);
        if ( $_ eq '' ) {
            require Carp;
            Carp::carp("Empty compile time value given to use lib");

            # at foo.pl line ...
        }
        if ( -e && !-d _ ) {
            require Carp;
            Carp::carp("Parameter to use lib must be directory, not file");
        }
        unshift( @INC, $_ );

        # Put a corresponding archlib directory infront of $_ if it
        # looks like $_ has an archlib directory below it.
        if ( -d "$_/$archname" ) {
            unshift( @INC, "$_/$archname" )    if -d "$_/$archname/auto";
            unshift( @INC, "$_/$archname/$]" ) if -d "$_/$archname/$]/auto";
        }
    }
}

sub unimport {
    shift;
    my $mode = shift if $_[0] =~ m/^:[A-Z]+/;

    my %names;
    foreach (@_) {
        ++$names{$_};
        ++$names{"$_/$archname"} if -d "$_/$archname/auto";
    }

    if ( $mode and $mode eq ':ALL' ) {

        # Remove ALL instances of each named directory.
        @INC = grep { !exists $names{$_} } @INC;
    }
    else {
        # Remove INITIAL instance(s) of each named directory.
        @INC = grep { --$names{$_} < 0 } @INC;
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Tim Bunce, 2nd June 1995.

=head2 SEE ALSO

FindBin - optional module which deals with paths relative to the source file.

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

