#---------------------------------------------------------------------------
#  File:
#      handy_utilities.pl
#  Description:
#      Handy utilities of all shapes and sizes
#  Author:
#      Bruce Winter    bruce@misterhouse.net
#  Latest version:
#      http://misterhouse.net/mh/lib/handy_utilities.pl
#  Change log:
#    11/03/96  Created.
#
#---------------------------------------------------------------------------

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
sub Win32::DriveInfo::DrivesInUse;

package handy_utilities;
use strict;

sub main::batch {
    my(@cmds) = @_;
    my($bat_counter, $temp_dir, $bat_file, $cmd);
    $bat_counter = 0;
    $temp_dir = $main::config_parms{temp_dir};
    $temp_dir = $ENV{'TEMP'} unless -d $temp_dir;
    $temp_dir = $ENV{'TMP'}  unless -d $temp_dir;
    $temp_dir = "."          unless -d $temp_dir;
    do {
        $bat_counter++;
        $bat_file = "$temp_dir\\batch_commands.$bat_counter.bat";
    } until !-e $bat_file;
    open (BAT, ">$bat_file") or die "Error, can not open bat command file $bat_file: $!\n";
    print BAT "echo on\n";
    foreach $cmd (@cmds) {
        print BAT $cmd  . "\n";
    }
#   print BAT ":exit\necho on\ndel $bat_file\nexit\n";
    close BAT;
    system("start /min command /c $bat_file"); # Use cmd so the console will disappear when done ... exit after delete doesn't work :(
#   system("start /min cmd /c $bat_file"); # Use cmd so the console will disappear when done ... exit after delete doesn't work :(
}


sub main::fileit {              # Same as file_write
    my ($file, $data) = @_;
    open(LOG, ">$file") or print "Warning, could not open fileit file $file: $!\n";
    print LOG $data . "\n";
    close LOG;
}

sub main::file_head {
    my ($file, $records) = @_;
    my @head;
    open(DATA, $file) or print "head function error, could not open $file: $!\n";
    $records = 3 unless $records;
    while ($records--) {
        my $record = <DATA>;
        push(@head, $record);
    }
    close DATA;
    return wantarray ? @head : join('', @head);
}

sub main::file_tail {
    my ($file, $records) = @_;
    my @tail;
    open(DATA, $file) or print "tail function error, could not open $file: $!\n";

                                # Get the last few lines of a file
    $records = 3 unless $records;
    seek DATA, -1000, 2;
    @tail = (<DATA>)[-$records..-1];
    close DATA;
    return wantarray ? @tail : "@tail";
}

sub main::file_read {
    my ($file) = @_;
    open(LOG, "$file") or print "Warning, could not open file_read file $file: $!\n";
    binmode LOG;
    
    if (wantarray) {
        my @data = <LOG>;
        close LOG;
        return @data;
    }
                                # Read is faster than <> (?)
    else {
        my ($data, $buffer);
        while (read(LOG, $buffer, 8*2**10)) {
            $data .= $buffer;
        }
        close LOG;
        return $data;
    }
}

sub main::file_write {          # Same as fileit
    my ($file, $data) = @_;
    open(LOG, ">$file") or print "Warning, could not open file_write $file: $!\n";
    binmode LOG;
    print LOG $data;
#   print LOG $data . "\n";
    close LOG;
}

sub main::file_cat {
    my ($file1, $file2) = @_;
    open(LOG1, "$file1")   or print "Warning, could not open file_cat $file1: $!\n";
    open(LOG2, ">>$file2") or print "Warning, could not open file_cat $file2: $!\n";
    binmode LOG1;
    binmode LOG2;
    while (<LOG1>) {
        print LOG2 $_;
    }
    close LOG1;
    close LOG2;
}

                                # Used by &run and Process_Item ... must find pgm source for Win32::process
