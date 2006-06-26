#!/usr/bin/perl                                                                                 
#
#    Provides an object-based interface for all MP3 players.
#    Code for the different players should be moved into this object eventually
#    (no need for four mutually exclusive common code modules.)

use strict;

package Mp3Player;
@Mp3Player::ISA = ('Generic_Item');

my @mp3player_object_list;

sub new 
{
    my ($class, $address) = @_;
    my $self = {address => $address};

    bless $self, $class;

    push(@mp3player_object_list,$self);
    push(@{$$self{states}}, 'play', 'pause', 'stop', 'next song', 'previous song', 'shuffle', 'repeat', 'volume up', 'volume down', 'queue', 'clear list', 'random song');

    return $self;
}

sub default_setstate
{
    my ($self, $state) = @_;
    my $address = $self->{address} || 'localhost';

    print "Mp3Player set: " . $self->{address} . " to " . $state . "\n" if $::Debug{mp3};

	# NOTE: -1 is returned by the object to suppress the state change on failure.
	# X10 and Insteon controllers need to work like this (cm11 doesn't.)

	# 0 = failure goes to -1 for mh fail code;
	# 1 = success goes to 0, which mh sees as a success. (?)

    return mp3_player_control($state,$self->{address}) - 1;
}

sub mp3_player_control 
{
    my ($command, $host) = @_;
    my $result;

    if ($command =~ /^play:(.+)$/i) {
	eval "\$result = &::mp3_play($1)";
    }
    elsif ($command =~ /^playlist:(.+)$/i) {
	eval "\$result = &::mp3_playlist($1)";
    }
    elsif ($command =~ /^station:(.+)$/i) {
	eval "\$result = &::mp3_radio_play($1)";
    }
    elsif ($command =~ /^queue:(.+)$/i) {
	eval "\$result = &::mp3_queue($1)";
    }
    elsif ($command eq 'clear list') {
	eval "\$result = &::mp3_clear()";
    }
    else {
	eval "\$result = &::mp3_control('$command', '$host')";
    }

    if ($@) {
	    warn "mp3_control: eval error: $@\n";
	    return 0; # Failed to evaluate
    }
    elsif (!$result) {
	    warn "mp3_control: command failed: $command";
	    return 0; # Failed to execute
    }
    else {
	    return 1; # Success!
    }
}

1;


