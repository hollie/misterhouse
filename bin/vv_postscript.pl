#!/usr/bin/perl
#
# This script is run before ViaVoice outloud speaks. Here is where we usually
# suspend ESD so that any music or sounds will be turned off while speaking.
#

if ( open( AMIXER, "/tmp/.vvo_speak.unmute" ) ) {
    system("/usr/bin/amixer set Rear mute 2>&1 > /dev/null");
}
system("/usr/bin/esdctl on");
unlink("/tmp/.vvo_speak.unmute");
exit;
