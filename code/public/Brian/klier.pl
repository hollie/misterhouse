##########################
#  Klier Home Automation #
##########################

####################>>>  Define Different States

my $house_status_speech;
my $light_states = 'on,+90,+70,+50,+30,+10,-10,-30,-50,-70,-90,off';
my $appl_states  = 'on,off';
my $state;
my $af;
my $atx;
my $camera_cycle;

$timer_alarm       = new Timer;
$current_away_mode = new Generic_Item;
$timer_away        = new Timer;

$alarmactive = new Generic_Item;

if ($Reload)  { $camera_cycle = '1' }
if ($Startup) { $camera_cycle = '1' }

if ( state_now $Power_Supply eq 'Restored' ) {

    #speak 'Power has been restored';
    play( 'file' => 'c:\mh\sounds\voices\powerrestored.wav' );
    if ( state $current_away_mode eq 'away' ) {
        $page_email = "Power has been restored.";
    }
}

# Category=HVAC

####################>>>  Thermostat Setback

if ( $state = said $v_thermostat_setback) {
    print_log "Thermostat Setback is $state.";
}

if ( state_now $thermostat_setback eq 'on' ) {
    print_log "REMOTE - Thermostat Setback on.";
}

if ( state_now $thermostat_setback eq 'off' ) {
    print_log "REMOTE - Thermostat Setback off.";
}

# Category=Security

####################>>>  Cycle Security Cameras / Recite weather Information

$v_cycle_cams = new Voice_Cmd("Cycle Security Cameras");

if ( $state = said $v_cycle_cams) {
    set $request_wx_stuff 'on';
}

if ( state_now $request_wx_stuff eq 'on' ) {

    #run_voice_cmd 'Read a weather forecast';

    $camera_cycle = $camera_cycle + 1;
    if ( $camera_cycle > '4' ) { $camera_cycle = '1' }

    if ( $camera_cycle eq '1' ) {
        print_log "SECURITY - Manual Cycle to Back Door";
        set $security_cameras 'off';
        set $security_camera_backdoor 'on';
    }

    if ( $camera_cycle eq '2' ) {
        print_log "SECURITY - Manual Cycle to Driveway";
        set $security_cameras 'off';
        set $security_camera_driveway 'on';
    }

    if ( $camera_cycle eq '3' ) {
        print_log "SECURITY - Manual Cycle to Garage";
        set $security_cameras 'off';
        set $security_camera_garage 'on';
    }

    if ( $camera_cycle eq '4' ) {
        print_log "SECURITY - Manual Cycle to Front Door";
        set $security_cameras 'off';
        set $security_camera_frontdoor 'on';
    }

}

if ( state_now $request_wx_stuff eq 'off' ) {
    run_voice_cmd 'Last Weather Report';
}

# Category=Modes

####################>>>  Come Home/Goodnight Macros

$v_come_home = new Voice_Cmd('Come Home Mode');
if ( ( said $v_come_home) || ( state_now $come_home_stuff eq 'on' ) ) {
    set $current_away_mode 'home';
    set $alarmactive 'off';
    set $timer_alarm 0;
    set $thermostat_setback 'off';
    print_log "Come Home Macro Activated";
    speak "Come home mode is now activated.";

    #play('file' => 'c:\mh\sounds\voices\comehomemode.wav');
}

$v_away_mode = new Voice_Cmd('Away Mode');
if ( ( said $v_away_mode) || ( state_now $come_home_stuff eq 'off' ) ) {
    set $current_away_mode 'away';
    set $thermostat_setback 'on';
    set $timer_away 10;
    print_log "Away/Goodnight Macro Activated";
    speak "Away mode is now activated.  Goodbye!";

    #play('file' => 'c:\mh\sounds\voices\awaymode.wav');
}

if ( expired $timer_away) {
    set $All_Lights 'off';

    #set $alarmactive 'on';
    set $boombox_bedroom 'off';
    set $projector 'off';
    set $timer_away 0;
}

####################>>>  Morning Alarm Buttons

if ( state_now $morning_alarm_buttons eq 'on' ) {
    run_voice_cmd 'Alarm Clock On';
}

if ( state_now $morning_alarm_buttons eq 'off' ) {
    run_voice_cmd 'Alarm Clock Off';
}

# Category=Lights

####################>>> All Lights

#$v_all_lights = new Voice_Cmd("All Lights [$appl_states]");
#
#if ($state = said $v_all_lights) {
#    set $All_Lights $state;
#    print_log "All Lights $state.";
#    speak "All Lights $state.";
#}

