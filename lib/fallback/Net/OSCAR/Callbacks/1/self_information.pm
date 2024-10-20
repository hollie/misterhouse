package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$session->{ip} = $data{ip} if $data{ip};

if(exists($data{stealth_status})) {
	my $stealth_state;
	if($data{stealth_status} & 0x100) {
		$stealth_state = 1;
	} else {
		$stealth_state = 0;
	}

	if($stealth_state xor $session->{stealth}) {
		$connection->log_print(OSCAR_DBG_DEBUG, "Stealth state changed: ", $stealth_state);
		$session->{stealth} = $stealth_state;
		$session->callback_stealth_changed($stealth_state);
	}
}


if($data{session_length}) {
	$connection->log_print(OSCAR_DBG_DEBUG, "Someone else signed on with this screenname?  Session length == $data{session_length}");
}

};
