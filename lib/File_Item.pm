
=head1 B<File_Item>

=head2 SYNOPSIS

     use File_Item;
     $f_deep_thoughts = new File_Item("$Pgm_Root/data/remarks/deep_thoughts.txt");
     my $thought = read_next $f_deep_thoughts;
     set_index $f_deep_thoughts 1;
     
     $f_weather_forecast = new File_Item("$Pgm_Root/data/web/weather_forecast.tx t");
     set_watch $f_weather_forecast;
     display name $f_weather_forecast if changed $f_weather_forecast;
     
     $shoutcast_log = new File_Item 'd:/shoutcast/sc_serv.log';
     print "Log data: $state" if $New_Second and $state = said $shoutcast_log;

=head2 DESCRIPTION

An item for reading and/or monitoring a file

Use File_Item to read a line of (or all of the) data from a file, and/or 
to monitor a file for changes.

Note:  These methods currently read the entire file, so if have big files (say,
>1 meg) we want to read, we should invent some new methods.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

use strict;

package File_Item;

=item C<new('file_name')>

Instantiation method.  'file_name' is the path and name of the file to read/monitor.

=cut

sub new {
    my ( $class, $file ) = @_;
    my $self = { file => $file, index => 0 };
    print "Warning, File_Item file does not exist: $file\n\n"
      if $main::Debug{file} and !-f $file;
    bless $self, $class;
    return $self;
}

=item C<name()>

Returns the path and name of the file associated with this item.  Slashes are translated to backslashes on Windows system.

=cut

sub name {
    my $filename = $_[0]->{file};

    # Translate path names if on msdos
    $filename =~ tr|\/|\\| if $main::OS_win;
    return $filename;
}

=item C<restore_string()>

Returns a string used to restore the index after a restart. bin/mh calls this method (for each item that has it) every 5 minutes to create mh_temp.saved_states in the data directory. 

=cut

sub restore_string {
    my ($self) = @_;

    my $index = $self->{index};
    my $restore_string = $self->{object_name} . "->{index} = $index" if $index;

    return $restore_string;
}

=item C<set_watch('flag')>

Sets the 'changed' time check.

=cut

sub set_watch {
    my ( $self, $flag ) = @_;
    my $file = $self->{file};
    $self->{time} = ( stat $file )[9];
    $self->{time} = time
      unless $self->{time};    # In case the file does not exist yet.
    $self->{flag}   = $flag;
    $self->{target} = $main::Respond_Target
      if $main::Respond_Target;    # Pass default target along
    print "File watch set for $file, flag=$flag. time=$self->{time}\n"
      if $main::Debug{file};
}

=item C<changed()>

Returns 0 if the file was not changed since the last set_watch call.  When the file changes: if 'flag' was specified in the last set_watcn call, 'flag' is returned, otherwise, it returns the number of seconds since the last set_watch call.

=cut

sub changed {
    my ($self) = @_;
    return unless $self->{time};    # Watch not set
    my $file = $self->{file};
    return 0 unless -e $file;       # Ignore non-existant or deleted files
    if ( my $diff = ( stat $file )[9] - $self->{time} ) {
        print "File changed for $file. diff=$diff\n" if $main::Debug{file};
        $self->{time} = 0;          # Reset;
        if ( $self->{flag} ) {
            return $self->{flag};
        }
        else {
            return
              $diff;   # Return number of seconds it was since the watch was set
        }
    }
    else {
        return 0;
    }
}

=item C<exist()>

Returns 1 if the file exists, 0 otherwise.

=cut

sub exist {
    my ($self) = @_;
    my $file = $self->{file};
    return -e $file;
}

=item C<exist_now()>

Returns 1 if the file was created since the last exist_now test, 0 otherwise.

=cut

sub exist_now {
    my ($self) = @_;
    my $file = $self->{file};
    if ( -e $file ) {
        unless ( $self->{exist} ) {
            $self->{exist} = 1;
            return 1;
        }
    }
    elsif ( $self->{exist} ) {
        $self->{exist} = 0;
    }
    return 0;
}

=item C<read_all()>

Returns contents for the file. If used in a list context, a list is returned, otherwise a string of all the lines.

=cut

sub read_all {
    my ($self) = @_;
    return &main::file_read( $$self{file} );
}

=item C<read_head(num)>

Returns the first I<num> lines of a file.  Defaults to ten lines if I<num> not given.  See file_head.

=cut

sub read_head {
    my ( $self, $n ) = @_;
    $n = 10 unless defined $n;
    return &main::file_head( $$self{file}, $n );
}

=item C<read_tail(num)>

Returns the last I<num> lines of a file.  Defaults to ten lines if I<num> not given.  See file_tail.

