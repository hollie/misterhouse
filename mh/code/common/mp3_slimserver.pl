# Category=Music

#@ 
#@ This script controls the Slimserver software
#@ It has been tested with SliMP3 hardware on x86 Linux, but should work
#@ with Squeezebox as well as on any platform.
#@
#@ Enable common/mp3.pl to manage MP3's.
#@
#@ Set slimserver_server and slimserver_player parms
#@ to the slimserver host, web port, and player MAC address or ip address.
#@ Defaults to localhost:9000, but slimserver_player is required.
#@
#@ Set mp3_dir to point to both the playlists and the music dirs
#@ If slimserver runs on a diff machine, I believe the paths need to
#@ be the same for both machines to these dirs.

=begin comment

 mp3_slimserver.pl

 Slimserver is for SliMP3 and Squeezebox products from
 http://www.slimdevices.com.

 Author: Paul Estes
 Hacked from mp3_winamp.pl
 V1.0 30 Nov 03 - created

 Known bugs:
 History and recovery playlists show up in the playlist on mh
 Playlists with apostrophes don't work
 Probably others

=cut

sub mp3_play {
	my $file = shift;
	my $host = $config_parms{slimserver_host};
	$host = 'localhost:9000' unless $host;
	print_log "mp3 play: $file";
	$file =~ s./.%2f.g;
	my $url = "http://$host/status.txt?p0=playlist&p1=load&p2=$file&player=$config_parms{slimserver_player}";
	get $url;
}

sub mp3_queue {
	my $file = shift;
	my $host = $config_parms{slimserver_host};
	$host = 'localhost:9000' unless $host;
	print_log "mp3 queue: $file";
	$file =~ s./.%2f.g;
	my $url = "http://$host/status.txt?p0=playlist&p1=add&p2=$file&player=$config_parms{slimserver_player}";
	get $url;
}

sub mp3_clear {
	my $host = $config_parms{slimserver_host};
	$host = 'localhost:9000' unless $host;
	print_log "mp3 playlist cleared";
	my $url = "http://$host/status.txt?p0=playlist&p1=clear&player=$config_parms{slimserver_player}";
        print "slimserver request: $url\n" if $Debug{'slimserver'};
	get $url;
}

sub mp3_get_playlist {
# This doesn't work yet
    return ["not implemented"];
}

sub mp3_get_playlist_pos {
    # don't know how to do this 
    return 0;
}

# noloop=start      This directive allows this code to be run on startup/reload

my $mp3_states = "Play,Stop,Pause," .
		"Next Song,Previous Song,Volume up, Volume down";
my %slim_commands = ('Play' => 'play', 'Stop' => 'stop',
		'Pause' => 'pause', 'Next Song' => 'jump_fwd',
		'Previous Song' => 'jump_rew', 'Volume up' => 'volume_up',
		'Volume down' => 'volume_down');

# noloop=stop

sub slimpserver_control {
	my $command = shift;
	$command = $slim_commands{$command} if $slim_commands{$command};
	my $host = $config_parms{slimserver_host};
	$host = 'localhost:9000' unless $host;
	print_log "Setting $host slim to $command";
	my $url = "http://$host";
	$url .= "/status.txt?p0=button&p1=$command&player=$config_parms{slimserver_player}";
        print "slimserver request: $url\n" if $Debug{'slimserver'};
	get $url;
}


$v_slimserver_control = new Voice_Cmd("Set the house mp3 player to [$mp3_states]");

if ($state = said $v_slimserver_control) {
       slimpserver_control($state);
}
