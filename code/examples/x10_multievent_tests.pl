
# This is a test event for showing 2 ways of dealing with multi-event X10 strings
# mh will test for "XD1DJ" and for "XD1 XDJ", for incoming strings of "XD1 XDJ" and "XD1DJ"

# Note: you can test this event by typing in the test strings into the tk "Enter command" window
#       or from the command line with the house command (e.g. house XD1DJ)

# These sensors will be triggered by any of the following combinations of data from the X10 interface:

#   XD1DJ    -> "Test sensor1 ON"
#   XD1DK    -> "Test sensor1 OFF"
#   XD1  XDJ -> "Test sensor1 ON"
#   XD1  XDK -> "Test sensor1 OFF"

#   XD2      -> "Test sensor2 motion"
#   XD2  XDJ -> "Test sensor2 ON"
#   XD2  XDJ -> "Test sensor2 OFF"
#   XD2DJ    -> "Test sensor2 ON"
#   XD2DK    -> "Test sensor2 OFF"

$test_sensor1 = new Serial_Item( 'XD1DJ', ON );
$test_sensor1->add( 'XD1DK', OFF );

$test_sensor2 = new Serial_Item( 'XD2', 'motion' );
$test_sensor2->add( 'XDJ', ON );
$test_sensor2->add( 'XDK', OFF );

print_log "Test sensor1 was triggered to $state"
  if $state = state_now $test_sensor1;
print_log "Test sensor2 was triggered to $state"
  if $state = state_now $test_sensor2;

# Here is an example of detecting multi-key input from X10 controllers

# This detects a double push of A1-ON (code=A1, on=AJ) with Palm remote.
$test_button2 = new Serial_Item 'XA1AJA1AJ';
speak "Palm A1 key was pressed twice" if state_now $test_button2;

# This would detect O1 button on a X10 maxi-controler was pushed twice.
$test_button3 = new Serial_Item 'XO1O1';
tie_event $test_button3 "speak 'Button O1 was just pressed twice'";