sub main::find_pgm_path {
    my($pgm) = @_;
                                # Windows programs with blanks in the name are a problem :(
                                # Can not distinguish a program blank from an argument blank!
    my ($pgm_path, $pgm_args) = $pgm =~ /^(\S+) ?(.*)/;
#   print "db pgm_path=$pgm_path\n";

    unless($pgm_path = &main::which($pgm_path)) {
        print "Warning, new Process:  Can not find path to pgm=$pgm_path args=$pgm_args\n";
#       return;
    }
                                # This is in desperation ... see notes on &run and &process_item $cflag. 
                                # We must avoid .bat files on order to make processes killable :(
    if ($main::OS_win and $pgm_path =~ /bat$/ and &main::file_head($pgm_path) =~ /mh -run (\S+)/) {
        my $perl_code = $1;
        my $pgm_interp;
        if ($pgm_interp = &main::which('mh.exe')) {
            $pgm_args = "-run $perl_code $pgm_args";
            $pgm_path = $pgm_interp;
        }
        elsif ($pgm_interp = &main::which('perl.exe')) {
            $pgm_args = "$perl_code $pgm_args";
            $pgm_path = $pgm_interp;
        }
        else {
            print "\nWarning, interpretor not found for bat file: $pgm_path\n";
        }
    }
    $pgm_path =~ tr|\/|\\| if $main::OS_win;
    return ($pgm_path, $pgm_args);
}


sub main::get_tickcount {
    if ($main::OS_win) {
        my $time = Win32::GetTickCount;
        $time += 2**32 if $time < 0; # This wraps to negative after 25 days.  Resets after 49 :(
        return $time;
    }
    else {
        my $time = time;
        return $time * 1000;            # Need subsecond clock on unix!
    }
}



sub main::logit {
    my ($log_file, $log_data, $log_format) = @_;
    $log_format = 14 unless defined $log_format;
    open(LOG, ">>$log_file") or print "Warning, could not open log file $log_file: $!\n";
    if ($log_format == 0) {
        print LOG $log_data;
    }
    else {
        my $time_date = &main::time_date_stamp($log_format);
        $log_data =~ s/[\n\r]+/ /g; # So log only takes one line.
        print LOG "$time_date $log_data\n";
    }
    close LOG;
}

sub main::logit_dbm {
    my ($log_file, $log_key, $log_data) = @_;
    my ($log_count, %DBM);
    if ($log_key) {

                                # Assume we have already done use DB_File in calling program
                                #  - we want to make sure we can still call this when perl is not installed
        use Fcntl;
        tie (%DBM, 'DB_File',    $log_file, O_RDWR|O_CREAT, 0666) or print "\nError, can not open dbm file $log_file: $!";

        ($log_count) = $DBM{$log_key} =~ /^(\S+)/;
        $DBM{$log_key} = ++$log_count . ' ' . $log_data;
#       print "Db dbm key=$log_key count=$log_count data=$log_data\n";
        dbmclose %DBM;
    }
}

sub main::read_dbm {
    my ($dbm_file, $key) = @_;
    use Fcntl;
    my %DBM_search;
    tie (%DBM_search,  'DB_File',  $dbm_file,  O_RDWR|O_CREAT, 0666) or
        print "\nError in search_dbm, can not dbm file $dbm_file: $!\n";
    if ($key) {
        my $value = $DBM_search{$key};
        dbmclose %DBM_search;
        return $value;
    }
    else {
        return %DBM_search;
    }
}

sub main::search_dbm {
    my ($dbm_file, $string) = @_;
    my @results;
    my ($key, $value);
    use Fcntl;
    my %DBM_search;
    tie (%DBM_search,  'DB_File',  $dbm_file,  O_RDWR|O_CREAT, 0666) or
        print "\nError in search_dbm, can not dbm file $dbm_file: $!\n";

    my ($count1, $count2);
    $count1 = $count2 = 0;
    while (($key, $value) = each %DBM_search) {
        $count1++;
        if ($key =~ /$string/i or $value =~ /$string/i) {
            $count2++;
            push(@results, $key, $value);
        }
    }
    dbmclose %DBM_search;
    return ($count1, $count2, @results);
}

