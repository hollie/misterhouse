
# Category=Test

#@ Test various speak options (e.g. voice, card, start/stop, volume)

#print '+' if &Voice_Text::is_speaking;


$house_tagline = new  File_Item("$config_parms{data_dir}/remarks/1100tags.txt");
$test_speak0 = new Voice_Cmd 'Test speech 0 tagline';
speak(read_next $house_tagline) if said $test_speak0;


$test_speak0a = new Voice_Cmd 'Test speech 0 tagline to a file';
#peak to_file => "$config_parms{data_dir}/test_tts.wav", compression => 'high',
speak to_file => "$config_parms{data_dir}/test_tts.wav", compression => 'none',
  text => read_next $house_tagline if said $test_speak0a;


$test_speak = new Voice_Cmd 'Test speech [start,stop,pause,resume,rewind,fastforward,fast,normal,slow,-6,-4,4,6,10]';

if ($state = state_now $test_speak) {
    if ($state eq 'start') {
        my $text = file_head "$Pgm_Root/docs/faq.txt", 20;
        speak $text;
    }
    else {
        speak mode => $state, 
    }
}

$test_speak2 = new Voice_Cmd 'Test speech voice 1 [Mike,Sam,Mary]';
if ($state = state_now $test_speak2) {
    speak "<voice required='name=Microsoft $state'>Testing ${state}'s voice";
}

$test_speak3 = new Voice_Cmd 'Test speech voice 2 [Mike,Sam,Mary,child,male,female,random]';
if ($state = state_now $test_speak3) {
    speak voice => $state, text => 'testing';
}

$test_speak4 = new Voice_Cmd 'Test speech voice 3 [Mike,Sam,Mary,child,male,female,random]';
if ($state = state_now $test_speak4) {
    speak voice => $state;
}

$test_speak5 = new Voice_Cmd 'Test speech voice 4 [Mike,Sam,Mary,child,male,female,random]';
if ($state = state_now $test_speak5) {
    speak voice => $state, text => "Testing voice $state";
}

$test_speak6 = new Voice_Cmd 'Test speech volume 1 [0,25,50,75,100,200]';
if ($state = state_now $test_speak6) {
    speak volume => $state;
}
$test_speak7 = new Voice_Cmd 'Test speech volume 2 [0,25,50,75,100,200]';
if ($state = state_now $test_speak7) {
    speak volume => $state, text => "Testing volume at $state";
}


$test_speak8 = new Voice_Cmd 'Test speech rate 1 [slow,normal,fast,-6,0,6]';
if ($state = state_now $test_speak8) {
    speak rate => $state;
}
$test_speak9 = new Voice_Cmd 'Test speech rate 2 [slow,normal,fast,-6,0,6]';
if ($state = state_now $test_speak9) {
    speak rate => $state, text => "Testing rate at $state";
}



$test_speak10 = new Voice_Cmd 'Default speech output 1 card [1,2,3,4]';
if ($state = state_now $test_speak10) {
    speak card => $state;
}
$test_speak11 = new Voice_Cmd 'Test speech output 2 card [1,2,3,4]';
if ($state = state_now $test_speak11) {
    speak card => $state, text => "Testing speech to soundcard $state";
}

#speak card => 3, text => "Testing: $Second" if new_second 10;


# Category=Test

$test_voice_ms = new Voice_Cmd "Speak in many voices";


if (said $test_voice_ms) {
    speak voice => 'Sam',     text => "This is Microsoft Sam's voice";
    speak voice => 'Mike2',   text => "This is Microsoft Mike's voice";
    speak voice => 'Mary',    text => "This is Microsoft Mary's voice";
    speak voice => 'Mike',    text => "This is AT&T Mike's voice";
    speak voice => 'Crystal', text => "This is AT&T Crystal's voice";
    speak voice => 'Rich',    text => "This is AT&T Rich's voice";
}

if (0 and said $test_voice_ms) {
    my $msg;
    $msg .= &Voice_Text::set_voice('Rich',    "This is AT&T Rich's voice");
    $msg .= &Voice_Text::set_voice('Crystal', "This is AT&T Crystal's voice");
    $msg .= &Voice_Text::set_voice('Mike',    "This is AT&T Mike's voice");
    $msg .= &Voice_Text::set_voice('Mary',    "This is Microsoft Mary's voice");
    $msg .= &Voice_Text::set_voice('Mike2',   "This is Microsoft Mike's voice");
    $msg .= &Voice_Text::set_voice('Sam',     "This is Microsoft Sam's voice");
    speak $msg;
}
