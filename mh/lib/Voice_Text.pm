
package Voice_Text;
use strict;

use vars '$VTxt_version';
my (@VTxt, $VTxt_stream, $VTxt_festival, $save_mute_esd, $save_change_volume, %pronouncable);


my $is_speaking_timer = new Timer;

sub init {
    my ($engine) = @_;
    
    if ($main::config_parms{voice_text} =~ /festival/i or $engine and $engine eq 'festival') {
        print "Creating festival TTS socket\n";
        my $festival_address = "$main::config_parms{festival_host}:$main::config_parms{festival_port}";
        $VTxt_festival = new  Socket_Item(undef, undef, $festival_address, 'festival');
        if (start $VTxt_festival) {
            if ($main::config_parms{festival_init_cmds}) {
                print "Data sent to festival: $main::config_parms{festival_init_cmds}\n";
                set $VTxt_festival qq[$main::config_parms{festival_init_cmds}];
            }
        }
    }
    
    if ($main::config_parms{voice_text} =~ /ms/i and $main::OS_win) {
        print "Creating MS TTS object for voice_text=$main::config_parms{voice_text} ...\n";
        
                                # Test and default to the new SDK 5 SAPI
        $VTxt_version = lc $main::config_parms{voice_text};
        unless ($VTxt_version eq 'msv4') {
            if (my $test = Win32::OLE->new('Sapi.SpVoice')) {
                $VTxt_version = 'msv5';

                                # Create objects for all available output cards
                my $outputs = $test->GetAudioOutputs;
                my $count   = $outputs->Count;
                for my $i (1 .. $count) {
                    next if $main::config_parms{voice_text_cards} and $main::config_parms{voice_text_cards} !~ /$i/;
                    my $object = $outputs->Item($i-1);
                    my $des    = $object->GetDescription;
                    print "  Sound card $i: $des\n";
                    $VTxt[$i] = Win32::OLE->new('Sapi.SpVoice');
                    $VTxt[$i] ->{AudioOutput} = $object;
                }
                $VTxt[0] = $VTxt[1]; # Default to the first card;

                                # Create an object for to_file calls
                $VTxt_stream = Win32::OLE->new('Sapi.SpVoice');
                
            }
            else {
                $VTxt_version = 'msv4';
            }
        }
            
        if ($VTxt_version eq 'msv4') {
            $VTxt[0] = Win32::OLE->new('Speech.VoiceText');
#           unless (@VTxt) {
            unless ($VTxt[0]) {
                print "\n\nError, could not create ms Speech TTS object.  ", Win32::OLE->LastError(), "\n\n";
                return;
            }
        
#           print "Registering the MS TTS object\n";
            $VTxt[0]->Register("Local PC", "perl voice_text.pm");
#           $VTxt[0]->{Enabled} = 1;
        }
        print " engine used: $VTxt_version\n";
    }
}

