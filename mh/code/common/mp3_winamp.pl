# Category=Music

#@ 
#@ This script controls the <a href='http://www.winamp.com'>Winamp MP3 player</a> for Windows. It 
#@ handles operation of the mp3 player. Enable mp3.pl to manage the MP3 database.  
#@ This script requires the <a href='http://www.kostaa.com/winamp/'>httpq plug-in</a>
#@ or wactrl, by david_kindred@iname.com  (windows only, included in mh/bin dir).
#@ Greater functionality/control is achieved with httpq. 
#@
#@ Set mp3_program to where winamp is installed.  For example, 
#@   mp3_program=C:\Progra~1\Winamp\winamp.exe

# Supports -debug=winamp for logging, otherwise quiet

# Version ??? lets call it 1.01 - 9-16-03 Dan Uribe
#  Major update to align functions with David's common mp3 code and xmms
#  Supports a target host or defaults to localhost (Seems to work, but really untested)
#  

# noloop=start      This directive allows this code to be run on startup/reload
my (%winamp_commands, $mp3_states);
if ($config_parms{mp3_program_control} eq 'wactrl') {
    $mp3_states = "Play,Stop,Pause,Restart,Rewind,Forward," . 
                  "Next Song,Previous Song,Volume up,Volume down,ontop";
    %winamp_commands = ('Restart' => 'start', 'Rewind' => 'rew5s', 'Forward' => 'ffwd5s', 
                        'Next Song' => 'nextsong', 'Previous Song' => 'prevsong',
                        'Volume up' => 'volup', 'Volume down' => 'voldown');
}
else {
    $mp3_states = "Play,Stop,Pause,Next Song,Previous Song,Volume Up,Volume Down,Random Song,Toggle Shuffle,Toggle Repeat,Restart,Shoutcast Connect,Add Song,Clear List";
    %winamp_commands = ('Next Song' => 'next', 'Previous Song' => 'prev',
                        'Toggle Shuffle' => 'shuffle', 'Toggle Repeat' => 'repeat',
                        'Volume Up' => 'volumeup', 'Volume Down' => 'volumedown', 'Shoutcast Connect' => 'shoutcast_connect',
			'Add Song' => 'playfile', 'Clear List' => 'delete' );
}
my $mp3_host = 'localhost'; 
$mp3_host = $config_parms{mp3_program_host} if $config_parms{mp3_program_host};
# noloop=stop

# Add Player Commands 
$v_mp3_control1 = new  Voice_Cmd("Set the house mp3 player to [$mp3_states]");
&mp3_control($state, $mp3_host)  if $state = said $v_mp3_control1;

# House player process
$p_winamp_house = new Process_Item "$config_parms{mp3_program}";

