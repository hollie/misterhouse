
# This is a test event for showing 2 ways of dealing with muilt-event X10 strings
# mh will test for "XD1DJ" and for "XD1 XDJ", for incoming strings of "XD1 XDJ" and "XD1DJ"

# Note: you can test this event by typing in the test strings into the tk "Enter command" window
#       or from the command line with the house command (e.g. house XD2DJ)

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


$test_sensor1      = new  Serial_Item('XD1DJ', ON);
$test_sensor1    ->     add          ('XD1DK', OFF);

$test_sensor2      = new  Serial_Item('XD2', 'motion');
$test_sensor2    ->     add          ('XDJ',   ON);
$test_sensor2    ->     add          ('XDK',   OFF);

print_log "Test sensor1 was triggered to $state" if $state = state_now $test_sensor1;
print_log "Test sensor2 was triggered to $state" if $state = state_now $test_sensor2;
