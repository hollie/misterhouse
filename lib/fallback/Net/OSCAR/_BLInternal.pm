=pod

Net::OSCAR::_BLInternal -- internal buddylist stuff

This handles conversion of Net::OSCAR to "OSCAR buddylist format",
and the sending of buddylist changes to the OSCAR server.

=cut

package Net::OSCAR::_BLInternal;

use strict;
use Net::OSCAR::Common qw(:all);
use Net::OSCAR::Constants;
use Net::OSCAR::Utility;
use Net::OSCAR::TLV;
use Net::OSCAR::XML;

use vars qw($VERSION $REVISION);
$VERSION = '1.925';
$REVISION = '$Revision: 1.56 $';

sub init_entry($$$$) {
	my($blinternal, $type, $gid, $bid) = @_;

	$blinternal->{$type} ||= tlv();
	$blinternal->{$type}->{$gid} ||= tlv();
	$blinternal->{$type}->{$gid}->{$bid} ||= {};
	$blinternal->{$type}->{$gid}->{$bid}->{name} ||= "";
	$blinternal->{$type}->{$gid}->{$bid}->{data} ||= tlv();
	$blinternal->{$type}->{$gid}->{$bid}->{__BLI_DIRTY} = 1;
	$blinternal->{$type}->{$gid}->{$bid}->{__BLI_DELETED} = 0;
}

sub blentry_clear($%) {
	my($session, %data) = @_;

	if(chain_exists($session->{blinternal}, $data{entry_type}, $data{group_id}, $data{buddy_id})) {
		$session->{blinternal}->{$data{entry_type}}->{$data{group_id}}->{$data{buddy_id}}->{__BLI_DELETED} = 1;
	}
}

sub blentry_set($%) {
	my($session, %data) = @_;

	init_entry($session->{blinternal}, $data{entry_type}, $data{group_id}, $data{buddy_id});
	my $typedata = tlv_decode($data{entry_data});

	$session->{blinternal}->{$data{entry_type}}->{$data{group_id}}->{$data{buddy_id}}->{name} = $data{entry_name} if $data{entry_name};
	while(my($key, $value) = each %$typedata) {
		$session->{blinternal}->{$data{entry_type}}->{$data{group_id}}->{$data{buddy_id}}->{data}->{$key} = $value;
	}
	$session->log_printf_cond(OSCAR_DBG_DEBUG, sub { "Got BLI entry %s 0x%04X/0x%04X/0x%04X with %d bytes of data:%s", $data{entry_name}, $data{entry_type}, $data{group_id}, $data{buddy_id}, length($typedata), hexdump($data{entry_data}) });
}

sub blparse($$) {
	my($session, $data) = @_;

	$session->{visibility} = VISMODE_PERMITALL; # If we don't have p/d data, this is default.

	delete $session->{blinternal};
	$session->{blinternal} = tlv();

	while(length($data) > 4) {
		my($name) = unpack("n/a*", $data);
		substr($data, 0, 2+length($name)) = "";
		my($gid, $bid, $type, $sublen) = unpack("n4", substr($data, 0, 8, ""));
		my $typedata = substr($data, 0, $sublen, "");
		blentry_set($session, 
			entry_type => $type,
			group_id => $gid,
			buddy_id => $bid,
			entry_name => $name,
			entry_data => $typedata
		);
	}

	BLI_to_NO($session);
}

