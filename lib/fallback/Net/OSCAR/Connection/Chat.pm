=pod

Net::OSCAR::Connection::Chat -- OSCAR chat connections

=cut

package Net::OSCAR::Connection::Chat;

$VERSION = '1.925';
$REVISION = '$Revision: 1.10 $';

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

	my $svcdata = protoparse($self, "chat_invite_rendezvous_data")->pack(
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
		status => "propose",
		svcdata => $svcdata
	);

        return $self->{session}->send_message($who, 2, protoparse($self, "rendezvous_IM")->pack(%rvdata), 0, $cookie);
}

sub chat_send($$;$$) {
	my($self, $msg, $noreflect, $away) = @_;

	my %protodata = (
		cookie => randchars(8),
		message => $msg
	);
	$protodata{reflect} = "" unless $noreflect;
	$protodata{is_automatic} = "" if $away;

	$self->proto_send(protobit => "outgoing_chat_IM", protodata => \%protodata);
}

sub part($) { shift->disconnect(); }	
sub url($) { shift->{url}; }
sub name($) { shift->{name}; }
sub exchange($) { shift->{exchange}; }

1;