$v_ambient_lights = new Voice_Cmd("Ambient Lights");

# Turn entryway and living room lamp on at sunset
if ( ( $state = said $v_ambient_lights) or ( time_now "$Time_Sunset - 1:00" ) )
{
    set $ambient_lights 'off';
    set $ambient_lights 'on';
    set $computer_room_light '-50';
    set $living_room_light '-60';
    set $bedroom_light '-40';
    set $christmas_lights 'on';

    #set $christmas_lights '-20';
}

####################>>>  Kitchen Light

#$v_kitchen_light = new Voice_Cmd("Kitchen Light [$appl_states]");
#
#if ($state = said $v_kitchen_light) {
#    set $kitchen_light $state;
#    print_log "Kitchen Light is $state.";
#    speak "Kitchen Light is $state.";
#}

if ( state_now $kitchen_light eq 'on' ) {
    print_log "REMOTE - Kitchen Light on.";
}
if ( state_now $kitchen_light eq 'off' ) {
    print_log "REMOTE - Kitchen Light off.";
}

####################>>>  Living Room Light

#$v_living_room_light = new Voice_Cmd("Living Room Light [$light_states]");
#
#if ($state = said $v_living_room_light) {
#    set $living_room_light $state;
#    print_log "Living Room Light is $state.";
#    speak "Living Room Light is $state.";
#}

if ( state_now $living_room_light eq 'on' ) {
    play( 'file' => 'c:\mh\sounds\tap.wav' );
    print_log "REMOTE - Living Room Light on.";
}

if ( state_now $living_room_light eq 'off' ) {
    play( 'file' => 'c:\mh\sounds\tap.wav' );
    print_log "REMOTE - Living Room Light off.";
}

####################>>>  Computer Room Light

#$v_computer_room_light = new Voice_Cmd("Computer Room Light [$light_states]");
#
#if ($state = said $v_computer_room_light) {
#    set $computer_room_light $state;
#    print_log "Computer Room Light is $state.";
#    speak "Computer Room Light is $state.";
#}

if ( state_now $computer_room_light eq 'on' ) {
    print_log "REMOTE - Computer Room Light on.";
}
if ( state_now $computer_room_light eq 'off' ) {
    print_log "REMOTE - Computer Room Light off.";
}

####################>>>  Bedroom Light

#$v_bedroom_light = new Voice_Cmd("Bedroom Lamp [$light_states]");
#
#if ($state = said $v_bedroom_light) {
#    set $bedroom_light $state;
#    print_log "Bedroom Lamp is $state.";
#    speak "Bedroom Lamp is $state.";
#}

if ( state_now $bedroom_light eq 'on' ) {
    print_log "REMOTE - Bedroom Lamp on.";
}
if ( state_now $bedroom_light eq 'off' ) {
    print_log "REMOTE - Bedroom Lamp off.";
}

####################>>>  Back Porch Light

#$v_back_porch_light = new Voice_Cmd("Back Porch Light [$appl_states]");
#
#if ($state = said $v_back_porch_light) {
#    set $back_porch_light $state;
#    print_log "Back Porch Light is $state.";
#    speak "Back Porch Light is $state.";
#}

if ( state_now $back_porch_light eq 'on' ) {
    print_log "REMOTE - Back Porch Light on.";
}
if ( state_now $back_porch_light eq 'off' ) {
    print_log "REMOTE - Back Porch Light off.";
}

####################>>>  Garage Light

#$v_back_porch_light = new Voice_Cmd("Back Porch Light [$appl_states]");
#
#if ($state = said $v_back_porch_light) {
#    set $back_porch_light $state;
#    print_log "Back Porch Light is $state.";
#    speak "Back Porch Light is $state.";
#}

if ( state_now $garage_light eq 'on' ) { print_log "REMOTE - Garage Light on." }
if ( state_now $garage_light eq 'off' ) {
    print_log "REMOTE - Garage Light off.";
}

####################>>>  Christmas Lights

#$v_christmas_lights = new Voice_Cmd("Christmas Lights [$light_states]");
#
#if ($state = said $v_christmas_lights) {
#    set $christmas_lights $state;
#    print_log "Christmas Lights are $state.";
#}

if ( state_now $christmas_lights eq 'on' ) {
    print_log "REMOTE - Christmas Lights on.";
}
if ( state_now $christmas_lights eq 'off' ) {
    print_log "REMOTE - Christmas Lights off.";
}

####################>>>  Christmas Tree

#$v_christmas_tree = new Voice_Cmd("Christmas Tree [$light_states]");
#
#if ($state = said $v_christmas_tree) {
#    set $christmas_tree $state;
#    print_log "Christmas Tree is $state.";
#}

