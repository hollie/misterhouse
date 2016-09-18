# Category=Fountain

=begin comment

From Bill Sobel on 2/4/01

Now that the new version is out (and the source forge list finally sent out
the pooled messages), I wanted to post some examples of the new tie_filter
and tie_time functions.

I started with two small files of mine, one controls my fountain and one is
for my sprinklers.  The new functions removed a bunch of hard to read
conditional cases and rolled everything up into simple statements.
Eventually I see these statements moving into the table file format so we
can define an object and apply simple operations to it from one place (as
was recently requested by another list member).

=cut

#noloop=start

#
# Manage Fountain (on/off schedule and voice command)
#
$v_fountain = new Voice_Cmd('Courtyard Fountain [on,off]');
$v_fountain->set_info('Controls the courtyard fountain');
$v_fountain->tie_items($Outside_Courtyard_Fountain);

$Outside_Courtyard_Fountain->tie_time( '00,07 13,14,15 * * 0,6',
    'on', 'log=fountain.log Fountain ON generated due to time of day' );
$Outside_Courtyard_Fountain->tie_time( '00,07 16,17,18,29,20,21 * * *',
    'on', 'log=fountain.log Fountain ON generated due to time of day' );
$Outside_Courtyard_Fountain->tie_time( '00,03,07 22 * * *',
    'off', 'log=fountain.log Fountain OFF generated due to time of day' );

$Outside_Courtyard_Fountain->tie_filter( '$Mode_Vacation->state() eq "on"',
    'on', 'log=fountain.log Fountain ON overridden by vacation mode' );
$Outside_Courtyard_Fountain->tie_filter( '$Windy->state() eq "1"',
    'on',
    'log=fountain.log Fountain ON overridden due to high winds detected' );
$Outside_Courtyard_Fountain->tie_filter(
    '$Cold_outside->state() eq "1"',
    'on',
    'log=fountain.log Fountain ON overridden due to cold outdoor temperatures'
);

#noloop=stop

# This can later be changed to tieing Gusty and Fountain once we added latching to Gusty
$Outside_Courtyard_Fountain->set('off')
  if $Outside_Courtyard_Fountain->state eq 'on' and $Gusty->state() eq '1';
print_log("log=fountain.log Fountain OFF generated due to gusty winds")
  if $Outside_Courtyard_Fountain->state eq 'on' and $Gusty->state() eq '1';

#X10A,           M1,                     Sprinklers_Rear_Lawn,                   Outside|Irrigation
#X10A,           M2,                     Sprinklers_Rear_Slope,                  Outside|Irrigation
#X10A,           M3,                     Sprinklers_Rear_Shrubs_Right,           Outside|Irrigation
#X10A,           M4,                     Sprinklers_Front_Shrubs,                Outside|Irrigation
#X10A,           M5,                     Sprinklers_Front_Lawn,                  Outside|Irrigation
#X10A,           M6,                     Sprinklers_Rear_Shrubs_Left,            Outside|Irrigation

#noloop=start

# Morning watering cycle
$Sprinklers->tie_time( '30 05 * * *', 'on:5,3,2,3,5,2',
    'log=irrigation.log Running first morning watering cycle' );
$Sprinklers->tie_time( '30 06 * * *', 'on:5,3,2,3,5,2',
    'log=irrigation.log Running second morning watering cycle' );
$Sprinklers->tie_time( '30 07 * * *', 'on:5,3,0,3,5,0',
    'log=irrigation.log Running third morning watering cycle' );

# Evening watering cycle
$Sprinklers->tie_time( '$Time_Sunset-1:20', 'on:0,1,0,1',
    'log=irrigation.log Running first evening watering cycle' );
$Sprinklers->tie_time( '$Time_Sunset-1:00', 'on:0,1,0,1',
    'log=irrigation.log Running second evening watering cycle' );
$Sprinklers->tie_time( '$Time_Sunset-0:40', 'on:0,1,0,1',
    'log=irrigation.log Running third evening watering cycle' );
$Sprinklers->tie_time( '$Time_Sunset-0:20', 'on:0,1,0,1',
    'log=irrigation.log Running fourth evening watering cycle' );

# When watering is finished, set the default watering times (one minute per zone)
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

