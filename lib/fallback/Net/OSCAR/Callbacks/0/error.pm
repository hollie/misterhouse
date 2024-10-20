package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

my $error = "";
if($family == 0x4) {
	$error = "Your message could not be sent for the following reason: ";
} else {
	$error = "Error in ".$connection->{description}.": ";
}
$session->log_printf(OSCAR_DBG_DEBUG, "Got error %d on req 0x%04X/0x%08X.", $data{errno}, $family, $reqid);
return if $data{errno} == 0;
$error .= (ERRORS)[$data{errno}] || "unknown error";
$error .= " (".$data{error_details}.")." if $data{error_details};
send_error($session, $connection, $data{errno}, $error, 0, $reqdata);

};
