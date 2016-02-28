#$Id$

my $PlaylistDir = $config_parms{mp3_playlist_dir};

# this script expect to receive a single function call to control xmms
# and an optional argument

my $RC;
my ( $Cmd, $Arg ) = split( /=/, $ARGV[0] );
$Cmd = lc($Cmd);

if ( !&Xmms_Running ) {
    return &XmmsNotRunning;
}

# the Cmd received will then be pass to xmms
if ( $Cmd ne "status" && $Cmd ne "" ) {
    CMD: {
        if ( $Cmd eq "play" )  { Xmms_Control("Play");  last CMD; }
        if ( $Cmd eq "stop" )  { Xmms_Control("Stop");  last CMD; }
        if ( $Cmd eq "pause" ) { Xmms_Control("pause"); last CMD; }
        if ( $Cmd eq "volume" ) { Xmms_Control( "Volume", $Arg ); last CMD; }
        if ( $Cmd eq "volumeup" )     { Xmms_Control("VolumeUp");   last CMD; }
        if ( $Cmd eq "volumedown" )   { Xmms_Control("VolumeDown"); last CMD; }
        if ( $Cmd eq "random" )       { Xmms_Control("Random");     last CMD; }
        if ( $Cmd eq "nextsong" )     { Xmms_Control("NextSong");   last CMD; }
        if ( $Cmd eq "prevsong" )     { Xmms_Control("PrevSong");   last CMD; }
        if ( $Cmd eq "playlistctrl" ) { return PlaylistCtrl();      last CMD; }
    }
    Xmms::sleep(0.25);
}

#print_log "MP3_WebXmmsCtrl.pl After Cmd parse";

# we create the top part of the window (MP3_Control frame)
my $Song = Xmms_Control("get_playlist_title");
$Song =~ tr/_/ /;    # replace _ by " " to make it clear
my $Volume = Xmms_Control("get_volume");
$Volume = ( int( ( $Volume + 2 ) / 5 ) * 5 )
  ;                  # volume by slice of 5, xmms doesn't change exactly
my $Pos      = Xmms_Control("get_playlist_pos");
my $SongTime = Xmms_Control("get_output_timestr");

return mp3_top( $Pos, $Song, $Volume, $SongTime );

sub mp3_top {

    my ( $Pos, $Song, $Volume, $SongTime ) = @_;
    my $HTTP;
    $HTTP = "
<html><body>
<meta http-equiv='Pragma' content='no-cache'> 
<meta http-equiv='Expires' content='-1'> 
<meta http-equiv='Refresh' content='15;url=/jukebox/MP3_WebXmmsCtrl.pl'>
<base target ='MP3_Control'>
<table width='100%' border='0'>
<tr>
<td><a href='/jukebox/MP3_WebXmmsCtrl.pl?Play'>       <img src='play.gif' border='0'></a></td>
<td><a href='/jukebox/MP3_WebXmmsCtrl.pl?Stop'>       <img src='stop.gif' border='0'></a></td>
<td><a href='/jukebox/MP3_WebXmmsCtrl.pl?Pause'>      <img src='pause.gif' border='0'></a></td>
<td><a href='/jukebox/MP3_WebXmmsCtrl.pl?PrevSong'>   <img src='previous.gif' border='0'></a></td>
<td><a href='/jukebox/MP3_WebXmmsCtrl.pl?NextSong'>   <img src='next.gif' border='0'></a></td>

<FORM action='/jukebox/MP3_WebXmmsCtrl.pl' method='get'>
<td align='right'>
<SELECT name='Volume'  onChange='form.submit()'>
  ";
    my $Value;

    for $Value (
        0,  5,  10, 15, 20, 25, 30, 35, 40, 45, 50, 55,
        60, 65, 70, 75, 80, 85, 90, 95, 100
      )
    {
        if ( $Volume == $Value ) {
            $HTTP = $HTTP . "<option value=\"$Value\" SELECTED>Vol: $Value\n";
        }
        else {
            $HTTP = $HTTP . "<option value=\"$Value\">Vol: $Value\n";
        }
    }

    $HTTP = $HTTP . "
</SELECT>
</td>
</FORM>
<td><a href='/jukebox/MP3_WebXmmsCtrl.pl?VolumeUp'><center><BIG>+</BIG></center></a></td>
<td><a href='/jukebox/MP3_WebXmmsCtrl.pl?VolumeDown'><center><BIG>-</BIG></center></a></td>
</tr></table>

<table width='100%' border='0'>
<td align='left'>$Pos. $Song</td>
<td align='right'>$SongTime</td>
</table>
<HR>
</body>
</html>

EOF
  ";

    return $HTTP;
}

sub NotUsingLinux {

    my $HTTP = "<html><body>";
    $HTTP = $HTTP . "<H1><CENTER>";
    $HTTP = $HTTP . "You need Linux to run this program";
    $HTTP = $HTTP . "With the Xmms-perl module installed";
    $HTTP = $HTTP . "</CENTER></H1>";
    $HTTP = $HTTP . "</body></html>";
    return $HTTP;
}

