# Category = Test

$v_ta    = new Voice_Cmd('Speak All');
$v_tm    = new Voice_Cmd('Speak Master');
$v_to50  = new Voice_Cmd('Speak Office 50');
$v_to100 = new Voice_Cmd('Speak Office 100');
$v_tk    = new Voice_Cmd('Speak Kitchen');
$v_tg    = new Voice_Cmd('Speak Garage');
$v_tok   = new Voice_Cmd('Speak Office,Kitchen');
$v_tmult = new Voice_Cmd('Speak Multi test');

speak "rooms=all This message goes to all rooms "        if said $v_ta;
speak "rooms=Master This message in Master Bedroom Only" if said $v_tm;
speak(
    mode   => 'unmuted',
    volume => 50,
    text   => "rooms=Office This message in Office Only"
) if said $v_to50;
speak(
    mode   => 'unmuted',
    volume => 100,
    text   => "rooms=Office This message in Office Only"
)                                                     if said $v_to100;
speak "rooms=Kitchen This message in Kitchen Only"    if said $v_tk;
speak "rooms=Garage Test This message in Garage Only" if said $v_tg;
speak "rooms=Office,kitchen This message in Office and Kitchen" if said $v_tok;

if ( said $v_tmult) {
    speak "rooms=all This is all rooms, watch carefully now";
    speak "rooms=garage This is just the garage";
    speak "rooms=master,office and this is the master and office";
}