# Buddylist-Internal -> Net::OSCAR
# Sets various $session hashkeys from blinternal.
# That's what Brian Bli-to-no'd do. ;)
sub BLI_to_NO($) {
	my($session) = @_;
	my $bli = $session->{blinternal};

	delete $session->{blinternal_visbid};
	delete $session->{blinternal_iconbid};

	$session->{buddies} ||= bltie(1);
	$session->{buddies}->{__BLI_DIRTY} = 0;

	$session->{permit} ||= bltie;
	$session->{deny} ||= bltie;


	foreach my $type ([2, "permit"], [3, "deny"]) {
		my($num, $name) = @$type;

		if(exists $bli->{$num}) {
			foreach my $bid(keys(%{$bli->{$num}->{0}})) {
				my $item = $bli->{$num}->{0}->{$bid};

				if($item->{__BLI_DELETED}) {
					delete $session->{$name}->{$item->{name}};
					delete $bli->{$num}->{0}->{$bid};
				} elsif($item->{__BLI_DIRTY}) {
					$session->{$name}->{$item->{name}} = {buddyid => $bid};
					$item->{__BLI_DIRTY} = 0;
				}
			}
		}
	}


	foreach my $type (4, 5, 0x14) {
		delete $bli->{$type}->{0}->{$_} foreach grep { $bli->{$type}->{0}->{$_}->{__BLI_DELETED} } keys %{$bli->{$type}->{0}};
	}

	if(exists $bli->{4} and exists $bli->{4}->{0} and (my($visbid) = grep {exists($bli->{4}->{0}->{$_}->{data}->{0xCB})} keys %{$bli->{4}->{0}})) {
		$session->{blinternal_visbid} = $visbid;
		my $typedata = $bli->{4}->{0}->{$visbid}->{data};
		if($bli->{4}->{0}->{$visbid}->{__BLI_DIRTY}) {
			($session->{visibility}) = unpack("C", $typedata->{0xCA}) if $typedata->{0xCA};

			my $groupperms = $typedata->{0xCB};
			($session->{groupperms}) = unpack("N", $groupperms) if $groupperms;
			$session->{profile} = $typedata->{0x0100} if exists($typedata->{0x0100});
			($session->{icon_checksum}) = unpack("n", $typedata->{0x0101}) if exists($typedata->{0x0101});
			($session->{icon_timestamp}) = unpack("N", $typedata->{0x0102}) if exists($typedata->{0x0102});
			($session->{icon_length}) = unpack("N", $typedata->{0x0103}) if exists($typedata->{0x0103});

			$session->{appdata} = $typedata;

			$session->set_info($session->{profile}) if exists($session->{profile});

			$bli->{4}->{0}->{$visbid}->{__BLI_DIRTY} = 0;
		}
	} else {
		# No permit info - we permit everyone
		$session->{visibility} = VISMODE_PERMITALL;
		$session->{groupperms} = 0xFFFFFFFF;
	}

	if(exists $bli->{0x14} and exists $bli->{0x14}->{0} and (my($iconbid) = grep {exists($bli->{0x14}->{0}->{$_}->{data}->{0xD5})} keys %{$bli->{0x14}->{0}})) {
		$session->{blinternal_iconbid} = $iconbid;
		my $typedata = $bli->{0x14}->{0}->{$iconbid}->{data};
		$session->{icon_md5sum} = $typedata->{0xD5};
	}


	my @ret;

	foreach my $gid (keys %{$bli->{1}}) {
		next unless exists $bli->{1}->{$gid}->{0};
		my $item = $bli->{1}->{$gid}->{0};

		if($item->{__BLI_DELETED}) {
			delete $bli->{1}->{$gid}->{0};
			next if $gid == 0 or !$item->{name};

			delete $session->{buddies}->{$item->{name}};
			push @ret, {type => MODBL_WHAT_GROUP, action => MODBL_ACTION_DEL, group => $item->{name}};
		} elsif($item->{__BLI_DIRTY}) {
			$item->{__BLI_DIRTY} = 0;
			next if $gid == 0 or !$item->{name};

			$session->{buddies}->{$item->{name}} ||= {};
			my $entry = $session->{buddies}->{$item->{name}};

			$entry->{__BLI_DIRTY} = 0;
			$entry->{__BLI_DELETED} = 0;
			$entry->{groupid} = $gid;
			$entry->{members} = bltie unless $entry->{members};
			$entry->{data} = $item->{data};

			push @ret, {type => MODBL_WHAT_GROUP, action => MODBL_ACTION_ADD, group => $item->{name}};
		}
	}

	foreach my $gid (keys %{$bli->{0}}) {
		foreach my $bid (keys %{$bli->{0}->{$gid}}) {
			my $item = $bli->{0}->{$gid}->{$bid};
			my $group = "";
			$group = $bli->{1}->{$gid}->{0}->{name} if chain_exists($bli, 1, $gid, 0);

			if($item->{__BLI_DELETED}) {
				delete $bli->{0}->{$gid}->{$bid};
				next if $gid == 0 or !$group;

				delete $session->{buddies}->{$group}->{members}->{$item->{name}} if $group;
				push @ret, {type => MODBL_WHAT_BUDDY, action => MODBL_ACTION_DEL, group => $group, buddy => $item->{name}};
			} elsif($item->{__BLI_DIRTY}) {
				$item->{__BLI_DIRTY} = 0;
				next if $gid == 0 or !$group;

				my $comment = undef;
				$comment = $item->{data}->{0x13C} if exists($item->{data}->{0x13C});

				my $alias = undef;
				$alias = $item->{data}->{0x131} if exists($item->{data}->{0x131});

				$session->{buddies}->{$group}->{members}->{$item->{name}} ||= {};
				my $entry = $session->{buddies}->{$group}->{members}->{$item->{name}};
				$entry->{__BLI_DIRTY} = 0;
				$entry->{__BLI_DELETED} = 0;
				$entry->{buddyid} = $bid;
				$entry->{online} = 0 unless exists($entry->{online});
				$entry->{comment} = $comment;
				$entry->{alias} = $alias;
				$entry->{data} = $item->{data};
				$entry->{screenname} = Net::OSCAR::Screenname->new($item->{name});

				push @ret, {type => MODBL_WHAT_BUDDY, action => MODBL_ACTION_ADD, group => $group, buddy => $item->{name}};
			}
		}
	}

	return @ret;
}

