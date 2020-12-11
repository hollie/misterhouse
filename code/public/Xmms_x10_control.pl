#Category=Remote_Jukebox
#$Id$

# This script create a remote control interface to my  MP3 Jukebox
# My system use a TM751 X10 transceiver to receive the remote signal
# And a palmpad remote control HR21 from X10 to send the command
# I set the housecode to J
# I use 8 button, but could easily be extend to 16
# I use the On and Off Value for every button
# For button 2 (ON/OFF)
# The ON code is XJ2JJ, this will call the play function of Xmms
# The Off code is XJ2JK

# You need to create Playlist (m3u file) containing a list of MP3 song
# playlist are defined on button 6 and 7  ( 4 differents )
my $Playlist1 = "/MP3/playlist/X10/Playlist_1.m3u";
my $Playlist2 = "/MP3/playlist/X10/Playlist_2.m3u";
my $Playlist3 = "/MP3/playlist/X10/Playlist_3.m3u";
my $Playlist4 = "/MP3/playlist/X10/Playlist_4.m3u";

# remote button 2
$x10_jukebox_play = new Serial_Item('XJ2JJ');
$x10_jukebox_stop = new Serial_Item('XJ2JK');

# remote button 3
$x10_jukebox_pause  = new Serial_Item('XJ3JJ');
$x10_jukebox_random = new Serial_Item('XJ3JK');

# remote button 4
$x10_jukebox_next = new Serial_Item('XJ4JJ');
$x10_jukebox_prev = new Serial_Item('XJ4JK');

# remote button 5
$x10_jukebox_volume_up   = new Serial_Item('XJ5JJ');
$x10_jukebox_volume_down = new Serial_Item('XJ5JK');

# remote button 6
$x10_jukebox_playlist_1 = new Serial_Item('XJ6JJ');
$x10_jukebox_playlist_2 = new Serial_Item('XJ6JK');

# remote button 7
$x10_jukebox_playlist_3 = new Serial_Item('XJ7JJ');
$x10_jukebox_playlist_4 = new Serial_Item('XJ7JK');

&Xmms_Control("stop")       if state_now $x10_jukebox_stop;
&Xmms_Control("play")       if state_now $x10_jukebox_play;
&Xmms_Control("pause")      if state_now $x10_jukebox_pause;
&Xmms_Control("random")     if state_now $x10_jukebox_random;
&Xmms_Control("NextSong")   if state_now $x10_jukebox_next;
&Xmms_Control("PrevSong")   if state_now $x10_jukebox_prev;
&Xmms_Control("VolumeUp")   if state_now $x10_jukebox_volume_up;
&Xmms_Control("VolumeDown") if state_now $x10_jukebox_volume_down;

if ( state_now $x10_jukebox_playlist_1) {
    Xmms_Control("clear");
    speak "Loading playlist 1";
    if ( Xmms_Control( "load_playlist_file", "$Playlist1" ) ) {
        speak "done";
        sleep 1;
        Xmms_Control("play");
    }
    else {
        speak "Problem loading playlist";
    }
}

if ( state_now $x10_jukebox_playlist_2) {
    Xmms_Control("clear");
    speak "Loading playlist 2";
    if ( Xmms_Control( "load_playlist_file", "$Playlist2" ) ) {
        speak "done";
        sleep 1;
        Xmms_Control("play");
    }
    else {
        speak "Problem loading playlist";
    }
}

if ( state_now $x10_jukebox_playlist_3) {
    Xmms_Control("clear");
    speak "Loading playlist 3";
    if ( Xmms_Control( "load_playlist_file", "$Playlist3" ) ) {
        speak "done";
        sleep 1;
        Xmms_Control("play");
    }
    else {
        speak "Problem loading playlist";
    }
}

if ( state_now $x10_jukebox_playlist_4) {
    Xmms_Control("clear");
    speak "Loading playlist 4";
    if ( Xmms_Control( "load_playlist_file", "$Playlist4" ) ) {
        speak "done";
        sleep 1;
        Xmms_Control("play");
    }
    else {
        speak "Problem loading playlist";
    }
}

#$Log: Xmms_x10_control.pl,v $
#Revision 1.3  2004/02/01 19:24:20  winter
# - 2.87 release
#
