
# Category=Media

#@ This script controls the <a href='http://www.xinehq.org'>Xine Media player</a> for Linux
#@ and other platforms. It handles operation of the media player.
#@ Enable mhmedia.pl (when available )to manage the media database.
#@ This script requires the use of sockets.
#@
#@ Set mhmedia_program to where xine is installed.  For example,
#@   mhmedia_program=/usr/bin/xine
#@   YOU NEED TO DO THIS ONLY IF THE PLAYER IS ON THE LOACAL MACHINE
#@ If the Player is on a non local machine this parameter is ignored

=begin comment

 mhmedia_xine.pl

 xine can be found at http://www.xinehq.org/ and is frequently installed by 
 default in many distros such as Redhat, but often without support for some formats 
 due to legal reasons.  In that case, download and install the appropriate package.  

 The intention of this module is to enable a PC with xine and a netowork connection to
 play various types of media, including video materials.  This module requires xine to
 be started in network mode, so it can be controled by a tcp connection.
 You will need to setup a xine 'passwd' file on your player machine, this is typically 
 located in the home directory of the user the player runs as this is typically 
 ~/.xine/passwd on a *nix machine. A generic entry of ALL:ALLOW will let anyone remotely
 control the xine engine.  You may want to use authorization


 Author: Pete Flaherty
 Liberally hacked mp3_ files by Richard Phillips, god@ni... which was hacked from 
 the code originally written by Dave Lounsberry for the GQmpeg player 
 - thanks and kudos, Dave and Richard.
 
 V0.01 - 23 Feb 2005  - created initial concept proof hack
 V0.02 - 12 Mar 2005  - updated functions and post processing of return data 
 V0.10 - 15 Mar 2005  - initial release, all functions should be active and usable
			added authentication for the player
 V0.11 -  4 Apr 2005  - added play DVD function
 v0.12 -  5 May 2005  - fixed playing files with spaces, will not work with commas
  
 Note: localhost functionality not tested 

=cut

# noloop=start
#my $mediaState = "";
# noloop=stop

my $mediahost = $config_parms{media_server_host_port}
  ;    #@ the server (localhost)  and port (6789) for the player
$mediahost = "localhost:6789" unless $mediahost;

my $mediaPlaylist = $config_parms{media_server_playlist}
  ;    #@full path to the palylist including the name
$mediaPlaylist = "/root/.xine/playlist.tox" unless $mediaPlaylist;

my $mediaUser = $config_parms{media_server_user};    #optional login information
my $mediaPass = $config_parms{media_server_pass};
my $mediapath = ""
  unless $config_parms{media_file_path};    #used in mhmedia_list web function

$mediacmd = new Socket_Item( undef, undef, $mediahost, 'media', 'tcp' );

if ($Reload) {
    start $mediacmd ;
    $Save{mhmedia_control} = 'Startup';

}

#Check for outstanding state changes and cleanups
my $mhmediastate = $Save{mhmedia_control};
if ( $mhmediastate ne '' ) {

    #print " .... we have post processing to do for :: $mhmediastate \n";
    &mhmedia_return($mhmediastate);    #	check for returned results

}

$v_mhmedia_control_state = new Voice_Cmd("mhmedia Control [off,on,check]");
if ( $state = said $v_mhmedia_control_state) {
    if ( $state eq 'off' ) {
        $Save{mhmedia_mode} = $state;

        #set $mediacmd 'quit';
        stop $mediacmd ;
    }
    elsif ( $state eq 'on' ) {
        $Save{mhmedia_mode} = $state;
        start $mediacmd;
        $Save{mhmedia_control} = 'Startup';
        &mhmedia_return('Startup');
    }

    #else {
    &mhmedia_running;

    #my $tmp = said $mediacmd ;
    #}
    #    speak "mhmedia control now $state.";
}

my $cmdlist =
    "Play,Stop,Pause,Up,Down,Left,Right,Select,Menu,"
  . "Next Track,Previous Track,Next Chapter,Previous Chapter,Restart,"
  . "Volume Down,Volume Up,Mute,Shuffle On,Shuffle Off,Repeat On,Repeat Off,"
  . "Panel,Play DVD,Load Playlist,Playlist,track,"
  . "FastForward,Rewind,Slow,Fullscreen";

$v_mhmedia_control_cmd =
  new Voice_Cmd( "Set the house media player to [" . $cmdlist . "]" );
my $state;

if ( $Reload or $Startup ) {
    run_voice_cmd "Set the house media player to Load Playlist";
}

mhmedia_control($state) if $state = said $v_mhmedia_control_cmd;

