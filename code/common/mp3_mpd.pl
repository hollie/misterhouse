
# Category=Music

# $Date$
# $Revision$

#@ This script controls the MPD Music Player Daemon for Linux. It handles operation of the mp3 player. <br />
#@ Enable mp3.pl to manage the MP3 database.<br />
#@ This script requires Audio::MPD.<br />
#@ Set mp3_program to where mpd is installed.  For example,<br />
#@   <pre>mp3_program=/usr/bin/mpd</pre>
#@ Make sure you have mp3_dir set so MPD knows where your Music files are. Example:<br />
#@   <pre>mp3_dir=/home/mh/music</pre>
#@ Currently mp3_mpd.pl requires a subdirectory in your mp3_dir called "playlists" and a <br />
#@ symbolic link created to mp3_search_results.m3u in your data dir<br />
#@   E.g. <pre>/home/mh/music/playlists</pre>and
#@ <pre>/home/mh/music/playlists/mp3_search_results.m3u -> /home/mh/data/mp3_search_results.m3u</pre>
#@ <strong>Please Note:</strong> If MPD dies, this script will keep attempting to start it until it successfully starts.<br />
#@ If MPD is not running when Misterhouse is started, it will be started automatically<br />

=begin comment

 mp3_mpd.pl

 V1.0 Taken mp3 control code from mp3_xmms.pl. Modified to use Audio::MPD
 V1.1 Remote Server Functionality has been added

=cut

use Audio::MPD;
use Audio::MPD::Playlist;

my $mpdconn;
my $data_dir    = $main::config_parms{data_dir};
my $mp3_program = $main::config_parms{mp3_program};

if ($Reload) {
    if ( !-e "$data_dir/mpd/mpd.conf" ) {
        print_log "Generating Initial MPD Config File" if $main::Debug{mp3_mpd};
        &gen_mpd_conf;
    }
}
else {
    $mpdconn = &init_mpd_con;
}

$v_mp3_control_state = new Voice_Cmd("MP3 Control [off,on]");
if ( $state = said $v_mp3_control_state) {
    $Save{mp3_mode} = $state;
    if ( $state eq 'off' ) {
        $mpdconn->kill;
    }
    else {
        &mp3_running;
    }
    speak "MP3 control now $state.";
}

if ( done_now $p_mp3_build_list) {
    print_log "Updating MPD Database...";
    $mpdconn->updatedb;
    print_log "MPD Database Updated";
}

$v_mp3_control_cmd = new Voice_Cmd(
    "Set the house mp3 player to [Play,Stop,Pause,Restart,Next Song,Previous Song,Volume Down,Volume Up,Shuffle On,Shuffle Off,Repeat On,Repeat Off,track]"
);
$v_mp3_vol_control = new Voice_Cmd(
    "Set the house mp3 volume to [5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,100]"
);
$v_mpd_control = new Voice_Cmd("[Regenerate,Restart] MPD");

my $state;
mp3_control($state)     if $state = said $v_mp3_control_cmd;
mp3_vol_control($state) if $state = said $v_mp3_vol_control;
mpd_control($state)     if $state = said $v_mpd_control;

sub mpd_control {
    my $state       = shift;
    my $mp3_program = $main::config_parms{mp3_program};
    my $data_dir    = $main::config_parms{data_dir};
    my $mpdStatus   = "";
    if ( $state eq 'Restart' ) {
        unless ( &check_pid == 1 ) {
            `killall $mp3_program`;
            `$mp3_program $data_dir/mpd/mpd.conf`;

            #sleep 1 sec to let the process start
            sleep 1;
            if ( &check_pid != 1 ) {
                print_log "$mp3_program failed to start";
                return;
            }
            print_log "$mp3_program started";

        }
    }
    elsif ( $state eq 'Regenerate' ) {
        if (&gen_mpd_conf) {
            speak "M P D configuration file successfully generated";
        }
        else {
            speak
              "There was an error generating the configuration file for M P D";
        }
    }
}

