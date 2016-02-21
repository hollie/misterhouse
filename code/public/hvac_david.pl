
=begin comment

This code module controls the HVAC system replacing the thermostat. I still have the house
thermostat as a standby set at 60 degrees. 

Each room has a iButton temperature probe that is read using an external program called digitemp.
The digitemp readings are logged into separate RRD databases. Misterhouse pulls the latest readings
from the RRD database. With 19 different iButtons I have found this to be the best solution.

Misterhouse controls the HVAC system through a a Weeder Solid State Reply board. 
The weeder SS Relay is configured in a separate code file as follows:

	$hvac_heat_relay           = new  Serial_Item('ACA', ON, 'weeder');
	$hvac_heat_relay                  -> add     ('AOA', OFF, 'weeder');
	$hvac_heat_relay                  -> add     ('ARA', 'status', 'weeder');

	$hvac_ac_relay            = new   Serial_Item('ACB', ON, 'weeder');
	$hvac_ac_relay                    -> add     ('AOB', OFF, 'weeder');
	$hvac_ac_relay                    -> add     ('ARB', 'status', 'weeder');

	$hvac_fan_relay           = new   Serial_Item('ACC', ON, 'weeder');
	$hvac_fan_relay                   -> add     ('AOC', OFF, 'weeder');
	$hvac_fan_relay                   -> add     ('ARC', 'status', 'weeder');


Good luck and remember to have a backup thermostat!!!!!!!!!

Dave Lounsberry, dbl@dittos.yi.org

=cut

#$TempNicole   		= new Weather_Item 'TempNicole';    	# Nicole's bedroom ibutton temp
#$TempEric     		= new Weather_Item 'TempEric';  	# Eric's bedroom ibutton temp
#$TempLiving   		= new Weather_Item 'TempLiving';    	# Living Room ibutton temp
#$TempAttic    		= new Weather_Item 'TempAttic';     	# Attic ibutton temp
#$TempOutdoor  		= new Weather_Item 'TempOutdoor';   	# Outdoor ibuttom temp
#$TempPond     		= new Weather_Item 'TempPond';      	# Fish pond outside
#$TempDiningVault   	= new Weather_Item 'TempDiningVault'; 	# Dining Room Vault temp
#$TempMasterVault   	= new Weather_Item 'TempMasterVault';  	# Mater Bedroom Vault temp
#$TempMaster   		= new Weather_Item 'TempMaster';  	# Mater Bedroom temp
#$TempPlayRoom   	= new Weather_Item 'TempPlayRoom';    	# Playroom temp
#$TempGarage   		= new Weather_Item 'TempGarage';    	# Garage temp
#$TempHVACDuct   	= new Weather_Item 'TempHVACDuct';    	# HVAC Duct temp
#$TempHVACReturn   	= new Weather_Item 'TempHVACReturn';    # HVAC Return Duct temp
#$TempOffice   		= new Weather_Item 'TempOffice';        # Office temp
#
#$TempIndoor   		= new Weather_Item 'TempIndoor';    	# The average temp to use as whole house temp
#
# Category=HVAC_Auto
$v_heat_onoff_temp =
  new Voice_Cmd('Set HVAC heat auto on off temp [50,55,60,65,70]');
$v_heat_onoff_temp->set_info(
    'What temperature will Misterhouse automatically turn off the HVAC heat control',
    undef, 1
);
if ( $state = said $v_heat_onoff_temp) {
    $Save{hvac_heat_auto_onoff_temp} = $state;
    speak(
        play => "hvac",
        text => "The HVAC auto on off outside temp set to $state degrees."
    );
    print_log "The HVAC auto on off outside temp set to $state degrees.";
    &check_auto_onoff;
}

