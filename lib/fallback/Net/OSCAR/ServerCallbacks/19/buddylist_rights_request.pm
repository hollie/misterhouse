package Net::OSCAR::ServerCallbacks;
use strict;
use warnings;
use vars qw($SESSIONS $SCREENNAMES %COOKIES $screenname $connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$connection->proto_send(protobit => "buddylist_3_response", reqid => $reqid, protodata => {maximums => [
	200, 50, 128, 128, 1, 1, 50, 0, 0, 3, 0, 0, 0, 128, 128, 20, 200, 1, 0, 1, 0
]});

};

