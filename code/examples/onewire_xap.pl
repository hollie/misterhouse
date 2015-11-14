# category = HVAC

=begin

To declare the one-wire xAP object and a set of dependent analog sensors, define
items in the .mht file. For example,

OWX, house,  house_owx
ANALOG_SENSOR,  inside-t,  temp_inside,  house_owx,  Sensors|Temperature,  temp
ANALOG_SENSOR,  inside-h,  humid_inside,  house_owx,  Sensors|Temperature,  humid

where "inside-t" is the sensor ID that correlates to the oxc daemon's config;
"temp_inside" is the item name; "house_owx" is the OneWire_xAP item's name;
"Sensors|Temperature" are group names and "temp" is the sensor type

=cut

# could also be set via an ini parm
my $thermo_temps = "68,69,70,71,72,73,74,75,76,77,78,79,80";

# define voice commands to set thermostat cool and heat setpoints
$v_thermo_cool_sp =
  new Voice_Cmd("Set thermostat cool setpoint to [$thermo_temps]");
if ( $state = said $v_thermo_cool_sp) {
    $main::Save{'cool_setpoint'} = $state;
    $temp_inside->token( 'cool_setpoint', $state );
    $temp_inside->check_tied_state_conditions();
}

$v_thermo_heat_sp =
  new Voice_Cmd("Set thermostat heat setpoint to [$thermo_temps]");
if ( $state = said $v_thermo_heat_sp) {
    $main::Save{'heat_setpoint'} = $state;
    $temp_inside->token( 'heat_setpoint', $state );
    $temp_inside->check_tied_state_conditions();
}

# setup additional properties not definable via .mht

# noloop=start

# map sensors to weather hash
$temp_inside->map_to_weather('TempIndoor');
$humid_inside->map_to_weather('HumidIndoor');

# now, create the conditions ("rules") used for state transition
# note the use of $token_<tokentag> syntax
my $hot_condition     = '$measurement > $token_cool_setpoint';
my $comfort_condition = '$token_heat_setpoint <= $measurement and '
  . '$measurement <= $token_cool_setpoint';
my $cool_condition = '$measurement < $token_heat_setpoint';

# now, tie the conditions
$temp_inside->tie_state_condition( $hot_condition,     'hot' );
$temp_inside->tie_state_condition( $comfort_condition, 'comfort' );
$temp_inside->tie_state_condition( $cool_condition,    'cool' );

# now that the conditions are tied, just update the token values
# when needed; don't worry about untieing and retieing conditions; just,
# set them once as above w/i this noloop block

# compensate for miscalibrated temp sensor - partly due to heating inside case
$temp_inside->apply_offset(-3.5);

# noloop=stop

if ($Reload) {

    # this should only ever happen once; it would be better to grab these
    # values from ini parms and possibly auto-alter these as a function
    # of mode and/or season
    $main::Save{'cool_setpoint'} = '80' unless $main::Save{'cool_setpoint'};
    $main::Save{'heat_setpoint'} = '68' unless $main::Save{'heat_setpoint'};

    # add setpoint tokens to simpify condition statements
    # note that this is also needed as tokens aren't persisted across restarts
    $temp_inside->token( 'cool_setpoint', $main::Save{'cool_setpoint'} );
    $temp_inside->token( 'heat_setpoint', $main::Save{'heat_setpoint'} );

    # and, finally, force an evaluation so that state is set
    $temp_inside->check_tied_state_conditions();
}

# print out values; useful for confirmation/troubleshooting
if ( new_minute 1 ) {
    print "inside temp = " . $temp_inside->measurement . "F\n";
    print "inside humid = " . $humid_inside->measurement . "%\n";
}