$v_ac_onoff_temp = new Voice_Cmd(
    'Set HVAC AC auto on off temp [70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85]'
);
$v_ac_onoff_temp->set_info(
    'What temperature will Misterhouse automatically turn off the HVAC AC control',
    undef, 1
);
if ( $state = said $v_ac_onoff_temp) {
    $Save{hvac_ac_auto_onoff_temp} = $state;
    speak(
        play => "hvac",
        text => "The HVAC auto on off outside temp set to $state degrees."
    );
    print_log "The HVAC auto on off outside temp set to $state degrees.";
    &check_auto_onoff;
}

$v_hvac_auto_onoff =
  new Voice_Cmd( 'HVAC auto on/off control [heat,ac,off]', undef, 1 );
$v_hvac_auto_onoff->set_info(
    'Sets whether misterhouse will turn off HVAC modes automatically',
    undef, 1 );
if ( $state = said $v_hvac_auto_onoff) {
    print_log "HVAC auto on/off is now $state";
    speak( play => "hvac", text => "HVAC auto on and off is now $state" );
    $Save{hvac_auto_onoff} = $state;
    &update_hvac_state("HVAC recycling");
    &check_auto_onoff;
}

# Category=HVAC_Control

$v_hvac_control = new Voice_Cmd( 'HVAC control [on,off]', undef, 1 );
$v_hvac_control->set_info(
    'Sets whether misterhouse will control the HVAC system',
    undef, 1 );
if ( $state = said $v_hvac_control) {
    if ( $state eq 'off' ) {
        &hvac_on_off(OFF);
    }
    $Save{hvac_control} = $state;
    print_log "HVAC control is now $state";
    speak( play => "hvac", text => "HVAC control is now $state" );
}

$v_hvac_mode = new Voice_Cmd( 'HVAC mode [heat,AC,off]', undef, 1 );
$v_hvac_mode->set_info(
    'Manually set the misterhouse thermostat to heat, AC or off. Misterhouse may decide to change it to something else though.',
    undef, 1
);
if ( $state = said $v_hvac_mode) {
    if ( $state eq 'off' ) {
        &hvac_on_off(OFF);
    }
    $Save{hvac_mode} = $state;
    print_log "HVAC mode has been set to $state";
}

$v_thermo_temp = new Voice_Cmd(
    'Set daytime thermostat to [65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80]'
);
$v_thermo_temp->set_info(
    'Misterhouse thermostat setting during the day (home and awake).');
if ( $state = said $v_thermo_temp) {
    $Save{daytime_temp} = $state;
    speak(
        play => "hvac",
        text => "The day time thermostat is now set to $state degrees."
    );
    print_log "The day time thermostat is now set to $state degrees.";
    &set_thermostat;
}

$v_travel_temp = new Voice_Cmd(
    'Set travel thermostat to [60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80]'
);
$v_thermo_temp->set_info('Misterhouse thermostat setting when traveling.');
if ( $state = said $v_travel_temp) {
    $Save{travel_temp} = $state;
    speak(
        play => "hvac",
        text => "The travel thermostat is now set to $state degrees."
    );
    print_log "The travel thermostat is now set to $state degrees.";
    &set_thermostat;
}

$v_away_thermo_temp = new Voice_Cmd(
    'Set away thermostat to [60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80]'
);
if ( $state = said $v_away_thermo_temp) {
    $Save{away_temp} = $state;
    speak(
        play => "hvac",
        text => "The away thermostat is now set to $state degrees."
    );
    print_log "The away thermostat is now set to $state degrees.";
    &set_thermostat;
}

$v_sleep_thermo_temp = new Voice_Cmd(
    'Set sleep thermostat to [65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80]'
);
if ( $state = said $v_sleep_thermo_temp) {
    $Save{sleep_temp} = $state;
    speak(
        play => "hvac",
        text => "The sleep thermostat is now set to $state degrees."
    );
    print_log "The sleep thermostat is now set to $state degrees.";
    &set_thermostat;
}

$hvac_recycle_timer = new Timer();

$v_hvac_recycle =
  new Voice_Cmd( 'HVAC time before recycle [30,60,90,120,150,180,210,240]',
    undef, 1 );
