
$Weather{temp_test}++ if new_second 5;
$Weather{temp_test} = 0 if new_second 30;

$w_test1 = new Weather_Item 'temp_test';
$w_test2 = new Weather_Item 'temp_test > 4';
$w_test3 = new Weather_Item 'temp_test == 0';

print "Weather change 1: $temp\n" if defined( $temp = state_now $w_test1);
print "Weather change 2: $Weather{test}\n" if state_now $w_test2;
print "Weather change 3: $Weather{test}\n" if state_now $w_test3;

