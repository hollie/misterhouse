=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	AlsaPlayer.pm

Description:
   Allows the full creation and control of alsaplayer processes on your
   system.  I use this with a M-Audio Delta 410 and the Linux ALSA drivers
   to create up to four simultaneous stereo MP3 streams.  I then connect
   those outputs to my Netstreams Musica whole-house audio system to
   provide customized music throughout my house.

Author:
	Kirk Bauer
	kirk@kaybee.org

License:
	This free software is licensed under the terms of the GNU public license.

Alsaplayer:
   This Misterhouse module assumes the 'alsaplayer' program is installed and
   operational as the Misterhouse user.  Since I run mine in real-time mode,
   and local security is not a big issue, I have my binary set setuid root
   (owned by root and mode 4555).  You can help improve performance by telling
   alsaplayer to not load ID3 tags from MP3s by modifying its configuration
   file (.alsaplayer/config in your home directory) and setting 'mad.parse_id3'
   to false.  

   NOTE: The setting of MAX_SONGS_AT_ONCE below will determine how many songs
   will be queued to Alsaplayer in one command.  Since the command doesn't
   return until the MP3s are all processed, setting the number too big will
   cause Misterhouse to pause while loading or changing playlists.  The value
   you should use depends on your system speed, whether or not Alsaplayer is
   parsing ID3 tags, and how fast your storage device is.

   You can change the default binary location and options by copying the
   following lines into your mh.private.ini:

      alsaplayer_binary=alsaplayer
      alsaplayer_opts= -q --nosave -i daemon -P

