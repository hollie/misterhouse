
# Category=Music

#@ This script controls the <a href='http://www.xmms.org'>Xmms MP3 player</a> for Linux. It
#@ handles operation of the mp3 player. Enable mp3.pl to manage the MP3 database.
#@ This script requires Xmms::Remote.
#@
#@ Set mp3_program to where xmms is installed.  For example,
#@   mp3_program=/usr/bin/xmms

=begin comment

 mp3_xmms.pl

 xmms can be found at http://www.xmms.org/ and is frequently installed by 
 default in many distros such as Redhat, but often without MP3 support due
 to legal reasons.  In that case, download and install the xmms-mp3 package.  

 Author: Richard Phillips, god@ni...
 Liberally hacked from the code originally written by Dave Lounsberry for 
 the GQmpeg player - thanks and kudos, Dave.
 V1.0 - 25 Dec 2001 - created
 
 V1.1 - 26 Dec 2001 - changed to use xmms-shell to enable volume control, 
 add repeat and shuffle options and also support the buttons in the ia5 
 jukebox.
 
 V1.2 - 6 Jan 2002 - added in code to provide info on what's currently 
 playing - you need to load up Xmms::Remote but you'll already have that if 
 you're using xmms-shell. I guess if I could be bothered I'd change the 
 script to avoid using xmms-shell at all, but heck - why fix it if it ain't 
 broke...
 
 V1.3 - 20 Jan 2002 - updated and improved so that when using the slightly 
 modified "mp3_playlist_xmms.pl" it is now able to load playlists from the 
 main ia5 jukebox as well as select individual songs. Hint - to clear a 
 playlist you need to go into browse music categories and select the "clear 
 mp3 playlist" button. To be able to do this from the jukebox, just create a 
 playlist called - say - clearplaylist.m3u and save it in your playlist 
 directory, then you can clear the playlist by selecting this file...... 
 sneaky, but it works. Oh, remember that after adding any new mp3 files you 
 need to go into the browse/music/build mp3 database.
 
 V1.4 - 14 August added global variable "NowPlaying" so I can see that in the 
 status line on the ia5 web page. To use this, add "&playing&" into the 
 html_status_line settings in mh.ini/mh.private.ini 

 Revision by Brian Rudy (brudyNO@SP...)
 V1.5 - 6 Jan 2003 - Replaced all external xmms-shell calls with native 
 Xmms::Remote routines. Updated comment syntax.

 V1.6 - 28 Aug 2003 - by David Norwood (dnorwood2@yahoo.com) Changed name 
 from mp3_control_xmms.pl to mp3_xmms.pl and made more generic, so it can 
 be included in the common code directory.  

 V1.7 - 28 Feb 2004 - Pete Flaherty added mp3_playing to detect running state
 
 V1.8 - 12 Jul 2004 - Pete Flaherty added mp3_playlist_delete to allow current 
 playlist entry deletion (does not save list on purpose)

 Requires this package:  xmms-devel
'
=cut

use Xmms;
use Xmms::Remote ();
use Xmms::Config ();

#use Getopt::Std;

my $session = 0;
my $remote  = Xmms::Remote->new($session);

$v_mp3_control_state = new Voice_Cmd("MP3 Control [off,on]");
if ( $state = said $v_mp3_control_state) {
    $Save{mp3_mode} = $state;
    if ( $state eq 'off' ) {
        $remote->quit;
    }
    else {
        &mp3_running;
    }
    speak "MP3 control now $state.";
}

$v_mp3_control_cmd = new Voice_Cmd(
    "Set the house mp3 player to [Play,Stop,Pause,Restart,Next Song,Previous Song,Volume Down,Volume Up,Shuffle On,Shuffle Off,Repeat On,Repeat Off,Hide Window,Show Window,track]"
);

my $state;
mp3_control($state) if $state = said $v_mp3_control_cmd;