# Gee, guess what this does?  Hint: see sub BLI_to_NO.
sub NO_to_BLI($) {
	my $session = shift;

	my $bli = tlv();
	my $oldbli = $session->{blinternal};

	# Copy old data
	my $visbid = $session->{blinternal_visbid} || int(rand(30000)) + 1;
	my $iconbid = $session->{blinternal_iconbid} || 0x51F4;
	foreach my $type (keys %$oldbli) {
		next if $type == 2 or $type == 3;
		foreach my $gid (keys %{$oldbli->{$type}}) {
			foreach my $bid (keys %{$oldbli->{$type}->{$gid}}) {
				next if $type == 4 and $bid == $visbid;
				next if $type == 0x14 and $bid == $iconbid;

				init_entry($bli, $type, $gid, $bid);
				$bli->{$type}->{$gid}->{$bid}->{name} = $oldbli->{$type}->{$gid}->{$bid}->{name};
				foreach my $data (keys %{$oldbli->{$type}->{$gid}->{$bid}->{data}}) {
					$bli->{$type}->{$gid}->{$bid}->{data}->{$data} = $oldbli->{$type}->{$gid}->{$bid}->{data}->{$data};
				}
			}
		}
	}


	foreach my $permit (keys %{$session->{permit}}) {
		init_entry($bli, 2, 0, $session->{permit}->{$permit}->{buddyid});
		$bli->{2}->{0}->{$session->{permit}->{$permit}->{buddyid}}->{name} = $permit;
	}

	foreach my $deny (keys %{$session->{deny}}) {
		init_entry($bli, 3, 0, $session->{deny}->{$deny}->{buddyid});
		$bli->{3}->{0}->{$session->{deny}->{$deny}->{buddyid}}->{name} = $deny;
	}

	init_entry($bli, 4, 0, $visbid);
	$bli->{4}->{0}->{$visbid}->{data}->{0xCA} = pack("C", $session->{visibility} || VISMODE_PERMITALL);
	$bli->{4}->{0}->{$visbid}->{data}->{0xCB} = pack("N", $session->{groupperms} || 0xFFFFFFFF);

	#Net::OSCAR protocol extensions
	$bli->{4}->{0}->{$visbid}->{data}->{0x0100} = $session->{profile} if $session->{profile};
	$bli->{4}->{0}->{$visbid}->{data}->{0x0101} = pack("n", $session->{icon_checksum}) if $session->{icon_checksum};
	$bli->{4}->{0}->{$visbid}->{data}->{0x0102} = pack("N", $session->{icon_timestamp}) if $session->{icon_timestamp};
	$bli->{4}->{0}->{$visbid}->{data}->{0x0103} = pack("N", $session->{icon_length}) if $session->{icon_length};

	foreach my $appdata(keys %{$session->{appdata}}) {
		$bli->{4}->{0}->{$visbid}->{data}->{$appdata} = $session->{appdata}->{$appdata};
	}

	if(exists($session->{icon_md5sum}) || chain_exists($oldbli, 0x14, 0, $iconbid)) {
		init_entry($bli, 0x14, 0, $iconbid);

		if(chain_exists($oldbli, 0x14, 0, $iconbid)) {
			$bli->{0x14}->{0}->{$iconbid}->{name} = $oldbli->{0x14}->{0}->{$iconbid}->{name};

			$bli->{0x14}->{0}->{$iconbid}->{data}->{$_} = $oldbli->{0x14}->{0}->{$iconbid}->{data}->{$_}
			   foreach grep { $_ != 0xD5 } keys %{$oldbli->{0x14}->{0}->{$iconbid}->{data}};
		} else {
			$bli->{0x14}->{0}->{$iconbid}->{name} = "1";
		}

		if(exists($session->{icon_md5sum})) {
			$bli->{0x14}->{0}->{$iconbid}->{data}->{0xD5} = $session->{icon_md5sum};
		}
	}

	init_entry($bli, 1, 0, 0);
	if($session->{buddies}->{__BLI_DIRTY}) {
		$bli->{1}->{0}->{0}->{data}->{0xC8} = pack("n*", map { $_->{groupid} } grep { ref($_) } values %{$session->{buddies}});
		$session->{buddies}->{__BLI_DIRTY} = 0;
	} else {
		$bli->{1}->{0}->{0}->{__BLI_SKIP} = 1;
		$oldbli->{1}->{0}->{0}->{__BLI_SKIP} = 1;
	}

	while(my($grpname, $grp) = each(%{$session->{buddies}})) {
		next if $grpname eq "__BLI_DIRTY";

		my $gid = $grp->{groupid};

		if($grp->{__BLI_DELETED}) {
			delete $session->{buddies}->{$grpname};
			delete $bli->{1}->{$gid}->{0};
			next;
		}

		if(not $grp->{__BLI_DIRTY}) {
			$bli->{1}->{$gid}->{0}->{__BLI_SKIP} = 1;
			$oldbli->{1}->{$gid}->{0}->{__BLI_SKIP} = 1;
			next;
		} else {
			$grp->{__BLI_DIRTY} = 0;
		}

		init_entry($bli, 1, $gid, 0);
		my $bligrp = $bli->{1}->{$gid}->{0};
		$bligrp->{name} = $grpname;


		# Clear out data, since the user may have deleted keys.
		$bli->{1}->{$gid}->{0}->{data} = tlv();

		# It seems that WinAIM can now have groups without 0xC8 data, and gets pissed if we create such data where it doesn't exist.
		if(!exists($oldbli->{1}->{$gid}) or chain_exists($oldbli, 1, $gid, 0, "data", 0xC8)) {
			$bligrp->{data}->{0xC8} = pack("n*",
				map { $_->{buddyid} }
				grep { not $_->{__BLI_DELETED} }
				values %{$grp->{members}});
		}

		if(chain_exists($oldbli, 1, $gid, 0)) {
			$bli->{1}->{$gid}->{0}->{data}->{$_} = $oldbli->{1}->{$gid}->{0}->{data}->{$_}
			   foreach grep { $_ != 0xC8 } keys %{$oldbli->{1}->{$gid}->{0}->{data}};
		}


		while(my($buddy, $bud) = each(%{$grp->{members}})) {
			my $bid = $bud->{buddyid};

			if($bud->{__BLI_DELETED}) {
				delete $grp->{members}->{$buddy};
				delete $bli->{0}->{$gid}->{$bid};
				next;
			}

			if(not $bud->{__BLI_DIRTY}) {
				$bli->{0}->{$gid}->{$bid}->{__BLI_SKIP} = 1;
				$oldbli->{0}->{$gid}->{$bid}->{__BLI_SKIP} = 1;
				next;
			} else {
				$bud->{__BLI_DIRTY} = 0;
			}

			next unless $bid;
			init_entry($bli, 0, $gid, $bid);
			my $blibud = $bli->{0}->{$gid}->{$bid};
			$blibud->{name} = "$buddy"; # Make sure to get strinfied version of Screenname

			$blibud->{data} = tlv();
			while(my ($key, $value) = each(%{$bud->{data}})) {
				$blibud->{data}->{$key} = $value;
			}
			$blibud->{data}->{0x13C} = $bud->{comment} if defined $bud->{comment};
			$blibud->{data}->{0x131} = $bud->{alias} if defined $bud->{alias};
		}
	}

	BLI_to_OSCAR($session, $bli);
}

