# Category=HVAC


                                # Turn attic fan on if warmer inside, in the summer
if ($weather{TempOutdoor} > 55 and
    $Season eq 'Summer' and
    $weather{TempOutdoor} < ($weather{TempIndoor} - 1) and
    (time_cron '0 0,2,5 * * *')) {
    print "fan on\n";
    set $attic_fan ON;
}
                                # Don't leave it on all night long
if (time_cron '0 1,3,6 * * *') {
    set $attic_fan OFF;
}


                                # Turn furnace and ceiling fans on when the Winter 
                                # solar heat needs to be distrubuted
if ($weather{TempOutdoor} < 50 and
    state $furnace_fan eq OFF and
    ($Season eq 'Fall' or $Season eq 'Winter') and
    $weather{TempIndoor} > 76 and
    $Hour > 9 and $Hour < 16) {
    speak "Notice, the sun as warmed us up to $weather{TempIndoor} degrees, so I am turning the fans on at $Time_Now";
    set $furnace_fan ON;
    set $living_room_fan ON;
    set $bedroom_fan ON;
}
                                # Turn them off after it has cooled down, or in late afternoon
if (state $furnace_fan eq ON and $weather{TempIndoor} and ($weather{TempIndoor} < 74 or $Hour > 18)) {
    speak "Notice, it has cooled down to $weather{TempIndoor} degrees, so I am turning the fans off at $Time_Now";
    set $furnace_fan OFF;
    set $living_room_fan OFF;
    set $bedroom_fan OFF;
}
    
    
                                # Create a setback thermostat
#&tk_entry      ('Heat Temp', \$Save{heat_temp});
#&tk_radiobutton('Heat Temp', \$Save{heat_temp}, [60, 64, 66, 68, 70]);

                                # Turn the heat on
my $hyster = 1;
$state = state $furnace_heat;
if   ($state eq OFF and $weather{TempIndoor} and $weather{TempIndoor} < $Save{heat_temp}) {
    my $heat_time_diff = &time_diff($Save{heat_time}, $Time);
    speak "Turning furnace heat on after $heat_time_diff at $weather{TempIndoor} degrees";
    print_log "Furnace heat has been turned $state: temp=$weather{TempIndoor} time=$heat_time_diff";
    logit("$config_parms{data_dir}/logs/furnace.$Year_Month_Now.log",  "state=on   temp=$weather{TempIndoor}  time=$heat_time_diff  ");
    set $furnace_heat ON;
    $Save{heat_time} = $Time;
}    
                                # Turn the heat off
elsif ($state eq ON and $weather{TempIndoor} and $weather{TempIndoor} > ($Save{heat_temp} + $hyster)) {
    my $heat_time_diff = &time_diff($Save{heat_time}, $Time);
    speak "Turning furnace heat off after $heat_time_diff at $weather{TempIndoor} degrees";
    print_log "Furnace heat has been turned $state: temp=$weather{TempIndoor} time=$heat_time_diff";
    logit("$config_parms{data_dir}/logs/furnace.$Year_Month_Now.log",  "state=off  temp=$weather{TempIndoor}  time=$heat_time_diff");
    set $furnace_heat OFF;
    set $furnace_heat OFF;
    $Save{heat_time} = $Time;
}    


                                # Manual controls

$v_furnace_fan = new  Voice_Cmd('Furnace fan [on,off]', undef, 1);
if ($state = said $v_furnace_fan) {
    speak "furnace fan has been turned $state";
    set $furnace_fan $state;
}

$v_furnace_heat = new  Voice_Cmd('Furnace heat [on,off]', undef, 1);
if ($state = said $v_furnace_heat) {
    print_log "Furnace heat has been turned $state";
    set $furnace_heat $state;
}

$v_living_room_fan = new  Voice_Cmd('Living room fan [on,off]');
set $living_room_fan $state if $state = said $v_living_room_fan;

$v_bedroom_fan = new  Voice_Cmd('Bedroom fan [on,off]');
set $bedroom_fan $state if $state = said $v_bedroom_fan;

$v_attic_fan = new  Voice_Cmd('Attic fan [on,off]');
set $attic_fan $state if $state = said $v_attic_fan;


if (state_now $toggle_attic_fan) {
    $state = (ON eq state $attic_fan) ? OFF : ON;
    set $attic_fan $state;
    speak("The attic fan was toggled to $state");
}
