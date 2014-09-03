# Category = Test

#@ A simple voice command test.
#@ Try changing editing this file then 'Reload Code' to test

$my_test1 = new Voice_Cmd 'Run test [1,2,3]';

if ( $state = said $my_test1) {
    if ( $state == 1 ) {
        speak "You ran test 1 at $Time_Now";
    }
    elsif ( $state == 2 ) {
        display "You ran test 2 on $Date_Now";
    }
    elsif ( $state == 3 ) {
        print_log "Test 3 to the print log";
    }
}
