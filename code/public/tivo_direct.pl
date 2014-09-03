#
# Direct Tivo
#

=begin comment

From Andrew Drummond on 02/2003:

Here's my Direct Tivo Code for all interested, the tcl program should be
installed in your hack directory, and execute it from your rc.sysinit or
rc.remote-login script (in the etc/rc.d directory) with the following
code

echo "Starting Misterhouse Related Daemon"
if [ -e /hack/bin/mh2.tcl ]; then
   /hack/bin/mh2.tcl > /dev/null &
fi

You will also need the newtext2osd program from the following site :

http://www.geocities.com/wyngnut2k/

The version on the site is newer that the version I am running so if you
have any problems please let me know.

The default port that the server listens on in 4560 and may be changed
at the bottom of the tcl script.

I threw together the example code included with no testing so if there
are any problems please let me know.


=cut

Category = Test

  $restartTimer = new Timer;

############################
# The default port is 4560 #
############################

# noloop=start
$directivo = new Socket_Item( undef, undef, "192.168.0.103:4560", 'tivo', 'tcp',
    'record' );
start $directivo;

# noloop=stop

# LWRP = Line Wrap 1=On 0=off
# SECS = Number of seconds to display on screen
# FGCL = Foreground Color
# BGCL = Back Ground Color
# XPOS = Starting X Position
# YPOS = Starting Y Position
# TEXT = TEXT TO DISPLAY

# Displays "This is a test" wrapping to next line is necessary
# for 5 seconds before clearing the screen. It is displeay in
# Forground color 2, Background color 1, Starting at Xposition 1
# and Y position 1
# set $directivo "OSD: *LWRP*1*SECS*5*FGCL*2*BGCL*1*XPOS*1*YPOS*1*TEXT*This is a test*";

# Sends the 345 to the tivo (the equiv of changing to channel 345 with
# your remote
# set $directtivo "SENDKEY: 3 4 5";

# said $directtivo can return
# event xxx or remote xxx
# eg. "event NOWPLAYING" telling you that the tivo has just entered
# the NOWPLAYING screen. I have not taken the time to figure out
# all of the event names so you may get e.g 'event 8' returned.
#
# e.g "remote CHANNELUP" the channel up button was just pressed on the
# remote.

$test1 = new Voice_Cmd("direct tivo to [FoxE,FoxW,COM]");

if ( $state_test = said $test1) {
    if ( active $directivo) {
        if ( $state_test eq "FoxE" ) {
            set $directivo "SENDKEY: 3 8 8";
        }
        elsif ( $state_test eq "FoxW" ) {
            set $directivo "SENDKEY: 3 8 9";
        }
        elsif ( $state_test eq "COM" ) {
            set $directivo "SENDKEY: 2 4 9";
        }
        set $directivo
          "OSD: *LWRP*1*SECS*5*FGCL*2*BGCL*1*XPOS*1*YPOS*1*TEXT*$state_test*";
    }
}

if ( $said_dtivo = said $directivo) {
    set $directivo
      "OSD: *LWRP*1*SECS*5*FGCL*2*BGCL*1*XPOS*1*YPOS*1*TEXT*$said_dtivo*";
}

if ( inactive_now $directivo) {
    print_log "Direct Tivo Telnet session closed";
    set restartTimer 10, sub {
        $directivo =
          new Socket_Item( undef, undef, "192.168.0.103:4560", 'tivo', 'tcp',
            'record' );
    };

}
