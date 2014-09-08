# Category=Music
#
# This version of mp3_control controls the xmms MP3 player for Linux. It handles playlists and the
# operation of the mp3 player. It now also handles separate songs. It requires Xmms::Remote
#
# xmms can be found at http://www.xmms.org/ and is frequently installed by default in many distros such as Redhat.
#
# Author: Richard Phillips, god__AT__ninkasi__DOT___com
# Liberally hacked from the code originally written by Dave Lounsberry for the GQmpeg player - thanks and kudos, Dave.
# V1.0 - 25 Dec 2001 - created
# V1.1 - 26 Dec 2001 - changed to use xmms-shell to enable volume control, add repeat and shuffle options and also
# support the buttons in the ia5 jukebox.
# V1.2 - 6 Jan 2002 - added in code to provide info on what's currently playing - you need to load up Xmms::Remote
# but you'll already have that if you're using xmms-shell. I guess if I could be bothered I'd change the script to
# avoid using xmms-shell at all, but heck - why fix it if it ain't broke...
# V1.3 - 20 Jan 2002 - updated and improved so that when using the slightly modified "mp3_playlist_xmms.pl" it
# is now able to load playlists from the main ia5 jukebox as well as select individual songs. Hint - to clear a playlist
# you need to go into browse music categories and select the "clear mp3 playlist" button. To be able to do this from the
# jukebox, just create a playlist called - say - clearplaylist.m3u and save it in your playlist directory, then you can
# clear the playlist by selecting this file...... sneaky, but it works. Oh, remember that after adding any new mp3 files
# you need to go into the browse/music/build mp3 database.
# V1.4 - 14 August added global variable "NowPlaying" so I can see that in the status line on the ia5 web page.
# To use this, add "&playing&" into the html_status_line settings in mh.ini/mh.private.ini
# Revision by Brian Rudy (brudyNO@SPAMpraecogito.com)
# V1.5 - 6 Jan 2003 - Replaced all external xmms-shell calls with native Xmms::Remote routines.
# V1.6 - 31 July 2003 [Richard Phillips] - added in code to start xmms if not loaded

#
# The following entries are required in mh.ini or mh.private.ini
#
# where xmms is installed
#   mp3_program=/usr/bin/xmms
# xmms playlist directory
#   mp3_playlist_dir=/mnt/data/playlists
# playlist extension
#   mp3_playlist_ext=m3u
# where your mp3 files live
#   mp3_file_dir=/mnt/data/music
# of course all mp3 files have a mp3 extension
#   mp3_file_ext=mp3
use Xmms;
use Xmms::Remote ();

#use Getopt::Std;

my $playcmd;

$v_mp3_control_state = new Voice_Cmd("MP3 Control [off,on]");
if ( $state = said $v_mp3_control_state) {
    $Save{mp3_mode} = $state;
    if ( $state eq 'off' ) {
        $remote->quit;
    }
    else {
        exec $config_parms{mp3_program} unless my $Pid = fork;
    }
    print_log "MP3 control now $state.";
    speak "MP3 control now $state.";
}

$v_mp3_control_cmd = new Voice_Cmd(
    "Set the house mp3 player to [Play,Stop,Pause,Restart,Next Song,Previous Song,Volume Down,Volume Up,Shuffle On,Shuffle Off,Repeat On,Repeat Off]"
);

