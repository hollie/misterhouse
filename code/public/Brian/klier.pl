##########################
#  Klier Home Automation  #
##########################

#-----> Define Different States

my $light_states = 'on,+90,+50,+10,-10,-50,-90,off';
my $appl_states = 'on,off';
my $state;

$timer_goodnight = new Timer;

#-----> All Available X10 Codes
$unused_xcvr = new X10_Item('A1');                      # A1 (unused)
$motion_detector_backdoor = new X10_Appliance('A2');    # A2
$motion_detector_kitchen = new X10_Appliance('A5');     # A5
$low_light_kitchen = new X10_Appliance('A6');           # A6
$motion_detector_frontdoor = new X10_Appliance('A7');   # A7
$motion_detector_living_room = new X10_Appliance('A9');      # A9 (unused)
$low_light_living_room = new X10_Appliance('AA');            # A10
$living_room = new X10_Item('B1');                      # B1
$bedroom_lamp = new X10_Item('B2');                     # B2
$front_entryway = new X10_Item('B3');                   # B3
$request_time_stuff = new X10_Appliance('B4');          # B4 (voice)
$boombox_bedroom = new X10_Appliance('B5');             # B5
                                                        # B6 (Caller ID)
$request_music_stuff = new X10_Appliance('B7');         # B7
$request_wx_stuff = new X10_Appliance('B8');            # B8
$circ_fan = new X10_Appliance('B9');                    # B9
$kitchen_light = new X10_Item('BA');                    # B10
$bed_heater = new X10_Appliance('BB');                  # B11
$whats_on_tv = new X10_Appliance('BC');                 # B12 (voice)
$projector = new X10_Appliance('BD');                   # B13
$air_cond_fan = new X10_Appliance('BE');                # B14
$back_porch_light = new X10_Appliance('BF');            # B15
$come_home_stuff = new X10_Appliance('BG');             # B16

# Category=Informational

#-----> Weather Information (B8)

if (state_now $request_wx_stuff eq 'on') {run_voice_cmd 'Read a weather forecast'};
if (state_now $request_wx_stuff eq 'off') {run_voice_cmd 'Last Weather Report'};

#-----> Come Home/Goodnight Macros (B16)

$v_come_home = new Voice_Cmd('Come Home Mode');
if ((said $v_come_home) || (state_now $come_home_stuff eq 'on')) {
    print_log "Come Home Macro Activated";
    speak "Welcome Home!";
    
#    if (time_greater_than($Time_Sunset)) {
        set $living_room 'on';
        set $living_room 'off';
        set $living_room 'on';
        set $living_room 'off';
        set $living_room 'on';
        set $living_room 'off';
#    }
}

$v_good_night = new Voice_Cmd('Goodnight Mode');
if ((said $v_good_night) || (state_now $come_home_stuff eq 'off')) {
    set $timer_goodnight 10;
    print_log "Goodnight Macro Activated";
    speak "Good Night!";
    run_voice_cmd "Stop Music";
}

if (expired $timer_goodnight) {
    set $living_room '-90';
    set $front_entryway '-90';
    set $bedroom_lamp '-90';
    set $living_room 'off';
    set $front_entryway 'off';
    set $boombox_bedroom 'off';
    set $bedroom_lamp 'off';
    set $kitchen_light 'off';
    set $back_porch_light 'off';
    set $projector 'off';
    set $timer_goodnight 0;
}

# Category=Lights

#-----> Kitchen Light (A2)

$v_kitchen_light = new Voice_Cmd("Kitchen Light [$appl_states]");

if ($state = said $v_kitchen_light) {
    set $kitchen_light $state;
    print_log "Kitchen Light is $state.";
    speak "Kitchen Light is $state.";
}

if (state_now $kitchen_light eq 'on') {
    print_log "REMOTE - Kitchen Light on.";
}

if (state_now $kitchen_light eq 'off') {
    print_log "REMOTE - Kitchen Light off.";
}

