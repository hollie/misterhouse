package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

foreach (@{$data{departures}}) {
	$session->callback_chat_buddy_out(Net::OSCAR::Screenname->new(\$_), $connection);
}

};
