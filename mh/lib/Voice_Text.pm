
package Voice_Text;
use strict;

use vars '$VTxt_version';
my (@VTxt, $VTxt_stream1, $VTxt_stream2, $VTxt_festival, $VTxt_mac, $save_mute_esd, $save_change_volume, %pronouncable);
my (%voice_names, @voice_names, $voice_names_index, $VTxt_pid);


my $is_speaking_timer = new Timer;

sub init {
    my ($engine) = @_;

# The darwin hook is currently done in the main bin/mh code
#    if ($main::Info{OS_name}=~ /darwin/i) {
#        &main::my_use("Mac::Sound");
#		&main::my_use("Mac::Speech");
#        my $voice = $main::config_parms{speak_voice};
#        $voice = 'Albert' unless $voice;
#        my $Mac_voice = $Mac::Speech::Voice{$voice};
#        $VTxt_mac = NewSpeechChannel($Mac_voice); # Need a default voice here?
#    }
    
    if (($main::config_parms{voice_text} =~ /festival/i or $engine and $engine eq 'festival') and
        $main::config_parms{festival_host}) {
        my $festival_address = "$main::config_parms{festival_host}:$main::config_parms{festival_port}";
        print "Creating festival TTS socket on $festival_address\n";
        $VTxt_festival = new  Socket_Item(undef, undef, $festival_address, 'festival', 'tcp', 'raw');
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
                    print " - Sound card $i: $des\n";
                    $VTxt[$i] = Win32::OLE->new('Sapi.SpVoice');
                    $VTxt[$i] ->{AudioOutput} = $object;
                }
                $VTxt[0] = $VTxt[1]; # Default to the first card;

                                # Create an object for to_file calls
                $VTxt_stream1 = Win32::OLE->new('Sapi.SpVoice');
               
            }
            else {
                $VTxt_version = 'msv4';
            }
        }
            
        if ($VTxt_version eq 'msv4') {
            $VTxt[0] = Win32::OLE->new('Speech.VoiceText');
            unless ($VTxt[0]) {
                print "\n\nError, could not create ms Speech TTS object.  ", Win32::OLE->LastError(), "\n\n";
                return;
            }
        
#           print "Registering the MS TTS object\n";
            $VTxt[0]->Register("Local PC", "perl voice_text.pm");
#           $VTxt[0]->{Enabled} = 1;
        }
        print " - Engine used:  $VTxt_version\n";
    }

}

