package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$session->postprocess_userinfo(\%data);
$session->callback_buddy_info($data{screenname}, \%data);

};
