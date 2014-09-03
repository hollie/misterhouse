# Category=Lights

#@ Controls various lights.

my $light_states = 'on,brighten,dim,off,-10,+10,-30,-50,-80,+30,+50,+80,status';

$v_christmas_lights = new Voice_Cmd("Christmas Lights [$light_states]");
if ( $state = $v_christmas_lights->{said} ) {
    set $christmas_lights_bed $state;
    set $christmas_lights_nick $state;
    set $christmas_lights $state;
}

# if (time_cron '30 06 * 11,12,1 1-5' or
#if (time_cron '00 18 * 12,1 *') {
if ( time_now "$Time_Sunset + 1:00" ) {

    #if (time_cron '00 18 * 12,1 *') {
    #     set $christmas_lights_bed ON;
    #     set $christmas_lights_nick ON;
    set $christmas_lights ON;
}

if (   time_cron '30 08 * 11,12,1 1-5'
    or time_cron '30 22 * 11,12,1 *' )
{
    #     set $christmas_lights_bed OFF;
    #     set $christmas_lights_nick OFF;
    set $christmas_lights OFF;
}

$v_backyard_light = new Voice_Cmd("Backyard Light [$light_states]");
set $backyard_light $state if $state = $v_backyard_light->{said};

set $backyard_light OFF if time_cron('30 21 * * 1-5');
set $backyard_light OFF if time_cron('00,30 22,1 * * * ');

#if ($toggle_backyard_light->{state_now}) {
#    $state = (ON eq state $backyard_light) ? OFF : ON;
#    set $backyard_light $state;
#    speak("rooms=family The backyard light was toggled to $state");
#}

$v_driveway_light = new Voice_Cmd("Driveway light [$light_states]");
set $driveway_light $state if $state = $v_driveway_light->{said};
set $driveway_light OFF if time_cron('00 1,4,7,10,13,16 * * * ');

$v_garage_light = new Voice_Cmd("Garage light [$light_states]");
set $garage_light $state if $state = $v_garage_light->{said};
set $garage_light OFF if time_cron('01 01,03 * * * ');

$v_garage_lights = new Voice_Cmd("Garage lights [$light_states]");
set $garage_lights $state if $state = $v_garage_lights->{said};
set $garage_lights OFF if time_cron('01 01,03 * * * ');

# For testing
$garage_light_relay = new X10_Item 'I2';
set $garage_lights $state if $state = state_now $garage_light_relay;

# $v_pedestal_light = new  Voice_Cmd("Pedestal light [$light_states]");
#set $pedestal_light $state if $state = $v_pedestal_light->{said};

$v_living_light = new Voice_Cmd("Living room light [$light_states]");
set $living_light $state if $state = $v_living_light->{said};

$v_living_fan_light = new Voice_Cmd("Living room fan light [$light_states]");
set $living_fan_light $state if $state = $v_living_fan_light->{said};

$v_camera_light = new Voice_Cmd("Camera light [$light_states]");
set $camera_light $state if $state = $v_camera_light->{said};

$v_left_bedroom_light = new Voice_Cmd("Left bedroom light [$light_states]");
set $left_bedroom_light $state if $state = $v_left_bedroom_light->{said};

$v_right_bedroom_light = new Voice_Cmd("Right bedroom light [$light_states]");
set $right_bedroom_light $state if $state = $v_right_bedroom_light->{said};

# $v_study_light = new  Voice_Cmd("Study light [$light_states]");
#set $study_light $state if $state = $v_study_light->{said};

$v_nick_reading_light = new Voice_Cmd("Nicks reading light [$light_states]");
set $nick_reading_light $state if $state = $v_nick_reading_light->{said};

#if (time_cron('00 21 * * *')) {
#if (time_now '9:00 PM') {
#    speak("I just turned on Nick's reading light");
#    set $nick_reading_light ON;
#}

set $nick_reading_light OFF if time_cron '00 9,17,23 * * * ';
if (
    (
           $nick_reading_light->{state_now} eq ON
        or $all_lights_on_nick->{state_now}
    )
    and time_greater_than '11:45 PM'
  )
{
    speak
      "room=nick Master Nick, you bad boy.  It is time to sleep, not to speak.";
    set $nick_reading_light OFF;
}

#if (time_now "$Time_Sunset + 1:00") {
#    speak("I just turned the backyard light on at $Time_Now");
#    print "I just turned the backyard light on at $Time_Now, sunset=$Time_Sunset\n";
#    set $backyard_light ON;
#}

#if (time_now "$Time_Sunset + 0:30") {
#    speak("I just turned the pedestal light on at $Time_Now");
#    set $pedestal_light ON;
#}

#set $pedestal_light OFF if time_cron '15,45 22,23,24 * * *';
#set $pedestal_light OFF if time_now('10:05 PM');

#if (time_now '8:04AM + 0:03') {
#    speak("testa 2 worked");
#}

$v_outside_lights = new Voice_Cmd("Outside lights [$light_states]");
set $Outside $state if $state = $v_outside_lights->{said};

$v_bedroom_lights = new Voice_Cmd("Bedroom lights [$light_states]");
set $Bedroom $state if $state = $v_bedroom_lights->{said};

#all_bedroom_lights  = new Serial_Item('XPOPO',  ON);
#all_bedroom_lights -> add            ('XPPPP', OFF);
#$all_bedroom_lights  = new Serial_Item('XPOPALL_ON',  ON);
#$all_bedroom_lights -> add            ('XPOPALL_OFF', OFF);

$all_lights_living = new X10_Item('O');
$v_lights_living   = new Voice_Cmd("Living lights [on,off]");
$v_lights_living->tie_items($all_lights_living);

$v_lights_all = new Voice_Cmd("All lights [on,off]");
$v_lights_all->set_info('This controls all the lights in the house');

# Set lights with Group_Item s
set $All_Lights $state if $state = $v_lights_all->{said};

$v_living_lights_all = new Voice_Cmd("Living room lights [on,off]");
set $Living_Room $state if $state = $v_living_lights_all->{said};

$v_bathroom_light_all = new Voice_Cmd("Bathroom lights [$light_states]");
set $bathroom_light $state if $state = $v_bathroom_light_all->{said};

# Example of creating a lived in random light event
#if (time_random('* 8-22 * * 0,6', 2)) {
#    $state = (ON eq state $camera_light) ? OFF : ON;
#    print_log "Setting camera light $state";
#    set $camera_light $state;
#}

#$v_internet_light = new  Voice_Cmd "Internet Light [$light_states]";
#$v_internet_light ->tie_items($internet_light);
#$v_internet_light ->set_authority('anyone');