if ( $state = said $v_hvac_recycle) {
    speak(
        play => "hvac",
        text => "HVAC time before recycle is now $state minutes."
    );
    $Save{hvac_recycle_min} = $state;
}

$v_hvac_recycle_time =
  new Voice_Cmd( 'HVAC recycle time [5,10,15,20,30,40,50,60]', undef, 1 );
if ( $state = said $v_hvac_recycle_time) {
    speak( play => "hvac", text => "HVAC recycle time is now $state minutes." );
    $Save{hvac_recycle_time_min} = $state;
}

$v_attic_fan_control = new Voice_Cmd( 'Attic fan control [on,off]', undef, 1 );
if ( $state = said $v_attic_fan_control) {
    print_log "Attic fan control is now $state";
    speak( play => "hvac", text => "Attic fan control is now $state" );
    $Save{attic_fan_control} = $state;
}

# just remind the house that misterhouse will not control the HVAC system.
if ( ( time_cron '0 8,11,14,17,22 * * *' ) and ( $Save{hvac_control} ne 'on' ) )
{
    $Save{hvac_control} = 'off';    # if not on, then it should be off.
    speak( play => "hvac", text => "HVAC control is off." );
}

# check thermostat setting every 5 minutes and adjust if necessary
if (new_minute) {
    &set_thermostat;
}

