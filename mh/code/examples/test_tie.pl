
# This is an example of how to tie and untie items and events


$v_test_tie   = new Voice_Cmd '[tie_a,untie_a,tie_b,untie_b,tie_all,untie_all] test2 to test1';
$v_test_item1 = new Voice_Cmd 'set test1 to [a,b,c]';
$item1 = new Generic_Item;
$item2 = new Generic_Item;

tie_items $v_test_item1 $item1;

# Another way to write the above
#  $v_test_item1->tie_items($item1);

# The above tie has the same effect as this:
#   set $item1 $state if $state = said $v_test_item1;


$item1 ->   tie_items($item2, "a", "A") if 'tie_a'     eq said $v_test_tie;
$item1 ->   tie_items($item2, "b", "B") if 'tie_b'     eq said $v_test_tie;
$item1 ->   tie_items($item2)           if 'tie_all'   eq said $v_test_tie;
$item1 -> untie_items($item2, "a")      if 'untie_a'   eq said $v_test_tie;
$item1 -> untie_items($item2, "b")      if 'untie_b'   eq said $v_test_tie;
$item1 -> untie_items($item2)           if 'untie_all' eq said $v_test_tie;

tie_event $item1 'print_log "Item1 set to $state"';
tie_event $item2 'print_log "Item2 set to $state"';

# The above ties has is equivalent to this:
#   print_log "Item1 set to $state" if $state = state_now $item1;
#   print_log "Item2 set to $state" if $state = state_now $item2;

