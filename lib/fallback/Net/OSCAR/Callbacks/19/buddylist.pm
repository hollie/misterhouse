package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$session->{blarray} ||= [];
substr($data{data}, 0, 3) = "";
substr($data{data}, -4, 4) = "" if $snac->{flags2};
push @{$session->{blarray}}, $data{data};

if($snac->{flags2}) {
	$connection->log_printf(OSCAR_DBG_SIGNON, "Got buddylist segment -- need %d more.", $snac->{flags2});
} else {
	delete $session->{gotbl};

	Net::OSCAR::_BLInternal::blparse($session, join("", @{$session->{blarray}}));
	delete $session->{blarray};
	got_buddylist($session, $connection);
}

};
