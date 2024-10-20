package Net::OSCAR::ServerCallbacks;
use strict;
use warnings;
use Net::OSCAR::Constants;
use vars qw($SESSIONS $SCREENNAMES %COOKIES $screenname $connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

my $hash;
($screenname, $hash) = ($data{screenname}, $data{auth_response});

if(!$SCREENNAMES->{$screenname}) {
	$connection->proto_send(protobit => "authorization_response", protodata => {error => 1});
}

my @valid_hashes = map {
	[$_, encode_password($session, exists($data{pass_is_hashed}) ? md5($SCREENNAMES->{$screenname}->{pw}) : $SCREENNAMES->{$screenname}->{pw}, $_)];
} keys %{$SESSIONS->{$screenname}->{keys}};

my $valid = 0;
foreach (@valid_hashes) {
	next unless $_->[1] eq $hash;
	$valid = 1;
	delete $SCREENNAMES->{$screenname}->{keys}->{$_->[0]};
	last;
}

if($valid) {
	my $key = randchars(256);
	$connection->proto_send(protobit => "authorization_response", protodata => {
		screenname => $SCREENNAMES->{$screenname}->{sn},
		email => $SCREENNAMES->{$screenname}->{email},
		auth_cookie => $key,
		server_ip => "127.0.0.1"
	});
	$session->delconn($connection);

	$COOKIES{$key} = {sn => $screenname, conntype => CONNTYPE_BOS};
} else {
	$connection->proto_send(protobit => "authorization_response", protodata => {error => 5});
	$session->delconn($connection);
}

};

