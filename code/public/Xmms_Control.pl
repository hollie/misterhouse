
#$Id$

# This script define some control function interacting with Xmms program
# It relies on the Xmms-Perl modules, this modules need to
# be installed on the system prior to run thoses subroutines.
# It's available from cpan.org

# the call to Xmms_Running, will try to start the program if not already
# &Xmms_Running;

# only other call to control Xmms
# the call receive a command, and an argument if needed
# here's the call list

# Here's the call list to basic function
# &XmmsControl("play");
# &XmmsControl("stop");
# &XmmsControl("pause");
# &XmmsControl("pause");
# &XmmsControl("clear");                           remove all the song from the current playlist
# &XmmsControl("volume","Volume_level");           set the volume level to volume_level
# &XmmsControl("volumeup"); increase the volume by 5
# &XmmsControl("volumedown"); decrease the volume by 5
# &XmmsControl("nextsong");  start playing the next song in the current playlist
# &XmmsControl("prevsong");  start playing the previous song in the current playlist
# &XmmsControl("set_playlist_pos","playlist_pos");  Jump to song at playlist_pos in the current playlist
# &XmmsControl("load_playlist_file","playlist_file");  Load a playlist file to the current playlist
# &XmmsControl("shuffle","on");  Will randomize the current playlist
# &XmmsControl("shuffle","off");  Will sort the current playlist

# here's the call list to query the system
# my $title = &XmmsControl("get_playlist_title");  return the name of the current song
# my $volume = &XmmsControl("get_volume");         return the volume level
# my $pos = &XmmsControl("get_playlist_pos");      return the current position in the playlist
# my $time = &XmmsControl("get_output_timestr");   return the current play time from the current song
# my $length = &XmmsControl("get_playlist_length"); return the length of the current song

# here's the call list to ease interface creation
# &XmmsControl("random"); Toggle the random bit
# &XmmsControl("playlist_add","playlist_file");
# &XmmsControl("get_playlist_files");
# &XmmsControl("get_playlist_timestr");
# &XmmsControl("get_playlist_titles");

sub Xmms_Running {
    use Xmms::Remote();
    my $remote = Xmms::Remote->new;

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

        #sleep 1 sec to let the process start
        sleep 1;
        $XmmsStatus = `/sbin/pidof $mp3_program`;
        chop $XmmsStatus;
        if ( $XmmsStatus eq "" ) {
            print_log "Can't start $mp3_program";
            return 0;
        }
        print_log "$mp3_program started";
    }
    return 1;
}

sub Xmms_Control {

    # this need to run with linux/xmms only
    if ( $^O ne "linux" ) {
        return NotUsingLinux();
    }

    my $PlaylistDir = $main::config_parms{mp3_playlist_dir};
    my $mp3_program = $main::config_parms{mp3_program};

    use Xmms;
    use Xmms::Remote();
    my $remote = Xmms::Remote->new;

    # this script expect to receive a single function call to control xmms
    # and an optional argument
    my ( $Cmd, $Arg ) = @_;
    $Cmd = lc($Cmd);

    #print_log "CMD=[$Cmd] ARG=[$Arg]\n";

    # if xmms is not running, we will start it
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

    # the Cmd received will then be pass to xmms
    CMD: {
        if ( $Cmd eq "play" )  { return $remote->play;  last CMD; }
        if ( $Cmd eq "stop" )  { return $remote->stop;  last CMD; }
        if ( $Cmd eq "pause" ) { return $remote->pause; last CMD; }
        if ( $Cmd eq "random" ) { return $remote->toggle_shuffle; }
        if ( $Cmd eq "clear" )  { return $remote->playlist_clear; last CMD; }
        if ( $Cmd eq "volume" ) { return $remote->set_volume($Arg); last CMD; }
        if ( $Cmd eq "get_playlist_title" ) {
            return $remote->get_playlist_title;
            last CMD;
        }
        if ( $Cmd eq "get_volume" ) { return $remote->get_volume; last CMD; }
        if ( $Cmd eq "get_playlist_pos" ) {
            return $remote->get_playlist_pos + 1;
            last CMD;
        }
        if ( $Cmd eq "get_output_timestr" ) {
            return $remote->get_output_timestr();
            last CMD;
        }
        if ( $Cmd eq "get_playlist_length" ) {
            return $remote->get_playlist_length();
            last CMD;
        }

        if ( $Cmd eq "volumeup" ) {
            my $Vol = $remote->get_volume;
            $Vol += 5;
            return $remote->set_volume($Vol);
            last CMD;
        }

        if ( $Cmd eq "volumedown" ) {
            my $Vol = $remote->get_volume;
            $Vol -= 5;
            return $remote->set_volume($Vol);
            last CMD;
        }

        if ( $Cmd eq "nextsong" ) {
            return $remote->set_playlist_pos( $remote->get_playlist_pos + 1 );
            last CMD;
        }

        if ( $Cmd eq "prevsong" ) {
            return $remote->set_playlist_pos( $remote->get_playlist_pos - 1 );
            last CMD;
        }

        # set current song to position
        if ( $Cmd eq "set_playlist_pos" ) {
            return $remote->set_playlist_pos($Arg);
            last CMD;
        }

        # add to the current playlist (argument received is reference to array)
        if ( $Cmd eq "playlist_add" ) {
            return $remote->playlist_add($Arg);
            last CMD;
        }

        # return an array reference to a list containing the current playlist
        if ( $Cmd eq "get_playlist_files" ) {
            return $remote->get_playlist_files;
            last CMD;
        }

        # return the time from the song in the playlist position
        if ( $Cmd eq "get_playlist_timestr" ) {
            return $remote->get_playlist_timestr($Arg);
            last CMD;
        }

        # return a reference to a list containing the playlist title
        if ( $Cmd eq "get_playlist_titles" ) {
            return $remote->get_playlist_titles;
            last CMD;
        }

        # load a playlist file, this is to ease the xmms-perl modules
        # which require a reference to a list, this is done in this call
        if ( $Cmd eq "load_playlist_file" ) {

            # arg contain dir and file seperated by /
            if ( -f "$Arg" ) {
                my @List;
                open PLAYLIST, "$Arg";
                while (<PLAYLIST>) {
                    push @List, $_;
                }
                Xmms_Control( "Playlist_Add", \@List );
                Xmms::sleep(0.25);
                print_log "Loading playlist $Arg\'";
                return 1;
            }
            else {
                print_log "$Arg is not a playlist file";
                return 0;
            }

        }

        # The xmms-perl toolkit doesn't provide any way to fetch
        # the true random status, but only a way to change the status.
        # this command will randomize the list (on), or sort it(off)
        if ( $Cmd eq "shuffle" ) {
            my $LIST = Xmms_Control("get_playlist_files");
            if ( $Arg eq "on" ) {

                # extract from Perl Cookbook 4.17
                my $i;
                for ( $i = @$LIST; --$i; ) {
                    my $j = int rand( $i + 1 );
                    next if $i == $j;
                    @$LIST[ $i, $j ] = @$LIST[ $j, $i ];
                }
            }
            elsif ( $Arg eq "off" ) {
                @$LIST = sort @$LIST;

            }
            Xmms_Control("clear");
            Xmms_Control( "Playlist_Add", $LIST );
            Xmms_Control("Play");
            return 0;
        }

        print_log "Invalid Xmms_Control command [$Cmd]";
        return 0;
    }

    print_log "Problem with Xmms_Control subroutine";
}

#$Log: Xmms_Control.pl,v $
#Revision 1.3  2004/02/01 19:24:20  winter
# - 2.87 release
#
