
=head1 B<AlsaPlayer>

=head2 SYNOPSIS

Note that you can have as many AlsaPlayer objects as you want but each one must have a unique alsa device name.

  use AlsaPlayer;
  my $mp3_player = new AlsaPlayer('mp3_player', 'alsa_device_name');

  use PlayList;
  my $kirk_mp3s = new PlayList;

  if ($Reload) {
    # Starts the Alsaplayer process
    $mp3_player->start();

    # Populate the playlist
    $kirk_mp3s->add_files('/mnt/mp3s/KirkAll.m3u');
    $kirk_mp3s->add_files('/mnt/mp3s/blah/blah.mp3');
    $kirk_mp3s->add_files('/mnt/mp3s/favorites/');

    # Start playing the MP3s
    $mp3_player->add_playlist($kirk_mp3s);
    $mp3_player->unpause();
  }

If you want randomized playlist, you can call the randomize() function on the PlayList object before adding it to the player but after populating it with MP3s.  Instead (or in addition to), you can call shuffle(1) on AlsaPlayer before adding any playlists.  This requires you to have patched your AlsaPlayer as described just above the shuffle function in this module.

=head2 DESCRIPTION

Allows the full creation and control of alsaplayer processes on your system.  I use this with a M-Audio Delta 410 and the Linux ALSA drivers to create up to four simultaneous stereo MP3 streams.  I then connect those outputs to my Netstreams Musica whole-house audio system to provide customized music throughout my house.

You can get the most current version of this file and other files related whole-house music/speech setup here: http://www.linux.kaybee.org:81/tabs/whole_house_audio/

Alsaplayer:

This Misterhouse module assumes the 'alsaplayer' program is installed and operational as the Misterhouse user.  Since I run mine in real-time mode, and local security is not a big issue, I have my binary set setuid root (owned by root and mode 4555).  You can help improve performance by telling alsaplayer to not load ID3 tags from MP3s by modifying its configuration file (.alsaplayer/config in your home directory) and setting 'mad.parse_id3' to false.  I do this when I'm running MP3s off of a network drive.

Usage Details:

Input States:  The object accepts the following input states:

 - next: Go to the next song
 - previous: Go to the previous song
 - pause: Pause the player
 - unpause: Resume the player

Output States: You can watch for the following states from an AlsaPlayer object:

 - new_song: Player just started playing a new song.
 - playlist_loaded: Player just finished loading the current playlist

TODO:

 - Have not implemented seeking/jumping to points in a MP3 (--seek and --relative)
 - Have not implemented variable speed (--speed)
 - Have not implemented the ability to jump straight to a specific track (--jump)

Notes:

 - The alsaplayer processes are not stopped when Misterhouse exits, but you could kill them by running 'killall alsaplayer' upon shutdown.  This module attempts to reconnect with players through restarts, but if there are problems you may want to do a 'killall alsaplayer' followed by a 'rm /tmp/alsaplayer*'.

Bugs:

 - Since the command-line of Alsaplayer only has '--pause' (toggle) and --play, this module attempts to keep track of the pause state, but sometimes it can get it wrong.  So, it is best to set up a remote or voice command to allow you to manually pause/resume the MP3s...
 - I believe the file ~/.alsaplayer/alsaplayer.m3u will mess things up and I recommend removing it before starting up Misterhouse.

Special Thanks to:  Bruce Winter - Misterhouse

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item C<start()> 

Starts the process and/or resumes playing

=item C<stop()>

Stops playing

=item C<remove_all_playlists()> 

removes all PlayList objects (and pauses the player).

=item C<add_playlist(obj)> 

adds a PlayList object to this player's MP3 queue

=item C<remove_playlist(obj)> 

removes a PlayList object from this player's MP3 queue

=item C<unpause()> 

Unpauses the player

=item C<pause()> 

Pauses the player

=item C<pause_toggle()> 

Pauses or unpauses the player

=item C<forward(seconds)> 

Jumps forward the specified number of seconds.

=item C<rewind(seconds)> 

Jumps back the specified number of seconds.

=item C<is_paused()> 

Returns current paused status

=item C<next_song()> 

Jump to the next song in the playlist

=item C<previous_song()> 

Return to the previous song in the playlist

