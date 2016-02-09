
$test_cb1 = new Voice_Cmd 'Test set_by 1';
$test_cb2 = new Voice_Cmd 'Test set_by 2';

if ( state_now $test_cb1) {
    &run_voice_cmd( 'Test set_by 2', undef, 'hacker' );
}

if ( state_now $test_cb2) {
    my $set_by = get_set_by $test_cb2;
    print_log "set_by test changed by $set_by";
}

