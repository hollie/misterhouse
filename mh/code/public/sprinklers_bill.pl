
I really don't have too much logic yet on the sprinkler activation, what I'm using now is:

(From my .mht file)
X10S,           M,                      Sprinklers,
Outside|Irrigation
X10A,           M1,                     Sprinklers_Rear_Lawn,
Outside|Irrigation
X10A,           M2,                     Sprinklers_Rear_Slope,
Outside|Irrigation
X10A,           M3,                     Sprinklers_Rear_Shrubs_Right,
Outside|Irrigation
X10A,           M4,                     Sprinklers_Front_Shrubs,
Outside|Irrigation
X10A,           M5,                     Sprinklers_Front_Lawn,
Outside|Irrigation
X10A,           M6,                     Sprinklers_Rear_Shrubs_Left,
Outside|Irrigation
X10A,           M7,                     Sprinklers_Zone_7,
Outside|Irrigation
X10A,           M8,                     Sprinklers_Zone_8,
Outside|Irrigation
X10I,           M9,                     SprinkerTempEnable,
Outside|Irrigation
X10I,           MB,                     SprinklerTest,
Outside|Irrigation
X10I,           ME,                     SprinkerEnable,
Outside|Irrigation

(From the .pl file)

#noloop=start
# Sprinkler test is set to the code of the button on the RCS device
$SprinklerTest->tie_items($Sprinklers, "on", "on");
$Sprinklers->set_runtimes(10,10,10,10,10,10);
#noloop=stop

# If the sprinklers were disabled, turn them back on
if($New_Day)
{
    $SprinkerEnable->set('on');
}

# Water in the mornings multiple times (part of the backyard is an upslope,
long watering times
# cause lots of runoff.  Breaking it up lets it soak in between 'passes'.
if (time_cron('00 06,07,08 * * *'))
{
    $Sprinklers->set_runtimes(5,3,3,3,5,3);
    $Sprinklers->set('on');
}
elsif (time_cron('00 10,22 * * *'))
{
    $Sprinklers->set_runtimes(10,10,10,10,10,10);
}
# The complete state is to be done.
#elsif ($Sprinklers->state_now eq 'complete')

# Nighttime extra water for the planters
if ((time_now "$Time_Sunset-1:00") or (time_now "$Time_Sunset-0:30"))
{
    $Sprinklers->set_runtimes(undef,2,undef,2,undef,undef);
    $Sprinklers->set('on');
}