if ( state_now $christmas_tree eq 'on' ) {
    print_log "REMOTE - Christmas Tree on.";
}
if ( state_now $christmas_tree eq 'off' ) {
    print_log "REMOTE - Christmas Tree off.";
}

####################>>>  Christmas Light Macro

$v_xmas_light_macro = new Voice_Cmd("Christmas Light Macro");

if ( $state = said $v_xmas_light_macro) {
    set $christmas_lights 'on';

    #set $christmas_lights '-20';
}

# Category=Appliances

####################>>>  Unused Transceiver (A)

#$v_unused_xcvr = new Voice_Cmd("Unused Transceiver [$appl_states]");
#
#if ($state = said $v_unused_xcvr) {
#    set $unused_xcvr $state;
#    print_log "Unused Transceiver is $state.";
#}

if ( state_now $unused_xcvr eq 'on' ) {
    print_log "REMOTE - Unused Xcvr on.";
}

if ( state_now $unused_xcvr eq 'off' ) {
    print_log "REMOTE - Unused Xcvr off.";
}

####################>>>  Boombox

#$v_boombox_bedroom = new Voice_Cmd("Boombox [$appl_states]");
#
#if ($state = said $v_boombox_bedroom) {
#    set $boombox_bedroom $state;
#    print_log "Boombox is $state.";
#}
#
#if (state_now $boombox_bedroom eq 'on') {
#    print_log "REMOTE - Boombox on.";
#}
#
#if (state_now $boombox_bedroom eq 'off') {
#    print_log "REMOTE - Boombox off.";
#}

####################>>>  Circulation Fan

#$v_circ_fan = new Voice_Cmd("Circulation Fan [$appl_states]");
#
#if ($state = said $v_circ_fan) {
#    set $circ_fan $state;
#    print_log "Circulation Fan is $state.";
#}

if ( state_now $circ_fan eq 'on' ) {
    print_log "REMOTE - Circulation Fan on.";
}

if ( state_now $circ_fan eq 'off' ) {
    print_log "REMOTE - Circulation Fan off.";
}

####################>>>  Motion Detector Warning (Back Door)

if ( state_now $motion_detector_backdoor eq 'motion' ) {
    print_log "Motion - Back Door";

    # Turn on Light if a presence is detected after dusk.
    if ( time_greater_than($Time_Sunset) or time_less_than($Time_Sunrise) ) {
        set $back_porch_light 'on';
    }

    logit( "$Pgm_Path/../web/mh/motion.log", "Motion Detected Back Door<BR>" );
    set $cctv_record_alarm 'on';
    play( 'file' => 'c:\mh\sounds\voices\motionbackdoor.wav' );

    if ( state $security_camera_backdoor ne 'on' ) {
        set $security_cameras 'off';
        set $security_camera_backdoor 'on';
    }

    if ( state $current_away_mode eq 'away' ) {
        $page_email = "Motion at Back Door.";
    }

}

if ( state_now $motion_detector_backdoor eq 'still' ) {
    print_log "ALL CLEAR at Back Door";
    set $cctv_record_alarm 'off';

    # And cut light when motion is cleared.
    if ( state $back_porch_light ne 'off' ) {
        set $back_porch_light 'off';
    }

    logit( "$Pgm_Path/../web/mh/motion.log", "ALL CLEAR Back Door<BR>" );

    #speak "Back Door Clear.";
}

####################>>> Motion Detector Warning (Trailer)

if ( state_now $motion_detector_trailer eq 'motion' ) {
    print_log "Motion - Trailer";

    # Turn on Light if a presence is detected after dusk.
    if ( time_greater_than($Time_Sunset) or time_less_than($Time_Sunrise) ) {
        set $back_porch_light 'on';

        #play('file' => 'c:\mh\sounds\sit.wav');
    }

    logit( "$Pgm_Path/../web/mh/motion.log", "Motion Detected Trailer<BR>" );
    set $cctv_record_alarm 'on';
    play( 'file' => 'c:\mh\sounds\OUTERMK.WAV' );

    # speak "Motion has been detected in the trailer.";

    if ( state $security_camera_driveway ne 'on' ) {
        set $security_cameras 'off';
        set $security_camera_driveway 'on';
    }

    if ( state $current_away_mode eq 'away' ) {

        #        $page_email = "Motion in Trailer.";
    }

}

