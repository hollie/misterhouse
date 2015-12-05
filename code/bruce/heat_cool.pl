# Category=HVAC

#@ Heating and fan control

# Turn attic fan on if warmer inside, in the summer
if (    $Weather{TempOutdoor} > 55
    and $Season eq 'Summer'
    and $Weather{TempOutdoor} < ( $Weather{TempIndoor} - 1 )
    and $Weather{TempIndoor} > 75
    and ( time_cron '0 0,2,4,6 * * *' ) )
{
    print "fan on\n";
    set $attic_fan ON;
}

# Don't leave it on all night long
if ( time_cron '0 1,3,5,8 * * *' ) {
    set $attic_fan OFF;
}

# Turn furnace and ceiling fans on when the Winter
# solar heat needs to be distrubuted
if (    $Weather{TempOutdoor} < 50
    and state $furnace_fan eq OFF
    and ( $Season eq 'Fall' or $Season eq 'Winter' )
    and $Weather{TempIndoor} > 76
    and $Hour > 9
    and $Hour < 16 )
{
    speak
      "Notice, the sun as warmed us up to $Weather{TempIndoor} degrees, so I am turning the fans on at $Time_Now";
    set $furnace_fan ON;
    set $living_room_fan ON;
    set $bedroom_fan ON;
}

# Turn them off after it has cooled down, or in late afternoon
if (    state $furnace_fan eq ON
    and $Weather{TempIndoor}
    and ( $Weather{TempIndoor} < 74 or $Hour > 18 ) )
{
    speak
      "Notice, it has cooled down to $Weather{TempIndoor} degrees, so I am turning the fans off at $Time_Now";
    set $furnace_fan OFF;
    set $living_room_fan OFF;
    set $bedroom_fan OFF;
}

# Create a setback thermostat
#&tk_entry      ('Heat Temp', \$Save{heat_temp});
#&tk_radiobutton('Heat Temp', \$Save{heat_temp}, [60, 64, 66, 68, 70]);

# Turn the heat on
$state = state $furnace_heat;
my $hyster = 1;
if (    $state eq OFF
    and $Weather{TempIndoor}
    and $Weather{TempIndoor} < ( $Save{heat_temp} - $hyster ) )
{
    my $heat_time_diff = &time_diff( $Save{heat_time}, $Time );
    speak
      "Turning furnace heat on after $heat_time_diff at $Weather{TempIndoor} degrees";
    print_log
      "Furnace heat has been turned on: temp=$Weather{TempIndoor} time=$heat_time_diff";
    logit(
        "$config_parms{data_dir}/logs/furnace.$Year_Month_Now.log",
        "state=on   temp=$Weather{TempIndoor}  time=$heat_time_diff  "
    );
    set $furnace_heat ON;
    $Save{heat_time} = $Time;
}

# Turn the heat off
elsif ( $state eq ON
    and $Weather{TempIndoor}
    and $Weather{TempIndoor} > ( $Save{heat_temp} + $hyster ) )
{
    my $heat_time_diff = &time_diff( $Save{heat_time}, $Time );
    speak
      "Turning furnace heat off after $heat_time_diff at $Weather{TempIndoor} degrees";
    print_log
      "Furnace heat has been turned off: temp=$Weather{TempIndoor} time=$heat_time_diff";
    logit(
        "$config_parms{data_dir}/logs/furnace.$Year_Month_Now.log",
        "state=off  temp=$Weather{TempIndoor}  time=$heat_time_diff"
    );
    set $furnace_heat OFF;
    $Save{heat_time} = $Time;
}

# Safeguard to make we don't leave the furnace heat on if somehow its state got lost
#  - skip if we already set for this pass

if (
    new_minute 10
    and !(
        $furnace_heat->{state_next_pass}
        and @{ $furnace_heat->{state_next_pass} }
    )
  )
{
    if (
        (
                $Weather{TempIndoor}
            and $Weather{TempIndoor} > ( $Save{heat_temp} + $hyster + 0.5 )
        )
        and $Weather{TempOutdoor} < 50
      )
    {
        if ( $state ne OFF ) {
            my $heat_time_diff = $Time - $Save{heat_time};
            $heat_time_diff = &time_diff($heat_time_diff);
            my $msg =
              "Danger Will Winterson, the furnace has been left on for $heat_time_diff.";
            $msg .=
              "The outdoor temperature is $Weather{TempOutdoor} degrees and indoor is $Weather{TempIndoor} degrees";
            $msg .= "I am turning that silly furnace off";
            display $msg, 0;
            speak $msg;
        }
        print_log
          "Furnace heat was left on.  Turning off at $Weather{TempIndoor} degrees";
        set $furnace_heat OFF;
    }

    # If we think it is off, lets fire the relay again to make sure
    print "db furnace state=$state\n";
    set $furnace_heat OFF if $state eq OFF;
}

# Manual controls

$v_furnace_fan = new Voice_Cmd( 'Furnace fan [on,off]', undef, 1 );
if ( $state = said $v_furnace_fan) {
    speak "furnace fan has been turned $state";
    set $furnace_fan $state;
}

$v_furnace_heat = new Voice_Cmd( 'Furnace heat [on,off]', undef, 1 );
if ( $state = said $v_furnace_heat) {
    print_log "Furnace heat has been turned $state";
    set $furnace_heat $state;
}

$v_living_room_fan = new Voice_Cmd('Living room fan [on,off]');
set $living_room_fan $state if $state = said $v_living_room_fan;

$v_bedroom_fan = new Voice_Cmd('Bedroom fan [on,off]');
set $bedroom_fan $state if $state = said $v_bedroom_fan;

$v_attic_fan = new Voice_Cmd('Attic fan [on,off]');
set $attic_fan $state if $state = said $v_attic_fan;

if ( state_now $toggle_attic_fan) {
    $state = ( ON eq state $attic_fan) ? OFF : ON;
    set $attic_fan $state;
    speak("The attic fan was toggled to $state");
}
