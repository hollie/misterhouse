use strict;

package File_Item;

sub new {
    my ($class, $file) = @_;
    my $self = {file => $file, index => 0};
    print "Warning, File_Item file does not exist: $file\n\n" if $main::Debug{file} and !-f $file;
    bless $self, $class;
    return $self;
}

sub name {
    my $filename = $_[0]->{file};
                                # Translate path names if on msdos
    $filename =~ tr|\/|\\| if $main::OS_win;
    return $filename;
}

sub restore_string {
    my ($self) = @_;

    my $index = $self->{index};
    my $restore_string = $self->{object_name} . "->{index} = $index" if $index;

    return $restore_string;
}

sub set_watch {
    my ($self, $flag) = @_;
    my $file = $self->{file};
    $self->{time} = (stat $file)[9];
    $self->{time} = time unless $self->{time}; # In case the file does not exist yet.
    $self->{flag} = $flag;
    $self->{target} = $main::Respond_Target if $main::Respond_Target; # Pass default target along
    print "File watch set for $file, flag=$flag. time=$self->{time}\n" if $main::Debug{file};
}

sub changed {
    my ($self) = @_;
    return unless $self->{time}; # Watch not set
    my $file = $self->{file};
    return 0 unless -e $file;   # Ignore non-existant or deleted files
    if (my $diff = (stat $file)[9] - $self->{time} ) {
        print "File changed for $file. diff=$diff\n" if $main::Debug{file};
        $self->{time} = 0;      # Reset;
        if ($self->{flag}) {
            return $self->{flag};
        }
        else {
            return $diff;           # Return number of seconds it was since the watch was set
        }
    }
    else {
        return 0;
    }
}

sub exist {
    my ($self) = @_;
    my $file = $self->{file};
    return -e $file;
}

sub exist_now {
    my ($self) = @_;
    my $file = $self->{file};
    if (-e $file) {
	unless ($self->{exist}) {
	    $self->{exist} = 1;
	    return 1;
	}
    }
    elsif ($self->{exist}) {
	$self->{exist} = 0;
    }
    return 0;
}


sub read_all {
    my ($self) = @_;
    return &main::file_read($$self{file});
}

sub read_head {
    my ($self, $n) = @_;
    return &main::file_head($$self{file}, $n);
}

sub read_tail {
    my ($self, $n) = @_;
    return &main::file_tail($$self{file}, $n);
}

my $file_handle_cnt = 0;
sub said {
    my ($self) = @_;

    no strict 'refs';           # Because of dynamic handle ref 
                                # Could/should use object IO package here?
    my $handle = $$self{handle};
    unless ($handle) {
        return unless -e $$self{file};
        $$self{handle} = $handle = 'FILEITEM' . $file_handle_cnt++;
        open ($handle, $$self{file}) or print "Error, could not open File_Item $$self{file}: $!\n";

                                # On startup, point pointer to the tail of the file
        while (<$handle>) { }
        $$self{index} = tell $handle;
        print "File_Item said method for $$self{file} opened to index $$self{index}\n";
        return;                 # No new data on startup
    }
    seek $handle, $$self{index}, 0;     # Go to where the last data was read
    my $data = <$handle>;       # One record per call
    $$self{index} = tell $handle;

    print "File_Item index=$$self{index} data: $_\n" if $data;
    return $data;
}

sub read_random {
    my ($self) = @_;
    my $record;
                                # Note, random read will write over index
                                #   ... lets us init to random spots in a file. 
    ($record, $$self{index}) = &main::read_record($$self{file}, 'random'); # From handy_utilities.pl
    return $record;
}

sub read_next {
    my ($self) = @_;
    my $record;
                                # If there is no index (e.g. startup), start with a random record.
    return read_random $self unless defined $$self{index};

    ($record, $$self{index}) = &main::read_record($$self{file}, $$self{index} + 1);
    return $record;
}

sub read_current {
    my ($self) = @_;
    my $record;
                                # If there is no index (e.g. startup), start with a random record.
    return read_random $self unless $$self{index};

    ($record, $$self{index}) = &main::read_record($$self{file}, $$self{index});
    return $record;
}

                                # This was a bad name for an object method ... perl already uses index!
sub index {
	return $_[0]->{index};
}

sub get_index {
	return $_[0]->{index};
}

sub set_index {
    my ($self, $state) = @_;
    $self->{index} = $state;
}

1;


#
# $Log$
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
