#!/usr/bin/perl
#
# This script is run before ViaVoice outloud speaks. Here is where we usually
# suspend ESD so that any music or sounds will be turned off while speaking.
#

system("/usr/bin/esdctl off");

open( AMIXER, "/usr/bin/amixer get Rear |" ) or die "Couldn't fork amixer";
while (<AMIXER>) {
    chomp;
    next unless (/^\s+Rear/);
    s/(\[|\]|%|:)//g;
    ( $channel, $num, $vol, $state, $rest ) = split( " ", $_, 5 );
    if ( $state =~ /mute/ig ) {
        system("/usr/bin/amixer set Rear unmute 2>&1 > /dev/null");
        open( UNMUTE, "> /tmp/.vvo_speak.unmute" )
          or die
          "Can't create unmute file, check ownership of /tmp/.vvo_speak.unmute";
        print UNMUTE "$state\n";
        close(UNMUTE);
        last;
    }
    else {
        unlink("/tmp/.vvo_speak.unmute");
        last;
    }
}
close(AMIXER);
exit;