# Send changes to BLI over to OSCAR
sub BLI_to_OSCAR($$) {
	my($session, $newbli) = @_;
	my $oldbli = $session->{blinternal};
	my (@adds, @modifies, @deletes);
        $session->crapout($session->{services}->{0+CONNTYPE_BOS}, "You must wait for a buddylist_ok or buddylist_error callback before calling commit_buddylist again.") if $session->{budmods};
	$session->{budmods} = [];

	my %budmods;
	$budmods{add} = [];
	$budmods{modify} = [];
	$budmods{delete} = [];

	# First, delete stuff that we no longer use and modify everything else
	foreach my $type(keys %$oldbli) {

		my $budtype = (BUDTYPES)[$type] || "unknown type $type";

		foreach my $gid(keys %{$oldbli->{$type}}) {
			foreach my $bid(keys %{$oldbli->{$type}->{$gid}}) {
				my $oldentry = $oldbli->{$type}->{$gid}->{$bid};
				if($oldentry->{__BLI_SKIP}) {
					delete $oldentry->{__BLI_SKIP};
					next;
				}

				my $olddata = tlv_encode($oldentry->{data});
				$session->log_printf_cond(OSCAR_DBG_DEBUG, sub { "Old BLI entry %s 0x%04X/0x%04X/0x%04X with %d bytes of data:%s", $oldentry->{name}, $type, $gid, $bid, length($olddata), hexdump($olddata) });
				my $delete = 0;
				if(exists($newbli->{$type}) and exists($newbli->{$type}->{$gid}) and exists($newbli->{$type}->{$gid}->{$bid})) {
					my $newentry = $newbli->{$type}->{$gid}->{$bid};
					my $newdata = tlv_encode($newentry->{data});
					$session->log_printf_cond(OSCAR_DBG_DEBUG, sub { "New BLI entry %s 0x%04X/0x%04X/0x%04X with %d bytes of data:%s", $newentry->{name}, $type, $gid, $bid, length($newdata), hexdump($newdata) });

					next if
						$newentry->{name} eq $oldentry->{name}
					  and	$newdata eq $olddata;

					# Apparently, we can't modify the name of a buddylist entry?
					if($newentry->{name} ne $oldentry->{name}) {
						$delete = 1;
					} else {
						$session->log_print(OSCAR_DBG_DEBUG, "Modifying.");

						push @{$budmods{modify}}, {
							reqdata => {desc => "modifying $budtype $newentry->{name}", type => $type, gid => $gid, bid => $bid},
							protodata => {
								entry_name => $newentry->{name},
								group_id => $gid,
								buddy_id => $bid,
								entry_type => $type,
								entry_data => $newdata
							}
						};
					}
				} else {
					$delete = 1;
				}

				if($delete) {
					$session->log_print(OSCAR_DBG_DEBUG, "Deleting.");

					push @{$budmods{delete}}, {
						reqdata => {desc => "deleting $budtype $oldentry->{name}", type => $type, gid => $gid, bid => $bid},
						protodata => {
							entry_name => $oldentry->{name},
							group_id => $gid,
							buddy_id => $bid,
							entry_type => $type,
							entry_data => $olddata
						}
					};
				}
			}
		}
	}

	# Now, add the new stuff
	foreach my $type(keys %$newbli) {

		my $budtype = (BUDTYPES)[$type] || "unknown type $type";

		foreach my $gid(keys %{$newbli->{$type}}) {
			foreach my $bid(keys %{$newbli->{$type}->{$gid}}) {
				my $entry = $newbli->{$type}->{$gid}->{$bid};
				if($entry->{__BLI_SKIP}) {
					delete $entry->{__BLI_SKIP};
					next;
				}

				next if exists($oldbli->{$type}) and exists($oldbli->{$type}->{$gid}) and exists($oldbli->{$type}->{$gid}->{$bid}) and $oldbli->{$type}->{$gid}->{$bid}->{name} eq $newbli->{$type}->{$gid}->{$bid}->{name};

				my $data = tlv_encode($entry->{data});

				$session->log_printf_cond(OSCAR_DBG_DEBUG, sub { "New BLI entry %s 0x%04X/0x%04X/0x%04X with %d bytes of data:%s", $entry->{name}, $type, $gid, $bid, length($data), hexdump($data) });

				push @{$budmods{add}}, {
					reqdata => {desc => "adding $budtype $entry->{name}", type => $type, gid => $gid, bid => $bid},
					protodata => {
						entry_name => $entry->{name},
						group_id => $gid,
						buddy_id => $bid,
						entry_type => $type,
						entry_data => $data
					}
				};
			}
		}
	}

	# Actually send the changes.  Don't send more than 7K in a single SNAC.
	# FLAP size limit is 8K, but that includes headers - good to have a safety margin
	foreach my $type (qw(add modify delete)) {
		my $changelist = $budmods{$type};

		my(@reqdata, @packets);
		my $packet = "";
		foreach my $change(@$changelist) {
			$packet .= protoparse($session, "buddylist_modification")->pack(%{$change->{protodata}});
			push @reqdata, $change->{reqdata};

			if(length($packet) > 7*1024) {
				#$session->log_print(OSCAR_DBG_INFO, "Adding to blmod queue (max packet size reached): type $type, payload size ", scalar(@reqdata));
				push @packets, {
					type => $type,
					data => $packet,
					reqdata => [@reqdata],
				};
				$packet = "";
				@reqdata = ();
			}
		}
		if($packet) {
			#$session->log_print(OSCAR_DBG_INFO, "Adding to blmod queue (no more changes): type $type, payload size ", scalar(@reqdata));
			push @packets, {
				type => $type,
				data => $packet,
				reqdata => [@reqdata],
			};
		}

		push @{$session->{budmods}}, map {
			{
				protobit => "buddylist_" . $_->{type},
				reqdata => $_->{reqdata},
				protodata => {mods => $_->{data}}
			};
		} @packets;
	}

	push @{$session->{budmods}}, {protobit => "end_buddylist_modifications"}; # End BL mods
	#$session->log_print(OSCAR_DBG_INFO, "Adding terminator to blmod queue.");

	$session->{blold} = $oldbli;
	$session->{blinternal} = $newbli;

	if(@{$session->{budmods}} <= 1) { # We only have the start/end modification packets, no actual changes
		#$session->log_print(OSCAR_DBG_INFO, "Empty blmod queue - calling buddylist_ok.");
		delete $session->{budmods};
		$session->callback_buddylist_ok();
	} else {
		#$session->log_print(OSCAR_DBG_INFO, "Non-empty blmod queue - sending initiator and first change packet.");
		$session->svcdo(CONNTYPE_BOS, protobit => "start_buddylist_modifications");
		$session->svcdo(CONNTYPE_BOS, %{shift @{$session->{budmods}}}); # Send the first modification
	}
}

sub chain_exists($@) {
	my($tlv, @refs) = @_;

	while(@refs) {
		my $ref = shift @refs;
		if(exists($tlv->{$ref})) {
			$tlv = $tlv->{$ref};
		} else {
			return 0;
		}
	}

	return defined($tlv) ? 1 : 0;	
}

1;
