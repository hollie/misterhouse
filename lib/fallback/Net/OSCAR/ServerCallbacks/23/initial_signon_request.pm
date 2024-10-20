package Net::OSCAR::ServerCallbacks;
use strict;
use warnings;
use vars qw($SESSIONS $SCREENNAMES %COOKIES $screenname $connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

if(exists($SCREENNAMES->{$data{screenname}})) {
	$screenname = $data{screenname};
	my $key = sprintf("%08d", int(rand(99999999)));
	print "$screenname would like to sign on.  Generated key '$key'\n";

	$SESSIONS->{$screenname} ||= {};
	$SESSIONS->{$screenname}->{keys} ||= {};
	$SESSIONS->{$screenname}->{sessions} ||= [];
	$SESSIONS->{$screenname}->{status} ||= {
		online => 0,
	};

	$SESSIONS->{$screenname}->{keys}->{$key} = 1;
	$connection->proto_send(protobit => "authentication_key", protodata => {key => $key});
} else {
	$connection->proto_send(protobit => "authorization_response", protodata => {error => 1});
	$session->delconn($connection);
}

};