if ( state_now $motion_detector_trailer eq 'still' ) {
    print_log "ALL CLEAR in Trailer";
    set $cctv_record_alarm 'off';

    # And cut light when motion is cleared.
    if ( state $back_porch_light ne 'off' ) {
        set $back_porch_light 'off';
    }

    logit( "$Pgm_Path/../web/mh/motion.log", "ALL CLEAR Trailer<BR>" );

    #speak "Back Door Clear.";
}

####################>>>  Bed Heater

#$v_bed_heater = new Voice_Cmd("Bed Heater [$appl_states]");
#
#if ($state = said $v_bed_heater) {
#    set $bed_heater $state;
#    print_log "Bed Heater is $state.";
#    speak "Bed Heater is $state.";
#}

if ( state_now $bed_heater eq 'on' ) {
    print_log "REMOTE - Bed Heater on.";
}

if ( state_now $bed_heater eq 'off' ) {
    print_log "REMOTE - Bed Heater off.";
}

####################>>>  Motion Detector Warning (Front Door)

if ( state_now $motion_detector_frontdoor eq 'motion' ) {
    print_log "Motion - Front Door";
    logit( "$Pgm_Path/../web/mh/motion.log", "Motion Detected Front Door<BR>" );
    set $cctv_record_alarm 'on';
    play( 'file' => 'c:\mh\sounds\voices\motionfrontdoor.wav' );

    if ( state $security_camera_frontdoor ne 'on' ) {
        set $security_cameras 'off';
        set $security_camera_frontdoor 'on';
    }

    if ( state $current_away_mode eq 'away' ) {
        $page_email = "Motion at Front Door.";
    }

}

if ( state_now $motion_detector_frontdoor eq 'still' ) {
    print_log "ALL CLEAR - Front Door";
    set $cctv_record_alarm 'off';
    logit( "$Pgm_Path/../web/mh/motion.log", "ALL CLEAR Front Door<BR>" );

    #speak "Front Door Clear.";
}

####################>>> Low Light (Front Door)

if ( state_now $low_light_frontdoor eq 'dark' ) {
    print_log "Low Light - Front Door";
    logit( "$Pgm_Path/../web/mh/motion.log", "Low Light Front Door<BR>" );
}

if ( state_now $low_light_frontdoor eq 'light' ) {
    print_log "Normal Light - Front Door";
    logit( "$Pgm_Path/../web/mh/motion.log", "Normal Light Front Door<BR>" );
}

####################>>>  Motion Detector Warning (Kitchen)

if ( state_now $motion_detector_kitchen eq 'motion' ) {
    print_log "Motion - Kitchen";

    if (    ( state $alarmactive eq 'on' )
        and ( seconds_remaining_now $timer_alarm == '0' ) )
    {
        set $timer_alarm 30;
        speak "Alarm is on. 30 seconds to enter disable code.";
    }

    # Turn on Light if a presence is detected after dusk.
    if (   ( state $low_light_kitchen eq 'dark' )
        or ( time_greater_than($Time_Sunset) )
        or ( time_less_than($Time_Sunrise) ) )
    {
        set $kitchen_light 'on';
    }

    logit( "$Pgm_Path/../web/mh/motion.log", "Motion Detected Kitchen<BR>" );
}

if ( state_now $motion_detector_kitchen eq 'still' ) {
    print_log "ALL CLEAR - Kitchen";

    # And cut light when motion is cleared.
    if ( state $kitchen_light ne 'off' ) {
        set $kitchen_light 'off';
    }

    logit( "$Pgm_Path/../web/mh/motion.log", "ALL CLEAR Kitchen<BR>" );
}

####################>>>  Low Light (Kitchen)

if ( state_now $low_light_kitchen eq 'dark' ) {
    print_log "Low Light - Kitchen";
    logit( "$Pgm_Path/../web/mh/motion.log", "Low Light Kitchen<BR>" );
}

if ( state_now $low_light_kitchen eq 'light' ) {
    print_log "Normal Light - Kitchen";
    logit( "$Pgm_Path/../web/mh/motion.log", "Normal Light Kitchen<BR>" );
}

####################>>>  Motion Detector Warning (Living Room)

if ( state_now $motion_detector_living_room eq 'motion' ) {
    print_log "Motion - Living Room";
    logit( "$Pgm_Path/../web/mh/motion.log",
        "Motion Detected Living Room<BR>" );

    if (    ( state $alarmactive eq 'on' )
        and ( seconds_remaining_now $timer_alarm == '0' ) )
    {
        set $timer_alarm 30;
        speak "Alarm is on. 30 seconds to enter disable code.";
    }
}

