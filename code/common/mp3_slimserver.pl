# Category=Music
#
#@ This script controls the Slimserver software
#@ This version has been modified in order to optionaly and transparently direct mh/slimserver
#@ music to networked computers, using their own players
#@ surch as Winamp, as another way to distribute music streams into different destinations,
#@ and to display the related clients/slimserver activity in the Tk Log window.
#@
#@ Also It has been tested with SliMP3 hardware on x86 Linux, but should work
#@ with Squeezebox as well as on any platform.
#@
#@ Enable common/mp3.pl to manage MP3's.
#@
#@ Set slimserver_server parms and slimserver_player parms
#@ to the slimserver host, web port, and player MAC address or ip address.
#@ Defaults are to localhost:9000 but slimserver_player parm is required filled or blank.
#@
#@
#@ The multiplayer option Works by leaving empty the mh.ini slimserver_player parm (ip client address),
#@ if so it will automatically retrieve the remote client ip address using $Socket_Ports{http}{client_ip_address}
#@ reedirecting the slimserver service to that client.
#@
#@ As requirements:
#@
#@ Install the software player on each remote client (Winamp)
#@ Install this mp3_slimserver.pl
#@ Install the slimserver itself
#@ Finally you need to manually let each of your players find the slimserver stream by executing
#@ (example Winamp to slimserver IP and port):
#@   Open your Remote Winamp-> Play-> Location->then type http://your_server_IP:9000/stream.mp3
#@   Your Winamp Player will be ready to stream from slimserver
#@
#@ The only Drawbacks: The play,Prev,Next commands on the remote player
#@ must be issued using the misterhouse mp3 web interface,
#@ the response to a command takes as much as 8 seconds and can't control volume.
#@ The Pros: It is a rather simple (even wireless) unexpensive and effective way to distribute
#@  your mp3 jukebox music to several PCs.
#@
#@ Don't forget to set mp3_dir to point to both the playlists and the music dirs
#@ If slimserver runs on a diff machine, I believe the paths need to
#@ be the same for both machines to these dirs.
#@

=begin comment

 mp3_slimserver.pl

 Slimserver is for SliMP3 and Squeezebox products from
 http://www.slimdevices.com.

 Author: Paul Estes
 Hacked from mp3_winamp.pl
 V1.0 30 Nov 03 - created
 Modify by Raul Rodriguez July 25th,2004
 Known bugs:
 History and recovery playlists show up in the playlist on mh
 Playlists with apostrophes don't work
 Probably others

=cut

use Mp3Player;

$jukebox = new Mp3Player;

sub mp3_play {
    my $file = shift;
    my $host = $config_parms{slimserver_host};
    $host = 'localhost:9000' unless $host;
    my $client_ip = $config_parms{slimserver_player};
    $client_ip = $Socket_Ports{http}{client_ip_address} unless $client_ip;
    print_log "Player IP address for playing slimserver " . $client_ip;
    print_log "mp3 play: $file";
    $file =~ s./.%2f.g;
    my $url =
      "http://$host/status.txt?p0=playlist&p1=load&p2=$file&player=$client_ip";
    get $url;
}

sub mp3_queue {
    my $file = shift;
    my $host = $config_parms{slimserver_host};
    $host = 'localhost:9000' unless $host;
    my $client_ip = $config_parms{slimserver_player};
    $client_ip = $Socket_Ports{http}{client_ip_address} unless $client_ip;
    print_log "Player IP address queueing slimserver " . $client_ip;
    print_log "mp3 queue: $file";
    $file = &escape($file);
    my $url =
      "http://$host/status.txt?p0=playlist&p1=add&p2=$file&player=$client_ip";
    get $url;
}

sub mp3_clear {
    my $host = $config_parms{slimserver_host};
    $host = 'localhost:9000' unless $host;
    my $client_ip = $config_parms{slimserver_player};
    $client_ip = $Socket_Ports{http}{client_ip_address} unless $client_ip;
    print_log "Player IP address clearing slimserver " . $client_ip;
    print_log "mp3 playlist cleared";
    my $url = "http://$host/status.txt?p0=playlist&p1=clear&player=$client_ip";
    print "slimserver request: $url\n" if $Debug{'slimserver'};
    get $url;
}

sub mp3_get_playlist {

    # This doesn't work yet
    return 0;
}

sub mp3_get_playlist_pos {

    # don't know how to do this
    return 0;
}

# noloop=start      This directive allows this code to be run on startup/reload
my $mp3_states =
  "Play,Stop,Pause,Next Song,Previous Song,Volume up, Volume down";
my %slim_commands = (
    'play'          => 'play',
    'stop'          => 'stop',
    'pause'         => 'pause',
    'next song'     => 'jump_fwd',
    'previous song' => 'jump_rew',
    'volume up'     => 'volume_up',
    'volume down'   => 'volume_down'
);
$v_slimserver_control =
  new Voice_Cmd("Set the house mp3 player to [$mp3_states]");

# noloop=stop

sub mp3_control {
    my $command = shift;
    $command = $slim_commands{ lc($command) } if $slim_commands{ lc($command) };

    # *** Need clear list and encode filename

    my $host = $config_parms{slimserver_host};
    $host = 'localhost:9000' unless $host;
    my $client_ip = $config_parms{slimserver_player};
    $client_ip = $Socket_Ports{http}{client_ip_address} unless $client_ip;

    #	print_log "Player IP address controlling slimserver " . $client_ip;
    #	print_log "Setting $host slimserver to $command";
    my $url = "http://$host";
    $url .= "/status.txt?p0=button&p1=$command&player=$client_ip";
    print "slimserver request: $url\n" if $Debug{'slimserver'};
    get $url;
}

if ( $state = said $v_slimserver_control) {
    respond "app=mp3 $state";
    mp3_control($state);
}
