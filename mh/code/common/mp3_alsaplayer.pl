
# Category=Music

#@ This script controls the alsaplayer MP3 player for Linux.  It requires
#@ AlsaPlayer.pm and handles operation of the mp3 player. Enable mp3.pl to 
#@ manage the MP3 database.  

=begin comment

You must have at least one Alsaplayer defined and assign it as the default
player by calling set_default_alsaplayer().

use AlsaPlayer;
my $mp3_player = new AlsaPlayer('mp3_player', 'alsa_device_name');

if ($Reload) {
   &set_default_alsaplayer($mp3_player);
}

=cut

use AlsaPlayer;

my $default;

sub set_default_alsaplayer {
   $default = $_[0];
}

$v_mp3_control_cmd = new Voice_Cmd("Set the house mp3 player to [Play,Stop,Pause,Restart,Next Song,Previous Song,Volume Down,Volume Up,Shuffle On,Shuffle Off,Repeat On,Repeat Off]");
my $state;
mp3_control($state) if $state = said $v_mp3_control_cmd;

sub mp3_control {
   my ($state, $player) = @_;
   $player = $default unless defined($player); 
   if ($state eq 'Play') {
      $player->start();
   } elsif ($state eq 'Stop') {
      $player->stop();
   } elsif ($state eq 'Pause') {
      $player->pause();
   } elsif ($state eq 'Next Song') {
      $player->next_song();
   } elsif ($state eq 'Previous Song') {
      $player->previous_song();
   } elsif ($state eq 'Volume Down') {
      my $vol = $player->volume;
      $vol -= 0.1;
      if ($vol < 0) {
         $vol = 0;
      }
      $player->volume($vol);
   } elsif ($state eq 'Volume Up') {
      my $vol = $player->volume;
      $vol += 0.1;
      if ($vol > 1) {
         $vol = 1;
      }
      $player->volume($vol);
   } elsif ($state eq 'Shuffle On') {
      $player->shuffle();
   }

   print_log "mp3 player set to " . said $v_mp3_control_cmd;
}

sub mp3_play {
   my ($file, $player) = @_;
   $player = $default unless defined($player); 
   $player->clear();
   $player->add_files($file);
   $player->start();
   print_log "mp3 play: $file";
}

sub mp3_queue {
   my ($file, $player) = @_;
   $player = $default unless defined($player); 
   $player->add_files($file);
   print_log "mp3 queue: $file";
}

sub mp3_clear {
   my ($file, $player) = @_;
   $player = $default unless defined($player); 
   $player->clear();
   print_log "mp3 playlist cleared";
}

sub mp3_get_playlist {
   my ($file, $player) = @_;
   $player = $default unless defined($player); 
   my @list = $player->get_playlist;
   return \@list;
}

# return the current volume 
sub mp3_get_volume {
   my ($file, $player) = @_;
   $player = $default unless defined($player); 
   return $player->volume;
}

# return the number of songs in the current playlist 
sub mp3_get_playlist_length { 
   my ($file, $player) = @_;
   $player = $default unless defined($player); 
   return $player->get_playlist_length();
}

# we don't support this function
sub mp3_get_playlist_pos { 
   return -1;
}

# returns the song that is currently playing
sub mp3_get_curr_song { 
   my ($file, $player) = @_;
   $player = $default unless defined($player); 
   return $player->get_title();
}

sub mp3_running {
   my ($file, $player) = @_;
   $player = $default unless defined($player); 
   return $player->is_okay();
}
