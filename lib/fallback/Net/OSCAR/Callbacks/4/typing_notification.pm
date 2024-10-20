package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$session->callback_typing_status(Net::OSCAR::Screenname->new(\$data{screenname}), $data{typing_status});

};
