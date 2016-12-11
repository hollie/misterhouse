
print '+' if &Voice_Text::is_speaking;

$test_speak = new Voice_Cmd
  '[start,stop,pause,resume,rewind,fastforward,fast,normal,slow,150,200,300] test speech';

if ( $state = state_now $test_speak) {
    if ( $state eq 'start' ) {
        my $text = file_head "$Pgm_Root/docs/faq.txt", 100;
        speak $text;
    }
    else {
        speak
          mode => $state,
          ;
    }
}
