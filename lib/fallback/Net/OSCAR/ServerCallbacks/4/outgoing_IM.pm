package Net::OSCAR::ServerCallbacks;
use strict;
use warnings;
use vars qw($SESSIONS $SCREENNAMES %COOKIES $screenname $connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

my $target = $SESSIONS->{$data{screenname}};
if(!$target or !$target->{sessions}->[0]) {
	return srv_send_error($connection, $family, 4);
}

$connection->proto_send(reqid => $reqid, protobit => "IM_acknowledgement", protodata => {
	cookie => $data{cookie},
	channel => $data{channel},
	screenname => $data{screenname}
});


$data{screenname} = $screenname;
$data{evil} = 0;
$data{flags} = 0;

$target->{sessions}->[0]->proto_send(protobit => "incoming_IM", protodata => {%data});

};

