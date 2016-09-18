# Category=TV and Music

# From Douglas Nakakihara  on 6/17/00
#
# I've been wanting to write my own MP3 player for Misterhouse for a long
#time. I've finally done it and have got it to the point that (I think ;-)
#ppl can actually use it.
#
# Key features:
# *Fast response
# *Precise volume and track-skip control
# *Can directly set random play on or off
# *Will tell you the MP3 ID tag info (or filename, if not avail)
# *Will show a GIF/JPG image based on MP3 filename
# *Supports WinAmp m3u playlist files and can associate that filetype
# *Playlist file can point to a directory (I love this feature)
# *Built-in m3u playlist editor (I couldn't help myself!)
# *Not a bad MP3 player by itself IMHO
# *Requires MS Mediaplayer 6.x installed (Haven't tested ver 7 yet)
# *Sample PERL script included in zip

# Download from www.dougworld.com

#
# Define the following in your mh.private.ini
# mp3_dir=e:/data/playlists
# mp3_extention=m3u
# mp3_program=e:/mh/bin/mrMP3.exe
# (Obviously, substitute your paths ;-)
#
# I copy the mrMP3.exe and mrMP3.ini to the mh\bin directory,
# but that's probably not really necessary.
#
# Here are some of the valid mrMP3 parms:
#
#  volume=65
#  autoplay
#  picture
#  pictop
#  datapath=e:\mh\data\doug
#  listpath=e:\data\playlists
#  dirpath=d:\mp3s
#
# You will need to use the datapath parm to point it to your mh.ini data_dir directory
#

$v_mp3_control = new Voice_Cmd(
    "music [Play,Stop,Pause,Next Song,"
      . "Previous Song,Volume up,Volume down,"
      . "Randomize on,Randomize off]",
    ""
);

if ( $state = said $v_mp3_control) {

    # Start mrMP3, if it is not already running
    &sendkeys_find_window( 'mr_MP3', $config_parms{mp3_program} );

    if ( $state eq "Play" ) {
        fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "PLAY" );
    }
    if ( $state eq "Stop" ) {
        fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "STOP" );
    }
    if ( $state eq "Pause" ) {
        fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "PAUSE" );
    }
    if ( $state eq "Next Song" ) {
        fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "NEXT" );
    }
    if ( $state eq "Previous Song" ) {
        fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "PREV" );
    }
    if ( $state eq "Randomize on" ) {
        fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "RAND ON" );
        speak "randomize on";
    }
    if ( $state eq "Randomize off" ) {
        fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "RAND OFF" );
        speak "randomize off";
    }
    if ( $state eq "Volume up" ) {
        fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "VOL UP" );
        speak "volume up";
    }
    if ( $state eq "Volume down" ) {
        fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "VOL DOWN" );
        speak "volume down";
    }

    #For some unknown reason, things don't work right unless
    this is here !print_log "MRmp3 set to $state";

}

# Allows multi-song skip 1 to 10
$v_mp3_control3 = new Voice_Cmd( "music skip [1,2,3,4,5,6,7,8,9,10]", "" );

if ( $state = said $v_mp3_control3) {

    # Start mrMP3, if it is not already running
    &sendkeys_find_window( 'mr_MP3', $config_parms{mp3_program} );

    speak "skip $state";
    fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "SKIP $state" );
}

# Allows multi-song back 1 to 10
$v_mp3_control4 = new Voice_Cmd( "music back [1,2,3,4,5,6,7,8,9,10]", "" );

if ( $state = said $v_mp3_control4) {

    # Start mrMP3, if it is not already running
    &sendkeys_find_window( 'mr_MP3', $config_parms{mp3_program} );

    speak "back $state";
    fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "SKIP -$state" );
}

# Allows for volume 0 to 100 by 10
$v_mp3_control5 = new Voice_Cmd(
    "music volume
[0,10,20,30,40,50,60,70,80,90,100]", ""
);

if ( $state = said $v_mp3_control5) {

    # Start mrMP3, if it is not already running
    &sendkeys_find_window( 'mr_MP3', $config_parms{mp3_program} );

    speak "volume $state";
    fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "VOL $state" );
}

# Allow for loading playlists
# noloop=start      This directive allows this code to be run on
startup / reload my $mp3names = &load_playlist;

# noloop=stop
$v_play_music = new Voice_Cmd( "select [$mp3names]", "" );

if ( $state = said $v_play_music) {

    speak "$state selected.";

    # Start mrMP3, if it is not already running
    &sendkeys_find_window( 'mr_MP3', $config_parms{mp3_program} );

    print_log "Loading mp3 playlist: $state";
    fileit(
        "$config_parms{data_dir}/mrMP3_cmd.dat", "LIST
$config_parms{mp3_dir}\\$state.$config_parms{mp3_extention}"
    );

}

$v_whatisthis = new Voice_Cmd( "[What, Who] is playing", "" );
$f_playlist_state = new File_Item("$config_parms{data_dir}/mrMP3_play.dat");
if ( $state = said $v_whatisthis) {
    fileit( "$config_parms{data_dir}/mrMP3_cmd.dat", "PAUSE" );
    select undef, undef, undef, 1;
    my $msg = read_all $f_playlist_state;
    speak("$msg.");
}

sub load_playlist {

    my $mp3names;
    opendir( DIR, $config_parms{mp3_dir} ) or print "Error in opening mp3_dir
$config_parms{mp3_dir}: $!\n";
    print "Reading $config_parms{mp3_dir} for $config_parms{mp3_extention}
files\n";
    for ( readdir(DIR) ) {
        next unless /(\S+)\.(\S+)/;
        next unless lc $2 eq lc $config_parms{mp3_extention};

        #  print "name=$1 ext=$2 match $config_parms{mp3_extention}\n";
        $mp3names .= $1 . ",";
    }
    print "names=$mp3names\n";
    return $mp3names;

}

