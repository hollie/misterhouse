=pod

Net::OSCAR::MethodInfo -- Mappings from method names to (SNAC,family).  Used by
rate management functionality

=cut

package Net::OSCAR::MethodInfo;

$VERSION = '1.925';
$REVISION = '$Revision: 1.2 $';

use strict;
use warnings;
use vars qw(@ISA $VERSION $REVISION);
use Net::OSCAR::XML;

sub encode($) {
	my %snac = protobit_to_snac($_[0]);
	my($family, $subtype) = ($snac{family}, $snac{subtype});
	return pack("nn", $family, $subtype);
}

our %methods = (
	set_stealth => encode("set_extended_status"),
	get_info => encode("get_info"),
	get_away => encode("get_away"),
	send_typing_status => encode("typing_notification"),
	evil => encode("outgoing_warning"),
	get_icon => encode("buddy_icon_download"),
	set_extended_status => encode("set_extended_status"),
	set_info => encode("set_info"),
	change_password => encode("change_account_info"),
	confirm_account => encode("confirm_account_request"),
	change_email => encode("change_account_info"),
	format_screenname => encode("change_account_info"),
	set_idle => encode("set_idle"),
	chat_join => encode("chat_navigator_room_create"),
	chat_accept => encode("chat_invitation_accept"),
	chat_decline => encode("chat_invitation_decline"),
	auth_response => encode("signon"),
	get_icq_info => encode("ICQ_meta_request"),
	send_message => encode("outgoing_IM"),
	svcreq => encode("service_request"),
	send_im => encode("outgoing_IM"),
	file_send => encode("outgoing_IM"),
	rendezvous_revise => encode("outgoing_IM"),
	rendezvous_reject => encode("outgoing_IM"),
	chat_send => encode("outgoing_chat_IM")
);

1;
