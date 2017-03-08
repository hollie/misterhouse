# Category=HVAC

# MisterHouse Ecobee3 thermostat controller
# Brian Rudy (brudyNO@SPAMpraecogito.com)
#
# For additional functionality and configuration requirements, see Ecobee.pm

# Home/away
if ( my $state = state_now $home_occupants) {
    if ( $state eq "home" ) {
        print_log "Setting thermostat to home mode (occupants home)";
        $ecobee_thermo->set_hold("climate_nextTransition_home");
    }
    else {
        print_log "Setting thermostat to away mode (occupants away)";
        $ecobee_thermo->set_hold("climate_nextTransition_away");
    }
}

# New stuff that interacts with the Ecobee MH module

$v_query_ecobee_temp = new Voice_Cmd 'Get current thermostat temperature';

if ( my $state = said $v_query_ecobee_temp) {
    print_log "Getting current thermostat temperature";
    my $actualTemp = $ecobee_thermo->get_temp();
    print_log "The thermostat temperature is $actualTemp";
}

if ( my $state = state_now $ecobee_thermo) {
    print_log "Ecobee temperature is now " . ( $state * 0.1 ) . " degrees F";
}

if ( my $state = state_now $thermo_humid) {
    print_log "Ecobee humidity is now $state\%";
}

if ( my $state = state_now $thermo_hvac_status) {
    print_log "Ecobee status is now $state";
}

if ( my $state = state_now $thermo_mode) {
    print_log "Ecobee mode is now $state";
}

if ( my $state = state_now $thermo_climate) {
    print_log "Ecobee climate is now $state";
}

$v_clear_ecobee_hold = new Voice_Cmd 'Clear thermostat hold';
if ( my $state = said $v_clear_ecobee_hold) {
    print_log "Clearing the current thermostat hold";
    $ecobee_thermo->clear_hold();
}

$v_set_temp_hold = new Voice_Cmd 'Set thermostat temperature hold';
if ( my $state = said $v_set_temp_hold) {
    print_log "Setting a thermostat temperature hold";
    $ecobee_thermo->set_hold("temperature_nextTransition_740_760");
}

$v_set_climate_hold = new Voice_Cmd 'Set thermostat climate hold to [home,away,sleep]';
if ( my $state = said $v_set_climate_hold) {
    print_log "Setting a thermostat climate hold to $state";
    $ecobee_thermo->set_hold("climate_nextTransition_$state");
}

