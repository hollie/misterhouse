
package Voice_Text;
use strict;

my ($VTxt, $VTxt_festival, $VTxt_Outloud, $save_mute_esd, $save_change_volume);

sub init {

	if ($main::config_parms{voice_text} =~ /festival/i) {
		print "Creating festival TTS socket\n";
		my $festival_address = "$main::config_parms{festival_host}:$main::config_parms{festival_port}";
		$VTxt_festival = new  Socket_Item(undef, undef, $festival_address);
		start $VTxt_festival;
	}
	if ($main::config_parms{voice_text} =~ /vvo_speak/i) {
		print "Creating ViaVoice Outloud socket\n";
		my $vvo_speak_address = "$main::config_parms{vvo_host}:$main::config_parms{vvo_port}";
		$VTxt_Outloud = new  Socket_Item(undef, undef, $vvo_speak_address);
		start $VTxt_Outloud;
	}

	if ($main::config_parms{voice_text} =~ /ms/i and $main::OS_win) {
		print "Creating voice MS TTS object\n";
#       	$VTxt = CreateObject OLE 'Speech.VoiceText';
		$VTxt = Win32::OLE->new('Speech.VoiceText');
		unless ($VTxt) {
			print "\n\nError, could not create Speech TTS object.  ", Win32::OLE->LastError(), "\n\n";
			return;
		}

		print "Registering the MS TTS object\n";
		$VTxt->Register("Local PC", "perl voice_text.pm");
#		print "Setting speed\n";
#		$VTxt->{Enabled} = 1;
#		my $speed_old = $VTxt->{'Speed'};
    	}
    	return $VTxt;
}

sub speak_text {
	my(%parms) = @_;
	my $pgm_root = $main::Pgm_Root;

	unless ($VTxt or $VTxt_festival or $VTxt_Outloud ) {
		unless ($main::config_parms{voice_text}) {
			print "Can not speak.  mh.ini entry for voice_text is disabled. Phrase=$parms{text}\n";
		} else {
			print "Can not speak.  Voice_Text object failed to create. Phrase=$parms{text}\n";
       	 	}
        	return;
	}

	if ($VTxt_festival) {
		print "Data sent to festival: $parms{text}\n";
		set $VTxt_festival qq[(SayText "$parms{text}")];
	}

	if ($VTxt_Outloud) {
		set $VTxt_Outloud "speak";
		print "Data sent to vvo_speak: speak\n";
		$parms{text} =~ s/[\r,\n]/ /g;	# some text has returns and newlines, text must be one one line.
		print "Data sent to vvo_speak: $parms{text}\n";
		set $VTxt_Outloud qq[$parms{text}];
	}

	if ($VTxt) {

		# Turn off vr while speaking ... SB live card will listen while speaking!
		#  - this doesn't work.  TTS does not start right away.  Best to poll in Voice_Cmd
#		&Voice_Cmd::deactivate;

	        my(%priority) = ('normal' => hex(200), 'high' => hex(100), 'veryhigh' => hex(80));
		my(%type)     = ('statement' => hex(1), 'question' => hex(2), 'command' => hex(4),
                         'warning'   => hex(8), 'reading'  => hex(10), 'numbers' => hex(20),
                         'spreadsheet'   => hex(40));
		$priority{$parms{'priority'}} = $parms{'priority'} if $parms{'priority'} =~ /\d+/; # allow for direct parm
		$parms{'priority'} = 'normal' unless $priority{$parms{'priority'}};
		$parms{'type'} = 'statement' unless $type{$parms{'type'}};
		$parms{'speed'} = 170 unless defined $parms{'speed'};
        
#		$VTxt->{'Speed'} = $parms{'speed'} if defined $parms{'speed'};
		my ($priority, $type, $voice);
		$priority = $priority{$parms{'priority'}};
		$type = $type{$parms{'type'}};
                                # Unfortunatly, the voice controls do not work with the 
                                # '95 vintage Centigram text->speech engine :(
#       	print "priority=$priority type=$type flag=", $priority | $type, "\n";
        	$voice = qq[\\Vce=Speaker="$parms{voice}"\\] if $parms{voice};
#       	$voice = q[\Chr="Angry"\\];
#       	$voice = q[\\\\Vol=2222\\\\];
#       	$voice = q[\\VOL=2222\\];
#       	$voice = q[/Vol=2222/];
#       	print "text=$parms{'text'}\n";
#       	print "voice=$voice\n";

#       	$VTxt->Speak($voice . $parms{'text'}, ($priority | $type));
#       	$VTxt->Speak($voice . $parms{'text'}, $priority, "Vce=Speaker=Biff")
#       	print "Sending text to Speak object with voice=$voice type=$type, prioirty=$priority ...";
#       	$VTxt->Speak($voice . $parms{'text'}, $priority, $voice);
#       	$VTxt->Speak($voice . $parms{'text'}, $priority);
#       	$VTxt->Speak($voice . $parms{'text'}, $type, $priority);

        	$VTxt->Speak($voice . $parms{'text'}, $priority);

#       	$VTxt->Speak($parms{'text'}, ($priority | $type));
#       	$VTxt->Speak('Hello \Chr="Angry"\ there. Bruce is \Vce=Speaker=Biff\ a very smart idiot guy.', hex('201'));

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
    return unless $VTxt;
    return $VTxt->{IsSpeaking};
}

                                # This has been moved to mh.  Leave this stub in so 
                                # we don't break old user code
sub last_spoken {
    my ($how_many) = @_;
    &main::speak_log_last($how_many);
}

    
sub set_vvo_option {
    my ($command, $setting) = @_;
    set $VTxt_Outloud $command;
    set $VTxt_Outloud $setting;
    return;
}
    
1;

#
# $Log$
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