#-----> Living Room Lamp (B1)

$v_living_room = new Voice_Cmd("Living Room Lamp [$light_states]");

if ($state = said $v_living_room) {
    set $living_room $state;
    print_log "Living Room Lamp is $state.";
    speak "Living Room Lamp is $state.";
}

if (state_now $living_room eq 'on') {
    print_log "REMOTE - Living Room Light on.";
}

if (state_now $living_room eq 'off') {
    print_log "REMOTE - Living Room Light off.";
}

#-----> Front Entryway Lamp (B3)

$v_front_entryway = new Voice_Cmd("Front Entryway Lamp [$light_states]");

if ($state = said $v_front_entryway) {
    set $front_entryway $state;
    print_log "Front Entryway Lamp is $state.";
    speak "Front Entryway Lamp is $state.";
}

if (state_now $front_entryway eq 'on') {
    print_log "REMOTE - Front Entryway Light on.";
}

if (state_now $front_entryway eq 'off') {
    print_log "REMOTE - Front Entryway Light off.";
}

#-----> Bedroom (B5)

$v_bedroom_lamp = new Voice_Cmd("Bedroom Lamp [$light_states]");

if ($state = said $v_bedroom_lamp) {
    set $bedroom_lamp $state;
    print_log "Bedroom Lamp is $state.";
    speak "Bedroom Lamp is $state.";
}

if (state_now $bedroom_lamp eq 'on') {
    print_log "REMOTE - Bedroom Lamp on.";
}

if (state_now $bedroom_lamp eq 'off') {
    print_log "REMOTE - Bedroom Lamp off.";
}

#-----> Back Porch Light (B15)

$v_back_porch_light = new Voice_Cmd("Back Porch Light [$appl_states]");

if ($state = said $v_back_porch_light) {
    set $back_porch_light $state;
    print_log "Back Porch Light is $state.";
    speak "Back Porch Light is $state.";
}

if (state_now $back_porch_light eq 'on') {
    print_log "REMOTE - Back Porch Light on.";
}

if (state_now $back_porch_light eq 'off') {
    print_log "REMOTE - Back Porch Light off.";
}

# Category=Appliances

#-----> Unused Transceiver (A1)

$v_unused_xcvr = new Voice_Cmd("Unused Transceiver [$appl_states]");

if ($state = said $v_unused_xcvr) {
    set $unused_xcvr $state;
    print_log "Unused Transceiver is $state.";
    speak "Unused Transceiver is $state.";
}

if (state_now $unused_xcvr eq 'on') {
    print_log "REMOTE - Unused Xcvr on.";
}

if (state_now $unused_xcvr eq 'off') {
    print_log "REMOTE - Unused Xcvr off.";
}


#-----> Boombox (B2)

$v_boombox_bedroom = new Voice_Cmd("Boombox [$appl_states]");

if ($state = said $v_boombox_bedroom) {
    set $boombox_bedroom $state;
    print_log "Boombox is $state.";
    speak "Boombox is $state.";
}

if (state_now $boombox_bedroom eq 'on') {
    print_log "REMOTE - Boombox on.";
}

if (state_now $boombox_bedroom eq 'off') {
    print_log "REMOTE - Boombox off.";
}

#-----> Circulation Fan (B9)

$v_circ_fan = new Voice_Cmd("Circulation Fan [$appl_states]");

if ($state = said $v_circ_fan) {
    set $circ_fan $state;
    print_log "Circulation Fan is $state.";
    speak "Circulation Fan is $state.";
}

if (state_now $circ_fan eq 'on') {
    print_log "REMOTE - Circulation Fan on.";
}

if (state_now $circ_fan eq 'off') {
    print_log "REMOTE - Circulation Fan off.";
}

#-----> Motion Detector Warning (B10)

