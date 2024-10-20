package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

my($rate, $worrisome);

if($session->{rate_manage_mode} != OSCAR_RATE_MANAGE_NONE) {
	delete $data{message_type};

	my $cinfo = $connection->{rate_limits}->{$data{class_id}};
	$cinfo->{$_} = $data{$_} foreach keys(%data);
}


if($data{current} <= $data{disconnect}) {
	$rate = RATE_DISCONNECT;
	$worrisome = 1;
} elsif($data{current} <= $data{limit}) {
	$rate = RATE_LIMIT;
	$worrisome = 1;
} elsif($data{current} <= $data{alert}) {
	$rate = RATE_ALERT;
	if($data{current} - $data{limit} < 500) {
		$worrisome = 1;
	} else {
		$worrisome = 0;
	}
} else { # We're clear
	$rate = RATE_CLEAR;
	$worrisome = 0;
}

$session->callback_rate_alert($rate, $data{clear}, $data{window}, $worrisome, 0);

};