if ( state_now $motion_detector_living_room eq 'still' ) {
    print_log "ALL CLEAR - Living Room";
    logit( "$Pgm_Path/../web/mh/motion.log", "ALL CLEAR Living Room<BR>" );
}

####################>>>  Low Light (Living Room)

if ( state_now $low_light_living_room eq 'dark' ) {
    print_log "Low Light - Living Room";
    logit( "$Pgm_Path/../web/mh/motion.log", "Low Light Living Room<BR>" );
}

if ( state_now $low_light_living_room eq 'light' ) {
    print_log "Normal Light - Living Room";
    logit( "$Pgm_Path/../web/mh/motion.log", "Normal Light Living Room<BR>" );
}

####################>>>  Motion Detector Warning (Garage)

if ( state_now $motion_detector_garage eq 'motion' ) {
    print_log "Motion - Garage";

    # Turn on Light if a presence is detected after dusk.
    if (   ( state $low_light_garage eq 'dark' )
        or ( time_greater_than($Time_Sunset) )
        or ( time_less_than($Time_Sunrise) ) )
    {
        set $garage_light 'on';
    }

    logit( "$Pgm_Path/../web/mh/motion.log", "Motion Detected Garage<BR>" );
    set $cctv_record_alarm 'on';
    play( 'file' => 'c:\mh\sounds\voices\motiongarage.wav' );

    if ( state $security_camera_garage ne 'on' ) {
        set $security_cameras 'off';

        #set $security_camera_driveway 'on';
        set $security_camera_garage 'on';
    }

    if ( state $current_away_mode eq 'away' ) {
        $page_email = "Motion in Garage.";
    }
}

if ( state_now $motion_detector_garage eq 'still' ) {
    print_log "ALL CLEAR - Garage";
    set $cctv_record_alarm 'off';

    # And cut light when motion is cleared.
    if ( state $garage_light ne 'off' ) {
        set $garage_light 'off';
    }
    logit( "$Pgm_Path/../web/mh/motion.log", "ALL CLEAR Garage<BR>" );
}

####################>>> Low Light (Garage)

if ( state_now $low_light_garage eq 'dark' ) {
    print_log "Low Light - Garage";
    logit( "$Pgm_Path/../web/mh/motion.log", "Low Light Garage<BR>" );
}

if ( state_now $low_light_garage eq 'light' ) {
    print_log "Normal Light - Garage";
    logit( "$Pgm_Path/../web/mh/motion.log", "Normal Light Garage<BR>" );
}

####################>>>  Projector

#$v_projector = new Voice_Cmd("Projector [$appl_states]");
#
#if ($state = said $v_projector) {
#    set $projector $state;
#    print_log "Projector is $state.";
#}

if ( state_now $projector eq 'on' ) {
    print_log "REMOTE - Projector on.";
}

if ( state_now $projector eq 'off' ) {
    print_log "REMOTE - Projector off.";
}

####################>>>  Air Conditioner Fan

#$v_air_cond_fan = new Voice_Cmd("Air Conditioner Fan [$appl_states]");
#
#if ($state = said $v_air_cond_fan) {
#    set $air_cond_fan $state;
#    print_log "Air Conditioner is $state.";
#}

if ( state_now $air_cond_fan eq 'on' ) {
    print_log "REMOTE - Air Conditioner on.";
}

if ( state_now $air_cond_fan eq 'off' ) {
    print_log "REMOTE - Air Conditioner off.";
}

####################>>> Master Alarm Procedure
# Category=Security

$v_masteralarm = new Voice_Cmd("Master Alarm [$appl_states]");

if ( $state = said $v_masteralarm eq 'on' ) {
    logit( "$Pgm_Path/../web/mh/motion.log", "MASTER ALARM!<BR>" );
    speak "Master Alarm!";
    for ( my $i = 0; $i != 3; ++$i ) {
        play( 'file' => 'C:\MH\SOUNDS\STALLHRN.WAV' );
        set $timer_alarm 0;
        set $All_Lights 'on';
        set $All_Lights 'off';
    }
}

if ( $state = said $v_masteralarm eq 'off' ) {
    speak "Master Alarm Off.";
}

if ( expired $timer_alarm) {
    run_voice_cmd "Master Alarm on";
}

if ( state_now $alarm_lights eq 'on' ) {
    logit( "$Pgm_Path/../web/mh/motion.log", "Security - All Lights On<BR>" );
    print_log "SECURITY - All Lights On!!!";
    speak "Security.  All Lights On.";

    #play('file' => 'C:\MH\SOUNDS\STALLHRN.WAV');
    set $computer_room_light 'on';

    #set $All_Lights 'on';
}

