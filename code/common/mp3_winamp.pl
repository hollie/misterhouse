# Category=Music

# $Date$
# $Revision$

#@
#@ This script controls the <a href='http://www.winamp.com'>Winamp MP3 player</a> for Windows. It
#@ handles operation of the mp3 player. Enable mp3.pl to manage the MP3 database.
#@ This script requires version 2.0 of the <a href='http://www.kostaa.com/winamp/'>httpq plug-in</a>
#@ or wactrl, by david_kindred@iname.com  (windows only, included in mh/bin dir).
#@ Greater functionality/control is achieved with httpq.
#@
#@ Set mp3_program to where winamp is installed.  For example,
#@   mp3_program=C:\Progra~1\Winamp\winamp.exe

# Supports -debug=winamp for logging, otherwise quiet

# Version ??? lets call it 1.01 - 9-16-03 Dan Uribe
#  Major update to align functions with David's common mp3 code and xmms
#  Supports a target host or defaults to localhost (Seems to work, but really untested)

# V1.02 28 Feb 2004 David Norwood,
#	  Update to add mp playing

# V1.03  1 Mar 2004 Pete Flaherty,
#	  Updated mp3_output_timestr to deliver consistant data with xmms output of same function
#         now delivers "mm:ss/MM:SS (xx%)"  where mm:ss is the Elapsed time MM:SS is the Total time
#         and (xx%) is the elapsed percentage of the total time

# V1.04 15 July 2004 Pete Flaherty
#	  Added mp3_playlist_delete to remove entries from current list

use Mp3Player;

# noloop=start      This directive allows this code to be run on startup/reload

eval 'use Win32::TieRegistry 0.20 (Delimiter=>"/", ArrayValues=>0)';
use vars '$Registry';

my $winamp_path;

if ($OS_win) {    # Not really needed as this is a Windows-only module
    $winamp_path =
      $Registry->{'Classes/Applications/Winamp.exe/shell/open/command//'};
    $winamp_path = $1 if $winamp_path and $winamp_path =~ /"(.*?)"/;
    print "Found local Winamp: $winamp_path\n" if $Debug{winamp};
}

$jukebox = new Mp3Player;

my ( %winamp_commands, $mp3_states );
if ( $config_parms{mp3_program_control} eq 'wactrl' ) {
    $mp3_states = "Play,Stop,Pause,Restart,Rewind,Forward,"
      . "Next Song,Previous Song,Volume up,Volume down,ontop";
    %winamp_commands = (
        'restart'       => 'start',
        'rewind'        => 'rew5s',
        'Forward'       => 'ffwd5s',
        'next song'     => 'nextsong',
        'previous song' => 'prevsong',
        'volume up'     => 'volup',
        'volume down'   => 'voldown'
    );
}
else {

    #Shuffle on/off

    $mp3_states =
      "Play,Stop,Pause,Next Song,Previous Song,Volume Up,Volume Down,Random Song,Toggle Shuffle,Toggle Repeat,Shoutcast Connect,Clear List";
    %winamp_commands = (
        'next song'         => 'next',
        'previous song'     => 'prev',
        'toggle shuffle'    => 'shuffle',
        'toggle repeat'     => 'repeat',
        'volume up'         => 'volumeup',
        'volume down'       => 'volumedown',
        'shoutcast connect' => 'shoutcast_connect',
        'clear list'        => 'delete'
    );
}
my $mp3_host = 'localhost';
$mp3_host = $config_parms{mp3_program_host} if $config_parms{mp3_program_host};

# noloop=stop

# Add Player Commands
$v_mp3_control1 = new Voice_Cmd("Set the house mp3 player to [$mp3_states]");
$v_mp3_control2 = new Voice_Cmd("Set music to [$mp3_states]");
&mp3_control( $state, $mp3_host )
  if $state = said $v_mp3_control1
  or $state = said $v_mp3_control2;

# House player process (not used, sendkeys takes care of starting winamp)
$p_winamp_house = new Process_Item "\"$config_parms{mp3_program}\"";

