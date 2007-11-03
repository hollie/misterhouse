package Net::OSCAR::ServerCallbacks;
use strict;
use warnings;
use vars qw($SESSIONS $SCREENNAMES %COOKIES $screenname $connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$connection->proto_send(reqid => $reqid, protobit => "incoming_profile", protodata => {
	screenname => $data{screenname},
	awaymsg => "Got away message at " . scalar(ctime(time())),
	evil => 0,
	flags => 0x20,
	onsince => 0,
	membersince => 0,
	idle => 0,
	capabilities => ""
});

};

