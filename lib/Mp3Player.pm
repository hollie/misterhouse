
=head1 B<Mp3Player>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Provides an object-based interface for all MP3 players.  Code for the different players should be moved into this object eventually (no need for four mutually exclusive common code modules.)

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#!/usr/bin/perl

use strict;

package Mp3Player;
@Mp3Player::ISA = ('Generic_Item');

my @mp3player_object_list;

sub new {
    my ( $class, $address ) = @_;
    my $self = { address => $address };

    bless $self, $class;

    push( @mp3player_object_list, $self );
    push(
        @{ $$self{states} },
        'play',
        'pause',
        'stop',
        'next song',
        'previous song',
        'shuffle',
        'repeat',
        'volume up',
        'volume down',
        'clear list',
        'random song'
    );

    return $self;
}

sub default_setstate {
    my ( $self, $state ) = @_;
    my $address = $self->{address} || 'localhost';

    print "Mp3Player set: " . $self->{address} . " to " . $state . "\n"
      if $::Debug{mp3};

    # NOTE: -1 is returned by the object to suppress the state change on failure.
    # X10 and Insteon controllers need to work like this (cm11 doesn't.)

    # 0 = failure goes to -1 for mh fail code;
    # 1 = success goes to 0, which mh sees as a success. (?)

    return mp3_player_control( $state, $self->{address} ) - 1;
}

sub play {
    my $self = shift;
    print "\n\n\nPlaying: $_[0]\n\n\n";
    return &mp3_player_control( "play \"$_[0]\"", $self->{address} );
}

sub mp3_player_control {
    my ( $command, $host ) = @_;
    my $result;

    if ( $command =~ /^play "(.+)"$/i ) {
        eval "\$result = &::mp3_play(qq|$1|, '$host')";
    }
    elsif ( $command =~ /^station "(.+)"$/i ) {
        eval "\$result = &::mp3_radio_play(qq|$1|, '$host')";
    }
    elsif ( $command =~ /^queue "(.+)"$/i ) {
        eval "\$result = &::mp3_queue(qq|$1|, '$host')";
    }
    elsif ( $command eq 'clear list' ) {
        eval "\$result = &::mp3_clear()";
    }
    else {
        eval "\$result = &::mp3_control('$command', '$host')";
    }

    if ($@) {
        warn "mp3_control: eval error: $@\n";
        return 0;    # Failed to evaluate
    }
    elsif ( !$result ) {
        warn "mp3_control: command failed: $command";
        return 0;    # Failed to execute
    }
    else {
        return 1;    # Success!
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

