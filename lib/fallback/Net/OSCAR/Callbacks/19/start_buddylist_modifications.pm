package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

# Someone else is modifying our buddylist.
# Lock it so that commit_buddylist() is deferred.
$session->{__BLI_locked} = 1;

};
