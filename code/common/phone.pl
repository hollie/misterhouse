# Category=Phone

#@ Allows for searching, displaying, and backing up phone logs

# Allow for searching for numbers
#&tk_entry('Phone Search', \$Save{phone_search});

if ( $temp = $Tk_results{'Phone Search'} ) {
    print_log "Searching for $temp";

    # Search data logged from incoming caller id data.

    my $results = &search_phone_calls($temp);
    display $results, 120, 'Phone Search Results', 'systemfixed';

    undef $Tk_results{'Phone Search'};
}

sub search_phone_calls {
    my ($string) = @_;
    print_log "Searching for $string";

    # Search data logged from incoming caller id data.
    my ( $count1, $count2, %results ) =
      &dbm_search( "$config_parms{data_dir}/phone/callerid.dbm", $string );

    # Also search in array created from mh.ini caller_id_file data
    while ( my ( $key, $value ) = each %Caller_ID::name_by_number ) {
        if ( $key =~ /$string/i or $value =~ /$string/i ) {
            $value =
              &dbm_read( "$config_parms{data_dir}/phone/callerid.dbm", $key )
              ;    # Use dbm data for consistency
            $results{$key} = $value;
        }
    }
    $count2 = keys %results;   # Reset count, in case Caller_ID search found any

    my $results;
    if ($count2) {
        for ( sort keys %results ) {
            my ( $cid_number, $cid_date, $cid_name ) =
              $results{$_} =~ /(\S+) (.+) name=(.+)/;
            $cid_name = $Caller_ID::name_by_number{$_}
              if $Caller_ID::name_by_number{$_};
            $results .= sprintf( "%13s calls=%3s last=%26s %s\n",
                $_, $cid_number, $cid_date, $cid_name );
        }

        #       map {$results .= "   $_: $results{$_}\n\n"} sort keys %results;
        $results =
          "Results:  $count2 out of $count1 records matched $string\n\n"
          . $results;
    }
    else {
        $results = "\n      No match found\n";
    }
    return $results;
}

# Show phone logs
$v_phone_log_tk = new Voice_Cmd('Show the tk phone log');
$v_phone_log_tk->set_info(
    'Display a tk popup of all the incoming and outgoing phone calls');

if ( said $v_phone_log_tk) {
    print "running display_callers\n";
    undef @ARGV;

    # Much faster to 'do' than to 'run'
    do "$Pgm_Path/display_callers";

    #    run "display_callers";
}

# Do monthly phone cleanup chores
if ($New_Month) {

    print_log "Backup on phone logs";

    my $dbm_file = "$config_parms{data_dir}/phone/callerid.dbm";
    $dbm_file =~ s|/|\\|g if $OS_win;    # System calls need dos pathnames :(

    print_log "Backing up phone log to logs $dbm_file.$Year_Month_Now";

    copy( "$dbm_file", "$dbm_file.$Year_Month_Now" )
      or print_log "Error in phone dbm copy 1: $!";

    # dbm_copy will delete any bad entries (those with binary characters) from the file.
    system("dbm_copy $dbm_file");
    copy( "$dbm_file.backup", "$dbm_file" )
      or print_log "Error in phone dbm copy 2: $!";

}