if ( state_now $alarm_lights eq 'off' ) {
    logit( "$Pgm_Path/../web/mh/motion.log", "Security - All Lights Off<BR>" );
    print_log "SECURITY - All Lights Off!!!";
    speak "Security.  All Lights Off.";

    #play('file' => 'C:\MH\SOUNDS\STALLHRN.WAV');
    set $computer_room_light 'off';
}

if ( state_now $alarm_detected eq 'on' ) {
    logit( "$Pgm_Path/../web/mh/motion.log", "MASTER ALARM!<BR>" );
    print_log "SECURITY - MASTER ALARM!!!";
    speak "Master Alarm!";
    play( 'file' => 'C:\MH\SOUNDS\STALLHRN.WAV' );

    #set $All_Lights 'on';
    #set $All_Lights 'off';
}

if ( state_now $alarm_detected eq 'off' ) {
    play( 'file' => 'C:\MH\SOUNDS\STALLHRN.WAV' );

    #set $All_Lights 'off';
}

####################>>>  Security Cameras

$v_security_camera_backdoor = new Voice_Cmd("Security Camera Back Door");
if ( $state = said $v_security_camera_backdoor) {
    play( 'file' => 'c:\mh\sounds\voices\securitybackdoor.wav' );
    set $security_cameras 'off';
    set $security_camera_backdoor 'on';
    print_log "SECURITY - Back Door Camera.";
}

$v_security_camera_garage = new Voice_Cmd("Security Camera Garage");
if ( $state = said $v_security_camera_garage) {
    speak "The security monitor is now viewing the garage.";

    #play('file' => 'c:\mh\sounds\voices\securityfrontdoor.wav');
    set $security_cameras 'off';
    set $security_camera_garage 'on';
    print_log "SECURITY - Garage Camera.";
}

$v_security_camera_frontdoor = new Voice_Cmd("Security Camera Front Door");
if ( $state = said $v_security_camera_frontdoor) {
    play( 'file' => 'c:\mh\sounds\voices\securitycfrontdoor.wav' );
    set $security_cameras 'off';
    set $security_camera_frontdoor 'on';
    print_log "SECURITY - Front Door Camera.";
}

$v_security_camera_driveway = new Voice_Cmd("Security Camera Driveway");
if ( $state = said $v_security_camera_driveway) {
    speak "The security monitor is now viewing the drive way.";

    #play('file' => 'c:\mh\sounds\voices\securityfrontdoor.wav');
    set $security_cameras 'off';
    set $security_camera_driveway 'on';
    print_log "SECURITY - Driveway Camera.";
}

$v_security_camera_off = new Voice_Cmd("All Security Cameras Off");
if ( $state = said $v_security_camera_off) {
    set $security_cameras 'off';
    print_log "SECURITY - All Cameras Off.";
}

# Category=Informational

####################>>>  Information Requests

# Respond if asked "What's on TV?"
if ( state_now $whats_on_tv eq 'on' ) { run_voice_cmd 'Whats on TV?' }

# Respond if asked "Time and Temperature?"
$v_request_time = new Voice_Cmd('Time and Temperature');
if ( ( said $v_request_time) || ( state_now $request_time_stuff eq 'on' ) ) {
    speak "It's $Time_Now on $Date_Now.  Sunrise is at $Time_Sunrise,
           sunset is at $Time_Sunset.  Temperature is $Weather{TempOutdoor}.";
}

# Respond if asked "House Status"
$v_house_status = new Voice_Cmd('House Status');
if ( ( said $v_house_status) || ( state_now $request_time_stuff eq 'off' ) ) {
    $house_status_speech = '';
    if ( state $living_room_light ne 'off' ) {
        $house_status_speech .= "The living room light is currently on.";
    }
    if ( state $computer_room_light ne 'off' ) {
        $house_status_speech .= "The computer room light is on right now.";
    }
    if ( state $bedroom_light ne 'off' ) {
        $house_status_speech .= "The light in the bedroom is on.";
    }
    if ( state $back_porch_light ne 'off' ) {
        $house_status_speech .= "The back porch light is currently on.";
    }
    if ( state $kitchen_light ne 'off' ) {
        $house_status_speech .= "The kitchen light is on right now.";
    }
    if ( state $bed_heater ne 'off' ) {
        $house_status_speech .= "The bed heater is warming up.";
    }

    #    if (state $projector ne 'off') {$house_status_speech .= "The home theater projector is on."};
    if ( state $air_cond_fan ne 'off' ) {
        $house_status_speech .= "The air conditioner fan is currently on.";
    }
    if ( state $circ_fan ne 'off' ) {
        $house_status_speech .= "The circulation fan is on right now.";
    }
    if ( state $motion_detector_garage ne 'still' ) {
        $house_status_speech .= "There is somebody in the garage.";
    }
    if ( state $motion_detector_kitchen ne 'still' ) {
        $house_status_speech .= "There is somebody in the kitchen.";
    }
    if ( state $motion_detector_trailer ne 'still' ) {
        $house_status_speech .= "There is somebody near the trailer.";
    }

    if ( $house_status_speech eq '' ) {
        $house_status_speech = 'Everything is off at the moment.';
    }

    speak $house_status_speech;
}

