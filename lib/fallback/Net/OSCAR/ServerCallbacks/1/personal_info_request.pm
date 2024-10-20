package Net::OSCAR::ServerCallbacks;
use strict;
use warnings;
use vars qw($SESSIONS $SCREENNAMES %COOKIES $screenname $connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$connection->proto_send(reqid => $reqid, protobit => "self_information", protodata => {
	screenname => $screenname,
 			evil => 0,
	flags => 0x20,
	onsince => time(),
	idle => 0,
	session_length => 0,
	ip => 0
});

};

