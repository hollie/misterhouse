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
$v_thermo_cool_sp = new Voice_Cmd("Set thermostat cool setpoint to [$thermo_temps]");
if ($state = said $v_thermo_cool_sp) {
   $main::Save{'cool_setpoint'} = $state;
   &set_thermo_sensor($temp_basement);
}

$v_thermo_heat_sp = new Voice_Cmd("Set thermostat heat setpoint to [$thermo_temps]");
if ($state = said $v_thermo_heat_sp) {
   $main::Save{'heat_setpoint'} = $state;
   &set_thermo_sensor($temp_basement);
}

# setup additional properties not definable via .mht

# noloop=start

# map sensors to weather hash
$temp_outside->map_to_weather('TempOutdoor');
$humid_outside->map_to_weather('HumidOutdoor');
$temp_inside->map_to_weather('TempIndoor');
$humid_inside->map_to_weather('HumidIndoor');

# compensate for miscalibrated temp sensor - partly due to heating inside case
$temp_inside->apply_offset(-3.5);

# noloop=stop

if ($Reload) {
   # this should only ever happen once; it would be better to grab these
   # values from ini parms and possibly auto-alter these as a function
   # of mode and/or season
   $main::Save{'cool_setpoint'} = '80' unless $main::Save{'cool_setpoint'};
   $main::Save{'heat_setpoint'} = '68' unless $main::Save{'heat_setpoint'};
   # evaluate tied state conditions
   &set_thermo_sensor($temp_inside);
}

# print out values; useful for confirmation/troubleshooting
if (new_minute 1) {
	print "outside temp = " . $temp_outside->measurement . "F\n";
	print "outside humid = " . $humid_outside->measurement . "%\n";
	print "inside temp = " . $temp_inside->measurement . "F\n";
	print "inside humid = " . $humid_inside->measurement . "%\n";
}

sub set_thermo_sensor {
   my ($sensor) = @_;
   print "Setting thermostat sensor state conditions\n";

   my $hot_condition = '$measurement > ' . $main::Save{'cool_setpoint'};
   my $comfort_condition = $main::Save{'heat_setpoint'} . 
                        ' <= $measurement and $measurement <= ' . 
                        $main::Save{'cool_setpoint'};
   my $cool_condition = '$measurement < ' . $main::Save{'heat_setpoint'};
   $sensor->untie_state_condition(); # untie all
   # add state conditions
   $sensor->tie_state_condition($hot_condition, 'hot');
   $sensor->tie_state_condition($comfort_condition, 'comfort');
   $sensor->tie_state_condition($cool_condition, 'cool');
   # cause a state evaluation
   $sensor->check_tied_state_conditions();
}