sub mp3_vol_control {
    my $vol = shift;
    return 0 unless &mp3_running;
    $mpdconn->volume($vol);
}

sub mp3_control {
    my $state = shift;
    return 0 unless &mp3_running;
    if ( $state eq 'Play' ) {
        $mpdconn->play;
    }
    elsif ( $state eq 'Stop' ) {
        $mpdconn->stop;
    }
    elsif ( $state eq 'Pause' ) {
        $mpdconn->pause(1);
    }
    elsif ( $state eq 'Restart' ) {
        $mpdconn->play(0);
    }
    elsif ( $state eq 'Next Song' ) {
        $mpdconn->next;
    }
    elsif ( $state eq 'Previous Song' ) {
        $mpdconn->prev;
    }
    elsif ( $state eq 'Volume Down' ) {
        my $vol = $mpdconn->status->volume();
        $vol -= 10;
        if ( $vol < 0 ) {
            $vol = 0;
        }
        $mpdconn->volume($vol);
    }
    elsif ( $state eq 'Volume Up' ) {
        my $vol = $mpdconn->status()->volume();
        $vol += 10;
        if ( $vol > 100 ) {
            $vol = 100;
        }
        $mpdconn->volume($vol);
    }
    elsif ( $state eq 'Shuffle On' ) {
        my $shufflestat = $mpdconn->status()->random();
        if ( !$shufflestat ) {
            $mpdconn->random(1);
        }
    }
    elsif ( $state eq 'Shuffle Off' ) {
        my $shufflestat = $mpdconn->status()->shuffle();
        if ($shufflestat) {
            $mpdconn->toggle_shuffle;
        }
    }
    elsif ( $state eq 'Repeat On' ) {
        my $repeatstat = $mpdconn->status()->repeat();
        if ( !$repeatstat ) {
            $mpdconn->repeat(1);
        }
    }
    elsif ( $state eq 'Repeat Off' ) {
        my $repeatstat = $mpdconn->status()->repeat();
        if ($repeatstat) {
            $mpdconn->repeat(0);
        }
    }

    #    elsif ($state eq 'track') {
    #      $mpdconn->track($pos);
    #    }
    print_log "mp3 player set to " . said $v_mp3_control_cmd . " ($state)";
}

sub mp3_play {
    my $file = shift;
    return 0 unless &mp3_running;
    $mpdconn->playlist->clear;
    if ( $file =~ m/(.m3u|.pls)/i ) {
        $file =~ s/$main::config_parms{data_dir}\///;
        $file =~ s/.m3u|.pls//g;
        $mpdconn->playlist->load("$file");
    }
    else {
        $file =~ s/$main::config_parms{mp3_dir}\///;
        $mpdconn->playlist->add("$file");
    }
    $mpdconn->play;
    print_log "mp3 play: $file";
}

sub mp3_queue {
    my $file = shift;
    $file =~ s/$main::config_parms{data_dir}\///;
    return 0 unless &mp3_running;
    if ( $file =~ m/(.m3u|.pls)/i ) {
        $file =~ s/$main::config_parms{data_dir}\///;
        $file =~ s/.m3u|.pls//g;
        $mpdconn->playlist->load("$file");
    }
    else {
        $file =~ s/$main::config_parms{mp3_dir}\///;
        $mpdconn->playlist->add("$file");
    }
    $mpdconn->play;
    print_log "mp3 queue: $file";
}

# clears the current playlist
sub mp3_clear {
    $mpdconn->playlist->clear;
    print_log "mp3 playlist cleared";
}

# return a reference to a list containing the playlist titles
sub mp3_get_playlist {
    my $count = 0;
    my @refarray;
    my @myarr = $mpdconn->playlist->as_items;
    foreach (@myarr) {
        @refarray[$count] = $_->title . " - " . $_->artist;
        $count += 1;
    }
    return \@refarray;
}

