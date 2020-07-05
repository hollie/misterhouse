package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

my $reqdesc = "";
$data{subrequest} ||= 0;
if($data{request_type} == 2) {
	$reqdesc = ADMIN_TYPE_PASSWORD_CHANGE;
} elsif($data{request_type} == 3) {
	if(exists($data{new_email})) {
		$reqdesc = ADMIN_TYPE_EMAIL_CHANGE;
	} else {
		$reqdesc = ADMIN_TYPE_SCREENNAME_FORMAT;
	}
} elsif($data{request_type} == 0x1E) {
	$reqdesc = ADMIN_TYPE_ACCOUNT_CONFIRM;
}
delete $session->{adminreq}->{0+$reqdesc} if $reqdesc;
$reqdesc ||= sprintf "unknown admin reply type 0x%04X/0x%04X", $data{request_type}, $data{subrequest};

my $errdesc = "";
if(exists($data{error_code})) {
	if($reqdesc eq "account confirm") {
		$errdesc = "Your account is already confirmed.";
	} else {
		if($data{error_code} == 1) {
			$errdesc = ADMIN_ERROR_DIFFSN;
		} elsif($data{error_code} == 2) {
			$errdesc = ADMIN_ERROR_BADPASS;
		} elsif($data{error_code} == 6) {
			$errdesc = ADMIN_ERROR_BADINPUT;
		} elsif($data{error_code} == 0xB or $data{error_code} == 0xC) {
			$errdesc = ADMIN_ERROR_BADLENGTH;
		} elsif($data{error_code} == 0x13) {
			$errdesc = ADMIN_ERROR_TRYLATER;
		} elsif($data{error_code} == 0x1D) {
			$errdesc = ADMIN_ERROR_REQPENDING;
		} elsif($data{error_code} == 0x21) {
			$errdesc = ADMIN_ERROR_EMAILLIM;
		} elsif($data{error_code} == 0x23) {
			$errdesc = ADMIN_ERROR_EMAILBAD;
		} else {
			$errdesc = sprintf("Unknown error 0x%04X.", $data{error_code});
		}
	}
	$session->callback_admin_error($reqdesc, $errdesc, $data{error_url});
} else {
	if($reqdesc eq "screenname format") {
		$session->{screenname} = Net::OSCAR::Screenname->new(\$data{new_screenname});
	} elsif($reqdesc eq "email change") {
		$session->{email} = $data{new_email};
	}
	$session->callback_admin_ok($reqdesc);
}

};
