# Category=none

$test_button1 = new X10_Appliance 'OE';
speak "test set to $state" if $state = state_now $test_button1;

