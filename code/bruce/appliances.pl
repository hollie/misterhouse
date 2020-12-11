# Category=Appliances

#@ Controls various appliances.

$v_fountain = new Voice_Cmd('Fountain [on,off]');
$v_fountain->set_info('Controls the backyard fountain');

$freezing = new Weather_Item 'TempOutdoor < 32';
if ( state_now $fountain eq ON and state $freezing) {
    speak "Sorry, fountains don't work too well when frozen";
    set $fountain OFF;
}

#set $fountain $state if $state = said $v_fountain;
tie_items $v_fountain $fountain;
tie_event $v_fountain 'speak "Ok, fountain was turned $state"';

# Off for vacation
# set $fountain   ON if $Month > 4 and $Month < 9 and time_cron('00 20 * * *');

#et $fountain   ON if $Season eq 'Summer' and time_cron('00 08 * * *');
set $fountain ON if ( $Month > 4 and $Month < 11 ) and time_cron('00 08 * * *');
set $fountain ON if ( $Month > 4 and $Month < 11 ) and time_cron('00 20 * * *');
set $fountain OFF if time_cron('30 23 * * *');
set $fountain OFF if time_cron('00,30 09 * * *');

# Toggle cameras, in case they get hung up
$v_garage_cameras = new Voice_Cmd('Garage Cameras [on,off,reset]');
$v_garage_cameras->set_info('Conrols power to the garage cameras');
$v_garage_cameras->tie_items( $garage_cameras, 'reset', 'OFF~5~ON' );
$v_garage_cameras->tie_items($garage_cameras);
set $garage_cameras 'OFF~5~ON' if time_cron '00 01,13 * * *';

#$fountain -> hidden(1);

#if (state_now $toggle_fountain) {
#    $state = (ON eq state $fountain) ? OFF : ON;
#    set $fountain $state;
#    speak("rooms=family The fountain was toggled to $state");
#}

#$v_dishwasher = new  Voice_Cmd('Dishwasher [on,off]');
#set $dishwasher $state if $state = said $v_dishwasher;

#v_indoor_fountain = new  Voice_Cmd 'Indoor fountain [on,off]', 'Ok, I turned it $v_indoor_fountain->{said}';
#$v_indoor_fountain = new  Voice_Cmd 'Indoor fountain [on,off]', 'Ok, will turn fountain to %STATE%';
$v_indoor_fountain = new Voice_Cmd 'Indoor fountain [on,off]';
$v_indoor_fountain->set_info('Controls the small indoor fountain by the piano');
$v_indoor_fountain->tie_items($indoor_fountain);
$v_indoor_fountain->tie_event('speak "Ok, fountain was turned $state"');

#tie_items $v_indoor_fountain $indoor_fountain;
#et $indoor_fountain $state if $state = said $v_indoor_fountain;

#set $indoor_fountain  OFF if time_cron('00,30 10 * * *');
#set $indoor_fountain  ON  if time_cron('30 6 * * 1-5');
#set $indoor_fountain  OFF if time_cron('30 8 * * 1-5');

#$v_family_tv = new  Voice_Cmd('{Family room,downstairs} TV [on,off]');
#$v_family_tv-> set_info('This old Family room TV (no IR control)');

#set $family_tv $state if $state = said $v_family_tv;

$v_dockntalk = new Voice_Cmd('DockNTalk [on,off,toggle]');
$v_dockntalk->tie_items($DockNTalk);
