
# Different ways of adding delay to an event without
# causing mh to pause.

$v_test_delay = new Voice_Cmd 'Run delay test [1,2,3,4,5]';

if ( $state = said $v_test_delay) {
    print_log "Starting delay test $state";
    if ( $state == 1 ) {
        run_after_delay 2, "print_log 'Ending delay test 1'";
    }
    elsif ( $state == 2 ) {
        run_after_delay 2, sub {
            print_log "Ending delay test 2a";
            run_after_delay 2, sub {
                print_log "Ending delay test 2b";
              }
          }
    }
    else {
        Timer->new->set(
            2,
            sub {
                print_log "Ending delay test 3";
            }
        );
    }

}

