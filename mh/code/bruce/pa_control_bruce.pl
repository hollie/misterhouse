
# Category=Music

#@ Controls the PA relays.

$pa_radio            = new  Serial_Item('DBHD', ON);
$pa_radio           -> add             ('DBLD', OFF);

$v_pa_radio = new  Voice_Cmd('Music [on,off]');
$v_pa_radio-> set_info('Play the phone "music on hold" over the PA system');

if ($state = said $v_pa_radio) {
    set $pa_radio $state;
    run_voice_cmd "speakers $state";
}
