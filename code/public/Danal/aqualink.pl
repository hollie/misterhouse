# Category=Pool

#@ Jandy Aqualink Interface for swimming pool and spa

=begin comment

aqualink.pl
 2.0 Extensive rework of Tim's original by Danal Estes <danal@earthling.net> - 11/2002

 1.1 Misc enhancements by Tim Doyle <tim@greenscourt.com> - 11/17/2001
     Fixed AUX naming bug
     Queries pool data at startup and saves data for use later (like on Audrey pages)
     Plays alert.wav if the pool temp drops below 40 degrees
     Fixed the 'spa' command
     Logs spa temp data when heating
     General fine-tuning

 1.0 Original version by Tim Doyle <tim@greenscourt.com> - 5/9/2001

This script allows MisterHouse to communicate with a Jandy AquaLink RS
Serial Adapter (#7620), allowing for Home Automation control of a Jandy
AquaLink RS Pool Control system.

=cut

my $command;
my $data;
my $state;
my $units;
my $value;
my $Cleaner;
my $SpaReady;
my $SpaHeating;
my $Waterfall;

my $AIRTMPmode  = '';
my $POOLTMPmode = '';
my $SPATMPmode  = '';
my $SOLTMPmode  = '';
my $AUX1mode    = '';
my $AUX2mode    = '';
my $AUX3mode    = '';
my $AUX4mode    = '';
my $AUX5mode    = '';
my $AUXXmode    = '';
my $CLEANRmode  = '';
my $OPMODEmode  = '';
my $POOLHTmode  = '';
my $POOLSPmode  = '';
my $PUMPmode    = '';
my $SPAmode     = '';
my $SPASPmode   = '';
my $SPAHTmode   = '';
my $VBATmode    = '';

my $AUX1 =
  ( $config_parms{Jandy_AUX1} )
  ? $config_parms{Jandy_AUX1}
  : 'pool auxiliary device 1';
my $AUX2 =
  ( $config_parms{Jandy_AUX2} )
  ? $config_parms{Jandy_AUX2}
  : 'pool auxiliary device 2';
my $AUX3 =
  ( $config_parms{Jandy_AUX3} )
  ? $config_parms{Jandy_AUX3}
  : 'pool auxiliary device 3';
my $AUX4 =
  ( $config_parms{Jandy_AUX4} )
  ? $config_parms{Jandy_AUX4}
  : 'pool auxiliary device 4';
my $AUX5 =
  ( $config_parms{Jandy_AUX5} )
  ? $config_parms{Jandy_AUX5}
  : 'pool auxiliary device 5';
my $AUXX =
  ( $config_parms{Jandy_AUXX} )
  ? $config_parms{Jandy_AUXX}
  : 'pool auxiliary device X or Solar';
my $CLEANR =
  ( $config_parms{Jandy_Cleaner} )
  ? $config_parms{Jandy_Cleaner}
  : 'Pool Cleaner';

$aqualink = new Serial_Item( undef, undef, 'serial11' );

if ($Reload) {
    set $aqualink "#ECHO=0";       #Don't echo our commands
    set $aqualink "#COSMSGS=1";    #Tell us when things change
    &aqualinklog("Started");

    #  set $aqualink "#OPTIONS?";                        #Get the Power Center Options
}

#if ($New_Minute) {
#  if ($SpaReady eq 'true') {
#    set $aqualink "#SPATMP?";
#  }
#}

if ( $data = said $aqualink ) {
    $data =~ s/\n//;
    $data =~ s/\r//;
    print_log "Aqualink: $data";

    if ( $data =~ m#^!00\s(\S+)\s=\s(.*)# ) {
        my $command = $1;
        my $value   = $2;

        if ( $value eq '1' ) { $value = 'on'; }
        if ( $value eq '0' ) { $value = 'off'; }

        if ( $value =~ m#^(\S+)\s([F|C])# ) {
            $value = $1;
            $units = $2;
        }

        if ( $command eq 'AIRTMP' ) {
            &aqualinklog("Air Temp $value $AIRTMPmode");
            $Save{PoolAIRTMP} = $value;
            speak
              "Djeeni says: Pool Air temperature is currently $value degrees."
              if $AIRTMPmode ne '';
            $AIRTMPmode = '';
        }

        if ( $command eq 'AUX1' ) {
            &aqualinklog("AUX1 $value $AUX1mode");
            $Save{PoolAUX1} = $value;
            speak "Djeeni says: $AUX1 is currently $value." if $AUX1mode ne '';
            $AUX1mode = '';
        }

        if ( $command eq 'CLEANR' ) {
            &aqualinklog("CLEANR $value $CLEANRmode");
            $Save{PoolCLEANR} = $value;
            speak "Djeeni says: $CLEANR is currently $value."
              if $CLEANRmode ne '';
            $CLEANRmode = '';
        }

        if ( $command eq 'AUX2' ) {
            &aqualinklog("AUX2 $value $AUX2mode");
            $Save{PoolAUX2} = $value;
            speak "Djeeni says: $AUX2 is currently $value." if $AUX2mode ne '';
            $AUX2mode = '';
        }

        if ( $command eq 'AUX3' ) {
            &aqualinklog("AUX3 $value $AUX3mode");
            $Save{PoolAUX3} = $value;
            speak "Djeeni says: $AUX3 is currently $value." if $AUX3mode ne '';
            $AUX3mode = '';
        }

        if ( $command eq 'AUX4' ) {
            &aqualinklog("AUX4 $value $AUX4mode");
            $Save{PoolAUX4} = $value;
            speak "Djeeni says: $AUX4 is currently $value." if $AUX4mode ne '';
            $AUX4mode = '';
        }

        if ( $command eq 'AUX5' ) {
            &aqualinklog("AUX5 $value $AUX5mode");
            $Save{PoolAUX5} = $value;
            speak "Djeeni says: $AUX5 is currently $value." if $AUX5mode ne '';
            $AUX5mode = '';
            if ( $value eq 'on' ) {
                set $Pool_Maint_age ( 'Chlorine' eq state $Pool_Maint_age)
                  ? 'Oxygen'
                  : 'Chlorine';
            }
        }

        if ( $command eq 'AUXX' ) {
            &aqualinklog("AUXX $value $AUXXmode");
            $Save{PoolAUXX} = $value;
            speak "Djeeni says: $AUXX is currently $value." if $AUXXmode ne '';
            $AUXXmode = '';
        }

        if ( $command eq 'MODEL' ) {
            speak "The Aqua Link power panel is model $value.";
            $Save{PoolMODEL} = $value;
        }

        if ( $command eq 'OK' ) {
            &aqualinklog("OK");
        }

        if ( $command eq 'OPMODE' ) {
            &aqualinklog("OPMODE $value $OPMODEmode");
            $Save{PoolOPMODE} = $value;
            speak
              "Djeeni says: Aqualink system operation mode is currently $value."
              if $OPMODEmode ne '';
            $OPMODEmode = '';
        }

        if ( $command eq 'LEDS' ) {

            #It appears this data isn't updated except periodically, and thus can be stale

            speak "The LED values are $value";
            $value =~ m#^(\S+)\s(\S+)\s(\S+)\s(\S+)\s(\S+)#;
            my %table_ledcodes = qw(0 Off 1 On 2 Flash 3 Slow-Flash);
            my $LED1           = $table_ledcodes{ vec( chr($1), 0, 2 ) };
            my $LED2           = $table_ledcodes{ vec( chr($1), 1, 2 ) };
            my $LED3           = $table_ledcodes{ vec( chr($1), 2, 2 ) };
            my $LED4           = $table_ledcodes{ vec( chr($1), 3, 2 ) };
            my $LED5           = $table_ledcodes{ vec( chr($2), 0, 2 ) };
            my $LED6           = $table_ledcodes{ vec( chr($2), 1, 2 ) };
            my $LED7           = $table_ledcodes{ vec( chr($2), 2, 2 ) };
            my $LED8           = $table_ledcodes{ vec( chr($2), 3, 2 ) };
            my $LED9           = $table_ledcodes{ vec( chr($3), 0, 2 ) };
            my $LED10          = $table_ledcodes{ vec( chr($3), 1, 2 ) };
            my $LED11          = $table_ledcodes{ vec( chr($3), 2, 2 ) };
            my $LED12          = $table_ledcodes{ vec( chr($3), 3, 2 ) };
            my $LED13          = $table_ledcodes{ vec( chr($4), 0, 2 ) };
            my $LED14          = $table_ledcodes{ vec( chr($4), 1, 2 ) };
            my $LED15          = $table_ledcodes{ vec( chr($4), 2, 2 ) };
            my $LED16          = $table_ledcodes{ vec( chr($4), 3, 2 ) };
            my $LED17          = $table_ledcodes{ vec( chr($5), 0, 2 ) };
            my $LED18          = $table_ledcodes{ vec( chr($5), 1, 2 ) };
            my $LED19          = $table_ledcodes{ vec( chr($5), 2, 2 ) };
            my $LED20          = $table_ledcodes{ vec( chr($5), 3, 2 ) };

            #This is Jandy Model Dependant.
            speak "Filter Pump L E D is $LED7";
            speak "Heater L E Dees are $LED15 $LED16";
            speak "Spa Mode L E D is $LED6";
            speak "$AUX1 L E D is $LED5";
            speak "$AUX2 L E D is $LED4";
            speak "$AUX3 L E D is $LED3";
            speak "$AUX4 L E D is $LED9";
            speak "$AUX5 L E D is $LED8";
            speak "$AUXX L E D is $LED19";
        }

        if ( $command eq 'OPTIONS' ) {
            speak "Examining your Power Center Option Settings";

            #Switch 8
            if ( $value > 127 ) {
                speak "You have a heat pump";
                $value = $value - 128;
            }
            else {
                speak "You have a gas heater";
            }

            #Switch 7
            if ( $value > 63 ) {
                speak "You have an unknown setting";
                $value = $value - 64;
            }

            #Switch 6
            if ( $value > 31 ) {
                speak "You have an unknown setting";
                $value = $value - 32;
            }

            #Switch 5
            if ( $value > 15 ) {
                speak "You have an unknown setting";
                $value = $value - 16;
            }

            #Switch 4
            if ( $value > 7 ) {
                speak "You have the heater cooldown mode disabled";
                $value = $value - 8;
            }
            else {
                speak "You have the heater cooldown mode enabled";
            }

            #Switch 3
            if ( $value > 3 ) {
                speak "You have spa spillover / waterfall enabled";
                $value     = $value - 4;
                $Waterfall = '1';
            }
            else {
                speak "You have $AUX3 enabled";
                $Waterfall = '0';
            }

            #Switch 2
            if ( $value > 1 ) {
                speak "You have a two speed pump";
                $value = $value - 2;
            }
            else {
                speak "You have a one speed pump";
            }

            #Switch 1
            if ( $value > 0 ) {
                speak "You have a pool cleaner";
                $Cleaner = '1';
            }
            else {
                speak "You have $AUX1 enabled";
                $Cleaner = '0';
            }
        }

        if ( $command eq 'POOLHT' ) {
            &aqualinklog("POOLHT $value $POOLHTmode");
            $Save{PoolPOOLHT} = $value;
            speak "Djeeni says: The Pool heater is currently $value."
              if $POOLHTmode ne '';
            $POOLHTmode = '';
        }

        if ( $command eq 'POOLSP' ) {
            &aqualinklog("POOLSP $value $POOLSPmode");
            $Save{PoolPOOLSP} = $value;
            speak "Djeeni says: The Pool set point is currently $value."
              if $POOLSPmode ne '';
            $POOLSPmode = '';
        }

        if ( $command eq 'POOLTMP' ) {
            &aqualinklog("POOLTMP $value $POOLTMPmode");
            $Save{PoolPOOLTMP} = $value;
            speak "Djeeni says: The Pool temperature is currently $value."
              if $POOLTMPmode ne '';
            $POOLTMPmode = '';
        }

        if ( $command eq 'PUMP' ) {
            &aqualinklog("PUMP $value $PUMPmode");
            $Save{PoolPUMP} = $value;
            speak "Djeeni says: The Pool filter pump is currently $value."
              if $PUMPmode ne '';
            $PUMPmode = '';
        }

        if ( $command eq 'SPA' ) {
            &aqualinklog("SPA $value $SPAmode");
            $value = ( $value eq 'on' ) ? 'Spa' : 'Pool';
            $Save{PoolSPA} = $value;
            speak
              "Djeeni says: The Pool Spa mode is currently $value. Repeat $value"
              if $SPAmode ne '';
            $SPAmode = '';
        }

        if ( $command eq 'SPAHT' ) {
            &aqualinklog("SPAHT $value $SPAHTmode");
            $Save{PoolSPAHT} = $value;
            speak "Djeeni says: The Spa heater is currently $value."
              if $SPAHTmode ne '';
            $SPAHTmode = '';
        }

        if ( $command eq 'SPASP' ) {
            &aqualinklog("SPASP $value $SPASPmode");
            $Save{PoolSPASP} = $value;
            speak "Djeeni says: The Spa set point is currently $value."
              if $SPASPmode ne '';
            $SPASPmode = '';
        }

        if ( $command eq 'SPATMP' ) {
            &aqualinklog("SPATMP $value $SPATMPmode");
            $Save{PoolSPATMP} = $value;
            speak "Djeeni says: The Spa temperature is currently $value."
              if $SPATMPmode ne '';
            $SPATMPmode = '';
        }

        if ( $command eq 'VBAT' ) {
            if ( $value =~ m#^(\S+)\sLOW# ) {
                $value = $1 / 100;
                speak "Warning: The pool battery is low at $value volts.";
                &aqualinklog("Low Battery $value");
            }
            else {
                $value = $value / 100;
                &aqualinklog("VBAT $value $VBATmode");
                $Save{PoolVBAT} = $value;
                speak
                  "Djeeni says: The Pool backup battery voltage is currently $value."
                  if $VBATmode ne '';
                $VBATmode = '';
            }
        }

        if ( $command eq 'VERS' ) {
            speak "The Jandy RS Serial Adapter firmware is version $value.";
            $Save{PoolVERS} = $value;
        }

    }    # End of data looks like a response

    if ( $data =~ m#^\?(\S+)\s(.*)# ) {
        my $ErrCode = $1;
        my $ErrMesg = $2;
        speak "Aqua Link Error: $ErrMesg";
        print_log "Aqualink Error: $ErrCode $ErrMesg";
        &aqualinklog("Aqualink Error: $ErrCode $ErrMesg");
    }    # End of data looks like an error message

    #Check for a reset of the RS Serial Adapter
    if ( $data =~ m#^Jandy Products.*# ) {
        run_after_delay 2,
          sub { set $aqualink "#ECHO=0"; set $aqualink "#COSMSGS=1"; };
    }

}    # End of data from aqualink

##########################################################################
# Category=Pool Query

$v_pool_airtemp_speak = new Voice_Cmd("Pool air temperature");
set_order $v_pool_airtemp_speak '01';
set_icon $v_pool_airtemp_speak 'palmsun';
if ( $state = said $v_pool_airtemp_speak) {
    set $aqualink "#AIRTMP?";
    $AIRTMPmode = 'speak';
    select undef, undef, undef, .5;
}

$v_spa_state_speak = new Voice_Cmd("Pool/Spa status");
set_order $v_spa_state_speak '02';
set_icon $v_spa_state_speak 'query';
if ( $state = said $v_spa_state_speak) {
    set $aqualink "#SPA?";
    $SPAmode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_temp_speak = new Voice_Cmd("Pool temperature");
set_order $v_pool_temp_speak '03';
set_icon $v_pool_temp_speak 'pool';
if ( $state = said $v_pool_temp_speak) {
    set $aqualink "#POOLTMP?";
    $POOLTMPmode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_spatemp_speak = new Voice_Cmd("Spa temperature");
set_order $v_pool_spatemp_speak '04';
set_icon $v_pool_spatemp_speak 'spa';
if ( $state = said $v_pool_spatemp_speak) {
    set $aqualink "#SPATMP?";
    $SPATMPmode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_heat_speak = new Voice_Cmd("Pool heater status");
set_order $v_pool_heat_speak '05';
set_icon $v_pool_heat_speak 'pool';
if ( $state = said $v_pool_heat_speak) {
    set $aqualink "#POOLHT?";
    $POOLHTmode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_spaheat_speak = new Voice_Cmd("Spa heater status");
set_order $v_pool_spaheat_speak '06';
set_icon $v_pool_spaheat_speak 'spa';
if ( $state = said $v_pool_spaheat_speak) {
    set $aqualink "#SPAHT?";
    $SPAHTmode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_sp_speak = new Voice_Cmd("Pool setpoint");
set_order $v_pool_sp_speak '07';
set_icon $v_pool_sp_speak 'pool';
if ( $state = said $v_pool_sp_speak) {
    set $aqualink "#POOLSP?";
    $POOLSPmode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_spasp_speak = new Voice_Cmd("Spa setpoint");
set_order $v_pool_spasp_speak '08';
set_icon $v_pool_spasp_speak 'spa';
if ( $state = said $v_pool_spasp_speak) {
    set $aqualink "#SPASP?";
    $SPASPmode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_pump_speak = new Voice_Cmd("Filter pump status");
set_order $v_pool_pump_speak '09';
set_icon $v_pool_pump_speak 'pump';
if ( $state = said $v_pool_pump_speak) {
    set $aqualink "#PUMP?";
    $PUMPmode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_cleaner_speak = new Voice_Cmd("Pool cleaner status");
set_order $v_pool_cleaner_speak '10';
set_icon $v_pool_cleaner_speak 'pump';
if ( $state = said $v_pool_pump_speak) {
    set $aqualink "#CLEANR?";
    $CLEANRmode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_aux3_speak = new Voice_Cmd("$AUX3 status");
set_order $v_pool_aux3_speak '11';
set_icon $v_pool_aux3_speak 'pool';
if ( $state = said $v_pool_aux3_speak) {
    set $aqualink "#AUX3?";
    $AUX3mode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_aux2_speak = new Voice_Cmd("$AUX2 status");
set_order $v_pool_aux2_speak '12';
set_icon $v_pool_aux2_speak 'spa';
if ( $state = said $v_pool_aux2_speak) {
    set $aqualink "#AUX2?";
    $AUX2mode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_auxx_speak = new Voice_Cmd("$AUXX status");
set_order $v_pool_auxx_speak '13';
set_icon $v_pool_auxx_speak 'pool';
if ( $state = said $v_pool_auxx_speak) {
    set $aqualink "#AUXX?";
    $AUXXmode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_aux4_speak = new Voice_Cmd("$AUX4 status");
set_order $v_pool_aux4_speak '14';
set_icon $v_pool_aux4_speak 'spa';
if ( $state = said $v_pool_aux4_speak) {
    set $aqualink "#AUX4?";
    $AUX4mode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_aux5_speak = new Voice_Cmd("$AUX5 status");
set_order $v_pool_aux5_speak '15';
set_icon $v_pool_aux5_speak 'trivia';
if ( $state = said $v_pool_aux5_speak) {
    set $aqualink "#AUX5?";
    $AUX5mode = 'speak';
    select undef, undef, undef, .5;
}

$v_pool_display_status = new Voice_Cmd("Display Pool Status");
set_order $v_pool_display_status '16';
set_icon $v_pool_aux5_speak 'info';
if ( $state = said $v_pool_display_status) {
    print_log "Display Pool Status";
    my $results =
      "<pre>Pool Settings, all as of last explicit query or notification:\n";
    $results .= "\n";
    $results .= "Pool area Air Temperature = $Save{PoolAIRTMP}\n";
    $results .= "            Pool/Spa Mode = $Save{PoolSPA}\n";
    $results .= "       Main (filter) Pump = $Save{PoolPUMP}\n";
    $results .=
      "     Cleaner (sweep) Pump = $Save{PoolCLEANR} (a.k.a $CLEANR)\n";
    $results .= "\n";
    $results .= "   Pool Water Temperature = $Save{PoolPOOLTMP}\n";
    $results .= "     Pool Water Set Point = $Save{PoolPOOLSP}\n";
    $results .= "              Pool Heater = $Save{PoolPOOLHT}\n";
    $results .= "\n";
    $results .= "    Spa Water Temperature = $Save{PoolSPATMP}\n";
    $results .= "      Spa Water Set Point = $Save{PoolSPASP}\n";
    $results .= "               Spa Heater = $Save{PoolSPAHT}\n";
    $results .= "\n";
    $results .= "                     Aux1 = $Save{PoolAUX1} (a.k.a $AUX1)\n";
    $results .= "                     Aux2 = $Save{PoolAUX2} (a.k.a $AUX2)\n";
    $results .= "                     Aux3 = $Save{PoolAUX3} (a.k.a $AUX3)\n";
    $results .= "                     Aux4 = $Save{PoolAUX4} (a.k.a $AUX4)\n";
    $results .= "                     Aux5 = $Save{PoolAUX5} (a.k.a $AUX5)\n";
    $results .= "                     Auxx = $Save{PoolAUXX} (a.k.a $AUXX)\n";
    $results .= "\n";
    $results .= "        Power Panel Model = $Save{PoolMODEL}\n";
    $results .= "   Serial Adapter Version = $Save{PoolVERS}\n";
    $results .= "    System Operation Mode = $Save{PoolOPMODE}\n";
    $results .= "   Backup Battery Voltage = $Save{PoolVBAT}\n";

    display $results, 20, 'Pool Saved Status', 'fixed';
}

##########################################################################
# Category=Pool Settings

$v_pool_pump_set = new Voice_Cmd("Filter pump [ON,OFF]");
set_order $v_pool_pump_set '01';
set_icon $v_pool_pump_set 'pump';
if ( $state = said $v_pool_pump_set) {
    set $aqualink "#PUMP=$state";
    $PUMPmode = 'set';
    select undef, undef, undef, .5;
}

$v_pool_cleaner_set = new Voice_Cmd("Pool cleaner [ON,OFF]");
set_order $v_pool_cleaner_set '02';
set_icon $v_pool_cleaner_set 'pump';
if ( $state = said $v_pool_cleaner_set) {
    set $aqualink "#CLEANR=$state";
    $CLEANRmode = 'set';
    select undef, undef, undef, .5;
}

$v_pool_mode_set = new Voice_Cmd("Pool Mode");
set_order $v_pool_mode_set '03';
set_icon $v_pool_mode_set 'pool';
if ( $state = said $v_pool_mode_set) {
    set $aqualink "#SPA=OFF";
    $SPAmode = 'set';
    select undef, undef, undef, .5;
}

$v_spa_mode_set = new Voice_Cmd("Spa mode");
set_order $v_spa_mode_set '04';
set_icon $v_spa_mode_set 'spa';
if ( $state = said $v_spa_mode_set) {
    set $aqualink "#SPA=ON";
    $SPAmode = 'set';
    select undef, undef, undef, .5;
}

$v_pool_heat_set = new Voice_Cmd("Pool heater [ON,OFF]");
set_order $v_pool_heat_set '05';
set_icon $v_pool_heat_set 'heater';
if ( $state = said $v_pool_heat_set) {
    set $aqualink "#POOLHT=$state";
    $POOLHTmode = 'set';
    select undef, undef, undef, .5;
}

$v_spa_heat_set = new Voice_Cmd("Spa heater [ON,OFF]");
set_order $v_spa_heat_set '06';
set_icon $v_spa_heat_set 'heater';
if ( $state = said $v_spa_heat_set) {
    set $aqualink "#SPAHT=$state";
    $SPAHTmode = 'set';
    select undef, undef, undef, .5;
}

$v_pool_sp_up = new Voice_Cmd("Increase the pool setpoint");
set_order $v_pool_sp_up '07';
set_icon $v_pool_sp_up 'raise';
if ( $state = said $v_pool_sp_up) {
    set $aqualink "#POOLSP+";
    $POOLSPmode = 'set';
    select undef, undef, undef, 1.25;
}

$v_spa_sp_up = new Voice_Cmd("Increase the spa setpoint");
set_order $v_spa_sp_up '08';
set_icon $v_spa_sp_up 'raise';
if ( $state = said $v_spa_sp_up) {
    set $aqualink "#SPASP+";
    $SPASPmode = 'set';
    select undef, undef, undef, 1.25;
}

$v_pool_sp_dn = new Voice_Cmd("Decrease the pool setpoint");
set_order $v_pool_sp_dn '09';
set_icon $v_pool_sp_dn 'lower';
if ( $state = said $v_pool_sp_dn) {
    set $aqualink "#POOLSP-";
    $POOLSPmode = 'set';
    select undef, undef, undef, 1.25;
}

$v_spa_sp_dn = new Voice_Cmd("Decrease the spa setpoint");
set_order $v_spa_sp_dn '10';
set_icon $v_spa_sp_dn 'lower';
if ( $state = said $v_spa_sp_dn) {
    set $aqualink "#SPASP-";
    $SPASPmode = 'set';
    select undef, undef, undef, 1.25;
}

$v_pool_AUX3_set = new Voice_Cmd("$AUX3 [ON,OFF]");
set_order $v_pool_AUX3_set '11';
set_icon $v_pool_AUX3_set 'pool';
if ( $state = said $v_pool_AUX3_set) {
    set $aqualink "#AUX3=$state";
    $AUX3mode = 'set';
    select undef, undef, undef, .5;
}

$v_pool_AUX2_set = new Voice_Cmd("$AUX2 [ON,OFF]");
set_order $v_pool_AUX2_set '12';
set_icon $v_pool_AUX2_set 'spa';
if ( $state = said $v_pool_AUX2_set) {
    set $aqualink "#AUX2=$state";
    $AUX2mode = 'set';
    select undef, undef, undef, .5;
}

$v_pool_AUXX_set = new Voice_Cmd("$AUXX [ON,OFF]");
set_order $v_pool_AUXX_set '13';
set_icon $v_pool_AUXX_set 'pool';
if ( $state = said $v_pool_AUXX_set) {
    set $aqualink "#AUXX=$state";
    $AUXXmode = 'set';
    select undef, undef, undef, .5;
}

$v_pool_AUX4_set = new Voice_Cmd("$AUX4 [ON,OFF]");
set_order $v_pool_AUX4_set '14';
set_icon $v_pool_AUX4_set 'spa';
if ( $state = said $v_pool_AUX4_set) {
    set $aqualink "#AUX4=$state";
    $AUX4mode = 'set';
    select undef, undef, undef, .5;
}

##########################################################################
# Category=Pool SysDiag

$v_pool_diag =
  new Voice_Cmd("Run the Aqualink serial adapter diagnostics (bad/fails)");
set_icon $v_pool_diag 'debug';
if ( $state = said $v_pool_diag) { set $aqualink "#DIAG"; }

$v_pool_options = new Voice_Cmd("Get the Power Center option DIP switches");
set_icon $v_pool_options 'info';
if ( $state = said $v_pool_options) { set $aqualink "#OPTIONS?"; }

$v_pool_leds = new Voice_Cmd("Get the L E D Status");
set_icon $v_pool_leds 'info';
if ( $state = said $v_pool_leds) { set $aqualink "#LEDS?"; }

$v_pool_vers = new Voice_Cmd("Get the Aqualink serial adapter version");
set_icon $v_pool_vers 'info';
if ( $state = said $v_pool_vers) { set $aqualink "#VERS?"; }

$v_pool_model = new Voice_Cmd("Get the Aqualink model number");
set_icon $v_pool_model 'info';
if ( $state = said $v_pool_model) { set $aqualink "#MODEL?"; }

$v_reset = new Voice_Cmd("Reset the Aqualink Serial Adapter");
set_icon $v_reset 'debug';
if ( $state = said $v_reset) {
    set $aqualink "#RST";
    speak "Resetting the Jandy RS Serial Adapter";
}

$v_pool_mode_chk = new Voice_Cmd("Check the Aqualink system mode");
set_icon $v_pool_mode_chk 'info';
if ( $state = said $v_pool_mode_chk) {
    set $aqualink "#OPMODE?";
    $OPMODEmode = 'speak';
}

$v_pool_battery = new Voice_Cmd("Check the pool battery");
set_icon $v_pool_battery 'info';
if ( $state = said $v_pool_battery) {
    set $aqualink "#VBAT?";
    $VBATmode = 'speak';
}

##########################################################################

#if ($Startup) {
#  run_after_delay 2, "run_voice_cmd 'Check the pool pump status'";
#  run_after_delay 4, "run_voice_cmd 'Check the pool heater status'";
#  run_after_delay 6, "run_voice_cmd 'Check the pool temperature'";
#  run_after_delay 8, "run_voice_cmd 'Check the spa status'";
#  run_after_delay 10, "run_voice_cmd 'Check the spa heater status'";
#  run_after_delay 12, "run_voice_cmd 'Check the spa temperature'";
#  run_after_delay 14, "run_voice_cmd 'Check the pool cleaner'";
#  run_after_delay 16, "run_voice_cmd 'Check the pool auxiliary device 3 status'";
#  run_after_delay 18, "run_voice_cmd 'Check the air temperature'";
#}

sub aqualinklog {
    my ($text) = @_;
    &::logit( "$::config_parms{data_dir}/logs/aqualink.$::Year_Month_Now.log",
        "Aqualink: $text" );
}

#Commands
#
#Q=Query T=Toggle S=Set A=Action
#Uppercase = supported  Lowercase = unsupported
#
#
#AIRTMP     Q      Air Temperature
#AUX1       QtS    Auxiliary 1
#AUX2       QtS    Auxiliary 2
#AUX3       QtS    Auxiliary 3
#CLEANR     QtS    Cleaner
#CMDCHR     qs     Command Character
#COSMSGS    S      Change of Service Messages
#DIAG       A      Run Diagnostics
#ECHO       qS     Echo back commands
#ERRCHR     qs     Error Character
#LEDS       q      LED Status
#MODEL      Q      Model Number of AquaLink RS System
#NRMCHR     qs     Normal Character
#OPMODE     Q      Operational Mode (Auto, Service, Timeout)
#OPTIONS    Q      Options DIP Switch Settings
#POOLHT     QtS    Pool Heater
#POOLSP     QS     Pool Setpoint
#POOLTMP    Q      Pool Temp
#PUMP       QtS    Pump
#RSPFMT     qs     Response Format
#RST        A      Reset Serial Adapter
#S1         q      Serial Adapter DIP Switch
#SPA        QtS    Spa
#SPAHT      QtS    Spa Heater
#SPASP      QS     Spa Setpoint
#SPATMP     Q      Spa Temp
#UNITS      q      Temp Units
#VBAT       Q      Battery Voltage
#VERS       Q      Version of RS Serial Adapter
