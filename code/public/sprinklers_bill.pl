
=begin comment

Pointers to the IrrMaster 4-zone sprinkler controller

 http://www.homecontrols.com/product.html?prodnum=HCLC4&id_hci=0920HC569027 
 http://ourworld.compuserve.com/homepages/rciautomation/p6.htm

Coded as X10_IrrigationController  in mh/lib/X10_Items.pm. 

From Bill Sobel 09/2002:

I really don't have too much logic yet on the sprinkler activation, what I'm using now is:

I originally wrote the module, here is my irrigation script (not too
elaborate, but hopefully it will get you going).  Basically you send the
unit an 'on' command and it will run each zone according the values earlier
specified in a call to runtimes.  You can also 'overload' an on command and
specify the runtimes as in 'on:5,4,3,2'.  That runs zone 1 for 5 minutes,
zone 2 for 4 minutes, etc.

Bill

#X10A,           M1,                     Sprinklers_Rear_Lawn,Outside|Irrigation
#X10A,           M2,                     Sprinklers_Rear_Slope,Outside|Irrigation
#X10A,           M3,                     Sprinklers_Rear_Shrubs_Right,Outside|Irrigation
#X10A,           M4,                     Sprinklers_Front_Shrubs,Outside|Irrigation
#X10A,           M5,                     Sprinklers_Front_Lawn,Outside|Irrigation
#X10A,           M6,                     Sprinklers_Rear_Shrubs_Left,Outside|Irrigation

=cut 

#noloop=start

# Morning watering cycle
$Sprinklers->tie_time( '30 05 * * *', 'on:5,5,2,5,5,2',
    'log=irrigation.log Running first morning watering cycle' );

# Re-enabled in late May for more lawn water
$Sprinklers->tie_time( '30 06 * * *', 'on:5,5,2,5,5,2',
    'log=irrigation.log Running second morning watering cycle' );

#$Sprinklers->tie_time('30 07 * * *', 'on:5,5,0,5,5,0', 'log=irrigation.log Running third morning watering cycle');

# Evening watering cycle
#$Sprinklers->tie_time('$Time_Sunset-1:20', 'on:0,1,0,4', 'log=irrigation.log Running first evening watering cycle');
#$Sprinklers->tie_time('$Time_Sunset-1:00', 'on:0,1,0,4', 'log=irrigation.log Running second evening watering cycle');
#$Sprinklers->tie_time('$Time_Sunset-0:40', 'on:0,1,0,3', 'log=irrigation.log Running third evening watering cycle');
#$Sprinklers->tie_time('$Time_Sunset-0:20', 'on:0,1,0,2', 'log=irrigation.log Running fourth evening watering cycle');

# When watering is finished, set the default watering times (one minute perzone)
$Sprinklers->tie_event( '$Sprinklers->set_runtimes(1,1,1,1,1,1)',
    'complete',
    'log=irrigation.log Zone cascade complete, setting default run times' );

# Enable the sprinklers every day at midnight (in case they were disabled for the day due to rain/weather/manual/etc)
$SprinkerEnable->tie_time( '00 00 * * *', 'on',
    'log=irrigation.log Sending midnight sprinkler enable command' );

# Link the sprinkler test item to the sprinkler on command
$SprinklerTest->tie_items( $Sprinklers, "on", "on:1,1,1,1,1,1",
    'log=irrigation.log Sprinklers sent on due to sprinkler test command' );

# Filter ON commands to the zone cascade if the cold weather flag is set
$Sprinklers->tie_filter( '$Cold_outside->state() eq "1"',
    'on', 'log=irrigation.log Sprinkler run overridden due to cold weather' );

#noloop=stop

