
# Show how to set up a set of timed events using a stack of timed states

$test_generic1  = new Generic_Item;
$test_generic2  = new Generic_Item;
$test_generic3  = new Generic_Item;

if (new_second 15) {
    set $test_generic1 '~1~on~2~off';
    set $test_generic2 '~5~on~2~off';
    set $test_generic3 '~10~on~2~off';
}

$test_generic1 -> tie_event('print_log "item1 toggled to $state"');
$test_generic2 -> tie_event('print_log "item2 toggled to $state"');
$test_generic3 -> tie_event('print_log "item3 toggled to $state"');
