# Category = MisterHouse

#@ Controls sound volume durring speak and play events.

# Here is what this code does:
#  - Controls volume and sets a object whenever speak or play is called
#  - Sets the mh_speakers object, which can be used to control relay
#    controlled speakers on and off before and after TTS and wave
#    file sounds (see mh/code/bruce/pa_control.pl).
#  - Plays the mh.ini sound_pre wav file before all sounds.
#    Useful if you want to add delay, or an activation noise for things
#    like VOX (Voice Activated) Radios .
#  - Allows for restarting voice engines

$mh_volume         = new Generic_Item;
$mh_speakers       = new Generic_Item;
$mh_speakers_timer = new Timer;
$Info{Volume_Control} = 'Command Line' if $Reload and $config_parms{volume_get_cmd} and $config_parms{volume_set_cmd};





                                # Detect if we are speaking or not
                                # Note, a call to is_speaking seems to be expensive on Windows
                                #  -  mip meter drops from 220 to 170 with this call :(
                                # Call it every 250 ms
my ($is_speaking, $is_speaking_flag);
$is_speaking = &Voice_Text::is_speaking if $New_Msecond_250;

# *** This is BS Play needs its own logic (which does not take msv5 into account!)

#$is_speaking = 1 if active $mh_speakers_timer;

sub put_volume_back {
    print_log("Putting volume back") if defined $volume_previous;
    $is_speaking_flag = 0;
    set $mh_speakers OFF;
    set_volume2($volume_previous) if defined $volume_previous;
#   &Win32::Sound::Volume($volume_previous) if $OS_win and defined $volume_previous;
#   Audio::Mixer::set_cval('vol', $volume_previous) if $main::Info{OS_name} eq "linux" and defined $volume_previous;
#   &Voice_Cmd::activate if $OS_win;	
}


if (!$is_speaking_flag and $is_speaking) {
#   print_log 'Speakers on';
    $is_speaking_flag = 1;
    set $mh_speakers ON;
                                # The following has no effect :(
#   &Voice_Cmd::deactivate if $OS_win; # So mh does not listen to itself
}
if ($is_speaking_flag and !$is_speaking) {
   print_log "Speakers off, volume reset to $volume_previous" if defined $volume_previous;
   &put_volume_back();
}

$test_volume = new Voice_Cmd 'Test volume at [5,20,60,100]';
$test_volume-> tie_event('$test_volume->respond("volume=$state Testing volume at $state%")');

                                # Currently, this only works with the MS Voice TTS
$test_speak_mode = new Voice_Cmd 'Set speech to [stop,pause,resume,rewind,fastforward,fast,normal,slow,-5,5]';
$test_speak_mode-> tie_event('speak mode => $state');

                                # Currently, this only works with the MS Voice TTS
$test_speech_flags = new Voice_Cmd 'Test [xml,sable] speech tags';
if ($state = said $test_speech_flags) {
    respond "$Pgm_Root/docs/ms_speech_xml_example.txt" if $state eq 'xml';
    respond "engine=festival $Pgm_Root/docs/festival_speech_example.sable" if $state eq 'sable';
}

                                # Allow for default volume control.  Reset on startup.
set $mh_volume $mh_volume->state if $Startup;
if (defined($state = state_now $mh_volume) and $state ne '') {
    if (!$Info{Volume_Control}) {
        print_log "Volume control not enabled";
    }
    elsif ($state < 0 or $state > 100) {
        $state = 100;
        set $mh_volume 100;
    }
    else {
        print_log "Changing volume to $state";
        set_volume2($state);
    }
}
                                # Set hooks so set_volume is called whenever speak or play is called
&Speak_pre_add_hook(\&set_volume) if $Reload;
&Play_pre_add_hook (\&set_volume) if $Reload;

#noloop=start
my $volume_previous;
#noloop=stop
sub set_volume {
    return if $is_speaking;     # Speaking volume wins over play volume
    return unless $Info{Volume_Control}; # Verify we have a volume control module installed

    my %parms = @_;

                                # msv5 changes volume with xml tags in lib/Voice_Text.pm
    return if $parms{text} and $Voice_Text::VTxt_version eq 'msv5';

    undef $volume_previous;
    my $volume = $parms{volume};
    $volume = $mh_volume->{state} unless $volume;
    return unless $volume;      # Leave volume at last setting
                                # Set a timer since we can not detect when a wav file is done
    if ($parms{time}) {
       set $mh_speakers_timer $parms{time}, '&put_volume_back()';
    }


    if ($parms{time} or ($parms{text} and $Voice_Text::VTxt_version ne 'msv5')) {
        print_log "Setting volume to $volume";
	$volume = 100 if $volume > 100;
 
        $volume_previous = set_volume2($volume);

    }
}

sub set_volume2 {
    my ($volume) = @_;
    my $volume_previous;
    if ($Info{Volume_Control} eq 'Command Line') {
        $volume_previous = `$config_parms{volume_get_cmd}`;
        chomp $volume_previous;
        my $r = system eval qq("$config_parms{volume_set_cmd}");
    }
    elsif ($Info{Volume_Control} eq 'Win32::Sound' and !$config_parms{skip_volume}            ) {
	# *** nothing here to store previous volume!!! Will leave at this volume until next sound
        $volume = int 255 * $volume / 100;   # (0->100 =>  0->255)
        $volume = $volume + ($volume << 16); # Hack to fix a bug in Win32::Sound::Volume
        &Win32::Sound::Volume($volume);
    }
    elsif ($Info{Volume_Control} eq 'Audio::Mixer') {
        my @vol = Audio::Mixer::get_cval('vol');
        $volume_previous = ($vol[0] + $vol[1]) / 2;
#       Audio::Mixer::set_cval('vol', $volume);
        Audio::Mixer::set_cval('spkr', $volume);
    }
    return $volume_previous;
}

                                # Allow for a pre-speak/play wav file
&Speak_pre_add_hook(\&sound_pre_speak) if $Reload and $config_parms{sound_pre_speak};
&Play_pre_add_hook (\&sound_pre_play)  if $Reload and $config_parms{sound_pre_play};

sub sound_pre_speak {
    my %parms = @_;
    return if $parms{no_pre};
    play mode => 'wait', no_pre => 1, file => $config_parms{sound_pre_speak};

# ***  Config parm for this pause!

    #&sleep_time(400);           # So the TTS engine doesn't grab the sound card first
}
sub sound_pre_play {
    my %parms = @_;
    return if $parms{no_pre};
    play mode => 'wait', no_pre => 1, file => $config_parms{sound_pre_play};
}


                                # Allow for restarting of TTS engine
$restart_tts = new Voice_Cmd 'Restart the TTS engine';
$restart_tts-> set_info('This will restart the voice Text To Speech engine, in case it died for some reason');

&Voice_Text::init if said $restart_tts;