=item C<volume(vol)> 

Sets the volume ('1.0' is 100%) and/or returns the current volume.

=item C<shuffle(bool)> 

Turns shuffle on or off -- should set before adding the MP3s and this does require a patch to your AlsaPlayer as described below.

=item C<get_album()> 

Returns the current album title (only if ID3 tags are set to be read in your alsaplayer config and the MP3 has ID3 tags).

=item C<get_title()> 

Returns the current song title (if ID3 tags are set to be read in your alsaplayer config and the MP3 has ID3 tags) or the name of the current MP3.

=item C<get_artist()> 

Returns the current artist name (only if ID3 tags are set to be read in your alsaplayer config and the MP3 has ID3 tags).

=item C<get_path()> 

Returns the filename of the song currently being played.

=item C<get_playlist_length()> 

Returns number of songs in playlist.

=item C<is_busy()> 

Returns true if one or more commands are waiting to be executed OR if songs are waiting to be added to the playlist.

=item C<add_files()> 

Adds arbitrary MP3s to this player

=item C<remove_files()> 

Removes arbitrary MP3s from this player

=item C<clear()> 

Removes all playlists and MP3s

=item C<get_playlist()> 

Returns current playlist

=item C<get_playlist_length()> 

Returns length current playlist

=item C<quit()> 

Shuts down the player (restart by calling start())

=item C<restart()> 

Restarts the player (I use this on my voice output channel... once I play MP3s on that output, until I restart alsaplayer aplay does not produce very good quality audio)

=cut

use strict;

package AlsaPlayer;

@AlsaPlayer::ISA = ('Generic_Item');

use constant MAX_SESSIONS   => 32;
use constant SCAN_FREQUENCY => 5;

my @sessions   = ();
my $count      = 0;
my @pending    = ();
my @check_once = ();

@AlsaPlayer::ISA = ('Generic_Item');

sub new {
    my ( $class, $name, $channel ) = @_;
    my $self = {};
    $$self{'control'}      = new Process_Item();
    $$self{'session'}      = -1;
    $$self{'channel'}      = $channel;
    $$self{'session_name'} = $name;
    $$self{'replace'}      = 1;
    $$self{'volume'}       = '1.00';
    @{ $$self{'queue'} }            = ();
    @{ $$self{'pending_playlist'} } = ();
    bless $self, $class;
    $count++;
    &::print_log("AlsaPlayer: creating object number $count")
      if $main::Debug{alsaplayer};

    if ( $count == 1 ) {
        &::print_log("AlsaPlayer: adding mainloop pre-hook")
          if $main::Debug{alsaplayer};
        &::MainLoop_pre_add_hook( \&AlsaPlayer::_scan_sessions, 1 );

        #      system("killall alsaplayer");
        unless ( $::config_parms{alsaplayer_binary} ) {
            $::config_parms{alsaplayer_binary} = 'alsaplayer';
        }
    }
    for ( my $i = 0; $i < MAX_SESSIONS; $i++ ) {
        if (    ( $sessions[$i] )
            and ( $sessions[$i]->{'session_name'} eq $name ) )
        {
            &::print_log("AlsaPlayer: session $name already at id $i")
              if $main::Debug{alsaplayer};
            $sessions[$i] = $self;
            $$self{'session'} = $i;
        }
    }
    unless ( $$self{'session'} >= 0 ) {
        push @check_once, $self;
    }
    return $self;
}

# Doesn't currently seem to be called upon code reload
sub DESTROY {
    my ($self) = @_;
    &::print_log("AlsaPlayer($$self{session_name}): Destructor called.");
    if ( $$self{'session'} >= 0 ) {
        if ( $sessions[ $$self{'session'} ] eq $self ) {
            &::print_log(
                "AlsaPlayer($$self{session_name}): Destructor unregistering session $$self{session}..."
            );
            $sessions[ $$self{'session'} ] = undef;
        }
    }
}