if ($New_Minute) {

    # fetch the latest temp readings from the RRDs for each sensor.
    my @outside_temp = &fetch_rrd_hilo("outside");
    my @living_temp  = &fetch_rrd_hilo("living_room");
    my @master_temp  = &fetch_rrd_hilo("master_bedroom");
    my @pond_temp    = &fetch_rrd_hilo("pond");
    my @attic_temp   = &fetch_rrd_hilo("attic");
    my @nicole_temp  = &fetch_rrd_hilo("nicole_bedroom");
    my @eric_temp    = &fetch_rrd_hilo("eric_bedroom");

    # populate Weather variables used for HVAC control
    $Weather{TempOutdoor} = round $outside_temp[1];      # round with 1 digit
    $Weather{TempLiving}  = round $living_temp[1], 2;    # round with 2 digits
    $Weather{TempMaster}  = round $master_temp[1], 2;    # round with 2 digits
    $Weather{TempPond}    = round $pond_temp[1], 2;      # round with 2 digits
    $Weather{TempAttic}   = round $attic_temp[1], 2;     # round with 2 digits
    $Weather{TempEric}    = round $eric_temp[1], 2;      # round with 2 digits
    $Weather{TempNicole}  = round $nicole_temp[1], 2;    # round with 2 digits

    # put the thermostat setting in rrd for graphing along with temps
    &update_rrd( "thermostat", $Save{thermostat} ) if $Save{hvac_mode} ne 'off';

    if (    $Save{hvac_mode} eq 'AC'
        and $Save{sleeping_parents} eq 'on'
        and $Weather{TempMaster} )
    {
        $Weather{TempIndoor} = $Weather{TempMaster};
    }
    else {
        my $temp = 0;
        my $tot  = 0;
        if ( $Weather{TempLiving} ) {
            $temp += $Weather{TempLiving};
            $tot++;
        }
        if ( $Weather{TempNicole} ) {
            $temp += $Weather{TempNicole};
            $tot++;
        }
        if ( $Weather{TempEric} ) {
            $temp += $Weather{TempEric};
            $tot++;
        }
        $Weather{TempIndoor} = round $temp/ $tot, 2;
    }

    if (    new_minute 15
        and $Save{hvac_mode} ne 'off'
        and $Save{hvac_control} eq 'on' )
    {
        my $fstate = 'NA';
        if ( $Save{hvac_mode} eq 'heat' ) {
            $fstate = state $hvac_heat_relay;
        }
        elsif ( $Save{hvac_mode} eq 'AC' ) {
            $fstate = state $hvac_ac_relay;
        }
        print_log(
            "Thermostat check: Indoor:$Weather{TempIndoor},  ThermoStat:$Save{thermostat},  Mode:$Save{hvac_mode},  State:$fstate"
        );
    }

    # make sure we don't have a problem
    if (   ( $Save{hvac_mode} eq 'heat' and $Weather{TempIndoor} > 73 )
        or ( $Save{hvac_mode} eq 'AC' and $Weather{TempIndoor} < 65 ) )
    {
        speak(
            play => "hvac",
            text =>
              "Whoaa dude! The indoor temperature is $Weather{TempIndoor} degrees. Yikes!"
        );
        &hvac_on_off(OFF);
    }

    if ( $Save{attic_fan_control} eq 'on' ) {
        if (    $Weather{TempIndoor}
            and $Weather{TempIndoor} >= ( $Save{thermostat} + 5 ) )
        {    # it's warm inside
            if (    $Weather{TempOutdoor}
                and $Weather{TempOutdoor} <= $Save{thermostat} - 5 )
            {    # it's cold outside
                if (    $Save{attic_fan_mode} ne 'on'
                    and $Save{house_occupied} eq 'on' )
                {
                    $Save{attic_fan_mode} = 'on';
                    speak(
                        play => "hvac",
                        text =>
                          "The outside temperature is $Weather{TempOutdoor}, the inside temperature is $Weather{TempIndoor}. You might want to open the windows and turn on the attic fan."
                    );
                }
            }
        }
        elsif ( $Weather{TempIndoor}
            and $Weather{TempIndoor} < ( $Save{thermostat} - 1 ) )
        {
            if (    $Save{attic_fan_mode} eq 'on'
                and $Save{house_occupied} eq 'on' )
            {
                $Save{attic_fan_mode} = 'off';
                speak(
                    play => "hvac",
                    text =>
                      "The inside temperature is $Weather{TempIndoor}. If the attic fan is on, you should probably turn it off."
                );
            }
        }
    }

    if ( $Save{hvac_control} eq 'on' ) {
        &check_auto_onoff;

        # ----------------------------------------------------------------------
        # Cooling section
        # ----------------------------------------------------------------------
        if ( $Save{hvac_mode} eq 'AC' ) {
            $Weather{TempIndoor} = $Save{TempIndoor} if !$Weather{TempIndoor};
            $state = state $hvac_ac_relay;
            my $hyster   = .5;
            my $too_cold = 65;
            if ( $state eq OFF ) {
                if (    $Weather{TempIndoor}
                    and $Weather{TempIndoor} >=
                    ( $Save{thermostat} + $hyster ) )
                {
                    if ( active $hvac_recycle_timer) {
                        print_log("HVAC recycle timer active, waiting.");
                    }
                    else {
                        &hvac_on_off(ON);
                    }
                }
            }
            elsif ( $state eq ON ) {
                if (    $Weather{TempIndoor}
                    and $Weather{TempIndoor} <=
                    ( $Save{thermostat} - $hyster ) )
                {
                    &hvac_on_off(OFF);
                }
                else {
                    &check_for_recycle;
                }
            }

        }    # end cooling section

        # ----------------------------------------------------------------------
        # Heating section
        # ----------------------------------------------------------------------
        if ( $Save{hvac_mode} eq 'heat' ) {
            $Weather{TempIndoor} = $Save{TempIndoor} if !$Weather{TempIndoor};
            $state = state $hvac_heat_relay;
            my $hyster  = 1;
            my $too_hot = 75;
            if ( $state eq OFF ) {
                if (    $Weather{TempIndoor}
                    and $Weather{TempIndoor} <=
                    ( $Save{thermostat} - $hyster ) )
                {
                    if ( active $hvac_recycle_timer) {
                        print_log("HVAC recycle timer active, waiting.");
                    }
                    else {
                        &hvac_on_off(ON);
                    }
                }
            }
            elsif ( $state eq ON ) {
                if (    $Weather{TempIndoor}
                    and $Weather{TempIndoor} >=
                    ( $Save{thermostat} + $hyster ) )
                {
                    &hvac_on_off(OFF);
                }
                else {
                    &check_for_recycle;
                }
            }

        }    # end heating section
    }
    elsif ( $Save{hvac_control} eq 'off' ) {
        my $state;
        $state = state $hvac_heat_relay if $Save{hvac_mode} eq 'heat';
        $state = state $hvac_ac_relay   if $Save{hvac_mode} eq 'AC';
        &hvac_on_off(OFF) if $state ne OFF;
    }
}

