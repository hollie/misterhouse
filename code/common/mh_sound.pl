# Category = MisterHouse

# $Date$
# $Revision$

#@ Controls sound volume durring speak and play events.

# Here is what this code does:
#  - Controls volume and sets a object whenever speak or play is called
#  - Sets the mh_speakers object, which can be used to control relay
#    controlled speakers on and off before and after TTS and wave
#    file sounds (see mh/code/bruce/pa_control.pl).
#  - Plays the mh.ini sound_pre wav file before all sounds.
#    Useful if you want to add delay, or an activation noise for things
#    NOTE: Use speak_chime module instead! Old method is not being maintained.
#    like VOX (Voice Activated) Radios .
#  - Allows for restarting voice engines

$mh_volume            = new Generic_Item;
$mh_speakers          = new Generic_Item;
$mh_speakers_timer    = new Timer;
$Info{Volume_Control} = 'Command Line'
  if $Reload
  and $config_parms{volume_master_get_cmd}
  and $config_parms{volume_master_set_cmd};

################################################
# Allow for default volume control. Reset on startup.
################################################

# noloop=start

&set_volume_master_wrapper( $mh_volume->{state} )
  if $Startup and defined $mh_volume->{state};
&set_volume_wav( $config_parms{volume_wav_default_volume} )
  if $Startup and defined $config_parms{volume_wav_default_volume};

if ( defined( $state = state_now $mh_volume) and $state ne '' ) {
    &set_volume_master_wrapper($state);
}

my $volume_master_changed = 0;
my $volume_wav_previous;

# noloop=start

$Tk_objects{sliders}{volume} = &tk_scalebar( \$mh_volume, 0, 'Volume' )
  if $MW
  and $Reload
  and $Run_Members{mh_sound};

if ( $MW and $Reload ) {
    my $volume_temp = 0;
    $volume_temp = $mh_volume->{state} if defined $mh_volume->{state};
    if ( $Tk_objects{fb4} ) {
        $Tk_objects{volume_status} = $Tk_objects{fb4}->ProgressBar(
            -from   => 0,
            -to     => 100,
            -value  => $volume_temp,
            -width  => 20,
            -blocks => 12
        )->pack(qw/-side left -padx 2/);
        &configure_element( 'progress', \$Tk_objects{volume_status}, 1 );
    }

}

# Detect if we are speaking or not
# Note, a call to is_speaking seems to be expensive on Windows
#  -  mip meter drops from 220 to 170 with this call :(
# Call it every 250 ms
my ( $is_speaking, $is_speaking_flag );
$is_speaking = &Voice_Text::is_speaking if $New_Msecond_250;

#$is_speaking = 1 if active $mh_speakers_timer;

# Eureka! This all FINALLY works with everything (sliders, status, Windows, Winamp DJ, etc.)

sub put_volume_back {
    my $wav_did_it = shift;
    if ($wav_did_it) {
        if ( !$is_speaking_flag ) {
            set $mh_speakers OFF
              ;    # don't turn speakers off if talking (WAV likely a chime)
        }
    }
    else {

        $is_speaking_flag = 0;
        set $mh_speakers OFF;
    }

    # MSv5 has nothing to do with the mixer

    if ( defined $config_parms{volume_wav_default_volume}
        and ( $Voice_Text::VTxt_version ne 'msv5' or $wav_did_it ) )
    {
        print_log(
            "Putting wav volume back to $config_parms{volume_wav_default_volume}"
        );
        &set_volume_wav( $config_parms{volume_wav_default_volume} );

        if ($volume_master_changed) {
            $volume_master_changed = 0;
            &set_volume_master_wrapper( $mh_volume->{state} );
        }

    }

}

if ( !$is_speaking_flag and $is_speaking ) {

    #   print_log 'Speakers on';
    $is_speaking_flag = 1;
    print_log "Setting speakers ON";
    set $mh_speakers ON;

    # The following has no effect :(
    #   &Voice_Cmd::deactivate if $OS_win; # So mh does not listen to itself
}
if ( $is_speaking_flag and !$is_speaking ) {

    # *** v5 has nothing to do with the mixer

    print_log "Speakers off, volume reset to $volume_wav_previous"
      if defined $volume_wav_previous and $Voice_Text::VTxt_version ne 'msv5';
    &put_volume_back();

}

$test_volume = new Voice_Cmd 'Test volume at [5,20,60,100]';
$test_volume->tie_event(
    '$test_volume->respond("volume=$state Testing volume at $state%")');

# Currently, this only works with the MS Voice TTS
$test_speak_mode = new Voice_Cmd
  'Set speech to [stop,pause,resume,rewind,fastforward,fast,normal,slow,-5,5]';
$test_speak_mode->tie_event('speak mode => $state');

