
# Example of using stacked states to fire a series of X10 commands with delays
# For example, cycleing through a set of X10 camera codes to turn them on sequentially
# (an ON to one automatically sets all the others to off)

# Sets X10 code B14,B14, and B15 to ON (OJ) with a 5 second delay, repeating every 20 seconds

$test_x10 = new X10_Item();
$test_x10->set('XB14OJ~5~XB15OJ~5~XB16OJ') if new_second 20;
