
# Example of testing idle times with time_idle

$test_idle = new Generic_Item;
$test_idle->tie_event('print "Idle item set to $state\n"');

$test_idle_v = new Voice_Cmd 'Set test idle object to [on,off]';
$test_idle_v->tie_items($test_idle);

print "Test item is idle\n" if $New_Second and get_idle_time $test_idle > 2;

if ( $test_idle->time_idle('4 seconds') ) {
    print_log "Item toggled by time_idle";
    set $test_idle TOGGLE;
}

# Examples of tie_time and a simple if test on time_idle

#$test_idle  -> tie_time('time_idle 4 s',    TOGGLE, 'Item toggled by tie_time idle');
$test_idle->tie_time( 'time_idle 2 s on',
    OFF, 'Item set to off by tie_time idle' );

