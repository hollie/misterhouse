#Category=Astronomy

$v_get_Satellite_TLE = new Voice_Cmd('Get Satellite TLE');
$v_get_Satellite_TLE->set_info(
    "Get Two Line Elements for 100 Brightest Satellites");

#my $f_Satellite_TLE   = "$config_parms{data_dir}/data/visual100TLE.txt";
my $f_Satellite_TLE = "C:/TLE/visual100TLE.txt";
my $u_Satellite_TLE = 'http://www.celestrak.com/NORAD/elements/visual.txt';

$p_Satellite_TLE =
  new Process_Item("get_url $u_Satellite_TLE $f_Satellite_TLE");

if ( my $state = state_now $v_get_Satellite_TLE) {
    start $p_Satellite_TLE;
    print_log
      "Getting Visual 100 Satellite TLEs from $u_Satellite_TLE; placing in $f_Satellite_TLE";
}

if ( done_now $p_Satellite_TLE) {
    print_log "Getting Visual 100 Satellite TLE process done";
}

run_voice_cmd 'Get Satellite TLE' if time_now('6:01 PM');