sub mp3_control {
    my $state = shift;
    return 0 unless &mp3_running;
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
        $vol -= 10;
        if ( $vol < 0 ) {
            $vol = 0;
        }
        $remote->set_main_volume($vol);
    }
    elsif ( $state eq 'Volume Up' ) {
        my $vol = $remote->get_main_volume;
        $vol += 10;
        if ( $vol > 100 ) {
            $vol = 100;
        }
        $remote->set_main_volume($vol);
    }
    elsif ( $state eq 'Shuffle On' ) {
        my $shufflestat = $remote->is_shuffle;
        if ( !$shufflestat ) {
            $remote->toggle_shuffle;
        }
    }
    elsif ( $state eq 'Shuffle Off' ) {
        my $shufflestat = $remote->is_shuffle;
        if ($shufflestat) {
            $remote->toggle_shuffle;
        }
    }
    elsif ( $state eq 'Repeat On' ) {
        my $repeatstat = $remote->is_repeat;
        if ( !$repeatstat ) {
            $remote->toggle_repeat;
        }
    }
    elsif ( $state eq 'Repeat Off' ) {
        my $repeatstat = $remote->is_repeat;
        if ($repeatstat) {
            $remote->toggle_repeat;
        }
    }
    elsif ( $state eq 'Hide Window' ) {
        $remote->main_win_toggle(0);
    }
    elsif ( $state eq 'Show Window' ) {
        $remote->main_win_toggle(1);
    }

    #    elsif ($state eq 'track') {
    #      $remote->track($pos);
    #    }
    print_log "mp3 player set to " . said $v_mp3_control_cmd . $state;
}

sub mp3_play {
    my $file = shift;
    return 0 unless &mp3_running;
    run qq[$config_parms{mp3_program} "$file"];
    print_log "mp3 play: $file";
}

sub mp3_queue {
    my $file = shift;
    return 0 unless &mp3_running;
    run qq[$config_parms{mp3_program} -e "$file"];
    print_log "mp3 queue: $file";
}

# clears the current playlist
sub mp3_clear {
    $remote->playlist_clear;
    print_log "mp3 playlist cleared";
}

# return a reference to a list containing the playlist titles
sub mp3_get_playlist {
    return $remote->get_playlist_titles;
}

# get current song position
sub mp3_get_playlist_pos {
    return $remote->get_playlist_pos;
}

# set current song to position
sub mp3_set_playlist_pos {
    my $pos = shift;
    return $remote->set_playlist_pos($pos);
}

# add to the current playlist (argument received is reference to array)
sub mp3_playlist_add {
    return $remote->playlist_add($1);
}

# delete from the current playlist (argument received is reference to array)
sub mp3_playlist_delete {
    my $pos = shift;
    print_log "deleting track $pos";
    return $remote->playlist_delete($pos);
}

# return an array reference to a list containing the current playlist
sub mp3_get_playlist_files {
    return $remote->get_playlist_files;
}

# return the time from the song in the playlist position
sub mp3_get_playlist_timestr {
    my $pos = shift;
    return $remote->get_playlist_timestr($pos);
}

# return the title of the current song
sub mp3_get_playlist_title {
    return $remote->get_playlist_title;
}

# return the current volume
sub mp3_get_volume {
    return $remote->get_volume;
}

# return the elapsed/total time of current song
sub mp3_get_output_timestr {
    return $remote->get_output_timestr();
}

# return the number of songs in the current playlist
sub mp3_get_playlist_length {
    return $remote->get_playlist_length();
}

# return if the player is running
sub mp3_playing {
    return $remote->is_playing();
}

sub mp3_player_running {
    return $remote->is_running();
}

sub mp3_running {

    # have we defined mp3_program
    my $mp3_program = $main::config_parms{mp3_program};
    if ( $mp3_program eq "" ) {
        print_log "mp3_program not defined";
        return 0;
    }

    # if xmms is not running, we will start it
    my $XmmsStatus;
    unless ( $remote->is_running ) {
        print_log "$mp3_program is not running, attempting to start";
        `$mp3_program >/dev/null 2>/dev/null&`;

        #sleep 5 sec to let the process start
        sleep 5;

        # 09/05/05 dnorwood, took out the /sbin/ path to pidof, because it's in /bin on debian
        $XmmsStatus = `pidof $mp3_program`;
        chop $XmmsStatus;
        if ( $XmmsStatus eq "" ) {
            print_log "Can't start $mp3_program";
            return 0;
        }
        &mp3_control('Hide Window') if $main::config_parms{mp3_program_hide};
        print_log "$mp3_program started";
    }
    return 1;
}

