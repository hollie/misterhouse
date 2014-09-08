
=head1 B<PlayList>

=head2 SYNOPSIS

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

=head2 DESCRIPTION

Object containing a list of music files.  Currently supports:

  1) MP3 files
  2) M3U files contaning lists of MP3 files
  3) Directories containing MP3 files

Currently used by AlsaPlayer.pm on Linux.  Changes to the playlist
are passed along to any AlsaPlayers that have the playlist currently
attached.

You can get the most current version of this file and other files related
whole-house music/speech setup here:

  http://www.linux.kaybee.org:81/tabs/whole_house_audio/

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

use strict;

package PlayList;

sub new {
    my ($class) = @_;
    my $self = {};
    @{ $$self{'list'} } = ();
    bless $self, $class;
    return $self;
}

sub _get_m3u {
    my ($file)   = @_;
    my @ret      = ();
    my $basename = $file;
    $basename =~ s/\/[^\/]+\.m3u$//;
    if ( open( LIST, $file ) ) {
        while ( my $line = <LIST> ) {
            chomp($line);
            $line =~ s/\r$//;

            # Skip winamp extended info
            next if $line =~ /^#/;

            # Convert backslashes to forward-slashes
            $line =~ s=\\=/=g;
            unless ( $line =~ /^\// ) {
                $line = ( $basename . '/' . $line );
            }
            push @ret, $line;
        }
        close(LIST);
    }
    return (@ret);
}

sub _get_dir {
    my ( $dir, $ext ) = @_;
    my @ret  = ();
    my @dirs = ();
    if ( opendir( DIR, $dir ) ) {
        while ( my $entry = readdir(DIR) ) {
            next if $entry =~ /^\./;
            if ( -d $dir . '/' . $entry ) {
                push @dirs, $dir . '/' . $entry;
            }
            elsif ( ( $entry =~ /\.m3u$/ )
                and ( not $ext or ( $ext eq 'm3u' ) ) )
            {
                push @ret, &_get_m3u( $dir . '/' . $entry );
            }
            elsif ( ( $entry =~ /\.mp3$/ )
                and ( not $ext or ( $ext eq 'mp3' ) ) )
            {
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
    my ( $self, @files ) = @_;
    foreach my $file (@files) {
        for ( my $i = 0; $i <= $#{ $$self{'list'} }; $i++ ) {
            if ( $$self{'list'}->[$i] eq $file ) {
                splice @{ $$self{'list'} }, $i, 1;
            }
        }
    }
    foreach ( @{ $$self{'registrations'} } ) {
        $_->_remove_playlist_files(@files);
    }
}

sub _register {
    my ( $self, $ptr ) = @_;
    $ptr->_add_playlist_files( @{ $$self{'list'} } );
    for ( my $i = 0; $i <= $#{ $$self{'registrations'} }; $i++ ) {
        if ( $$self{'registrations'}->[$i] eq $ptr ) {
            return;
        }
    }
    push @{ $$self{'registrations'} }, $ptr;
}

sub _unregister {
    my ( $self, $ptr ) = @_;
    for ( my $i = 0; $i <= $#{ $$self{'registrations'} }; $i++ ) {
        if ( $$self{'registrations'}->[$i] eq $ptr ) {
            splice @{ $$self{'registrations'} }, $i, 1;
        }
    }
    $ptr->_remove_playlist_files( @{ $$self{'list'} } );
}

sub _add_files {
    my ( $self, $ext, @files ) = @_;
    my @new = ();
    foreach (@files) {
        if ( ( $_ =~ /\.m3u$/ ) and ( not $ext or ( $ext eq 'm3u' ) ) ) {
            push @new, &_get_m3u( $_, $ext );
        }
        elsif ( -d $_ ) {
            push @new, &_get_dir( $_, $ext );
        }
        else {
            push @new, $_;
        }
    }
    if (@new) {
        push @{ $$self{'list'} }, @new;
        foreach ( @{ $$self{'registrations'} } ) {
            $_->_add_playlist_files(@new);
        }
    }
}

=item C<add_files(list)>

Adds one or more .mp3, .m3u and/or directories to this
playlist object (and any players with this object attached).

=cut

sub add_files {
    my ( $self, @files ) = @_;
    $self->_add_files( '', @files );
}

=item C<add_mp3_files(list)>

Adds one or more .mp3 files and/or directories to this
playlist object (and any players with this object attached).

=cut

sub add_mp3_files {
    my ( $self, @files ) = @_;
    $self->_add_files( 'mp3', @files );
}

=item C<add_m3u_files(list)>

Adds the contents of any m3u files that are specified
or that are found in a directory (recursively) that was specified.

=cut

sub add_m3u_files {
    my ( $self, @files ) = @_;
    $self->_add_files( 'm3u', @files );
}

=item C<remove_files(list)>

Removes one or more .mp3, .m3u and/or directories from
this playlist object (and any players with this object attached).

=cut

sub remove_files {
    my ( $self, @files ) = @_;
    my @remove = ();
    foreach (@files) {
        if ( $_ =~ /\.m3u$/ ) {
            push @remove, &_get_m3u($_);
        }
        elsif ( -d $_ ) {
            push @remove, &_get_dir($_);
        }
        else {
            push @remove, $_;
        }
    }
    if (@remove) {
        $self->_do_remove_files(@remove);
    }
}

=item C<clear()>

Empties this playlist.

=cut

sub clear {
    my ($self) = @_;
    $self->_do_remove_files( @{ $$self{'list'} } );
}

=item C<randomize_by_dir()>

Call only after you have added your MP3s... randomizes the
order of songs by directory -- i.e. first it determines all of the
directories, and then randomly picks one, and then another, etc.  Note
that the MP3 list is sorted in this process, so I'd recomment beginning
your MP3 names with the track number on each CD -- i.e. 01-xx.mp3.  I use
this to basically sort by directory.

=cut

sub randomize_by_dir {
    my ($self) = @_;
    my @orig_list = sort @{ $$self{'list'} };
    my @dirlist;
    @{ $$self{'list'} } = ();
    my $lastdir = '';
    foreach (@orig_list) {

        # First, get list of directories...
        my $dir = $_;
        $dir =~ s/\/[^\/]+$//;
        $dir =~ s/-Disc_\d$//;
        unless ( $dir eq $lastdir ) {
            $lastdir = $dir;
            push @dirlist, $dir;
        }
    }
    while (@dirlist) {
        my $random_num = int( rand( $#dirlist + 1 ) );
        my $random_dir = $dirlist[$random_num];
        for ( my $i = 0; $i <= $#orig_list; $i++ ) {
            if ( $orig_list[$i] =~ /^\Q$random_dir\E(-Disc_\d)?\// ) {
                push @{ $$self{'list'} }, $orig_list[$i];
            }
        }
        splice @dirlist, $random_num, 1;
    }
}

=item C<randomize()>

Call only after you have added your MP3s... randomizes the
order of all songs currently in the playlist.

=cut

sub randomize {
    my ($self) = @_;
    my @orig_list = @{ $$self{'list'} };
    @{ $$self{'list'} } = ();
    while (@orig_list) {
        my $random = int( rand( $#orig_list + 1 ) );
        push @{ $$self{'list'} }, $orig_list[$random];
        splice @orig_list, $random, 1;
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Kirk Bauer  kirk@kaybee.org

Special Thanks to:  Bruce Winter - Misterhouse

=head2 SEE ALSO

AlsaPlayer.pm

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

