# Category=Music
#
# This version of mp3_control only controls the gqmpeg MP3 player for Linux.
# GQmpeg can be found at http://www.geocities.com/SiliconValley/Haven/5235/index.html
# It only handles playlists and the operation of the mp3 player. It does not handle
# separate songs.
#
# Author: Dave Lounsberry, dlounsberry@kc.rr.com
#
# The following entries are required in mh.ini or mh.private.ini
#       # whereever gqmpeg is installed
#   mp3_program=/usr/local/bin/gqmpeg
#           # gqmpeg saves playlists in $HOME/.gqmpeg/playlists directory (by default)
#   mp3_playlist_dir=/home/dbl/.gqmpeg/playlists
#       # gqmpeg saves playlists with and .gqmpeg extension (by default)
#   mp3_playlist_ext=gqmpeg
#           # where are your mp3 files
#   mp3_file_dir=/home/dbl/.pan/download
#           # of course all mp3 files have a mp3 extension
#   mp3_file_ext=mp3

my $playcmd;
my %gqmpeg_arguments = (
    'Play'          => '-p',
    'Stop'          => '-s',
    'Restart'       => '-p',
    'Pause'         => '-ps',
    'Next Song'     => '-n',
    'Previous Song' => '-b'
);

$v_mp3_control_state = new Voice_Cmd("MP3 Control [off,on]");
if ( $state = said $v_mp3_control_state) {
    $Save{mp3_mode} = $state;
    print_log "MP3 control now $state.";
    speak "MP3 control now $state.";
}

$v_mp3_control_cmd = new Voice_Cmd(
    "Set mp3 player to [Play,Stop,Pause,Restart,Next Song,Previous Song]");
if ( $state = said $v_mp3_control_cmd) {
    run "$config_parms{mp3_program} $gqmpeg_arguments{$state}";
    $state = $gqmpeg_arguments{$state} if $gqmpeg_arguments{$state};
    print_log "mp3 player set to " . said $v_mp3_control_cmd;
}

$v_play_clear_music = new Voice_Cmd("Clear mp3 playlist");
if ( $state = said $v_play_clear_music) {
    $playcmd = $config_parms{mp3_program} . " -plclr ";
    run "$playcmd ";
    print_log "Cleared mp3 player playlist";
}

# noloop=start      This directive allows this code to be run on startup/reload
my $mp3playlist = &load_mp3_file_list( $config_parms{mp3_playlist_dir},
    $config_parms{mp3_playlist_ext} );

# noloop=stop

$v_play_music = new Voice_Cmd("Append MP3 playlist [$mp3playlist]");
if ( $state = said $v_play_music) {
    my $playlist = $state;
    $playlist =~ s/[_\-.]/ /g;
    print_log "Loading mp3 playlist: $playlist";
    speak("Appended MP3 playlist $playlist.");

    # The play button is a toggle so if it is not playing then it won't start when you select
    # a new or add a playlist. If you put a -p to start it playing, it will stop if it is
    # already playing. But, stop is not a toggle and it resets the play toggle. So.... I stop it
    # and start it to make sure it is playing. Hmmm
    $playcmd =
        $config_parms{mp3_program}
      . " -plappend "
      . $config_parms{mp3_playlist_dir} . "/"
      . $state . "."
      . $config_parms{mp3_playlist_ext} . "; "
      . $config_parms{mp3_program}
      . " -s -p";
    print_log "mp3 player set to playlist $playlist";
    print_log "playcmd=$playcmd";
    run "$playcmd";
}

sub load_mp3_file_list {
    my ( $dir, $extention ) = @_;
    my $mp3names;

    opendir( DIR, $dir ) or print "Error in opening mp3_dir $dir: $!\n";
    print "Reading $dir for $extention files\n";
    for ( readdir(DIR) ) {
        next unless /(\S+)\.(\S+)/;
        $mp3names .= $1 . ",";
    }
    return $mp3names;
}