sub main::my_use {
    my($module) = @_;
    eval "use $module";
    if ($@) {
        print "\nError in loading module=$module:\n  $@";
        print " - See install.html for instructions on how to install perl module $module\n\n";
    }
    return $@;
}

#---------------------------------------------------------------------------
#   parse a string into blank delimited arguments
#
sub main::parse_arg_string {
    my($arg_string) = @_;
    my($arg, @args, $i);

    # Split command string into arguments, allowing for quoted strings
    while ($arg_string) {
        ($arg, $arg_string) = $arg_string =~ /(\S+) *(.*)/;
        if (substr($arg, 0, 1) eq '"') {
            $i = index($arg_string, '"');
            $arg .= ' ' . substr($arg_string, 0, $i+1);
            $arg_string = substr($arg_string, $i+1);
#       print "db2 i=$i arg=$arg command=$arg_string...\n";
        }
        push (@args, $arg);
    }
#   print "db args=", join("\n", @args);
    return @args;
}

sub main::plural {
    my($value, $des) = @_;
    $des .= 's' if abs($value) != 1;
    return "$value $des";
}
sub main::plural2 {
    my($value) = @_;
    my $suffix;
	my $r = $value % 10;
                                # 11,12,13 are excptions.  th-ify them
    if ($value > 10 and $value < 21) {
        $suffix = 'th';
    }        
    elsif ($r == 1) {
        $suffix = 'st';
    }
    elsif ($r == 2) {
        $suffix = 'nd';
    }
    elsif ($r == 3) {
        $suffix = 'rd';
    }
    else {
        $suffix = 'th';
    }
    return $value . $suffix;
}
                                # Un-pluralize something if there is only one of them
sub main::plural_check {
    my($text) = @_;
    if ($text =~ /(\d+)/ and abs $1 == 1) {
        $text =~ s/s\.?$//;
        $text =~ s/ are / is /;
    }
    return $text;
}


sub main::read_mh_opts {
    my($ref_parms, $Pgm_Path, $debug) = @_;
    my $private_parms = $Pgm_Path . "/mh.private.ini";
    $private_parms = $ENV{mh_parms} if $ENV{mh_parms};
    &main::read_opts($ref_parms, $Pgm_Path . "/mh.ini", $debug, $Pgm_Path . '/..');
    &main::read_opts($ref_parms, $private_parms, $debug, $Pgm_Path . '/..') if -e $private_parms;
}