sub check_for_recycle {
    my $hvac_time_diff = ( $Time - $Save{hvac_time} );

    #print_log ("hvac_time_diff = $hvac_time_diff, Save{hvac_recycle_min) = $Save{hvac_recycle_min}*60");
    if ( $hvac_time_diff >= $Save{hvac_recycle_min} * 60 ) {
        my $nice_hvac_time_diff = &time_diff($hvac_time_diff);

        #print_log ("nice_hvac_time_diff = $nice_hvac_time_diff");
        speak(
            play => "hvac",
            text =>
              "The HVAC has been running for $nice_hvac_time_diff. Turning off for recycle."
        );
        set $hvac_recycle_timer ( $Save{hvac_recycle_time_min} * 60 );
        &hvac_on_off(OFF);
        &update_hvac_state("HVAC recycling");
    }
    return;
}

sub check_auto_onoff {
    return unless $Save{hvac_control} eq 'on';

    if ( $Save{travel_mode} eq 'on' ) {
        &update_hvac_state("HVAC recycling");
        return;
    }
    if ( $Save{hvac_auto_onoff} ne 'off' ) {
        if ( $Save{hvac_mode} eq 'off' ) {

            # should the HVAC be on?
            if ( $Save{hvac_auto_onoff} eq 'heat' ) {
                if (    $Weather{TempOutdoor}
                    and $Weather{TempOutdoor} <=
                    $Save{hvac_heat_auto_onoff_temp} )
                {
                    if (    $Weather{TempIndoor}
                        and $Weather{TempIndoor} <= $Save{thermostat} - 1 )
                    {    # it's cold outside
                        if ( $Save{house_occupied} eq 'on' )
                        {    # it's hot outside
                            speak(
                                play => "hvac",
                                text =>
                                  "The outdoor temperature is $Weather{TempOutdoor} degrees and the inside temperature is $Weather{TempIndoor}. Setting HVAC to heat. If the windows are open, you should close them."
                            );
                            run_voice_cmd 'HVAC mode heat';
                            &update_hvac_state("Thermostat controlled cycle");
                        }
                        else {
                            &update_hvac_state(
                                "Ready to switch to heat, but waiting for occupancy"
                            );
                        }
                    }
                    else {
                        &update_hvac_state(
                            "Ready to switch to heat, but waiting for inside temp to go below thermostat."
                        );
                    }
                }
                else {
                    &update_hvac_state(
                        "Outside temp warmer than heat auto onoff temp");
                }
            }
            elsif ( $Save{hvac_auto_onoff} eq 'ac' ) {
                if (    $Weather{TempOutdoor}
                    and $Weather{TempOutdoor} >=
                    $Save{hvac_ac_auto_onoff_temp} )
                {
                    if (    $Weather{TempIndoor}
                        and $Weather{TempIndoor} >= $Save{thermostat} + 1 )
                    {
                        if ( $Save{house_occupied} eq 'on' )
                        {    # it's hot outside
                            speak(
                                play => "hvac",
                                text =>
                                  "The outdoor temperature is $Weather{TempOutdoor} degrees and the inside temperature is $Weather{TempIndoor}. Setting HVAC to AC. If the windows are open, you should close them."
                            );
                            run_voice_cmd 'HVAC mode AC';
                            &update_hvac_state("Thermostat controlled cycle");
                        }
                        else {
                            &update_hvac_state(
                                "Ready to switch to AC, but waiting for occupancy"
                            );
                        }
                    }
                    else {
                        &update_hvac_state(
                            "Ready to switch to AC, but waiting for inside temp to exceed thermostat."
                        );
                    }
                }
                else {
                    &update_hvac_state(
                        "Outside temp colder than AC auto onoff temp");
                }

            }

        }
        elsif ( $Save{hvac_mode} eq 'heat' ) {

            # should the furnace be off?
            if (    $Weather{TempOutdoor}
                and $Weather{TempOutdoor} > $Save{hvac_heat_auto_onoff_temp} )
            {
                speak(
                    play => "hvac",
                    text =>
                      "The outdoor temperature is $Weather{TempOutdoor} degrees. Setting HVAC to off. Maybe you should open the windows?"
                );
                &hvac_on_off(OFF);
                run_voice_cmd 'HVAC mode off';
                &update_hvac_state(
                    "Outside temp more than HEAT auto onoff setting.");
            }
        }
        elsif ( $Save{hvac_mode} eq 'AC' ) {

            # leave AC on or off
            if (    $Weather{TempOutdoor}
                and $Weather{TempOutdoor} < $Save{hvac_ac_auto_onoff_temp} )
            {
                speak(
                    play => "hvac",
                    text =>
                      "The outdoor temperature is $Weather{TempOutdoor} degrees. Setting HVAC to off. Maybe you should open the windows?"
                );
                &hvac_on_off(OFF);
                run_voice_cmd 'HVAC mode off';
                &update_hvac_state(
                    "Outside temp less than AC auto onoff setting.");
            }
        }
    }
    else {
        &update_hvac_state("Auto off: Thermostat controlled cycle");
    }
    return;
}