#---------------- Session ----------------
#name: kirk
#playlist_length: 992
#volume: 1.00
#speed: 100%
#-------------- Current Track ------------
#artist: Smashing Pumpkins
#title: Tonight Tonight
#album: Smashing Pumpkins
#path: /mnt/mp3s/02-Smashing_Pumpkins-Tonight_Tonight.mp3
#frames: 10432
#length: 272 seconds
#position: 26
#-----------------------------------------
# Without reading of ID3 tags only have:
#-------------- Current Track ------------
#title: 02-Smashing_Pumpkins-Tonight_Tonight.mp3
#frames: 9752
#length: 254 seconds
#position: 225
#-----------------------------------------
sub _get_status {
    my ($id) = @_;
    unless (
        open( STATUS, "$::config_parms{alsaplayer_binary} --status -n $id|" ) )
    {
        &::print_log(
            "AlsaPlayer: ERROR: Couldn't execute program '$::config_parms{alsaplayer_binary}'"
        );
        return;
    }
    my $name = '';
    my ( $key, $val );
    while ( my $line = <STATUS> ) {
        chomp($line);
        if ( ( $key, $val ) = ( $line =~ /^([^:]+):\s+(.*)$/ ) ) {
            if ( $key eq 'name' ) {
                $name = $val;
                if ( $sessions[$id]
                    and ( $sessions[$id]->{'session_name'} ne $val ) )
                {
                    # Sometimes if an alsaplayer dies another session is reported instead
                    # when using the same ID
                    $name = '';
                }
            }
            elsif ( $key eq 'speed' ) {
                if ( $sessions[$id] ) {
                    if (    ( $val eq '0%' )
                        and ( not $sessions[$id]->{'paused'} )
                        and ( not @{ $sessions[$id]->{'queue'} } ) )
                    {
                        if ( $sessions[$id]->{'playlist_length'} > 0 ) {
                            &::print_log(
                                "AlsaPlayer($sessions[$id]->{session_name}): Resuming because it is paused but shouldn't be"
                            ) if $main::Debug{alsaplayer};
                            $sessions[$id]->_queue_cmd('start');
                        }
                    }
                    elsif ( ( $val eq '100%' )
                        and ( $sessions[$id]->{'paused'} )
                        and ( not @{ $sessions[$id]->{'queue'} } ) )
                    {
                        &::print_log(
                            "AlsaPlayer($sessions[$id]->{session_name}): Pausing because it is playing but shouldn't be"
                        ) if $main::Debug{alsaplayer};
                        $sessions[$id]->_queue_cmd('pause');
                    }
                }
            }
            elsif ( ( $key eq 'frames' ) and ( $val == 0 ) ) {

                # Nothing playing... erase data
                if ( $sessions[$id] ) {
                    $sessions[$id]->{'artist'} = '';
                    $sessions[$id]->{'album'}  = '';
                    $sessions[$id]->{'title'}  = '';
                }
            }
            elsif ( $key eq 'volume' ) {
                if ( $sessions[$id] ) {
                    unless ( $sessions[$id]->{'volume'} == $val ) {
                        $sessions[$id]
                          ->_queue_cmd( 'volume', $sessions[$id]->{'volume'} );
                    }
                }
            }
            elsif ( $key eq 'speed' ) {
                $sessions[$id]->{'speed'} = $val if $sessions[$id];
            }
            elsif ( $key eq 'path' ) {
                $sessions[$id]->{'path'} = $val if $sessions[$id];
            }
            elsif ( $key eq 'artist' ) {
                $sessions[$id]->{'artist'} = $val if $sessions[$id];
            }
            elsif ( $key eq 'playlist_length' ) {
                if ( $sessions[$id] ) {
                    $sessions[$id]->{'playlist_length'} = $val;
                    $sessions[$id]->_rebuild_playlist() unless ( $val > 0 );
                }
            }
            elsif ( $key eq 'album' ) {
                $sessions[$id]->{'album'} = $val if $sessions[$id];
            }
            elsif ( $key eq 'title' ) {
                if ( $sessions[$id] ) {
                    if ( $sessions[$id]->{'title'} ne $val ) {
                        $sessions[$id]->{'title'} = $val;
                        $sessions[$id]->set_states_for_next_pass('new_song');
                        $sessions[$id]->{'album'} = '';
                    }
                }
            }
        }
    }
    close(STATUS);
    if ( $sessions[$id] ) {
        if (    ( $sessions[$id]->{'playlist_length'} > 0 )
            and ( not $sessions[$id]->{'title'} ) )
        {
            # Sometimes I notice that the playlist is loaded but no track is selected, so
            # jump to the first track...
            $sessions[$id]->_queue_cmd( 'jump', 1 );
        }
    }
    return $name;
}