# if xmms is not running, we will start it
# have we defined mp3_program
my $mp3_program = $main::config_parms{mp3_program};
if ( $mp3_program eq "" ) {
    print_log "mp3_program not defined";
    return 0;
}
my $XmmsStatus;
unless ( $remote->is_running ) {
    print_log "$mp3_program is not running, attempting to start";
    `$mp3_program >/dev/null 2>/dev/null&`;

    #sleep 1 sec to let the process start
    sleep 1;
    $XmmsStatus = `/sbin/pidof $mp3_program`;
    chop $XmmsStatus;
    if ( $XmmsStatus eq "" ) {
        print_log "Can't start $mp3_program";
        exit 1;
    }
    print_log "$mp3_program started";
}
if ( $state = said $v_mp3_control_cmd) {
    if ( $state eq 'Play' ) {
        $remote->play;
    }
    elsif ( $state eq 'Stop' ) {
        $remote->stop;
    }
    elsif ( $state eq 'Pause' ) {
        $remote->pause;
    }
    elsif ( $state eq 'Restart' ) {
        $remote->set_playlist_pos(0);
        Xmms::sleep(0.25);
        $remote->play;
    }
    elsif ( $state eq 'Next Song' ) {
        $remote->playlist_next;
    }
    elsif ( $state eq 'Previous Song' ) {
        $remote->playlist_prev;
    }
    elsif ( $state eq 'Volume Down' ) {
        my $vol = $remote->get_main_volume;
        $vol = $vol - 10;
        if ( $vol < 0 ) {
            $vol = 0;
        }
        $remote->set_main_volume($vol);
    }
    elsif ( $state eq 'Volume Up' ) {
        my $vol = $remote->get_main_volume;
        $vol = $vol + 10;
        if ( $vol > 100 ) {
            $vol = 100;
        }
        $remote->set_main_volume($vol);
    }
    elsif ( $state eq 'Shuffle On' ) {
        my $shufflestat = $remote->is_shuffle;
        if ( $shufflestat == 0 ) {
            $remote->toggle_shuffle;
        }
    }
    elsif ( $state eq 'Shuffle Off' ) {
        my $shufflestat = $remote->is_shuffle;
        if ( $shufflestat == 1 ) {
            $remote->toggle_shuffle;
        }
    }
    elsif ( $state eq 'Repeat On' ) {
        my $repeatstat = $remote->is_repeat;
        if ( $repeatstat == 0 ) {
            $remote->toggle_repeat;
        }
    }
    elsif ( $state eq 'Repeat Off' ) {
        my $repeatstat = $remote->is_repeat;
        if ( $repeatstat == 1 ) {
            $remote->toggle_repeat;
        }
    }

    print_log "mp3 player set to " . said $v_mp3_control_cmd;
}

$v_play_clear_music = new Voice_Cmd("Clear mp3 playlist");
if ( $state = said $v_play_clear_music) {
    $remote->playlist_clear;
    print_log "Cleared mp3 player playlist";
}

# noloop=start      This directive allows this code to be run on startup/reload
my $mp3playlist = &load_mp3_file_list( $config_parms{mp3_playlist_dir},
    $config_parms{mp3_playlist_ext} );

# noloop=stop

$v_play_music = new Voice_Cmd("Add MP3 playlist [$mp3playlist]");
if ( $state = said $v_play_music) {
    my $playlist = $state;
    $playlist =~ s/[_\-.]/ /g;
    print_log "Adding mp3 playlist: $playlist";
    speak("Added MP3 playlist $playlist.");
    $remote->playlist_clear;
    Xmms::sleep(0.25);
    $remote->playlist(
        [
                $config_parms{mp3_playlist_dir} . "/"
              . "$playlist" . "."
              . $config_parms{mp3_playlist_ext}
        ]
    );

    #$Save{mp3_playlist} = $playlist;
    print_log "mp3 player set to playlist $playlist";
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

# The following returns the current song being played
my $session = 0;
my $remote  = Xmms::Remote->new($session);
$v_what_playing = new Voice_Cmd('What is now playing');
if ( $state = said $v_what_playing) {
    my $mp3playing =
      ${ $remote->get_playlist_titles }[ $remote->get_playlist_pos ];
    speak $mp3playing;
}

$Save{NowPlaying} =
  ${ $remote->get_playlist_titles }[ $remote->get_playlist_pos ]
  if new_second 30;

#$v_what_playlist = new Voice_Cmd('Show playlist');
#if ($state = said $v_what_playlist) {
##    $playcmd = $config_parms{mp3_program_control} . " -e playlist";
##    run "$playcmd";
## this is intended to show a listing of songs in the current playlist..... haven't quite worked it out yet though....
#	my $mp3playing=@{$remote->get_playlist_titles};
#	speak $mp3playing;
#}