sub XmmsNotRunning {
    my $HTTP = "<html><body>";
    $HTTP = $HTTP . "<H1><CENTER>";
    $HTTP = $HTTP . "Xmms is not currently running on the system";
    $HTTP = $HTTP . "</CENTER></H1>";
    $HTTP = $HTTP . "</body></html>";
    return $HTTP;
}

# this generate the playlist control frame
# display refreh the playlist loaded in XMMS
# Clear will clear the playlist
# Shuffle will shuffle the current playlist
# everything else is a pointer to a directory containing plaulist (m3u)
# the frame end with the number of song in the playlist, it's a url to refresh the frame

sub PlaylistCtrl {

    my $HTTP = Header();

    # find the available playlist directory,
    # this directory contains playlist specific to this subdirectories
    opendir( DIR, $PlaylistDir ) or return CantOpenDir();
    chdir "$PlaylistDir";

    $HTTP = $HTTP . "<table width='100%' border='0'>\n";
    $HTTP = $HTTP
      . "<td><a href='/jukebox/MP3_WebXmmsPlaylist.pl?Refresh' target=MP3_Playlist><center><BIG> Refresh </BIG></center></td>\n";
    $HTTP = $HTTP
      . "<td><a href='/jukebox/MP3_WebXmmsPlaylist.pl?ClearPlaylist' target=MP3_Playlist><center><BIG> Clear </BIG></center></td>\n";
    $HTTP = $HTTP
      . "<td><a href='/jukebox/MP3_WebXmmsPlaylist.pl?Shuffle' target=MP3_Playlist><center><BIG> Shuffle </BIG></center></td>\n";
    $HTTP = $HTTP
      . "<td><a href='/jukebox/MP3_WebXmmsPlaylist.pl?Sort' target=MP3_Playlist><center><BIG> Sort </BIG></center></td>\n";

    my $file;

    # we create a URL for every subdirectory, they contain the actual playlist
    while ( $file = readdir(DIR) ) {
        if ( -d $file && $file !~ /\./ ) {
            $file =~ tr/_/ /;
            $HTTP = $HTTP
              . "<td><a href='/jukebox/MP3_WebXmmsPlaylist.pl?List=$file' target=MP3_Playlist><center><BIG> $file </BIG></center></td>\n";
        }
    }
    my $PlaylistLength = Xmms_Control("get_playlist_length");
    $HTTP = $HTTP
      . "<td><a href='/jukebox/MP3_WebXmmsCtrl.pl?PlaylistCtrl' target=MP3_PlaylistCtrl> <center><BIG>($PlaylistLength)</BIG></center></a></td>";
    $HTTP = $HTTP . "</table>\n";
    $HTTP = $HTTP . Footer();

    return $HTTP;

    sub CantOpenDir {
        my $HTTP = Header();
        $HTTP = $HTTP . "<H1><CENTER>";
        $HTTP = $HTTP . "I can't open $$PlaylistDir to fetch playlist.";
        $HTTP = $HTTP
          . "Please verify mh.ini for the correct directory namer, under mp3_playlist_dir.";
        $HTTP = $HTTP . "</CENTER></H1>";
        $HTTP = $HTTP . Footer();
        return $HTTP;
    }

    sub Header {
        my $HTTP = "<html><body>\n";
        $HTTP = $HTTP . "<meta http-equiv='Pragma' content='no-cache'>\n";
        $HTTP = $HTTP . "<meta http-equiv='Expires' content='-1'>\n";
        $HTTP = $HTTP
          . "<meta http-equiv='Refresh' content='60;url=/jukebox/MP3_WebXmmsCtrl.pl?PlaylistCtrl'>\n";
        $HTTP = $HTTP . "<base target ='MP3_PlaylistCtrl'>\n";
        return $HTTP;
    }

    sub Footer {
        return "</body></html>\n";
    }

}

#$Log: MP3_WebXmmsCtrl.pl,v $
#Revision 1.3  2004/02/01 19:24:37  winter
# - 2.87 release
#
#Revision 1.5  2002/01/27 01:57:36  gaetan
#Beta 0.1
#/
#
#Revision 1.4  2002/01/12 18:16:43  gaetan
#Version avant de faire une fonction xmms_control
#
#Revision 1.3  2002/01/07 01:17:26  gaetan
#big change, move from xmms-shell to the Xmms perl module
#more change in the display (time etc.)
#create a shuffle simulation tyo workaround the lack of on/off shuffle
#
#$Log: MP3_WebXmmsCtrl.pl,v $
#Revision 1.3  2004/02/01 19:24:37  winter
# - 2.87 release
#
#Revision 1.5  2002/01/27 01:57:36  gaetan
#Beta 0.1
#/
#
#Revision 1.4  2002/01/12 18:16:43  gaetan
#Version avant de faire une fonction xmms_control
#
#Revision 1.3  2002/01/07 01:17:26  gaetan
#big change, move from xmms-shell to the Xmms perl module
#more change in the display (time etc.)
#create a shuffle simulation tyo workaround the lack of on/off shuffle
#
#Revision 1.2  2002/01/02 01:45:31  gaetan
#modif with pulldown for random and volume
#
#Revision 1.1  2002/01/01 20:48:27  gaetan
#Initial revision
#