# Primary Control function
sub mp3_control {
    my ($command, $host, $arg1) = @_;

                                # This translates from speakable commands to program commands
    $command = $winamp_commands{$command} if $winamp_commands{$command};
    
    $host = $mp3_host unless $host;
    print_log "Setting $host winamp to $command" if $Debug{winamp};

    return unless &mp3_running($mp3_host);

    if (&is_httpq) {
        my $url = "http://$host:$config_parms{mp3_program_port}";
        if($command eq 'Random Song'){
            my $mp3_num_tracks = get "$url/getlistlength?p=$config_parms{mp3_program_password}";
            my $song = int(rand($mp3_num_tracks));
            my $mp3_song_name  = get "$url/getplaylisttitle?p=$config_parms{mp3_program_password}&a=$song";
            $mp3_song_name =~ s/[\n\r]//g;
            print_log "Now Playing $mp3_song_name" if $Debug{winamp};
            get "$url/stop?p=$config_parms{mp3_program_password}";
            get "$url/setplaylistpos?p=$config_parms{mp3_program_password}&a=$song";
            get "$url/play?p=$config_parms{mp3_program_password}";
        }
        elsif($command =~ /volume/i){
           $temp = '';
            # 10 passes is about 20 percent 
            for my $pass (1 .. 5) {
                $temp .= filter_cr get "$url/$command?p=$config_parms{mp3_program_password}";
            }
            print_log "Winamp (httpq $host) set to $command: $temp" if $Debug{winamp};
        }
	elsif($command =~ /shuffle/i) {
		$temp .= filter_cr get "$url/shuffle_status?p=$config_parms{mp3_program_password}";
		if ($temp) {
			get "$url/shuffle?p=$config_parms{mp3_program_password}&a=0";
			print_log "Winamp (httpq $host) Shuffle set OFF" if $Debug{winamp};
		}
		else {
			get "$url/shuffle?p=$config_parms{mp3_program_password}&a=1";
			print_log "Winamp (httpq $host) Shuffle set ON" if $Debug{winamp};
		}
	}
	elsif($command =~ /playfile/i) {
		$arg1 =~ s/&&/&/g;
		# Escape name ala http
	        $arg1 =~ s/ /%20/g;
        	$arg1 =~ s/\#/%23/g;
        	$arg1 =~ s/\&/%26/g;
        	$arg1 =~ s/\'/%27/g;
        	$arg1 =~ s/\,/%2C/g;
		my $url = "http://$host:$config_parms{mp3_program_port}";
		my $temp = filter_cr get "$url/playfile?p=$config_parms{mp3_program_password}&a=$arg1";
		print_log "Winamp (httpq $host) song/list $arg1 added: $temp" if $Debug{winamp};
	}
	else {
            $temp = filter_cr get "$url/$command?p=$config_parms{mp3_program_password}";
            print_log "Winamp (httpq $host) set to $command: $temp" if $Debug{winamp};
        }
	return $temp;
    }
    else {
        print_log "Winamp (watrl) set to $command" if $Debug{winamp};
                                # Volume only goes by 1.5%, so run it a bunch
        my $i = 1;
        $i = 25 if $command =~ /^vol/;
        for (1 .. $i) {
            run "$config_parms{mp3_program_control} $command";
        }
    }
}

# Play Song, Clear list if present - this really should support a remote host 
sub mp3_play {
    my $file = shift;
    return unless &mp3_running('localhost');
    # No httpq specific stuff... much easier to clear list and play file from cmd line
    $file =~ s/&&/&/g;
    run qq[$config_parms{mp3_program} "$file"];
    print_log "mp3 play: $file" if $Debug{winamp};
}

# Queue Song, Append to current playlist
sub mp3_queue {
	my $file = shift;
	return 0 if ($file eq '');
	my $host = shift || $mp3_host;
	if (&is_httpq) {
		&mp3_control('Add Song', $host, $file);
	}
	else {
		$file =~ s/&&/&/g;
		run qq[$config_parms{mp3_program} /ADD "$file"];  ##/ # For gVim syntax
		print_log "mp3 queue: $file" if $Debug{winamp};
	}
}

# Just for ease
sub is_httpq {
	return $config_parms{mp3_program_control} eq 'httpq' ? 1 : 0 ;
}

# Clear current playlist
sub mp3_clear {
	my $host = shift;
	if (&is_httpq) {
		if (&mp3_control('Clear List', $host) ) {
			print_log "mp3 clear: success" if $Debug{winamp};
		}
		else {
			print_log "mp3 clear: failed" if $Debug{winamp};
		}
	}
	else {
    # don't know how to do this 
		print_log "mp3 clear: Unsupported" if $Debug{winamp};
	}
}

        # return a reference to a list containing the playlist titles
sub mp3_get_playlist {
	my $host = shift || $mp3_host;
	if (&is_httpq) {
	        return unless &mp3_player_running($host); # Avoid frequent calls to a non-existant player ... get is too slow
		my $url = "http://$host:$config_parms{mp3_program_port}/getplaylisttitle?p=$config_parms{mp3_program_password}";
		my $mp3List = get $url;
		my @mp3Queue = split("<br>",$mp3List);
		return \@mp3Queue;
	}
	else {
    # don't know how to do this 
		print_log "mp3 get playlist: Unsupported" if $Debug{winamp};
	}
	
}

        # get current song position
sub mp3_get_playlist_pos {
	my $host = shift || $mp3_host;
	if (&is_httpq) {
		my $url = "http://$host:$config_parms{mp3_program_port}/getlistpos?p=$config_parms{mp3_program_password}";
		return get "$url";
	}
	else {
    # don't know how to do this 
		print_log "mp3 get playlist pos: Unsupported" if $Debug{winamp};
	}
}

        # set current song to position