sub set_thermostat {
    return unless $Save{hvac_control} eq 'on';

    &check_auto_onoff;

    # if no one is home, cut the thermostat
    if ( $Save{travel_mode} eq 'on' ) {
        if ( $Save{thermostat} != $Save{travel_temp} ) {
            print_log "Setting thermostat to travel setting.";
            speak(
                play => "hvac",
                text => "Setting thermostat to $Save{travel_temp} degrees."
            );
            $Save{thermostat} = $Save{travel_temp};
        }
    }
    elsif ( $Save{house_occupied} eq 'off' ) {
        if ( $Save{thermostat} != $Save{away_temp} ) {
            print_log "Setting thermostat to away setting.";
            speak(
                play => "hvac",
                text => "Setting thermostat to $Save{away_temp} degrees."
            );
            $Save{thermostat} = $Save{away_temp};
        }
    }
    elsif ( $Save{sleeping_parents} eq 'on' ) {    # sleeping
        if ( $Save{thermostat} != $Save{sleep_temp} ) {
            print_log "Setting thermostat to sleep setting.";
            speak(
                play => "hvac",
                text => "Setting thermostat to $Save{sleep_temp} degrees."
            );
            $Save{thermostat} = $Save{sleep_temp};
        }
    }
    else {                                         # daytime and someone is home
        if ( $Save{thermostat} != $Save{daytime_temp} ) {
            print_log "Setting thermostat to occupied awake setting.";
            speak(
                play => "hvac",
                text => "Setting thermostat to $Save{daytime_temp} degrees."
            );
            $Save{thermostat} = $Save{daytime_temp};
        }
    }
    return;
}

