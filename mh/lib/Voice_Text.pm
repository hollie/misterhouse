
package Voice_Text;
use strict;

my ($VTxt, $VTxt_festival, $speak_pgm, $save_mute_esd, $save_change_volume, %pronouncable);
my ($ViaVoiceTTS); #mod for ViaVoiceTTS

my $is_speaking_timer = new Timer;

sub init {

    if ($main::config_parms{voice_text} =~ /festival/i) {
        print "Creating festival TTS socket\n";
        my $festival_address = "$main::config_parms{festival_host}:$main::config_parms{festival_port}";
        $VTxt_festival = new  Socket_Item(undef, undef, $festival_address);
        start $VTxt_festival;
        if ($main::config_parms{festival_init_cmds}) {
            print "Data sent to festival: $main::config_parms{festival_init_cmds}\n";
            set $VTxt_festival qq[$main::config_parms{festival_init_cmds}];
        }
    }
    if ($main::config_parms{voice_text} =~ /vv_tts/i) {
        $speak_pgm = qq[$main::Pgm_Path/vv_tts.pl];
        $speak_pgm .= " -prescript "     . $main::config_parms{vv_tts_prescript}     if $main::config_parms{vv_tts_prescript};
        $speak_pgm .= " -postscript "    . $main::config_parms{vv_tts_postscript}    if $main::config_parms{vv_tts_postscript};
        $speak_pgm .= " -playcmd "       . $main::config_parms{vv_tts_playcmd}       if $main::config_parms{vv_tts_playcmd};
        $speak_pgm .= " -default_sound " . $main::config_parms{vv_tts_default_sound} if $main::config_parms{vv_tts_default_sound};
        print "VV TTS command string: $speak_pgm\n";
    }
    if ($main::config_parms{voice_text} =~ /program (\S+)/i) {
        $speak_pgm = $1;
        $speak_pgm .= " " . $main::config_parms{speak_volume} if $main::config_parms{speak_volume};
        $speak_pgm .= " " . $main::config_parms{speak_pitch}  if $main::config_parms{speak_pitch};
        $speak_pgm .= " " . $main::config_parms{speak_rate}  if $main::config_parms{speak_rate};
        $speak_pgm .= " " . $main::config_parms{speak_voice}  if $main::config_parms{speak_voice};
        print "Speak string: $speak_pgm\n";
    }

    if ($main::config_parms{voice_text} =~ /viavoice/i) {
      $ViaVoiceTTS = 1;     #define $ViaVoiceTTS if 'voice_text=viavoice'
      print "Using ViaVoiceTTS.pm for speech.\n";  
    }

    if ($main::config_parms{voice_text} =~ /ms/i and $main::OS_win) {
        print "Creating MS TTS object\n";
#       $VTxt = CreateObject OLE 'Speech.VoiceText';
        $VTxt = Win32::OLE->new('Speech.VoiceText');
        unless ($VTxt) {
            print "\n\nError, could not create Speech TTS object.  ", Win32::OLE->LastError(), "\n\n";
            return;
        }
        
#       print "Registering the MS TTS object\n";
        $VTxt->Register("Local PC", "perl voice_text.pm");
#       print "Setting speed\n";
#       $VTxt->{Enabled} = 1;
#       my $speed_old = $VTxt->{'Speed'};
    }
    return $VTxt;
}

