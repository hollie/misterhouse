
$test_dbm = new Voice_Cmd 'Run dbm test [1,2,3]';

if ( $state = said $test_dbm) {
    if ( $state == 1 ) {
        logit_dbm( "$config_parms{data_dir}/junk1.dbm", 'test1', $Time_Date );
        logit_dbm( "$config_parms{data_dir}/junk1.dbm", 'test2', $Time );
        print_log "dbm write: $Time_Date";
    }
    if ( $state == 2 ) {
        my $td = dbm_read( "$config_parms{data_dir}/junk1.dbm", 'test1' );
        print_log "dbm read: $td";
    }
    if ( $state == 3 ) {
        my %data = dbm_read("$config_parms{data_dir}/junk1.dbm");
        my $data;
        for my $key ( sort keys %data ) {
            $data .= "key=$key value=$data{$key}\n";
        }
        display $data;
    }
}
