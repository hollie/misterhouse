package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

if(!ref($session->{budmods}) || !@{$session->{budmods}}) {
	$connection->log_print(OSCAR_DBG_WARN, "Unexpected blmod ack!");
	return;
}
my $budmods = $session->{budmods};

$connection->log_print(OSCAR_DBG_DEBUG, "Got blmod ack (", scalar(@$budmods), " left).");
my(@errors) = @{$data{error}};

my @reqdata = @$reqdata;
foreach my $error(reverse @errors) {
	my($errdata) = shift @reqdata;
	last unless $errdata;
	if($error != 0) {
		$session->{buderrors} = 1;
		my($type, $gid, $bid) = ($errdata->{type}, $errdata->{gid}, $errdata->{bid});
		if(exists($session->{blold}->{$type}) and exists($session->{blold}->{$type}->{$gid}) and exists($session->{blold}->{$type}->{$gid}->{$bid})) {
			$session->{blinternal}->{$type}->{$gid}->{$bid} = $session->{blold}->{$type}->{$gid}->{$bid};
		} else {
			delete $session->{blinternal}->{$type} unless exists($session->{blold}->{$type});
			delete $session->{blinternal}->{$type}->{$gid} unless exists($session->{blold}->{$type}) and exists($session->{blold}->{$type}->{$gid});
			delete $session->{blinternal}->{$type}->{$gid}->{$bid} unless exists($session->{blold}->{$type}) and exists($session->{blold}->{$type}->{$gid}) and exists($session->{blold}->{$type}->{$gid}->{$bid});
		}

		$connection->proto_send(%{pop @$budmods}); # Stop making changes
		delete $session->{budmods};
		$session->callback_buddylist_error($error, $errdata->{desc});
		last;
	}
}

if($session->{buderrors}) {
	Net::OSCAR::_BLInternal::BLI_to_NO($session) if $session->{buderrors};
	delete $session->{qw(blold buderrors budmods)};
} else {
	if(@$budmods) {
		$connection->proto_send(%{shift @$budmods});
	}

	if(!@$budmods) {
		delete $session->{budmods};
		$session->callback_buddylist_ok;
	}
}

};
