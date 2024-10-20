package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$session->{__BLI_locked} = 0;
$session->callback_buddylist_changed(Net::OSCAR::_BLInternal::BLI_to_NO($session));

if($session->{__BLI_commit_later}) {
	$session->{__BLI_commit_later} = 0;
	$session->commit_buddylist();
}

};
