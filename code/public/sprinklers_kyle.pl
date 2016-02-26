
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

if ( ( time_cron "38 4,16 * * *" ) or $Reload ) {
    run_voice_cmd "Get internet weather data";
}

if (   ( time_cron "40 4,16 * * *" )
    or ( $Time_Uptime_Seconds == 60 and $New_Second ) )
{
    foreach my $day ( split /\|/, $Weather{'Forecast Days'} ) {
        my $chance = $Weather{"Chance of rain $day"};
        if ( $chance >= 50 ) {
            $Save{sprinkler_skip} = 3;
            print_log
              "Chance of rain on $day is $chance.  Setting Save{sprinkler_skip} to: $Save{sprinkler_skip}";
            last;
        }
        elsif ( $chance > 0 ) {
            print_log
              "Chance of rain on $day is only $chance.  Not skipping sprinklers.";
        }
    }
}

# Front Yard
if (
    time_now("$Time_Sunset - 1:00")
    and (
        (
            (
                   $Day eq 'Sun'
                or $Day eq 'Mon'
                or $Day eq 'Tue'
                or $Day eq 'Wed'
                or $Day eq 'Thu'
                or $Day eq 'Fri'
            )
            and ( $Month >= 5 and $Month <= 9 )
        )
        or (
            (
                   $Day eq 'Mon'
                or $Day eq 'Tue'
                or $Day eq 'Wed'
                or $Day eq 'Thu'
                or $Day eq 'Fri'
            )
            and ( $Month == 4 )
        )
        or (
            (
                   $Day eq 'Mon'
                or $Day eq 'Tue'
                or $Day eq 'Thu'
                or $Day eq 'Fri'
            )
            and ( $Month == 3 or $Month == 10 )
        )
        or (    ( $Day eq 'Mon' or $Day eq 'Wed' or $Day eq 'Fri' )
            and ( $Month == 2 or $Month == 11 ) )
        or (    ( $Day eq 'Mon' or $Day eq 'Thu' )
            and ( $Month == 1 or $Month == 12 ) )
    )
  )
{
    if ( $Save{sprinkler_skip} == 3 ) {
        print_log "Rain forecasted, skipping sprinklers.";
    }
    elsif ( $Save{sprinkler_skip} > 0 ) {
        print_log "Skipping sprinklers due to recent rain.";
    }
    else {
        set $SprinklersFront
          '1-on~600~1-off;2-on~600~2-off;3-on~600~3-off;4-on~600~4-off';
        print_log "Starting front sprinkler cycle";
    }
}
print_log "Front Sprinkler set to $state by $SprinklersFront->{setby}."
  if $state = state_now $SprinklersFront;

# Back Yard
if (
    time_now("$Time_Sunset")
    and (
        (
            (
                   $Day eq 'Sun'
                or $Day eq 'Mon'
                or $Day eq 'Tue'
                or $Day eq 'Wed'
                or $Day eq 'Thu'
                or $Day eq 'Fri'
            )
            and ( $Month >= 5 and $Month <= 9 )
        )
        or (
            (
                   $Day eq 'Mon'
                or $Day eq 'Tue'
                or $Day eq 'Wed'
                or $Day eq 'Thu'
                or $Day eq 'Fri'
            )
            and ( $Month == 4 )
        )
        or (
            (
                   $Day eq 'Mon'
                or $Day eq 'Tue'
                or $Day eq 'Thu'
                or $Day eq 'Fri'
            )
            and ( $Month == 3 or $Month == 10 )
        )
        or (    ( $Day eq 'Mon' or $Day eq 'Wed' or $Day eq 'Fri' )
            and ( $Month == 2 or $Month == 11 ) )
        or (    ( $Day eq 'Mon' or $Day eq 'Thu' )
            and ( $Month == 1 or $Month == 12 ) )
    )
  )
{
    if ( $Save{sprinkler_skip} == 3 ) {
        print_log "Rain forecasted, skipping sprinklers.";
    }
    elsif ( $Save{sprinkler_skip} > 0 ) {
        print_log "Skipping sprinklers due to recent rain.";
    }
    else {
        set $SprinklersRear '1-on~800~1-off;2-on~800~2-off;3-on~300~3-off';
        print_log "Starting rear sprinkler cycle";
    }
}
print_log "Rear Sprinkler set to $state by $SprinklersRear->{setby}."
  if $state = state_now $SprinklersRear;

# Enable the front sprinklers every day at midnight (in case they were disabled for the day due to rain/weather/manual/etc)
if ( time_now("00:00") ) {
    set $SprinkerFrontEnable 'on';
    print_log "Sending midnight sprinkler enable command for front yard";
}

# Enable the back sprinklers every day at midnight (in case they were disabled for the day due to rain/weather/manual/etc)
if ( time_now("00:00") ) {
    set $SprinkerRearEnable 'on';
    print_log "Sending midnight sprinkler enable command for back yard";
}

if ( $Save{sprinkler_skip} and $New_Day ) {
    $Save{sprinkler_skip}--;
    print_log
      "!!!! DEBUG: New Save{sprinkler_skip} value: $Save{sprinkler_skip}";
}

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
