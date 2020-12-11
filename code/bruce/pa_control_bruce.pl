
# Category=Music

# PA needs a default group for some reason, or it will default to all!
$pa_default = new Group;

$pa_none = new Generic_Item;
$pa_default->add($pa_none);

#@ Controls the PA relays.

$pa_radio = new Serial_Item( 'DBHD', ON );
$pa_radio->add( 'DBLD', OFF );

$v_pa_radio = new Voice_Cmd('Music [on,off]');
$v_pa_radio->set_info('Play the phone "music on hold" over the PA system');

if ( $state = said $v_pa_radio) {
    set $pa_radio $state;
    run_voice_cmd "speakers $state";
}
