=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	PlayList.pm

Description:
   Object containing a list of music files.  Currently supports:
      1) MP3 files
      2) M3U files contaning lists of MP3 files
      3) Directories containing MP3 files

   Currently used by AlsaPlayer.pm on Linux.  Changes to the playlist
   are passed along to any AlsaPlayers that have the playlist currently
   attached.

Author:
	Kirk Bauer
	kirk@kaybee.org

   You can get the most current version of this file and other files related
   whole-house music/speech setup here:
     http://www.linux.kaybee.org:81/tabs/whole_house_audio/

License:
	This free software is licensed under the terms of the GNU public license.

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

Usage:
   add_files(list): Adds one or more .mp3, .m3u and/or directories to this
      playlist object (and any players with this object attached).
   remove_files(list): Removes one or more .mp3, .m3u and/or directories from
      this playlist object (and any players with this object attached).
   clear(): Empties this playlist.
   randomize(): Call only after you have added your MP3s... randomizes the
      order of all songs currently in the playlist.

Special Thanks to: 
	Bruce Winter - Misterhouse

See Also:
   AlsaPlayer.pm

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package PlayList;

sub new
{
	my ($class) = @_;
	my $self={};
   @{$$self{'list'}} = ();
	bless $self,$class;
	return $self;
}

sub _get_m3u {
   my ($file) = @_;
   my @ret = ();
   my $basename = $file;
   $basename =~ s/\/[^\/]+\.m3u$//;
   if (open (LIST, $file)) {
      while (my $line = <LIST>) {
         chomp($line);
         $line =~ s/\r$//;
         # Skip winamp extended info
         next if $line =~ /^#/;
         # Convert backslashes to forward-slashes
         $line =~ s=\\=/=g;
         unless ($line =~ /^\//) {
            $line = ($basename . '/' . $line);
         }
         push @ret, $line;
      }
      close(LIST);
   }
   return (@ret);
}

sub _get_dir {
   my ($dir) = @_;
   my @ret = ();
   my @dirs = ();
   if (opendir (DIR, $dir)) {
      while (my $entry = readdir(DIR)) {
         next if $entry =~ /^\./;
         if (-d $dir . '/' . $entry) {
            push @dirs, $dir . '/' . $entry;
         } elsif ($entry =~ /\.m3u$/) {
            push @ret, &_get_m3u($dir . '/' . $entry);
         } elsif ($entry =~ /\.mp3$/) {
            push @ret, "$dir/$entry";
         }
      }
      close(DIR);
   }
   foreach (@dirs) {
      push @ret, &_get_dir($_);
   }
   return (@ret);
}

sub _do_remove_files {
   my ($self, @files) = @_;
   foreach my $file (@files) {
      for (my $i = 0; $i <= $#{$$self{'list'}}; $i++) {
         if ($$self{'list'}->[$i] eq $file) {
            splice @{$$self{'list'}}, $i, 1;
         }
      }
   }
   foreach (@{$$self{'registrations'}}) {
      $_->_remove_playlist_files(@files);
   }
}

sub _register {
   my ($self, $ptr) = @_;
   $ptr->_add_playlist_files(@{$$self{'list'}});
   for (my $i = 0; $i <= $#{$$self{'registrations'}}; $i++) {
      if ($$self{'registrations'}->[$i] eq $ptr) {
         return;
      }
   }
   push @{$$self{'registrations'}}, $ptr;
}

sub _unregister {
   my ($self, $ptr) = @_;
   for (my $i = 0; $i <= $#{$$self{'registrations'}}; $i++) {
      if ($$self{'registrations'}->[$i] eq $ptr) {
         splice @{$$self{'registrations'}}, $i, 1;
      }
   }
   $ptr->_remove_playlist_files(@{$$self{'list'}});
}

sub add_files {
   my ($self, @files) = @_;
   my @new = ();
   foreach (@files) {
      if ($_ =~ /\.m3u$/) {
         push @new, &_get_m3u($_);
      } elsif (-d $_) {
         push @new, &_get_dir($_);
      } else {
         push @new, $_;
      }
   }
   if (@new) {
      push @{$$self{'list'}}, @new;
      foreach (@{$$self{'registrations'}}) {
         $_->_add_playlist_files(@new);
      }
   }
}

sub remove_files {
   my ($self, @files) = @_;
   my @remove = ();
   foreach (@files) {
      if ($_ =~ /\.m3u$/) {
         push @remove, &_get_m3u($_);
      } elsif (-d $_) {
         push @remove, &_get_dir($_);
      } else {
         push @remove, $_;
      }
   }
   if (@remove) {
      $self->_do_remove_files(@remove);
   }
}

sub clear {
   my ($self) = @_;
   $self->_do_remove_files(@{$$self{'list'}});
}

sub randomize {
   my ($self) = @_;
   my @orig_list = @{$$self{'list'}};
   @{$$self{'list'}} = ();
   while (@orig_list) {
      my $count = $#orig_list;
      my $random = int(rand($count + 1));
      push @{$$self{'list'}}, $orig_list[$random];
      splice @orig_list, $random, 1;
   }
}

1;