sub _rebuild_playlist {
    my ($self) = @_;
    if ( keys %{ $$self{'playlist'} } ) {
        &::print_log("AlsaPlayer($$self{session_name}): _rebuild_playlist()")
          if $main::Debug{alsaplayer};
        $$self{'replace'} = 1;
        foreach ( keys %{ $$self{'playlist'} } ) {

            #&::print_log("AlsaPlayer($$self{session_name}): _rebuild_playlist(): $_") if $main::Debug{alsaplayer};
            push @{ $$self{'pending_playlist'} }, $_;
        }
    }
}

sub _reconnect {
    my ($self) = @_;
    &::print_log(
        "AlsaPlayer($$self{session_name}): _reconnect(): session=$$self{'session'}, pending=$$self{'pending'}"
    ) if $main::Debug{alsaplayer};
    &::print_log(
        "AlsaPlayer($$self{session_name}): trying to restart and reconnect...");
    $self->start();
    $self->_rebuild_playlist();
}

sub _died {
    my ($self) = @_;
    &::print_log(
        "AlsaPlayer($$self{session_name}): _died(): session=$$self{'session'}, pending=$$self{'pending'}"
    ) if $main::Debug{alsaplayer};
    if ( $$self{'session'} >= 0 ) {
        unless ( $$self{'halted'} or $$self{'restarted'} ) {
            &::print_log(
                "AlsaPlayer($$self{session_name}): ERROR: process died...");
        }
        $$self{'restarted'} = 0;
        $sessions[ $$self{'session'} ] = undef;

        # Delete old socket file...
        system("rm -f /tmp/alsaplayer_*_$$self{session}");
        $$self{'control'}->stop();
        $$self{'session'} = -1;
        $$self{'pending'} = 0;
        if ( $$self{'object_name'} and not $$self{'halted'} ) {
            &::print_log(
                "AlsaPlayer($$self{session_name}): Scheduling a restart...");
            $$self{'reconnect_timer'} = new Timer;
            $$self{'reconnect_timer'}
              ->set( 5, "$$self{object_name}->_reconnect()" );
        }
    }
}

sub _send_cmd {
    my ( $self, $cmd, $args ) = @_;
    &::print_log(
        "AlsaPlayer($$self{session_name}): about to execute '$cmd' with args '$args'"
    ) if $main::Debug{alsaplayer};
    system(
        "$::config_parms{alsaplayer_binary} -n $$self{'session'} --$cmd $args");
    &::print_log(
        "AlsaPlayer($$self{session_name}): done executing '$cmd' with args '$args'"
    ) if $main::Debug{alsaplayer};
}

sub _queue_cmd {
    my ( $self, $cmd, $args ) = @_;
    if (    ( $$self{'session'} >= 0 )
        and not @{ $$self{'queue'} }
        and not $$self{'replace'} )
    {
        # Can do this now
        $self->_send_cmd( $cmd, $args );
    }
    else {
        # Need to queue it...
        my $ref;
        $ref->[0] = $cmd;
        $ref->[1] = $args;
        &::print_log(
            "AlsaPlayer($$self{session_name}): queueing '$cmd' with args '$args'"
        ) if $main::Debug{alsaplayer};
        push @{ $$self{'queue'} }, $ref;
    }
}

sub clear {
    my ($self) = @_;
    $self->remove_all_playlists();
    $self->_queue_cmd('clear');
    $$self{'replace'} = 1;
    %{ $$self{'playlist'} }         = ();
    @{ $$self{'pending_playlist'} } = ();
    &::print_log("AlsaPlayer($$self{session_name}): clear()")
      if $main::Debug{alsaplayer};
}

sub remove_all_playlists {
    my ($self) = @_;
    foreach ( @{ $$self{'playlists'} } ) {
        $_->_unregister($self);
    }
    @{ $$self{'playlists'} } = ();
}