sub mp3_set_playlist_pos {
	my $pos = shift;
	return 0 if ($pos eq '');
	my $host = shift || $mp3_host;
	if (&is_httpq) {
		my $url = "http://$host:$config_parms{mp3_program_port}/setplaylistpos?p=$config_parms{mp3_program_password}&a=$pos";
		print_log $url;
		return get "$url";
	}
	else {
    # don't know how to do this 
		print_log "mp3 set playlist pos: Unsupported" if $Debug{winamp};
	}
}

        # add to the current playlist (argument received is reference to array)
sub mp3_playlist_add {
	my $file = shift;
	return 0 if ($file eq '');
	my $host = shift || $mp3_host;
#    return $remote->playlist_add($1);
#
#    How is this diffrent from queue?
#
	&mp3_queue($file,$host);
}

        # return an array reference to a list containing the current playlist
sub mp3_get_playlist_files {
	my $host = shift || $mp3_host;
	if (&is_httpq) {
		my $url = "http://$host:$config_parms{mp3_program_port}/getplaylistfile?p=$config_parms{mp3_program_password}";
		my $mp3List = get $url;
		my @mp3Queue = split("<br>",$mp3List);
		return \@mp3Queue;
	}
	else {
    # don't know how to do this 
		print_log "mp3 get playlist files: Unsupported" if $Debug{winamp};
	}
}

        # return the time from the song in the playlist position
sub mp3_get_playlist_timestr {
    # don't know how to do this 
	print_log "mp3 get playlist timestr: Unsupported" if $Debug{winamp};
}

        # return the title of the current song 
sub mp3_get_playlist_title { 
	my $host = shift || $mp3_host;
	if (&is_httpq) {
		my $cPos = get "http://$host:$config_parms{mp3_program_port}/getlistpos?p=$config_parms{mp3_program_password}";
		return get "http://$host:$config_parms{mp3_program_port}/getplaylisttitle?p=$config_parms{mp3_program_password}&a=$cPos";
	}
	else {
    # don't know how to do this 
		print_log "mp3 get playlist title: Unsupported" if $Debug{winamp};
	}
}

        # return the current volume 
sub mp3_get_volume {
    # don't know how to do this 
	print_log "mp3 get volume: Unsupported" if $Debug{winamp};
}

        # return the elapsed/total time of current song  
sub mp3_get_output_timestr {
	my $type = shift;
	my $host = shift || $mp3_host;
	if (&is_httpq) {
		if ($type == 1 || $type =~ /Len/i) {
			return get "http://$host:$config_parms{mp3_program_port}/getoutputtime?p=$config_parms{mp3_program_password}&a=1";
		}
		else {
			my $tPos = get "http://$host:$config_parms{mp3_program_port}/getoutputtime?p=$config_parms{mp3_program_password}&a=0";
			return $tPos / 1000;  # Returned as ms convert to sec
		}
	}
	else {
    # don't know how to do this 
		print_log "mp3 get output timestr: Unsupported" if $Debug{winamp};
	}
}

        # return the number of songs in the current playlist 
sub mp3_get_playlist_length { 
	my $host = shift || $mp3_host;
	if (&is_httpq) {
		return  get "http://$host:$config_parms{mp3_program_port}/getlistlength?p=$config_parms{mp3_program_password}";
	}
	else {
    # don't know how to do this 
		print_log "mp3 get playlist length: Unsupported" if $Debug{winamp};
	}

}

        # return the status of the player 
sub mp3_running { 
	my $host = shift || $mp3_host;
                                # Start winamp, if it is not already running (windows localhost only)
#	&sendkeys_find_window 'Winamp', $config_parms{mp3_program};
	if ($OS_win && $host eq 'localhost' && done $p_winamp_house && ! &sendkeys_find_window('Winamp', $config_parms{mp3_program})) {
		start $p_winamp_house;
		select undef, undef, undef, .4;
		print_log "Starting WinAmp";
	}
	if (&is_httpq) {
		return "http://$host:$config_parms{mp3_program_port}/getversion?p=$config_parms{mp3_program_password}";
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
        return 1;  # Not sure what other methods we have to check here
    }
}  


