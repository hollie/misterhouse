package Net::AIM;
# This package was shamelessly adapted from Net::IRC by Aryeh Goldsmith

BEGIN { require 5.004; }    # needs IO::* and $coderef->(@args) syntax 

use Net::AIM::Connection;
use IO::Select;
use Carp;
use strict;
use vars qw($VERSION);

$VERSION = "0.01";

# Front end to addfh(), below. Sets it to read by default.
# Takes at least 1 arg:  an object to add to the select loop.
#           (optional)   a flag string to pass to addfh() (see below)
sub addconn {
    my ($self, $conn) = @_;
    
    $self->addfh( $conn->socket, $conn->can('parse'), ($_[2] || 'r'), $conn);
}

# Adds a filehandle to the select loop. Tasty and flavorful.
# Takes 3 args:  a filehandle or socket to add
#                a coderef (can be undef) to pass the ready filehandle to for
#                  user-specified reading/writing/error handling.
#    (optional)  a string with r/w/e flags, similar to C's fopen() syntax,
#                  except that you can combine flags (i.e., "rw").
#    (optional)  an object that the coderef is a method of
sub addfh {
    my ($self, $fh, $code, $flag, $obj) = @_;
    my ($letter);

    die "Not enough arguments to AIM->addfh()" unless defined $code;

    
    if ($flag) {
	foreach $letter (split(//, lc $flag)) {
	    if ($letter eq 'r') {
		$self->{_read}->add( $fh );
	    } elsif ($letter eq 'w') {
		$self->{_write}->add( $fh );
	    } elsif ($letter eq 'e') {
		$self->{_error}->add( $fh );
	    }
	}
    } else {
	$self->{_read}->add( $fh );
    }
    
    $self->{_connhash}->{$fh} = [ $code, $obj ];
}


# Sets or returns the debugging flag for this object.
# Takes 1 optional arg: a new boolean value for the flag.
sub debug {
    my $self = shift;

    if (@_) {
	$self->{_debug} = $_[0];
    }
    return $self->{_debug};
}


# Goes through one iteration of the main event loop. Useful for integrating
# other event-based systems (Tk, etc.) with Net::AIM.
# Takes no args.
sub do_one_loop {
    my $self = shift;
    
    my ($ev, $sock, $time, $nexttimer, $timeout);
    
    # Check the queue for scheduled events to run.
    

    $time = time();             # no use calling time() all the time.
    $nexttimer = 0;
    foreach $ev ($self->queue) {
	if ($self->{_queue}->{$ev}->[0] <= $time) {
	    $self->{_queue}->{$ev}->[1]->
		(@{$self->{_queue}->{$ev}}[2..$#{$self->{_queue}->{$ev}}]);
	    delete $self->{_queue}->{$ev};
	} else {
	    $nexttimer = $self->{_queue}->{$ev}->[0] 
		if ($self->{_queue}->{$ev}->[0] < $nexttimer
		    or not $nexttimer);
	}
    }
    
    # Block until input arrives, then hand the filehandle over to the
    # user-supplied coderef. Look! It's a freezer full of government cheese!

    if ($nexttimer) {
	$timeout = $nexttimer - $time < $self->{_timeout}
	? $nexttimer - $time : $self->{_timeout};
    } else {
	$timeout = $self->{_timeout};
    }
    foreach $ev (IO::Select->select($self->{_read},
				    $self->{_write},
				    $self->{_error},
				    $timeout)) {
	foreach $sock (@{$ev}) {
	    my $conn = $self->{_connhash}->{$sock};
	    
	    # $conn->[0] is a code reference to a handler sub.
	    # $conn->[1] is optionally an object which the
	    #    handler sub may be a method of.
	    
	    $conn->[0]->($conn->[1] ? ($conn->[1], $sock) : $sock);
	}
    }
}

# Ye Olde Contructor Methode. You know the drill.
# Takes absolutely no args whatsoever.
sub new {
    my $proto = shift;

    my $self = {
	        '_conn'     => [],
		'_connhash' => {},
		'_error'    => IO::Select->new(),
		'_debug'    => 0,
		'_queue'    => {},
		'_qid'      => 'a',
		'_read'     => IO::Select->new(),
		'_timeout'  => undef,
		'_write'    => IO::Select->new(),
	    };

    bless $self, $proto;

    return $self;
}

# Creates and returns a new Connection object.
# Any args here get passed to Connection->connect().
sub newconn {
    my $self = shift;
    my $conn = Net::AIM::Connection->new($self, @_);
    
    return if $conn->error;
    return $conn;
}


# Returns a list of listrefs to event scheduled to be run.
# Takes the args passed to it by Connection->schedule()... see it for details.
sub queue {
    my $self = shift;

    if (@_) {
        $self->{_qid} = 'a' if $self->{_qid} eq 'zzzzzzzz';
        my $id = $self->{_qid};
        $self->{_queue}->{$self->{_qid}++} = [ @_ ];
        return ($id);

    } else {
        return keys %{$self->{_queue}};
    }
}


# Takes a scheduled event ID to remove from the queue.
# Returns the deleted coderef, if you actually care.
sub dequeue {
    my ($self, $id) = @_;
    delete $self->{_queue}->{$id}
}

# Front-end for removefh(), below.
# Takes 1 arg:  a Connection (or DCC or whatever) to remove.
sub removeconn {
    my ($self, $conn) = @_;
    
    $self->removefh( $conn->socket );
}

# Given a filehandle, removes it from all select lists. You get the picture.
sub removefh {
    my ($self, $fh) = @_;
    
    $self->{_read}->remove( $fh );
    $self->{_write}->remove( $fh );
    $self->{_error}->remove( $fh );
    delete $self->{_connhash}->{$fh};
}

# Begin the main loop. Wheee. Hope you remembered to set up your handlers
# first... (takes no args, of course)
sub start {
    my $self = shift;

    while (1) {
	$self->do_one_loop();
    }
}

# Sets or returns the current timeout, in seconds, for the select loop.
# Takes 1 optional arg:  the new value for the timeout, in seconds.
# Fractional timeout values are just fine, as per the core select().
sub timeout {
    my $self = shift;

    if (@_) { $self->{_timeout} = $_[0] }
    return $self->{_timeout};
}

1;
__END__

=head1 NAME

Net::AIM - Perl extension for AOL Instant Messenger TOC protocol

=head1 SYNOPSIS

  use Net::AIM;

  $aim = new Net::AIM;
  $conn = $aim->newconn(Screenname   => 'Perl AIM',
                        Password     => 'ilyegk');
  $aim->start;

=head1 DESCRIPTION

This module implements an OO interface to the Aol Instant Messenger TOC protocol.

This version contains not much more than hacked code that merely connects
to the aol TOC servers and acts on instant messages.


=head1 AUTHOR

=over

=item *

Written by Aryeh Goldsmith E<lt>aryeh@ironarmadillo.comE<gt>.

=item *

Adapted from Net::IRC which was conceived and initially developed by:
     Greg Bacon E<lt>gbacon@adtran.comE<gt> and
     Dennis Taylor E<lt>dennis@funkplanet.comE<gt>.

=back

=head1 URL

The Net::IRC project:
http://netirc.betterbox.net/

The Net::AIM project:
http://projects.aryeh.net/Net-AIM/

=head1 SEE ALSO

perl(1), Net::IRC.


=cut