if (state_now $motion_detector_backdoor eq 'on') {
    print_log "Motion detected near Back Door - $Time_Now";

    # Turn on Light if a presence is detected after dusk.
    if (time_greater_than($Time_Sunset) or time_less_than($Time_Sunrise)) {
        set $back_porch_light 'on';
    }

    logit("$Pgm_Path/../web/mh/motion.log", "Motion Detected Back Door<BR>");
    play('file' => 'C:\MH\SOUNDS\OUTERMK.WAV');
    #play('file' => 'C:\MH\SOUNDS\INNERMK.WAV');
}

if (state_now $motion_detector_backdoor eq 'off') {
    print_log "ALL CLEAR at Back Door";

    # And cut light when motion is cleared.
    if (time_greater_than($Time_Sunset) or time_less_than($Time_Sunrise)) {
        set $back_porch_light 'off';
    }

    logit("$Pgm_Path/../web/mh/motion.log", "ALL CLEAR Back Door<BR>");
    #speak "Back Door Clear.";
}

#-----> Bed Heater (B11)

$v_bed_heater = new Voice_Cmd("Bed Heater [$appl_states]");

if ($state = said $v_bed_heater) {
    set $bed_heater $state;
    print_log "Bed Heater is $state.";
    speak "Bed Heater is $state.";
}

if (state_now $bed_heater eq 'on') {
    print_log "REMOTE - Bed Heater on.";
}

if (state_now $bed_heater eq 'off') {
    print_log "REMOTE - Bed Heater off.";
}

#-----> Motion Detector Warning (B12)

if (state_now $motion_detector_frontdoor eq 'on') {
    print_log "Motion - Front Door";
    logit("$Pgm_Path/../web/mh/motion.log", "Motion Detected Front Door<BR>");
    play('file' => 'C:\MH\SOUNDS\MRSDITH.WAV');
}

if (state_now $motion_detector_frontdoor eq 'off') {
    print_log "ALL CLEAR - Front Door";
    logit("$Pgm_Path/../web/mh/motion.log", "ALL CLEAR Front Door<BR>");
    #speak "Front Door Clear.";
}

#-----> Motion Detector Warning (A5)

if (state_now $motion_detector_kitchen eq 'on') {
    print_log "Motion - Kitchen";

    # Turn on Light if a presence is detected after dusk.
    if (state $low_light_kitchen eq 'on') {
    # if (time_greater_than($Time_Sunset) or time_less_than($Time_Sunrise)) {
        set $kitchen_light 'on';
    }

    logit("$Pgm_Path/../web/mh/motion.log", "Motion Detected Kitchen<BR>");
}

if (state_now $motion_detector_kitchen eq 'off') {
    print_log "ALL CLEAR - Kitchen";

    # And cut light when motion is cleared.
    #if (state $low_light_kitchen eq 'off') {
    # if (time_greater_than($Time_Sunset) or time_less_than($Time_Sunrise)) {
        set $kitchen_light 'off';
    #}

    logit("$Pgm_Path/../web/mh/motion.log", "ALL CLEAR Kitchen<BR>");
}

#-----> Motion Detector Warning (A9)

if (state_now $motion_detector_living_room eq 'on') {
    print_log "Motion - Living Room";
    logit("$Pgm_Path/../web/mh/motion.log", "Motion Detected Living Room<BR>");
}

if (state_now $motion_detector_living_room eq 'off') {
    print_log "ALL CLEAR - Living Room";
    logit("$Pgm_Path/../web/mh/motion.log", "ALL CLEAR Living Room<BR>");
}

#-----> Projector (B13)

$v_projector = new Voice_Cmd("Projector [$appl_states]");

if ($state = said $v_projector) {
    set $projector $state;
    print_log "Projector is $state.";
    speak "Projector is $state.";
}

if (state_now $projector eq 'on') {
    print_log "REMOTE - Projector on.";
}

if (state_now $projector eq 'off') {
    print_log "REMOTE - Projector off.";
}

#-----> Air Conditioner Fan (B14)

$v_air_cond_fan = new Voice_Cmd("Air Conditioner Fan [$appl_states]");

