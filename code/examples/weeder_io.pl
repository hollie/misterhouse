
=begin comment

This is a 12/00 note from Craig Schaeffer on how he interfaces to 
the current weeder kits.  The code in mh/code/bruce uses the old weeder kits.

I have both the new digital I/O weeder kit and the analog kit. I have a digital
I/O kit set configured as 'B' and an analog kit configured as 'A'. In items.pl,

I do not think the code to handle state changes had to be modified (or maybe
only slightly modified). The major difference between the new weeder kits and
the old, is that the new codes are shorter and each kit is configured to have a
unique code (A,B,C, etc.) instead of the old codes 'D1', 'D2', etc. for
digital, 'A1', 'A2' for analog, etc. They also run at 9600 baud, so they cannot
coexist with old kits on the same serial port.

The 2 states 'init' and 'read' are commands SENT to the weeder kit. 'BSJ' sets
kit 'B', pin 'J' as a switch. 'BRJ' sends a read command to kit 'B', pin 'J'. 
The other two items 'OPENED' and 'CLOSED' are RECEIVED from the weeder kit and
represent the high ('BJH') and low ('BJL') states of kit 'B', pin 'J'. They are
sent to mh each time the switch changes states (in my case, when the kitchen
motion detector fires, or the sump pump fills/empties). 

=cut

# digital items
$kitchen_motion_b = new Serial_Item( 'BJH', OPENED );    #J
$kitchen_motion_b->add( 'BJL', CLOSED );
$kitchen_motion_b->add( 'BSJ', 'init' );
$kitchen_motion_b->add( 'BRJ', 'read' );

$sump_pump_b = new Serial_Item( 'BKH', 'empty' );        #K
$sump_pump_b->add( 'BKL', 'full' );
$sump_pump_b->add( 'BSK', 'init' );
$sump_pump_b->add( 'BRK', 'read' );

$bedroom_motion_b = new Serial_Item( 'BLH', OPENED );    #L
$bedroom_motion_b->add( 'BLL', CLOSED );
$bedroom_motion_b->add( 'BSL', 'init' );
$bedroom_motion_b->add( 'BRL', 'read' );

# Analog items
$analog_request_a = new Serial_Item( 'AS', 'read',  'weeder' );
$analog_request_z = new Serial_Item( 'AZ', 'reset', 'weeder' );
$analog_results   = new Serial_Item( 'A',, 'weeder' );
$temp_outside       = new Serial_Item( 'A1',, 'weeder' );
$temp_computer_room = new Serial_Item( 'A2',, 'weeder' );
$temp_sensor3       = new Serial_Item( 'A3',, 'weeder' );
$temp_archy         = new Serial_Item( 'A4',, 'weeder' );
