=begin comment

From Kyle Kirkland on 10/2002

It took me a little time to figure out the syntax
of the different files, but having all the code there
really helped.  I now have my RedHat 8 Linux box
controlling my sprinkler system on an easy to maintain
program.  To share, here's what I ended up with:

=cut

# Category=Sprinklers
#
# Pointers to the IrrMaster 4-zone sprinkler controller
#
#  http://www.homecontrols.com/product.html?prodnum=HCLC4&id_hci=0920HC569027
#  http://ourworld.compuserve.com/homepages/rciautomation/p6.htm
#
# Coded as X10_IrrigationController  in mh/lib/X10_Items.pm.
#
# From Bill Sobel 09/2002:
#
# I really don't have too much logic yet on the sprinkler activation, what I'm using now is:
#
# I originally wrote the module, here is my irrigation script (not too
# elaborate, but hopefully it will get you going).  Basically you send the
# unit an 'on' command and it will run each zone according the values earlier
# specified in a call to runtimes.  You can also 'overload' an on command and
# specify the runtimes as in 'on:5,4,3,2'.  That runs zone 1 for 5 minutes,
# zone 2 for 4 minutes, etc.
#
# Bill

#X10A,           E1,                     Sprinklers_Rear_Lawn1,Outside|Irrigation
#X10A,           E2,                     Sprinklers_Rear_Lawn2,Outside|Irrigation
#X10A,           E3,                     Sprinklers_Rear_Shrubs,Outside|Irrigation

#noloop=start

# Morning watering cycle
$Sprinklers->tie_time('30 05 * * 1,3,5', 'on:10,10,10', 'log=irrigation.log Running first morning watering cycle');
# Re-enabled in late May for more lawn water
#$Sprinklers->tie_time('30 06 * * *', 'on:5,5,2,5,5,2', 'log=irrigation.log Running second morning watering cycle');
#$Sprinklers->tie_time('30 07 * * *', 'on:5,5,0,5,5,0', 'log=irrigation.log Running third morning watering cycle');

# Evening watering cycle
#$Sprinklers->tie_time('$Time_Sunset-1:20', 'on:0,1,0,4', 'log=irrigation.log Running first evening watering cycle');
#$Sprinklers->tie_time('$Time_Sunset-1:00', 'on:0,1,0,4', 'log=irrigation.log Running second evening watering cycle');
#$Sprinklers->tie_time('$Time_Sunset-0:40', 'on:0,1,0,3', 'log=irrigation.log Running third evening watering cycle');
#$Sprinklers->tie_time('$Time_Sunset-0:20', 'on:0,1,0,2', 'log=irrigation.log Running fourth evening watering cycle');

# When watering is finished, set the default watering times (one minute perzone)
$Sprinklers->tie_event('$Sprinklers->set_runtimes(1,1,1,1,1,1)','complete',
  'log=irrigation.log Zone cascade complete, setting default run times');

# Enable the sprinklers every day at midnight (in case they were disabled for the day due to rain/weather/manual/etc)
$SprinkerEnable->tie_time('00 00 * * *', 'on', 'log=irrigation.log Sending midnight sprinkler enable command');

# Link the sprinkler test item to the sprinkler on command
$SprinklerTest->tie_items($Sprinklers, "on", "on:1,1,1,1,1,1",
'log=irrigation.log Sprinklers sent on due to sprinkler test command');

# Filter ON commands to the zone cascade if the cold weather flag is set
$Sprinklers->tie_filter('$Cold_outside->state() eq "1"', 'on',
'log=irrigation.log Sprinkler run overridden due to cold weather');

#noloop=stop


=begin comment 

Put this in sprinklers.mht

=-=-=-=-=-=-=-=-=-=- BEGIN sprinklers.mht =-=-=-=-=-=-=-=-=-=
Format = A

X10S,	E,	Sprinklers,		Outside|Irrigation
X10A,	E1,	Sprinklers_Rear_Lawn1,	Outside|Irrigation
X10A,	E2,	Sprinklers_Rear_Lawn2,	Outside|Irrigation
X10A,	E3,	Sprinklers_Rear_Shrubs,	Outside|Irrigation
X10I,	EA,	SprinklerTest,		Outside|Irrigation
X10I,	EE,	SprinkerEnable,		Outside|Irrigation

=-=-=-=-=-=-=-=-=-=--= END sprinklers.mht =-=-=-=-=-=-=-=-=-=

=cut