sub add_files {
    my ( $self, @songs ) = @_;
    my @mp3s = ();
    foreach (@songs) {
        if (/\.m3u$/) {
            require PlayList;
            push @mp3s, ( PlayList::_get_m3u($_) );
        }
        else {
            push @mp3s, $_;
        }
    }
    print "Got here: @mp3s\n";
    $self->_add_playlist_files(@mp3s);
}

sub remove_files {
    my ( $self, @songs ) = @_;
    $self->_remove_playlist_files(@songs);
}

sub add_playlist {
    my ( $self, $playlist ) = @_;
    push @{ $$self{'playlists'} }, $playlist;
    $playlist->_register($self);
}

sub remove_playlist {
    my ( $self, $playlist ) = @_;
    for ( my $i = 0; $i <= $#{ $$self{'playlists'} }; $i++ ) {
        if ( $$self{'playlists'}->[$i] eq $playlist ) {
            $playlist->_unregister($self);
            splice @{ $$self{'playlists'} }, $i, 1;
        }
    }
}

sub set {
    my ( $self, $state ) = @_;
    &::print_log("AlsaPlayer($$self{'session_name'}): got state: $state")
      if $main::Debug{alsaplayer};
    if ( $state eq 'next' ) {
        $self->next_song();
    }
    elsif ( $state eq 'previous' ) {
        $self->previous_song();
    }
    elsif ( $state eq 'pause' ) {
        $self->pause();
    }
    elsif ( $state eq 'unpause' ) {
        $self->unpause();
    }
}

sub get_playlist_length {
    my ($self) = @_;
    return ( $$self{'playlist_length'} );
}

sub get_playlist {
    my ($self) = @_;
    return ( keys %{ $$self{'playlist'} }, @{ $$self{'pending_playlist'} } );
}

sub _add_playlist_files {
    my ( $self, @files ) = @_;
    foreach (@files) {
        $$self{'playlist'}->{$_}++;
        if ( $$self{'playlist'}->{$_} == 1 ) {

            #&::print_log("AlsaPlayer($$self{'session_name'}): adding to pending playlist: $_") if $main::Debug{alsaplayer};
            push @{ $$self{'pending_playlist'} }, $_;
            if ( $$self{'replace'} ) {

                #            unless ($$self{'paused'} == 0) {
                #               $$self{'paused'} = 0;
                #               &::print_log("AlsaPlayer($$self{session_name}): setting paused to 0 because replace is about to be called (after add)") if $main::Debug{alsaplayer};
                #            }
            }
        }
    }
}

sub _remove_playlist_files {
    my ( $self, @files ) = @_;
    foreach (@files) {
        $$self{'playlist'}->{$_}--;
    }
    @{ $$self{'pending_playlist'} } = ();
    foreach ( keys %{ $$self{'playlist'} } ) {
        &::print_log(
            "AlsaPlayer($$self{session_name}): removing '$_' from pending playlist"
        ) if $main::Debug{alsaplayer};
        if ( $$self{'playlist'}->{$_} > 0 ) {
            push @{ $$self{'pending_playlist'} }, $_;
            &::print_log(
                "AlsaPlayer($$self{session_name}): keeping '$_' in playlist")
              if $main::Debug{alsaplayer};
        }
        else {
            delete $$self{'playlist'}->{$_};
        }
    }
    $$self{'replace'} = 1;
    if ( @{ $$self{'pending_playlist'} } ) {

        #      $$self{'paused'} = 0;
        #      &::print_log("AlsaPlayer($$self{session_name}): setting paused to 0 because replace is about to be called (after remove)") if $main::Debug{alsaplayer};
    }
    else {
        &::print_log(
            "AlsaPlayer($$self{session_name}): no songs left in playlist... pausing."
        ) if $main::Debug{alsaplayer};

        # No songs left... just pause it...
        $self->pause();
    }
}

sub _reattached {
    my ( $self, $id ) = @_;
    &::print_log("AlsaPlayer($$self{session_name}): reattached to ID: $id");
    $sessions[$id]    = $self;
    $$self{'session'} = $id;
    $$self{'pending'} = 0;
    @{ $$self{'queue'} } = ();
    $self->_queue_cmd('stop');
}

sub is_okay {
    my ($self) = @_;
    return 0 if ( $$self{'pending'} );
    return 1 if ( $$self{'session'} >= 0 );
}

