# Category=Lights

my $light_states = 'on,brighten,dim,off,-30,-50,-80,+30,+50,+80,status';
  
$christmas_lights      = new X10_Item('O8');
$christmas_lights_bed  = new X10_Item('P3');
$christmas_lights_nick = new X10_Item('N8');

$v_christmas_lights = new  Voice_Cmd("Christmas Lights [$light_states]");
if ($state = said $v_christmas_lights) {
    set $christmas_lights_bed $state;
    set $christmas_lights_nick $state;
    set $christmas_lights $state;
}

if (time_cron '20 06 * 12,1 1-5' or
    time_cron '00 18 * 12,1 *') {
    set $christmas_lights_bed ON;
    set $christmas_lights_nick ON;
    set $christmas_lights ON;
}

if (time_cron '30 08 * 12,1 1-5' or
    time_cron '30 22 * 12,1 *') {
    set $christmas_lights_bed OFF;
    set $christmas_lights_nick OFF;
    set $christmas_lights OFF;
}

$v_backyard_light = new  Voice_Cmd("Backyard Light [$light_states]");
set $backyard_light $state if $state = said $v_backyard_light;

set $backyard_light OFF if time_cron('30 21 * * 1-5');
set $backyard_light OFF if time_cron('00,30 22,1 * * * ');
if (state_now $toggle_backyard_light) {
    $state = (ON eq state $backyard_light) ? OFF : ON;
    set $backyard_light $state;
    speak("rooms=family The backyard light was toggled to $state");
}


$v_driveway_light = new  Voice_Cmd("Driveway light [$light_states]");
set $driveway_light $state if $state = said $v_driveway_light;
set $driveway_light OFF if time_cron('00,30 22,23 * * * ');

$v_garage_light = new  Voice_Cmd("Garage light [$light_states]");
set $garage_light $state if $state = said $v_garage_light;
set $garage_light OFF if time_cron('01,31 22,23 * * * ');

 $v_pedestal_light = new  Voice_Cmd("Pedestal light [$light_states]");
set $pedestal_light $state if $state = said $v_pedestal_light;

 $v_living_light = new  Voice_Cmd("Living room light [$light_states]");
set $living_light $state if $state = said $v_living_light;

$v_camera_light = new  Voice_Cmd("Camera light [$light_states]");
set $camera_light $state if $state = said $v_camera_light;

 $v_left_bedroom_light = new  Voice_Cmd("Left bedroom light [$light_states]");
set $left_bedroom_light $state if $state = said $v_left_bedroom_light;

 $v_right_bedroom_light = new  Voice_Cmd("Right bedroom light [$light_states]");
set $right_bedroom_light $state if $state = said $v_right_bedroom_light;

 $v_study_light = new  Voice_Cmd("Study light [$light_states]");
set $study_light $state if $state = said $v_study_light;

 $v_nick_reading_light = new  Voice_Cmd("Nicks reading light [$light_states]");
set $nick_reading_light $state if $state = said $v_nick_reading_light;

#if (time_cron('00 21 * * *')) {
#if (time_now '9:00 PM') {
#    speak("I just turned on Nick's reading light");
#    set $nick_reading_light ON;
#}

set $nick_reading_light OFF if time_cron '00 9,17,23 * * * ';
if ((state_now $nick_reading_light eq ON or state_now $all_lights_on_nick) and
    time_greater_than '11:45 PM') {
    speak "room=nick Master Nick, you bad boy.  It is time to sleep, not to speak.";
    set $nick_reading_light OFF;
}

if (time_now("$Time_Sunset + 0:15")) {
    speak("I just turned the backyard light on at $Time_Now");
    print "I just turned the backyard light on at $Time_Now, sunset=$Time_Sunset\n";
    set $backyard_light ON;
}

if (time_now("$Time_Sunset + 0:30")) {
    speak("I just turned the pedestal light on at $Time_Now");
    set $pedestal_light ON;
}

set $pedestal_light OFF if time_cron '15,45 22,23,24 * * *';
#set $pedestal_light OFF if time_now('10:05 PM');

#if (time_now('8:04AM + 0:03')) {
#    speak("testa 2 worked");
#}

$outside_lights = new Group($backyard_light, $garage_light, $driveway_light);
$living_lights  = new Group($pedestal_light, $camera_light, $christmas_lights, $living_light);
$bedroom_lights = new Group($left_bedroom_light, $right_bedroom_light, $bedroom_fan_light, $bedroom_reading_light);

$v_outside_lights = new  Voice_Cmd("Outside lights [$light_states]");
set $outside_lights $state if $state = said $v_outside_lights;

$v_bedroom_lights = new  Voice_Cmd("Bedroom lights [$light_states]");
set $bedroom_lights $state if $state = said $v_bedroom_lights;

#all_bedroom_lights  = new Serial_Item('XPOPO',  ON);
#all_bedroom_lights -> add            ('XPPPP', OFF);
#$all_bedroom_lights  = new Serial_Item('XPOPALL_ON',  ON);
#$all_bedroom_lights -> add            ('XPOPALL_OFF', OFF);


$all_lights_bed    = new X10_Item('P');
$all_lights_living = new X10_Item('O');
$all_lights  = new Group($all_lights_bed, $all_lights_living);

$v_lights_all = new  Voice_Cmd("All lights [on,off]");
$v_lights_all -> set_info('This controls all the lights in the house');

set $all_lights $state if $state = said $v_lights_all;

$v_living_lights_all = new  Voice_Cmd("Living room lights [on,off]");
set $living_lights $state if $state = said $v_living_lights_all;

$v_bedroom_lights_all = new  Voice_Cmd("Bedroom room lights [on,off]");
set $bedroom_lights $state if $state = said $v_bedroom_lights_all;


                                # Example of creating a lived in random light event
#if (time_random('* 8-22 * * 0,6', 2)) {
#    $state = (ON eq state $camera_light) ? OFF : ON;
#    print_log "Setting camera light $state";
#    set $camera_light $state;
#}
