

$test_x10_item1 = new X10_Item('P7');
$test_x10_item2 = new X10_Item('P7');

$v_test_x10_item1 = new Voice_Cmd('Set test x10 item [on,off]');
$v_test_x10_item1-> tie_items($test_x10_item1);

tie_event $test_x10_item1 'print_log "item1 set to $state"';
tie_event $test_x10_item2 'print_log "item2 set to $state"';