sub _activated {
    my ( $self, $id ) = @_;
    &::print_log("AlsaPlayer($$self{session_name}): found ID: $id");
    $sessions[$id]    = $self;
    $$self{'session'} = $id;
    $$self{'pending'} = 0;
}

sub is_busy() {
    my ($self) = @_;
    if ( @{ $$self{'queue'} } ) {
        return 1;
    }
    elsif ( @{ $$self{'pending_playlist'} } ) {
        return 1;
    }
    return 0;
}

sub _quote_str {
    my ($str) = @_;
    if ( $str =~ /'/ ) {
        $str =~ s/\\/\\\\/g;
        $str =~ s/"/\\"/g;
        $str =~ s/`/\\`/g;
        $str =~ s/\$/\\\$/g;
        return "\"$str\"";
    }
    else {
        return "'$str'";
    }
}

sub _scan_sessions() {
    for ( my $i = 0; $i < MAX_SESSIONS; $i++ ) {
        if ( $sessions[$i] ) {

            # Send one pending command...
            if ( @{ $sessions[$i]->{'queue'} }
                and not $sessions[$i]->{'replace'} )
            {
                &::print_log(
                    "AlsaPlayer($sessions[$i]->{session_name}): Replace=$sessions[$i]->{'replace'}"
                ) if $main::Debug{alsaplayer};
                my $cmd = shift @{ $sessions[$i]->{'queue'} };
                $sessions[$i]->_send_cmd( $cmd->[0], $cmd->[1] );
            }
            elsif ( ( @{ $sessions[$i]->{'pending_playlist'} } )
                and $sessions[$i]->{'control'}->done() )
            {
                my $cmd = 'enqueue';
                if ( $sessions[$i]->{'replace'} ) {
                    $cmd = 'replace';
                    $sessions[$i]->{'replace'} = 0;
                }
                my $songs = '';
                my $song;
                &::print_log(
                    "AlsaPlayer($sessions[$i]->{session_name}): before: pending playlist has $#{$sessions[$i]->{'pending_playlist'}} entries"
                ) if $main::Debug{alsaplayer};
                while ( $song = shift @{ $sessions[$i]->{'pending_playlist'} } )
                {
                    $songs .= ' ' . &_quote_str($song);

                    #               &::print_log("AlsaPlayer($sessions[$i]->{session_name}): adding song: $song");
                    if (   ( length $songs > 4000 )
                        or
                        ( ( length $songs > 500 ) and ( $cmd eq 'replace' ) ) )
                    {
                        last;
                    }
                }
                &::print_log(
                    "AlsaPlayer($sessions[$i]->{session_name}): after: pending playlist has $#{$sessions[$i]->{'pending_playlist'}} entries"
                ) if $main::Debug{alsaplayer};
                if ($songs) {

                    #&::print_log("AlsaPlayer($sessions[$i]->{session_name}): adding songs with '$cmd': $songs") if $main::Debug{alsaplayer};
                    $sessions[$i]->{'control'}->set(
                        "$::config_parms{alsaplayer_binary} -n '$sessions[$i]->{'session'}' --$cmd $songs"
                    );
                    $sessions[$i]->{'control'}->start();
                    unless ( @{ $sessions[$i]->{'pending_playlist'} } ) {
                        if ( $sessions[$i]->{'shuffle'} ) {
                            $sessions[$i]->_queue_cmd('shuffle');
                        }
                        $sessions[$i]->set('playlist_loaded');
                        &::print_log(
                            "AlsaPlayer($sessions[$i]->{session_name}): playlist has been loaded: paused=$sessions[$i]->{paused}"
                        ) if $main::Debug{alsaplayer};
                    }
                }
            }
            elsif ( @{ $sessions[$i]->{'queue'} } ) {
                my $cmd = shift @{ $sessions[$i]->{'queue'} };
                $sessions[$i]->_send_cmd( $cmd->[0], $cmd->[1] );
            }
        }
    }
    return unless ( $::New_Second and ( ( $::Second % SCAN_FREQUENCY ) == 0 ) );
    my $label = '';
    for ( my $i = 0; $i < MAX_SESSIONS; $i++ ) {
        if ( $sessions[$i] ) {

            # Check status
            $label = &_get_status($i);
            unless ($label) {
                $sessions[$i]->_died();
                $sessions[$i] = undef;
            }
        }
        unless ( $sessions[$i] ) {
            if ( @pending or @check_once ) {
                if ( $label = &_get_status($i) ) {
                    &::print_log(
                        "AlsaPlayer: scanned id $i and found label: $label")
                      if $main::Debug{alsaplayer};
                    if (@pending) {
                        for ( my $j = 0; $j <= $#pending; $j++ ) {
                            if ( $pending[$j]->{'session_name'} eq $label ) {
                                $pending[$j]->_activated($i);
                                splice @pending, $j, 1;
                            }
                        }
                    }
                    if (@check_once) {
                        for ( my $j = 0; $j <= $#check_once; $j++ ) {
                            if ( $check_once[$j]->{'session_name'} eq $label ) {
                                $check_once[$j]->_reattached($i);
                                splice @check_once, $j, 1;
                            }
                        }
                    }
                }
            }
        }
    }
    my @start = @check_once;
    @check_once = ();
    foreach (@start) {
        &::print_log(
            "AlsaPlayer($$_{session_name}): did not find process already running..."
        ) if $main::Debug{alsaplayer};
        if ( $$_{'pending'} ) {
            $$_{'pending'} = 0;
            $_->start();
        }
    }
}

