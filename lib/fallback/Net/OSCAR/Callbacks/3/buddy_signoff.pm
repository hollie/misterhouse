package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

my $buddy = $data{screenname};
my($grpname, $group) = $session->findbuddy($buddy);
return unless $grpname;

 		delete $session->{userinfo}->{$buddy};
my $budinfo = $group->{members}->{$buddy};
foreach (keys %$budinfo) {
	delete $budinfo->{$_} unless /^(?:buddyid|data|__BLI.*|alias|online|comment|screenname)$/;
}
$budinfo->{online} = 0;

$connection->log_print(OSCAR_DBG_DEBUG, "And so, another former ally has abandoned us.  Curse you, $buddy!");
$session->callback_buddy_out($budinfo->{screenname}, $grpname);

};