# get current song position
sub mp3_get_playlist_pos {
    if (&mp3_playing) {
        return $mpdconn->song->pos;
    }
    else {
        return 0;
    }
}

# set current song to position
sub mp3_set_playlist_pos {
    my $pos = shift;
    return $mpdconn->play($pos);
}

# add to the current playlist (argument received is reference to array)
sub mp3_playlist_add {
    return $mpdconn->add($1);
}

# delete from the current playlist (argument received is reference to array)
sub mp3_playlist_delete {
    my $pos = shift;
    print_log "deleting track $pos";
    return $mpdconn->playlist->delete($pos);
}

# return an array reference to a list containing the current playlist
sub mp3_get_playlist_files {

    #return $mpdconn->playlist;
}

# return the time from the song in the playlist position
sub mp3_get_playlist_timestr {
    my $pos  = shift;
    my $time = $mpdconn->song($pos)->time;

    # Convert seconds to days, hours, minutes, seconds
    my @parts = gmtime($time);
    return sprintf( "%d:%02d", @parts[1], @parts[0] );
}

# return the title of the current song
sub mp3_get_playlist_title {
    return $mpdconn->song->title;
}

sub mp3_get_playlist_artist {
    return $mpdconn->song->artist;
}

# return the current volume
sub mp3_get_volume {
    return $mpdconn->status->volume;
}

# return the elapsed/total time of current song
sub mp3_get_output_timestr {
    return $mpdconn->status->time->sofar . "/" . $mpdconn->status->time->total;
}

# return the number of songs in the current playlist
sub mp3_get_playlist_length {
    return $mpdconn->status->playlistlength();
}

# return if the player is running
sub mp3_playing {
    my $state = $mpdconn->status->state();
    if ( $state eq "play" ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub mp3_player_running {
    return &mp3_running;
}

sub mp3_running {
    my $data_dir = $main::config_parms{data_dir};

    # have we defined mp3_program
    my $mp3_program = $main::config_parms{mp3_program};
    if ( $mp3_program eq "" ) {
        print_log "mp3_program not defined";
        return 0;
    }

    # if mpd is not running, we will start it
    unless ( &check_pid == 1 ) {
        print_log "$mp3_program is not running, attempting to start";
        `$mp3_program $data_dir/mpd/mpd.conf`;

        #sleep 1 sec to let the process start
        sleep 1;
        if ( &check_pid != 1 ) {
            print_log "Can't start $mp3_program";
            return 0;
        }
        print_log "$mp3_program started";
    }
    return 1;
}

sub gen_mpd_conf {
    my $conf       = "";
    my $data_dir   = $main::config_parms{data_dir};
    my $workingdir = &trim(`pwd`) . "/$data_dir";
    open( MYFILE, "$data_dir/mpd/mpd.conf.raw" );
    while (<MYFILE>) {
        chomp;
        $conf .= "$_\n";
    }
    close(MYFILE);
    $conf =~ s/MP3_MUSIC_DIR/$main::config_parms{mp3_dir}/g;
    $conf =~ s/DATA_DIR/$workingdir/g;
    open( MYFILE, ">$data_dir/mpd/mpd.conf" );
    print MYFILE $conf;
    close(MYFILE);
}

sub trim($) {
    my $string = shift;
    $string =~ s/(^\s+|\s+$)//g;
    return $string;
}

sub check_pid {
    my $data_dir = $main::config_parms{data_dir};
    if ( -e "$data_dir/mpd/pid" ) {
        my $state;
        my $pid;
        open( MYFILE, "$data_dir/mpd/pid" );
        while (<MYFILE>) {
            chomp;
            $pid = "$_\n";
        }
        $state = kill 0, $pid;
        return $state;
    }
    else {
        return 0;
    }
}

sub init_mpd_con {
    eval {
        my $mpd = Audio::MPD->new();
        return $mpd;
    };
}