Example Usage:
   Note that you can have as many AlsaPlayer objects as you want but each
   one must have a unique alsa device name.

      use AlsaPlayer;
      my $mp3_player = new AlsaPlayer('alsa_device_name');

      use PlayList;
      my $kirk_mp3s = new PlayList;

      if ($Startup) {
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

   If you want randomized playlist, you can call the randomize() function on 
   the PlayList object before adding it to the player but after populating
   it with MP3s.  Instead (or in addition to), you can call shuffle(1) on 
   AlsaPlayer before adding any playlists.  This requires you to have patched
   your AlsaPlayer as described just above the shuffle function in this module.

Usage Details:
   States:
      You can watch for the following states from an AlsaPlayer object:
         new_song: Player just started playing a new song.
         playlist_loaded: Player just finished loading the current playlist

   Functions:
      start(): Starts the process and/or resumes playing
      stop(): Stops playing
      remove_all_playlists(): removes all PlayList objects (and pauses the player).
      add_playlist(obj): adds a PlayList object to this player's MP3 queue
      remove_playlist(obj): removes a PlayList object from this player's MP3 queue
      unpause(): Unpauses the player
      pause(): Pauses the player
      pause_toggle(): Pauses or unpauses the player
      is_paused(): Returns current paused status
      next_song(): Jump to the next song in the playlist
      previous_song(): Return to the previous song in the playlist
      volume(vol): Sets the volume ('1.0' is 100%) and/or returns the current volume.
      shuffle(bool): Turns shuffle on or off -- should set before adding the MP3s and
         this does require a patch to your AlsaPlayer as described below.
      get_album(): Returns the current album title (only if ID3 tags are set to be
         read in your alsaplayer config and the MP3 has ID3 tags).
      get_title(): Returns the current song title (if ID3 tags are set to be
         read in your alsaplayer config and the MP3 has ID3 tags) or the name of
         the current MP3.
      get_artist(): Returns the current artist name (only if ID3 tags are set to be
         read in your alsaplayer config and the MP3 has ID3 tags).

TODO:
   - Have not implemented seeking/jumping to points in a MP3 (--seek and --relative)
   - Have not implemented variable speed (--speed)
   - Have not implemented the ability to jump straight to a specific track (--jump)

Notes:
   - The alsaplayer processes are not stopped when Misterhouse exits, but you could
   kill them by running 'killall alsaplayer' upon shutdown.
   - Upon startup, 'killall alsaplayer' is run which will kill all currently running
   alsaplayer processes.

Special Thanks to: 
	Bruce Winter - Misterhouse

See Also:
   PlayList.pm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package AlsaPlayer;

@AlsaPlayer::ISA = ('Generic_Item');

use constant MAX_SESSIONS => 32;
use constant SCAN_FREQUENCY => 5;
use constant MAX_SONGS_AT_ONCE => 25;

my @sessions = ();
my $count = 0;
my @pending = ();

@AlsaPlayer::ISA = ('Generic_Item');

sub new
{
	my ($class, $channel) = @_;
	my $self={};
   $$self{'session'} = -1;
   $$self{'channel'} = $channel;
   $$self{'replace'} = 1;
   @{$$self{'queue'}} = ();
   @{$$self{'pending_playlist'}} = ();
	bless $self,$class;
   $count++;
   &::print_log("AlsaPlayer: creating object number $count"); 
   if ($count == 1) {
      &::print_log("AlsaPlayer: adding mainloop pre-hook"); 
      &::MainLoop_pre_add_hook(\&AlsaPlayer::_scan_sessions, 1);
      system("killall alsaplayer");
   }
   unless ($$self{'object_name'}) {
      $$self{'object_name'} = "instance$count";
   }
	return $self;
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
   unless (open(STATUS, "$::config_parms{alsaplayer_binary} --status -n $id|")) {
      &::print_log("AlsaPlayer: ERROR: Couldn't execute program '$::config_parms{alsaplayer_binary}'"); 
      return;
   }
   my $name = '';
   my ($key, $val);
   while (my $line = <STATUS>) {
      chomp($line);
      if (($key, $val) = ($line =~ /^([^:]+):\s+(.*)$/)) {
         if ($key eq 'name') {
            $name = $val;
         } elsif ($key eq 'volume') {
            $sessions[$id]->{'volume'} = $val;
         } elsif ($key eq 'speed') {
            $sessions[$id]->{'speed'} = $val;
         } elsif ($key eq 'artist') {
            $sessions[$id]->{'artist'} = $val;
         } elsif ($key eq 'album') {
            $sessions[$id]->{'album'} = $val;
         } elsif ($key eq 'title') {
            if ($sessions[$id]->{'title'} ne $val) {
               $sessions[$id]->{'title'} = $val;
               $sessions[$id]->set('new_song');
            }
         }
      }
   }
   close(STATUS);
   return $name;
}

sub _died {
   my ($self) = @_;
   if ($$self{'session'} >= 0) {
      &::print_log("AlsaPlayer($$self{object_name}): ERROR: process died"); 
   }
   $$self{'session'} = -1;
}

sub _send_cmd {
   my ($self, $cmd, $args) = @_;
   &::print_log("AlsaPlayer($$self{object_name}): about to execute '$cmd' with args '$args'"); 
   system("$::config_parms{alsaplayer_binary} -n $$self{'session'} --$cmd $args");
   &::print_log("AlsaPlayer($$self{object_name}): done executing '$cmd' with args '$args'"); 
}

sub _queue_cmd {
   my ($self, $cmd, $args) = @_;
   if (($$self{'session'} >= 0) and not @{$$self{'queue'}} and not $$self{'replace'}) {
      # Can do this now
      $self->_send_cmd($cmd, $args);
   } else {
      # Need to queue it...
      my $ref;
      $ref->[0] = $cmd;
      $ref->[1] = $args;
      &::print_log("AlsaPlayer($$self{object_name}): queueing '$cmd' with args '$args'"); 
      push @{$$self{'queue'}}, $ref;
   }
}

sub remove_all_playlists {
   my ($self) = @_;
   foreach (@{$$self{'playlists'}}) {
      $_->_unregister($self);
   }
   @{$$self{'playlists'}} = ();
}

sub add_playlist {
   my ($self, $playlist) = @_;
   push @{$$self{'playlists'}}, $playlist;
   $playlist->_register($self);
}

sub remove_playlist {
   my ($self, $playlist) = @_;
   for (my $i = 0; $i <= $#{$$self{'playlists'}}; $i++) {
      if ($$self{'playlists'}->[$i] eq $playlist) {
         $playlist->_unregister($self);
         splice @{$$self{'playlists'}}, $i, 1;
      }
   }
}

sub _add_playlist_files {
   my ($self, @files) = @_;
   foreach (@files) {
      $$self{'playlist'}->{$_}++;
      if ($$self{'playlist'}->{$_} == 1) {
         push @{$$self{'pending_playlist'}}, $_;
      }
   }
}

sub _remove_playlist_files {
   my ($self, @files) = @_;
   foreach (@files) {
      $$self{'playlist'}->{$_}--;
   }
   @{$$self{'pending_playlist'}} = ();
   foreach (keys %{$$self{'playlist'}}) {
      &::print_log("AlsaPlayer($$self{object_name}): removing '$_' from pending playlist"); 
      if ($$self{'playlist'}->{$_} > 0) {
         push @{$$self{'pending_playlist'}}, $_;
         &::print_log("AlsaPlayer($$self{object_name}): keeping '$_' in playlist"); 
      } else {
         delete $$self{'playlist'}->{$_};
      }
   }
   $$self{'replace'} = 1;
   unless (@{$$self{'pending_playlist'}}) {
      &::print_log("AlsaPlayer($$self{object_name}): no songs left in playlist... pausing."); 
      # No songs left... just pause it...
      $self->pause();
   }
}

sub _activated {
   my ($self, $id) = @_;
   &::print_log("AlsaPlayer($$self{object_name}): found ID: $id"); 
   $sessions[$id] = $self;
   $$self{'session'} = $id;
   $$self{'pending'} = 0;
}

sub _scan_sessions() {
   for (my $i = 0; $i < MAX_SESSIONS; $i++) {
      if ($sessions[$i]) {
         # Send one pending command...
         if (@{$sessions[$i]->{'queue'}} and not $sessions[$i]->{'replace'}) {
            &::print_log("AlsaPlayer($sessions[$i]->{object_name}): Replace=$sessions[$i]->{'replace'}");
            my $cmd = shift @{$sessions[$i]->{'queue'}};
            $sessions[$i]->_send_cmd($cmd->[0], $cmd->[1]);
            #sleep 15;
         } elsif (@{$sessions[$i]->{'pending_playlist'}}) {
            my $cmd = 'enqueue';
            if ($sessions[$i]->{'replace'}) {
               $sessions[$i]->{'paused'} = 0;
               &::print_log("AlsaPlayer($sessions[$i]->{object_name}): setting paused to 0 because replace is about to be called");
               $cmd = 'replace';
               $sessions[$i]->{'replace'} = 0;
            }
            my @songs = splice @{$sessions[$i]->{'pending_playlist'}}, 0, MAX_SONGS_AT_ONCE;
            if (@songs) {
               &::print_log("AlsaPlayer($sessions[$i]->{object_name}): adding $#songs songs with '$cmd'"); 
               system($::config_parms{alsaplayer_binary}, '-n', $sessions[$i]->{'session'}, "--$cmd", @songs);
               &::print_log("AlsaPlayer($sessions[$i]->{object_name}): system call returned"); 
               if ($sessions[$i]->{'shuffle'}) {
                  $sessions[$i]->_queue_cmd('shuffle');
               }
               unless (@{$sessions[$i]->{'pending_playlist'}}) {
                  $sessions[$i]->set('playlist_loaded');
               }
            }
            #sleep 15;
         } elsif (@{$sessions[$i]->{'queue'}}) {
            my $cmd = shift @{$sessions[$i]->{'queue'}};
            $sessions[$i]->_send_cmd($cmd->[0], $cmd->[1]);
            #sleep 15;
         }
      }
   }
   return unless ($::New_Second and (($::Second % SCAN_FREQUENCY) == 0));
   my $label = '';
   for (my $i = 0; $i < MAX_SESSIONS; $i++) {
      if ($sessions[$i]) {
         # Check status
         $label = &_get_status($i);
         unless ($label) {
            $sessions[$i]->_died();
            $sessions[$i] = 0;
         }
      } elsif (@pending) {
         if ($label = &_get_status($i)) {
            for (my $j = 0; $j <= $#pending; $j++) {
               if ($pending[$j]->{'object_name'} eq $label) {
                  $pending[$j]->_activated($i);
                  splice @pending, $j, 1;
               }
            }
         }
      }
   }
}

sub unpause {
   my ($self) = @_;
   if ($$self{'paused'} and not $$self{'replace'}) {
      $self->_queue_cmd('pause');
      $$self{'paused'} = 0;
      &::print_log("AlsaPlayer($$self{object_name}): setting paused to 0 in unpause()");
   }
}

sub is_paused {
   my ($self) = @_;
   return $$self{'paused'};
}

sub pause {
   my ($self) = @_;
   unless ($$self{'paused'}) {
      $self->_queue_cmd('pause');
      $$self{'paused'} = 1;
      &::print_log("AlsaPlayer($$self{object_name}): setting paused to 0 in pause()");
   }
}

sub pause_toggle {
   my ($self) = @_;
   $self->_queue_cmd('pause');
   $$self{'paused'} = not $$self{'paused'};
   &::print_log("AlsaPlayer($$self{object_name}): setting paused to $$self{paused} in pause_toggle()");
}

sub next_song {
   my ($self) = @_;
   $self->_queue_cmd('next');
}

sub previous_song {
   my ($self) = @_;
   $self->_queue_cmd('prev');
}

sub stop {
   my ($self) = @_;
   $self->_queue_cmd('stop');
}

sub volume {
   my ($self, $volume) = @_;
   if (defined($volume)) {
      $self->_queue_cmd('volume', $volume);
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
   my ($self, $shuffle) = @_;
   if (defined($shuffle)) {
      $$self{'shuffle'} = $shuffle;
      if ($shuffle) {
         $self->_queue_cmd('shuffle');
      }
   }
   return $$self{'shuffle'};
}

#sub _quote_str {
#   my ($str) = @_;
#   if ($str =~ /'/) {
#      $str =~ s/\\/\\\\/g;
#      $str =~ s/"/\\"/g;
#      $str =~ s/`/\\`/g;
#      $str =~ s/\$/\\\$/g;
#      return "\"$str\"";
#   } else {
#      return "'$str'";
#   }
#}

sub get_album {
   my ($self) = @_;
   return $$self{'album'};
}

sub get_title {
   my ($self) = @_;
   return $$self{'title'};
}

sub get_artist {
   my ($self) = @_;
   return $$self{'artist'};
}

sub start {
   my ($self) = @_;
   if (($$self{'session'} >= 0) or ($$self{'pending'})) {
      # Already running, so send in the --start command
      $self->_queue_cmd('start');
      return;
   }
   unless ($::config_parms{alsaplayer_binary}) {
      $::config_parms{alsaplayer_binary} = 'alsaplayer';
   }
   my $opts = $::config_parms{alsaplayer_opts};
   unless ($opts) {
      $opts = '-q --nosave -i daemon -P';
   }
   my $channel = '';
   if ($$self{'channel'}) {
      $channel = "-d $$self{'channel'}";
   }
   my $program = "$::config_parms{alsaplayer_binary} $opts -s '$$self{object_name}' -r $channel &";
   &::print_log("AlsaPlayer($$self{object_name}): About to execute: '$program'"); 
   unless (system($program) == 0) {
      &::print_log("AlsaPlayer($$self{object_name}): start() ERROR: Couldn't execute program '$program'"); 
      return;
   }
   $$self{'pending'} = 1;
   $$self{'replace'} = 1;
   &::print_log("AlsaPlayer($$self{object_name}): setting paused to 1 in start()");
   $$self{'paused'} = 1;
   push @pending, $self;
}

1;
