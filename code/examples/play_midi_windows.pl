
# When someone enters our "TV"
# room I would like to play the first 30 seconds of a random selection of TV
# theme song (Cheers, Law and Order, X_Files, Quincy etc.) midi files as
# background for my usual motion announcement.   The problem is in limiting
# the midi play (~ 30 seconds) without having to listen to the full midi.  I
# could individually hand edit all 30 of my TV midis to extract the first 30
# seconds, but my mind balks at the thought of mindless drudgery.

#
# Here is an example of how to play midi files for a specified time on Windows
# Process_Item is used so we can kill it after specified time
# Another approach would be to use sendkeys to stop/close mplayer
#

$midi_test_p = new Process_Item;
$midi_test_v =
  new Voice_Cmd '[Start,Stop,Play5,Play10,Play20,Play30] a midi file';
$midi_test_t = new Timer;

if ( $state = state_now $midi_test_v) {
    print_log "${state}ing the test midi file";
    if ( $state eq 'Stop' ) {
        stop $midi_test_p;
    }
    else {
        #       my $file = 'c:\win98\media\canyon.mid';
        my $file = 'c:\winnt\media\passport.mid';
        print_log "Playing $file";

        #       run "mplayer.exe  /play /close $file"; # Win98
        #       run "mplay32.exe  /play /close $file"; # Win2K
        set $midi_test_p "mplay32.exe  /play /close $file";
        start $midi_test_p;
        if ( $state =~ /Play(\d+)/ ) {
            print_log "Midi timer set for $1 seconds";
            set $midi_test_t $1;
        }
    }
}

run_voice_cmd 'Stop a midi file' if expired $midi_test_t;

print_log "Midi file playback is done" if done_now $midi_test_p;
