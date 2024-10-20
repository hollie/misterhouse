package Net::OSCAR::ServerCallbacks;
use strict;
use warnings;
use vars qw($SESSIONS $SCREENNAMES %COOKIES $screenname $connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

my $blist;

my $visdata = tlv_encode(tlv(
	0xCA => 0,
	0xCB => 0xFFFFFFFF,
));
$blist = "xxx";
$blist .= pack("n5a*", 0, 0, 0xCB, 4, length($visdata), $visdata);
$blist .= pack("na*n4", length("Buddies"), "Buddies", 1, 0, 1, 0);
my $i = 1;
$blist .= pack("na*n4", length($_), $_, 1, $i++, 0, 0) foreach @{$SCREENNAMES->{$screenname}->{blist}};

$connection->proto_send(reqid => $reqid, protobit => "buddylist", protodata => {data => $blist});

};