sub speak_text {
    my(%parms) = @_;
    
    $parms{text} = force_pronounce($parms{text}) if %pronouncable;

                                # Only MSVoice currently tells us when it is done
                                # For all others, set a timer with a rough guess
    set $is_speaking_timer (1 + (length $parms{text}) / 10) unless $VTxt;

    unless ($VTxt or $speak_pgm or $VTxt_festival or $ViaVoiceTTS) {
        unless ($main::config_parms{voice_text}) {
            print "Can not speak.  mh.ini entry for voice_text is disabled. Phrase=$parms{text}\n";
        } else {
            print "Can not speak.  Voice_Text object failed to create. Phrase=$parms{text}\n";
        }
        return;
    }

    if ($VTxt_festival) {
#<SABLE>
#<SPEAKER NAME="male1">
#<VOLUME LEVEL="loud">
#<RATE SPEED="-10%">
# text
#</RATE>
#</VOLUME>
#</SPEAKER>
#</SABLE>
        if ($parms{voice} or $parms{volume} or $parms{rate}) {
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
        }
        print "Data sent to festival: $parms{text}\n";
        set $VTxt_festival qq[(SayText "$parms{text}")];
    }

    if ($ViaVoiceTTS or $main::config_parms{voice_text} =~ /vv_tts/i) {
        $parms{voice} = $main::config_parms{viavoice_voice} unless $parms{voice};
        my %voice_table = (male => 1, female => 2, child => 3, elder_female => 7, elder_male => 8);
        $parms{voice} = $voice_table{lc $parms{voice}} if $voice_table{lc $parms{voice}};
        $parms{text} =~ s/\"/\'/g;
    }

    if ($speak_pgm) {
        my $self = {};
        my $pid = fork;
        $SIG{CHLD}  = "IGNORE";                   # eliminate zombies created by FORK()
        if ($pid) {
            $$self{pid} = $pid;
        } elsif (defined $pid) {
            my $speak_pgm_arg = '';
            if (my $file = $parms{play}) {
                unless ($file =~ /^System/ or $file =~ /^[\\\/]/ or $file =~ /^\S\:/) {
                    $file = "$main::config_parms{sound_dir}/$parms{play}";
                    $file = "$main::config_parms{sound_dir_common}/$parms{play}" unless -e $file;
                }
                $speak_pgm_arg .= " -play $file ";
            }
            if ($main::config_parms{voice_text} =~ /vv_tts/i) {
                $speak_pgm_arg .= " -text '`v$parms{voice} $parms{text}'";
            }
            else {
                $speak_pgm .= ' -volume ' . $parms{volume} if $parms{volume};
                $speak_pgm .= ' -pitch  ' . $parms{pitch}  if $parms{pitch};
                $speak_pgm .= ' -voice  ' . $parms{voice}  if $parms{voice};
                $speak_pgm_arg .= qq[ "$parms{text}"];
            }
            
            print "db start TTS: $speak_pgm $speak_pgm_arg\n" if $main::config_parms{debug} eq 'voice';
            exec qq[$speak_pgm $speak_pgm_arg];
            die 'cant exec $speak_pgm';
        }
    }

    if ($ViaVoiceTTS) {
        $SIG{CHLD}  = "IGNORE";        # eliminate zombies created by FORK()
FORK:                                  # straight out of the book
        if (my $pid=fork) {            # if forked ok
            # Parent's code
            print "$parms{text} sent to $pid\n";
        } elsif (defined $pid) {
            # child's code here
            my $prog = <<ProgCode;
use ViaVoiceTTS;
my \$tts = new ViaVoiceTTS();
ViaVoiceTTS::setVoice \$tts,"$parms{voice}";
ViaVoiceTTS::speak \$tts,"$parms{text}";
exit 0;
ProgCode
            exec "echo '$prog' | $^X ";   # pipe prog to perl
            die "ViaVoiceTTS child died"; # This statement should not be reached
        } elsif ($! =~ /No more process/) {
            # EAGAIN, supposedly recoverable fork error
            sleep 2;
            redo FORK;
        } else {
            # weird fork error
            die "Can't fork: $!\n";
        }
    }

    if ($VTxt) {
        
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
        
#       $VTxt->{'Speed'} = $parms{'speed'} if defined $parms{'speed'};
        my ($priority, $type, $voice);
        $priority = $priority{$parms{'priority'}};
        $type = $type{$parms{'type'}};
                                # Unfortunatly, the voice controls do not work with the 
                                # '95 vintage Centigram text->speech engine :(
#           print "priority=$priority type=$type flag=", $priority | $type, "\n";
        $voice = qq[\\Vce=Speaker="$parms{voice}"\\] if $parms{voice};
        $voice = '' unless $voice;
#           $voice = q[\Chr="Angry"\\];
#           $voice = q[\\\\Vol=2222\\\\];
#           $voice = q[\\VOL=2222\\];
#           $voice = q[/Vol=2222/];
#           print "text=$parms{'text'}\n";
#           print "voice=$voice\n";

#           $VTxt->Speak($voice . $parms{'text'}, ($priority | $type));
#           $VTxt->Speak($voice . $parms{'text'}, $priority, "Vce=Speaker=Biff")
#           print "Sending text to Speak object with voice=$voice type=$type, prioirty=$priority ...";
#           $VTxt->Speak($voice . $parms{'text'}, $priority, $voice);
#           $VTxt->Speak($voice . $parms{'text'}, $priority);
#           $VTxt->Speak($voice . $parms{'text'}, $type, $priority);

        print "Voice_Text.pm ms_tts: VTxt=$VTxt text=$parms{'text'}\n" if $main::config_parms{debug} eq 'voice';
        $VTxt->Speak($voice . $parms{'text'}, $priority);

#           $VTxt->Speak($parms{'text'}, ($priority | $type));
#           $VTxt->Speak('Hello \Chr="Angry"\ there. Bruce is \Vce=Speaker=Biff\ a very smart idiot guy.', hex('201'));

                                # From Agent SpeechOutputTags2zip.doc
#   Chr=Normal,Monotone,Whisper
#   Ctx=Address,Email,Unknow
#   Emp  (Emphasizes the next word
#   Pau=number (pauses for number of milliseconds from 10 to 2550 (.01 to 2.55 seconds)
#   Pit=number (Sets the baseline pitch in hertz (from 50 to 400)
#   Rst  Resets all tags
#   Spd=number  Speed from 50 to 250
#   Vol=number  Volume from 0 to 65535

# More Control tags are at the end of Speeck SDK lowtts.doc

    }
}

sub is_speaking {
    if ($VTxt) {
        return $VTxt->{IsSpeaking};
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

sub speak_mode {
    my ($mode) = lc shift;
                                # Only MS TTS for now
    if ($VTxt) {
        return $VTxt->StopSpeaking      if $mode eq 'stop';
        return $VTxt->AudioPause        if $mode eq 'pause';
        return $VTxt->AudioResume       if $mode eq 'resume';
        return $VTxt->AudioFastForward  if $mode eq 'fastforward';
        return $VTxt->AudioRewind       if $mode eq 'rewind';
        return $VTxt->{Speed} = 250     if $mode eq 'fast';
        return $VTxt->{Speed} = 200     if $mode eq 'normal';
        return $VTxt->{Speed} = 150     if $mode eq 'slow';
        return $VTxt->{Speed} = $mode   if $mode =~ /^\d+$/
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
