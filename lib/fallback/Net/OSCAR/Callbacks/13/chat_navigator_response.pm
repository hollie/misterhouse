package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

return if exists($data{exchange}); # This was a rights request

foreach my $room (@{$data{room}}) {
	# Generate a random request ID
	my($reqid) = "";
	$reqid = pack("n", 4);
	$reqid .= randchars(2);
	($reqid) = unpack("N", $reqid);

	$session->{chats}->{$reqid} = $room;

	$session->svcdo(CONNTYPE_BOS, protobit => "service_request", reqid => $reqid, protodata => {
		type => CONNTYPE_CHAT,
		chat => {
			exchange => $room->{exchange},
			url => $room->{url}
		}
	});
}

};
