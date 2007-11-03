=pod

Net::OSCAR::Connection::Server -- Net::OSCAR server connection

=cut

package Net::OSCAR::Connection::Server;

$VERSION = '1.925';
$REVISION = '$Revision: 1.5 $';
@ISA = qw(Net::OSCAR::Connection);

use strict;
use vars qw($VERSION @ISA);
use Carp;
use Socket;
use Symbol;

use Net::OSCAR::Common qw(:all);
use Net::OSCAR::Constants;
use Net::OSCAR::Connection;
use Net::OSCAR::ServerCallbacks;

sub new($@) {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->listen($self->{session}->{port}) unless exists($self->{socket});

	$self->{oscar_state} = "listening";
	$self->{signon_done} = 0;

	return $self;
}

sub process_one($;$$$) {
	my($self, $read, $write, $error) = @_;
	my $snac;

	if($error) {
		$self->{sockerr} = 1;
		return $self->disconnect();
	}

	if($write && $self->{outbuff}) {
		$self->log_print(OSCAR_DBG_DEBUG, "Flushing output buffer.");
		$self->flap_put();
	}

	if($read && !$self->{connected}) {
		$self->log_print(OSCAR_DBG_NOTICE, "Incoming connection.");

		my $socket = gensym();
		accept($socket, $self->{socket});
		my $peer = $self->{session}->addconn(socket => $socket, conntype => CONNTYPE_SERVER, description => "new peer");

		$peer->set_blocking(0);
		$peer->{connected} = 1;
		$peer->{state} = "write";
		$peer->{oscar_state} = "new";
		$self->{session}->callback_connection_changed($peer, "write");
		return 1;
	} elsif($write and $self->{oscar_state} eq "new") {
		$self->log_print(OSCAR_DBG_DEBUG, "Putting connack.");
		$self->flap_put(pack("N", 1), FLAP_CHAN_NEWCONN);
		$self->{state} = "readwrite";
		$self->{session}->callback_connection_changed($self, "readwrite");
		$self->{oscar_state} = "ready";

		$self->{families} = {};
		$self->{families}->{$_} = 1 foreach (1..30);
	} elsif($read) {
		my $no_reread = 0;

		while(1) {
			my $flap = $self->flap_get($no_reread) or return 0;
			next if length($flap) == 4;
			my $snac = $self->snac_decode($flap) or return 0;
			Net::OSCAR::ServerCallbacks::process_snac($self, $snac);
		} continue {
			$no_reread = 1;
		}
	}
}

1;
