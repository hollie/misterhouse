package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

$session->{gotbl} = 1;

$session->{bl_limits}->{groups} = $data{maximums}->[1];
$session->{bl_limits}->{permits} = $data{maximums}->[2];
$session->{bl_limits}->{denies} = $data{maximums}->[3];

# Buddy limit is minimum of this and the buddy rights response value
if($session->{bl_limits}->{buddies}) {
	if($data{maximums}->[0] < $session->{bl_limits}->{buddies}) {
		$session->{bl_limits}->{buddies} = $data{maximums}->[0];
	}
} else {
	$session->{bl_limits}->{buddies} = $data{maximums}->[0];
}

};
