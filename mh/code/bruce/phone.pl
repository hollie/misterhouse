# Category=Phone

                                # Allow for searching for numbers
#&tk_entry('Phone Search', \$Save{phone_search});
if ($Tk_results{'Phone Search'}) {
    print_log "Searching for $Tk_results{'Phone Search'}";
                                # Search data logged from incoming caller id data.
    my ($count1, $count2, %results) = &dbm_search("$config_parms{data_dir}/phone/callerid.dbm", $Save{phone_search});
                                # Also search in array created from mh.ini caller_id_file data
    while (my($key, $value) = each %Caller_ID::name_by_number) {
        if ($key =~ /$Save{phone_search}/i or $value =~ /$Save{phone_search}/i) {
            $value = &dbm_read("$config_parms{data_dir}/phone/callerid.dbm", $key); # Use dbm data for consistency
            $results{$key} = $value;
        }
    }
    $count2 = keys %results;    # Reset count, in case Caller_ID search found any

    if ($count2) {
        my $results;
        for (sort keys %results) {
            my ($cid_number, $cid_date, $cid_name) = $results{$_} =~ /(\S+) (.+) name=(.+)/;
            $cid_name = $Caller_ID::name_by_number{$_} if $Caller_ID::name_by_number{$_};
            $results .= sprintf("%13s calls=%3s last=%26s %s\n", $_, $cid_number, $cid_date, $cid_name);
        }
#       map {$results .= "   $_: $results{$_}\n\n"} sort keys %results;
        display "Results:  $count2 out of $count1 records matched\n\n" . $results, 120, 'Phone Search Results', 'systemfixed';
    }
    else {
        display "\n      No match found\n", 5, 'Phone Search Results';
    }
#   run qq[get_tv_info -times all -dates "$Save{tv_days}" -keys "$Save{tv_search}"];
#   set_watch $f_tv_file;
    undef $Tk_results{'Phone Search'};
}


                                # Show phone logs via a popup or web page
$v_phone_log_in  = new  Voice_Cmd 'List recent phone calls';
$v_phone_log_in -> set_info('Lists recent incoming phone calls');

my $phone_dir = "$config_parms{data_dir}/phone";
if (said  $v_phone_log_in) {
    display &display_phone_in_log;
}

$v_phone_log_reload  = new  Voice_Cmd 'Reload phone log code';
$v_phone_log_reload -> set_info('Used when developing phone_logs.pl.  Reloads just that code, so is quicker than a full mh reload');
if (said $v_phone_log_reload) {
    print_log "Loading code member phone_logs.pl";
    eval "phone_logs.pl";
    print_log "eval results: $@";
}

                                # Show phone logs
$v_phone_log_tk  = new  Voice_Cmd('Show the phone log');
$v_phone_log_tk -> set_info('Display a tk popup of all the incoming and outgoing phone calls');

if (said  $v_phone_log_tk) {
    print "running display_callers\n";
    undef @ARGV;
                                # Much faster to 'do' than to 'run'
    do "$Pgm_Path/display_callers";
#   run "display_callers";
}

                                # Do monthly phone cleanup chores
if ($New_Month) {

    speak "Backup on phone logs";

    my $dbm_file = "$config_parms{data_dir}/data/phone/callerid.dbm";
    $dbm_file =~ s|/|\\|g if $OS_win; # System calls need dos pathnames :(

    print_log "Backing up phone log to logs $dbm_file.$Year_Month_Now";

    copy("$dbm_file", "$dbm_file.$Year_Month_Now") or print_log "Error in phone dbm copy 1: $!";

				# dbm_copy will delete any bad entries (those with binary characters) from the file.
    system("dbm_copy $dbm_file");
    copy("$dbm_file.backup", "$dbm_file") or print_log "Error in phone dbm copy 2: $!";
    
}

