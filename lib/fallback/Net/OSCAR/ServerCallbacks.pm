=pod

Net::OSCAR::ServerCallbacks -- Process responses from OSCAR client

=cut

package Net::OSCAR::ServerCallbacks;

$VERSION = '1.925';
$REVISION = '$Revision: 1.8 $';

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

use Digest::MD5 qw(md5);
use POSIX qw(ctime);

our %protohandlers;
our $SESSIONS = bltie();
our $SCREENNAMES = bltie();
our %COOKIES;
$SCREENNAMES->{somedude} = {sn => "Some Dude", pw => "somepass", email => 'some@dude.com', blist => [qw(SomeDude OtherDude)]};
$SCREENNAMES->{otherdude} = {sn => "Other Dude", pw => "otherpass", email => 'other@dude.com', blist => [qw(SomeDude OtherDude)]};


sub srv_send_error($$$) {
	my($connection, $family, $errno) = @_;

	$connection->proto_send(family => $family, protobit => "error", protodata => {errno => $errno});
}

sub process_snac($$) {
	our($connection, $snac) = @_;
	our($conntype, $family, $subtype, $data, $reqid) = ($connection->{conntype}, $snac->{family}, $snac->{subtype}, $snac->{data}, $snac->{reqid});
	our $screenname = $connection->{screenname};

	our $reqdata = delete $connection->{reqdata}->[$family]->{pack("N", $reqid)};
	our $session = $connection->{session};

	our $protobit = snac_to_protobit(%$snac);
	if(!$protobit) {
		return $session->callback_snac_unknown($connection, $snac, $data);
	}

	our %data = protoparse($session, $protobit)->unpack($data);
	$connection->log_printf(OSCAR_DBG_DEBUG, "Got SNAC 0x%04X/0x%04X: %s", $snac->{family}, $snac->{subtype}, $protobit);

	if(!exists($protohandlers{$protobit})) {
		$protohandlers{$protobit} = eval {
			require "Net/OSCAR/ServerCallbacks/$family/$protobit.pm";
		};
		if($@) {
			my $olderr = $@;
			$protohandlers{$protobit} = eval {
				require "Net/OSCAR/ServerCallbacks/0/$protobit.pm";
			};
		}
	}

	if($protohandlers{$protobit}) {
		$protohandlers{$protobit}->();
	} else {
		#srv_send_error($connection, $family, 1);
		print "Unhandled protobit: $protobit\n";
	}
}

1;

