
# Test Process_Item

$test_process1 = new Process_Item;

$v_test_process1 = new Voice_Cmd 'Test process_item [1,2,3]';

if ($state = said $v_test_process1) {
    print_log "Starting process test $state";
    if ($state == 1) {
        set $test_process1 'sleep 3';
    }
                                # Example of doing multiple commands
    if ($state == 2) {
        set $test_process1 'sleep 1', 'sleep 2';
        add $test_process1 'sleep 1';
    }
                                # Example of mixing external and internal processes
                                #  - internal & functions only work on unix systems.
    if ($state == 3) {
        set $test_process1 'sleep 2', '&main::print_log("mid sleep")', 'sleep 2';
    }
    start $test_process1;
}

print_log 'Test process 1 just finished' if done_now $test_process1;