# Primary Control function
sub mp3_control {
    my ( $command, $host, $arg1 ) = @_;

    # This translates from speakable commands to program commands
    $command = $winamp_commands{ lc($command) }
      if $winamp_commands{ lc($command) };

    $host = $mp3_host unless $host;
    print "Setting $host winamp to $command\n" if $::Debug{winamp};

    return 0 unless &mp3_running($host);

    if (&is_httpq) {
        my $url = "http://$host:$config_parms{mp3_program_port}";
        if ( $command =~ /random song/i ) {
            my $mp3_num_tracks =
              get "$url/getlistlength?p=$config_parms{mp3_program_password}";
            my $song          = int( rand($mp3_num_tracks) );
            my $mp3_song_name = get
              "$url/getplaylisttitle?p=$config_parms{mp3_program_password}&a=$song";
            $mp3_song_name =~ s/[\n\r]//g;
            print "Now Playing $mp3_song_name\n" if $Debug{winamp};
            get "$url/stop?p=$config_parms{mp3_program_password}";
            get
              "$url/setplaylistpos?p=$config_parms{mp3_program_password}&a=$song";
            $temp =
              filter_cr get "$url/play?p=$config_parms{mp3_program_password}";
            return $temp;
        }
        elsif ( $command =~ /volume/i ) {
            $temp = '';

            # 10 passes is about 20 percent
            for my $pass ( 1 .. 5 ) {
                $temp .= filter_cr get
                  "$url/$command?p=$config_parms{mp3_program_password}";
            }
            print "Winamp (httpq $host) set to $command: $temp\n"
              if $Debug{winamp};
        }
        elsif ( $command =~ /shuffle/i ) {
            $temp .= filter_cr get
              "$url/shuffle_status?p=$config_parms{mp3_program_password}";
            if ($temp) {
                get "$url/shuffle?p=$config_parms{mp3_program_password}&a=0";
                print "Winamp (httpq $host) Shuffle set OFF\n"
                  if $Debug{winamp};
            }
            else {
                get "$url/shuffle?p=$config_parms{mp3_program_password}&a=1";
                print "Winamp (httpq $host) Shuffle set ON\n" if $Debug{winamp};
            }
        }
        elsif ( $command =~ /repeat/i ) {
            $temp .= filter_cr get
              "$url/repeat_status?p=$config_parms{mp3_program_password}";
            if ($temp) {
                get "$url/repeat?p=$config_parms{mp3_program_password}&a=0";
                print "Winamp (httpq $host) Repeat set OFF\n" if $Debug{winamp};
            }
            else {
                get "$url/repeat?p=$config_parms{mp3_program_password}&a=1";
                print "Winamp (httpq $host) Repeat set ON\n" if $Debug{winamp};
            }
        }
        else {
            $temp = filter_cr get
              "$url/$command?p=$config_parms{mp3_program_password}";
            print "Winamp (httpq $host) set to $command: $temp\n"
              if $Debug{winamp};
        }
        return $temp;
    }
    else {
        print "Winamp (watrl) set to $command\n" if $Debug{winamp};

        # Volume only goes by 1.5%, so run it a bunch
        my $i = 1;
        $i = 25 if $command =~ /^vol/;
        for ( 1 .. $i ) {
            run "\"$config_parms{mp3_program_control}\" $command";
        }
    }
}

# Play Song, Clear list if present
sub mp3_play {
    my $file = shift;
    return 0 if ( $file eq '' );
    my $host = shift || $mp3_host;
    return 0 unless &mp3_running($host);

    $file =~ s/&&/&/g;
    $file =~ s/\//\\/g;
    if (&is_httpq) {

        # Escape name ala http
        #$file =~ s/ /%20/g;
        #$file =~ s/\#/%23/g;
        #$file =~ s/\&/%26/g;
        #$file =~ s/\'/%27/g;
        #$file =~ s/\,/%2C/g;
        $file = &escape($file);
        my $url = "http://$host:$config_parms{mp3_program_port}";
        my $temp =
          filter_cr get "$url/delete?p=$config_parms{mp3_program_password}";
        print
          "winamp debug $url/playfile?p=$config_parms{mp3_program_password}&a=$file\n"
          if $Debug{winamp};
        $temp = filter_cr get
          "$url/playfile?p=$config_parms{mp3_program_password}&a=$file";
        $temp = filter_cr get "$url/play?p=$config_parms{mp3_program_password}";
        print "Winamp (httpq $host) song/list $file added: $temp\n"
          if $Debug{winamp};
        return ( $temp =~ /1/ );
    }
    else {
        run qq[$config_parms{mp3_program} "$file"];
        print "mp3 play: $file\n" if $Debug{winamp};
        return 1;
    }
}

# Queue Song, Append to current playlist
sub mp3_queue {
    my $file = shift;
    return 0 if ( $file eq '' );
    my $host = shift || $mp3_host;
    return 0 unless &mp3_running($host);
    $file =~ s/&&/&/g;
    $file =~ s/\//\\/g;
    if (&is_httpq) {

        # Escape name ala http
        #$file =~ s/ /%20/g;
        #$file =~ s/\#/%23/g;
        #$file =~ s/\&/%26/g;
        #$file =~ s/\'/%27/g;
        #$file =~ s/\,/%2C/g;
        $file = escape($file);
        my $url  = "http://$host:$config_parms{mp3_program_port}";
        my $temp = filter_cr get
          "$url/playfile?p=$config_parms{mp3_program_password}&a=$file";
        print "Winamp (httpq $host) song/list $file added: $temp\n"
          if $Debug{winamp};
    }
    else {
        run qq["$config_parms{mp3_program}" /ADD "$file"]; ##/ # For gVim syntax
        print "mp3 queue: $file\n" if $Debug{winamp};
    }
}