# Currently, this only works with the MS Voice TTS
$test_speech_flags = new Voice_Cmd 'Test [xml,sable] speech tags';
if ( $state = said $test_speech_flags) {
    respond "$Pgm_Root/docs/ms_speech_xml_example.txt" if $state eq 'xml';
    respond "engine=festival $Pgm_Root/docs/festival_speech_example.sable"
      if $state eq 'sable';
}

$Tk_objects{volume_status}->configure( -value => $mh_volume->{state} )
  if $Tk_objects{volume_status} and ( state_now $mh_volume);

sub set_volume_master {
    my ($volume) = @_;

    if ( $Info{Volume_Control} eq 'Command Line' ) {
        my $volume_cmd = $config_parms{volume_master_set_cmd};
        print_log eval qq("$volume_cmd");
        my $r = system eval qq("$volume_cmd");
    }
}

sub set_volume_master_wrapper {
    my $state = shift;
    if ( !$Info{Volume_Control} ) {
        print_log "Volume control not enabled";
        return;
    }
    elsif ( $state < 0 or $state > 100 ) {
        $state = 100;
        set $mh_volume 100;
    }
    else {
        print_log "Setting master volume to $state";
        &set_volume_master($state);
    }
    $Tk_objects{volume_status}->configure( -value => $state )
      if $Tk_objects{volume_status};

}

sub set_volume_wav {
    my ($volume) = @_;
    my $volume_wav_previous;
    if ( $Info{Volume_Control} eq 'Command Line' ) {
        print_log "$config_parms{volume_wav_get_cmd}";
        $volume_wav_previous = `$config_parms{volume_wav_get_cmd}`;
        chomp $volume_wav_previous;
        my $volume_cmd = $config_parms{volume_wav_set_cmd};
        print_log eval qq("$volume_cmd");
        my $r = system eval qq("$volume_cmd");
    }
    print_log "Previous wav volume was $volume_wav_previous";

    #return $volume_wav_previous;
}

# Set hooks so set_volume is called whenever speak or play is called
&Speak_pre_add_hook( \&set_volume_pre_hook ) if $Reload;
&Play_pre_add_hook( \&set_volume_pre_hook )  if $Reload;

sub set_volume_pre_hook {
    print_log "FUNCTION: set_volume_pre_hook";
    return
      if $is_speaking
      and $Voice_Text::VTxt_version ne
      'msv5';    # Speaking volume wins over play volume (unless using MSv5!)
    return
      unless $Info{Volume_Control}
      ;          # Verify we have a volume control module installed
    my %parms = @_;

    # msv5 changes volume with xml tags in lib/Voice_Text.pm
    return if $parms{text} and $Voice_Text::VTxt_version eq 'msv5';

    undef $volume_wav_previous;
    my $volume = $parms{volume};
    my $mode   = $parms{mode};

    # *** Oops the following line is wrong--mh_volume is linked to mixer
    # Not to be used as the default for playing WAV's, speaking, etc.

    #$volume = $mh_volume->{state} unless $volume;
    return unless $volume;

    unless ($mode) {
        if ( defined $mode_mh ) {    # *** Outdated (?)
            $mode = state $mode_mh;
        }
        else {
            $mode = $Save{mode};
        }
    }
    return if $mode eq 'mute' or $mode eq 'offline';

    # Set a timer since we can not detect when a wav file is done
    if ( $parms{time} ) {
        set $mh_speakers_timer $parms{time},
          '&put_volume_back(1)';     # flag to say WAV did it!
    }

    if ( $parms{time}
        or ( $parms{text} and $Voice_Text::VTxt_version ne 'msv5' ) )
    {
        print_log "Setting wav volume to $volume";
        $volume = 100 if $volume > 100;

        $volume_wav_previous = &set_volume_wav($volume);

        if ( $parms{mhvolume} ) {
            $volume_master_changed = 1;
            &set_volume_master_wrapper( $parms{mhvolume} );
        }

    }
}

# Allow for a pre-speak/play wav file
&Speak_pre_add_hook( \&sound_pre_speak )
  if $Reload and $config_parms{sound_pre_speak};
&Play_pre_add_hook( \&sound_pre_play )
  if $Reload and $config_parms{sound_pre_play};

sub sound_pre_speak {
    my %parms = @_;
    return if $parms{no_pre};
    play mode => 'wait', no_pre => 1, file => $config_parms{sound_pre_speak};

    # ***  Config parm for this pause!

    #&sleep_time(400); # So the TTS engine doesn't grab the sound card first
}

sub sound_pre_play {
    my %parms = @_;
    return if $parms{no_pre};
    play mode => 'wait', no_pre => 1, file => $config_parms{sound_pre_play};
}

# Allow for restarting of TTS engine
$restart_tts = new Voice_Cmd 'Restart the TTS engine';
$restart_tts->set_info(
    'This will restart the voice Text To Speech engine, in case it died for some reason'
);

&Voice_Text::init if said $restart_tts;
