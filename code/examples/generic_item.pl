
# Category = Test

# Generic_Item can be use to store any data.

# This shows how you can use Generic_Item in a couple of different ways
#  - $test_data1/2 uses it to monitor Tk entry fields
#  - $test_remote  uses it to monitor
#    several different items with one test.

$test_data1 = new Generic_Item;
$test_data2 = new Generic_Item;
&tk_entry( 'Test data 1', $test_data1 );
&tk_entry( 'Test data 2', $test_data2 );

$test_data3 = new Generic_Item;
tie_items $test_data1 $test_data3;
tie_items $test_data2 $test_data3;

print_log "Test item 3 was set to $state" if $state = state_now $test_data3;