sub unpause {
    my ($self) = @_;
    $self->_queue_cmd('start');
    $$self{'paused'} = 0;
    &::print_log(
        "AlsaPlayer($$self{session_name}): setting paused to 0 in unpause()")
      if $main::Debug{alsaplayer};
}

sub is_paused {
    my ($self) = @_;
    return $$self{'paused'};
}

sub pause {
    my ($self) = @_;
    unless ( $$self{'paused'} ) {
        $self->_queue_cmd('pause');
        $$self{'paused'} = 1;
        &::print_log(
            "AlsaPlayer($$self{session_name}): setting paused to 1 in pause()")
          if $main::Debug{alsaplayer};
    }
}

sub pause_toggle {
    my ($self) = @_;
    $self->_queue_cmd('pause');
    $$self{'paused'} = not $$self{'paused'};
    &::print_log(
        "AlsaPlayer($$self{session_name}): setting paused to $$self{paused} in pause_toggle()"
    ) if $main::Debug{alsaplayer};
}

sub next_song {
    my ($self) = @_;
    $self->_queue_cmd('next');
}

sub previous_song {
    my ($self) = @_;
    $self->_queue_cmd('prev');
}

sub forward {
    my ( $self, $seconds ) = @_;
    if ( $seconds > 0 ) {
        $self->_queue_cmd( 'relative', $seconds );
    }
    else {
        &::print_log(
            "AlsaPlayer($$_{session_name}): forward($seconds): Invalid parameter"
        );
    }
}

sub rewind {
    my ( $self, $seconds ) = @_;
    if ( $seconds > 0 ) {
        $self->_queue_cmd( 'relative', -$seconds );
    }
    else {
        &::print_log(
            "AlsaPlayer($$_{session_name}): rewind($seconds): Invalid parameter"
        );
    }
}

sub stop {
    my ($self) = @_;
    $self->_queue_cmd('stop');
    $$self{'paused'} = 1;
}

sub volume {
    my ( $self, $volume ) = @_;
    if ( defined($volume) ) {
        $self->_queue_cmd( 'volume', $volume );
        $$self{'volume'} = $volume;
    }
    return $$self{'volume'};
}

=cut

At least with Alsaplayer 0.99.76, there was no command-line
option to enable shuffle-mode.  So this patch will add one:

--- app/Main.orig       2004-03-15 12:24:37.000000000 -0700
+++ app/Main.cpp        2004-03-15 12:25:25.000000000 -0700
@@ -291,6 +291,7 @@
                "  --volume vol          set software volume [0.0-1.0]\n"
                "  --start               start playing\n"
                "  --stop                stop playing\n"
+               "  --shuffle             shuffle playlist\n"
                "  --pause               pause/unpause playing\n"
                "  --prev                jump to previous track\n"
                "  --next                jump to next track\n"
@@ -363,6 +364,7 @@
        int do_remote_control = 0;
        int do_start = 0;
        int do_stop = 0;