# For concise code (which is still lacking in this module!)

sub is_httpq {
    return $config_parms{mp3_program_control} eq 'httpq' ? 1 : 0;
}

# Clear current playlist
sub mp3_clear {
    my $host = shift;
    if (&is_httpq) {
        if ( &mp3_control( 'Clear List', $host ) ) {
            print "mp3 clear: success\n" if $Debug{winamp};
        }
        else {
            print "mp3 clear: failed\n" if $Debug{winamp};
        }
    }
    else {
        # don't know how to do this
        print "mp3 clear: Unsupported\n" if $Debug{winamp};
    }
}

# return a reference to a list containing the playlist titles
sub mp3_get_playlist {
    my $host = shift || $mp3_host;
    return 0
      unless &mp3_player_running($host)
      ;    # Avoid frequent calls to a non-existant player ... get is too slow
    if (&is_httpq) {
        my $url =
          "http://$host:$config_parms{mp3_program_port}/getplaylisttitle?p=$config_parms{mp3_program_password}";
        my $mp3List = get $url;
        my @mp3Queue = split( "<br>", $mp3List );
        return \@mp3Queue;
    }
    else {
        # don't know how to do this
        print "mp3 get playlist: Unsupported\n" if $Debug{winamp};
    }

}

# get current song position
sub mp3_get_playlist_pos {
    my $host = shift || $mp3_host;
    if (&is_httpq) {
        my $url =
          "http://$host:$config_parms{mp3_program_port}/getlistpos?p=$config_parms{mp3_program_password}";
        return get "$url";
    }
    else {
        # don't know how to do this
        print "mp3 get playlist pos: Unsupported\n" if $Debug{winamp};
    }
}

# set current song to position

# *** Bogus!  See main box
sub mp3_set_playlist_pos {
    my $pos = shift;
    return 0 if ( $pos eq '' );
    my $host = shift || $mp3_host;
    if (&is_httpq) {
        my $url =
          "http://$host:$config_parms{mp3_program_port}/setplaylistpos?p=$config_parms{mp3_program_password}&a=$pos";
        print "Winamp URI:$url\n" if $Debug{winamp};
        return get "$url";
    }
    else {
        # don't know how to do this
        print "mp3 set playlist pos: Unsupported\n" if $Debug{winamp};
    }
}

# add to the current playlist (argument received is reference to array)
sub mp3_playlist_add {
    my $file = shift;
    return 0 if ( $file eq '' );
    my $host = shift || $mp3_host;

    #    return $remote->playlist_add($1);
    #
    #    How is this diffrent from queue?
    #
    &mp3_queue( $file, $host );
}

sub mp3_playlist_delete {
    my $pos = shift;
    return 0 if ( $pos eq '' );
    my $host = shift || $mp3_host;
    if (&is_httpq) {
        my $url =
          "http://$host:$config_parms{mp3_program_port}/deletepos?p=$config_parms{mp3_program_password}&a=$pos";
        print "Winamp URI: $url\n" if $Debug{winamp};
        return get "$url";
    }
    else {
        # don't know how to do this
        print "mp3 playlist delete: Unsupported\n" if $Debug{winamp};
    }
}

# return an array reference to a list containing the current playlist
sub mp3_get_playlist_files {
    my $host = shift || $mp3_host;
    if (&is_httpq) {
        my $url =
          "http://$host:$config_parms{mp3_program_port}/getplaylistfile?p=$config_parms{mp3_program_password}";
        my $mp3List = get $url;
        my @mp3Queue = split( "<br>", $mp3List );
        return \@mp3Queue;
    }
    else {
        # don't know how to do this
        print "mp3 get playlist files: Unsupported\n" if $Debug{winamp};
    }
}

# return the time from the song in the playlist position
sub mp3_get_playlist_timestr {

    # don't know how to do this
    print "mp3 get playlist timestr: Unsupported\n" if $Debug{winamp};
}

# return the title of the current song
sub mp3_get_playlist_title {
    my $host = shift || $mp3_host;
    if (&is_httpq) {
        my $cPos = get
          "http://$host:$config_parms{mp3_program_port}/getlistpos?p=$config_parms{mp3_program_password}";
        return get
          "http://$host:$config_parms{mp3_program_port}/getplaylisttitle?p=$config_parms{mp3_program_password}&a=$cPos";
    }
    else {
        # don't know how to do this
        print "mp3 get playlist title: Unsupported\n" if $Debug{winamp};
    }
}

