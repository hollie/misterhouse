package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

if($session->{gotbl}) {
	delete $session->{gotbl};
	$connection->log_print(OSCAR_DBG_WARN, "Couldn't get your buddylist - probably because you don't have one.");
	got_buddylist($session, $connection);			
} else {
	$connection->log_print_cond(OSCAR_DBG_INFO, sub { "Buddylist error:", hexdump($data{data}) });
}


};