sub speak_text {
    my(%parms) = @_;

    if ($parms{address}) {
        my @address = split ',', $parms{address}; 
        delete $parms{address};
        $parms{to_file} = "$main::config_parms{html_dir}/cache/speak_address.$main::Second.wav";

        &speak_text(%parms);
        package main;   # So the we do not have to use $main::
        for my $address (@address) {
            my $address_code = $config_parms{voice_text_address_code};
            $address_code =~ s|\$address|$address|;
            $address_code =~ s|\$url|http://$Info{IPAddress_local}:$config_parms{http_port}/cache/speak_address.$main::Second.wav|;
            print "Voice_text running address code: $address_code\n" if $main::Debug{voice};
            eval $address_code;
            print "voice_text_address_code eval error: $@" if $@;
        }
        return;
    }
                                # If text is specified, save the default output, so we can set it back
    my $vtxt_default;
    if ($parms{card}) {
        $vtxt_default = $VTxt[0] if $parms{text};
        $VTxt[0] = $VTxt[$parms{card}];
    }

    
                                # Use this as a rough guess if other methods fail
				# - Must trigger timer this pass, not next, or http server
				#   will return before we start!  Hence, call to set_from_last_pass
    unless (@VTxt) {
        set $is_speaking_timer (1 + (length $parms{text}) / 10);
        set_from_last_pass $is_speaking_timer;
    }

    my ($speak_pgm, $speak_engine);
    $speak_engine = $parms{engine};
    $speak_engine = $main::config_parms{voice_text} unless $speak_engine;

    $speak_pgm = $1                                     if $speak_engine =~ /program (\S+)/;
    $speak_pgm = $main::config_parms{voice_text_flite}  if $speak_engine eq 'flite';
    $speak_pgm = "$^X $main::Pgm_Path/vv_tts.pl"        if $speak_engine =~ /vv_tts/i;
    $speak_pgm = "$^X $main::Pgm_Path/vv_tts_simple.pl" if $speak_engine =~ /viavoice/i;


    if($speak_engine =~ /NaturalVoiceWine/i) {
        my $wine_path = $main::config_parms{wine_path};
        $wine_path = 'wine' unless -e $wine_path;
        my $nv_path = $main::config_parms{voice_text_naturalvoice}; # DOS path to NatVox stuff
        $speak_pgm = "$wine_path '$nv_path/bin/ttsstandaloneplayer.exe' -- -data '$nv_path/data' -xml";
    }
    elsif ($speak_engine =~ /NaturalVoice/i) {
        my $path = $main::config_parms{voice_text_naturalvoice};
        $speak_pgm = "$path/bin/TTSStandalonePlayerDT -data $path/data -xml";
#       $speak_pgm = "$path/bin/TTSDesktopPlayer      -data $path/data -xml";
    }
    elsif ($main::Info{OS_name}=~ /darwin/i) {
        $speak_pgm = 'MacSpeech' unless $speak_pgm;
#       $speak_pgm = 'osascript' unless $speak_pgm;
    }
    elsif ($speak_engine =~ /viavoice/i or $speak_engine =~ /vv_tts/i) {
        $parms{voice} = $main::config_parms{viavoice_voice} unless $parms{voice};
        $parms{voice} = $voice_names{lc $parms{voice}} if $voice_names{lc $parms{voice}};
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

                                # Allow for a percentage volume number - Steve Switzer 1/19/2003
    my $mh_volume = state $main::mh_volume if $main::mh_volume;
    print "Voice_Text volume=$parms{volume}, mh_volume=$mh_volume\n" if $main::Debug{voice};
    if ($parms{volume} =~ /(\d+)\%$/) {
        $parms{volume} = int($mh_volume * $1 / 100);
        print "Voice_Text new volume=$parms{volume}\n" if $main::Debug{voice};
    }
    $parms{volume} = 100 if $parms{volume} and $parms{volume} > 100;


    $parms{text} = &set_rate($parms{rate},     $parms{text}) if $parms{rate}; # Allow for slow,normal,fast,wpm:###
    $parms{text} = &set_voice($parms{voice},   $parms{text}, $speak_engine) if $parms{voice};
    $parms{text} = &set_volume($parms{volume}, $parms{text}) if $parms{volume};
    $parms{text} = &set_pitch($parms{pitch},   $parms{text}) if $parms{pitch};

    $parms{text} = force_pronounce($parms{text}) if %pronouncable;

                                # These mess up -text "text" calls and not useful when speaking?
    $parms{text} =~ s/\"//g unless $parms{no_mod};

                                # Drop XML speech tags unless supported
    $parms{text} =~ s/<\/?voice.*?>//g unless ($VTxt_version and $VTxt_version eq 'msv5') or $speak_engine =~ /naturalvoice/i;
    
    return unless $parms{text} or $parms{play};

    if ($speak_engine =~ /^&/) {
        $speak_engine =~ s/^&/&main::/;
        eval "$speak_engine(%parms)";
        print "Voice_Text $speak_engine eval error: $@" if $@;
    }
    elsif ($speak_engine =~ /festival/i) {
        &init('festival') unless $VTxt_festival;

				# Clear out buffer, so is_speaking works
        $main::Socket_Ports{festival}{data_record} = '';
        $main::Socket_Ports{festival}{data}        = '';
    
        if ($parms{to_file}) {
                                       # Change from relative to absolute path
            $parms{to_file} = "$main::Pgm_Path/$1" if $parms{to_file} =~ /^\.\/(.+)/;
            $parms{text} = qq[(utt.save.wave (utt.synth (Utterance Text "$parms{text}")) "$parms{to_file}" "riff")];
            if ($VTxt_festival and active $VTxt_festival) {
                $parms{text} =~ s/<\/?speaker.*?>//ig; # Server does not do sable
                print "Voice_text TTS:  Festival saving to file via server: $parms{to_file}\n" if $main::Debug{voice};
                set $VTxt_festival $parms{text};
                unless ($parms{async}) {
                                          # Wait for server to respond that it is done
                    my $sock = $main::Socket_Ports{festival}{sock};
                    my $i;
                    while ($i++ < 100) {
                        print '-';
                        select undef, undef, undef, .1;
                        if (my $nfound = &main::socket_has_data($sock)) {
                            last;
                        }
                    }
                }
            }
            else {
                my $file = "$main::config_parms{data_dir}/mh_temp.festival.txt";
                &main::file_write($file, $parms{text});
                print "Voice_text TTS: Festival saving to file: $file\n" if $main::Debug{voice};
                system("$main::config_parms{voice_text_festival} -b $file");
            }
            select undef, undef, undef, .2; # Need this ?
        }
        elsif ($parms{voice} or $parms{volume} or $parms{rate} or 
               $parms{text} =~ /<sable>i/ or !$VTxt_festival) {
            my $text = $parms{text};
            unless ($text =~ /<sable>i/) {
                $parms{rate}   = '-50%'  if $parms{rate}   eq 'slow';
                $parms{rate}   = '+50%'  if $parms{rate}   eq 'fast';
                $parms{volume} = 'quiet' if $parms{volume} eq 'soft';
                if ($parms{volume}) {
                    $text = qq[<VOLUME LEVEL="$parms{volume}"> $text </VOLUME>];
                }
                if ($parms{rate}) {
                    $text = qq[<RATE SPEED="$parms{rate}"> $text </RATE>];
                }
                $text = qq[<SABLE> $text </SABLE>];
            }
            my $random = int rand 1000; # Use random file name so we can talk 2+ at once.
            my $file = "$main::config_parms{data_dir}/mh_temp.festival.$random.sable";
            &main::file_write($file, $text);
            print "Voice_text TTS: $main::config_parms{voice_text_festival} --tts $file\n" if $main::Debug{voice};
            system("($main::config_parms{voice_text_festival} --tts $file ; ) &");
#            system("($main::config_parms{voice_text_festival} --tts $file ; rm $file) &");
#            system("($main::config_parms{voice_text_festival} --tts $file ; cat $file) &");
        }
        else {
            print "Data sent to festival: $parms{text}\n" if $main::Debug{voice};
            set $VTxt_festival qq[(SayText "$parms{text}")];
        }
    }
    elsif ($speak_pgm) {
        my $fork = 1 unless $parms{to_file} and !$parms{async}; # Must wait for to_file requests, so http requests work

        my $pid = fork if $fork;
        $SIG{CHLD}  = "IGNORE";                   # eliminate zombies created by FORK()
        if ($fork and $pid) {
            $VTxt_pid = $pid;
        } elsif (!$fork or defined $pid) { 
                                # Or else browser will wait for child to finish speaking
            &::socket_close('http') if $main::Socket_Ports{http}{socka};
            my $speak_pgm_arg = '';
            my $speak_pgm_use_stdin = 0;
            my $sound_key = $parms{play};
            if ($sound_key and $main::Sounds{$sound_key}) {
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
                if ($main::config_parms{vv_tts_pa_control} and $main::config_parms{xcmd_file}) {
                	$speak_pgm_arg .= ' -pa_control -xcmd_file ' . $main::config_parms{xcmd_file};
                	if ($parms{rooms}) {
                		$speak_pgm_arg .= ' -rooms ' . $parms{rooms};
                    } else {
                		$speak_pgm_arg .= ' -rooms default';
                    }
                }
                $speak_pgm_arg .= ' -debug '   if $main::Debug{voice};
                $speak_pgm_arg .= ' -nomixer ' if $main::config_parms{vv_tts_nomixer};

                $parms{volume} = '75'  if $parms{volume} eq 'soft';
                $parms{volume} = '100' if $parms{volume} eq 'loud';

                $speak_pgm_arg .= ' -volume '       . $parms{volume}       if $parms{volume};
                $speak_pgm_arg .= ' -play_volume '  . $parms{play_volume}  if $parms{play_volume};
                $speak_pgm_arg .= ' -voice_volume ' . $parms{voice_volume} if $parms{voice_volume};
                $parms{voice} = '' unless $parms{voice} =~ /^\d+$/; # -voice supports numbers only
                $speak_pgm_arg .= ' -voice '        . "'$parms{voice}'"    if $parms{voice};
                $speak_pgm_arg .= ' -to_file '      . $parms{to_file}      if $parms{to_file};
                $speak_pgm_arg .= qq[ -text "$parms{text}"];
            }
            elsif ($speak_engine =~ /viavoice/) {
                $speak_pgm_arg .= ' -voice '     . "'$parms{voice}'"  if $parms{voice};
                $speak_pgm_arg .= ' -to_file '   . $parms{to_file}    if $parms{to_file};
                $speak_pgm_arg .= ' -right '     . $parms{right}      if $parms{right};
                $speak_pgm_arg .= ' -left '      . $parms{left}       if $parms{left};
                $speak_pgm_arg .= qq[ "$parms{text}"];
            }
            elsif ($speak_pgm =~ /flite/) {
                $speak_pgm_arg .= " -o $parms{to_file}" if $parms{to_file};
                $speak_pgm_arg .= qq[ -t "$parms{text}"];
            }
            elsif ($speak_engine =~ /naturalvoice/i) {
                if ($parms{to_file}) {
                    $speak_pgm  =~ s/Player/File/i;
                    my $file = $parms{to_file};
#                   $file = "$main::config_parms{wine_path_temp}/mh_voice_text.wav" if $speak_engine =~ /naturalvoicewine/i;
                    $speak_pgm  .= " -o $file";
                }

# Use either of these ... use_stdin has problems with mh -tk 1
                $parms{text} =~ s/\"/\'/g;   # Leave ' for use in I've etc
                $speak_pgm   = qq[echo "$parms{text}" | $speak_pgm];
#               $speak_pgm_use_stdin = 1;    

                $speak_pgm .= " > /dev/null" unless $main::Debug{voice} and $main::Debug{voice} > 1;
            }
            elsif ($speak_pgm eq 'MacSpeech') {
                my $volume_reset = GetDefaultOutputVolume();
                SetDefaultOutputVolume(2**$parms{volume}) if $parms{volume};
                SpeakText($VTxt_mac, $parms{text});
                SetDefaultOutputVolume(2**$volume_reset)  if $parms{volume};
#               sleep 1 while SpeechBusy();
            }
            elsif ($speak_pgm eq 'osascript') {
                $parms{text} =~ s/\"/\'/g;   # Leave ' for use in I've etc
                if ($parms{volume}) {
                    $parms{volume} = int (7 * $parms{volume}/100) if $parms{volume} > 7;
                    $speak_pgm_arg .= qq[ -e 'set volume $parms{volume}'];
                }
                $speak_pgm_arg .= qq[ -e 'say "$parms{text}"'];
                            # Reset to previous level ... how do we get that??
                if ($parms{volume_reset}) {
                    $speak_pgm_arg .= qq[ -e 'set $parms{volume_reset}'];
                }
            }
                # Not sure what other programs are being used here
            else {
                $speak_pgm_arg .= qq[ "$parms{text}"];
                $speak_pgm_arg .= " -volume  $parms{volume}"  if $parms{volume};
                $speak_pgm_arg .= " -pitch   $parms{pitch}"   if $parms{pitch};
                $speak_pgm_arg .= " -rate    $parms{rate}"    if $parms{rate};
                $speak_pgm_arg .= " -voice   '$parms{voice}'" if $parms{voice};
                $speak_pgm_arg .= " -to_file $parms{to_file}" if $parms{to_file};
            }
            
            print "Voice_text TTS: f=$fork stdin=$speak_pgm_use_stdin p=$speak_pgm a=$speak_pgm_arg\n" if $main::Debug{voice};

            if ($speak_pgm_use_stdin) {
                open  VOICE, "| $speak_pgm $speak_pgm_arg";
                print VOICE $parms{text};
                close VOICE ;
                exit 0 if $fork;
            }
            elsif ($fork) {
                exec qq[$speak_pgm $speak_pgm_arg];
                die 'cant exec $speak_pgm';
#                system qq[$speak_pgm $speak_pgm_arg];
#                &main::copy("$main::config_parms{wine_path_temp}/mh_voice_text.wav", $parms{to_file})
#                  if $parms{to_file} and $speak_engine =~ /naturalvoicewine/i;
#                exit 0;
            }
            else {
                system qq[$speak_pgm $speak_pgm_arg];
            }
        }
    }
    elsif ($VTxt[0]) {
        print "Voice_Text.pm ms_tts: comp=$parms{compression} async=$parms{async} to_file=$parms{to_file} VTxt=$VTxt[0] text=$parms{'text'}\n" 
          if $main::Debug{voice};
        if ($VTxt_version eq 'msv5') {
                                # Allow option to save speech to a wav file
            if ($parms{to_file}) {
# From sdk SpeechAudioFormatType:
# SAFT8kHz8BitMono            =  4 (16k for for 4 words)
# SAFT8kHz16BitMono           =  6 (32k)
# SAFT11kHz8BitMono           =  8 (22k)
# SAFT11kHz16BitMono          = 10 (44k)
# SAFT22kHz16BitMono          = 22 (88k ... this is the default)
# SAFTCCITT_ALaw_8kHzMono     = 41 (16k)
# SAFTTrueSpeech_8kHz1BitMono = 40 (2k .. the most compressed, but not useable by Audrey)
# SAFTCCITT_uLaw_8kHzMono     = 48 (176k)
# SAFTADPCM_8kHzMono          = 56 (176k)
# SAFTGSM610_8kHzMono         = 64 (88k?? ... this is the same as the default)
# SAFTGSM610_11kHzMono        = 65 (3k .. not useable on CE3 CompaQ IA1) 
# SAFTGSM610_22kHzMono        = 66 (5k .. not choppy like above 11kHz mode)
# SAFTGSM610_44kHzMono        = 67 (9k)
                $VTxt_stream2 = Win32::OLE->new('Sapi.SpFileStream');
                $VTxt_stream2->{Format}->{Type} = 4;
                $VTxt_stream2->{Format}->{Type} = 22 if $parms{compression} eq 'low';
                $VTxt_stream2->{Format}->{Type} = 66 if $parms{compression} eq 'high';
                $VTxt_stream2->Open($parms{to_file}, 3, 0);
                $VTxt_stream1->{AudioOutputStream} = $VTxt_stream2;
                if ($parms{async}) {
                    $VTxt_stream1->Speak($parms{text}, 1 + 8); # Flags: 1=async 8=XML
                }
                else {
                    $VTxt_stream1->Speak($parms{text}, 8); # Flags: 8=XML (no async, so we can close)
                    $VTxt_stream2->Close;
                    undef $VTxt_stream2;
#                   &main::print_log("Text->wav file:  $parms{to_file}");
#                   &main::play($parms{to_file});
                }
            }
            else {
#               $VTxt[0]->Speak($parms{text}, 1 + 2 + 8); # Flags: 1=async  2=purge  8=XML
                $VTxt[0]->Speak($parms{text}, 1 +     8);
            }
        }
                                                                # Older engine
        else {
            if ($parms{to_file}) {
                &main::print_log("speak -to_file not supported with tts engine msv4.  Text=$parms{text}");
                return;
            }
        
        # Turn off vr while speaking ... SB live card will listen while speaking!
        #  - this doesn't work.  TTS does not start right away.  Best to poll in Voice_Cmd
#           &Voice_Cmd::deactivate;

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
#           $voice = qq[\\Vce=Speaker="$parms{voice}"\\] if $parms{voice};
            $voice = '' unless $voice;
            
            print "Voice_Text.pm ms_tts: VTxt=$VTxt[0] text=$parms{'text'}\n" if $main::Debug{voice};
            $VTxt[0]->Speak($voice . $parms{'text'}, $priority);
            
#           $VTxt[0]->Speak($parms{'text'}, ($priority | $type));
#           $VTxt[0]->Speak('Hello \Chr="Angry"\ there. Bruce is \Vce=Speaker=Biff\ a very smart idiot guy.', hex('201'));
        }

    }
    else {
        print "Can not speak for engine=$speak_engine: Phrase=$parms{text}\n" if $speak_engine;
    }
    
    $VTxt[0] = $vtxt_default if $vtxt_default;
    
}

sub is_speaking {
    my ($card) = @_;
    $card = 0 unless $card;
    if (@VTxt and $VTxt[$card]) {
        if ($VTxt_version eq 'msv5') {
                                # I think these are the same??  I did not benchmark for speed.
#           return $VTxt[$card]->WaitUntilDone(0);
            return 2 == ($VTxt[$card]->Status->{RunningState});
        }
        else {
            return $VTxt[$card]->{IsSpeaking};
        }
    }
    elsif ($VTxt_pid) {
        return 1 unless waitpid($VTxt_pid, 1);
        unset $is_speaking_timer;
        undef $VTxt_pid;
        return 0;
    }
    else {
        return active $is_speaking_timer;
    }
}

sub is_speaking_wav {
    if ($VTxt_stream1) {
                                # I RunningState does not work with streams, but
                                # WaitUntilDone does (returns 0 while speaking)
        my $rc = $VTxt_stream1->WaitUntilDone(0);
        if ($rc) {
            $VTxt_stream2->Close;
            undef $VTxt_stream2;
        }
        return !$rc;
    }
				# Festival will echo back when it is done generating speech
				# Note: This does NOT work with live speech, as it finished
				#       generating that before it finishes speaking it.
    elsif ($VTxt_festival and active $is_speaking_timer) {
				# Either of these should work
#       my $d=&main::socket_has_data($main::Socket_Ports{festival}{sock});
        my $s = said $VTxt_festival;
#	print "s=$s d=$d ";
        if ($s) {
            unset $is_speaking_timer;
            select undef, undef, undef, .2; # Need this ?
        }
        return active $is_speaking_timer;
    }
    else {
        return &is_speaking();
    }
}

                                # This has been moved to mh.  Leave this stub in so 
                                # we don't break old user code
sub last_spoken {
    my ($how_many) = @_;
    &main::speak_log_last($how_many);
}

sub list_voices {
#   return @voice_names;
#   &read_parms unless %voice_names;  # Don't need this ... now called on startup.
    return (sort keys  %voice_names);
}
sub list_voice_names {
    return @voice_names;
}
    
sub read_parms {
                                # Read in voice name translation and list of available voices
    &main::read_parm_hash(\%voice_names, $main::config_parms{voice_names});
    my %temp = reverse %voice_names;
    @voice_names = sort   keys %temp;
    print "Voice names: @voice_names\n";

    my $pronouncable_list_file = $main::config_parms{pronouncable_list_file};
    if ($::Startup or main::file_change($pronouncable_list_file)) {
        my ($phonemes, $word, $cnt);
        open (WORDS, $pronouncable_list_file) or 
          print "\nError, could not find the pronouncable word file $pronouncable_list_file: $!\n"; 
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

}


sub set_mode {
    my ($mode) = lc shift;
    print "Setting mode to $mode\n" if $mode and $main::Debug{voice};
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
                                # AT&T docs say range is 0 -> 200, but
                                # I saw no difference between 100 and 200
#       $volume *= 2;           # Volume range is 0 -> 200
 
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
    my ($voice, $text, $speak_engine) = @_;

    return $text unless $voice;

    $speak_engine = $main::config_parms{voice_text} unless $speak_engine;

                         # Override according to mh.ini voice_names list
    $voice = $voice_names{lc $voice} if $voice_names{lc $voice};

                         # Random pick from the list in the mh.ini voice_names parm
    if ($voice eq 'random') {
        my $i = int((@voice_names) * rand);
        $voice = $voice_names[$i];
        print "Setting random voice.  i=$i voice=$voice\n" if $main::Debug{voice};
    }
    elsif ($voice eq 'next') {
        $voice_names_index = 1 if ++$voice_names_index > @voice_names;
        $voice = $voice_names[$voice_names_index - 1];
        print "Setting next voice.  index=$voice_names_index voice=$voice\n" if $main::Debug{voice};
    }
                         # This option is just plain goofy.  Inspired by dictionaraoke.org
                         # Works only for xml enabled engines like MSv5 or linux NaturalVoices
    elsif ($voice eq 'all') {
        my @words = split ' ', $text;
        $text = '';
        for my $word (@words) {
            $voice_names_index = 1 if ++$voice_names_index > @voice_names;
            $text .= "<voice required='Name=$voice_names[$voice_names_index-1]'>$word</voice> ";
        }
        return $text . '.';     # Add . or last word is not spoken??
    }

    if (($VTxt_version and $VTxt_version eq 'msv5') or $speak_engine =~ /naturalvoice/i) {
        my $spec;
        if ($voice =~ /female/i) {
            $spec .= "Gender=Female;";
        }
        elsif ($voice =~ /male/i) {
            $spec .= "Gender=Male;";
        }
        if ($voice =~ /child/i) {
            $spec .= "Age=Child;";
        }
        elsif ($voice =~ /grownup/i) {
            $spec .= "Age=!Child;";
        }
                                # Old code
        if (0 and $voice =~ /random/) {
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
#           $spec = "Name=Microsoft $voice";
#           $spec = "Name=ATT DTNV 1.3 $voice";
            $spec = "Name=$voice";
        }

        print "Setting xml voice ($voice) to spec=$spec\n" if $main::Debug{voice};

                                # If text is given, set for just this text with XML.  Otherwise change the default
        if ($text) {
            return "<voice required='$spec'> " . $text . " </voice>";
        }
                                # First voice returned is the best fit
        elsif ($VTxt_version) {
            for my $object (Win32::OLE::in $VTxt[0]->GetVoices($spec)) {
                print "Setting voice ($voice) to $spec: $object\n" if $main::Debug{voice};
                $VTxt[0]->{Voice} = $object;
                return;
            }
        }
    }
    elsif ($voice and $speak_engine =~ /festival/i) {
        return "<SPEAKER NAME='$voice'> " . $text . " </SPEAKER>";
    }
    else {
        return $text;
    }
}


sub force_pronounce {
    my($phrase) = @_;
    print "input  phrase is '$phrase'\n" if $main::Debug{voice};
    for my $word (keys %pronouncable) {
        $phrase =~ s/\b$word\b/$pronouncable{$word}/gi;
    }
    print "output phrase is '$phrase'\n" if $main::Debug{voice};
    return $phrase;
}
    
1;

#
# $Log$
# Revision 1.46  2003/03/09 19:34:41  winter
#  - 2.79 release
#
# Revision 1.45  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.44  2003/01/18 03:32:42  winter
#  - 2.77 release
#
# Revision 1.43  2003/01/12 20:39:20  winter
#  - 2.76 release
#
# Revision 1.42  2002/12/24 03:05:08  winter
# - 2.75 release
#
# Revision 1.41  2002/12/02 04:55:19  winter
# - 2.74 release
#
# Revision 1.40  2002/11/10 01:59:57  winter
# - 2.73 release
#
# Revision 1.39  2002/10/13 02:07:59  winter
#  - 2.72 release
#
# Revision 1.38  2002/09/22 01:33:24  winter
# - 2.71 release
#
# Revision 1.37  2002/07/01 22:25:28  winter
# - 2.69 release
#
# Revision 1.36  2002/05/28 13:07:51  winter
# - 2.68 release
#
# Revision 1.35  2002/03/31 18:50:39  winter
# - 2.66 release
#
# Revision 1.34  2002/03/02 02:36:51  winter
# - 2.65 release
#
# Revision 1.33  2002/01/23 01:50:33  winter
# - 2.64 release
#
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
