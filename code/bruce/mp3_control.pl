# Category=Music

#@ mp3 player control usint ghe httpq winamp plugin

#$v_mp3_control1 = new  Voice_Cmd("Set the house mp3 player to [$mp3_states]");
$v_mp3_control2 = new Voice_Cmd("Set Zacks mp3 player to [$mp3_states]");
$v_mp3_control3 = new Voice_Cmd("Set Nicks mp3 player to [$mp3_states]");
$v_mp3_control4 =
  new Voice_Cmd("Set the shoutcast mp3 player to [$mp3_states]");
$v_mp3_control5 = new Voice_Cmd("Set the phone mp3 player to [$mp3_states]");

#&mp3_control($state, 'house') if $state = said $v_mp3_control1;
&mp3_control( $state, 'warp' ) if $state = said $v_mp3_control3;
&mp3_control( $state, 'z' )    if $state = said $v_mp3_control2;
&mp3_control( $state, 'c1' )   if $state = said $v_mp3_control4;
&mp3_control( $state, 'p90' )  if $state = said $v_mp3_control5;

# Control kid music
$v_mp3_control_boys = new Voice_Cmd '{Turn, } {Boy,boys} music [on,off]';
$v_mp3_control_boys->set_info('One stop shopping for loud music control :)');
$mp3_control_boys_off = new Serial_Item 'XPD', 'off';    # Bedroom
$mp3_control_boys_off->add( 'XND', 'off' );              # Nick's room

if (   $state = said $v_mp3_control_boys
    or $state = state_now $mp3_control_boys_off
    or time_cron '45  6 * * 1-5'
    or time_cron '45 22 * * 1-5'
    or time_cron '45 23 * * 0,6' )
{
    $state = 'off' unless $state;
    $state = ( $state eq 'on' ) ? 'PLAY' : 'STOP';
    print_log "Setting boy's mp3 players to $state";
    run_voice_cmd "Set Nicks mp3 player to $state";

    #    run_voice_cmd "Set Zacks mp3 player to $state";
}

# Allow for control with an X10 palmpad
$mp3_x10_control = new Serial_Item( 'XM9MK', 'Play' );
$mp3_x10_control->add( 'XM9MJ', 'Stop' );
$mp3_x10_control->add( 'XMBMK', 'Next Song' );
$mp3_x10_control->add( 'XMBMJ', 'Previous Song' );
$mp3_x10_control->add( 'XMAMK', 'Volume up' );
$mp3_x10_control->add( 'XMAMJ', 'Volume down' );

if ( $state = state_now $mp3_x10_control) {
    print_log "X10 input, setting mp3 to $state";
    run_voice_cmd "Set the house mp3 player to $state";
}