sub mhmedia_control {
    my $state = shift;
    print " MEDIA Control State is $state \n";
    $Save{mhmedia_control} = $state;    #Save the command for later

    #    return 0 unless &mhmedia_running;

    if ( $state eq 'Play' ) {
        set $mediacmd 'play';
    }
    elsif ( $state eq 'Stop' ) {
        set $mediacmd 'stop';
    }
    elsif ( $state eq 'Pause' ) {
        set $mediacmd 'pause';
    }

    # Navigation events

    elsif ( $state eq 'Up' ) {
        set $mediacmd 'event up';
    }
    elsif ( $state eq 'Down' ) {
        set $mediacmd 'event down';
    }
    elsif ( $state eq 'Left' ) {
        set $mediacmd 'event left';
    }
    elsif ( $state eq 'Right' ) {
        set $mediacmd 'event right';
    }
    elsif ( $state eq 'Select' ) {
        set $mediacmd 'event select';
    }
    elsif ( $state eq 'Menu' ) {
        set $mediacmd 'event menu';
    }

    #Internal video navigation eg chapters
    elsif ( $state eq 'Next Chapter' ) {
        set $mediacmd 'event next';
    }
    elsif ( $state eq 'Previous Chapter' ) {
        set $mediacmd 'event previous';
    }

    # Playlist manipulation Assuming a base playlist is loaded
    elsif ( $state eq 'Next Track' ) {
        set $mediacmd 'playlist next';
    }
    elsif ( $state eq 'Previous Track' ) {
        set $mediacmd 'playlist prev';
    }

    #  ~/.xine/playlist.tox is assumed to be loaded
    elsif ( $state eq 'Restart' ) {

        # Reset the playlist
        set $mediacmd 'set_playlist_pos(0)';

        # Then Stop and restart the player
        set $mediacmd 'stop';
        sleep 2;
        set $mediacmd 'play';
    }

    elsif ( $state eq 'Volume Down' ) {
        set $mediacmd 'get audio volume';
    }

    elsif ( $state eq 'Volume Up' ) {
        set $mediacmd 'get audio volume';
    }

    elsif ( $state eq 'Mute' ) {
        set $mediacmd 'get audio mute';
    }

    # Misc functions
    elsif ( $state eq 'Shuffle On' ) {
        my $shufflestat = set $mediacmd 'is_shuffle';
        if ( !$shufflestat ) {
            set $mediacmd 'set loop shuffle';
        }
    }
    elsif ( $state eq 'Shuffle Off' ) {
        my $shufflestat = set $mediacmd 'is_shuffle';
        if ($shufflestat) {
            set $mediacmd 'set loop no';
        }
    }
    elsif ( $state eq 'Repeat On' ) {
        my $repeatstat = set $mediacmd 'is_repeat';
        if ( !$repeatstat ) {
            set $mediacmd 'set repeat';
        }
    }
    elsif ( $state eq 'Repeat Off' ) {
        my $repeatstat = set $mediacmd 'is_repeat';
        if ($repeatstat) {
            set $mediacmd 'set loop no';
        }
    }

    # Visual settings
    elsif ( $state eq 'Panel' ) {
        set $mediacmd 'gui panel';
    }
    elsif ( $state eq 'Playlist' ) {
        set $mediacmd 'gui playlist';
    }
    elsif ( $state eq 'Playlist' ) {
        set $mediacmd 'gui playlist';
    }
    elsif ( $state eq 'Load Playlist' ) {
        set $mediacmd "playlist del *";
        set $mediacmd "mrl add $mediaPlaylist";
        sleep 1;
        set $mediacmd "playlist first";
        set $mediacmd "stop";
    }
    elsif ( $state eq 'Play DVD' ) {
        set $mediacmd 'mrl add dvd://';
        set $mediacmd 'playlist last';
    }
    elsif ( $state eq 'FastForward' ) {
        set $mediacmd 'set speed XINE_SPEED_FAST_4';
    }

    elsif ( $state eq 'Rewind' ) {
        set $mediacmd 'set speed XINE_SPEED_SLOW_2';
    }

    elsif ( $state eq 'Slow' ) {
        set $mediacmd 'set speed XINE_SPEED_SLOW_4';
    }

    elsif ( $state eq 'Fullscreen' ) {
        set $mediacmd 'fullscreen';
    }

    #    elsif ($state eq 'track') {
    #      set $mediacmd track ($pos);
    #    }
    print_log "Media player set to " . said $v_mhmedia_control_cmd ;

}
if ($state) {

}