##################################################
# Attic cooling
##################################################
if ( $Season eq 'Summer' and new_minute 10 ) {

    # powered attic vent, keep the attic cool on those hot days
    my $mode;
    my $gradient = $Weather{TempAttic} - $Weather{TempOutdoor};

    #print_log "TempAttic=$Weather{TempAttic}";
    print_log
      "Attic/Outside/Inside Temp Check: A:$Weather{TempAttic}, O:$Weather{TempOutdoor},  I:$Weather{TempIndoor},  G:$gradient, mode:$mode, current_state="
      . state $roof_vent_fan;

    if ( ( $Weather{TempIndoor} < $Weather{TempOutdoor} && $gradient > 20 ) )
    {    # dont want the attic heating
        $mode = 1;
        set $roof_vent_fan ON;
    }
    else {
        $mode = 0;
        set $roof_vent_fan OFF;
    }

    if ( state $roof_vent_fan ne ON && state $roof_vent_fan ne OFF ) {
        run_voice_cmd 'Turn roof vent fan off';
        print_log "Invalid ROOF VENT FAN status set to OFF";
    }

    if ( $mode == 0 && state $roof_vent_fan eq ON ) {
        run_voice_cmd 'Turn roof vent fan off';
    }
    if ( $mode == 1 && state $roof_vent_fan eq OFF ) {
        run_voice_cmd 'Turn roof vent fan on';
    }
}

$v_vent_fan = new Voice_Cmd("Turn roof vent fan [on,off]");
if ( $state = said $v_vent_fan) {
    if ( $state eq ON ) {
        play("sound_effects/TypeKey.au");
        set $roof_vent_fan ON;
        if ( state $roof_vent_fan ne ON ) {
            print_log "The ROOF VENT FAN turned ON";
        }
    }
    elsif ( $state eq OFF ) {
        set $roof_vent_fan OFF;
        if ( state $roof_vent_fan eq ON ) {
            print_log "The ROOF VENT FAN turned OFF";
        }
    }
}

$v_hvac_filter_maxuse = new Voice_Cmd(
    'Remind HVAC filter change every [200,250,300,350,400,450,500] hours',
    undef, 1 );
if ( $state = said $v_hvac_filter_maxuse) {
    $Save{hvac_filter_maxuse_hr} = $state;
    print(
        play => "hvac",
        text => "HVAC filter change reminder set to $state hours."
    );
}

$v_hvac_filter_changed =
  new Voice_Cmd( 'HVAC filter has been changed', undef, 1 );
if ( $state = said $v_hvac_filter_changed) {
    print_log "HVAC filter has been changed, Resetting timer.";
    speak(
        play => "hvac",
        text => "HVAC filter has been changed. Resetting timer."
    );
    run_voice_cmd 'stop HVAC filter timer';
    if ( state $hvac_heat_relay eq 'on' or state $hvac_ac_relay eq 'on' ) {
        run_voice_cmd 'start HVAC filter timer';
    }
}

sub hvac_on_off {
    ($state) = @_;
    return unless $state eq ON or $state eq OFF;

    my $hvac_time_diff = &time_diff( $Save{hvac_time}, $Time );
    return unless $Save{hvac_mode} eq 'heat' or $Save{hvac_mode} eq 'AC';

    speak( play => "hvac_" . $state );
    print_log
      "HVAC $Save{hvac_mode} has been turned $state temp=$Weather{TempIndoor} time=$hvac_time_diff";
    logit( "$config_parms{data_dir}/logs/hvac.$Year_Month_Now.log",
        "state=$state  mode=$Save{hvac_mode}  temp=$Weather{TempIndoor}  time=$hvac_time_diff  "
    );

    if ( $Save{hvac_mode} eq 'heat' ) {
        set $hvac_heat_relay $state;
    }
    if ( $Save{hvac_mode} eq 'AC' ) {
        set $hvac_ac_relay $state;
    }
    $Save{hvac_time} = $Time;
    if ( $state eq ON ) {
        &Timer::resume($hvac_on_timer);
        &Timer::resume($hvac_filter_timer);
        &filter_check;
    }
    if ( $state eq OFF ) {
        &Timer::pause($hvac_on_timer);
        &Timer::pause($hvac_filter_timer);
    }

    #
    # erics register is close to furnace and tends to push more heat than
    # necessary for this smaller room. Check his room temp and compare to Nicoles
    # bedroom temp which is on end of duct run to make sure someone
    # has not opened the register too far, roasting my little guy.
    #

    #	if ($Weather{TempEric} >= ($Weather{TempIndoor} + 2)) {
    #		speak (play=>"hvac", text=>"Erics bedroom is too warm. Check his register.");
    #	} elsif ($Weather{TempIndoor} >= ($Weather{TempEric} + 2)) {
    #		speak (play=>"hvac", text=>"Erics bedroom is too cold. Check his register.");
    #	}
##
    #	if ($Weather{TempNicole} >= ($Weather{TempIndoor} + 2)) {
    #		speak (play=>"hvac", text=>"Nicoles bedroom is too warm. Check her registers.");
    #	} elsif ($Weather{TempIndoor} >= ($Weather{TempNicole} + 2)) {
    #		speak (play=>"hvac", text=>"Nicoles bedroom is too cold. Check her registers.");
    #	}

    return;
}

