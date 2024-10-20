package Net::OSCAR::ServerCallbacks;
use strict;
use warnings;
use Net::OSCAR::Common qw(:all);
use vars qw($SESSIONS $SCREENNAMES %COOKIES $screenname $connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

my $cookie = pack("n", $reqid & 0xFFFF) . $data{cookie};
if($COOKIES{$cookie}) {
	my $peer = delete $COOKIES{$cookie};
	my $screenname = $peer->{sn};
	print "$screenname initiating BOS handshake.\n";
	$connection->{screenname} = $screenname;

	my $sess = $SESSIONS->{$screenname};
	push @{$sess->{sessions}}, $connection;
	$sess->{extstatus} ||= "";
	$sess->{away} = 0;
	$sess->{stealth} = 0;
	
	$connection->proto_send(protobit => "server_ready", protodata => {
		families => [grep { !OSCAR_TOOLDATA()->{$_}->{nobos} } keys %{OSCAR_TOOLDATA()}]
	});
} else {
	$connection->log_print(OSCAR_DBG_DEBUG, "No cookie: $cookie");
	$session->delconn($connection);
}

};

