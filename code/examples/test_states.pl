
# This test various state methods

$v_state1 = new Voice_Cmd 'Test multiple state sets';

$test_state1 = new Generic_Item;

if ( said $v_state1) {
    print_log "Seting test_state twice on pass $Loop_Count";
    set $test_state1 'state a';
    set $test_state1 'state b';
}

tie_event $test_state1 'print_log "Test State item $state on pass $Loop_Count"';

