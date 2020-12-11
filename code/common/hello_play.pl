# Category=Test

#@ Plays a short wav file when activated to test wav file playing.

$v_play_hello = new Voice_Cmd( 'Say hello to Bruce', 0 );
$v_play_hello->set_info('A short wav file from Bruce');
if ( said $v_play_hello) {
    play "hello_from_bruce.wav";
}
