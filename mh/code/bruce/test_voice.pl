
# Category=Test

$test_voice1 = new Voice_Cmd "Say something with a [loud,soft] voice";
$test_voice2 = new Voice_Cmd "Say something at a [fast,slow] speed";
$test_voice3 = new Voice_Cmd "Say something in voice [male1,female1]";
$test_voice4 = new Voice_Cmd "Say something to room [living,bedroom,all]";
$test_voice5 = new Voice_Cmd "Say something to room [living,bedroom,all] with a wav file";

speak(volume => $state, text => "This is an example of $state text")    if $state = said $test_voice1;
speak(rate   => $state, text => "This is an example of $state text")    if $state = said $test_voice2;
speak(voice  => $state, text => "This is an example of a $state voice") if $state = said $test_voice3;
speak(rooms  => $state, text => "Attention $state room people.  Hi.")   if $state = said $test_voice4;
play (rooms  => $state, file => "hello_from_bruce.wav", time => 5)      if $state = said $test_voice5;
