package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

if(defined($connection->{auth})) {
	$connection->log_print(OSCAR_DBG_SIGNON, "Sending password.");
	my(%signon_data) = signon_tlv($session, delete($connection->{auth}), $data{key});

	$session->svcdo(CONNTYPE_BOS, protobit => "signon", protodata => \%signon_data);
} else {
	$connection->log_print(OSCAR_DBG_SIGNON, "Giving client authentication challenge.");
	$session->callback_auth_challenge($data{key}, "AOL Instant Messenger (SM)");
}

};
