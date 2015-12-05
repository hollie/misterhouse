
# Category = MisterHouse

#@ Enables speech on the Mac

=begin comment 

From Jon Boehm on 8/2003:

Around 2.76 I, thru Bruce, added some
switches in the speech handler in mh. It key off of the 'darwin' OSX core.
If you do a grep in you mh dir for 'darwin' you will see the changes.
Basically I bypass mh's speech processing all together because I got strange
forking behavior. Instead I created the attached file.  Note: you need to
install the perl lib Mac::Speech and Mac::Sound for it to work.  If I
remember correctly, this is a sub lib of a bigger lib but if you do a search
for it you should find where it comes from.

Basically the attached file creates a OS X TTS channel at mh startup.  I've
found the first use of the TTS channel slow but the rest are very fast. Much
faster than before.  The only thing that I don't like is that it will only
destroy the channel if you quit mh.  This creates a problem for code reloads
and other kinds of restarts that don't quit mh.  More TTS channels are
created without destroying the old channel.  Besides a very very minor TTS
memory leek, which I have not been able to actually see, I have not seen any
side effect from this.

=cut

# noloop=start
use Mac::Sound;
use Mac::Speech;
$TimerVolume = new Timer;

#		my $volume_reset;
my $voice = $main::config_parms{speak_voice};
$voice = 'Victoria' unless $voice;
my $Mac_voice   = $Mac::Speech::Voice{$voice};
my $Mac_Channel = NewSpeechChannel($Mac_voice);    # Need a default voice here?
print "TTS Channel Created As: $Mac_Channel\n";

# noloop=stop

sub speak_mac {
    print "Speak_mac @_\n";
    my ($mac_text) = @_;

    #	$volume_reset = GetDefaultOutputVolume();
    #	print("reset volume: $volume_reset \t 2**$volume_reset\n");
    SetDefaultOutputVolume(0x01000100);

    #	print("Trying to Speak \t $mac_text\n");
    SpeakText( $Mac_Channel, $mac_text );
    set $TimerVolume 6;

    #  SetDefaultOutputVolume($volume_reset);
}
if ( expired $TimerVolume) {
    SetDefaultOutputVolume(0x00500050);    #$volume_reset
}

sub Dispose_Speech_Channel {
    print "TTS Channel Destroyed: $Mac_Channel\n";
    DisposeSpeechChannel($Mac_Channel);
}
