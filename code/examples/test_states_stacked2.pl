
# Show how to set up a set of timed events using a stack of timed states

$test_generic1 = new Generic_Item;
$test_generic2 = new Generic_Item;
$test_generic3 = new Generic_Item;

if ( new_second 15 ) {
    set $test_generic1 '~1~on~2~off';
    set $test_generic2 '~5~on~2~off';
    set $test_generic3 '~10~on~2~off';
}

$test_generic1->tie_event('print_log "item1 toggled to $state"');
$test_generic2->tie_event('print_log "item2 toggled to $state"');
$test_generic3->tie_event('print_log "item3 toggled to $state"');

# Example of using stacked states to fire a series of X10 commands with delays
# For example, cycleing through a set of X10 camera codes to turn them on sequentially
# (an ON to one automatically sets all the others to off)

# Sets X10 code B14,B14, and B15 to ON (OJ) with a 5 second delay, repeating every 20 seconds

$test_x10 = new X10_Item();
$test_x10->set('XB14OJ~5~XB15OJ~5~XB16OJ') if new_second 20;

