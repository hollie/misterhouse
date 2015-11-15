
=head1 B<handy_utilities>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Handy utilities of all shapes and sizes

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

#print "Creating handy utility functions ...";

# Pre-declare these so we don't fail on non-windows platforms
sub Win32::GetOSVersion;
sub Win32::FsType;
sub Win32::GetCwd;
sub Win32::LoginName;
sub Win32::NodeName;
sub Win32::IsWinNT;
sub Win32::IsWin95;
sub Win32::GetTickCount;
sub Win32::DriveInfo::DrivesInUse();
sub Win32::Sound::Volume;

#sub Win32::PerfLib;

#sub gettimeofday { return (scalar time, 0) }; # Used in get_tickcount, in case Time::Hires is not installed

package handy_utilities;
use strict;

sub main::batch {
    my (@cmds) = @_;
    my ( $bat_counter, $temp_dir, $bat_file, $cmd );
    $bat_counter = 0;
    $temp_dir    = $main::config_parms{temp_dir};
    $temp_dir    = $ENV{'TEMP'} unless -d $temp_dir;
    $temp_dir    = $ENV{'TMP'} unless -d $temp_dir;
    $temp_dir    = "." unless -d $temp_dir;
    do {
        $bat_counter++;
        $bat_file = "$temp_dir\\batch_commands.$bat_counter.bat";
    } until !-e $bat_file;
    open( BAT, ">$bat_file" )
      or die "Error, can not open bat command file $bat_file: $!\n";
    print BAT "echo on\n";
    foreach $cmd (@cmds) {
        print BAT $cmd . "\n";
    }

    #   print BAT ":exit\necho on\ndel $bat_file\nexit\n";
    close BAT;
    system("start /min command /c $bat_file")
      ; # Use cmd so the console will disappear when done ... exit after delete doesn't work :(

    #   system("start /min cmd /c $bat_file"); # Use cmd so the console will disappear when done ... exit after delete doesn't work :(
}

sub main::file_backup {
    my ( $file, $mode ) = @_;

    # Back it up if it is older than a few minutes old
    if (   ( $mode and ( $mode eq 'force' or $mode eq 'copy' ) )
        or ( $main::Time - ( stat $file )[9] ) > 60 * 10 )
    {
        print "Backing up file: $file to $file.backup\n";
        unlink "$file.backup4" if -e "$file.backup4";
        rename "$file.backup3", "$file.backup4" if -e "$file.backup4";
        rename "$file.backup2", "$file.backup3" if -e "$file.backup2";
        rename "$file.backup1", "$file.backup2" if -e "$file.backup1";
        if ( $mode eq 'copy' ) {
            main::file_cat( $file, "$file.backup1" ) if -e "$file";
        }
        else {
            rename "$file", "$file.backup1" if -e "$file";
        }
    }
}

sub main::fileit {    # Same as file_write
    my ( $file, $data ) = @_;
    open( LOG, ">$file" )
      or print "Warning, could not open fileit file $file: $!\n";
    print LOG $data . "\n";
    close LOG;
}

sub main::file_default {
    my ( $file, $default ) = @_;
    return ( $file and -f $file ) ? $file : $default;
}

sub main::file_head {
    my ( $file, $records ) = @_;
    my @head;
    open( DATA, $file )
      or print "head function error, could not open $file: $!\n";
    $records = 3 unless $records;
    while ( $records-- ) {
        my $record = <DATA>;
        push( @head, $record ) if $record;
    }
    close DATA;
    return wantarray ? @head : join( '', @head );
}

sub main::file_tail {
    my ( $file, $records ) = @_;
    my @tail;
    open( DATA, $file )
      or print "tail function error, could not open $file: $!\n";

    # Get the last few lines of a file
    $records = 3 unless $records;
    my $bytes =
      $records * 400;    # Guess on where to put the file pointer ... faster
    seek DATA, -$bytes, 2;
    my @data = <DATA>;
    $records = @data if @data < $records;
    @tail = @data[ -$records .. -1 ];
    close DATA;
    return wantarray ? @tail : join '', @tail;
}

# Find full paths to all files in requested dirs
sub main::file_read_dir {
    my @dirs = @_;
    my %files;
    for my $dir (@dirs) {
        opendir( DIR, $dir )
          or print
          "\nError in file_dir_read, can not open directory:  $dir. $!\n";
        my @files = readdir(DIR);
        close DIR;

        # Create a hash that shows the full file pathname.  First one wins
        for my $member (@files) {
            $files{$member} = "$dir/$member" unless $files{$member};
        }
    }
    return %files;
}

