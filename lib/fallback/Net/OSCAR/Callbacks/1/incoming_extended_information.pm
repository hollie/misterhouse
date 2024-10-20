package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

if(exists($data{upload_checksum})) {
	# OSCAR will send the upload request again on the icon connection.
	# Since we already have the sending queued up on that connection,
	# just ignore the repeat request.
	if($connection->{conntype} != CONNTYPE_ICON) {
		if($session->{icon} and $session->{is_on}) {
			$connection->log_print(OSCAR_DBG_INFO, "Uploading buddy icon.");
			$session->svcdo(CONNTYPE_ICON, protobit => "icon_upload", protodata => {
				icon => $session->{icon}
			});
		}
	}
} elsif(exists($data{resend_checksum})) {
	$connection->log_print(OSCAR_DBG_INFO, "Got icon resend request!");
	$session->set_icon($session->{icon}) if $session->{icon};
} elsif(exists($data{status_message})) {
	$session->callback_extended_status($data{status_message});
} else {
	$connection->log_print(OSCAR_DBG_WARN, "Unknown extended info request");
}

};