sub speak_text {
    my(%parms) = @_;

    if ($parms{address}) {
        my @address = split ',', $parms{address}; 
        delete $parms{address};
        $parms{to_file} = "$main::config_parms{html_dir}/speak_address.wav";
        &speak_text(%parms);
        package main;   # So the we do not have to use $main::
        for my $address (@address) {
            my $address_code = $config_parms{voice_text_address_code};
            $address_code =~ s|\$address|$address|;
            $address_code =~ s|\$url|http://$Info{Machine}:$config_parms{http_port}/speak_address.wav|;
            print "Voice_text running address code: $address_code\n" if $main::config_parms{debug} eq 'voice';
            eval $address_code;
        }
        return;
    }
                                # If text is specified, save the default output, so we can set it back
    my $vtxt_default;
    if ($parms{card}) {
        $vtxt_default = $VTxt[0] if $parms{text};
        $VTxt[0] = $VTxt[$parms{card}];
    }
    
                                # Only MSVoice currently tells us when it is done
                                # For all others, set a timer with a rough guess
    set $is_speaking_timer (1 + (length $parms{text}) / 10) unless @VTxt;

    my ($speak_pgm, $speak_engine);
    $speak_engine = $parms{engine};
    $speak_engine = $main::config_parms{voice_text} unless $speak_engine;

    $speak_pgm = $1                                     if $speak_engine =~ /program (\S+)/;
    $speak_pgm = $main::config_parms{voice_text_flite}  if $speak_engine eq 'flite';
    $speak_pgm = "$^X $main::Pgm_Path/vv_tts.pl"        if $speak_engine =~ /vv_tts/i;
    $speak_pgm = "$^X $main::Pgm_Path/vv_tts_simple.pl" if $speak_engine =~ /viavoice/i;


    if ($speak_engine =~ /viavoice/i or $speak_engine =~ /vv_tts/i) {
        $parms{voice} = $main::config_parms{viavoice_voice} unless $parms{voice};
        my %voice_table = (male => 1, female => 2, child => 3, elder_female => 7, elder_male => 8);
        $parms{voice} = $voice_table{lc $parms{voice}} if $voice_table{lc $parms{voice}};
    }


                                # Allow for pause,resume,stop,ff,rew.  Also allow mode to set rate
    if (my $mode = $parms{mode}) {
        if ($mode eq 'fast' or $mode eq 'normal' or $mode eq 'slow' or $mode =~ /^[\+\-]?\d+$/) {
            $parms{rate} = $mode;
        }
        else {
            &set_mode($mode);
        }
    }

    $parms{text} = &set_rate($parms{rate},     $parms{text}) if $parms{rate}; # Allow for slow,normal,fast,wpm:###
    $parms{text} = &set_voice($parms{voice},   $parms{text}) if $parms{voice};
    $parms{text} = &set_volume($parms{volume}, $parms{text}) if $parms{volume};
    $parms{text} = &set_pitch($parms{pitch},   $parms{text}) if $parms{pitch};
    
    $parms{text} = force_pronounce($parms{text}) if %pronouncable;

    $parms{text} =~ s/\"//g;    # These mess up -text "text" calls and not useful when speaking?
    
    return unless $parms{text};

    if ($speak_engine =~ /festival/i) {
        &init('festival') unless $VTxt_festival;
    
        if ($parms{to_file}) {
                                       # Change from relative to absolute path
            $parms{to_file} = "$main::Pgm_Path/$1" if $parms{to_file} =~ /^\.\/(.+)/;
            $parms{text} = qq[(utt.save.wave (utt.synth (Utterance Text "$parms{text}")) "$parms{to_file}" "riff")];
            if (active $VTxt_festival) {
                print "Voice_text TTS:  Festival saving to file via server: $parms{to_file}\n" if $main::config_parms{debug} eq 'voice';
                set $VTxt_festival $parms{text};
                                          # Wait for server to respond that it is done
                my $sock = $main::Socket_Ports{festival}{sock};
                my $i;
                while ($i++ < 50) {
                    select undef, undef, undef, .1;
                    if (my $nfound = &main::socket_has_data($sock)) {
                        last;
                    }
                }
            }
            else {
                my $file = "$main::config_parms{data_dir}/mh_temp.festival.txt";
                &main::file_write($file, $parms{text});
                print "Voice_text TTS: Festival saving to file: $file\n" if $main::config_parms{debug} eq 'voice';
                system("$main::config_parms{voice_text_festival} -b $file");
            }
            select undef, undef, undef, .2; # Need this ?
        }
        elsif ($parms{voice} or $parms{volume} or $parms{rate} or !active $VTxt_festival) {
            $parms{rate}   = '-50%'  if $parms{rate} eq 'slow';
            $parms{rate}   = '+50%'  if $parms{rate} eq 'fast';
            $parms{volume} = 'quiet' if $parms{volume} eq 'soft';
            my $prefix = qq[<SABLE>];
            my $suffix = qq[</SABLE>];
            if ($parms{voice}) {
                $prefix .= qq[<SPEAKER NAME="$parms{voice}">];
                $suffix = qq[</SPEAKER>] . $suffix;
            }
            if ($parms{volume}) {
                $prefix .= qq[<VOLUME LEVEL="$parms{volume}">];
                $suffix = qq[</VOLUME>]. $suffix;
            }
            if ($parms{rate}) {
                $prefix .= qq[<RATE SPEED="$parms{rate}">];
                $suffix = qq[</RATE>] . $suffix;
        }
            $parms{text} = $prefix . $parms{text} . $suffix;
            my $file = "$main::config_parms{data_dir}/mh_temp.festival.sable";
            &main::file_write($file, $parms{text});
            print "Voice_text TTS: $main::config_parms{voice_text_festival} --tts $file\n" if $main::config_parms{debug} eq 'voice';
            system("$main::config_parms{voice_text_festival} --tts $file &");
        }
        else {
            print "Data sent to festival: $parms{text}\n" if $main::config_parms{debug} eq 'voice';
            set $VTxt_festival qq[(SayText "$parms{text}")];
        }
    }
    elsif ($speak_pgm) {
        my $self = {};
        my $fork = 1 unless $parms{to_file}; # Must wait for to_file requests, so http requests work
        my $pid = fork if $fork;
        $SIG{CHLD}  = "IGNORE";                   # eliminate zombies created by FORK()
        if ($fork and $pid) {
            $$self{pid} = $pid;
        } elsif (!$fork or defined $pid) { 
            my $speak_pgm_arg = '';
            my $sound_key = $parms{play};
            if ($main::Sounds{$sound_key}) {
                #print "main::Sounds{sound_key}=$main::Sounds{$sound_key}\n";
                for my $parm (keys %{$main::Sounds{$sound_key}}) {
                    #print "parm=$parm, $main::Sounds{$sound_key}{$parm}\n";
                    $parms{$parm} = $main::Sounds{$sound_key}{$parm} unless $parms{$parm} and $parm ne 'play';
                }
                $parms{play} = $parms{file} if $parms{file};
            }
            if ($parms{play}) {
                my $file = $parms{play};
                unless ($parms{play} =~ /^System/ or $parms{play} =~ /^[\\\/]/ or $parms{play} =~ /^\S\:/) {
                    $parms{play} = "$main::config_parms{sound_dir}/$file";
                    $parms{play} = "$main::config_parms{sound_dir_common}/$file" unless -e $parms{play};
                }
            }
            $speak_pgm_arg .= " -play $parms{play} " if $parms{play};

            if ($speak_engine =~ /vv_tts/i) {
                $speak_pgm_arg .= " -prescript "      . $main::config_parms{vv_tts_prescript} if $main::config_parms{vv_tts_prescript};
                $speak_pgm_arg .= " -postscript "     . $main::config_parms{vv_tts_postscript} if $main::config_parms{vv_tts_postscript};
                $speak_pgm_arg .= " -playcmd "        . $main::config_parms{vv_tts_playcmd} if $main::config_parms{vv_tts_playcmd};
                $speak_pgm_arg .= " -default_sound "  . $main::config_parms{vv_tts_default_sound} if $main::config_parms{vv_tts_default_sound};
                $speak_pgm_arg .= " -default_volume " . $main::config_parms{sound_volume} if $main::config_parms{sound_volume};
                $speak_pgm_arg .= ' -debug '   if $main::config_parms{debug} eq 'voice';
                $speak_pgm_arg .= ' -nomixer ' if $main::config_parms{vv_tts_nomixer};

                $parms{volume} = '75'  if $parms{volume} eq 'soft';
                $parms{volume} = '100' if $parms{volume} eq 'loud';

                $speak_pgm_arg .= ' -volume '       . $parms{volume}       if $parms{volume};
                $speak_pgm_arg .= ' -play_volume '  . $parms{play_volume}  if $parms{play_volume};
                $speak_pgm_arg .= ' -voice_volume ' . $parms{voice_volume} if $parms{voice_volume};
                $speak_pgm_arg .= ' -voice '        . $parms{voice}        if $parms{voice};
                $speak_pgm_arg .= ' -to_file '      . $parms{to_file}      if $parms{to_file};
                $speak_pgm_arg .= qq[ -text "$parms{text}"];
            }
            elsif ($speak_engine =~ /viavoice/) {
                $speak_pgm_arg .= ' -voice '        . $parms{voice}        if $parms{voice};
                $speak_pgm_arg .= ' -to_file '      . $parms{to_file}      if $parms{to_file};
                $speak_pgm_arg .= qq[ "$parms{text}"];
            }
            elsif ($speak_pgm =~ /flite/) {
                $speak_pgm_arg .= " -o $parms{to_file}" if $parms{to_file};
                $speak_pgm_arg .= qq[ -t "$parms{text}"];
            }
                # Not sure what other programs are being used here
            else {
                $speak_pgm_arg .= " " . $main::config_parms{speak_volume} if $main::config_parms{speak_volume};
                $speak_pgm_arg .= " " . $main::config_parms{speak_pitch}  if $main::config_parms{speak_pitch};
                $speak_pgm_arg .= " " . $main::config_parms{speak_rate}   if $main::config_parms{speak_rate};
                $speak_pgm_arg .= " " . $main::config_parms{speak_voice}  if $main::config_parms{speak_voice};
                $speak_pgm_arg .= qq[ "$parms{text}"];
            }
            
            print "Voice_text TTS: $speak_pgm $speak_pgm_arg\n" if $main::config_parms{debug} eq 'voice';
            if ($fork) {
                exec qq[$speak_pgm $speak_pgm_arg];
                die 'cant exec $speak_pgm';
            }
            else {
                system qq[$speak_pgm $speak_pgm_arg];
            }
        }
    }
    elsif ($VTxt[0]) {
        print "Voice_Text.pm ms_tts: VTxt=$VTxt[0] text=$parms{'text'}\n" if $main::config_parms{debug} eq 'voice';
        if ($VTxt_version eq 'msv5') {
                                # Allow option to save speech to a wav file
            if ($parms{to_file}) {
                my $stream_old = $VTxt[0]->{AudioOutputStream};
                my $stream = Win32::OLE->new('Sapi.SpFileStream');
                $stream->Open($parms{to_file}, 3, 0);
                $VTxt_stream->{AudioOutputStream} = $stream;
                $VTxt_stream->Speak($parms{text}, 8); # Flags: 8=XML (no async, so we can close)
                $stream->Close;
                $VTxt_stream->{AudioOutputStream} = $stream_old;
#               &main::print_log("Text->wav file:  $parms{to_file}");
#               &main::play($parms{to_file});
            }
            else {
#               $VTxt[0]->Speak($parms{text}, 1 + 2 + 8); # Flags: 1=async  2=pruge  8=XML
                $VTxt[0]->Speak($parms{text}, 1 +     8);
            }
        }
                                                                # Older engine
        else {
        
        # Turn off vr while speaking ... SB live card will listen while speaking!
        #  - this doesn't work.  TTS does not start right away.  Best to poll in Voice_Cmd
#       &Voice_Cmd::deactivate;

            my(%priority) = ('normal' => hex(200), 'high' => hex(100), 'veryhigh' => hex(80));
            my(%type)     = ('statement' => hex(1), 'question' => hex(2), 'command' => hex(4),
                             'warning'   => hex(8), 'reading'  => hex(10), 'numbers' => hex(20),
                             'spreadsheet'   => hex(40));
            $parms{type} = 'statement'  unless $parms{'type'};
            $parms{speed} = 170         unless $parms{'speed'};
            $parms{priority} = 'normal' unless $parms{priority};
            $priority{$parms{'priority'}} = $parms{'priority'} if $parms{'priority'} =~ /\d+/; # allow for direct parm
            
#           $VTxt[0]->{'Speed'} = $parms{'speed'} if defined $parms{'speed'};
            my ($priority, $type, $voice);
            $priority = $priority{$parms{'priority'}};
            $type = $type{$parms{'type'}};
            $voice = qq[\\Vce=Speaker="$parms{voice}"\\] if $parms{voice};
            $voice = '' unless $voice;
            
            print "Voice_Text.pm ms_tts: VTxt=$VTxt[0] text=$parms{'text'}\n" if $main::config_parms{debug} eq 'voice';
            $VTxt[0]->Speak($voice . $parms{'text'}, $priority);
            
#           $VTxt[0]->Speak($parms{'text'}, ($priority | $type));
#           $VTxt[0]->Speak('Hello \Chr="Angry"\ there. Bruce is \Vce=Speaker=Biff\ a very smart idiot guy.', hex('201'));
        }

    }
    else {
        print "Can not speak for engine=$speak_engine: Phrase=$parms{text}\n";
    }
    
    $VTxt[0] = $vtxt_default if $vtxt_default;
    
}

