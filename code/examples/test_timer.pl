
# This shows a count down timer
$v_test_timer = new Voice_Cmd 'Test timer [1,10,20,40,60]';
$t_test_timer = new Timer;

if ( $state = said $v_test_timer) {
    print_log "starting timer";
    set $t_test_timer $state;
}

if ( expired $t_test_timer) {
    print_log "restarting timer";
    set $t_test_timer 10;
}

# This shows a count up timer
$test_timer = new Timer;
$test_timerv =
  new Voice_Cmd '[start,stop,restart,pause,resume,query] the stopwatch timer';

if ( $state = said $test_timerv) {
    start $test_timer   if $state eq 'start';
    stop $test_timer    if $state eq 'stop';
    restart $test_timer if $state eq 'restart';
    pause $test_timer   if $state eq 'pause';
    resume $test_timer  if $state eq 'resume';
    if ( $state eq 'query' ) {
        my $time = query $test_timer;
        print_log "$time seconds on the timer";
    }
}