#--------- Post Processing of returned Data ---------
# This is where we get data from the command above and
# do some processing before we can set the value
# Volume +/- Seek +/- etc ......
#
# This is where we do the post processing for returned values
#  supposedly
#
sub mhmedia_return {

    #$state = $Save{mhmedia_control};
    my $mediaMode = shift(@_);
    $mediaMode = shift(@_);    # retrieve the passwd command

    #  we expect that there is some data to be returned from the socket
    #  so we look.
    # We also need the state that called the check $mediaMode that was
    #  saved when we initialized the function that called us

    if ( $state = said $mediacmd and $mediaMode ne '' ) {

        print " We had a Mode of $mediaMode ($state)to process ...\n";

        # debug info
        #print " The media command < $mediaMode > that has a return is $state \n";

        # We need to do some clearing so we read the startup message
        if ( $mediaMode eq 'Startup' or !$mediaMode ) {
            my $value = $state;

            #if we want to authenticate here is where we do it
            if ( $config_parms{media_server_user} ) {
                set $mediacmd
                  "identify $config_parms{media_server_user}:$config_parms{media_server_pass}";
            }
            $mediaMode = '';
        }

        ### VOLUME up and down are relative values so we use 10% steps
        if ( $mediaMode eq 'Volume Up' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            $value += 10;
            set $mediacmd "set audio volume $value";
            $mediaMode = '';

            #print " Volume UP\n";
        }
        elsif ( $mediaMode eq 'Volume Down' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            $value -= 10;
            set $mediacmd "set audio volume $value";
            $mediaMode = '';

            #print " Volume Down\n";
        }

        ### Mute is a state so we read it and set the other
        elsif ( $mediaMode eq 'Mute' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            if ( $value eq '1' ) {
                set $mediacmd "set audio mute 0";
                $mediaMode = '';

                #print " Mute OFF\n";
            }
            elsif ( $value eq '0' ) {
                set $mediacmd "set audio mute 1";
                $mediaMode = '';

                #print " Mute ON";
            }
            print_log "Media Player Mute state is NOT $value";

        }

        ### When we load something in the playlist and need to play it we
        #  will wait for the mrl to be added and then issue an action
        elsif ( $mediaMode eq 'Play dVD' ) {
            set $mediacmd 'playlist last';
            $mediaMode = '';

            #print " Try to play dvd now\n";
        }

=begin comment
    these queries are setup in a sub routing and need to be returned to caller
    *- is an entry that needs processing and returns other are ok as is
	we''ll need to $Save{mhmedia_control} in the calling routines
	so we know what to do ...

    play
    queue
    clear    
    *-get_playlist
    *-get_playlist_pos
    *-get_playlist_files
    *-get_playlist_title
    *-get_volume
    *-get_output_timestr
    *-get_playlist_length
    *-playing
=cut

        elsif ( $mediaMode eq 'get_playlist' ) {

            # array of values needed for return
            my $PlayNow = '';

            # my [@PlayPos, @PlayMrl ];

            if ( substr( $state, 0, 2 ) eq '*>' ) {

                #    $nowPlaying =
            }

            my ( $cmdPre, $value ) = split( /: /, $state );

            # velues 'empty playlist.  *>    0 /path or mrl
            # *> is the current value
            print "Playlist $value";
            $mediaMode = '';

            #return ;
        }

        elsif ( $mediaMode eq 'get_playlist_pos' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            print "Playlist $value";
            $mediaMode = '';

            #return ;
        }

        elsif ( $mediaMode eq 'get_playlist_files' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            print "Playlist $value";
            $Save{mhmedia_get_playlist_files};
            $mediaMode = '';

            #return ;
        }

        elsif ( $mediaMode eq 'get_playlist_timestr' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            print "Playlist $value";
            $Save{mhmedia_get_playlist_timestr};
            $mediaMode = '';

            #return $value ;
        }

        elsif ( $mediaMode eq 'get_playlist_title' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            print "Playlist $value";
            $Save{mhmedia_get_playlist_title};
            $mediaMode = '';

            #return ;
        }

        elsif ( $mediaMode eq 'get_volume' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            print "Playlist $value";
            $Save{mhmedia_get_volume};
            $mediaMode = '';

            #return ;
        }

        elsif ( $mediaMode eq 'get_output_timestr' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            print "Output timestr $value\n";
            $mediaMode = '';

            #	return $value ;
        }

        elsif ( $mediaMode eq 'get_playlist_length' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            print "Playlist $value";
            $mediaMode = '';

            #return ;
        }

        elsif ( $mediaMode eq 'playing' ) {
            my ( $cmdPre, $value ) = split( /: /, $state );
            print "Playlist $value";
            $mediaMode = '';

            #return ;
        }
        print_log "mhmedia: $mediaMode command processed";

        $Save{mhmedia_control} = $mediaMode;

    }

    #Now that we've finished looking at the results we will save the
    # current state (in case we need to do something else )
    # if we've finished the post process this value will be blank
    #  and therefore we won't bother processing it on the next pass

    return;
}