sub is_speaking {
#    print " vt=$VTxt[0] .. ";
    if (@VTxt) {
        if ($VTxt_version eq 'msv5') {
            return 2 == ($VTxt[0]->Status->{RunningState});
        }
        else {
            return $VTxt[0]->{IsSpeaking};
        }
    }
    elsif ($VTxt_festival and active $is_speaking_timer) {
        my $state = said $VTxt_festival;
        unset $is_speaking_timer if $state;
        return active $is_speaking_timer;
    }
    else {
        return active $is_speaking_timer;
    }
}

                                # This has been moved to mh.  Leave this stub in so 
                                # we don't break old user code
sub last_spoken {
    my ($how_many) = @_;
    &main::speak_log_last($how_many);
}

    
sub read_pronouncable_list {
    my($pronouncable_list_file) = @_;

    my ($phonemes, $word, $cnt);

    open (WORDS, $pronouncable_list_file) or print "\nError, could not find the pronouncable word file $pronouncable_list_file: $!\n"; 

    undef %pronouncable;
    while (<WORDS>) {
        next if /^\#/;
        ($word, $phonemes) = $_ =~ /^(\S+)\s+(.+)\s*$/;
        next unless $word;
        $cnt++;
        $pronouncable{$word} = $phonemes;
    }
    print "Read $cnt entries from $pronouncable_list_file\n";
    close WORDS;
}

