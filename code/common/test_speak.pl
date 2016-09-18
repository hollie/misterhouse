
# Category=Test

#@ Test various speak options (e.g. voice, card, start/stop, volume)

#print '+' if &Voice_Text::is_speaking;

$house_tagline = new File_Item("$config_parms{data_dir}/remarks/1100tags.txt");
$test_speak1   = new Voice_Cmd 'Test speech with tagline';
respond( read_next $house_tagline) if said $test_speak1;

$test_speak2 = new Voice_Cmd
  'Test speech with tagline to a file with [low,normal,high] compression';

#peak to_file => "$config_parms{data_dir}/test_tts.wav", compression => 'high',
if ( $state = said $test_speak2) {
    my $file = "$config_parms{data_dir}/test_tts.wav";
    speak
      to_file     => $file,
      compression => $state,
      text        => read_current $house_tagline;
    my $size = int( ( -s $file ) / 1000 );
    print_log "File size is $size kbytes";
    play "$config_parms{data_dir}/test_tts.wav";
}

$test_speak3 = new Voice_Cmd
  'Test speech control of [start,stop,pause,resume,rewind,fastforward,fast,normal,slow,-6,-4,4,6,10]';
$test_speak3->set_info(
    'Reads the mh FAQ, allowing you to test the start,stop, ect speak options');

if ( $state = state_now $test_speak3) {
    if ( $state eq 'start' ) {
        my $text = file_head "$Pgm_Root/docs/faq.txt", 20;
        speak $text;
    }
    else {
        speak
          mode => $state,
          ;
    }
}

# Create a command search menu with all the Voice_Cmd words
my $voice_name_list = join( ',', &Voice_Text::list_voices );    # noloop
$test_speak4 =
  new Voice_Cmd "Test speech with voice [$voice_name_list,random,next]";
$test_speak4->set_info('Speak a phrase with the chosen voice');
speak "voice=$state Testing speech with voice $state"
  if $state = state_now $test_speak4;

$test_speak5 = new Voice_Cmd "Test speech of all voices";
if ( said $test_speak5) {
    for my $voice (&Voice_Text::list_voice_names) {
        speak voice => $voice, text => "This is ${voice}'s voice";
    }
}

$test_speak6 = new Voice_Cmd 'Test speech volume at [1,5,25,50,75,100,200]';
if ( $state = state_now $test_speak6) {
    speak volume => $state, text => "Testing volume at $state";
}

$test_speak7 = new Voice_Cmd 'Test speech rate at [slow,normal,fast,-6,6]';
if ( $state = state_now $test_speak7) {
    speak rate => $state, text => "Testing rate at $state";
}

$test_speak8 = new Voice_Cmd 'Test speech output to card [1,2,3,4]';
if ( $state = state_now $test_speak8) {
    speak card => $state, text => "Testing speech to soundcard $state";
}

$test_speak9 = new Voice_Cmd "Test speech to room [living,bedroom,all]";
speak
  rooms => $state,
  text  => "Attention $state room people.  Hi."
  if $state = said $test_speak9;

$test_speak10 =
  new Voice_Cmd "Test speech to room [living,bedroom,all] with a wav file";
play
  rooms => $state,
  file  => "hello_from_bruce.wav",
  time  => 5
  if $state = said $test_speak10;

$test_speak11 = new Voice_Cmd
  "Test speech engine [festival,viavoice,vv_tts,flite,NaturalVoice]";
speak
  engine => $state,
  text   => "Speaking with speech engine $state"
  if $state = said $test_speak11;

$test_voice12 = new Voice_Cmd
  "Change speech engine to [festival,viavoice,vv_tts,flite,NaturalVoice]";
if ( $state = said $test_voice12) {
    $config_parms{voice_text} = $state;
    speak "The default speech engine has been set to $state";
}

my $speak_app_keys = join ',', sort keys %{ $app_parms{speak} };    # noloop
$test_speak12 = new Voice_Cmd "Test speech app [$speak_app_keys]";
speak
  app  => $state,
  text => "Speaking with with app $state parms"
  if $state = said $test_speak12;
