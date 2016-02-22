
# Test setting of volume in speak and play (Windows only for now).

$v_test_sound1 = new Voice_Cmd 'Play a sound at [20%,50%,100%] volume';
$v_test_sound1->tie_event(
    'play(file => "hello_from_bruce.wav", volume => "$state")');
$v_test_sound1->tie_event('print_log "Setting test sound to $state volume"');

$v_test_sound2 = new Voice_Cmd 'Speak text at [20%,50%,100%,] volume';

#v_test_sound2-> tie_event('speak (text => "Ok, volume set to $state", volume => "$state")');
$v_test_sound2->tie_event('speak "volume=$state Ok, volume set to $state"');
$v_test_sound2->tie_event('print_log "Setting test TTS to $state volume"');

