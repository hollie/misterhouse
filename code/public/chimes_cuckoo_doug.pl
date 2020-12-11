
=begin comment

Weird. I have been playing with my own version of a cuckoo clock. I thought
about the method David Norwood used, but found the Wav files to be too large
if you want the timing of the cuckoos to be acceptable, well at least IMHO.
Attached is my solution. The problem with this method is that sometimes if
other things are happening, the timing gets off a little. But at least the
sounds are slow enuf so that they can be counted and that is really the whole
point--if there is onee.

 Category=Clock
 By Douglas J. Nakakihara
 Sound from http://www.thewavplace.com/bchimes/gongcuckoo.wav
 Wav file was renamed cuckoo.wav and placed in mh/sounds dir

=cut

# Play sound every half-hour
if ( time_cron('30 7-22 * * *') ) {
    play( file => "cuckoo.wav" );
}

# On hour, set number of cuckoos
my $CuckooHour;
if ( time_cron('0 7-22 * * *') ) {
    if ( $Hour > 12 ) {
        $CuckooHour = $Hour - 12;
    }
    else {
        $CuckooHour = $Hour;
    }
}

# Play cuckoos and decrement hour counter.
if ( $CuckooHour > 0 ) {
    play( mode => 'wait', file => "chimes/gongcuckoo.wav" );
    $CuckooHour--;
}