if ($state = said $v_air_cond_fan) {
    set $air_cond_fan $state;
    print_log "Air Conditioner Fan is $state.";
    speak "Air Conditioner Fan is $state.";
}

if (state_now $air_cond_fan eq 'on') {
    print_log "REMOTE - Air Conditioner on.";
}

if (state_now $air_cond_fan eq 'off') {
    print_log "REMOTE - Air Conditioner off.";
}

#-----> Low Light (A6)

if (state_now $low_light_kitchen eq 'on') {
    print_log "Low Light - Kitchen";
    logit("$Pgm_Path/../web/mh/motion.log", "Low Light Kitchen<BR>");
}

if (state_now $low_light_kitchen eq 'off') {
    print_log "Normal Light - Kitchen";
    logit("$Pgm_Path/../web/mh/motion.log", "Normal Light Kitchen<BR>");
}

#-----> Low Light (A10)

if (state_now $low_light_living_room eq 'on') {
    print_log "Low Light - Living Room";
    logit("$Pgm_Path/../web/mh/motion.log", "Low Light Living Room<BR>");
}

if (state_now $low_light_living_room eq 'off') {
    print_log "Normal Light - Living Room";
    logit("$Pgm_Path/../web/mh/motion.log", "Normal Light Living Room<BR>");
}

# Category=Informational

#-----> Information Requests

# Respond if asked "What's on TV?"
if (state_now $whats_on_tv eq 'on') {run_voice_cmd 'Whats on TV?'};

# Respond if asked "Time and Temperature?"
$v_request_time = new Voice_Cmd('Time and Temperature');
if ((said $v_request_time) || (state_now $request_time_stuff eq 'on')) {
    speak "It's $Time_Now on $Date_Now.  Sunrise is at $Time_Sunrise,
           sunset is at $Time_Sunset.  Current Temperature is $CurrentTemp
           degrees.";
}

# Respond if asked "House Status"
$v_house_status = new Voice_Cmd('House Status');
if ((said $v_house_status) || (state_now $request_time_stuff eq 'off')) {
    speak "Living Room Lamp is $living_room->{state}.
           Front Entryway Lamp is $front_entryway->{state}.
           Bedroom Lamp is $bedroom_lamp->{state}.
           Back Porch Light is $back_porch_light->{state}.
           Kitchen Light is $kitchen_light->{state}.
           Bed Heater is $bed_heater->{state}.
           Projector is $projector->{state}.
           Air Conditioner is $air_cond_fan->{state}.
           Circulation Fan is $circ_fan->{state}.
           Front Door Motion is $motion_detector_frontdoor->{state}.
           Back Door Motion is $motion_detector_backdoor->{state}.
           Kitchen Motion is $motion_detector_kitchen->{state}.
           Living Room Motion is $motion_detector_living_room->{state}.";
}

$v_reload_code = new Voice_Cmd('Reload code');
if (said $v_reload_code) {
    read_code();
}

$v_reboot = new  Voice_Cmd("Reboot the computer");
if (said $v_reboot and $OS_win) {
    speak("The house computer will reboot in 5 minutes.");
    Win32::InitiateSystemShutdown('HOUSE', 'Rebooting in 5 minutes', 300, 1, 1);
}

$v_reboot_abort = new Voice_Cmd("Abort the reboot");
if (said $v_reboot_abort and $OS_win) {
  Win32::AbortSystemShutdown('HOUSE');
  speak("OK, the reboot has been aborted.");
}

$v_uptime = new Voice_Cmd("What is your up time?");
if (said $v_uptime) {
    my $uptime_pgm = &time_diff($Time_Startup_time, time);
    my $uptime_computer = &time_diff(0, (get_tickcount)/1000);
    speak("I was started $uptime_pgm ago. The computer was booted $uptime_computer ago.");
}

$v_mode = new Voice_Cmd("Speech mode [normal,mute]");
if ($state = said $v_mode) {
    $Save{mode} = $state;
    speak "The house voice mode is now $state.";
    print_log "The house voice mode is now $state.";
}

