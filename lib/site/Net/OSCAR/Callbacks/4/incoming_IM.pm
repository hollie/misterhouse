package Net::OSCAR::Callbacks;
use strict;
use warnings;
use vars qw($connection $snac $conntype $family $subtype $data $reqid $reqdata $session $protobit %data);
use Socket qw(inet_ntoa);
sub {

my $sender = Net::OSCAR::Screenname->new(\$data{screenname});
my $sender_info = $session->{userinfo}->{$sender} ||= {};

if($data{channel} == 1) { # Regular IM
	%data = protoparse($session, "standard_IM_footer")->unpack($data{message_body});

	# Typing status
	my $typing_status = 0;
	if(exists($data{supports_typing_status})) {
		$sender_info->{typing_status} = 1;
	} else {
		delete $sender_info->{typing_status};
	}


	# Buddy icon
	my $new_icon = 0;
	if(exists($data{icon_data}->{icon_length}) and $session->{capabilities}->{buddy_icons}) {
		if(!exists($sender_info->{icon_timestamp})
		  or $data{icon_data}->{icon_timestamp} > $sender_info->{icon_timestamp}
		  or $data{icon_data}->{icon_checksum} != $sender_info->{icon_checksum}
		) {
			$new_icon = 1;
		}
	}

	$sender_info->{$_} = $data{icon_data}->{$_} foreach keys %{$data{icon_data}};

	$session->callback_new_buddy_icon($sender, $sender_info) if $new_icon;


	# Okay, finally we're done with silly processing of embedded flags
	$session->callback_im_in($sender, $data{message}, exists($data{is_automatic}) ? 1 : 0);

} elsif($data{channel} == 2) {
	%data = protoparse($session, "rendezvous_IM")->unpack($data{message_body});
	my $type = OSCAR_CAPS_INVERSE()->{$data{capability}};
	$session->{rv_proposals}->{$data{cookie}} ||= {};
	my $rv = $session->{rv_proposals}->{$data{cookie}};

	if($data{status} eq "cancel") {
		$connection->log_print(OSCAR_DBG_DEBUG, "Peer rejected proposal.");
		$session->callback_rendezvous_reject($data{cookie});
		$session->delconn($rv->{connection}) if $rv->{connection};
		delete $session->{rv_proposals}->{$data{cookie}};
		return;
	} elsif($data{status} eq "accept") {
		$connection->log_print(OSCAR_DBG_DEBUG, "Peer accepted proposal.");
		$rv->{accepted} = 1;

		delete $session->{rv_proposals}->{$data{cookie}};
		$session->callback_rendezvous_accept($data{cookie});
		return;
	}

	if(!$type) {
		$connection->log_print_cond(OSCAR_DBG_INFO, sub { "Unknown rendezvous type: ", hexdump($data{capability}) });
		$session->rendezvous_reject($data{cookie});
		return;
	}

	if(!$rv->{cookie}) {
		$rv->{type} = $type;
		$rv->{sender} = $sender;
		$rv->{recipient} = $session->{screenname};
		$rv->{cookie} = $data{cookie};
	} elsif($rv->{peer} ne $sender) {
		$connection->log_printf(OSCAR_DBG_WARN, "$sender tried to send a rendezvous which was previously sent by %s; discarding.", $rv->{peer});
		return;
	}

	if($type eq "chat") {
		my %svcdata = protoparse($session, "chat_invite_rendezvous_data")->unpack($data{svcdata});

		# Ignore invites for chats that we're already in
		if(not grep { $_->{url} eq $svcdata{url} }
		   grep { $_->{conntype} == CONNTYPE_CHAT }
		      @{$session->{connections}}
		) {
			# Extract chat ID from char URL
			$rv->{chat_url} = $svcdata{url};
			$svcdata{url} =~ /-.*?-(.*?)(\0*)$/;
			my $chat = $1;
			$chat =~ s/%([0-9A-Z]{1,2})/chr(hex($1))/eig;
			$rv->{name} = $chat;
			$rv->{exchange} = $svcdata{exchange};

			$session->callback_chat_invite($sender, $data{invitation_msg}, $chat, $svcdata{url});
		}
	} elsif($type eq "filexfer") {
		# If proposal is being revised, no svcdata will be present.
		my %svcdata;
		if($data{svcdata}) {
			%svcdata = protoparse($session, "file_transfer_rendezvous_data")->unpack($data{svcdata});

			$rv->{direction} = "receive";
			$rv->{accepted} = 0;
			$rv->{filenames} = $svcdata{files};
			$rv->{total_size} = $svcdata{size};
			$rv->{file_count} = $svcdata{file_count};
			$rv->{using_proxy} = 0;
			$rv->{tried_proxy} = 0;
			$rv->{tried_listen} = 0;
			$rv->{tried_connect} = 0;
		} elsif($rv->{connection}) {
			$session->delconn($rv->{connection});
			delete $rv->{connection};
		}

		$rv->{port} = $data{port};
		$rv->{external_ip} = $data{client_external_ip} ? inet_ntoa(pack("N", $data{client_external_ip})) : "";
		$rv->{ip} = $data{client_1_ip} ? inet_ntoa(pack("N", $data{client_1_ip})) : $rv->{external_ip};
		$rv->{ft_state} = "unconnected";

		$connection->log_printf(OSCAR_DBG_DEBUG, "Got proposal %s for %s:%d (external %s)", hexdump($rv->{cookie}), $rv->{ip}, $rv->{port}, $rv->{external_ip});
	} elsif($type eq "sendlist") {
		my %svcdata = protoparse($session, "buddy_list_transfer_rendezvous_data")->unpack($data{svcdata});
		delete $session->{rv_proposals}->{$data{cookie}};

		my $list = bltie();
		foreach my $group (@{$svcdata{group}}) {
			$list->{$group->{name}} = [];

			my $grouplist = $list->{$group->{name}};
			foreach my $buddy (@{$group->{buddies}}) {
				push @$grouplist, Net::OSCAR::Screenname->new(\$buddy->{name});
			}
		}

		$session->callback_buddylist_in($sender, $list);
	} else {
		$connection->log_print(OSCAR_DBG_INFO, "Unsupported rendezvous type '$type'");
		$session->rendezvous_reject($data{cookie});
	}
}

};
