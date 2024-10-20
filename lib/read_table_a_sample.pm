# ------------------------------------------------------------------------------

# noloop=start
#
# This is a read_table_A.pl extension module
#


=pod

=head1 B<read_table_a_sample>

    J. Author (author<at>example.com)

=head2 SYNOPSIS

    When defining in an .mht file:
        # READ_TABLE_A_SAMPLE,   item_name, parm1, ...

	Ex:
	READ_TABLE_A_SAMPLE,	sample1, All_Lights, other-parm

        Note: "READ_TABLE_A_SAMPLE" in uppercase is a convention in .mht files,
        but not a requirement. The type is converted to lowercase when used as
        a module name, for the convenience of the developers. All uppercase file
        names are a pain to work with.

    When defining in code:

        Ex: 
        my $sample1 = new read_table_a_sample(parm1, ...);
        $sample1->init(parm1, ...) if ($sample1->can('init'));
	

=head2 DESCRIPTION

    SAMPLE object does lots of impressive sample stuff. Well, actually, nothing
    at all, but that's because this is only an example. Your module will be more 
    useful.


=head2 FILE

    read_table_a_sample.pm		# Note: always lowercase filenames.


=head2 LICENSE

    This free software is licensed under the terms of the GNU public license.


=head2 NOTES

    (none)

=head2 METHODS

=over 4

=cut

# ------------------------------------------------------------------------------

package read_table_a_sample;

use strict;
use warnings;

@read_table_a_sample::ISA = ( 'Generic_Item' );

=item new($myname, @other_parms )

Create a new instance of the object. Name is required. Additional parms
may be included as required for your object. The "new" method is required.

=cut

sub new {
    my ( $class, $myname, @other_parms ) = @_;

    # Set up generic storage, inheritance, etc. Your needs may differ.
    my %myhash;
    my $self = \%myhash;
    tie %myhash, 'Generic_Item_Hash', $self;
    bless $self, $class;

    # Do whatever we need to in order to create this item. In our sample case, we're not
    # trying to set up new objects or structures, but you'll need more.
    warn "lib/read_table_a_sample.pm wasn't intended for actual use.\n";

    return $self;

}

=item init( $self, $myname, @other_parms )

Perform post instantiation set-up on the object. Some characteristics
of an object can't be performed until after the "new" method completes. This
is because the object doesn't really exist until after "new" returns a value.
One example is that the object can't be assigned to a group until after it
exists. These additional actions can be handled in the "init" method, if it
is present.

The "init" receives in its parameter list a pointer to the instantiated object
(e.g. "$self"), followed by all the same arguments as "new". If the "new"
method needs to pass additional parameters to the "init" method, it may do so
by storing them in the object. And, of course, "init" may delete them later if
they have no lasting purpose once init completes.

The "init" method is optional.

=cut

sub init {

    my ( $self, $myname, @other_parms ) = @_;

    # Perform any post-instantiation tasks. In this sample code, we'll assume the next parm is a
    # list of groups this object should be a member of, and add it to those groups.
    my $grouplist = $other_parms[0];	# Should probably do this when parsing @_ instead.
    # Use read_table_A.pm's code to process the group list, so we handle all the exceptions properly.
    my $code = main::read_table_grouplist_A($myname,$grouplist);
    eval "package main;$code;";	# Run the group creation/assignment code created by read_table_grouplist_A.
    if ($@) {
        main::print_log "Error: read_table_a_sample: Unable to create/assign groups while creating $myname: $@";
    } 

    return $self;
}

=pod

=back

=cut

# noloop=stop
1;
