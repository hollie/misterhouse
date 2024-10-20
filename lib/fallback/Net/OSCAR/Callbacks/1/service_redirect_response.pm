package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

my $conntype;
my %chatdata;

my $svctype = $data{service_type};

my $svcmap = tlv();
$svcmap->{$_} = $_ foreach (CONNTYPE_LOGIN, CONNTYPE_CHATNAV, CONNTYPE_CHAT, CONNTYPE_ADMIN, CONNTYPE_BOS, CONNTYPE_ICON);
$conntype = $svcmap->{$svctype} || sprintf("unknown (0x%04X)", $svctype);
if($svctype == CONNTYPE_CHAT) {
	%chatdata = %{$session->{chats}->{$reqid}};
	$conntype = "chat $chatdata{name}";
}

$connection->log_print(OSCAR_DBG_NOTICE, "Got redirect for $svctype.");

my $newconn = $session->addconn(auth => $data{auth_cookie}, conntype => $svctype, description => $conntype, peer => $data{server_ip});
if($svctype == CONNTYPE_CHAT) {
	$session->{chats}->{$reqid} = $newconn;
	my($key, $val);
	while(($key, $val) = each(%chatdata)) { $session->{chats}->{$reqid}->{$key} = $val; }
}

};