#-----> Timed Events
# TIME_CRON EVENTS - 1st digit = Minute(s) separated by commas
#                    2nd digit = Hour(s) separated by commas
#                    3rd digit = Day(s) separated by commas
#                    4th digit = Month(s) separated by commas
#                    5th digit = Day of week(s) 0=Sun 1=Mon 2=Tue, etc.
#                            * = Ignore this field

# Turn entryway and living room lamp on at sunset
if (time_now($Time_Sunset)) {
    set $front_entryway 'on';
    set $front_entryway '-60';
    set $living_room 'on';
    set $living_room '-60';
    set $bedroom_lamp 'on';
    set $bedroom_lamp '-50';
}

# Turn the lights off at 11:30 PM
if (time_cron('30 23 * * *')) {
    set $living_room '-90';
    set $front_entryway '-90';
    set $bedroom_lamp '-90';
    set $front_entryway 'off';
    set $living_room 'off';
    set $bedroom_lamp 'off';
    set $kitchen_light 'off';
}

speak("Merry Christmas.") if time_cron('0 10,14,18,22 25 12 *');
speak("Happy New Year!") if time_cron('0 10,14,18,22 1 1 *');
speak("Remember to take out the garbage!") if time_cron('45 6 * * 4');

play('file' => 'C:\MH\SOUNDS\M_CLK.WAV') if time_cron('0 7,8,9,10,11,12,13,14,15,16,17,18,19,20,21 * * 1,2,3,4,5');
play('file' => 'C:\MH\SOUNDS\M_CLK.WAV') if time_cron('0 10,11,12,13,14,15,16,17,18,19,20,21 * * 0,6');

set $boombox_bedroom 'on' if time_cron('0 6 * * 1,2,3,4,5');
set $boombox_bedroom 'off' if time_cron('30 6 * * 1,2,3,4,5');

set $bed_heater 'on' if (time_cron('30 20 * * *') and $CurrentTemp < '50');
set $bed_heater 'off' if time_cron('30 21 * * *');

set $bed_heater 'on' if (time_cron('0 5 * * *') and $CurrentTemp < '50');
set $bed_heater 'off' if time_cron('20 5 * * *');

if ($CurrentTemp eq $CurrentChill) {
    speak("It's $Time_Now. Temp is $CurrentTemp.") if time_cron('30 6,7,8,9,10,11,12,13,14,15,16,17,18,19,20 * * 1,2,3,4,5');
    speak("It's $Time_Now. Temp is $CurrentTemp.") if time_cron('30 10,11,12,13,14,15,16,17,18,19,20 * * 0,6');
}

if ($CurrentTemp ne $CurrentChill) {
    speak("It's $Time_Now. Temp is $CurrentTemp. Winnd Chill is $CurrentChill.") if time_cron('30 6,7,8,9,10,11,12,13,14,15,16,17,18,19,20 * * 1,2,3,4,5');
    speak("It's $Time_Now. Temp is $CurrentTemp. Winnd Chill is $CurrentChill.") if time_cron('30 10,11,12,13,14,15,16,17,18,19,20 * * 0,6');
}

#-----> Play a Collection of Music

$v_play_music = new Voice_Cmd('Play Music');
if (($state = said $v_play_music) || (state_now $request_music_stuff eq 'on')) {
    $Save{mode} = 'mute';
    run qq[winamp E:\\mp3s];
}

$v_play_xmas_music = new Voice_Cmd('Play Christmas Music');
if ($state = said $v_play_xmas_music) {
    $Save{mode} = 'mute';
    run qq[winamp E:\\mp3s\\christmas];
}

$v_stop_music = new Voice_Cmd('Stop Music');
if (($state = said $v_stop_music) || (state_now $request_music_stuff eq 'off')) {
    run qq[winamp /stop];
    $Save{mode} = 'normal';
}
