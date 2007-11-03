package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$session->callback_chat_joined($connection->{name}, $connection) unless $connection->{sent_joined}++;

$session->callback_chat_buddy_in(Net::OSCAR::Screenname->new(\$_->{screenname}), $connection) foreach @{$data{occupants}};

};