=cut

sub read_tail {
    my ( $self, $n ) = @_;
    $n = 10 unless defined $n;
    return &main::file_tail( $$self{file}, $n );
}

=item C<said()>

Returns data added to a file since the last call.  Only one record is returned per call.  This is useful for monitoring log files.  See mh/code/bruce/shoutcast_monitor.pl for an example. 

=cut

my $file_handle_cnt = 0;

sub said {
    my ($self) = @_;

    no strict 'refs';    # Because of dynamic handle ref
                         # Could/should use object IO package here?
    my $handle = $$self{handle};
    unless ($handle) {
        return unless -e $$self{file};
        $$self{handle} = $handle = 'FILEITEM' . $file_handle_cnt++;
        open( $handle, $$self{file} )
          or print "Error, could not open File_Item $$self{file}: $!\n";

        # On startup, point pointer to the tail of the file
        while (<$handle>) { }
        $$self{index} = tell $handle;
        print
          "File_Item said method for $$self{file} opened to index $$self{index}\n";
        return;    # No new data on startup
    }
    seek $handle, $$self{index}, 0;    # Go to where the last data was read
    my $data = <$handle>;              # One record per call
    $$self{index} = tell $handle;

    print "File_Item index=$$self{index} data: $_\n" if $data;
    return $data;
}

=item C<read_random()>

Reads a random record.  This also re-sets the index to the random position.

=cut

sub read_random {
    my ($self) = @_;
    my $record;

    # Note, random read will write over index
    #   ... lets us init to random spots in a file.
    ( $record, $$self{index} ) =
      &main::read_record( $$self{file}, 'random' );    # From handy_utilities.pl
    return $record;
}

=item C<read_next()>

Reads the next record, according to the index.  After reading the last record, it wraps back to the first.

=cut

sub read_next {
    my ($self) = @_;
    my $record;

    # If there is no index (e.g. startup), start with a random record.
    return read_random $self unless defined $$self{index};

    ( $record, $$self{index} ) =
      &main::read_record( $$self{file}, $$self{index} + 1 );
    return $record;
}

=item C<read_next_tail()>

Like read_next, except, it will not wrap back to the first record (i.e. after reaching the end of the file, it will alwasy return the last record).

=cut

sub read_next_tail {
    my ($self) = @_;
    my $record;
    unless ( defined $$self{index} ) {

        # If there is no index (e.g. startup), start with the first record
        $$self{index} = 0;
    }
    ( $record, $$self{index} ) =
      &main::read_record( $$self{file}, $$self{index} + 1, 1 );
    return $record;
}

=item C<read_current()>

meads the current record, according to the index.

=cut

sub read_current {
    my ($self) = @_;
    my $record;

    # If there is no index (e.g. startup), start with a random record.
    return read_random $self unless $$self{index};

    ( $record, $$self{index} ) =
      &main::read_record( $$self{file}, $$self{index} );
    return $record;
}

=item C<index()>

Deprecated.  Use get_index() instead.

=cut

# This was a bad name for an object method ... perl already uses index!
sub index {
    return $_[0]->{index};
}

=item C<get_index()>

Which record (line) of the file was last read.  The index is saved between mh sessions.  If you use a File_Item that does not yet have an index set, a random index will be used and stored.

=cut

sub get_index {
    return $_[0]->{index};
}

=item C<set_index(num)>

Set the index to line I<num>.  Defaults to 1 (first line) if I<num> not given.

=cut

sub set_index {
    my ( $self, $state ) = @_;
    $state = 1 unless defined $state;
    $self->{index} = $state;
}

=item C<get_type()>

Returns the class (or type, in Misterhouse terminology) of this item.

=cut

sub get_type {
    return ref $_[0];
}

=back

=head2 INI PARAMETERS

debug: Include C<file> in the comma seperated list of debug keywords to produce
debugging output from this item. 

=head2 AUTHOR

Bruce Winter

=head2 SEE ALSO

None

=head2 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, 
MA  02110-1301, USA.

=cut

1;

#
# $Log: File_Item.pm,v $
# Revision 1.13  2004/09/25 20:01:19  winter
# *** empty log message ***
#
# Revision 1.12  2004/06/06 21:38:44  winter
# *** empty log message ***
#
# Revision 1.11  2003/09/02 02:48:46  winter
#  - 2.83 release
#
# Revision 1.10  2003/02/08 05:29:22  winter
#  - 2.78 release
#
# Revision 1.9  2002/12/24 03:05:08  winter
# - 2.75 release
#
# Revision 1.8  2001/08/12 04:02:58  winter
# - 2.57 update
#
#