sub main::read_opts {
    my($ref_parms, $config_file, $debug, $pgm_root) = @_;
    my($key, $value);
    $pgm_root = $main::Pgm_Root unless $pgm_root;
    print "Reading config_file $config_file\n";
    open (CONFIG, "$config_file") or print "\nError, could not read config file $config_file\n";
    while (<CONFIG>) {
        next if /^\#/;
        ($key, $value) = $_ =~ /(\S+?) *= *([^\#]+)/;
        next unless $key;

        $value =~ s/\s+$//;   # Delete end of value blanks

        if ($value =~ /\$Pgm_Root/) {
            # substitue in $vars in the .ini file 
            #  - older perl does not eval to main::value :(
            #    so we do it the hard way
            $value =~ s/\$Pgm_Root/$pgm_root/;
#       eval "\$value = qq[$value]";
        }

                                # Last parm wins (in case we reload parm file)
#        next if defined $$ref_parms{$key};
        $$ref_parms{$key} = $value;
        print "parm key=$key value=$value\n" if $debug;
    }
    close CONFIG;
    return sort keys %{$ref_parms};
}

sub main::read_record {
    my($file, $index) = @_;
    my(@records);

                                # Note, we could be more clever here and use the trick on page 284 of the 
                                # perl cookbook to read a random line without saving all records from 
                                # the file.  

    open(DATA, $file) or print "Error, could not open read_record file: $file\n";
    @records = <DATA>;
    close DATA;

    if (lc($index) eq 'random') {
        srand(time);
        $index = 1 + int((@records) * rand);
    }
    else {
        $index = 1 if $index > @records;
    }
    my $record = $records[$index - 1];
    chomp $record;
    return ($record, $index);
}

#---------------------------------------------------------------------------
#   Win32 Registry 
#---------------------------------------------------------------------------

sub main::registry_get {
    my($key, $subkey) = @_;

    return unless $main::OS_win;

    return unless my $ptr = &main::registry_open($key);
    my %values;
    return unless $ptr->GetValues(\%values);
    my $key2 = $values{$subkey};
    my ($name, $type, $value) = @$key2 if $key2;

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
    my($key, $subkey, $type, $value) = @_;

    return unless my $ptr = &main::registry_open($key);

#   Don't know how to pass type in directly :(
#    $type = 1 if $type eq "REG_SZ";
#    $type = 3 if $type eq "REG_BINARY";
#    $type = 4 if $type eq "REG_DWORD"; 

    my $rc = $ptr->SetValueEx($subkey, 0, $type, $value);

    print "Registry key $subkey updated to $value, rc=$rc\n";
}

sub main::registry_open {

#   use Win32::Registry;
    
    my($key) = @_;

    my ($key1, $key2, $ptr);
    ($key1, $key2) = $key =~ /(HKEY_LOCAL_MACHINE)\\(.+)/;
    ($key1, $key2) = $key =~ /(HKEY_USERS)\\(.+)/ unless $key2;
    ($key1, $key2) = $key =~ /(HKEY_CURRENT_USER)\\(.+)/ unless $key2;
    ($key1, $key2) = $key =~ /(HKEY_CLASSES_ROOT)\\(.+)/ unless $key2;
    ($key1, $key2) = $key =~ /(HKEY_PERFORMANCE_DATA)\\(.+)/ unless $key2;
    ($key1, $key2) = $key =~ /(HKEY_PERFORMANCE_TEXT)\\(.+)/ unless $key2;
    ($key1, $key2) = $key =~ /(HKEY_PERFORMANCE_NLSTEXT)\\(.+)/ unless $key2;

#   print "type=$type value=$value key1=$key1, key2=$key2\n";
    unless ($key2) {
        print "Error, key not valid: $key\n";
    }
    no strict 'refs';
#   print "key1=$key1 key2=$key2\n";
    unless (${"main::$key1"}->Open($key2, $ptr)) {
    print "Error, could not open registry key $key: $!\n";
    return;
}
use strict 'refs';

return $ptr;
}

sub main::round {
    my($number, $digits) = @_;
    $digits = 0 unless $digits;
    $number = 0 unless $number;
    return $number unless $number =~ /^[\d\. \-\+]+$/;  # Leave none-numeric data alone
    return sprintf("%.${digits}f", $number);
}

#---------------------------------------------------------------------------
#   Run commands in a seperate process
#

my @Processes;

sub main::run_kill_processes {
    for my $ptr (@Processes) {
        my ($process, $pgm) = @$ptr;
        if ($main::OS_win) {
            unless ($process->Wait(0)) {
                print "Killing unfinished run process $process, pgm=$pgm\n";
                $process->Kill(1) or print "Warning , run can not kill process:", Win32::FormatMessage( Win32::GetLastError() ), "\n";
            }
        }
        else {
                                # These were detatched, not forked, so no pid to kill ... maybe should fork??
        }
    }
}


                                # This is depreciated ... use Process_Item.pm instead
sub main::run {
    my($mode, $pgm) = @_;
    $pgm = $mode unless $pgm;   # Mode is optional

    print "\nrunning command: $pgm\n";

    if ($main::OS_win) {

                                # Dang, Process::Create needs full path name ... use our handy perl which function
        my($pgm_path, $pgm_args) = &main::find_pgm_path($pgm);

        print "Running: pgm=$pgm_path args=$pgm_args\n";

        my ($cflag, $process);

                                # See note in Process_Item.pm about $cflag, kill, and .bat files.
#       use Win32::Process;
#       $cflag = DETACHED_PROCESS | CREATE_NEW_CONSOLE;
#       $cflag = DETACHED_PROCESS;
#       $cflag = NORMAL_PRIORITY_CLASS;

        my $pid = Win32::Process::Create($process, $pgm_path, "$pgm_path $pgm_args", 0, $cflag, '.') or
            print "Warning, run error: pgm_path=$pgm_path\n  -   pgm=$pgm   error=", Win32::FormatMessage( Win32::GetLastError() ), "\n";
        push(@Processes, [$process, $pgm]);

        $process->Wait(10000) if $mode eq 'inline'; # Wait for process
        return $process;
    }
    else {
                                # This will look for pgms in mh/bin, even if that is 
                                # not not in the path
        my($pgm_path, $pgm_args) = &main::find_pgm_path($pgm);
        $pgm = "$pgm_path $pgm_args";
        $pgm .= " &" unless $mode eq 'inline';
        system($pgm) == 0 or print "Warning, run system error:  pgm=$pgm rc=$?\n";
    }
}

                                # This uses 'start' command to detatch
sub main::run_old {
    my($mode, $pgm) = @_;
    $pgm = $mode unless $pgm;   # Mode is optional

    if ($main::OS_win) {
                                # Running system will leave a CMD window up after it has finished :(
                                # Unless ... you use cmd /c :)
                                # Need to use cmd with nt??
        $pgm = qq[command "/e:4000 /c $pgm"];   # Do this so the cmd window dissapears after the command is done
                            
        my $start = '';
        $start = 'start /min';
        $start = 'start /max' if $mode eq 'max';
        $start = ''           if $mode eq 'inline';
        $pgm = "$start $pgm";
    }
    else {
        $pgm = "./$pgm";        # Not all systems have the current dir in the path
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
        my($command) = @_;
        
        @ARGV = &main::parse_arg_string($command);
        my $perl_pgm = shift @ARGV;

        print "\nrunning perl command: ", join("^", $perl_pgm, @ARGV), "\n";
#   $0 = $perl_pgm;   $0 gets truncated for some wierd reason ... leave it alone
        my $perl_pgm_path = $ENV{'house_menu_path'} . '/bin';
        unshift(@INC, $perl_pgm_path) unless grep(($_ eq $perl_pgm_path), @INC);
        do $perl_pgm or print "Error, could not find $perl_pgm\n";
        print "Done with $perl_pgm\n";
    }


sub main::speakify_numbers {
    my($number) = @_;
    my($digit, $suffix);
    $digit = substr($number, -1);
    if ($digit == 1) {
        $suffix = 'st';
    }
    elsif ($digit == 2) {
        $suffix = 'nd';
    }
    elsif ($digit == 3) {
        $suffix = 'rd';
    }
    else {
        $suffix = 'th';
    }
    return $suffix;
}

sub main::speakify_list {
    my(@list) = @_;
    # Uniqify list and concatonate to make a, b and c
    my (%seen, $string);
    @list = grep {!$seen{$_}++ and $_} @list;
    if (@list < 2) {
        $string = "@list";
    }
    elsif (@list == 2) {
        $string = "$list[0] and $list[1]";
    }
    else {
        my $last = $#list;
        $string = join(', ', @list[0..$last-1]) . ", and $list[$last]";
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

    my($style, $time_or_file) = @_;
    my $time;
    if ($time_or_file) {
        if ($time_or_file =~ /^\d+$/) {
            $time = int $time_or_file;
        }
        elsif (-e $time_or_file) {
            $time = (stat($time_or_file))[9];
        }
        else {
            return undef;       # File does not exist
        }
    }
    else {
        $time = time;
    }

    my($sec, $min, $hour, $mday, $mon, $year, $wday) = (localtime($time))[0,1,2,3,4,5,6];
    my($day, $day_long, $month, $month_long, $year_full, $time_date_stamp, $time_ampm, $ampm);

    $day        = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")[$wday];
    $day_long   = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")[$wday];
    $month      = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")[$mon];
    $month_long = ("January", "Febuary", "March", "April", "May", "June",
                  "July", "August", "September", "October", "November", "December")[$mon];
    $mon++;

    $year_full = $year + 1900;
    $year_full += 100 if $year_full < 1970;

    $style = 1 unless $style;
    
                                # Do NOT convert to AMPM if time_format=24
    unless ($main::config_parms{time_format} == 24 or $style == 2 or $style == 12 or $style == 13 or $style == 14) {
        ($time_ampm, $hour, $min, $ampm) = &main::time_to_ampm("$hour:$min");
    }
    
    my $year_format;
    if ($main::config_parms{date_format} =~ /yyyy/) {
        $year_format = "%04d";
        $year += 1900;
    }
    else {
        $year_format = "%02d";
        $year = substr($year, 1, 2) if $year > 99;
    }
    my @day_month = ($main::config_parms{date_format} =~ /ddmm/) ? ($mday, $mon) : ($mon, $mday);

    if ($style == 1) {$time_date_stamp = sprintf("%s, %02d/%02d/$year_format  %02d:%02d %s",
                               $day_long, @day_month, $year, $hour, $min, $ampm) }
    elsif ($style == 2) {$time_date_stamp = sprintf("%s %s %02d %02d:%02d %s",
                               $day_long, $month, $mday, $hour, $min, $year_full) }
    elsif ($style == 3) {$time_date_stamp = sprintf("%s, %s %02d at %2d %s",
                               $day_long, $month, $mday, $hour, $ampm) }
    elsif ($style == 4) {$time_date_stamp = sprintf("%2d:%02d %s on %s, %s %02d",
                               $hour, $min, $ampm, $day_long, $month, $mday) }
    elsif ($style == 5) {$time_date_stamp = sprintf("%2d:%02d %s",
                               $hour, $min, $ampm) }
    elsif ($style == 6) {$time_date_stamp = sprintf("%s, %s %2d",
                               $day, $month, $mday) }
    elsif ($style == 7) {$time_date_stamp = sprintf("%s %02d:%02d%s",
                               $day, $hour, $min, $ampm) }
    elsif ($style == 8) {$time_date_stamp = sprintf("%2d:%02d",
                               $hour, $min) }
    elsif ($style == 9) {$time_date_stamp = sprintf("%02d/%02d/$year_format  %02d:%02d %s",
                               @day_month, $year, $hour, $min, $ampm) }
    elsif ($style == 10) {$time_date_stamp = sprintf("%04d_%02d", $year_full, $mon) }
    elsif ($style == 11) {$time_date_stamp = sprintf("%02d/%02d/$year_format", @day_month, $year) }
    elsif ($style == 12) {$time_date_stamp = sprintf("%02d/%02d/$year_format %02d:%02d:%02d",
                               @day_month, $year, $hour, $min, $sec) }
    elsif ($style == 13) {$time_date_stamp = sprintf("%02d:%02d:%02d",
                               $hour, $min, $sec) }
    elsif ($style == 14) {$time_date_stamp = sprintf("%s %02d/%02d/$year_format %02d:%02d:%02d",
                               $day, @day_month, $year, $hour, $min, $sec) }
    elsif ($style == 15) {$time_date_stamp = sprintf("%s, %s %s",
                               $day_long, $month_long, &main::plural2($mday)) }

    return wantarray ? ($time_date_stamp, $sec, $min, $hour, $ampm, $day_long, $mon, $mday, $year) : $time_date_stamp;
}

sub main::time_diff {
    my($time1, $time2, $nearest_unit, $format) = @_;
    my($diff, $nu, $seconds, $minutes, $hours, $days, $weeks, $years, @diff, $last, $string);
    $diff = abs($time2 - $time1);

    undef $nu;
    $nu = 1 if lc($nearest_unit) eq 'second';
    $nu = 2 if lc($nearest_unit) eq 'minute';
    $nu = 3 if lc($nearest_unit) eq 'hour';
    $nu = 4 if lc($nearest_unit) eq 'day';
    $nu = 5 if lc($nearest_unit) eq 'week';
    $nu = 6 if lc($nearest_unit) eq 'year';
    # If unit not specified, pick according to size of differences
    unless ($nu) {
        if ($diff < 5 * 60) {
            $nu = 1;
        }
        elsif ($diff < 5 * 60 * 60) {
            $nu = 2;
        }
        elsif ($diff < 5 * 60 * 60 * 24) {
            $nu = 3;
        }
        elsif ($diff < 5 * 60 * 60 * 24 * 7) {
            $nu = 4;
        }
        elsif ($diff < 5 * 60 * 60 * 24 * 7 * 52) {
            $nu = 5;
        }
        else {
            $nu = 6;
        }
    }

    $seconds = abs($time2 - $time1);
    $minutes = int($seconds / 60);
    $seconds -= 60 * $minutes;
    $hours   = int($minutes / 60);
    $minutes -= 60 * $hours;
    $days    = int($hours / 24);
    $hours   -= 24 * $days;
    $weeks   = int($days / 7);
    $days    -=  7 * $weeks;
    $years   = int($weeks / 52);
    $weeks   -= 52 * $years;

    if ($format eq 'numeric') {
        $string = sprintf("%3d days %02d:%02d:%02d", 7*(52*$years + $weeks) + $days, $hours, $minutes, $seconds);
    }
    else {
        undef @diff;
        push(@diff, &main::plural($years,   "year"))   if $years;
        push(@diff, &main::plural($weeks,   "week"))   if $weeks   and $nu < 6;
        push(@diff, &main::plural($days,    "day"))    if $days    and $nu < 5;
        push(@diff, &main::plural($hours,   "hour"))   if $hours   and $nu < 4;
        push(@diff, &main::plural($minutes, "minute")) if $minutes and $nu < 3;
        push(@diff, &main::plural($seconds, "second")) if $seconds and $nu < 2;
        
        $last = pop @diff;
        if (@diff > 0) {
            $string = join(', ', @diff) . " and $last";
        }
        else {
            $string = $last;
        }
        $string = '0 seconds' if $time1 == $time2;
    }

#   $string .= ($time2 > $time1) ? ' ago' : ' from now';
    $string = "unknown time.  time2=$time2 time1=$time1 diff=$diff" unless $string;  # debug
    return $string;
} 

sub main::time_to_ampm {
    my($time) = @_;
    my($hour, $min) = split(":", $time);
    my $ampm = ($hour < 12) ? "AM" : "PM";
    $hour -= 12 if $hour > 12;
    $hour =  12 if $hour == 0;
    return wantarray ? ("$hour:$min $ampm", $hour, $min, $ampm) : "$hour:$min $ampm";
} 

                                # Magic from pg. 237 of Programing Perl
                                #  - Probably better to use uuencode_base64 from Mime::Base64
sub main::uudecode {
    my ($string) = @_;
    $string =~ tr#A-Za-z0-9+/##cd;
    $string =~ tr#A-Za-z0-9+/# -_#;
    my $len = pack("c", 32 + 0.75*length($string));
    return unpack("u", $len . $string);
}


sub main::which {
    my ($pgm) = @_;
    for my $path (".", "$main::Pgm_Path", split(';', $ENV{PATH})) {
        chop $path if $path =~ /\\$/; # Drop trailing slash
        my $pgm_path = "$path/$pgm";
        return "$pgm_path.bat" if -e "$pgm_path.bat";
        return "$pgm_path.exe" if -e "$pgm_path.exe";
        return "$pgm_path.com" if -e "$pgm_path.com";
        return $pgm_path if -e $pgm_path;
    }
    return $pgm if -e $pgm;     # Covers the fully qualified $pgm name
    return;                     # Didn't find it
}

#print " done\n";

1;

#
# $Log$
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