$v_set_wakeup_alarm_on = new Voice_Cmd("Alarm Clock On");
if ( $state = said $v_set_wakeup_alarm_on) {
    &trigger_set(
        "time_cron '0 6 * * 1,2,3,4,5'",
        "run_voice_cmd 'Play Music from Upstairs'",
        "NoExpire", "ALARM ON", 1
    );
    speak "Alarm now active for tomorrow morning.";
    print_log "Alarm now active for tomorrow morning.";
}

$v_set_wakeup_alarm_off = new Voice_Cmd("Alarm Clock Off");
if ( $state = said $v_set_wakeup_alarm_off) {
    &trigger_set(
        "time_cron '0 6 * * 1,2,3,4,5'",
        "run_voice_cmd 'Play Music from Upstairs'",
        "Disabled", "ALARM ON", 1
    );
    speak "Alarm clock now off.";
    print_log "Alarm clock now off.";
}

# Category=Time

####################>>>  Timed Events
# TIME_CRON EVENTS - 1st digit = Minute(s) separated by commas
#                    2nd digit = Hour(s) separated by commas
#                    3rd digit = Day(s) separated by commas
#                    4th digit = Month(s) separated by commas
#                    5th digit = Day of week(s) 0=Sun 1=Mon 2=Tue, etc.
#                            * = Ignore this field

####################>>> Speak a reminder if the alarm is off

if ( time_cron('33 20,21 * * 0,1,2,3,4') ) {
    ( $af, $af, $atx, $af ) = &trigger_get('ALARM ON');
    if ( $atx eq 'Disabled' ) {
        speak
          "Notice: Please be aware that the alarm clock for tomorrow morning is off.";
        print_log "Alarm Clock Reminder Sent.";
    }
}

$Save{email_check} = 'yes' if time_cron('59 9 * * *');
$Save{email_check} = 'no'  if time_cron('59 21 * * *');

####################>>> Turn Christmas Lights on in the morning until 7:30

#if (time_cron('30 5 * * *')) {
#    set $christmas_lights 'on';
#    #set $christmas_lights '-20';
#}

#if (time_cron('30 7 * * *')) {
#    set $christmas_lights 'off';
#}

# Turn the lights and music off at 11:30 PM
if ( time_cron('30 23 * * *') ) {
    set $All_Lights 'off';
    set $christmas_lights 'off';
    run_voice_cmd "Stop Music";
}

speak("Merry Christmas.") if time_cron('0 10,14,18,22 25 12 *');
speak("Happy New Year!")  if time_cron('0 10,14,18,22 1 1 *');

#if (time_cron('0 10,11,12,13,14,15,16,17,18,19,20,21 * * *')) {
#    my $ChimeHour = $Hour;
#    if ($Hour > 12) {$ChimeHour = $Hour - 12};
#
#    if ($ChimeHour eq '1') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '2') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '3') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '4') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '5') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '6') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '7') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '8') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '9') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '10') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '11') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#    if ($ChimeHour eq '12') {play('mode' => 'wait', 'file' => 'LARGEWESTMINSTER.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONG.WAV,WESTDONGEND.WAV')};
#}

#play('file' => 'M_CLK.WAV') if time_cron('0 10,11,12,13,14,15,16,17,18,19,20,21 * * *');
##### 12/23/07 play('file' => 'LARGEWESTMINSTER.WAV') if time_cron('0 10,11,12,13,14,15,16,17,18,19,20,21 * * *');

#run_voice_cmd "Play KQ92" if time_cron('0 6 * * 1,2,3,4');

set $bed_heater 'on'
  if ( time_cron('30 19 * * *') and $Weather{TempOutdoor} < '50' );
if ( state $computer_room_light eq 'off' ) {
    set $bed_heater 'off' if time_cron('29 23 * * *');
}

