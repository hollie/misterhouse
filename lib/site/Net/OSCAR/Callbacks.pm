=pod

Net::OSCAR::Callbacks -- Process responses from OSCAR server

=cut

package Net::OSCAR::Callbacks;

$VERSION = '1.907';
$REVISION = '$Revision$';

use strict;
use vars qw($VERSION);
use Carp;

use Net::OSCAR::Common qw(:all);
use Net::OSCAR::Constants;
use Net::OSCAR::Utility;
use Net::OSCAR::TLV;
use Net::OSCAR::Buddylist;
use Net::OSCAR::_BLInternal;
use Net::OSCAR::XML;

sub process_snac($$) {
	my($connection, $snac) = @_;
	my($conntype, $family, $subtype, $data, $reqid) = ($connection->{conntype}, $snac->{family}, $snac->{subtype}, $snac->{data}, $snac->{reqid});

	my $reqdata = delete $connection->{reqdata}->[$family]->{pack("N", $reqid)};
	my $session = $connection->{session};

	my $protobit = snac_to_protobit(%$snac);
	if(!$protobit) {
		return $session->callback_snac_unknown($connection, $snac, $data);
	}

	my %data = protoparse($session, $protobit)->unpack($data);
	$connection->log_printf(OSCAR_DBG_DEBUG, "Got SNAC 0x%04X/0x%04X: %s", $snac->{family}, $snac->{subtype}, $protobit);

	if($protobit eq "authentication key") {
		if(defined($connection->{auth})) {
			$connection->log_print(OSCAR_DBG_SIGNON, "Sending password.");
			my(%signon_data) = signon_tlv($session, $connection->{auth}, $data{key});

			$session->svcdo(CONNTYPE_BOS, protobit => "signon", protodata => \%signon_data);
		} else {
			$connection->log_print(OSCAR_DBG_SIGNON, "Giving client authentication challenge.");
			$session->callback_auth_challenge($data{key}, "AOL Instant Messenger (SM)");
		}
	} elsif($protobit eq "authorization response") {
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
		}
	} elsif($protobit eq "rate info response") {
		$connection->proto_send(protobit => "rate acknowledgement");
		$connection->log_print(OSCAR_DBG_NOTICE, "BOS handshake complete!");

		if($conntype == CONNTYPE_BOS) {
			$connection->log_print(OSCAR_DBG_SIGNON, "Signon BOS handshake complete!");

			$connection->proto_send(protobit => "personal info request");
			$session->set_stealth(1) if $session->{stealth};

			$connection->proto_send(protobit => "buddylist rights request");
			$connection->proto_send(protobit => "buddylist request");
			$connection->proto_send(protobit => "locate rights request");
			$connection->proto_send(protobit => "buddy rights request");
			$connection->proto_send(protobit => "IM parameter request");
			$connection->proto_send(protobit => "BOS rights request");
		} elsif($conntype == CONNTYPE_CHAT) {
			$connection->ready();

			$session->callback_chat_joined($connection->name, $connection) unless $connection->{sent_joined}++;
		} else {
			if($conntype == CONNTYPE_CHATNAV) {
				$connection->proto_send(protobit => "chat navigator rights request");
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
	} elsif($protobit eq "incoming extended information") {
		if(exists($data{upload_checksum})) {
			# OSCAR will send the upload request again on the icon connection.
			# Since we already have the sending queued up on that connection,
			# just ignore the repeat request.
			if($connection->{conntype} != CONNTYPE_ICON) {
				if($session->{icon} and $session->{is_on}) {
					$connection->log_print(OSCAR_DBG_INFO, "Uploading buddy icon.");
					$session->svcdo(CONNTYPE_ICON, protobit => "icon upload", protodata => {
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
	} elsif($protobit eq "error") {
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
	} elsif($protobit eq "self information") {
		$session->{ip} = $data{ip} if $data{ip};

		if(exists($data{stealth_status})) {
			my $stealth_state;
			if($data{stealth_status} & 0x100) {
				$stealth_state = 1;
			} else {
				$stealth_state = 0;
			}

			if($stealth_state xor $session->{stealth}) {
				$connection->log_print(OSCAR_DBG_DEBUG, "Stealth state changed: ", $stealth_state);
				$session->{stealth} = $stealth_state;
				$session->callback_stealth_changed($stealth_state);
			}
		}


		if($data{session_length}) {
			$connection->log_print(OSCAR_DBG_DEBUG, "Someone else signed on with this screenname?  Session length == $data{session_length}");
		}
	} elsif($protobit eq "BOS rights response") {
		$session->set_info("");
	} elsif($protobit eq "buddy status update") {
		$session->postprocess_userinfo(\%data);
		my $screenname = $data{screenname};
		$connection->log_print(OSCAR_DBG_DEBUG, "Incoming bogey - er, I mean buddy - $screenname");

		my $group = $session->findbuddy($screenname);
		return unless $group; # Without this, remove_buddy screws things up until signoff/signon
		$data{buddyid} = $session->{buddies}->{$group}->{members}->{$screenname}->{buddyid};
		$data{online} = 1;
		foreach my $key(keys %data) {
			$session->{buddies}->{$group}->{members}->{$screenname}->{$key} = $data{$key};
		}
		if(exists($session->{buddies}->{$group}->{members}->{$screenname}->{idle}) and !exists($data{idle})) {
			delete $session->{buddies}->{$group}->{members}->{$screenname}->{idle};
			delete $session->{buddies}->{$group}->{members}->{$screenname}->{idle_since};
		}

		# Sync $session->{userinfo}->{$foo} with buddylist entry
		if($session->{userinfo}->{$screenname}) {
			if(!$session->{userinfo}->{$screenname}->{online}) {
				foreach my $key(keys %{$session->{userinfo}->{$screenname}}) {
					$session->{buddies}->{$group}->{members}->{$screenname}->{$key} = $session->{userinfo}->{$screenname}->{$key};
				}
				delete $session->{userinfo}->{$screenname};
				$session->{userinfo}->{$screenname} = $session->{buddies}->{$group}->{members}->{$screenname};
			}
		} else {
			$session->{userinfo}->{$screenname} = $session->{buddies}->{$group}->{members}->{$screenname};
		}

		$session->callback_buddy_in($screenname, $group, $session->{buddies}->{$group}->{members}->{$screenname});
	} elsif($protobit eq "buddy signoff") {
		my $buddy = $data{screenname};
		my $group = $session->findbuddy($buddy);
		$session->{buddies}->{$group}->{members}->{$buddy}->{online} = 0;
		$connection->log_print(OSCAR_DBG_DEBUG, "And so, another former ally has abandoned us.  Curse you, $buddy!");
		$session->callback_buddy_out($buddy, $group);
	} elsif($protobit eq "service redirect response") {
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
	} elsif($protobit eq "server ready") {
		send_versions($connection, 0);
		$connection->proto_send(protobit => "rate info request");
	} elsif($protobit eq "incoming IM") {
		my $sender = $data{screenname};
		my $sender_info = $session->{userinfo}->{$sender} ||= {};

		if($data{channel} == 1) { # Regular IM
			%data = protoparse($session, "standard IM footer")->unpack($data{message_body});

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
			%data = protoparse($session, "rendezvous IM")->unpack($data{message_body});
			my $type = OSCAR_CAPS_INVERSE()->{$data{capability}};
			$session->{rv_proposals}->{$data{cookie}} ||= {};
			my $rv = $session->{rv_proposals}->{$data{cookie}};

			if($data{status} == 1) {
				$connection->log_print(OSCAR_DBG_DEBUG, "Peer rejected proposal.");
				#$session->callback_rendezvous_reject($data{cookie});
				$session->delconn($rv->{connection}) if $rv->{connection};
				delete $session->{rv_proposals}->{$data{cookie}};
				return;
			} elsif($data{status} == 2) {
				$connection->log_print(OSCAR_DBG_DEBUG, "Peer accepted proposal.");
				$rv->{accepted} = 1;

				delete $session->{rv_proposals}->{$data{cookie}};
				#$session->callback_rendezvous_accept($data{cookie});
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
			}

			if($type eq "chat") {
				my %svcdata = protoparse($session, "chat invite rendezvous data")->unpack($data{svcdata});

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
				my %svcdata = protoparse($session, "file transfer rendezvous data")->unpack($data{svcdata});

			} else {
				$connection->log_print(OSCAR_DBG_INFO, "Unsupported rendezvous type '$type'");
				$session->rendezvous_reject($data{cookie});
			}
		}
	} elsif($protobit eq "chat invitation decline") {
		#$session->callback_rendezvous_reject($data{cookie});
		delete $session->{rv_proposals}->{$data{cookie}};
	} elsif($protobit eq "typing notification") {
		$session->callback_typing_status($data{screenname}, $data{typing_status});
	} elsif($protobit eq "rate change") {
		my($rate, $worrisome);

		if($data{current} <= $data{disconnect}) {
			$rate = RATE_DISCONNECT;
			$worrisome = 1;
		} elsif($data{current} <= $data{limit}) {
			$rate = RATE_LIMIT;
			$worrisome = 1;
		} elsif($data{current} <= $data{alert}) {
			$rate = RATE_ALERT;
			if($data{current} - $data{limit} < 500) {
				$worrisome = 1;
			} else {
				$worrisome = 0;
			}
		} else { # We're clear
			$rate = RATE_CLEAR;
			$worrisome = 0;
		}

		$session->callback_rate_alert($rate, $data{clear}, $data{window}, $worrisome);
	} elsif($protobit eq "incoming warning") {
		$session->callback_evil($data{new_level} / 10, $data{screenname} || undef);
	} elsif($protobit eq "IM acknowledgement") {
		$session->callback_im_ok($reqdata, $reqid);
	} elsif($protobit eq "buddylist 3 response") {
		$session->{gotbl} = 1;
	} elsif($protobit eq "buddylist") {
		$session->{blarray} ||= [];
		substr($data{data}, 0, 3) = "";
		substr($data{data}, -4, 4) = "" if $snac->{flags2};
		$session->{blarray}->[$snac->{flags2}] = $data{data};

		if($snac->{flags2}) {
			$connection->log_print(OSCAR_DBG_SIGNON, "Got buddylist segment -- need %d more.", $snac->{flags2});
		} else {
			delete $session->{gotbl};

			return unless Net::OSCAR::_BLInternal::blparse($session, join("", reverse @{$session->{blarray}}));
			delete $session->{blarray};
			got_buddylist($session, $connection);
		}
	} elsif($protobit eq "buddylist modification acknowledgement") {
		if(!ref($session->{budmods}) || !@{$session->{budmods}}) {
			$connection->log_print(OSCAR_DBG_WARN, "Unexpected blmod ack!");
			return;
		}
		$connection->log_print(OSCAR_DBG_DEBUG, "Got blmod ack (", scalar(@{$session->{budmods}}), " left).");
		my(@errors) = @{$data{error}};

		my @reqdata = @$reqdata;
		foreach my $error(reverse @errors) {
			my($errdata) = shift @reqdata;
			last unless $errdata;
			if($error != 0) {
				$session->{buderrors} = 1;
				my($type, $gid, $bid) = ($errdata->{type}, $errdata->{gid}, $errdata->{bid});
				if(exists($session->{blold}->{$type}) and exists($session->{blold}->{$type}->{$gid}) and exists($session->{blold}->{$type}->{$gid}->{$bid})) {
					$session->{blinternal}->{$type}->{$gid}->{$bid} = $session->{blold}->{$type}->{$gid}->{$bid};
				} else {
					delete $session->{blinternal}->{$type} unless exists($session->{blold}->{$type});
					delete $session->{blinternal}->{$type}->{$gid} unless exists($session->{blold}->{$type}) and exists($session->{blold}->{$type}->{$gid});
					delete $session->{blinternal}->{$type}->{$gid}->{$bid} unless exists($session->{blold}->{$type}) and exists($session->{blold}->{$type}->{$gid}) and exists($session->{blold}->{$type}->{$gid}->{$bid});
				}

				$connection->proto_send(%{pop @{$session->{budmods}}}); # Stop making changes
				delete $session->{budmods};
				$session->callback_buddylist_error($error, $errdata->{desc});
				last;
			}
		}

		if($session->{buderrors}) {
			Net::OSCAR::_BLInternal::BLI_to_NO($session) if $session->{buderrors};
			delete $session->{qw(blold buderrors budmods)};
		} else {
			$connection->proto_send(%{shift @{$session->{budmods}}});
			if(!@{$session->{budmods}}) {
				delete $session->{budmods};
				$session->callback_buddylist_ok;
			}
		}
	} elsif($protobit eq "buddylist error") {
		if($session->{gotbl}) {
			delete $session->{gotbl};
			$connection->log_print(OSCAR_DBG_WARN, "Couldn't get your buddylist - probably because you don't have one.");
			got_buddylist($session, $connection);			
		} else {
			$connection->log_print_cond(OSCAR_DBG_INFO, sub { "Buddylist error:", hexdump($data{data}) });
		}
	} elsif($protobit eq "incoming profile") {
		$session->postprocess_userinfo(\%data);
		$session->callback_buddy_info($data{screenname}, \%data);
	} elsif($protobit eq "chat navigator response") {
		return if exists($data{exchange}); # This was a rights request

		foreach my $room (@{$data{room}}) {
			# Generate a random request ID
			my($reqid) = "";
			$reqid = pack("n", 4);
			$reqid .= randchars(2);
			($reqid) = unpack("N", $reqid);

			$session->{chats}->{$reqid} = $room;

			$session->svcdo(CONNTYPE_BOS, protobit => "service request", reqid => $reqid, protodata => {
				type => CONNTYPE_CHAT,
				chat => {
					exchange => $room->{exchange},
					url => $room->{url}
				}
			});
		}
	} elsif($protobit eq "chat room status") {
		$session->callback_chat_joined($connection->{name}, $connection) unless $connection->{sent_joined}++;

		$session->callback_chat_buddy_in($_->{screenname}, $connection) foreach @{$data{occupants}};
	} elsif($protobit eq "chat buddy arrival") {
		foreach (@{$data{arrivals}}) {
			$session->callback_chat_buddy_in($_->{screenname}, $connection, $_);
		}
	} elsif($protobit eq "chat buddy departure") {
		foreach (@{$data{departures}}) {
			$session->callback_chat_buddy_out($_, $connection);
		}
	} elsif($protobit eq "incoming chat IM") {
		$session->callback_chat_im_in($data{sender}, $connection, $data{message});
	} elsif($protobit eq "account confirm response") {
		my $reqdesc = ADMIN_TYPE_ACCOUNT_CONFIRM;
		delete $session->{adminreq}->{0+$reqdesc};
		if($data{status} == 19) {
			$session->callback_admin_error($reqdesc, "Your account could not be confirmed.");
		} else {
			$session->callback_admin_ok($reqdesc);
		}
	} elsif($protobit eq "admin request response") {
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
				$session->{screenname} = $data{new_screenname};
			} elsif($reqdesc eq "email change") {
				$session->{email} = $data{new_email};
			}
			$session->callback_admin_ok($reqdesc);
		}
	} elsif($protobit eq "account confirmed") {
		$session->callback_admin_ok(ADMIN_TYPE_ACCOUNT_CONFIRM);
	} elsif($protobit eq "session was opened elsewhere") {
		$session->crapout($connection, "A session using this screenname has been opened in another location.");
	} elsif($protobit eq "buddy icon uploaded") {
		$session->callback_buddy_icon_uploaded();
	} elsif($protobit eq "buddy icon downloaded") {
		my $screenname = $data{screenname};
		my $user_info = $session->{userinfo}->{$screenname} ||= {};
		$user_info->{icon_checksum} = $data{checksum};
		$user_info->{icon} = $data{icon};
		$session->callback_buddy_icon_downloaded($screenname, $data{icon});
	} elsif($protobit eq "ICQ meta response") {
		my $uin = $data{our_uin};

		if($data{type} == 2010) {
			$session->{icq_meta_info_cache}->{$uin} ||= {};

			(%data) = protoparse($session, "ICQ meta info response")->unpack($data{typedata});
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

			(%data) = protoparse($session, "ICQ meta info response: $subtype")->unpack($data{response_data});
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
	}

	return 1;
}

sub got_buddylist($$) {
	my($session, $connection) = @_;

	$connection->proto_send(protobit => "add IM parameters");
	$connection->ready();

	$session->set_extended_status("") if $session->{capabilities}->{extended_status};
	$connection->proto_send(protobit => "set idle", protodata => {duration => 0});
	$connection->proto_send(protobit => "buddylist done");

	$session->{is_on} = 1;
	$session->callback_signon_done() unless $session->{sent_done}++;
}

sub default_snac_unknown($$$$) {
	my($session, $connection, $snac, $data) = @_;
	$session->log_printf_cond(OSCAR_DBG_WARN, sub { "Unknown SNAC %d/%d: %s", $snac->{family},$snac->{subtype}, hexdump($snac->{data}) });
}

1;

