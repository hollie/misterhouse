# Category=Phone

# This code needs more work.  Sort/search options, incoming callse, dbm names, etc
#  - keep it seperate from the Voice_Cmd in phone.pl so we can do quick loads
#    instead of full mh reloads


                                # This function will return a string that lists recent calls
sub display_phone_in_log {
    my @members = &read_phone_log_list;
    my @calls = reverse ((&read_phone_in_log(@members))[-$config_parms{max_log_entries}..-1]);
#   return  "<h4>List of recent calls</h4>" . (join '', @calls);
    return  join '', @calls;
}


                                # This function will read the members in the phone log dir
sub read_phone_log_list { 

    my ($file_qual) = @_;
    print "db fq=$file_qual.\n";
                               # Read directory for list of detailed phone logs ... default to the lastest one. 
    opendir(DIR, "$phone_dir/logs") or die "Could not open directory $phone_dir/logs: $!\n"; 
    my @members  = readdir(DIR); 
    my @members1 = reverse sort grep(/callerid.*$file_qual\.log$/, @members);
    my @members2 = reverse sort grep(/phone.*$file_qual\.log$/,    @members); 

                                # Default to just the latest member 
    @members1 = ($members1[0]); 
    @members2 = ($members2[0]); 

    return @members1;
}

                                # This function will read the current phone log and return
                                # a list array of all the calls.
sub read_phone_in_log { 
    my (@files) = @_;
                                # Sort by date, so most recent file is last 
    print "Reading @files\n";
    my (@calls);
    for my $log_file (sort {-M $b <=> -M $a} @files) { 
        next unless $log_file;
        $log_file = "$phone_dir/logs/$log_file";
#       print "Reading $log_file, date=", -M $log_file, ".\n"; 
        open (DATA, $log_file) or die "Error, could not open file $log_file: $!\n"; 
        binmode DATA;       # In case bad (binary) data is logged 
        while (<DATA>) { 
            tr/\x20-\x7e//cd; # Translate bad characters or else TK will mess up 
            my($time_date, $number, $name) = $_ =~ /(.+?)(\d\d\d\-\d\d\d\-\d\d\d\d) (.+)$/; 
        
                                # Deal with "private, 'out of area', and bad data" calls 
            unless ($name) { 
                $time_date = substr($_, 0, 21); 
                $number = substr($_, 21, 12); 
                if ($number =~ /OUT OF AREA/) { 
                    $number = " Out of Area"; 
                } 
                elsif ($number =~ /PRIVATE/) { 
                    $number = " Private"; 
                } 
                else { 
                    $number = ' Lost Phone Data'; 
                    $name = "  " . substr($_, 21); 
                } 
            } 

                                # Make it pretty 
            my $name2 = $Caller_ID::name_by_number{$number};
            $name2 = $name unless $name2;
#           print "db name=$name number=$number tim=$time_date\n";
            push @calls, sprintf("%20s %-12s %s\n",  $time_date, $number, $name2);
        } 
    }
    return @calls;
}