+       int do_shuffle = 0;
        int do_prev = 0;
        int do_next = 0;
        int do_pause = 0;
@@ -415,6 +417,7 @@
                { "crossfade", 0, 0, 'x' },
                { "output", 1, 0, 'o' },
                { "stop", 0, 0, 'U' },
+               { "shuffle", 0, 0, '!' },
                { "pause", 0, 0, 'O' },
                { "start", 0, 0, 'T' },
                { "prev", 0, 0, 'Q' },
@@ -582,6 +585,10 @@
                        case 'I':
                                global_interface_script = optarg;
                                break;
+                       case '!':
+                               do_remote_control = 1;
+                               do_shuffle = 1;
+                               break;
                        case 'U':
                                do_remote_control = 1;
                                do_stop = 1;
=cut

# Turning shuffle off only applies after the playlist is replaced
sub shuffle {
    my ( $self, $shuffle ) = @_;
    if ( defined($shuffle) ) {
        $$self{'shuffle'} = $shuffle;
        if ($shuffle) {
            $self->_queue_cmd('shuffle');
        }
    }
    return $$self{'shuffle'};
}

sub get_album {
    my ($self) = @_;
    return $$self{'album'};
}

sub get_path {
    my ($self) = @_;
    return $$self{'path'};
}

sub get_title {
    my ($self) = @_;
    return $$self{'title'};
}

sub get_artist {
    my ($self) = @_;
    return $$self{'artist'};
}

sub halt {
    my ($self) = @_;
    $$self{'halted'} = 1;
    $self->_queue_cmd('quit');
}

sub restart {
    my ($self) = @_;
    $$self{'restarted'} = 1;
    $self->_queue_cmd('quit');
}

sub start {
    my ($self) = @_;
    &::print_log(
        "AlsaPlayer($$self{session_name}): start(): session=$$self{'session'}, pending=$$self{'pending'}"
    ) if $main::Debug{alsaplayer};
    if ( ( $$self{'session'} >= 0 ) or ( $$self{'pending'} ) ) {

        # Already running, so send in the --start command
        $self->_queue_cmd('start');
        $$self{'paused'} = 0;
        &::print_log(
            "AlsaPlayer($$self{session_name}): setting paused to 0 in start()")
          if $main::Debug{alsaplayer};
        return;
    }
    $$self{'halted'} = 0;
    for ( my $k = 0; $k <= $#check_once; $k++ ) {
        if ( $self eq $check_once[$k] ) {

            # Wait to check if the process is already running...
            &::print_log(
                "AlsaPlayer($$self{session_name}): waiting to see if process is already running..."
            ) if $main::Debug{alsaplayer};
            $$self{'pending'} = 1;
            return;
        }
    }
    my $opts = $::config_parms{alsaplayer_opts};
    unless ($opts) {
        $opts = '-r -q --nosave -i daemon -P';
    }
    my $channel = '';
    if ( $$self{'channel'} ) {
        $channel = "-d $$self{'channel'}";
    }
    my $program =
      "$::config_parms{alsaplayer_binary} $opts -s '$$self{session_name}' -r $channel &";
    &::print_log(
        "AlsaPlayer($$self{session_name}): About to execute: '$program'")
      if $main::Debug{alsaplayer};
    unless ( system($program) == 0 ) {
        &::print_log(
            "AlsaPlayer($$self{session_name}): start() ERROR: Couldn't execute program '$program'"
        );
        return;
    }
    $$self{'pending'} = 1;
    $$self{'replace'} = 1;
    &::print_log(
        "AlsaPlayer($$self{session_name}): setting paused to 1 in start()")
      if $main::Debug{alsaplayer};

    #   $$self{'paused'} = 1;
    push @pending, $self;
    for ( my $k = 0; $k <= $#check_once; $k++ ) {
        if ( $self eq $check_once[$k] ) {
            splice @check_once, $k, 1;
        }
    }
}

1;

=back

=head2 INI PARAMETERS

You can change the default binary location and options by copying the following lines into your mh.private.ini:

  alsaplayer_binary=alsaplayer
  alsaplayer_opts= -q --nosave -i daemon -P

=head2 AUTHOR

Kirk Bauer
kirk@kaybee.org

=head2 SEE ALSO

B<PlayList.pm>

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

