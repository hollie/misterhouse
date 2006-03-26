=pod

Net::OSCAR::Connection::Chat -- OSCAR chat connections

=cut

package Net::OSCAR::Connection::Chat;

$VERSION = '1.907';
$REVISION = '$Revision: 1.4.2.8 $';

use strict;
use Carp;

use Net::OSCAR::TLV;
use Net::OSCAR::Callbacks;
use vars qw(@ISA $VERSION);
use Net::OSCAR::Common qw(:all);
use Net::OSCAR::Constants;
use Net::OSCAR::Utility;
use Net::OSCAR::XML;
@ISA = qw(Net::OSCAR::Connection);

sub invite($$;$) {
	my($self, $who, $message) = @_;
	$message ||= "Join me in this Buddy Chat";

	$self->log_print(OSCAR_DBG_DEBUG, "Inviting $who to join us.");

	my $svcdata = protoparse($self, "chat invite rendezvous data")->pack(
		exchange => $self->{exchange},
		url => $self->{url}
	);

	my $cookie = randchars(8);
	my %rvdata = (
		capability => OSCAR_CAPS()->{chat}->{value},
		charset => "us-ascii",
		cookie => $cookie,
		invitation_msg => $message,
		push_pull => 1,
		status => 0,
		svcdata => $svcdata
	);

        return $self->{session}->send_message($who, 2, protoparse($self, "rendezvous IM")->pack(%rvdata), 0, $cookie);
}

sub chat_send($$;$$) {
	my($self, $msg, $noreflect, $away) = @_;

	my %protodata = (
		cookie => randchars(8),
		message => $msg
	);
	$protodata{reflect} = "" unless $noreflect;
	$protodata{is_automatic} = "" if $away;

	$self->proto_send(protobit => "outgoing chat IM", protodata => \%protodata);
}

sub part($) { shift->disconnect(); }	
sub url($) { shift->{url}; }
sub name($) { shift->{name}; }
sub exchange($) { shift->{exchange}; }

1;
