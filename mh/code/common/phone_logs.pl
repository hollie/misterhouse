# Category=Phone

#@ This code lists phone calls loged by the other phone_*.pl code. 
#@ It also creates subroutines used by the web interface to 
#@ display phone logs.

                                # Show phone logs via a popup or web page
$v_phone_log  = new  Voice_Cmd 'Display recent [incoming,outgoing,] phone calls';
$v_phone_log -> set_info('Show recent phone calls.');

my $phone_dir = "$config_parms{data_dir}/phone";
if ($state = said $v_phone_log) {
    display text =>  &phone_log('in', 999, 'text'), font => 'fixed' if $state eq 'incoming' or $state eq ' ';
    display text =>  &phone_log('out',999, 'text'), font => 'fixed' if $state eq 'outgoing' or $state eq ' ';
}

                                # This function returns phone logs to menus
sub phone_log {
    my ($log, $count, $format) = @_;
    $count = 9 unless $count;
    $log = 'callerid' if $log eq 'in';
    $log = 'phone'    if $log eq 'out';
    my @members = &read_phone_logs1($log);
    my @calls   = &read_phone_logs2($count, @members);
    $format = $Menus{response_format} unless $format;
    return &menu_format_list($format, "$log log", @calls);
}

                                # This function will read the members in the phone log dir
sub read_phone_logs1 { 

    my ($file_qual) = @_;
                               # Read directory for list of detailed phone logs ... default to the lastest one. 
    opendir(DIR, "$phone_dir/logs") or die "Could not open directory $phone_dir/logs: $!\n"; 
    my @members  = readdir(DIR); 
                                # Default to just the latest 2 members 
    @members = reverse sort grep(/$file_qual.*\.log$/, @members);
    if (@members < 2) {
        return (shift @members);
    } else {
        return (shift @members, shift @members) ;
    }
}

                                # This function will read in or out phone logs and return
                                # a list array of all the calls.
my %callerid_by_number;
sub read_phone_logs2 { 
    my ($count1, @files) = @_;
                                # Sort by date, so most recent file is first
    my (@calls);
    my $count2 = 1;
    print "Reading @files\n";
    for my $log_file (@files) { 
#       print "db lf=$log_file\n";
        $log_file = "$phone_dir/logs/$log_file";
        open (PLOG, $log_file) or die "Error, could not open file $log_file: $!\n"; 
        binmode PLOG;       # In case bad (binary) data is logged 
        my @a = reverse <PLOG>;
        while ($_ = shift @a) { 
            tr/\x20-\x7e//cd; # Translate bad characters or else TK will mess up 
            my($time_date, $number, $name, $line, $type);
                                # Incoming
#Tue 04/03/01 11:11:37 507-252-5976 COLVIN ELIZABET
#Mon 11/12/01 19:11:28  name=-UNKNOWN CALLER- data=###DATE11121911...NMBR...NAME-UNKNOWN CALLER-+++ line=W

            if ($log_file =~ /callerid/) {
		($time_date, $number, $name, $line, $type) = $_ =~ /(.+?) (1?\-?\d\d\d\-?\d\d\d\-?\d\d\d\d)\s+name=(.+)\s+line=(.+)\s+type=(.+)/;
                ($time_date, $number, $name) = $_ =~ /(.+?) (\d\d\d\-?\d\d\d\-?\d\d\d\d) name=(.+)/ unless $name;
                ($time_date, $number, $name) = $_ =~ /(.+?) (\d\d\d\d\d\d\d\d\d\d)(\s\w+\s\w+\s\w+\s)/ unless $name;
                ($time_date, $number, $name) = $_ =~ /(.+?) (\d\d\d\-?\d\d\d\d)/ unless $name; # AC is optional

                                # Deal with "private, 'out of area', and bad data" calls 
                unless ($name) { 
                    ($name) = $_ =~ /name=(.+)/;
                    $time_date = substr($_, 0, 21); 
                    if ($_ =~ /out of area/i) { 
                        $number = "Out of Area"; 
                    } 
                    elsif ($_ =~ /private/i) { 
                        $number = " Private"; 
                    } 
                    else { 
                        $number = 'Unknown';
                    } 
                } 
                $name =~ s/line=.+//;
                $name =~ s/data=.+//;
            }
                                # Outgoing
#Sun 04/01/01 12:03:09 O2525976
            else {
                ($time_date, $number)        = $_ =~ /(.+?) O(\S+)/; 
                                # See if we can find a name for this number 
                my $number_length = length($number); 
                if ($number_length == 7) { 
                    $number =~ s/(\d\d\d)/$config_parms{local_area_code}-$1-/; 
                } 
                if ($number_length == 11) { 
                    $number = substr($number, 1); 
                    $number =~ s/(\d\d\d)(\d\d\d)/$1-$2-/; 
                } 
                %callerid_by_number = dbm_read("$config_parms{data_dir}/phone/callerid.dbm") unless %callerid_by_number;
#               my $data = dbm_read("$config_parms{data_dir}/phone/callerid.dbm", $number);
                my $data = $callerid_by_number{$number};
                my ($calls, $time, $date, $name2) = $data =~ /^(\d+) +(.+), (.+) name=(.+)/ if $data;
                $name = $name2;
            }
            next unless $number;
            my($day, $date, $time) = split ' ', $time_date;
            $time = time_to_ampm $time;
                                # Make it pretty 
            my $name2 = $Caller_ID::name_by_number{$number};
            $name2 = $name unless $name2;
            $name2 = '' unless $name2;
            push @calls, sprintf("date=%20s number=%-12s name=%s line=%s type=%s",  $time_date, $number, $name2, $line, $type);
            last if ++$count2 > $count1;
        } 
        close PLOG;
    }
    print "Read ", scalar @calls, " calls\n";
    return @calls;
}