# Set Back the Thermostat from 5:55 a.m. to 3:10 p.m. Monday-Thursday
# only if the Alarm is off

if ( time_cron('55 5 * * 1,2,3,4,5') ) {
    ( $af, $af, $atx, $af ) = &trigger_get('ALARM ON');
    if ( $atx ne 'Disabled' ) {
        set $thermostat_setback 'on';
    }
}

set $thermostat_setback 'off' if time_cron('10 15 * * 1,2,3,4,5');

# Set Back the Thermostat from 9:30 p.m. to 5:45 a.m. Everyday
set $thermostat_setback 'on'  if time_cron('30 21 * * *');
set $thermostat_setback 'off' if time_cron('45 5 * * *');

if ( $Weather{TempOutdoor} eq $Weather{WindChill} ) {
    speak("It's $Time_Now. Temp is $Weather{TempOutdoor}.")
      if time_cron('0,30 10,11,12,13,14,15,16,17,18,19,20 * * *');
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '10:30', 05 );
    }
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '11:30', 05 );
    }
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '12:30', 05 );
    }
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '13:30', 05 );
    }
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '14:30', 05 );
    }
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '15:30', 05 );
    }
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '16:30', 05 );
    }
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '17:30', 05 );
    }
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '18:30', 05 );
    }
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '19:30', 05 );
    }
    if ( $Weather{TempOutdoor} < 11 ) {
        play( 'file' => 'c:\mh\sounds\voices\coldone.wav' )
          if time_now( '20:30', 05 );
    }

    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '10:30', 05 );
    }
    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '11:30', 05 );
    }
    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '12:30', 05 );
    }
    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '13:30', 05 );
    }
    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '14:30', 05 );
    }
    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '15:30', 05 );
    }
    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '16:30', 05 );
    }
    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '17:30', 05 );
    }
    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '18:30', 05 );
    }
    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '19:30', 05 );
    }
    if ( $Weather{TempOutdoor} > 89 ) {
        play( 'file' => 'c:\mh\sounds\voices\hotone.wav' )
          if time_now( '20:30', 05 );
    }
}

if ( $Weather{TempOutdoor} ne $Weather{WindChill} ) {
    speak(
        "It's $Time_Now. Temp is $Weather{TempOutdoor}. Winnd Chill is $Weather{WindChill}."
    ) if time_cron('30 10,11,12,13,14,15,16,17,18,19,20 * * *');
}

# Category=Entertainment

####################>>>  Play a Collection of Music

##$v_play_music = new Voice_Cmd('Play Music');
##if ($state = said $v_play_music) {
##    play('file' => 'c:\mh\sounds\voices\letmestartsomemusic.wav');
###    $Save{mode} = 'mute';
##    run qq[winamp E:\\mp3s];
##}

$v_play_music_up = new Voice_Cmd('Play Music from Upstairs');
if (   ( $state = said $v_play_music_up)
    || ( state_now $request_music_stuff eq 'on' ) )
{
    #if ($state = said $v_play_music_up) {
    play( 'file' => 'c:\mh\sounds\voices\letmestartsomemusic.wav' );

    #    $Save{mode} = 'mute';
    #    run qq[winamp H:\\];
    run qq[winamp C:\\DOCUME~1\\ADMINI~1\\MYDOCU~1\\MYMUSI~1];
}

$v_play_cassette = new Voice_Cmd('Play Cassette Tape');
if ( $state = said $v_play_cassette) {

    #if (($state = said $v_play_cassette) || (state_now $request_music_stuff eq 'on')) {
    #    $Save{mode} = 'mute';
    run qq[winamp I:\\];
}

##$v_play_kq92 = new Voice_Cmd('Play KQ92');
##if ($state = said $v_play_kq92) {
###    $Save{mode} = 'mute';
##    run qq[kq92];
##}

##$v_stop_kq92 = new Voice_Cmd('Stop WMPLAYER');
##if ($state = said $v_stop_kq92) {
###    $Save{mode} = 'mute';
##    run qq[kq92stop];
##}

$v_play_xmas_music = new Voice_Cmd('Play Christmas Music');
if ( $state = said $v_play_xmas_music) {

    #   $Save{mode} = 'mute';
    run qq[winamp H:\\christ~1];
}

$v_stop_music = new Voice_Cmd('Stop Music');
if (   ( $state = said $v_stop_music)
    || ( state_now $request_music_stuff eq 'off' ) )
{
    #    run_voice_cmd "Set house mp3 player to Stop";
    run qq[winamp /stop];
###    run qq[kq92stop];
###    $Save{mode} = 'normal';
}
