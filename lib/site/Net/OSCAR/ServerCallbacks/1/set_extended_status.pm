package Net::OSCAR::ServerCallbacks;
use strict;
use warnings;
use vars qw($SESSIONS $SCREENNAMES %COOKIES $screenname $connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

if($data{status_message}) {
	$SESSIONS->{$screenname}->{status}->{extstatus} = $data{status_message}->{message};
} elsif($data{stealth}) {
	$SESSIONS->{$screenname}->{status}->{stealth} = $data{stealth}->{state} & 0x100;
}

};