# return the current volume
sub mp3_get_volume {

    # don't know how to do this
    print "mp3 get volume: Unsupported\n" if $Debug{winamp};
}

# return the elapsed/total time of current song
sub mp3_get_output_timestr {
    my $type = shift;
    my $host = shift || $mp3_host;
    if (&is_httpq) {

        #		if ($type == 1 || $type =~ /Len/i) {
        my $songPos = get
          "http://$host:$config_parms{mp3_program_port}/getoutputtime?p=$config_parms{mp3_program_password}&a=0";
        my $songLen = get
          "http://$host:$config_parms{mp3_program_port}/getoutputtime?p=$config_parms{mp3_program_password}&a=1";

        # Format the info in a form consistant with xmms el:tm/to:tm

        my $tPos = $songPos / 1000;    #Posintion in miliseconds
        my $tLen = $songLen;           #Length of song in seconds
        if ($tLen) {
            my $tPct = int( ( $tPos / $tLen ) * 100 );   # what ist the % played

            my $tMin = int( $tPos / 60 );    #Make outputs in mm:ss format
            my $tSec = int( $tPos - ( $tMin * 60 ) )
              ;    # we don't care about fractions of mins & secs
            if ( $tSec < 10 ) { $tSec = "0$tSec"; }
            $songPos =
              "$tMin:$tSec";   # this should be the elapsed time in MM:SS format

            $tMin = int( $tLen / 60 );
            $tSec = int( $tLen - ( $tMin * 60 ) );
            if ( $tSec < 10 ) { $tSec = "0$tSec"; }
            $songLen =
              "$tMin:$tSec";    # this should be the Total time in MM:SS format

            return "$songPos/$songLen ($tPct%)";
        }

        #		}
        #		else {
        #			my $tPos = get "http://$host:$config_parms{mp3_program_port}/getoutputtime?p=$config_parms{mp3_program_password}&a=0";
        #			return $tPos / 1000;  # Returned as ms convert to sec
        #		}
    }
    else {
        # don't know how to do this
        print "mp3 get output timestr: Unsupported\n" if $Debug{winamp};
    }
}

# return the number of songs in the current playlist
sub mp3_get_playlist_length {
    my $host = shift || $mp3_host;
    if (&is_httpq) {
        return get
          "http://$host:$config_parms{mp3_program_port}/getlistlength?p=$config_parms{mp3_program_password}";
    }
    else {
        # don't know how to do this
        print "mp3 get playlist length: Unsupported\n" if $Debug{winamp};
    }
}

# return 0 if the player is stopped, 1 if playing, 3 if paused
sub mp3_playing {
    my $host = shift || $mp3_host;
    if (&is_httpq) {
        return get
          "http://$host:$config_parms{mp3_program_port}/isplaying?p=$config_parms{mp3_program_password}";
    }
    else {
        # don't know how to do this
        print "mp3 playing: Unsupported\n" if $Debug{winamp};
    }
}

# try to start winamp if not running and return the status of the player
sub mp3_running {
    my $host = shift || $mp3_host;

    # *** Tangled up BS
    # Play should just shell with file parameter if local!

    # Start winamp, if it is not already running (windows localhost only)
    if (
           $OS_win
        && ( $host eq 'localhost' )
        && done $p_winamp_house
        && !&sendkeys_find_window(
            'Winamp ',
            ( $config_parms{mp3_program} )
            ? $config_parms{mp3_program}
            : $winamp_path,
            5000
        )
      )
    {
        #		start $p_winamp_house;
        select undef, undef, undef, 10;
        print_log "Starting WinAmp";
    }
    if (&is_httpq) {
        return
          "http://$host:$config_parms{mp3_program_port}/getversion?p=$config_parms{mp3_program_password}";
    }
    else {
        # don't know how to do this
        return 1;
    }
}

# A quick way to test if the player is up
sub mp3_player_running {
    if (&is_httpq) {
        my $host = shift || 'localhost';
        return &net_socket_check("$host:$config_parms{mp3_program_port}");
    }
    else {
        return 1;    # Not sure what other methods we have to check here
    }
}

sub mp3_radio_play {
    my $file = shift;
    return 0 if ( $file eq '' );
    my $host = shift || $mp3_host;
    return 0
      if $host ne 'localhost'
      ;  # Can only launch URI's locally for some reason (httpq plugin problem?)
    return 0 unless &mp3_running($host);
    $file =~ s/&&/&/g;
    run qq["$config_parms{mp3_program}" "$file"];
    print "mp3 radio play: $file\n" if $Debug{winamp};
    return 1;
}
