#$Id$

# this script will display the current Xmms playlist,
# and will also display the playlist file (m3u).
# this work with closely with MP3_WebXmmsCtrl.pl. All the call
# to this script are done via the other script.
# This script will generate specific call xmms playlist.

use strict;
my $PlayListDir = $config_parms{mp3_playlist_dir};

# Need the Xmms-Perl module to control the jukebox
use Xmms;
use Xmms::Remote();
my $remote = Xmms::Remote->new;

my $RC;
my ( $Cmd, $arg ) = split( /=/, $ARGV[0] );
$Cmd = ( $Cmd eq "" ) ? "refresh" : $Cmd;
$Cmd = lc($Cmd);

my ( @LIST, $item );

my $HTTP = "";
$HTTP = Header();

if ( $Cmd eq "refresh" ) {
    DisplayPlaylist();
}

# jump receive the playlist number to jump to
if ( $Cmd eq "jump" ) {
    Xmms_Control( "set_playlist_pos", $arg - 1 );
    DisplayPlaylist();
}

# flush the playlist
if ( $Cmd eq "clearplaylist" ) {
    Xmms_Control("clear");
    DisplayPlaylist();
}

# this will display all the m3u files contained in $PlayListDir/$arg
# where argument is a directory under $config_parms{mp3_playlist_dir}
# Ex: a Album, Artist, Various, Rock directory
# all of them contains m3u file.
# there is a sort done on the dir content, to ease the search

if ( $Cmd eq "list" ) {
    my $File;
    my @LIST;
    my @SORTLIST;
    opendir( DIR, "$PlayListDir/$arg" ) or return CantOpenDir();
    chdir "$PlayListDir/$arg";
    $HTTP = $HTTP . "<table width=100% borders=0>\n";
    while ( $File = readdir(DIR) ) { push @LIST, $File; }
    @SORTLIST = sort @LIST;

    foreach $File (@SORTLIST) {
        if ( -f $File && $File =~ /m3u/ ) {
            my $DisplayName = $File;
            $DisplayName =~ tr/_/ /;
            $DisplayName =~ s/-/ - /g;
            $DisplayName =~ s/.m3u$//;
            $HTTP = $HTTP
              . "<td><a href=/jukebox/MP3_WebXmmsPlaylist.pl?Add=$arg/$File target=MP3_Playlist>$DisplayName</a></td><tr>\n";
        }
    }
    $HTTP = $HTTP . "</table>\n";
}

# this will add new song, from the choosen playlist
if ( $Cmd eq "add" ) {
    if ( Xmms_Control( "load_playlist_file", "$PlayListDir\/$arg" ) ) {
        DisplayPlaylist();
    }
    else {
        return CantOpenDir();
    }
}

# the xmms API doesn't allow us to get the shuffle status, so I randomize
# the current playlist, to simulate a shuffle
#
if ( $Cmd eq "shuffle" ) {
    Xmms_Control( "shuffle", "on" );
    DisplayPlaylist();
}

if ( $Cmd eq "sort" ) {
    Xmms_Control( "shuffle", "off" );
    DisplayPlaylist();
}

$HTTP = $HTTP . Footer();

return $HTTP;

# generate a table containing the playlist and a jump call to the choosen song
sub DisplayPlaylist {
    my $LIST = Xmms_Control("get_playlist_titles");
    if ( @$LIST == 0 ) {
        $HTTP = $HTTP
          . "<H1><CENTER>There is no track in the playlist</CENTER></H1>\n";
    }
    else {
        $HTTP = $HTTP . "<table width=100% borders=0>\n";
        my $pos = 1;

        foreach $item (@$LIST) {
            my $Time = Xmms_Control( "get_playlist_timestr", $pos - 1 );
            my $Str =
              "                                                            ";
            $Str = substr( "$pos. $item", 1 );
            $HTTP = $HTTP
              . "<td><a href=/jukebox/MP3_WebXmmsPlaylist.pl?Jump=$pos target=MP3_Playlist>$pos. $item</a><right> .... $Time</right></td><tr>\n";
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
      . "<meta http-equiv='Refresh' content='60;url=/jukebox/MP3_WebXmmsPlaylist.pl'>\n";
    $HTTP = $HTTP . "<base target ='MP3_Playlist'>\n";
    return $HTTP;
}

sub Footer {
    return "</body></html>";
}

sub CantOpenDir {
    $HTTP = $HTTP . "<H1><CENTER>";
    $HTTP = $HTTP . "I can't open $PlayListDir/$arg to fetch playlist.";
    $HTTP = $HTTP . "</CENTER></H1>";
    $HTTP = $HTTP . Footer();
    return $HTTP;
}

#$Log: MP3_WebXmmsPlaylist.pl,v $
#Revision 1.3  2004/02/01 19:24:37  winter
# - 2.87 release
#
#Revision 1.3  2002/01/27 01:57:45  gaetan
#Beta 0.1
#
#Revision 1.2  2002/01/12 18:17:08  gaetan
#Version avant de faire une fonction xmms_control
#
#Revision 1.1  2002/01/07 01:19:18  gaetan
#Initial revision
#
