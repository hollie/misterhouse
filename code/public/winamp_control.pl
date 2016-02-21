# Category=Music

# This code sends commands to winamp using windows messaging.  A substantial
# level of control over a locally running copy of winamp is possible.  There are
# also several commands that query Winamp and return information about the status
# of the playback. Not all of the available commands are implemented in this code.
# A complete list of available commands is available at:
#
#          http://www.winamp.com/nsdn/winamp2x/dev/sdk/api.jhtml.
#
# You will need to install the Win32-GUI package to make this all work.  See
# http://dada.perl.it for information about this package.
#
# If you are using ActiveState Perl you can use ppm (perl package manager)
#  to install Win32::GUI. See the following link:
#
#   http://www.xav.com/perl/faq/ActivePerl-faq2.html
#
# Pay attention to the part where they talk about setting the repository since
#  Win32::GUI does not appear to reside in the ActiveState repository. Instead I used Jenda's:
#
#   http://Jenda.Krynicky.cz/perl
#
# You can use the command lifted right out of the FAQ to set the repository in ppm:
#   set repository JENDA http://Jenda.Krynicky.cz/perl
#
# Also you may need to search for Win32-GUI instead of Win32::GUI...
#

use Win32::GUI;

sub winamp {
    use constant WM_USER =>
      0x0400;   # Some information about WM_USER is available at
                # http://msdn.microsoft.com/library/psdk/winui/messques_4soi.htm
                # WM_USER is not defined in Win32::GUI so it has to be
                # defined manually to use it with windows messaging.
    my $command = shift(@_);
    my $data    = shift(@_);
    my $winamp_handle;
    my $id;
    my $cmd_data;
    my $DEBUG = 0;

    my %cmd = (
        'previous'    => 40044,    #previous track
        'next'        => 40048,    #next track
        'play'        => 40045,    #play button
        'pause'       => 40046,    #pause/unpause
        'stop'        => 40047,    #stop button
        'fade'        => 40147,    #fade out and stops
        'stop next'   => 40157,    #stops after current track
        'forward'     => 40148,    #Fast-forward 5 seconds
        'rewind'      => 40144,    #Fast-rewind 5 seconds
        'beginning'   => 40154,    #Start of playlist
        'end'         => 40158,    #Go to end of playlist
        'eq'          => 40036,    #Toggle EQ
        'volume up'   => 40058,    #Raise volume by 1%
        'volume down' => 40059,    #Lower volume by 1%
        'repeat'      => 40022,    #Toggle repeat
        'shuffle'     => 40023,    #Toggle shuffle
        'close'       => 40001,    #Close Winamp
        'back 10'     => 40197     #Moves back 10 tracks in playlist
    );

    my %usr = (
        'version'    => 0,   #Returns the version of Winamp.
        'clear'      => 101, #Clears playlist.
        'play track' => 102, #Begins play of selected track.
        'status'     => 104, #Returns: playing=1, paused=3, stopped=all others
        'position'   => 105, #If data is 0, returns the position in milliseconds
             #If data is 1, returns current track length in seconds.
             #Returns -1 if not playing or if an error occurs.
        'offset' => 106,  #Seeks within the current track by 'data' milliseconds
        'write playlist' => 120,    #Writes out the current playlist to
                                    #Winampdir\winamp.m3u, and returns
                                    #the current position in the playlist.
        'set track'      => 121,    #Sets the playlist position to 'data'.
        'set volume'     => 122,    #Sets the volume to 'data' (0 to 255).
        'set balance' => 123, #Sets the balance to 'data' (0 left to 255 right).
        'playlist length' =>
          124,    #Returns length of the current playlist, in tracks.
        'playlist position' =>
          125,    #Returns current playlist position, in tracks.
        'restart' => 135    #Restarts Winamp
    );

    unless ( $winamp_handle = Win32::GUI::FindWindow( "Winamp v1.x", undef ) ) {
        print "Error: Winamp is not running\n" if $DEBUG;
        return -90;
    }

    if ( $id = $usr{"$command"} ) {
        print "Valid Winamp user command: $command, $data\n";
        return Win32::GUI::SendMessage( $winamp_handle, WM_USER, $data, $id );
    }

    if ( $cmd_data = $cmd{"$command"} ) {
        print "Valid Winamp command: $command\n" if $DEBUG;
        return Win32::GUI::SendMessage( $winamp_handle, WM_COMMAND, $cmd_data,
            $id );
    }

    print "Error: Invalid Winamp command\n" if $DEBUG;
    return -91;
}