#
# These functins will be called from external processes eg the media manager
#  there are still some inconsistant results as of v0.02 and I'll need to addess
#  exactly how the date will be returned to the caller
# I suspect that I will need to create a delayed return or a lib to immediately
#  process and return the date to the caller, thoug I'd like to impliment it here
#  for ease of maintainence
#

sub mhmedia_play {
    my $file = shift;
    ##Here we need to see if its a local player or a remote
    #  and wether or not its playing something
    #return 0 unless &mhmedia_running;
    print " Play this $file \n";

    set $mediacmd "playlist del *";
    select undef, undef, undef, .050;    # # Wait a while
    my $cmd = "mrl add '" . "$file'";
    set $mediacmd $cmd;
    select undef, undef, undef, .050;    # # Wait a while
    set $mediacmd 'play';

    #run qq[$config_parms{mhmedia_program} "$file"];
    print_log "mhmedia play: $file";
}
## Add a file to the playlist
sub mhmedia_queue {
    my $file = shift;

    #return 0 unless &mhmedia_running;
    print " queue $file";
    my $cmd = "mrl add '" . "$file'";
    set $mediacmd $cmd;

    #run qq[$config_parms{mhmedia_program} -e "$file"];
    print_log "mhmedia queued: $file";
}

# clears the current playlist
sub mhmedia_clear {
    set $mediacmd 'playlist delete all';
    print_log "mhmedia playlist cleared";
}

# GET return a reference to a list containing the playlist titles
sub mhmedia_get_playlist {
    set $mediacmd 'playlist show';
    select undef, undef, undef, .050;    # # Wait a while
    $state = said_next $mediacmd;
    return ($state);
}

# GET current song position  same as above but needs parse
sub mhmedia_get_playlist_pos {
    my $cntr = &mhmedia_get_playlist_length();
    set $mediacmd 'playlist show';       # ask for the lst
    select undef, undef, undef, .050;    # Wait a while
    my $rtn = 'No Playlist Title available';
    my $pos = 0;
    for ( $pos = 0, $pos < $cntr + 1, $pos++ ) {    # loop to get the list
        $state = said_next $mediacmd;
        print "return $state \n";
        my ( $cmd2, $val ) = split( /\s+ /, $state );    # break ths line up
        my ( $ptr,  $cmd ) = split( /\s+/,  $val );
        if ( $cmd2 eq "*>" ) {    # look current for the marker
             # cmd-is the filename, val-fn ,ptr-list number, cmd2- current selection
            $rtn = $ptr;    # return the pointer for the current selection
        }
    }
    return ($rtn);
}

# set current playlist to position
sub mhmedia_set_playlist_pos {
    my $cntr = &mhmedia_get_playlist_length();
    set $mediacmd 'playlist show';
    select undef, undef, undef, .050;    # # Wait a while
    my $rtn = 'No Playlist Title available';
    my $pos = 0;
    for ( $pos = 0, $pos < $cntr + 1, $pos++ ) {
        $state = said_next $mediacmd;
        print "return $state \n";
        my ( $cmd2, $val ) = split( /\s+ /, $state );
        my ( $ptr,  $cmd ) = split( /\s+/,  $val );
        if ( $cmd2 eq "*>" ) {
            print "cmd-$cmd :: val-$val :: ptr-$ptr :: cmd2-$cmd2 ::\n";
            $rtn = $ptr;
            print "We should return $cmd :: actually $rtn \n";
        }
    }
    return ($rtn);
}

# add to the current playlist (argument received is reference to array)
sub mhmedia_playlist_add {
    set $mediacmd 'mrl add $file';
}

# delete from the current playlist (argument received is reference to array)
sub mhmedia_playlist_delete {
    my $pos = shift;
    print_log "deleting track $pos";
    set $mediacmd 'playlist delete ($pos)';
}

# GET return an array reference to a list containing the current playlist
sub mhmedia_get_playlist_files {
    my $cntr = &mhmedia_get_playlist_length();
    set $mediacmd 'playlist show';
    select undef, undef, undef, .050;    # # Wait a while
    my @rtn = ();
    my $pos = 0;
    for ( $pos = 1, $pos < $cntr - 1, $pos++ ) {
        $state = said_next $mediacmd;
        print "return $state \n";
        my ( $cmd2, $val ) = split( /\s+ /, $state );
        my ( $ptr,  $cmd ) = split( /\s+/,  $val );
        print "cmd-$cmd :: val-$val :: ptr-$ptr :: cmd2-$cmd2 ::\n";
        push @rtn, $val;
        print "We should return $cmd :: actually \$rtn \n";
    }
    return \@rtn;
}

