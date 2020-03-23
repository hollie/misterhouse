package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
sub {

my $uin = $data{our_uin};

if($data{type} == 2010) {
	$session->{icq_meta_info_cache}->{$uin} ||= {};

	(%data) = protoparse($session, "ICQ_meta_info_response")->unpack($data{typedata});
	if($data{status} != 10) {
		delete $session->{icq_meta_info_cache}->{$uin};

		my $error = "Bad ICQ meta info response";
		if($data{status} == 20) {
			$error = "Could not get ICQ info for $uin.";
		}

		send_error($session, $connection, $data{status}, $error, 0, $reqdata);
		return;
	}

	if(!exists(ICQ_META_INFO_INVERSE()->{$data{subtype}})) {
		$session->log_printf(OSCAR_DBG_WARN, "Bad ICQ meta response subtype %d", $data{subtype});
		return;
	}
	my $subtype = ICQ_META_INFO_INVERSE()->{$data{subtype}};

	(%data) = protoparse($session, "ICQ_meta_info_response:_$subtype")->unpack($data{response_data});
	if($subtype eq "basic") {
		$session->{icq_meta_info_cache}->{$uin}->{home} = delete $data{home};
		$session->{icq_meta_info_cache}->{$uin}->{basic} = \%data;
	} elsif($subtype eq "office") {
		$session->{icq_meta_info_cache}->{$uin}->{office} = \%data;
	} elsif($subtype eq "background") {
		$session->{icq_meta_info_cache}->{$uin}->{background} = \%data;
		$session->{icq_meta_info_cache}->{$uin}->{background}->{spoken_languages} =
			[delete @data{qw(language_1 language_2 language_3)}];
	} elsif($subtype eq "notes") {
		$session->{icq_meta_info_cache}->{$uin}->{notes} = $data{notes};
	} elsif($subtype eq "email") {
		$session->{icq_meta_info_cache}->{$uin}->{email_addresses} = $data{addresses};
	} elsif($subtype eq "interests") {
		$session->{icq_meta_info_cache}->{$uin}->{interests} = $data{interests};
	} elsif($subtype eq "affiliations") {
		$session->{icq_meta_info_cache}->{$uin}->{past_affiliations} = $data{past_affilations};
		$session->{icq_meta_info_cache}->{$uin}->{present_affiliations} = $data{affiliations};
	} elsif($subtype eq "homepage") {
		$session->{icq_meta_info_cache}->{$uin}->{email_addresses} = $data{homepage};
	}

	if(!$snac->{flags2}) {
		$session->callback_buddy_icq_info($uin, delete $session->{icq_meta_info_cache}->{$uin});
	}
} else {
	$session->log_printf(OSCAR_DBG_WARN, "Unknown ICQ meta response %d", $data{type});
}

};
