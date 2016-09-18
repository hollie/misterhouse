
$test_timer_item = new X10_Item 'O7';
$test_timer_cmd  = new Voice_Cmd 'Test set_with_timer [1,2,3]';

if ( $state = said $test_timer_cmd) {
    set_with_timer $test_timer_item ON, 5  if $state == 1;
    set_with_timer $test_timer_item ON, 10 if $state == 2;
}

