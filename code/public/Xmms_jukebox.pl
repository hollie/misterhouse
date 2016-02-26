#Category=Xmms_Jukebox
#$Id$

#This script should create a Category named Xmms_Jukebox
#This will give you a basic jukebox functionality
#You could add as much playlist you want

# You need to create Playlist containing a list of MP3 song
my @Playlist;
$Playlist[1] = "/MP3/playlist/X10/Playlist_1.m3u";
$Playlist[2] = "/MP3/playlist/X10/Playlist_2.m3u";
$Playlist[3] = "/MP3/playlist/X10/Playlist_3.m3u";
$Playlist[4] = "/MP3/playlist/X10/Playlist_4.m3u";

$v_Play = new Voice_Cmd '[Play] song';
$v_Play->set_info("Play song on the jukebox");

$v_Stop   = new Voice_Cmd '[Stop] song';
$v_Pause  = new Voice_Cmd '[Pause] the jukebox';
$v_Random = new Voice_Cmd '[Randomize] the playlist';
$v_Sort   = new Voice_Cmd '[Sort] the playlist';
$v_Next   = new Voice_Cmd '[Next] song';
$v_Prev   = new Voice_Cmd '[Prev] song';
$v_Volume =
  new Voice_Cmd("Set volume to [0,10,20,30,40,50,60,65,70,75,80,85,90,95,100]");
$v_Playlist = new Voice_Cmd("Set Playlist number [1,2,3,4]");
$v_Now      = new Voice_Cmd("[Now] playing");
set_icon $v_Now 'music';

&Xmms_Control("play")  if ( said $v_Play eq "Play" );
&Xmms_Control("stop")  if ( said $v_Stop eq "Stop" );
&Xmms_Control("pause") if ( said $v_Pause eq "Pause" );
&Xmms_Control( "shuffle", "on" )  if ( said $v_Random eq "Randomize" );
&Xmms_Control( "shuffle", "off" ) if ( said $v_Sort eq "Sort" );
&Xmms_Control("nextsong") if ( said $v_Next eq "Next" );
&Xmms_Control("prevsong") if ( said $v_Prev eq "Prev" );

if ( my $volume = said $v_Volume) {
    &Xmms_Control( "volume", $volume );
}

if ( said $v_Playlist ne "" ) {
    my $num = said $v_Playlist;
    Xmms_Control("clear");
    speak "Loading playlist $num";
    if ( Xmms_Control( "load_playlist_file", "$Playlist[$num]" ) ) {
        speak "done";
        sleep 1;
        Xmms_Control("play");
    }
    else {
        speak "Problem loading playlist";
    }
}

if ( said $v_Now eq "Now" ) {
    print_log "Now Playing " . Xmms_Control("get_playlist_title");
}

#$Log: Xmms_jukebox.pl,v $
#Revision 1.3  2004/02/01 19:24:20  winter
# - 2.87 release
#