sub filter_check {

    # check the life of the furnace filter.
    my $used = round &Timer::query($hvac_filter_timer) / 60 / 60,
      2;    # hvac_filter_timer is in seconds, we track by hours
    if ( !$Save{hvac_filter_maxuse_hr} ) {
        speak( play => "hvac", text => "HVAC filter max use is not set." );
        return;
    }
    print_log
      "HVAC filter has been used $used hrs. (Max: $Save{hvac_filter_maxuse_hr} hrs.)";
    if ( $used >= $Save{hvac_filter_maxuse_hr} ) {
        speak( play => "hvac", text => "The HVAC filter needs to be changed." );
    }
    return;
}

sub web_hvac_on_use {

    # for web interface, return hours hvac has been used.
    return round &Timer::query($hvac_on_timer) / 60 / 60, 2;
}

sub web_hvac_filter_use {

    # for web interface, return hours hvac filter has been used.
    return round &Timer::query($hvac_filter_timer) / 60 / 60, 2;
}

sub web_hvac_vars {

    # populate Weather variables NOT used for HVAC control. Only updated when viewed via web interface.
    my @dining_vault_temp = &fetch_rrd_hilo("dining_vault");
    my @master_vault_temp = &fetch_rrd_hilo("master_vault");
    my @play_room_temp    = &fetch_rrd_hilo("playroom");
    my @garage_temp       = &fetch_rrd_hilo("garage");
    my @hvac_return_temp  = &fetch_rrd_hilo("hvac_in");
    my @hvac_duct_temp    = &fetch_rrd_hilo("hvac_out");
    my @office_temp       = &fetch_rrd_hilo("office");

    $Weather{TempDiningVault} = round $dining_vault_temp[1],
      2;    # round with 2 digits
    $Weather{TempMasterVault} = round $master_vault_temp[1],
      2;    # round with 2 digits
    $Weather{TempPlayRoom} = round $play_room_temp[1], 2;  # round with 2 digits
    $Weather{TempGarage}   = round $garage_temp[1],    2;  # round with 2 digits
    $Weather{TempHVACDuct} = round $hvac_duct_temp[1], 2;  # round with 2 digits
    $Weather{TempHVACReturn} = round $hvac_return_temp[1],
      2;                                                   # round with 2 digits
    $Weather{TempOffice} = round $office_temp[1], 2;       # round with 2 digits
    return;
}

sub update_hvac_state {
    ($state) = @_;
    if ( $Save{travel_mode} eq 'on' ) {
        $Save{hvac_state} = "Travel mode: ";
    }
    elsif ( $Save{house_occupied} eq 'on' ) {
        $Save{hvac_state} = "House Occupied: ";
    }
    elsif ( $Save{sleeping_parents} eq 'on' ) {
        $Save{hvac_state} = "Sleeping: ";
    }
    else {
        $Save{hvac_state} = "House Empty: ";
    }
    $Save{hvac_state} .= "$state";
    return;
}