sub set_mode {
    my ($mode) = lc shift;
                                # Only MS TTS for now
    if (@VTxt) {
        if ($VTxt_version eq 'msv5') {
            return $VTxt[0]->Skip('Sentence',99999) if $mode eq 'stop';
            return $VTxt[0]->Pause                  if $mode eq 'pause';
            return $VTxt[0]->Resume                 if $mode eq 'resume';
            return $VTxt[0]->Skip('Sentence',  5)   if $mode eq 'fastforward';
            return $VTxt[0]->Skip('Sentence', -5)   if $mode eq 'rewind';
            return $VTxt[0]->Skip('Sentence', $1)   if $mode =~ /forward_(\d+)/;
            return $VTxt[0]->Skip('Sentence', -$1)  if $mode =~ /rewind_(\d+)/;
        }
        else {
            return $VTxt[0]->StopSpeaking      if $mode eq 'stop';
            return $VTxt[0]->AudioPause        if $mode eq 'pause';
            return $VTxt[0]->AudioResume       if $mode eq 'resume';
            return $VTxt[0]->AudioFastForward  if $mode eq 'fastforward';
            return $VTxt[0]->AudioRewind       if $mode eq 'rewind';
        }
    }
}

sub set_pitch {
    my ($pitch, $text) = @_;
                                # Only MS TTS v5 for now
    if ($VTxt_version eq 'msv5') {
                                # Only xml support, so only for the specified text
        if ($text) {
            return "<pitch absmiddle='$pitch'/> " . $text;
        }
        else {
            print "\nError, no support for setting the default pitch\n";
            return;
        }
    }
    else {
        return $text;
    }
}


