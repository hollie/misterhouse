
# this script will display the current mp3 playlist,
# and will also display the playlist file (m3u).
# this work with closely with MP3_WebCtrl.pl. All the call
# to this script are done via the other script.
# This script will generate specific call playlist.

use strict;

my $RC;
my ( $Cmd, $arg ) = split( /=/, $ARGV[0] );
$Cmd = ( $Cmd eq "" ) ? "refresh" : $Cmd;
$Cmd = lc($Cmd);

my $HTTP = "";
$HTTP = Header();

if ( $Cmd eq "refresh" ) {
    DisplayPlaylist();
}

# jump receive the playlist number to jump to
if ( $Cmd eq "jump" ) {
    &mp3_set_playlist_pos( $arg - 1 );
    DisplayPlaylist();
}

# flush the playlist
if ( $Cmd eq "clearplaylist" ) {
    &mp3_clear();
    DisplayPlaylist();
}

# this will display all the m3u files contained in $PlayListDir/$arg
# where argument is a directory under $config_parms{mp3_playlist_dir}
# Ex: a Album, Artist, Various, Rock directory
# all of them contains m3u file.
# there is a sort done on the dir content, to ease the search

if ( $Cmd eq "list" ) {
    my ( $playlists, %playfiles ) = &mp3_playlists;
    for my $playlist ( sort keys %playfiles ) {
        my $DisplayName = $playlist;
        $DisplayName =~ tr/_/ /;
        $DisplayName =~ s/-/ - /g;
        $DisplayName =~ s/.m3u$//;
        $HTTP = $HTTP
          . "<td><a href=/music/MP3_WebPlaylist.pl?Add=$playfiles{$playlist} target=MP3_Playlist>$DisplayName</a></td><tr>\n";
    }
    $HTTP = $HTTP . "</table>\n";
}

# this will add new song, from the choosen playlist
if ( $Cmd eq "add" ) {
    &mp3_queue($arg);
}

$HTTP = $HTTP . Footer();

return $HTTP;

# generate a table containing the playlist and a jump call to the choosen song
sub DisplayPlaylist {
    my $titles = &mp3_get_playlist();
    if ( @$titles == 0 ) {
        $HTTP = $HTTP
          . "<H1><CENTER>There is no track in the playlist</CENTER></H1>\n";
    }
    else {
        $HTTP = $HTTP . "<table width=100% borders=0>\n";
        my $pos = 1;

        foreach my $item (@$titles) {
            my $Time = &mp3_get_playlist_timestr( $pos - 1 );
            my $Str =
              "                                                            ";
            $Str = substr( "$pos. $item", 1 );
            $HTTP = $HTTP
              . "<td><a href=/music/MP3_WebPlaylist.pl?Jump=$pos target=MP3_Playlist>$pos. $item</a><right> .... $Time</right></td><tr>\n";
            $pos++;
        }
        $HTTP = $HTTP . "</table>\n";
    }
}

#general header file
sub Header {
    my $HTTP = "<html><body>\n";
    $HTTP = $HTTP . "<meta http-equiv='Pragma' content='no-cache'>\n";
    $HTTP = $HTTP . "<meta http-equiv='Expires' content='-1'>\n";
    $HTTP = $HTTP
      . "<meta http-equiv='Refresh' content='60;url=/music/MP3_WebPlaylist.pl'>\n";
    $HTTP = $HTTP . "<base target ='MP3_Playlist'>\n";
    return $HTTP;
}

sub Footer {
    return "</body></html>";
}

