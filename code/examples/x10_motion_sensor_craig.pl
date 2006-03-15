
=begin comment

From Craig Schaeffer on 01 Feb 1999:

Bob, I just bought 3 of the Hawkeye II's.  One difference between the I 
and II is that the II's send 'ON' signals about every 10 seconds if they 
continue to detect motion. The I's only send the 'ON' once.  This works 
well if you want to use a timer to turn lights off instead of waiting 
for the hawkeye to signal no motion.  Just keep setting the timer every 
time more motion is detected.  Both work with mh, but the II's are more 
flexible.  Note: both Hawkeyes send on/off for dark/light conditions.  
This can only be disabled by covering the light sensor inside the unit.  
Hawkeye I's only send motion on/off if it thinks it is dark.  II's can 
be set to ignore light/dark and always send on/off when motion is 
detected.  I don't know if you wanted code samples for the Hawkeye, but 
here is what I use (borrowed from somewhere in Bruce's code)  I have 5 
motion detectors:

=end comment

$motion               = new Serial_Item('XPJ', ON);
$motion->               add            ('XPK', OFF);
$motion->               add            ('XOJ', ON);
$motion->               add            ('XOK', OFF);

$motion_unit          = new Serial_Item('XP6', 'computer room');
$motion_unit->          add            ('XP7', 'bedroom');
$motion_unit->          add            ('XP8', 'bedroom dark');
$motion_unit->          add            ('XP4', 'kitchen');
$motion_unit->          add            ('XP5', 'kitchen dark');
$motion_unit->          add            ('XO2', 'front yard');
$motion_unit->          add            ('XO4', 'back yard');

$timer_kitchen_light = new Timer();

if (state_now $motion eq ON) {
    if ((state $motion_unit) eq 'kitchen') {
	if (inactive $timer_kitchen_light) {
	    set $kitchen_light ON;
	    print "kitchen motion detected";
	    #speak ("kitchen motion detected");
	}
	set $timer_kitchen_light 240;
    }
}

if (expired $timer_kitchen_light) {
	set $kitchen_light OFF;
	print "kitchen light off";
	#speak ("kitchen light off");
}