sub main::file_read {
    my ( $file, $flag, $textmode ) = @_;
    open( LOG, "$file" )
      or print "Warning, could not open file_read file $file: $!\n";

    # $flag = 1 -> Read as a scalar, even if wantarray is true
    # $flag = 2 -> Read as an array, but drop comment records
    if ( wantarray and !( $flag and $flag == 1 ) ) {
        my @data = <LOG>;
        @data = grep( !/^\#/, @data ) if $flag and $flag == 2;
        close LOG;
        chomp @data;    # Why would we ever want \n here??
        return @data;
    }

    # Read is faster than <> (?)
    else {
        binmode LOG
          unless $textmode
          ;   # Don't use this on wantarray ... chomp will only get \n, not \r\n
        my ( $data, $buffer );
        while ( read( LOG, $buffer, 8192 ) )
        {     # 8*2**10 bytes ... is this optimal??
            $data .= $buffer;
        }
        close LOG;
        return $data;
    }
}

sub main::file_write {    # Same as fileit
    my ( $file, $data ) = @_;
    open( LOG, ">$file" )
      or print "Warning, could not open file_write $file: $!\n";
    binmode LOG;          # Without this, \n newlines get messed up
    print LOG $data;

    #   print LOG $data . "\n";
    close LOG;
}

sub main::file_cat {
    my ( $file1, $file2, $position ) = @_;
    if ( $position and $position eq 'top' ) {
        open( LOG1, $file1 )
          or print "Warning, could not open file_cat $file1: $!\n";
        open( LOG2, $file2 )
          or print "Warning, could not open file_cat $file2: $!\n";
        binmode LOG1;
        binmode LOG2;
        my @data = ( <LOG1>, <LOG2> );
        open( LOG2, ">$file2" )
          or print "Warning, could not open file_cat $file2: $!\n";
        binmode LOG2;
        while (@data) {
            my $r = shift @data;
            print LOG2 $r;
        }
        close LOG1;
        close LOG2;
    }

    # Default is to cat to the bottom
    else {
        open( LOG1, "$file1" )
          or print "Warning, could not open file_cat $file1: $!\n";
        open( LOG2, ">>$file2" )
          or print "Warning, could not open file_cat $file2: $!\n";
        binmode LOG1;
        binmode LOG2;
        while (<LOG1>) {
            print LOG2 $_;
        }
        close LOG1;
        close LOG2;
    }
}

# This drops carriage returns and line feeds
sub main::filter_cr {
    my ($data) = @_;
    $data =~ s/[\n\r]//g;
    return $data;
}

# Used by &run and Process_Item ... must find pgm source for Win32::process
sub main::find_pgm_path {
    my ($pgm) = @_;

    my ( $pgm_path, $pgm_args );

    if ( $pgm =~ /^\x22(.+?)\x22/ ) {
        $pgm_path = $1;
        ($pgm_args) = $pgm =~ /^\x22.+?\x22 ?(.*)/;
    }
    else {
        ( $pgm_path, $pgm_args ) = $pgm =~ /^(\S+) ?(.*)/;
    }

    print "db Finding program path=$pgm_path\n" if $::Debug{misc};

    unless ( $pgm_path = &main::which($pgm_path) ) {
        print
          "Warning, new Process:  Can not find path to pgm=$pgm, pgm_path=$pgm_path arg=$pgm_args\n";

        #       return;
    }

    # This is in desperation ... see notes on &run and &process_item $cflag.
    # We must avoid .bat files on order to make processes killable :(
    if (    $main::OS_win
        and $pgm_path =~ /bat$/
        and &main::file_head($pgm_path) =~ /mh -run (\S+)/ )
    {
        my $perl_code = $1;
        my $pgm_interp;
        if ( $pgm_interp = &main::which('mh.exe') ) {
            $pgm_args = "-run $perl_code $pgm_args";
            $pgm_path = $pgm_interp;
        }
        elsif ( $pgm_interp = &main::which('mhe.exe') ) {
            $pgm_args = "-run $perl_code $pgm_args";
            $pgm_path = $pgm_interp;
        }
        elsif ( $pgm_interp = &main::which('perl.exe') ) {
            $pgm_args = "$perl_code $pgm_args";
            $pgm_path = $pgm_interp;
        }
        else {
            print "\nWarning, interpretor not found for bat file: $pgm_path\n";
        }
    }
    $pgm_path =~ tr|\/|\\| if $main::OS_win;
    return ( $pgm_path, $pgm_args );
}

# Returns milliseconds
sub main::get_tickcount {
    my $time;
    if ($main::OS_win) {
        $time = Win32::GetTickCount;
    }
    else {
        if ( $main::Info{HiRes} ) {
            my ( $sec, $usec ) = &main::gettimeofday();    # From Time::HiRes
            $time = 1000 * $sec + $usec / 1000;
        }
        else {
            $time = time * 1000;
        }
    }
    $time += 2**32
      if $time < 0;  # This wraps to negative after 25 days.  Resets after 49 :(
    return $time;
}

sub main::logit {
    my ( $log_file, $log_data, $log_format, $head_tail ) = @_;
    $log_format = 14 unless defined $log_format;
    unless ( $log_format == 0 ) {
        $log_data =~ s/[\n\r]+/ /g;    # So log only takes one line.
        my $time_date = &main::time_date_stamp($log_format);
        $log_data = "$time_date $log_data\n";
    }
    if ( $head_tail and -e $log_file ) {
        open( LOG, $log_file )
          or print "Warning, could not open log file $log_file: $!\n";
        my @data = <LOG>;
        unshift @data, $log_data;
        open( LOG, ">$log_file" )
          or print "Warning, could not open log file $log_file: $!\n";
        print LOG @data;
    }
    else {
        open( LOG, ">>$log_file" )
          or print "Warning, could not open log file $log_file: $!\n";
        print LOG $log_data;
    }
    close LOG;
}

# Old names
sub main::read_dbm {
    &main::dbm_read(@_);
}

sub main::search_dbm {
    &main::dbm_search(@_);
}

sub main::dbm_write {
    my ( $log_file, $log_key, $log_data ) = @_;
    my ( $log_count, %DBM );
    if ($log_key) {

        # Assume we have already done use DB_File in calling program
        #  - we want to make sure we can still call this when perl is not installed
        use Fcntl;
        tie( %DBM, 'DB_File', $log_file, O_RDWR | O_CREAT, 0666 )
          or print "\nError, can not open dbm file $log_file: $!";
        ($log_count) = $DBM{$log_key} =~ /^(\S+)/;
        $DBM{$log_key} = $log_data;

        #       print "Db dbm key=$log_key count=$log_count data=$log_data\n";
        dbmclose %DBM;
    }
}

# Like dbm_write, but also keeps a tally of accesses
sub main::logit_dbm {
    my ( $log_file, $log_key, $log_data ) = @_;
    my ( $log_count, %DBM );
    if ($log_key) {

        # Assume we have already done use DB_File in calling program
        #  - we want to make sure we can still call this when perl is not installed
        use Fcntl;
        tie( %DBM, 'DB_File', $log_file, O_RDWR | O_CREAT, 0666 )
          or print "\nError, can not open dbm file $log_file: $!";

        ($log_count) = $DBM{$log_key} =~ /^(\S+)/;
        $DBM{$log_key} = ++$log_count . ' ' . $log_data;

        #       print "Db dbm key=$log_key count=$log_count data=$log_data\n";
        dbmclose %DBM;
    }
}

sub main::dbm_read {
    my ( $dbm_file, $key ) = @_;
    use Fcntl;
    my %DBM_search;
    tie( %DBM_search, 'DB_File', $dbm_file, O_RDWR | O_CREAT, 0666 )
      or print "\nError in dbm_read, can not open dbm file $dbm_file: $!\n";
    if ($key) {
        my $value = $DBM_search{$key};
        dbmclose %DBM_search;
        return $value;
    }
    else {
        return %DBM_search;
    }
}

sub main::dbm_search {
    my ( $dbm_file, $string ) = @_;
    my @results;
    my ( $key, $value );
    use Fcntl;
    my %DBM_search;
    tie( %DBM_search, 'DB_File', $dbm_file, O_RDWR | O_CREAT, 0666 )
      or print "\nError in dbm_search, can not open dbm file $dbm_file: $!\n";

    my ( $count1, $count2 );
    $count1 = $count2 = 0;
    while ( ( $key, $value ) = each %DBM_search ) {
        $count1++;
        if ( !$string or $key =~ /$string/i or $value =~ /$string/i ) {
            $count2++;
            push( @results, $key, $value );
        }
    }
    dbmclose %DBM_search;
    return ( $count1, $count2, @results );
}

sub main::memory_used {
    return unless $^O eq 'MSWin32' and Win32::IsWinNT;

    #   use Win32::PerfLib;
    #   &main::my_use('Win32::PerfLib');
    # Find process ref of ourself (230 is Process counter)
    # Note: this changes with time, so we must reget every time
    # GetObjectList takes 180 ms :(.  Total find_mem time is 200 ms
    # Got the Counter indexes via Win32::PerfLib::GetCounterNames
    my $perflib = Win32::PerfLib->new('');

    #    my $perflib = new Win32::PerfLib;
    my $proc_ref = {};
    $perflib->GetObjectList( 230, $proc_ref );
    $perflib->Close();

    my ( $perf_pid, $perf_mem_virt, $perf_mem_real, $perf_cpu );
    my $instance_ref = $proc_ref->{Objects}->{230}->{Instances};
    for my $p ( keys %{$instance_ref} ) {
        my $counter_ref = $instance_ref->{$p}->{Counters};

        # Find pointer to ourself
        for my $i ( keys %{$counter_ref} ) {

            # counter ID Process=784
            if (    $counter_ref->{$i}->{CounterNameTitleIndex} == 784
                and $counter_ref->{$i}->{Counter} == $$ )
            {
                $perf_pid = $p;
            }
        }

        # Now find pointer to memory counter
        if ($perf_pid) {
            for my $i ( keys %{$counter_ref} ) {

                # counter Working Set=180
                if ( $counter_ref->{$i}->{CounterNameTitleIndex} == 180 ) {
                    $perf_mem_real = $counter_ref->{$i}->{Counter};
                }

                # counter Page File Bytes=184
                if ( $counter_ref->{$i}->{CounterNameTitleIndex} == 184 ) {
                    $perf_mem_virt = $counter_ref->{$i}->{Counter};
                }

                # Could not figure out how to get %cpu used
                # counter % Processor Time=6  (/10**7 for seconds)
                # counter % Privileged Time=144
                # counter % User Time=142

                # counter % Total Processor Time=240
                # counter Current % Processor Time=1502
                # counter Total mSec - Processor=1522

                if ( $counter_ref->{$i}->{CounterNameTitleIndex} == 6 ) {
                    $perf_cpu = $counter_ref->{$i}->{Counter};

                    #                   print "db2 p=$p i=$i\n";
                }
            }
        }
        last if $perf_pid;
    }
    return ( $perf_mem_virt / 1024000, $perf_mem_real / 1024000,
        $perf_cpu / 10**7 );
}

sub main::my_use {
    my ($module) = @_;
    eval "use $module";
    if ($@) {
        print "\nError in loading module=$module:\n  $@";
        print
          "\n - See install.html for instructions on how to install perl module $module\n\n";
    }
    return $@;
}

#---------------------------------------------------------------------------
#   parse a string into blank delimited arguments
#
sub main::parse_arg_string {
    my ($arg_string) = @_;
    my ( $arg, @args, $i );

    # Split command string into arguments, allowing for quoted strings
    while ($arg_string) {
        ( $arg, $arg_string ) = $arg_string =~ /(\S+)\s*(.*)/;
        if ( substr( $arg, 0, 1 ) eq '"' ) {
            $i = index( $arg_string, '"' );
            $arg .= ' ' . substr( $arg_string, 0, $i + 1 );
            $arg_string = substr( $arg_string, $i + 1 );

            #       print "db2 i=$i arg=$arg command=$arg_string...\n";
        }
        push( @args, $arg );
    }

    #   print "db args=", join("\n", @args);
    return @args;
}

sub main::plural {
    my ( $value, $des ) = @_;
    $des .= 's' if abs($value) != 1;
    return "$value $des";
}

sub main::plural2 {
    my ($value) = @_;
    my $suffix;
    my $r = $value % 10;

    # 11,12,13 are excptions.  th-ify them
    if ( $value > 10 and $value < 21 ) {
        $suffix = 'th';
    }
    elsif ( $r == 1 ) {
        $suffix = 'st';
    }
    elsif ( $r == 2 ) {
        $suffix = 'nd';
    }
    elsif ( $r == 3 ) {
        $suffix = 'rd';
    }
    else {
        $suffix = 'th';
    }
    return $value . $suffix;
}

# Un-pluralize something if there is only one of them
sub main::plural_check {
    my ($text) = @_;
    if ( $text =~ /(\d+)/ and abs $1 == 1 ) {
        $text =~ s/s(\.?)$/$1/;
        $text =~ s/ are / is /;
    }
    return $text;
}

=item write_mh_opts

This function will add or edit Misterhouse parameters in the user's ini file. 
It will make a backup of the ini file, and it doesn't remove any comments 
in the file.  The first argument is a hash of parameters to set.  The second 
(optional) argument is the ini file you want to modify, and the third 
(optional) argument is set to 1 if you want to log the change. 

Examples:

  write_mh_opts({"photo_dir" -> $state}, undef, 1);
  write_mh_opts(%parms);

=cut

sub main::read_mh_opts {
    my ( $ref_parms, $pgm_path, $debug, $parm_file ) = @_;
    $debug = 0 unless $debug;

    my @parm_files;
    push @parm_files, $parm_file if $parm_file;
    push @parm_files, "$pgm_path/mh.ini";
    push @parm_files, "$pgm_path/mh.private.ini";
    push @parm_files, split ',', $ENV{mh_parms} if $ENV{mh_parms};

    print "Reading parm files: @parm_files\n" if $debug;
    for my $file (@parm_files) {
        next unless -e $file;
        print "  Reading parm file: $file\n" if $debug;
        &main::read_opts( $ref_parms, $file, $debug, $pgm_path . '/..' );
    }

    # Look for parm values that reference other vars (e.g.  $config_parms{data_dir}/data/email)
    # Need to do this AFTER all the parms are read in, so we can eval correctly
    package main;    # So the evals work ok with main vars
    for my $parm ( keys %$ref_parms ) {
        my $value = $$ref_parms{$parm};

        # Just do config parms ... this function is called by lots
        # of programs (e.g. get_url), so other mh vars are not always there.
        # Also do:  $Version, $Pgm_Path, $Pgm_Name, $Pgm_Root, and %Info
        # Avoid doing this to all .ini records, since some have built in $vars,
        # like this example:  irrigation_watering_day_alg=((($Mday % 2) == 1) || ($Mday == 31))

        if ( $value and $value =~ /(\$config_parms|\$Version|\$Pgm_|\$Info)/ ) {

            #       if ($value and $value =~ /\$config_parms/) {
            #       if ($value) {
            # Do this, since %config_parms may be a 'my' var, which can not
            # be change directly outside of the main program.
            $value =~ s/\$config_parms/\$\$ref_parms/g;
            print
              "read_mh_opts .ini parm evaled:  parm==$parm\n   value=$value\n"
              if $debug;
            eval "\$value = qq[$value]";
            print "   value=$value\n" if $debug;
            $$ref_parms{$parm} = $value;
        }
    }

    return @parm_files;
}

sub main::read_opts {
    my ( $ref_parms, $config_file, $debug, $pgm_root ) = @_;
    my ( $key, $value, $value_continued );
    $pgm_root = $main::Pgm_Root unless $pgm_root;

    # If debug == 0 (instead of undef) this is disabled
    print "Reading config_file $config_file\n"
      unless defined $debug and $debug == 0;
    open( CONFIG, "$config_file" )
      or print "\nError, could not read config file: $config_file\n";
    while (<CONFIG>) {
        next if /^\s*[\#\@]/;

        # Allow for multi-line values records
        # Allow for key => value continued data
        if (    $key
            and ($value) = $_ =~ /^\s+([^\#\@]+)/
            and $value !~ /^\s*\S+=[^\>]/ )
        {
            $value_continued = 1;
        }

        # Look for normal key=value records
        else {
            next unless ( $key, $value ) = $_ =~ /(\S+?)\s*=\s*(.*)/;
            if ($value) {
                $value =~ s/^[\#\@].*//;    # Delete end of line comments
                $value =~ s/\s+[\#\@].*//;
            }
            $value_continued = 0;
            next unless $key;
        }

        $value =~ s/\s+$//;                 # Delete end of value blanks

        # substitue in $vars in the .ini file
        #  - older perl does not eval to main::value :(
        #    so we do it the hard way
        #  - We can probably skip this now, as we
        #    now do evals above in mh_read_opts.
        if ( $value =~ /\$Pgm_Root/ ) {
            $value =~ s/\$Pgm_Root/$pgm_root/g;

            #           eval "\$value = qq[$value]";
        }

        # Last parm wins (in case we reload parm file)
        if ($value_continued) {
            $$ref_parms{$key} .= $value;
        }
        else {
            $$ref_parms{$key} = $value;

            # This is the main mh/bin/mh.ini parmfile
            if ( $config_file eq './mh.ini' ) {
                delete $$ref_parms{ $key . "_MHINTERNAL_filename" };
            }
            else {
                $$ref_parms{ $key . "_MHINTERNAL_filename" } = $config_file;
            }
        }
        print main::STDOUT
          "parm vc=$value_continued key=$key value=$$ref_parms{$key} file=$config_file\n"
          if $debug;
    }
    close CONFIG;
    return sort keys %{$ref_parms};
}

# Read a key/value string into a hass: key1 => value, key2 => value2

sub main::read_parm_hash {
    my ( $ref, $data, $preserve_case, $ref2 ) = @_;
    for my $temp ( split ',', $data ) {
        if ( my ( $key, $value ) = $temp =~ / *(.+?) *=> *(.+)/ ) {
            $value =~ s/ *$//;    # Drop trailing blanks
            $key = lc $key unless $preserve_case;
            $$ref{$key} = $value;
            push @$ref2, $key if $ref2;

            #           print "db key=$key, value=$value.\n";
        }
        else {
            print "Error parsing key => value string: t=$temp.\n";
        }
    }
}

sub main::get_parm_file {
    my ( $ref_parms, $param_name ) = @_;

    #   print "Test=" . $param_name . ":" . $$ref_parms{$param_name} . ":" . $$ref_parms{$param_name . "_MHINTERNAL_filename"} . "\n";
    return $$ref_parms{ $param_name . '_MHINTERNAL_filename' };
}

sub main::randomize_list {

    # Do a fisher yates shuffle (Perl cookbook 4.17 pg 121)
    for ( my $i = @_; --$i; ) {
        my $j = int rand( $i + 1 );
        @_[ $i, $j ] = @_[ $j, $i ];
    }
}

# Set 3rd parameter to 1 to return the last record if the index is out of
# range.  Otherwise, the first record will be returned.
sub main::read_record {
    my ( $file, $index, $last_when_out_of_range ) = @_;

    my $record = '';
    if ( lc($index) eq 'random' ) {
        my (@records);
        open( DATA, $file )
          or print "Error, could not open read_record file: $file\n";
        @records = <DATA>;
        close DATA;
        $index = 1 + int( ($#records) * rand );
        $record = $records[ $index - 1 ];
    }
    else {
        open( DATA, $file )
          or print "Error, could not open read_record file: $file\n";
        my $line;
        my $count = 0;
        my $first;
        while ( $line = <DATA> ) {
            $count++;
            if ( not $last_when_out_of_range and ( $count == 1 ) ) {
                $first = $line;
            }
            if ( $count == $index ) {
                $record = $line;
                last;
            }
        }
        close DATA;

        # Default to the last record if index wasn't found
        unless ($record) {
            if ($last_when_out_of_range) {
                $record = $line;
                $index  = $count;
            }
            else {
                $record = $first;
                $index  = 1;
            }
        }
    }
    chomp $record;
    return ( $record, $index );
}

#---------------------------------------------------------------------------
#   Win32 Registry
#---------------------------------------------------------------------------

sub main::registry_get {
    my ( $key, $subkey ) = @_;

    return unless $main::OS_win;

    return unless my $ptr = &main::registry_open($key);
    my %values;
    return unless $ptr->GetValues( \%values );
    my $key2 = $values{$subkey};
    my ( $name, $type, $value ) = @$key2 if $key2;

    # Valid types (from learning perl on win32): REG_SZ, DWORD, MULTI_SZ, EXPAND_SZ, and BINARY
    #    my $value2;
    #    if ($type eq REG_SZ) {
    #   $value2 = $value;
    #    }
    #    elsif ($type eq REG_DWORD) {
    #   $value2 = unpack('H8', $value);
    #    }
    #    elsif ($type eq REG_BINARY) {
    #   $value2 = $value;
    #    }
    #   print "name=$name, type=$type, value=$value\n";
    return $value;
}

sub main::registry_set {
    my ( $key, $subkey, $type, $value ) = @_;

    return unless my $ptr = &main::registry_open($key);

    #   Don't know how to pass type in directly :(
    #    $type = 1 if $type eq "REG_SZ";
    #    $type = 3 if $type eq "REG_BINARY";
    #    $type = 4 if $type eq "REG_DWORD";

    my $rc = $ptr->SetValueEx( $subkey, 0, $type, $value );

    print "Registry key $subkey updated to $value, rc=$rc\n";
}

sub main::registry_open {

    #   use Win32::Registry;

    my ($key) = @_;

    my ( $key1, $key2, $ptr );
    ( $key1, $key2 ) = $key =~ /(HKEY_LOCAL_MACHINE)\\(.+)/;
    ( $key1, $key2 ) = $key =~ /(HKEY_USERS)\\(.+)/ unless $key2;
    ( $key1, $key2 ) = $key =~ /(HKEY_CURRENT_USER)\\(.+)/ unless $key2;
    ( $key1, $key2 ) = $key =~ /(HKEY_CLASSES_ROOT)\\(.+)/ unless $key2;
    ( $key1, $key2 ) = $key =~ /(HKEY_PERFORMANCE_DATA)\\(.+)/ unless $key2;
    ( $key1, $key2 ) = $key =~ /(HKEY_PERFORMANCE_TEXT)\\(.+)/ unless $key2;
    ( $key1, $key2 ) = $key =~ /(HKEY_PERFORMANCE_NLSTEXT)\\(.+)/ unless $key2;

    #   print "type=$type value=$value key1=$key1, key2=$key2\n";
    unless ($key2) {
        print "Error, key not valid: $key\n";
    }
    no strict 'refs';

    #   print "key1=$key1 key2=$key2\n";
    unless ( ${"main::$key1"}->Open( $key2, $ptr ) ) {
        print "Error, could not open registry key $key: $!\n";
        return;
    }
    use strict 'refs';

    return $ptr;
}

sub main::round {
    my ( $number, $digits ) = @_;
    $digits = 0 unless $digits;
    $number = 0 unless $number;
    $number =~ s/,//g;
    return $number
      unless $number =~ /^[\d\. \-\+]+$/;    # Leave none-numeric data alone

    # If $digits <  10, it means round to that many decimals
    # If $digits >= 10, it means round to the nearest $digits
    if ( $digits >= 10 ) {
        return $digits * int( $number / $digits );
    }
    else {
        return sprintf( "%.${digits}f", $number );
    }
}

#---------------------------------------------------------------------------
#   Run commands in a seperate process
#

my @Processes;

sub main::run_kill_processes {
    for my $ptr (@Processes) {
        my ( $process, $pgm ) = @$ptr;
        if ($main::OS_win) {
            unless ( $process->Wait(0) ) {
                print "Killing unfinished run process $process, pgm=$pgm\n";
                $process->Kill(1)
                  or print "Warning , run can not kill process:",
                  Win32::FormatMessage( Win32::GetLastError() ), "\n";
            }
        }
        else {
            # These were detatched, not forked, so no pid to kill ... maybe should fork??
        }
    }
}

# If you want more control (e.g. detect when done), use Process_Item.pm
sub main::run {
    my ( $mode, $pgm, $no_log, $no_check ) = @_;

    # Mode is optional ... yuck ... optional parms should be last!
    unless ( $mode eq 'inline' ) {
        $no_log = $pgm;
        $pgm    = $mode;
    }

    if ($main::OS_win) {
        my ( $pgm_path, $pgm_args ) = &main::find_pgm_path($pgm);

        unless ($pgm_path) {
            warn "Program not found: $pgm";
            return;
        }
        print "Running: $pgm_path args=$pgm_args\n"
          unless $main::config_parms{no_log} =~ /run/ or $no_log;

        my ( $cflag, $process );

        # See note in Process_Item.pm about $cflag, kill, and .bat files.
        #       use Win32::Process;
        #       $cflag = DETACHED_PROCESS | CREATE_NEW_CONSOLE;
        #       $cflag = DETACHED_PROCESS;
        #       $cflag = NORMAL_PRIORITY_CLASS;
        $cflag = 0;    # Avoid uninit warnings

        my $pgm_path2 = $pgm_path;
        $pgm_path2 = "\"$pgm_path2\"" if $pgm_path2 =~ /\x20/;

        my $pid =
          Win32::Process::Create( $process, $pgm_path, "$pgm_path2 $pgm_args",
            0, $cflag, '.' )
          or print
          "Warning, run error: pgm_path=$pgm_path\n  -   pgm=$pgm   error=",
          Win32::FormatMessage( Win32::GetLastError() ), "\n";
        push( @Processes, [ $process, $pgm ] );

        $process->Wait(10000) if $mode eq 'inline';    # Wait for process
        return $process;
    }
    else {
        # This will look for pgms in mh/bin, even if it is
        # not in the path
        my ( $pgm_path, $pgm_args ) = &main::find_pgm_path($pgm);
        $pgm = "$pgm_path $pgm_args";
        $pgm .= " &" unless $mode eq 'inline';
        print "Running: $pgm\n"
          unless $main::config_parms{no_log} =~ /run/ or $no_log;
        system($pgm) == 0
          or print "Warning, run system error:  pgm=$pgm rc=$?\n";
    }
}

# This uses 'start' command to detatch
sub main::run_old {
    my ( $mode, $pgm ) = @_;
    $pgm = $mode unless $pgm;    # Mode is optional

    if ($main::OS_win) {

        # Running system will leave a CMD window up after it has finished :(
        # Unless ... you use cmd /c :)
        # Need to use cmd with nt??
        $pgm = qq[command "/e:4000 /c $pgm"]
          ;    # Do this so the cmd window dissapears after the command is done

        my $start = '';
        $start = 'start /min';
        $start = 'start /max' if $mode eq 'max';
        $start = '' if $mode eq 'inline';
        $pgm   = "$start $pgm";
    }
    else {
        $pgm = "./$pgm";    # Not all systems have the current dir in the path
        $pgm .= " &" unless $mode eq 'inline';
    }
    print "\nrunning command: $pgm\n";
    system($pgm) == 0 or print "Warning, run system error: pgm=$pgm rc=$?\n";
}

# Leave these other attempts at run for furture reference
my $comment_out = <<'eof';

sub main::run_old_win32_iproc {
    my($mode, $pgm) = @_;
    $pgm = $mode unless $pgm;   # Mode is optional

    use Win32::IProc
        qw( SW_SHOWNORMAL SW_SHOWDEFAULT SW_SHOWMAXIMIZED SW_MINIMIZE SW_HIDE SW_SHOW SW_MAXIMIZE FOREGROUND_RED
            FOREGROUND_GREEN FOREGROUND_BLUE BACKGROUND_RED BACKGROUND_GREEN BACKGROUND_BLUE
            FOREGROUND_INTENSITY NORMAL_PRIORITY_CLASS PROCESS_ALL_ACCESS INHERITED NONINHERITED FLOAT
            DIGITAL NULL CREATE_NEW_CONSOLE CREATE_NEW_PROCESS_GROUP);
    my $cflag = CREATE_NEW_CONSOLE;
    my $obj=new Win32::IProc || warn "Error, could not create process in hand_utilities run: $!\n";
    my $Attributes =FOREGROUND_RED | BACKGROUND_RED | BACKGROUND_GREEN | BACKGROUND_BLUE;
    my $Title ="Welcome to the world of Perl";
    $obj->Create(NULL, $pgm, INHERITED, $cflag, ".",
                 $Title, SW_SHOWDEFAULT, 200,200,600,300, $Attributes);

    &Win32::Sleep(100);        # Must let window appear before we can find its handle
    my $window_handle;
    $obj->GetForegroundHwnd(\$window_handle);
    $obj->ShowWindow($window_handle, SW_MINIMIZE);

    $obj->Wait(4000) if $mode eq 'inline'; # Wait for process
}

sub main::run_old2 {
    my($command) = @_;
    my(@command);
    # hmmm, maybe we don't need to do this anymore??  lets take it out and see.

    # We must do this ultra messy thing to get by the apparent
    # limit that perl has.  It truncates strings passed via `` or system at about 100 characters :(

    # We need to do this or else the " gets absorbed by the system command
    # so that a keyword like -subject "hi there" turns out as -subject hi there
#    $command =~ s/\"/\\\"/g;

#    while ($command) {
#        $i = index($command, " ", 40);
#        $i = 9999 if $i < 0;
#       push (@command, substr($command, 0, $i));
#   $command = substr($command, $i);
#    }

    print "\nrunning command: ", join("", @command), "\n" if $main::opt_verbose;
#   print `$command`;
#   print `@command`;
#    system(@command);
    system($command);
}
eof

#---------------------------------------------------------------------------
#   run another perl program via 'do'.  This is more efficient and
#       avoids the problem of perl not reading long ARGV strings from DOS.
#
sub main::run_perl {
    my ($command) = @_;

    @ARGV = &main::parse_arg_string($command);
    my $perl_pgm = shift @ARGV;

    print "\nrunning perl command: ", join( "^", $perl_pgm, @ARGV ), "\n";

    #   $0 = $perl_pgm;   $0 gets truncated for some wierd reason ... leave it alone
    my $perl_pgm_path = $ENV{'house_menu_path'} . '/bin';
    unshift( @INC, $perl_pgm_path )
      unless grep( ( $_ eq $perl_pgm_path ), @INC );
    do $perl_pgm or print "Error, could not find $perl_pgm\n";
    print "Done with $perl_pgm\n";
}

sub main::speakify_numbers {
    my ($number) = @_;
    my ( $digit, $suffix );
    $digit = substr( $number, -1 );
    if ( $digit == 1 ) {
        $suffix = 'st';
    }
    elsif ( $digit == 2 ) {
        $suffix = 'nd';
    }
    elsif ( $digit == 3 ) {
        $suffix = 'rd';
    }
    else {
        $suffix = 'th';
    }
    return $number . $suffix;
}

sub main::speakify_list {
    my (@list) = @_;

    # Uniqify list and concatonate to make a, b and c
    my ( %seen, $string );
    @list = grep { !$seen{$_}++ and $_ } @list;
    if ( @list < 2 ) {
        $string = "@list";
    }
    elsif ( @list == 2 ) {
        $string = "$list[0] and $list[1]";
    }
    else {
        my $last = $#list;
        $string = join( ', ', @list[ 0 .. $last - 1 ] ) . ", and $list[$last]";
    }
    return $string;
}

sub main::time_date_stamp {

    # This could be done much easier with use Date ... but here we have more flexablilty
    #  - Note:  If mh.ini parm time_format=24, the AM/PM formats are skipped

    # Here are the different styles:
    #  1:  Sunday, 12/25/99  01:52 PM
    #  2:  Sunday Dec 25 13:52 1999 (seems to be more compatable with javascript parsing)
    #  3:  Sunday, Dec 25 at 1 PM
    #  4:   1:52 PM on Sunday, Dec 25
    #  5:   1:52 PM
    #  6:  Sun, Dec 25
    #  7:  Sun 01:52PM
    #  8:   1:52  (skip the AM PM)
    #  9:  12/25/99  01:52 PM
    # 10:  1999_12 year_month, with leading 0, so log files are sorted ok (e.g. 97_01)
    # 11:  12/25/99
    # 12:  12/25/99 13:52:24
    # 13:  13:52:24
    # 14:  Sun 12/25/99 13:52:24
    # 15:  Sunday, December 25th
    # 16:  04/14/97  2:28:00 PM
    # 17:  2001-04-09 14:05:16  (POSIX strftime format)
    # 18:  YYYYMMDD (e.g. 20011201)
    # 19:  Sun, 06 Nov 1994 08:49:37 GMT  (RFC 822 format, needed by web servers)
    # 20:  YYYYMMDDHHMMSS
    # 21:  12:52 Sun 25 (For short time/date displays)
    # 22:  Sun, Dec 25 1:52 PM
    # 23:  relative to now (eg, 6 seconds ago, 4 hours from now, yesterday, etc)

    my ( $style, $time_or_file ) = @_;
    my $time;
    if ($time_or_file) {
        if ( $time_or_file =~ /^\d+$/ ) {
            $time = int $time_or_file;
        }
        elsif ( -e $time_or_file ) {
            $time = ( stat($time_or_file) )[9];
        }
        else {
            return undef;    # File does not exist
        }
    }
    else {
        $time = time;
    }

    my @time_data = ( $style == 19 ) ? gmtime($time) : localtime($time);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) =
      @time_data[ 0, 1, 2, 3, 4, 5, 6 ];

    my ( $day, $day_long, $month, $month_long, $year_full, $time_date_stamp,
        $time_ampm, $ampm );

    $day = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" )[$wday];
    $day_long = (
        "Sunday",   "Monday", "Tuesday",  "Wednesday",
        "Thursday", "Friday", "Saturday", "Sunday"
    )[$wday];
    $month = (
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    )[$mon];
    $month_long = (
        "January",   "February", "March",    "April",
        "May",       "June",     "July",     "August",
        "September", "October",  "November", "December"
    )[$mon];
    $mon++;

    $year_full = $year + 1900;
    $year_full += 100 if $year_full < 1970;

    $style = 1 unless $style;

    # Do NOT convert to AMPM if time_format=24
    $ampm = '';
    unless ( $main::config_parms{time_format} == 24
        or $style == 2
        or $style == 12
        or $style == 13
        or $style == 14
        or $style == 17 )
    {
        ( $time_ampm, $hour, $min, $ampm ) = &main::time_to_ampm("$hour:$min");
    }

    my $year_format;
    if ( $main::config_parms{date_format} =~ /yyyy/ ) {
        $year_format = "%04d";
        $year += 1900;
    }
    else {
        $year_format = "%02d";
        $year = substr( $year, 1, 2 ) if $year > 99;
    }
    my @day_month =
        ( $main::config_parms{date_format} =~ /ddmm/ )
      ? ( $mday, $mon )
      : ( $mon, $mday );

    if ( $style == 1 ) {
        $time_date_stamp = sprintf( "%s, %02d/%02d/$year_format  %02d:%02d %s",
            $day_long, @day_month, $year, $hour, $min, $ampm );
    }
    elsif ( $style == 2 ) {
        $time_date_stamp = sprintf( "%s %s %02d %02d:%02d %s",
            $day_long, $month, $mday, $hour, $min, $year_full );
    }
    elsif ( $style == 3 ) {
        $time_date_stamp = sprintf( "%s, %s %02d at %2d %s",
            $day_long, $month, $mday, $hour, $ampm );
    }
    elsif ( $style == 4 ) {
        $time_date_stamp = sprintf( "%2d:%02d %s on %s, %s %02d",
            $hour, $min, $ampm, $day_long, $month, $mday );
    }
    elsif ( $style == 5 ) {
        $time_date_stamp = sprintf( "%2d:%02d %s", $hour, $min, $ampm );
    }
    elsif ( $style == 6 ) {
        $time_date_stamp = sprintf( "%s, %s %2d", $day, $month, $mday );
    }
    elsif ( $style == 7 ) {
        $time_date_stamp =
          sprintf( "%s %02d:%02d%s", $day, $hour, $min, $ampm );
    }
    elsif ( $style == 8 ) {
        $time_date_stamp = sprintf( "%2d:%02d", $hour, $min );
    }
    elsif ( $style == 9 ) {
        $time_date_stamp = sprintf( "%02d/%02d/$year_format  %02d:%02d %s",
            @day_month, $year, $hour, $min, $ampm );
    }
    elsif ( $style == 10 ) {
        $time_date_stamp = sprintf( "%04d_%02d", $year_full, $mon );
    }
    elsif ( $style == 11 ) {
        $time_date_stamp =
          sprintf( "%02d/%02d/$year_format", @day_month, $year );
    }
    elsif ( $style == 12 ) {
        $time_date_stamp = sprintf( "%02d/%02d/$year_format %02d:%02d:%02d",
            @day_month, $year, $hour, $min, $sec );
    }
    elsif ( $style == 13 ) {
        $time_date_stamp = sprintf( "%02d:%02d:%02d", $hour, $min, $sec );
    }
    elsif ( $style == 14 ) {
        $time_date_stamp = sprintf( "%s %02d/%02d/$year_format %02d:%02d:%02d",
            $day, @day_month, $year, $hour, $min, $sec );
    }
    elsif ( $style == 15 ) {
        $time_date_stamp =
          sprintf( "%s, %s %s", $day_long, $month_long, &main::plural2($mday) );
    }
    elsif ( $style == 16 ) {
        $time_date_stamp = sprintf( "%02d/%02d/$year_format %02d:%02d:%02d %s",
            @day_month, $year, $hour, $min, $sec, $ampm );
    }
    elsif ( $style == 17 ) {
        $time_date_stamp = sprintf( "%s-%02d-%02d %02d:%02d:%02d",
            $year_full, $mon, $mday, $hour, $min, $sec );
    }
    elsif ( $style == 18 ) {
        $time_date_stamp = sprintf( "%04d%02d%02d", $year_full, $mon, $mday );
    }
    elsif ( $style == 19 ) {
        $time_date_stamp = sprintf( "%s, %2d %s %4d %02d:%02d:%02d GMT",
            $day, $mday, $month, $year_full, $hour, $min, $sec );
    }
    elsif ( $style == 20 ) {
        $time_date_stamp = sprintf( "%04d%02d%02d%02d%02d%02d",
            $year_full, $mon, $mday, $hour, $min, $sec );
    }
    elsif ( $style == 21 ) {
        $time_date_stamp = sprintf( "%2d:%02d $day $mday", $hour, $min );
    }
    elsif ( $style == 22 ) {
        $time_date_stamp = sprintf( "%s, %s %2d %2d:%02d%s",
            $day, $month, $mday, $hour, $min, $ampm );
    }
    elsif ( $style == 23 ) {
        my $diff = $time - $main::Time;
        my $past;
        $past = 1 if $diff < 0;
        $diff = abs $diff;
        my $a_day   = 24 * 60 * 60;
        my $a_week  = 7 * $a_day;
        my $a_month = 30 * $a_day;
        my $a_year  = 365 * $a_day;
        my (
            $now_sec, $now_min,  $now_hour, $now_mday,
            $now_mon, $now_year, $now_wday
        ) = localtime();
        my $today = &::timelocal( 0, 0, 0, $now_mday, $now_mon, $now_year );
        my $tomorrow = $today + $a_day;
        my $twodayshence   = $today + 2 * $a_day;
        my $yesterday      = $today - $a_day;
        my $thisweek       = $today - $now_wday * $a_day;
        my $nextweek       = $thisweek + $a_week;
        my $twoweekshence  = $thisweek + 2 * $a_week;
        my $lastweek       = $thisweek - $a_week;
        my $thismonth      = &::timelocal( 0, 0, 0, 1, $now_mon, $now_year );
        my $nextmonth      = $thismonth + $a_month;
        my $twomonthshence = $thismonth + 2 * $a_month;
        my $lastmonth      = $thismonth - $a_month;
        my $thisyear       = &::timelocal( 0, 0, 0, 1, 0, $now_year );
        my $nextyear       = $thisyear + $a_year;
        my $twoyearshence  = $thisyear + 2 * $a_year;
        my $lastyear       = $thisyear - $a_year;

        if ( $diff < 60 ) {
            $time_date_stamp =
              "$diff Seconds " . ( $past ? "ago" : "from now" );
        }
        elsif ( $diff < 120 ) {
            $time_date_stamp = "1 Minute " . ( $past ? "ago" : "from now" );
        }
        elsif ( $diff < 60 * 70 ) {
            my $t = &::round( $diff / 60 );
            $time_date_stamp = "$t Minutes " . ( $past ? "ago" : "from now" );
        }
        elsif ( ( $time > $today and $time < $tomorrow )
            or $diff < 12 * 60 * 60 )
        {
            my $t = &::round( $diff / ( 60 * 60 ) );
            $time_date_stamp =
                "$t Hour"
              . ( $t != 1 ? "s "  : " " )
              . ( $past   ? "ago" : "from now" );
        }
        elsif ( $past and $time > $yesterday ) {
            $time_date_stamp =
              "Yesterday at " . sprintf( "%2d:%02d %s", $hour, $min, $ampm );
        }
        elsif ( not $past and $time < $twodayshence ) {
            $time_date_stamp =
              "Tomorrow at " . sprintf( "%2d:%02d %s", $hour, $min, $ampm );
        }
        elsif ( ( $time > $thisweek and $time < $nextweek )
            or $diff < 4 * $a_day )
        {
            my $t = int( $diff / ($a_day) + 1 );
            $time_date_stamp =
                "$t Day"
              . ( $t != 1 ? "s "  : " " )
              . ( $past   ? "ago" : "from now" );
        }
        elsif ( $past and $time > $lastweek ) {
            $time_date_stamp = "Last Week";
        }
        elsif ( not $past and $time < $twoweekshence ) {
            $time_date_stamp = "Next Week";
        }
        elsif ( ( $time > $thismonth and $time < $nextmonth )
            or $diff < 3 * $a_week )
        {
            my $t = int( $diff / ($a_week) + 1 );
            $time_date_stamp =
                "$t Week"
              . ( $t != 1 ? "s "  : " " )
              . ( $past   ? "ago" : "from now" );
        }
        elsif ( $past and $time > $lastmonth ) {
            $time_date_stamp = "Last Month";
        }
        elsif ( not $past and $time < $twomonthshence ) {
            $time_date_stamp = "Next Month";
        }
        elsif ( ( $time > $thisyear and $time < $nextyear )
            or $diff < 4 * $a_month )
        {
            my $t = int( $diff / ($a_month) + 1 );
            $time_date_stamp =
                "$t Month"
              . ( $t != 1 ? "s "  : " " )
              . ( $past   ? "ago" : "from now" );
        }
        elsif ( $past and $time > $lastyear ) {
            $time_date_stamp = "Last Year";
        }
        elsif ( not $past and $time < $twoyearshence ) {
            $time_date_stamp = "Next Year";
        }
        else {
            my $t = int( $diff / ($a_year) + 1 );
            $time_date_stamp =
                "$t Year"
              . ( $t != 1 ? "s "  : " " )
              . ( $past   ? "ago" : "from now" );
        }
    }
    else {
        $time_date_stamp = "time_date_stamp format=$style not recognized";
    }
    return wantarray
      ? (
        $time_date_stamp, $sec, $min, $hour, $ampm,
        $day_long, $mon, $mday, $year
      )
      : $time_date_stamp;
}

sub main::time_add {
    my ($time_date) = @_;
    my $time2 = &main::my_str2time($time_date);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime($time2);
    $time_date = sprintf( "%d:%02d", $hour, $min );
    return $time_date;
}

sub main::time_diff {
    my ( $time1, $time2, $nearest_unit, $format ) = @_;
    my (
        $diff,  $nu,    $seconds, $minutes, $hours, $days,
        $weeks, $years, @diff,    $last,    $string
    );
    $diff = abs( $time2 - $time1 );

    undef $nu;
    $nu = 1 if lc($nearest_unit) eq 'second';
    $nu = 2 if lc($nearest_unit) eq 'minute';
    $nu = 3 if lc($nearest_unit) eq 'hour';
    $nu = 4 if lc($nearest_unit) eq 'day';
    $nu = 5 if lc($nearest_unit) eq 'week';
    $nu = 6 if lc($nearest_unit) eq 'year';

    # If unit not specified, pick according to size of differences
    unless ($nu) {
        if ( $diff < 5 * 60 ) {
            $nu = 1;
        }
        elsif ( $diff < 5 * 60 * 60 ) {
            $nu = 2;
        }
        elsif ( $diff < 5 * 60 * 60 * 24 ) {
            $nu = 3;
        }
        elsif ( $diff < 5 * 60 * 60 * 24 * 7 ) {
            $nu = 4;
        }
        elsif ( $diff < 5 * 60 * 60 * 24 * 7 * 52 ) {
            $nu = 5;
        }
        else {
            $nu = 6;
        }
    }

    $seconds = abs( $time2 - $time1 );
    $minutes = int( $seconds / 60 );
    $seconds -= 60 * $minutes;
    $hours = int( $minutes / 60 );
    $minutes -= 60 * $hours;
    $days = int( $hours / 24 );
    $hours -= 24 * $days;
    $weeks = int( $days / 7 );
    $days -= 7 * $weeks;
    $years = int( $weeks / 52 );
    $weeks -= 52 * $years;

    if ( $format eq 'numeric' ) {
        $string = sprintf(
            "%3d days %02d:%02d:%02d",
            7 * ( 52 * $years + $weeks ) + $days,
            $hours, $minutes, $seconds
        );
    }
    else {
        undef @diff;
        push( @diff, &main::plural( $years, "year" ) ) if $years;
        push( @diff, &main::plural( $weeks, "week" ) ) if $weeks and $nu < 6;
        push( @diff, &main::plural( $days,  "day" ) )  if $days and $nu < 5;
        push( @diff, &main::plural( $hours, "hour" ) ) if $hours and $nu < 4;
        push( @diff, &main::plural( $minutes, "minute" ) )
          if $minutes and $nu < 3;
        push( @diff, &main::plural( $seconds, "second" ) )
          if $seconds and $nu < 2;

        $last = pop @diff;
        if ( @diff > 0 ) {
            $string = join( ', ', @diff ) . " and $last";
        }
        else {
            $string = $last;
        }
        $string = '0 seconds' if $time1 == $time2;
    }

    #   $string .= ($time2 > $time1) ? ' ago' : ' from now';
    $string = "unknown time.  time2=$time2 time1=$time1 diff=$diff"
      unless $string;    # debug
    return $string;
}

sub main::time_to_ampm {
    my ($time) = @_;
    my ( $hour, $min ) = split( ":", $time );
    my $ampm = ( $hour < 12 ) ? "AM" : "PM";
    $hour -= 12 if $hour > 12;
    $hour = 12 if $hour == 0;
    return wantarray
      ? ( "$hour:$min $ampm", $hour, $min, $ampm )
      : "$hour:$min $ampm";
}

sub main::uniqify {
    my %list = map { $_, 1 } @_;
    return sort keys %list;
}

# Magic from pg. 237 of Programing Perl
#  - Probably better to use uuencode_base64 from Mime::Base64
sub main::uudecode {
    my ($string) = @_;
    $string =~ tr#A-Za-z0-9+/##cd;
    $string =~ tr#A-Za-z0-9+/# -_#;
    my $len = pack( "c", 32 + 0.75 * length($string) );
    return unpack( "u", $len . $string );
}

sub main::which {
    my ($pgm) = @_;

    # Not sure if ; is allow for in unix paths??
    my @paths =
      ($main::OS_win)
      ? split( ';',      $ENV{PATH} )
      : split( /[\:\;]/, $ENV{PATH} );
    for
      my $path ( $main::config_parms{bin_dir}, ".", "$main::Pgm_Path", @paths )
    {
        chop $path if $path =~ /\\$/;    # Drop trailing slash
        my $pgm_path = "$path/$pgm";
        if ($main::OS_win) {
            return "$pgm_path.bat" if -f "$pgm_path.bat";
            return "$pgm_path.exe" if -f "$pgm_path.exe";
            return "$pgm_path.com" if -f "$pgm_path.com";
        }
        return $pgm_path if -f $pgm_path;
    }
    return $pgm if -f $pgm;              # Covers the fully qualified $pgm name
    return;                              # Didn't find it
}

# Update ini parameters without changing order or removing comments
sub main::write_mh_opts {
    my ( $ref_parms, $pgm_root, $debug, $parm_file ) = @_;
    $debug = 0 unless $debug;
    $pgm_root = $main::Pgm_Root unless $pgm_root;

    unless ($parm_file) {
        ($parm_file) = split ',', $ENV{mh_parms} if $ENV{mh_parms};
        $parm_file = "$pgm_root/bin/mh.private.ini" unless $parm_file;
    }

    print "Reading config_file $parm_file\n" if $debug;
    open( INI_PARMS, "$parm_file" )
      or print "\nError, could not read config file: $parm_file\n", return 0;

    my ( $key, @parms, @done, $in_multiline );
    while ( my $line = <INI_PARMS> ) {

        # Remove old continuation lines from edited entries
        if ($in_multiline) {
            if ( $line =~ /^\s+[^#@\s]/ ) {
                next;
            }
            else {
                $in_multiline = 0;
            }
        }

        # Remove any repeats of edited entries
        foreach $key (@done) {
            if ( $line =~ /^$key\s*=/ ) {
                $in_multiline = 1;
                next;
            }
        }

        # Update changed entries
        foreach $key ( keys %$ref_parms ) {
            if ( $line =~ s/^$key\s*=.*/$key=$$ref_parms{$key}/ ) {
                delete $$ref_parms{$key};
                push @done, $key;
                $in_multiline = 1;
            }
        }

        # Compile new file entries
        push @parms, $line;
    }
    close INI_PARMS;

    # Re-write entire file if changes effect existing entries
    &main::file_backup( $parm_file, "copy" );
    if (@done) {
        print "Writing config_file $parm_file\n" if $debug;
        open( INI_PARMS, ">$parm_file" )
          or print "\nError, could not write config file: $parm_file\n",
          return 0;
        print INI_PARMS @parms;
        close INI_PARMS;
    }

    # Append any new parameters
    if (%$ref_parms) {
        print "Appending to config_file $parm_file\n" if $debug;
        open( INI_PARMS, ">>$parm_file" )
          or print "\nError, could not append to config file: $parm_file\n",
          return 0;
        foreach $key ( keys %$ref_parms ) {
            print INI_PARMS "$key=$$ref_parms{$key}\n";
        }
        close INI_PARMS;
    }
}

# returns a sorted array of hashes containing idle time data for
# items of the type (or inherited type) that is passed in
sub main::get_idle_item_data {
    my ($idle_types) = @_;
    my $time         = $main::Time;
    my %idle_items   = {};
    for my $object_type (&main::list_object_types) {
        for my $object_name ( &main::list_objects_by_type($object_type) ) {
            my $object =
              ( ref $object_name )
              ? $object_name
              : &main::get_object_by_name($object_name);
            foreach my $idle_type ( split( /,/, $idle_types ) ) {
                if ( $object->isa($idle_type) ) {
                    my $name = $object->get_object_name;
                    $name =~ s/^\$//;    # strip the $
                    my $idleduration = $object->get_idle_time;
                    my $idlehours =
                      sprintf( "%d", $idleduration / ( 60 * 60 ) );
                    my $idleminutes =
                      sprintf( "%d", ( $idleduration % ( 60 * 60 ) ) / 60 );
                    my $idleseconds = ( $idleduration % ( 60 * 60 ) ) % 60;
                    my $timeidle = $idleseconds . " seconds"
                      if defined($idleduration);
                    $timeidle = $idleminutes . " minutes and " . $timeidle
                      if $idleminutes;
                    $timeidle = $idlehours . " hours and " . $timeidle
                      if $idlehours;
                    $timeidle = "(unknown)" unless $timeidle;

                    $idle_items{$name}{name}      = $name;
                    $idle_items{$name}{idle}      = $idleduration;
                    $idle_items{$name}{idle_text} = $timeidle;
                    $idle_items{$name}{class}     = $idle_type;
                }
            }
        }
    }

    my @idle_data =
      sort { $idle_items{$a}{idle} <=> $idle_items{$b}{idle} } keys %idle_items;
    my @results = ();

    foreach my $key (@idle_data) {
        if ($key) {
            push @results, \%{ $idle_items{$key} };
        }
    }

    return @results;
}

#print " done\n";

1;

#
# $Log: handy_utilities.pl,v $
# Revision 1.79  2006/01/29 20:30:17  winter
# *** empty log message ***
#
# Revision 1.78  2005/05/22 18:13:06  winter
# *** empty log message ***
#
# Revision 1.77  2005/03/20 19:02:02  winter
# *** empty log message ***
#
# Revision 1.76  2005/01/23 23:21:45  winter
# *** empty log message ***
#
# Revision 1.75  2004/11/22 22:57:26  winter
# *** empty log message ***
#
# Revision 1.74  2004/09/25 20:01:19  winter
# *** empty log message ***
#
# Revision 1.73  2004/07/18 22:16:37  winter
# *** empty log message ***
#
# Revision 1.72  2004/07/05 23:36:37  winter
# *** empty log message ***
#
# Revision 1.71  2004/06/06 21:38:44  winter
# *** empty log message ***
#
# Revision 1.70  2004/05/02 22:22:17  winter
# *** empty log message ***
#
# Revision 1.69  2004/04/25 18:20:16  winter
# *** empty log message ***
#
# Revision 1.68  2004/03/23 01:58:08  winter
# *** empty log message ***
#
# Revision 1.67  2003/11/23 20:26:01  winter
#  - 2.84 release
#
# Revision 1.66  2003/07/06 17:55:12  winter
#  - 2.82 release
#
# Revision 1.65  2003/03/09 19:34:42  winter
#  - 2.79 release
#
# Revision 1.64  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.63  2003/01/18 03:32:42  winter
#  - 2.77 release
#
# Revision 1.62  2003/01/12 20:39:21  winter
#  - 2.76 release
#
# Revision 1.61  2002/12/24 03:05:08  winter
# - 2.75 release
#
# Revision 1.60  2002/12/02 04:55:20  winter
# - 2.74 release
#
# Revision 1.59  2002/09/22 01:33:24  winter
# - 2.71 release
#
# Revision 1.58  2002/08/22 04:33:20  winter
# - 2.70 release
#
# Revision 1.57  2002/07/01 22:25:28  winter
# - 2.69 release
#
# Revision 1.56  2002/05/28 13:07:52  winter
# - 2.68 release
#
# Revision 1.55  2002/03/02 02:36:51  winter
# - 2.65 release
#
# Revision 1.54  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.53  2001/11/18 22:51:43  winter
# - 2.61 release
#
# Revision 1.52  2001/10/21 01:22:32  winter
# - 2.60 release
#
# Revision 1.51  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.50  2001/06/27 03:45:14  winter
# - 2.54 release
#
# Revision 1.49  2001/05/28 21:14:38  winter
# - 2.52 release
#
# Revision 1.48  2001/04/15 16:17:21  winter
# - 2.49 release
#
# Revision 1.47  2001/02/24 23:26:40  winter
# - 2.45 release
#
# Revision 1.46  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.45  2001/01/20 17:47:50  winter
# - 2.41 release
#
# Revision 1.44  2000/12/03 19:38:55  winter
# - 2.36 release
#
# Revision 1.43  2000/11/12 21:02:38  winter
# - 2.34 release
#
# Revision 1.42  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.41  2000/10/09 02:31:13  winter
# - 2.30 update
#
# Revision 1.40  2000/10/01 23:29:40  winter
# - 2.29 release
#
# Revision 1.39  2000/09/09 21:19:11  winter
# - 2.28 release
#
# Revision 1.38  2000/08/19 01:25:08  winter
# - 2.27 release
#
# Revision 1.37  2000/06/24 22:10:55  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.36  2000/03/10 04:09:01  winter
# - Add Ibutton support and more web changes
#
# Revision 1.35  2000/02/20 04:47:55  winter
# -2.01 release
#
# Revision 1.34  2000/02/12 06:11:37  winter
# - commit lots of changes, in preperation for mh release 2.0
#
# Revision 1.33  2000/01/27 13:52:23  winter
# - update version number
#
# Revision 1.32  2000/01/13 13:41:18  winter
# - added find_pgm_path to run
#
# Revision 1.31  2000/01/02 23:47:03  winter
# - added plural2, and update time_date_stamp
#
# Revision 1.30  1999/12/13 00:04:17  winter
# - add date_format and file_cat
#
# Revision 1.29  1999/11/21 02:56:07  winter
# - modify logit $log_format.
#
# Revision 1.28  1999/11/08 02:22:41  winter
# - make time_date_stamp more efficient
#
# Revision 1.27  1999/10/09 20:39:07  winter
# - add read_dbm.  Take out use DB_file
#
# Revision 1.26  1999/10/02 22:41:36  winter
# - add search_dbm
#
# Revision 1.25  1999/09/27 03:18:24  winter
# - added read_mh_opts
#
# Revision 1.24  1999/09/12 16:57:24  winter
# - add binmode LOG on file read/write
#
# Revision 1.23  1999/08/30 00:24:03  winter
# - add binmode on file_read.
#
# Revision 1.22  1999/08/02 02:25:44  winter
# - move -e $pgm check which to the bottom
#
# Revision 1.21  1999/08/01 01:29:47  winter
# - add test for -e $pgm in which
#
# Revision 1.20  1999/07/21 21:15:26  winter
# - add my_use
#
# Revision 1.19  1999/07/05 22:35:44  winter
# - fix a file_head bug
#
# Revision 1.18  1999/06/27 20:17:29  winter
# - close misc handles
#
# Revision 1.17  1999/06/20 22:33:41  winter
# - check for overflow in get_tickcount
#
# Revision 1.16  1999/05/30 21:08:26  winter
# - fix bugs in get_tickcount and file_or_file check
#
# Revision 1.15  1999/04/29 12:19:54  winter
# - improve process kill on exit errata
#
# Revision 1.14  1999/03/28 00:33:42  winter
# - avoid Process Flags
#
# Revision 1.13  1999/03/21 17:33:15  winter
# - add find_pgm_path. Change run to use it.  Add various file_ subs
#
# Revision 1.12  1999/03/12 04:25:39  winter
# - use dbmopen, so perl2exe works
#
# Revision 1.11  1999/02/25 14:27:58  winter
# - allow for current path in which function
#
# Revision 1.10  1999/02/21 00:24:21  winter
# - add uudecode.  Allow time_date_stamp to work on files
#
# Revision 1.9  1999/02/16 02:05:15  winter
# - update run method to use process instead of system
#
# Revision 1.8  1999/02/08 00:29:47  winter
# - allow for unix use of the run function
#
# Revision 1.7  1999/02/01 00:08:09  winter
# - fix $mon++ bug.  Change read_parms to 'last wins'
#
# Revision 1.6  1999/01/30 19:53:22  winter
# -add file_write, like fileit.  Add file_read
#
# Revision 1.5  1999/01/23 16:32:48  winter
# - allow loading from non-windows boxes
#
# Revision 1.4  1999/01/10 02:30:19  winter
# - move old_error_check to mh (no Win32 here)
#
# Revision 1.3  1999/01/09 21:42:50  winter
# - put subs in alphabetic order
#
# Revision 1.2  1999/01/07 01:59:04  winter
# - allow time_date_stamp to return a scalar
#
# Revision 1.1  1998/12/08 02:25:09  winter
# - renamed ... I CAN speell :)
#
# Revision 1.3  1998/09/16 13:04:44  winter
# - do not override existing parm on ref_parms
#
#

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Bruce Winter    bruce@misterhouse.net

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

