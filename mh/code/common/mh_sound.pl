# Category=MisterHouse

# This member does 3 things:
#  - Controls volume and sets a object whenever speak or play is called
#    Currenly this is for Windows only (unix suggestions welcome!)
#  - Sets the mh_speakers object, which can be used to control relay
#    controled speakers on and off before and after TTS and wave
#    file sounds (see mh/code/bruce/pa_control.pl).
#  - Plays the mh.ini sound_pre wav file before all sounds.
#    Useful if you want to add delay, or an activation noise for things
#    like VOX (Voice Activated) Radios .

$mh_speakers       = new Generic_Item;
$mh_speakers_timer = new Timer;

                                # Detect if we are speaking or not
                                # Note, a call to is_speaking seems to be expensive on Windows
                                #  -  mip meter drops from 220 to 170 with this call :(
my ($is_speaking, $is_speaking_flag);
$is_speaking = &Voice_Text::is_speaking;

if (!$is_speaking_flag and ($is_speaking or active $mh_speakers_timer)) {
#   print_log 'Speakers on';
    $is_speaking_flag = 1;
    set $mh_speakers ON;
}
if ($is_speaking_flag and !($is_speaking or active $mh_speakers_timer)) {
#   print_log "Speakers off, volume reset to $volume_previous";
    $is_speaking_flag = 0;
    set $mh_speakers OFF;
    &Win32::Sound::Volume($volume_previous) if $OS_win and defined $volume_previous;
}

$test_volume = new Voice_Cmd 'Test volume at [5,20,60,100]';
$test_volume-> tie_event('speak "volume=$state Testing volume at $state%"');

                                # Set hooks so set_volume is called whenever speak or play is called
&Speak_pre_add_hook(\&set_volume) if $Reload;
&Play_pre_add_hook (\&set_volume) if $Reload;

my $volume_previous;
sub set_volume {
    return unless $OS_win;      # Not sure how to control volume on unix
                                # Test for win32 sound
    eval "Win32::Sound::Volume";
    return if $@;               # Older Win32 perls do not have this

    my %parms = @_;

                                # Set a timer since we can not detect when a wav file is done
    set $mh_speakers_timer  $parms{time} if $parms{time}; # Set in &play

    undef $volume_previous;
    my $volume = $parms{volume};
    $volume = $config_parms{sound_volume} unless defined $volume;
    $volume = 100 if $volume > 100;
#   print_log "Setting volume to $volume";
    return unless $volume;      # Leave volume at last (manual?) setting

                                # Store previous volume
    $volume_previous = Win32::Sound::Volume;

    $volume = int 255 * $volume / 100;   # (0->100 =>  0->255)
    $volume = $volume + ($volume << 16); # Hack to fix a bug in Win32::Sound::Volume 
    &Win32::Sound::Volume($volume);
}


                                # Allow for a pre-speak/play wav file

&Speak_pre_add_hook(\&sound_pre) if $Reload and $config_parms{sound_pre};
&Play_pre_add_hook (\&sound_pre) if $Reload and $config_parms{sound_pre};

sub sound_pre {
    my %parms = @_;
    return if !$config_parms{sound_pre} or $parms{no_pre};
    play mode => 'wait', no_pre => 1, no_post => 1, file => $config_parms{sound_pre};
}

