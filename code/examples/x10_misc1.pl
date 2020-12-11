
# Q: Is there a proper way of detecting an ON/OFF code and then switching
#    some other appliances/lights on and off?
#
# A: You can use existing Light or Appliance declarations, and the
#    state_now method to detect incoming X10 signals.  For example:

$kitchen_light = new X10_Appliance('A1');
speak "Light set to $state" if $state = state_now $kitchen_light;

# A: Or you can define and react to just a specific X10 string.
#    For example, to detect only A1 ON (AJ is for On on house code A):

$button_a1 = new Serial_Item('XA1AJ');
speak "Button A1 was pushed" if state_now $button_a1;

# Q: I also need to figure out how to make a light flash a couple of times.
#    If you've done this before, a code fragment would be most useful!
#
# A: You can easily flash it on once for 5 seconds with this:

set_with_timer $light1 ON, 5;

# A: To toggle it more than once, is trickier.
#    This will turn it on and off 3 times for 2 seconds each:

$timer_light1 = new Timer;
set $timer_light1 2, 'set $light1 TOGGLE"', 6;

