
# Category=Test

# This currently only works for Viavoice (not MS Voice)

$test_voice0 = new Voice_Cmd "Say something with a default voice";
$test_voice1 = new Voice_Cmd "Say something with a [loud,soft] voice";
$test_voice2 = new Voice_Cmd "Say something at a [fast,slow] speed";
$test_voice3 = new Voice_Cmd "Say something in voice [male,female,child,elder_male,elder_female,male1,male2,male3]";
$test_voice4 = new Voice_Cmd "Say something to room [living,bedroom,all]";
$test_voice5 = new Voice_Cmd "Say something to room [living,bedroom,all] with a wav file";
$test_voice6 = new Voice_Cmd "Say something with engine [festival,viavoice,vv_tts,flite]";
$test_voice7 = new Voice_Cmd "Change speech engine to [festival,viavoice,vv_tts,flite]";

speak                   text => "This is an example of default speech"  if $state = said $test_voice0;
speak rate   => $state, text => "This is an example of $state text"     if $state = said $test_voice2;
speak voice  => $state, text => "This is an example of a $state voice"  if $state = said $test_voice3;
speak rooms  => $state, text => "Attention $state room people.  Hi."    if $state = said $test_voice4;
play  rooms  => $state, file => "hello_from_bruce.wav", time => 5       if $state = said $test_voice5;
speak engine => $state, text => "Speaking with speech engine $state"    if $state = said $test_voice6;

if ($state = said $test_voice7) {
    $config_parms{voice_text} = $state;
    speak "The default speech engine has been set to $state";
}
