# category = HVAC

if ( my $current = $Livingroom_Thermostat->state_now ) {
    if ( $current =~ /inside_temp: (\d+)/ ) {
        print "inside thermostat temp is: $1\n";
    }
    if ( $current =~ /outside_temp: (\d+)/ ) {
        print "outside thermostat temp is: $1\n";
    }
    if ( $current =~ /heat_sp_temp: (\d+)/ ) {
        print "heat setpoint temp is: $1\n";
    }
    if ( $current =~ /cool_sp_temp: (\d+)/ ) {
        print "cool setpoint temp is: $1\n";
    }
    if ( $current =~ /mode: (.*)/ ) {
        print "HVAC mode is: $1\n";
    }
    if ( $current =~ /fan: (.*)/ ) {
        print "fan is: $1\n";
    }
    if ( $current =~ /setback: (.*)/ ) {
        print "inside thermostat temp is: $1\n";
    }
    if ( $current =~ /display_lockout: (.*)/ ) {
        print "display lockout status is: $1\n";
    }
    if ( $current =~ /thermostat_status/ ) {

        # with this, you can call the different methods to get the current values
    }
    if ( $current =~ /operating_mode_status: (.*)/ ) {
        print "thermostat operating mode is: $1\n";
    }
}

$v_Livingroom_Thermostat_mode = new Voice_Cmd(
    "Set the Livingroom Thermostat mode to [off, heat, cool, auto]");
$Livingroom_Thermostat->mode( $v_Livingroom_Thermostat_mode->{state} )
  if ( said $v_Livingroom_Thermostat_mode);

#$v_Master_Bedroom_Thermostat_mode = new Voice_Cmd("Set the Master Bedroom Thermostat mode to [off, heat, cool, auto]");
#$Master_Bedroom_Thermostat->mode($v_Master_Bedroom_Thermostat_mode->{state}) if (said $v_Master_Bedroom_Thermostat_mode);