sub set_rate {
    my ($rate, $text) = @_;

                                # Only MS TTS for now
    return $text unless @VTxt;

    if ($VTxt_version eq 'msv4') {
        $VTxt[0]->{Speed} = 250     if $rate eq 'fast';
        $VTxt[0]->{Speed} = 200     if $rate eq 'normal';
        $VTxt[0]->{Speed} = 150     if $rate eq 'slow';
        $VTxt[0]->{Speed} = $rate   if $rate =~ /^\d+$/;
        return $text;
    }
    else {
        $rate =  4 if $rate eq 'fast';
        $rate =  0 if $rate eq 'normal';
        $rate = -4 if $rate eq 'slow';
                                # If text is given, set for just this text with XML.  Otherwise change the default
        if ($text) {
            return "<rate absspeed='$rate'/> " . $text;
        }
        else {
            $VTxt[0]->{Rate} = $rate;
            return;
        }
    }

}

sub set_volume {
    my ($volume, $text) = @_;
                                # Only MS TTS v5 for now
    if ($VTxt_version eq 'msv5') {
                                # If text is given, set for just this text with XML.  Otherwise change the default
        if ($text) {
            return "<volume level='$volume'/> " . $text;
        }
        else {
            $VTxt[0]->{Volume} = $volume;
            return;
        }
    }
    else {
        return $text;
    }
}

