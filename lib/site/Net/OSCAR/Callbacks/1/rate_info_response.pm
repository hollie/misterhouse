package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
use Net::OSCAR::Utility qw(millitime);

sub {

$connection->unpause();

if($session->{rate_manage_mode} != OSCAR_RATE_MANAGE_NONE) {
	$connection->{rate_limits} ||= {classmap => {}};

	my $rinfo = $connection->{rate_limits};
	my $time = millitime();
	foreach my $class (@{$data{classes}}) {
		$class->{time_offset} = $time - $class->{last_time};
		$rinfo->{$class->{class_id}} = $class;
	}

	my $map = $rinfo->{classmap};
	foreach my $class (@{$data{classmembers}}) {
		my $id = $class->{class_id};
		foreach my $snacfam (@{$class->{snacs}}) {
			my $key = pack("nn", $snacfam->{family}, $snacfam->{subtype});
			$map->{$key} = $id;
		}
	}
}

$connection->proto_send(protobit => "rate_acknowledgement",
	classes => [map {$_->{class_id}} @{$data{classes}}]);
$connection->log_print(OSCAR_DBG_NOTICE, "BOS handshake complete!");

if($conntype == CONNTYPE_BOS) {
	$connection->log_print(OSCAR_DBG_SIGNON, "Signon BOS handshake complete!");

	$connection->proto_send(protobit => "personal_info_request");
	$session->set_stealth(1) if $session->{stealth};

	$connection->proto_send(protobit => "buddylist_rights_request");
	$connection->proto_send(protobit => "buddylist_request");
	$connection->proto_send(protobit => "locate_rights_request");
	$connection->proto_send(protobit => "buddy_rights_request");
	$connection->proto_send(protobit => "IM_parameter_request");
	$connection->proto_send(protobit => "BOS_rights_request");
} elsif($conntype == CONNTYPE_CHAT) {
	$connection->ready();

	$session->callback_chat_joined($connection->name, $connection) unless $connection->{sent_joined}++;
} else {
	if($conntype == CONNTYPE_CHATNAV) {
		$connection->proto_send(protobit => "chat_navigator_rights_request");
	}

	$session->{services}->{$conntype} = $connection;
	$connection->ready();

	if($session->{svcqueues}->{$conntype}) {
		foreach my $proto_item(@{$session->{svcqueues}->{$conntype}}) {
			$connection->proto_send(%$proto_item);
		}
	}

	delete $session->{svcqueues}->{$conntype};
}

};