# GET return the time from the song in the playlist position
sub mhmedia_get_playlist_timestr {
    set $mediacmd 'get length';
    select undef, undef, undef, .050;    # # Wait a while
    $state = said_next $mediacmd;
    my ( $cmd, $val ) = split( /: /, $state );
    $val = $val / 1000;                  # make it seconds
    return ($val);
}

# GET return the title of the current song
sub mhmedia_get_playlist_title {
    my $cntr = &mhmedia_get_playlist_length();
    set $mediacmd 'playlist show';
    select undef, undef, undef, .050;    # # Wait a while
    my $rtn = 'No Playlist Title available';
    my $pos = 0;
    for ( $pos = 0, $pos < $cntr + 1, $pos++ ) {
        $state = said_next $mediacmd;
        print "return $state \n";
        my ( $cmd2, $val ) = split( /\s+ /, $state );
        my ( $ptr,  $cmd ) = split( /\s+/,  $val );
        if ( $cmd2 eq "*>" ) {
            print "cmd-$cmd :: val-$val :: ptr-$ptr :: cmd2-$cmd2 ::\n";
            $rtn = $cmd;
            print "We should return $cmd :: actually $rtn \n";
        }
    }
    return ($rtn);
}

# GET return the current volume
sub mhmedia_get_volume {
    set $mediacmd 'get audio volume';
    select undef, undef, undef, .050;    # # Wait a while
    $state = said_next $mediacmd;
    return ($state);
}

# GET return the elapsed time of current Track/clip
sub mhmedia_get_output_timestr {
    set $mediacmd 'get position';
    select undef, undef, undef, .050;    # # Wait a while
    $state = said_next $mediacmd;
    my ( $cmd, $val ) = split( /: /, $state );
    $val = $val / 1000;                  # make it seconds
    return ($val);
}

# GET return the number of entries in the current playlist
sub mhmedia_get_playlist_length {
    set $mediacmd 'playlist show';       #parse list

    #    my ($pos,$len,\@files )=&mhmedia_parse_playlist();
    my $len = 0;
    select undef, undef, undef, .050;    # # Wait a while
    while ( said_next $mediacmd ) {
        $len = $len + 1;

        #$state = said_next $mediacmd;
        print " Length $len $state\n";
    }
    return ($len);
}

# return if the player is running
sub mhmedia_playing {
    set $mediacmd 'get position';        # 0 = stopped
    select undef, undef, undef, .050;    # # Wait a while
    $state = said_next $mediacmd;
    my ( $cmd, $val ) = split( /: /, $state );
    if ( $val gt '1' ) { $val = '1'; }    # we only want to know yes or no
    return ($val);
}

sub mhmedia_running {

    # have we defined mhmedia_program
    if ( &net_socket_check("$mediahost") eq '1' ) {
        my $msg = "MediaPlayer: the player is on-line ";

        if (&mhmedia_playing) {
            print_log "$msg and is running";
            return 1;
        }
        else {
            print_log "$msg and available";
            return 0;
        }
    }
    else {
        print_log " MediaPlayer: media player is off-line !";
    }
}

#### This section contains 'common' routines, like playlist pares and return

=begin comment    



sub mhmedia_parse_playlist {    
    my @rtn = () ; 	# the list or 'No Playlist Title available';
    my $pos = 0 ;	#
    my $rptr = '' ;	# the current playing position
    my $len = ()
    
    while ( said_next $mediacmd ) {
    #for ( $pos = 0 , $pos < $cntr + 1 , $pos++ ) 	# loop to get the list
	$state = said_next $mediacmd;
	print "return $state \n";

	# cmd-is the filename, val-fn ,ptr-list number, cmd2- current selection
	my ( $cmd2, $val) = split ( /\s+ /,$state);  	# break ths line up
	my ( $ptr, $cmd) = split ( /\s+/,$val);
	push @rtn, $val ;				# save the filename
	if ( $cmd2 eq "*>") { $rptr = $ptr ; }		# look current for the marker
	$len++;						# ipdate teh xounter
    }
    return ($rptr, $len, \@rtn);





    else {
	print "MediaPlayer: control socket is DOWN, attempting to start";
	#start $mediacmd ;
	
	if ( active $mediacmd ) {
	    print_log "MediaPlayer: control socket is UP";
	    return 1;
	}
	return 0;
    }
    
}
=cut
