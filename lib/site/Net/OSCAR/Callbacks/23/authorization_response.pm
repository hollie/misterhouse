package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

if($data{error}) {
	my $error = $data{error};
	$session->crapout($connection, "Invalid screenname.") if $error == 0x01;
	$session->crapout($connection, "Invalid password.") if $error == 0x05;
	$session->crapout($connection, "You've been connecting too frequently.") if $error == 0x18;
	my($errstr) = ((ERRORS)[$error]) || "unknown error";
	$errstr .= " ($data{error_details})" if $data{error_details};
	$session->crapout($connection, $errstr, $error);
	return 0;
} else {
	$connection->log_print(OSCAR_DBG_SIGNON, "Login OK - connecting to BOS");
	$session->addconn(
		auth => $data{auth_cookie},
		conntype => CONNTYPE_BOS,
		description => "basic OSCAR service",
		peer => $data{server_ip}
	);
	$connection->{closing} = 1;
	$connection->disconnect;
	$session->{screenname} = $data{screenname};
	$session->{email} = $data{email};

	Net::OSCAR::Screenname->new(\$session->{screenname});
}

};
