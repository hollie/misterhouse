package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$connection->log_print(OSCAR_DBG_DEBUG, "Incoming bogey - er, I mean buddy - $data{screenname}");
$session->postprocess_userinfo(\%data);
my $screenname = $data{screenname};

my($grpname, $group) = $session->findbuddy($screenname);
return unless $grpname; # Without this, remove_buddy screws things up until signoff/signon
my $budinfo = $group->{members}->{$screenname};

$data{buddyid} = $budinfo->{buddyid};
$data{online} = 1;
foreach my $key(keys %data) {
	next if $key eq "__UNKNOWN";
	$budinfo->{$key} = delete $data{$key};
}
if(exists($budinfo->{idle}) and !exists($data{idle})) {
	delete $budinfo->{idle};
	delete $budinfo->{idle_since};
}

# Sync $session->{userinfo}->{$foo} with buddylist entry
if(exists($session->{userinfo}->{$screenname})) {
	if($session->{userinfo}->{$screenname} != $budinfo)  {
		my $info = $session->{userinfo}->{$screenname};
		foreach my $key(keys %$info) {
			$budinfo->{$key} = $info->{$key};
		}
		$session->{userinfo}->{$screenname} = $budinfo;
	}
} else {
	$session->{userinfo}->{$screenname} = $budinfo;
}
$session->callback_buddy_in($screenname, $grpname, $budinfo);

};