sub set_voice {
    my ($voice, $text) = @_;
    $voice = lc $voice;
                                # Only MS TTS v5 for now
    if ($VTxt_version eq 'msv5') {
        my $spec;
        $voice = lc $voice;
        if ($voice =~ /female/) {
            $spec .= "Gender=Female;";
        }
        elsif ($voice =~ /male/) {
            $spec .= "Gender=Male;";
        }
        if ($voice =~ /child/) {
            $spec .= "Age=Child;";
        }
        elsif ($voice =~ /grownup/) {
            $spec .= "Age=!Child;";
        }

        if ($voice =~ /random/) {
            my (@voices, $object);
#           @voices = Win32::OLE::in $VTxt[0]->GetVoices($spec);
                                # Filter out unusual voices
            for $object (Win32::OLE::in $VTxt[0]->GetVoices($spec)) {
                next if $object->GetDescription eq 'Sample TTS Voice';
                next if $object->GetDescription eq 'MS Simplified Chinese Voice';
                push @voices, $object;
            }
            my $i = int((@voices) * rand);
            $object = $voices[$i];
            $spec = "Name=" . $object->GetDescription;
            print "Setting random voice.  i=$i spec=$spec\n";
        }

        unless ($spec) {
            $spec = "Name=Microsoft $voice";
        }

        print "Setting ms voice to spec=$spec\n";

                                # If text is given, set for just this text with XML.  Otherwise change the default
        if ($text) {
            return "<voice required='$spec'/> " . $text;
        }
                                # First voice returned is the best fit
        else {
            for my $object (Win32::OLE::in $VTxt[0]->GetVoices($spec)) {
                print "Setting voice for $spec: $object\n";
                $VTxt[0]->{Voice} = $object;
                return;
            }
        }
    }
    else {
        return $text;
    }
}


sub force_pronounce {
    my($phrase) = @_;
    print "input  phrase is '$phrase'\n" if $main::config_parms{debug} eq 'voice';
    for my $word (keys %pronouncable) {
        $phrase =~ s/\b$word\b/$pronouncable{$word}/gi;
    }
    print "output phrase is '$phrase'\n" if $main::config_parms{debug} eq 'voice';
    return $phrase;
}
    
1;

#
# $Log$
# Revision 1.32  2002/01/19 21:11:12  winter
# - 2.63 release
#
# Revision 1.31  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.30  2001/11/18 22:51:43  winter
# - 2.61 release
#
# Revision 1.29  2001/10/21 01:22:32  winter
# - 2.60 release
#
# Revision 1.28  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.27  2001/08/12 04:02:58  winter
# - 2.57 update
#
# Revision 1.26  2001/05/28 21:14:38  winter
# - 2.52 release
#
# Revision 1.25  2001/05/06 21:07:26  winter
# - 2.51 release
#
# Revision 1.24  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.23  2001/02/24 23:26:40  winter
# - 2.45 release
#
# Revision 1.22  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.21  2000/09/09 21:19:11  winter
# - 2.28 release
#
# Revision 1.20  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.19  2000/05/06 16:34:32  winter
# - 2.15 release
#
# Revision 1.18  2000/04/09 18:03:19  winter
# - 2.13 release
#
# Revision 1.17  2000/02/20 04:47:55  winter
# -2.01 release
#
# Revision 1.16  2000/01/27 13:44:27  winter
# - update version number
#
# Revision 1.15  2000/01/13 13:39:52  winter
# - added mixer_settings and vvo_stuff (added 2 weeks ago)
#
# Revision 1.12  1999/10/09 20:38:37  winter
# - add max_log_entries check
#
# Revision 1.11  1999/05/30 21:08:55  winter
# - change TDstamp format in log
#
# Revision 1.10  1999/02/21 00:27:17  winter
# - use $OS_win
#
# Revision 1.9  1999/02/04 14:21:28  winter
# - switch to new OLE calls.  Add better error checking
#
# Revision 1.8  1999/01/22 02:43:21  winter
# - add Festival support.
#
# Revision 1.7  1999/01/10 02:29:50  winter
# - give better 'tts engine disabled' messages
#
# Revision 1.6  1999/01/09 21:43:14  winter
# - improve ole fail error
#
# Revision 1.5  1999/01/07 01:55:03  winter
# - Limit size of Spoken_Text array
#
# Revision 1.4  1998/12/08 02:26:07  winter
# - add log
#
#
