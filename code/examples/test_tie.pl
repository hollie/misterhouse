
# This is an example of how to tie and untie items and events

# Create test command and items
$v_test_tie = new Voice_Cmd
  '[tie_a,untie_a,tie_b,untie_b,tie_all,untie_all] test2 to test1';
$v_test_item1 = new Voice_Cmd 'set test1 to [a,b,c]';
$item1        = new Generic_Item;
$item2        = new Generic_Item;

# The following has the same effect as this:
#   set $item1 $state if $state = said $v_test_item1;

tie_items $v_test_item1 $item1;

# Another way to write the above
#  $v_test_item1->tie_items($item1);

# Other tests

$item1->tie_items( $item2, "a", "A" ) if 'tie_a' eq said $v_test_tie;
$item1->tie_items( $item2, "b", "B" ) if 'tie_b' eq said $v_test_tie;
$item1->tie_items($item2) if 'tie_all' eq said $v_test_tie;
$item1->untie_items( $item2, "a" ) if 'untie_a' eq said $v_test_tie;
$item1->untie_items( $item2, "b" ) if 'untie_b' eq said $v_test_tie;
$item1->untie_items($item2) if 'untie_all' eq said $v_test_tie;

# The folowing ties are equivalent to this:
#   print_log "Item1 set to $state" if $state = state_now $item1;
#   print_log "Item2 set to $state" if $state = state_now $item2;

tie_event $item1 'print_log "Item1 set to $state"';
tie_event $item2 'print_log "Item2 set to $state"';

# The following is equivalent to this:
#   if (time_now '9:09 PM' or time_cron '* * * * * ') {
#     set $item1 TOGGLE;
#     print_log "Item1 toggled by time_now or time_cron test';
#   }

$item1->tie_time( '9:09 PM',     TOGGLE, 'Item1 toggled by time_now test' );
$item1->tie_time( '0 17 * * * ', ON,     'log=test1.log Item1 turned on' );
$item1->tie_time( '* * * * *',   TOGGLE, 'Item1 toggled by time_cron test' );

# This code will defeat anything from turning $item1 on if $windy is ON.

$windy = new Generic_Item;
$windy->set_states( ON, OFF );

$item1->tie_filter( 'state $windy eq ON',
    ON, 'Overriding item1 ON command because of wind' );

# This code will disable an item when we are away from the house

$item1       = new Generic_Item;
$status_away = new Generic_Item;
$status_away->set_states( ON, OFF );

$item1->tie_filter('state $status_away eq ON');
$item1->tie_event('print_log "item1 toggled to $state"');

$item1->set('toggle') if new_second 5;

# Test cross-tied items
#  - This allows us to set either item, and have the other one have the same state

$item3a = new Generic_Item;
$item3b = new Generic_Item;

$item3a->tie_items($item3b);
$item3b->tie_items($item3a);

tie_event $item3a 'print_log "Item3a set to $state"';
tie_event $item3b 'print_log "Item3b set to $state"';

$v_test_item3 = new Voice_Cmd 'set test3 to [a,b,c]';
tie_items $v_test_item3 $item3a;

