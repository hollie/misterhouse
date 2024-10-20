=pod

Net::OSCAR::Callbacks -- Process responses from OSCAR server

=cut

package Net::OSCAR::Callbacks;

$VERSION = '1.925';
$REVISION = '$Revision: 1.134 $';

use strict;
use vars qw($VERSION);
use Carp;

use Net::OSCAR::Common qw(:all);
use Net::OSCAR::Constants;
use Net::OSCAR::Utility;
use Net::OSCAR::TLV;
use Net::OSCAR::Buddylist;
use Net::OSCAR::_BLInternal;
use Net::OSCAR::XML;

our %protohandlers;

sub process_snac($$) {
	our($connection, $snac) = @_;
	our($conntype, $family, $subtype, $data, $reqid) = ($connection->{conntype}, $snac->{family}, $snac->{subtype}, $snac->{data}, $snac->{reqid});

	our $reqdata = delete $connection->{reqdata}->[$family]->{pack("N", $reqid)};
	our $session = $connection->{session};

	my $protobit = snac_to_protobit(%$snac);
	if(!$protobit) {
		return $session->callback_snac_unknown($connection, $snac, $data);
	}

	our %data = protoparse($session, $protobit)->unpack($data || "");
	$connection->log_printf(OSCAR_DBG_DEBUG, "Got SNAC 0x%04X/0x%04X: %s", $snac->{family}, $snac->{subtype}, $protobit);

	if(!exists($protohandlers{$protobit})) {
		$protohandlers{$protobit} = eval {
			require "Net/OSCAR/Callbacks/$family/$protobit.pm";
		};
		if($@) {
			my $olderr = $@;
			$protohandlers{$protobit} = eval {
				require "Net/OSCAR/Callbacks/0/$protobit.pm";
			};
			if($@) {
				$protohandlers{$protobit} = sub {};
			}
		}
	}
	$protohandlers{$protobit}->();

	return 1;
}

sub got_buddylist($$) {
	my($session, $connection) = @_;

	$connection->proto_send(protobit => "add_IM_parameters");
	$connection->ready();

	$session->set_extended_status("") if $session->{capabilities}->{extended_status};
	$connection->proto_send(protobit => "set_idle", protodata => {duration => 0});
	$connection->proto_send(protobit => "buddylist_done");

	$session->{is_on} = 1;
	$session->callback_signon_done() unless $session->{sent_done}++;
}

sub default_snac_unknown($$$$) {
	my($session, $connection, $snac, $data) = @_;
	$session->log_printf_cond(OSCAR_DBG_WARN, sub { "Unknown SNAC %d/%d: %s", $snac->{family},$snac->{subtype}, hexdump($snac->{data}) });
}

1;

