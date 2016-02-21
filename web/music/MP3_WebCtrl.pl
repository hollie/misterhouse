
# this script expect to receive a single function call to control xmms or winamp
# and an optional argument

my $RC;
my ( $Cmd, $Arg ) = split( /=/, $ARGV[0] );
$Cmd = lc($Cmd);

if ( !&mp3_running() ) {
    return &NotRunning;
}

# the Cmd received will then be pass to mp3 player
if ( $Cmd ne "status" && $Cmd ne "" ) {
    CMD: {
        if ( $Cmd eq "play" )  { &mp3_control("Play");  last CMD; }
        if ( $Cmd eq "stop" )  { &mp3_control("Stop");  last CMD; }
        if ( $Cmd eq "pause" ) { &mp3_control("pause"); last CMD; }
        if ( $Cmd eq "volume" ) { &mp3_control( "Volume", $Arg ); last CMD; }
        if ( $Cmd eq "volumeup" )     { &mp3_control("VolumeUp");   last CMD; }
        if ( $Cmd eq "volumedown" )   { &mp3_control("VolumeDown"); last CMD; }
        if ( $Cmd eq "random" )       { &mp3_control("Random");     last CMD; }
        if ( $Cmd eq "nextsong" )     { &mp3_control("NextSong");   last CMD; }
        if ( $Cmd eq "prevsong" )     { &mp3_control("PrevSong");   last CMD; }
        if ( $Cmd eq "playlistctrl" ) { return PlaylistCtrl();      last CMD; }
    }
}

#print_log "MP3_WebCtrl.pl After Cmd parse";

# we create the top part of the window (MP3_Control frame)
my $Song = &mp3_get_playlist_title();
$Song =~ tr/_/ /;    # replace _ by " " to make it clear
my $Volume = &mp3_get_volume();
$Volume = ( int( ( $Volume + 2 ) / 5 ) * 5 )
  ;                  # volume by slice of 5, xmms doesn't change exactly
my $Pos      = &mp3_get_playlist_pos();
my $SongTime = &mp3_get_output_timestr();

return mp3_top( $Pos, $Song, $Volume, $SongTime );

sub mp3_top {

    my ( $Pos, $Song, $Volume, $SongTime ) = @_;
    my $HTTP;
    $HTTP = "
<html><body>
<meta http-equiv='Pragma' content='no-cache'> 
<meta http-equiv='Expires' content='-1'> 
<meta http-equiv='Refresh' content='15;url=/music/MP3_WebCtrl.pl'>
<base target ='MP3_Control'>
<table width='100%' border='0'>
<tr>
<td><a href='/music/MP3_WebCtrl.pl?Play'>       <img src='play.gif' border='0'></a></td>
<td><a href='/music/MP3_WebCtrl.pl?Stop'>       <img src='stop.gif' border='0'></a></td>
<td><a href='/music/MP3_WebCtrl.pl?Pause'>      <img src='pause.gif' border='0'></a></td>
<td><a href='/music/MP3_WebCtrl.pl?PrevSong'>   <img src='previous.gif' border='0'></a></td>
<td><a href='/music/MP3_WebCtrl.pl?NextSong'>   <img src='next.gif' border='0'></a></td>

<FORM action='/music/MP3_WebCtrl.pl' method='get'>
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
<td><a href='/music/MP3_WebCtrl.pl?VolumeUp'><center><BIG>+</BIG></center></a></td>
<td><a href='/music/MP3_WebCtrl.pl?VolumeDown'><center><BIG>-</BIG></center></a></td>
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

sub NotRunning {
    my $HTTP = "<html><body>";
    $HTTP = $HTTP . "<H1><CENTER>";
    $HTTP = $HTTP . "The mp3 player is not currently running on the system";
    $HTTP = $HTTP . "</CENTER></H1>";
    $HTTP = $HTTP . "</body></html>";
    return $HTTP;
}

# this generate the playlist control frame
# display refreh the playlist loaded
# Clear will clear the playlist
# Shuffle will shuffle the current playlist
# everything else is a pointer to a directory containing plaulist (m3u)
# the frame end with the number of song in the playlist, it's a url to refresh the frame

sub PlaylistCtrl {

    my $HTTP = Header();

    $HTTP = $HTTP . "<table width='100%' border='0'>\n";
    $HTTP = $HTTP
      . "<td><a href='/music/MP3_WebPlaylist.pl?Refresh' target=MP3_Playlist><center><BIG> Refresh </BIG></center></td>\n";
    $HTTP = $HTTP
      . "<td><a href='/music/MP3_WebPlaylist.pl?ClearPlaylist' target=MP3_Playlist><center><BIG> Clear </BIG></center></td>\n";
    $HTTP = $HTTP
      . "<td><a href='/music/MP3_WebPlaylist.pl?Shuffle' target=MP3_Playlist><center><BIG> Shuffle </BIG></center></td>\n";
    $HTTP = $HTTP
      . "<td><a href='/music/MP3_WebPlaylist.pl?Sort' target=MP3_Playlist><center><BIG> Sort </BIG></center></td>\n";

    my ( $playlists, %playfiles ) = &mp3_playlists;
    for my $playlist ( sort keys %playfiles ) {
        $HTTP = $HTTP
          . "<td><a href='/music/MP3_WebPlaylist.pl?List=$playlist' target=MP3_Playlist><center><BIG> $playlist </BIG></center></td>\n";
    }
    my $PlaylistLength = &mp3_get_playlist_length();
    $HTTP = $HTTP
      . "<td><a href='/music/MP3_WebCtrl.pl?PlaylistCtrl' target=MP3_PlaylistCtrl> <center><BIG>($PlaylistLength)</BIG></center></a></td>";
    $HTTP = $HTTP . "</table>\n";
    $HTTP = $HTTP . Footer();

    return $HTTP;

    sub Header {
        my $HTTP = "<html><body>\n";
        $HTTP = $HTTP . "<meta http-equiv='Pragma' content='no-cache'>\n";
        $HTTP = $HTTP . "<meta http-equiv='Expires' content='-1'>\n";
        $HTTP = $HTTP
          . "<meta http-equiv='Refresh' content='60;url=/music/MP3_WebCtrl.pl?PlaylistCtrl'>\n";
        $HTTP = $HTTP . "<base target ='MP3_PlaylistCtrl'>\n";
        return $HTTP;
    }

    sub Footer {
        return "</body></html>\n";
    }

}
