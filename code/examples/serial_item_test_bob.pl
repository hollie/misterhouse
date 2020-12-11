
#serial_item_test.pl
# Bob Hackenberg (rhackenb@cyberenet.net)
# January 24, 1999
# Based on code written by Bruce Winters
#
# This code demonstrates the use of Serial_Item to read the state of
# two  X10 devices (A1 and A2).  When a an external X10 control such as
# Radio Shack Remote Power Center is used to turn either device on or
# off, the code checks the state of both devices and reports when one
# is turned on or off.  It cycles on a 10 second interval.  This could
# be used to take note sensors such as motion detectors.
#
# Question: is it possible to change the state of these devices within
# this code?

my $light1 = "";
my $light2 = "";
$light_sensor = new Serial_Item( 'XAJ', ON );
$light_sensor->add( 'XAK', OFF );
$light_sensor_unit = new Serial_Item( 'XA1', 'right' );
$light_sensor_unit->add( 'XA2', 'left' );
$light_timer = new Timer();

if ( inactive $light_timer) {
    if ( state_now $light_sensor eq ON ) {
        set $light_timer 10;
        if ( ( state $light_sensor_unit) eq 'right' ) {
            print "right is on\n";
            $light1 = "ON";
        }
        elsif ( ( state $light_sensor_unit) eq 'left' ) {
            print "left is on\n";
            $light2 = "ON";
        }
        print "light1 is $light1, light2 is $light2\n";
    }
    elsif ( state_now $light_sensor eq OFF ) {
        set $light_timer 10;
        if ( ( state $light_sensor_unit) eq 'right' ) {
            print "right is off\n";
            $light1 = "OFF";
        }
        elsif ( ( state $light_sensor_unit) eq 'left' ) {
            print "left is off\n";
            $light2 = "OFF";
        }
        print "light1 is $light1, light2 is $light2\n";
    }
}

