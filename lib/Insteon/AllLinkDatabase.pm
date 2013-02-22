=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	AllLinkDatabase.pm

Description:
	Generic class implementation of an insteon device's all link database.

Author(s):
	Gregg Liming / gregg@limings.net

License:
	This free software is licensed under the terms of the GNU public license.


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut


package Insteon::AllLinkDatabase;

use strict;
use Insteon;
use Insteon::Lighting;

# @Insteon::AllLinkDatabase::ISA = ('Generic_Item');


sub new
{
	my ($class, $device) = @_;
	my $self={};
	bless $self,$class;
        $$self{device} = $device;
        $self->health("unknown"); # unknown
	return $self;
}

sub _send_cmd
{
   my ($self, $msg) = @_;
   $$self{device}->_send_cmd($msg);
}

sub health
{
	# corrupt
	# unknown
        # empty
        # good
	my ($self, $health) = @_;
        $$self{health} = $health if defined $health;
        return $$self{health};
}

sub scandatetime
{
	my ($self, $scandatetime) = @_;
        $$self{scandatetime} = $scandatetime if defined $scandatetime;
        return $$self{scandatetime};
}

sub restore_string
{
	my ($self) = @_;
	my $restore_string = '';
	if ($$self{aldb}) {
		my $aldb = '';
		foreach my $aldb_key (keys %{$$self{aldb}}) {
			next unless $aldb_key eq 'empty' || $aldb_key eq 'duplicates' || $$self{aldb}{$aldb_key}{inuse};
			$aldb .= '|' if $aldb; # separate sections
			my $record = '';
			if ($aldb_key eq 'empty') {
				foreach my $address (@{$$self{aldb}{empty}}) {
					$record .= ';' if $record;
					$record .= $address;
				}
				$record = 'empty=' . $record;
			} elsif ($aldb_key eq 'duplicates') {
				my $duplicate_record = '';
				foreach my $address (@{$$self{aldb}{duplicates}}) {
					$duplicate_record .= ';' if $duplicate_record;
					$duplicate_record .= $address;
				}
				$record = 'duplicates=' . $duplicate_record;
			} else {
				my %aldb_record = %{$$self{aldb}{$aldb_key}};
				foreach my $record_key (keys %aldb_record) {
					next unless $aldb_record{$record_key};
					$record .= ',' if $record;
					$record .= $record_key . '=' . $aldb_record{$record_key};
				}
			}
			$aldb .= $record;
		}
#		&::print_log("[AllLinkDataBase] aldb restore string: $aldb") if $main::Debug{insteon};
		if (defined $self->scandatetime)
                {
			$restore_string .= $$self{device}->get_object_name . "->_aldb->scandatetime(q~" . $self->scandatetime . "~) if "
                        	. $$self{device}->get_object_name . "->_aldb;\n";
                }
		$restore_string .= $$self{device}->get_object_name . "->_aldb->health(q~" . $self->health . "~) if "
                        	. $$self{device}->get_object_name . "->_aldb;\n";
		$restore_string .= $$self{device}->get_object_name . "->_aldb->restore_aldb(q~$aldb~) if " . $$self{device}->get_object_name . "->_aldb;\n";
        }
	return $restore_string;
}

sub restore_aldb
{
	my ($self,$aldb) = @_;
	if ($aldb) {
		foreach my $aldb_section (split(/\|/,$aldb)) {
			my %aldb_record = ();
			my @aldb_empty = ();
			my @aldb_duplicates = ();
			my $deviceid = '';
			my $groupid = '01';
			my $is_controller = 0;
			my $subaddress = '00';
			foreach my $aldb_entry (split(/,/,$aldb_section)) {
				my ($key,$value) = split(/=/,$aldb_entry);
				next unless $key and defined($value) and $value ne '';
				if ($key eq 'empty') {
					@aldb_empty = split(/;/,$value);
				} elsif ($key eq 'duplicates') {
					@aldb_duplicates = split(/;/,$value);
				} else {
					$deviceid = lc $value if ($key eq 'deviceid');
					$groupid = lc $value if ($key eq 'group');
					$is_controller = $value if ($key eq 'is_controller');
					$subaddress = $value if ($key eq 'data3');
					$aldb_record{$key} = $value if $key and defined($value);
				}
			}
			if (@aldb_empty) {
				@{$$self{aldb}{empty}} = @aldb_empty;
			} elsif (@aldb_duplicates) {
				@{$$self{aldb}{duplicates}} = @aldb_duplicates;
			} elsif (scalar %aldb_record) {
				next unless $deviceid;
				my $aldbkey = $deviceid . $groupid . $is_controller;
				# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
				if ($subaddress ne '00' and $subaddress ne '01') {
					$aldbkey .= $subaddress;
				}
				%{$$self{aldb}{$aldbkey}} = %aldb_record;
			}
		}
#		$self->log_alllink_table();
	}
}




package Insteon::ALDB_i1;

use strict;
use Insteon;
use Insteon::Lighting;
use Insteon::Message;

@Insteon::ALDB_i1::ISA = ('Insteon::AllLinkDatabase');

sub new
{
	my ($class,$device) = @_;

	my $self = new Insteon::AllLinkDatabase($device);
	bless $self,$class;
	return $self;
}

sub _on_poke
{
	my ($self,%msg) = @_;
        my $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'peek');
	if (($$self{_mem_activity} eq 'update') or ($$self{_mem_activity} eq 'add'))
        {
		if ($$self{_mem_action} eq 'aldb_flag')
                {
			$$self{_mem_action} = 'aldb_group';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
                        $message->extra($$self{_mem_lsb});
                        $message->failure_callback($$self{_failure_callback});
			$self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_group')
                {
			$$self{_mem_action} = 'aldb_devhi';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
                        $message->extra($$self{_mem_lsb});
                        $message->failure_callback($$self{_failure_callback});
			$self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_devhi')
                {
			$$self{_mem_action} = 'aldb_devmid';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
                        $message->extra($$self{_mem_lsb});
                        $message->failure_callback($$self{_failure_callback});
			$self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_devmid')
                {
			$$self{_mem_action} = 'aldb_devlo';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
                        $message->extra($$self{_mem_lsb});
                        $message->failure_callback($$self{_failure_callback});
			$self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_devlo')
                {
			$$self{_mem_action} = 'aldb_data1';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
                        $message->extra($$self{_mem_lsb});
                        $message->failure_callback($$self{_failure_callback});
			$self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_data1')
                {
			$$self{_mem_action} = 'aldb_data2';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
                        $message->extra($$self{_mem_lsb});
                        $message->failure_callback($$self{_failure_callback});
			$self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_data2')
                {
			$$self{_mem_action} = 'aldb_data3';
			$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
                        $message->extra($$self{_mem_lsb});
                        $message->failure_callback($$self{_failure_callback});
			$self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_data3')
                {
			## update the aldb records w/ the changes that were made
			my $aldbkey = $$self{pending_aldb}{deviceid}
                        		. $$self{pending_aldb}{group}
                                        . $$self{pending_aldb}{is_controller};
			# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
			my $subaddress = $$self{pending_aldb}{data3};
			if (($subaddress ne '00') and ($subaddress ne '01'))
                        {
				$aldbkey .= $subaddress;
			}
			$$self{aldb}{$aldbkey}{data1} = $$self{pending_aldb}{data1};
			$$self{aldb}{$aldbkey}{data2} = $$self{pending_aldb}{data2};
			$$self{aldb}{$aldbkey}{data3} = $$self{pending_aldb}{data3};
			$$self{aldb}{$aldbkey}{inuse} = 1; # needed so that restore string will preserve record
			if ($$self{_mem_activity} eq 'add')
                        {
				$$self{aldb}{$aldbkey}{is_controller} = $$self{pending_aldb}{is_controller};
				$$self{aldb}{$aldbkey}{deviceid} = lc $$self{pending_aldb}{deviceid};
				$$self{aldb}{$aldbkey}{group} = lc $$self{pending_aldb}{group};
				$$self{aldb}{$aldbkey}{address} = $$self{pending_aldb}{address};
				$self->health("good");
			}
			# clear out mem_activity flag
			$$self{_mem_activity} = undef;
			if (defined $$self{_success_callback})
                        {
				my $callback = $$self{_success_callback};
				# clear it out *before* the eval
				$$self{_success_callback} = undef;
				package main;
				eval ($callback);
				package Insteon::ALDB_i1;
				&::print_log("[Insteon::ALDB_i1] error in link callback: " . $@)
					if $@ and $main::Debug{insteon};
			}
		}
	}
        elsif ($$self{_mem_activity} eq 'update_local')
        {
		if ($$self{_mem_action} eq 'local_onlevel')
                {
			$$self{_mem_lsb} = '21';
			$$self{_mem_action} = 'local_ramprate';
                        $message->extra($$self{_mem_lsb});
                        $message->failure_callback($$self{_failure_callback});
			$self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'local_ramprate')
                {
			if ($$self{device}->isa('Insteon::KeyPadLincRelay') or $$self{device}->isa('Insteon::KeyPadLinc'))
                        {
				# update from eeprom--only a kpl issue
				$message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'do_read_ee');
                                $self->_send_cmd($message);
			}
		}
	}
        elsif ($$self{_mem_activity} eq 'update_flags')
        {
		# update from eeprom--only a kpl issue
		$message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'do_read_ee');
                $message->failure_callback($$self{_failure_callback});
                $self->_send_cmd($message);
	}
        elsif ($$self{_mem_activity} eq 'delete')
        {
		# clear out mem_activity flag
		$$self{_mem_activity} = undef;
		# add the address of the deleted link to the empty list
		$self->add_empty_address($$self{pending_aldb}{address});
                # and, remove from the duplicates list (if it is a member)
                $self->delete_duplicate_link_address($$self{pending_aldb}{address});
		if (exists $$self{pending_aldb}{deviceid})
                {
			my $key = lc $$self{pending_aldb}{deviceid}
                        		. $$self{pending_aldb}{group}
                                        . $$self{pending_aldb}{is_controller};
			# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
			my $subaddress = $$self{pending_aldb}{data3};
			if ($subaddress ne '00' and $subaddress ne '01')
                        {
				$key .= $subaddress;
			}
			delete $$self{aldb}{$key};
		}

		if (defined $$self{_success_callback})
                {
			my $callback = $$self{_success_callback};
			# clear it out *before* the eval
			$$self{_success_callback} = undef;
			package main;
			eval ($callback);
			&::print_log("[Insteon::ALDB_i1] error in link callback: " . $@)
				if $@ and $main::Debug{insteon};
			package Insteon::ALDB_i1;
		}
	}
}

sub _on_peek
{
	my ($self,%msg) = @_;
        my $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'peek');
	if ($msg{is_extended}) {
		&::print_log("[Insteon::ALDB_i1]: extended peek for " . $$self{device}->{object_name}
		. " is " . $msg{extra}) if $main::Debug{insteon};
	}
        else
        {
		if ($$self{_mem_action} eq 'aldb_peek')
                {
			if ($$self{_mem_activity} eq 'scan')
                        {
				$$self{_mem_action} = 'aldb_flag';
				# if the device is responding to the peek, then init the link table
				#   if at the very start of a scan
				if (lc $$self{_mem_msb} eq '0f' and lc $$self{_mem_lsb} eq 'f8')
                                {
					# reinit the aldb hash as there will be a new one
					$$self{aldb} = undef;
					# reinit the empty address list
					@{$$self{aldb}{empty}} = ();
					# and, also the duplicates list
					@{$$self{aldb}{duplicates}} = ();
				}
			}
                        elsif ($$self{_mem_activity} eq 'update')
                        {
				$$self{_mem_action} = 'aldb_data1';
			}
                        elsif ($$self{_mem_activity} eq 'update_local')
                        {
				$$self{_mem_action} = 'local_onlevel';
			}
                        elsif ($$self{_mem_activity} eq 'update_flags')
                        {
				$$self{_mem_action} = 'update_flags';
			}
                        elsif ($$self{_mem_activity} eq 'delete')
                        {
				$$self{_mem_action} = 'aldb_flag';
			}
                        elsif ($$self{_mem_activity} eq 'add')
                        {
				$$self{_mem_action} = 'aldb_flag';
			}
                       	$message->extra($$self{_mem_lsb});
                        $message->failure_callback($$self{_failure_callback});
                       	$self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_flag')
                {
			if ($$self{_mem_activity} eq 'scan')
                        {
                        	&::print_log("[Insteon::ALDB_i1] DEBUG3: " . $$self{device}->get_object_name
                                	. " [0x" . $$self{_mem_msb} . $$self{_mem_lsb} . "] received: "
                                        . lc $msg{extra} . " for " .  $$self{_mem_action}) if  $main::Debug{insteon} >= 3;
				my $flag = hex($msg{extra});
				$$self{pending_aldb}{inuse} = ($flag & 0x80) ? 1 : 0;
				$$self{pending_aldb}{is_controller} = ($flag & 0x40) ? 1 : 0;
				$$self{pending_aldb}{highwater} = ($flag & 0x02) ? 1 : 0;
				if (!($$self{pending_aldb}{highwater}))
                                {
					# since this is the last unused memory location, then add it to the empty list
					$self->add_empty_address($$self{_mem_msb} . $$self{_mem_lsb});
					$$self{_mem_action} = undef;
					# clear out mem_activity flag
					$$self{_mem_activity} = undef;
                                   	if (lc $$self{_mem_msb} eq '0f' and lc $$self{_mem_lsb} eq 'f8')
                                        {
                                        	# set health as empty for now
                                        	$self->health("empty");
					}
                                        else
                                        {
                                        	$self->health("good");
                                        }

					&::print_log("[Insteon::ALDB_i1] " . $$self{device}->get_object_name . " completed link memory scan")
						if $main::Debug{insteon};
					if (defined $$self{_success_callback})
                                        {
						my $callback = $$self{_success_callback};
						# clear it out *before* the eval
						$$self{_success_callback} = undef;
						package main;
						eval ($callback);
						&::print_log("[Insteon::ALDB_i1] " . $$self{device}->get_object_name . ": error during scan callback $@")
							if $@ and $main::Debug{insteon};
						package Insteon::ALDB_i1;
					}
				}
                                elsif ($$self{pending_aldb}{inuse})
                                {
					$$self{pending_aldb}{flag} = $msg{extra};
					## confirm that we have a high-water mark; otherwise stop
					$$self{pending_aldb}{address} = $$self{_mem_msb} . $$self{_mem_lsb};
					$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
					$$self{_mem_action} = 'aldb_group';
                                	$message->extra($$self{_mem_lsb});
                        		$message->failure_callback($$self{_failure_callback});
                                	$self->_send_cmd($message);
				} else {
					$self->add_empty_address($$self{_mem_msb} . $$self{_mem_lsb});
					if ($$self{_mem_activity} eq 'scan'){
						my $newaddress = sprintf("%04X", hex($$self{_mem_msb} . $$self{_mem_lsb}) - 8);
						$$self{pending_aldb} = undef;
						$self->_peek($newaddress);
					}
				}
			}
                        elsif ($$self{_mem_activity} eq 'add')
                        {
                        	# TO-DO!!! Eventually add the ability to set the highwater mark
                                #  the below flags never reset the highwater mark so that
                                #  the scanner will continue scanning extra empty records
				my $flag = ($$self{pending_aldb}{is_controller}) ? 'E2' : 'A2';
				$$self{pending_aldb}{flag} = $flag;
                                $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                                $message->extra($flag);
                        	$message->failure_callback($$self{_failure_callback});
                                $self->_send_cmd($message);
			}
                        elsif ($$self{_mem_activity} eq 'delete')
                        {
                                $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                                $message->extra('02');
                        	$message->failure_callback($$self{_failure_callback});
                                $self->_send_cmd($message);
			}
		}
                elsif ($$self{_mem_action} eq 'aldb_group')
                {
			if ($$self{_mem_activity} eq 'scan')
                        {
                        	&::print_log("[Insteon::ALDB_i1] DEBUG3: " . $$self{device}->get_object_name
                                	. " [0x" . $$self{_mem_msb} . $$self{_mem_lsb} . "] received: "
                                        . lc $msg{extra} . " for " .  $$self{_mem_action}) if  $main::Debug{insteon} >= 3;
				$$self{pending_aldb}{group} = lc $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'aldb_devhi';
                               	$message->extra($$self{_mem_lsb});
			}
                        else
                        {
                                $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                                $message->extra($$self{pending_aldb}{group});
			}
                        $message->failure_callback($$self{_failure_callback});
                        $self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_devhi')
                {
			if ($$self{_mem_activity} eq 'scan')
                        {
                        	&::print_log("[Insteon::ALDB_i1] DEBUG3: " . $$self{device}->get_object_name
                                	. " [0x" . $$self{_mem_msb} . $$self{_mem_lsb} . "] received: "
                                        . lc $msg{extra} . " for " .  $$self{_mem_action}) if  $main::Debug{insteon} >= 3;
				$$self{pending_aldb}{deviceid} = lc $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'aldb_devmid';
                               	$message->extra($$self{_mem_lsb});
			}
                        elsif ($$self{_mem_activity} eq 'add')
                        {
				my $devid = substr($$self{pending_aldb}{deviceid},0,2);
                                $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                                $message->extra($devid);
			}
                        $message->failure_callback($$self{_failure_callback});
                        $self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_devmid')
                {
			if ($$self{_mem_activity} eq 'scan')
                        {
                        	&::print_log("[Insteon::ALDB_i1] DEBUG3: " . $$self{device}->get_object_name
                                	. " [0x" . $$self{_mem_msb} . $$self{_mem_lsb} . "] received: "
                                        . lc $msg{extra} . " for " .  $$self{_mem_action}) if  $main::Debug{insteon} >= 3;
				$$self{pending_aldb}{deviceid} .= lc $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'aldb_devlo';
                               	$message->extra($$self{_mem_lsb});
			}
                        elsif ($$self{_mem_activity} eq 'add')
                        {
				my $devid = substr($$self{pending_aldb}{deviceid},2,2);
                                $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                                $message->extra($devid);
			}
                        $message->failure_callback($$self{_failure_callback});
                        $self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'aldb_devlo')
                {
			if ($$self{_mem_activity} eq 'scan')
                        {
                        	&::print_log("[Insteon::ALDB_i1] DEBUG3: " . $$self{device}->get_object_name
                                	. " [0x" . $$self{_mem_msb} . $$self{_mem_lsb} . "] received: "
                                        . lc $msg{extra} . " for " .  $$self{_mem_action}) if  $main::Debug{insteon} >= 3;
				$$self{pending_aldb}{deviceid} .= lc $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'aldb_data1';
                               	$message->extra($$self{_mem_lsb});
                        	$message->failure_callback($$self{_failure_callback});
                               	$self->_send_cmd($message);
			}
                        elsif ($$self{_mem_activity} eq 'add')
                        {
				my $devid = substr($$self{pending_aldb}{deviceid},4,2);
                                $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                                $message->extra($devid);
                        	$message->failure_callback($$self{_failure_callback});
                                $self->_send_cmd($message);
			}
		}
                elsif ($$self{_mem_action} eq 'aldb_data1')
                {
			if ($$self{_mem_activity} eq 'scan')
                        {
                        	&::print_log("[Insteon::ALDB_i1] DEBUG3: " . $$self{device}->get_object_name
                                	. " [0x" . $$self{_mem_msb} . $$self{_mem_lsb} . "] received: "
                                        . lc $msg{extra} . " for " .  $$self{_mem_action}) if  $main::Debug{insteon} >= 3;
				$$self{_mem_action} = 'aldb_data2';
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{pending_aldb}{data1} = $msg{extra};
                               	$message->extra($$self{_mem_lsb});
                        	$message->failure_callback($$self{_failure_callback});
                               	$self->_send_cmd($message);
			}
                        elsif ($$self{_mem_activity} eq 'update' or $$self{_mem_activity} eq 'add')
                        {
				# poke the new value
                                $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                                $message->extra($$self{pending_aldb}{data1});
                        	$message->failure_callback($$self{_failure_callback});
                                $self->_send_cmd($message);
			}
		}
                elsif ($$self{_mem_action} eq 'aldb_data2')
                {
			if ($$self{_mem_activity} eq 'scan')
                        {
                        	&::print_log("[Insteon::ALDB_i1] DEBUG3: " . $$self{device}->get_object_name
                                	. " [0x" . $$self{_mem_msb} . $$self{_mem_lsb} . "] received: "
                                        . lc $msg{extra} . " for " .  $$self{_mem_action}) if  $main::Debug{insteon} >= 3;
				$$self{pending_aldb}{data2} = $msg{extra};
				$$self{_mem_lsb} = sprintf("%02X", hex($$self{_mem_lsb}) + 1);
				$$self{_mem_action} = 'aldb_data3';
                               	$message->extra($$self{_mem_lsb});
                        	$message->failure_callback($$self{_failure_callback});
                               	$self->_send_cmd($message);
			}
                        elsif ($$self{_mem_activity} eq 'update' or $$self{_mem_activity} eq 'add')
                        {
				# poke the new value
                                $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                                $message->extra($$self{pending_aldb}{data2});
                        	$message->failure_callback($$self{_failure_callback});
                                $self->_send_cmd($message);
			}
		}
                elsif ($$self{_mem_action} eq 'aldb_data3')
                {
			if ($$self{_mem_activity} eq 'scan')
                        {
                        	&::print_log("[Insteon::ALDB_i1] DEBUG3: " . $$self{device}->get_object_name
                                	. " [0x" . $$self{_mem_msb} . $$self{_mem_lsb} . "] received: "
                                        . lc $msg{extra} . " for " .  $$self{_mem_action}) if  $main::Debug{insteon} >= 3;
				$$self{pending_aldb}{data3} = $msg{extra};
				# check the previous record if highwater is set
				if ($$self{pending_aldb}{highwater})
                                {
					if ($$self{pending_aldb}{inuse})
                                        {
					# save pending_aldb and then clear it out
						my $aldbkey = lc $$self{pending_aldb}{deviceid}
							. $$self{pending_aldb}{group}
							. $$self{pending_aldb}{is_controller};
						# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
						my $subaddress = $$self{pending_aldb}{data3};
						if ($subaddress ne '00' and $subaddress ne '01')
                                                {
							$aldbkey .= $subaddress;
						}
						# check for duplicates
						if (exists $$self{aldb}{$aldbkey} && $$self{aldb}{$aldbkey}{inuse})
                                                {
							$self->add_duplicate_link_address($$self{pending_aldb}{address});
						}
                                                else
                                                {
							%{$$self{aldb}{$aldbkey}} = %{$$self{pending_aldb}};
						}
					}
                                        else
                                        {
						$self->add_empty_address($$self{pending_aldb}{address});
					}
					my $newaddress = sprintf("%04X", hex($$self{pending_aldb}{address}) - 8);
					$$self{pending_aldb} = undef;
					$self->_peek($newaddress);
				}
			}
                        elsif ($$self{_mem_activity} eq 'update' or $$self{_mem_activity} eq 'add')
                        {
				# poke the new value
                                $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                                $message->extra($$self{pending_aldb}{data3});
                        	$message->failure_callback($$self{_failure_callback});
                                $self->_send_cmd($message);
			}
		}
                elsif ($$self{_mem_action} eq 'local_onlevel')
                {
			my $device = $$self{device};
			my $on_level = $$device{_onlevel};
			$on_level = &Insteon::DimmableLight::convert_level($on_level);
                        $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                        $message->extra($on_level);
                        $message->failure_callback($$self{_failure_callback});
                        $self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'local_ramprate')
                {
                        my $device = $$self{device};
			my $ramp_rate = $$device{_ramprate};
			$ramp_rate = '1f' unless $ramp_rate;
                        $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                        $message->extra($ramp_rate);
                        $message->failure_callback($$self{_failure_callback});
                        $self->_send_cmd($message);
		}
                elsif ($$self{_mem_action} eq 'update_flags')
                {
			my $flags = $$self{_operating_flags};
                        $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'poke');
                        $message->extra($flags);
                        $message->failure_callback($$self{_failure_callback});
                        $self->_send_cmd($message);
		}
#
#			&::print_log("AllLinkDataBase: peek for " . $self->{object_name}
#		. " is " . $msg{extra}) if $main::Debug{insteon};
	}
}


sub scan_link_table
{
	my ($self,$success_callback,$failure_callback) = @_;
	$$self{_mem_activity} = 'scan';
	$$self{_success_callback} = ($success_callback) ? $success_callback : undef;
	$$self{_failure_callback} = ($failure_callback) ? $failure_callback : undef;
        $self->scandatetime(&main::get_tickcount);
        $self->health('corrupt'); # allow acknowledge to set otherwise
	$self->_peek('0FF8',0);
}

sub delete_link
{
	my ($self, $parms_text) = @_;
	my %link_parms;
	if (@_ > 2)
        {
		shift @_;
		%link_parms = @_;
	}
        else
        {
		%link_parms = &main::parse_func_parms($parms_text);
	}
	$$self{_success_callback} = ($link_parms{callback}) ? $link_parms{callback} : undef;
	$$self{_failure_callback} = ($link_parms{failure_callback}) ? $link_parms{failure_callback} : undef;
	if ($link_parms{address})
        {
	   	&main::print_log("[Insteon::ALDB_i1] Now deleting link [0x$link_parms{address}]");
		$$self{_mem_activity} = 'delete';
		$$self{pending_aldb}{address} = $link_parms{address};
		$self->_peek($link_parms{address},0);

	}
        else
        {
		my $insteon_object = $link_parms{object};
		my $deviceid = ($insteon_object) ? $insteon_object->device_id : $link_parms{deviceid};
		my $groupid = $link_parms{group};
		$groupid = '01' unless $groupid;
		my $is_controller = ($link_parms{is_controller}) ? 1 : 0;
		my $subaddress = ($link_parms{data3}) ? $link_parms{data3} : '00';
		# get the address via lookup into the hash
		my $key = lc $deviceid . $groupid . $is_controller;
		# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
		if ($subaddress ne '00' and $subaddress ne '01')
                {
			$key .= $subaddress;
		}
		my $address = $$self{aldb}{$key}{address};
		if ($address)
                {
			&main::print_log("[Insteon::ALDB_i1] Now deleting link [0x$address] with the following data"
				. " deviceid=$deviceid, groupid=$groupid, is_controller=$is_controller");
			# now, alter the flags byte such that the in_use flag is set to 0
			$$self{_mem_activity} = 'delete';
			$$self{pending_aldb}{deviceid} = lc $deviceid;
			$$self{pending_aldb}{group} = $groupid;
			$$self{pending_aldb}{is_controller} = $is_controller;
			$$self{pending_aldb}{address} = $address;
			$self->_peek($address,0);
		}
                else
                {
			&main::print_log('[Insteon::ALDB_i1] WARN: (' . $$self{device}->get_object_name . ') attempt to delete link that does not exist!'
				. " deviceid=$deviceid, groupid=$groupid, is_controller=$is_controller");
			if ($link_parms{callback})
                        {
				package main;
				eval($link_parms{callback});
				&::print_log("[Insteon::ALDB_i1] error encountered during delete_link callback: " . $@)
					if $@ and $main::Debug{insteon};
				package Insteon::AllLinkDataBase;
			}
		}
	}
}

sub delete_orphan_links
{
	my ($self, $audit_mode) = @_;
	@{$$self{delete_queue}} = (); # reset the work queue
	$$self{delete_queue_processed} = 0;
	my $selfname = $$self{device}->get_object_name;
	my $num_deleted = 0;

        # first, make sure that the health of ALDB is ok
        if ($self->health ne 'good')
        {
        	if ($$self{device}->isa('Insteon::RemoteLinc') or $$self{device}->isa('Insteon::MotionSensor'))
                {
        		&::print_log("[Insteon::ALDB_i1] Delete orphan links: ignoring link from deaf device: $selfname");

                }
                else
                {
        		&::print_log("[Insteon::ALDB_i1] Delete orphan links: skipping $selfname because health: "
                		. $self->health . ". Please rescan this device!!")
                       		if ($self->health ne 'empty');
                }
		$self->_process_delete_queue();
                return;
        }

	for my $linkkey (keys %{$$self{aldb}})
        {
		if ($linkkey ne 'empty' and $linkkey ne 'duplicates')
                {
			my $deviceid = lc $$self{aldb}{$linkkey}{deviceid};
			next unless $deviceid;
			my $group = $$self{aldb}{$linkkey}{group};
			my $is_controller = $$self{aldb}{$linkkey}{is_controller};
			my $data3 = $$self{aldb}{$linkkey}{data3};
                        # $device is the object that is referenced by the ALDB record's deviceid
			my $linked_device = ($deviceid eq lc $$self{device}->interface->device_id) ? $$self{device}->interface
					: &Insteon::get_object($deviceid,'01');
			if (!($linked_device))
                        {
                        	# no device is known by mh with the ALDB record's deviceid
                        	if ($audit_mode)
                                {
					&::print_log("[Insteon::ALDB_i1] (AUDIT) " . $selfname . " now deleting orphaned link w/ details: "
						. (($is_controller) ? "controller" : "responder")
						. ", deviceid=$deviceid, group=$group");
                                }
                                else
                                {
			       		my %delete_req = (deviceid => $deviceid,
                                        		group => $group,
                                                        is_controller => $is_controller,
							callback => "$selfname->_aldb->_process_delete_queue()",
                                                        data3 => $data3,
                                                        cause => "no device could be found");
			       		push @{$$self{delete_queue}}, \%delete_req;
                                }
			}
                        elsif ($linked_device->isa("Insteon::BaseInterface") and $is_controller)
                        {
				# ignore since this is just a link back to the PLM
			}
                        elsif ($linked_device->isa("Insteon::BaseInterface")) # and is a RESPONDER!!
                        {
				# does the PLM have a corresponding controlled link to $self?  If not, the delete this responder link
				if (!($linked_device->has_link($$self{device},$group,1)))
                                {
                                	if ($audit_mode)
                                        {
                                        	my $plm_scene = &Insteon::get_object('000000',$group);
						&::print_log("[Insteon::ALDB_i1] (AUDIT) Now deleting orphaned responder link in "
                                                	. $$self{device}->get_object_name
                                                        . (($data3 eq '00' or $data3 eq '01') ? "" : " [button:" . $data3 . "]")
                                                	. " because PLM does not have a corresponding controller record "
                                                	. "with group ($group)." . (($plm_scene && ref $plm_scene) ? " Please resync "
                                                        . $plm_scene->get_object_name . " before re-running in non-audit mode to restore PLM side"
                                                        : ""));
                                        }
                                        else
                                        {
				       		my %delete_req = (deviceid => $deviceid,
                                                		group => $group,
                                                                is_controller => $is_controller,
								callback => "$selfname->_aldb->_process_delete_queue()",
                                                                object => $linked_device,
                                                                data3 => $data3,
                                                        	cause => 'PLM does not have a link pointing back to device');
						push @{$$self{delete_queue}}, \%delete_req;
						$num_deleted++;
                                        }
				}
                                else
                                {
					# is there an entry in the items.mht that corresponds to this link?
                                	# find the corresponding PLM scene that has this group
					my $plm_link = &Insteon::get_object('000000', $group);
					if ($plm_link)
                                        {
						my $is_invalid = 1;
                                                # now, iterate over the PLM scene members to see if a match exists
						foreach my $member_ref (keys %{$$plm_link{members}})
                                                {
							my $member = $$plm_link{members}{$member_ref}{object};
							if ($member->isa('Light_Item'))
                                                        {
								my @lights = $member->find_members('Insteon::BaseLight');
								if (@lights)
                                                                {
									$member = @lights[0]; # pick the first
								}
							}
							if ($member->device_id eq $$self{device}->device_id)
                                                        {
								if ($data3 eq '00' or (lc $data3 eq lc $member->group))
                                                                {
									$is_invalid = 0;
							       		last;
								}
							}
						}
						if ($is_invalid)
                                                {
                                                	if ($audit_mode)
                                                        {
                                                        	my $button_msg = "";
                                                                if ($data3 ne '00' and $data3 ne '01')
                                                                {
                                                                       ## to-do - validate that $data3 is <= 8 for all 8 key devices
                                                                       $button_msg = " [button:" . $data3 . "]";
                                                                }
								&::print_log("[Insteon::ALDB_i1] (AUDIT) Delete orphan responder link from "
                                                                	. $selfname . $button_msg
                                                			. " to PLM because no SCENE_MEMBER entry could be found "
                                                                        . "in items.mht for INSTEON_ICONTROLLER: "
                                                                        . $plm_link->get_object_name);
                                                        }
                                                        else
                                                        {
								my %delete_req = (deviceid => $deviceid, group => $group, is_controller => $is_controller,
									callback => "$selfname->_aldb->_process_delete_queue()", object => $linked_device,
									cause => "no link is defined for the plm controlled scene", data3 => $data3);
						       		push @{$$self{delete_queue}}, \%delete_req;
								$num_deleted++;
                                                        }
						}
					}
                                        else
                                        {    # no corresponding PLM link found
                                        	if ($audit_mode)
                                                {
                                                        my $button_msg = "";
                                                        if ($data3 ne '00' and $data3 ne '01')
                                                        {
                                                                ## to-do - validate that $data3 is <= 8 for all 8 key devices
                                                                $button_msg = " [button:" . $data3 . "]";
                                                        }
							&::print_log("[Insteon::ALDB_i1] (AUDIT) Delete orphan responder link from "
                                				. $selfname . $button_msg . " to PLM because to PLM contoller exists for group:$group");
                                                }
                                                else
                                                {
							# delete the link since it doesn't exist
							my %delete_req = (deviceid => $deviceid, group => $group, is_controller => $is_controller,
								callback => "$selfname->_aldb->_process_delete_queue()", object => $linked_device,
								cause => "no plm link could be found", data3 => $data3);
							push @{$$self{delete_queue}}, \%delete_req;
							$num_deleted++;
                                                }
					}
                                }
			}
                        else # is a non-PLM device
                        {
                        	if ($linked_device->isa('Insteon::RemoteLinc') or $linked_device->isa('Insteon::MotionSensor'))
                                {
                                	&::print_log("[Insteon::ALDB_i1] Delete orphan links: ignoring link from $selfname to 'deaf' device: " . $linked_device->get_object_name);
                                }
                                # make sure that the health of the device's ALDB is ok
        			elsif ($linked_device->_aldb->health ne 'good')
       				{
        				&::print_log("[Insteon::ALDB_i1] Delete orphan links: skipping check for reciprocal links from "
                                        	. $linked_device->get_object_name . " because health: "
                				. $linked_device->_aldb->health . ". Please rescan this device!!")
                				if ($linked_device->_aldb->health ne 'empty');
        			}
                                else
                                {
                               		# does the device fail to have a reciprocal link?
                                	if (!($linked_device->has_link($self,$group,($is_controller) ? 0:1, $data3)))
                                	{
                                        	# this may be a case of an impartial link (not yet bidirectional)
                                        	# BUT... if is_controller and $device is not a member of $$self{device}
                                                #        if not is_controller and $$self{device} is not a member of $device,
                                                #        then the dangling link needs to be deleted
                                		if ($audit_mode)
                                        	{
                                        		if ($is_controller)
                                                	{
                                                        	# reference_object is the controller that is referenced by this ALDB's deviceid and the group
                                                		my $reference_object = &Insteon::get_object($$self{device}->device_id, $group);
                                                                # reverse_object is the responder referenced by the ALDB link and it's data3 content
                                                		my $reverse_object = &Insteon::get_object($linked_device->device_id, ($data3 eq '00') ? '01' : $data3);
                                                        	if (ref $reference_object and ref $reverse_object and
                                                                	$reference_object->isa("Insteon::BaseController") and
                                                                        $reference_object->has_member($reverse_object))
                                                                {
                                                			&::print_log("[Insteon::ALDB_i1] (AUDIT) WARNING: no reciprocal link defined for: "
                                        				. $reference_object->get_object_name
                                                			. " as controller and "
                                        				. $reverse_object->get_object_name
                                                                	. ". Please sync links with the applicable device; this link will not be deleted."
							       		);
                                                                }
                                                                else
                                                                {
                                                			&::print_log("[Insteon::ALDB_i1] (AUDIT) Deleting link defined for: "
                                        				. $$self{device}->get_object_name
                                                			. "($group) as controller and "
                                        				. $linked_device->get_object_name .  "(" . (($data3 eq '00') ? '01' : $data3) . ")"
                                                                	. " because no reciprocal link exists!"
							       		);
                                                                }
                                                	}
                                                	else # is a responder
                                                	{
                                                        	# reference_object is the responder that is referenced by this ALDB's deviceid
                                                                #   and the ALDB link's data3
                                                		my $reference_object = &Insteon::get_object($$self{device}->device_id,
                                                                                         ($data3 eq '00') ? '01' : $data3);
                                                                # reverse_object is the controller referenced by the ALDB link and the group
                                                		my $reverse_object = &Insteon::get_object($linked_device->device_id, $group );
                                                        	if (ref $reference_object and ref $reverse_object and $reverse_object->isa("Insteon::BaseController") and $reverse_object->has_member($reference_object))
                                                                {
                                                			&::print_log("[Insteon::ALDB_i1] (AUDIT) WARNING: no reverse link defined for: "
                                        				. $reference_object->get_object_name
                                                			. " as responder and "
                                        				. $reverse_object->get_object_name
                                                                	. ". Please sync links with the applicable device; this link will not be deleted."
									);
                                                		}
                                                                else
                                                                {
                                                			&::print_log("[Insteon::ALDB_i1] (AUDIT) Deleting link defined for: "
                                        				. $$self{device}->get_object_name
                                                			. "(" . (($data3 eq '00') ? '01' : $data3) . ") as responder and "
                                        				. $linked_device->get_object_name . "($group)"
                                                                	. " because no reverse links exists!"
									);
                                                                }
                                                        }
                                        	}
                                        	else  # non-audit mode
                                        	{
                                        		if ($is_controller)
                                                	{
                                                		my $reference_object = &Insteon::get_object($$self{device}->device_id, $group);
                                                		my $reverse_object = &Insteon::get_object($linked_device->device_id, ($data3 eq '00') ? '01' : $data3);
                                                        	if (ref $reference_object and ref $reverse_object and $reverse_object->isa("Insteon::BaseController") and $reverse_object->has_member($reference_object))
                                                                {
                                                			&::print_log("[Insteon::ALDB_i1] WARNING: no reciprocal link defined for: "
                                        				. $reference_object->get_object_name
                                                			. " as controller and "
                                        				. $reverse_object->get_object_name
                                                                	. ". Please sync links with the applicable device; this link will not be deleted."
							       		);
                                                                }
                                                                else
                                                                {
                                                			&::print_log("[Insteon::ALDB_i1] Deleting link defined for: "
                                        				. $$self{device}->get_object_name
                                                			. "($group) as controller and "
                                        				. $linked_device->get_object_name .  "(" . (($data3 eq '00') ? '01' : $data3) . ")"
                                                                	. " because no reciprocal link exists!"
							       		);
					       				my %delete_req = (deviceid => $deviceid,
                                                                        		group => $group,
                                                                                        is_controller => $is_controller,
											callback => "$selfname->_process_delete_queue()",
                                                                                        object => $linked_device,
											cause => "no link to the device could be found",
                                                                                        data3 => $data3);
					       				push @{$$self{delete_queue}}, \%delete_req;
									$num_deleted++;
                                                                }
                                                	}
                                                	else # is a responder
                                                	{
                                                		my $reference_object = &Insteon::get_object($$self{device}->device_id, ($data3 eq '00') ? '01' : $data3);
                                                		my $reverse_object = &Insteon::get_object($linked_device->device_id, $group );
                                                        	if (ref $reference_object and ref $reverse_object and $reverse_object->isa("Insteon::BaseController") and $reverse_object->has_member($reference_object))
                                                                {
                                                			&::print_log("[Insteon::ALDB_i1] WARNING: no reverse link defined for: "
                                        				. $reference_object->get_object_name
                                                			. " as responder and "
                                        				. $reverse_object->get_object_name
                                                                	. ". Please sync links with the applicable device; this link will not be deleted."
									);
                                                                }
                                                                else
                                                                {
                                                			&::print_log("[Insteon::ALDB_i1] Deleting link defined for: "
                                        				. $$self{device}->get_object_name
                                                			. "(" . (($data3 eq '00') ? '01' : $data3) . ") as responder and "
                                        				. $linked_device->get_object_name . "($group)"
                                                                	. " because no reverse links exists!"
									);
					       				my %delete_req = (deviceid => $deviceid,
                                                                        		group => $group,
                                                                                        is_controller => $is_controller,
											callback => "$selfname->_process_delete_queue()",
                                                                                        object => $linked_device,
											cause => "no link to the device could be found",
                                                                                        data3 => $data3);
					       				push @{$$self{delete_queue}}, \%delete_req;
									$num_deleted++;
                                                                }
                                                	}
                                        	}
					}
                                	else # device does have reciprocal link
                                	{
				       		my $is_invalid = 1;
						my $link = ($is_controller) ? &Insteon::get_object($$self{device}->device_id,$group)
						: &Insteon::get_object($linked_device->device_id,$group);
						if ($link)
                                        	{
							foreach my $member_ref (keys %{$$link{members}})
                                                	{
						       		my $member = $$link{members}{$member_ref}{object};
								if ($member->isa('Light_Item'))
                                                        	{
									my @lights = $member->find_members('Insteon::BaseLight');
							       		if (@lights)
                                                                	{
										$member = @lights[0]; # pick the first
									}
								}
								if ($member->isa('Insteon::BaseDevice') && !($member->is_root))
                                                        	{
									$member = $member->get_root;
								}
                        					if ($member->isa('Insteon::RemoteLinc') or $member->isa('Insteon::MotionSensor'))
                                                        	{
                                                               		&::print_log("[Insteon::ALDB_i1] ignoring link from " . $link->get_object_name . " to " .
                                                               		$member->get_object_name);
                                                               		$is_invalid = 0;
                                                        	}
                                                       		elsif ($member->isa('Insteon::BaseDevice') && !($is_controller)
                                                        		&& ($member->device_id eq $$self{device}->device_id))
                                                        	{
									$is_invalid = 0;
									last;
								}
                                                        	elsif ($member->isa('Insteon::BaseDevice') && $is_controller
                                                        		&& ($member->device_id eq $linked_device->device_id))
                                                		{
									$is_invalid = 0;
									last;
								}
							} # foreach
						}
						if ($is_invalid)
                                       		{
                                        		if ($audit_mode)
                                                	{
								&::print_log("[Insteon::ALDB_i1] (AUDIT) Delete orphan because no reverse link could be found "
                                        			. $linked_device->get_object_name .
                                                		" details: "
								. (($is_controller) ? "controller" : "responder")
								. ", deviceid=$deviceid, group=$group, data=$data3");
                                                	}
                                                	else
                                                	{
					       			my %delete_req = (deviceid => $deviceid,
                                                                		group => $group,
                                                                                is_controller => $is_controller,
										callback => "$selfname->_aldb->_process_delete_queue()",
                                                                                object => $linked_device,
						       				cause => "no reverse link could be found",
                                                                                data3 => $data3);
						       		push @{$$self{delete_queue}}, \%delete_req;
						       		$num_deleted++;
                                                	}
						}
                                        }
				}
			}
		}
                elsif ($linkkey eq 'duplicates')
                {
                	my @duplicate_addresses = ();
                        push @duplicate_addresses, @{$$self{aldb}{duplicates}};
			my $address = pop @duplicate_addresses;
			while ($address)
                        {
                        	if ($audit_mode)
                                {
					&::print_log("[Insteon::ALDB_i1] (AUDIT) Delete orphan because duplicate found "
                                        	. "$selfname, address=$address");
                                }
                                else
                                {
			       		my %delete_req = (address => $address,
							callback => "$selfname->_aldb->_process_delete_queue()",
							cause => "duplicate record found");
					push @{$$self{delete_queue}}, \%delete_req;
					$num_deleted++;
                                }
				$address = pop @duplicate_addresses;
			}
		}
	}
        if (!($audit_mode))
        {
        	&::print_log("[Insteon::ALDB_i1] ## Begin processing delete queue for: $selfname");
        }
	$self->_process_delete_queue();
}

sub _process_delete_queue {
	my ($self) = @_;
	my $num_in_queue = @{$$self{delete_queue}};
	if ($num_in_queue)
        {
		my $delete_req_ptr = shift(@{$$self{delete_queue}});
		my %delete_req = %$delete_req_ptr;
		if ($delete_req{address})
                {
			&::print_log("[Insteon::ALDB_i1] (#$num_in_queue) " . $$self{device}->get_object_name . " now deleting duplicate record at address "
				. $delete_req{address});
		}
                else
                {
			&::print_log("[Insteon::ALDB_i1] (#$num_in_queue) " . $$self{device}->get_object_name . " now deleting orphaned link w/ details: "
				. (($delete_req{is_controller}) ? "controller" : "responder")
				. ", " . (($delete_req{object}) ? "device=" . $delete_req{object}->get_object_name
				: "deviceid=$delete_req{deviceid}") . ", group=$delete_req{group}, cause=$delete_req{cause}");
		}
		$self->delete_link(%delete_req);
		$$self{delete_queue_processed}++;
	}
        else
        {
        	&::print_log("[Insteon::ALDB_i1] Nothing else to do for " . $$self{device}->get_object_name . " after deleting "
                	. $$self{delete_queue_processed} . " links") if $main::Debug{insteon};
		$$self{device}->interface->_aldb->_process_delete_queue($$self{delete_queue_processed});
	}
}

sub add_duplicate_link_address
{
	my ($self, $address) = @_;

        unshift @{$$self{aldb}{duplicates}}, $address;

        # now, keep the list sorted!
        @{$$self{aldb}{duplicates}} = sort(@{$$self{aldb}{duplicates}});

}

sub delete_duplicate_link_address
{
	my ($self, $address) = @_;
        my $num_duplicate_link_addresses = 0;
        
	$num_duplicate_link_addresses = @{$$self{aldb}{duplicates}} if (defined $$self{aldb}{duplicates});
        if ($num_duplicate_link_addresses)
        {
        	my @temp_duplicates = ();
        	foreach my $temp_address (@{$$self{aldb}{duplicates}})
        	{
                	if ($temp_address ne $address)
                        {
                        	push @temp_duplicates, $temp_address;
                        }
        	}
                # keep it sorted
                @{$$self{aldb}{duplicates}} = sort(@temp_duplicates);
        }
}

sub add_empty_address
{
	my ($self, $address) = @_;
        # before adding it, make sure that it isn't already in the list!!
	my $num_addresses = 0;
	$num_addresses = @{$$self{aldb}{empty}} if (defined $$self{aldb}{empty});
        my $exists = 0;
        if ($num_addresses and $address)
        {
        	foreach my $temp_address (@{$$self{aldb}{empty}})
        	{
                	if ($temp_address eq $address)
                        {
                        	$exists = 1;
                                last;
                        }
        	}
        }
        # add it to the list if it doesn't exist
        if (!($exists) and $address)
        {
		unshift @{$$self{aldb}{empty}}, $address;
        }

        # now, keep the list sorted!
        @{$$self{aldb}{empty}} = sort(@{$$self{aldb}{empty}});

}

sub get_first_empty_address
{
	my ($self) = @_;

        # NOTE: The issue here is that we give up an address from the list
        #   with the assumption that it will be made non-empty;
        #   So, if there is a problem during update/add, then will have
        #   a non-empty, but non-functional entry
	my $first_address = pop @{$$self{aldb}{empty}};

        if (!($first_address))
        {
        	# then, cycle through all of the existing non-empty addresses
                # to find the lowest one and then decrement by 8
                #
                # TO-DO: factor in appropriate use of the "highwater" flag
                #
		my $low_address = 0;
		for my $key (keys %{$$self{aldb}})
                {
			next if $key eq 'empty' or $key eq 'duplicates';
			my $new_address = hex($$self{aldb}{$key}{address});
			if (!($low_address))
                        {
				$low_address = $new_address;
				next;
			}
                        else
                        {
				$low_address = $new_address if (($new_address < $low_address) && ($new_address != 0));
			}
		}
		$first_address = ($low_address > 0) ? sprintf('%04X', $low_address - 8) : 0;
	}

        return $first_address;
}

sub add_link
{
	my ($self, $parms_text) = @_;
	my %link_parms;
	if (@_ > 2)
        {
		shift @_;
		%link_parms = @_;
	}
        else
        {
		%link_parms = &main::parse_func_parms($parms_text);
	}
	my $device_id;
	my $insteon_object = $link_parms{object};
	my $group = $link_parms{group};
	if (!(defined($insteon_object)))
        {
		$device_id = lc $link_parms{deviceid};
		$insteon_object = &Insteon::get_object($device_id, $group);
	}
        else
        {
		$device_id = lc $insteon_object->device_id;
	}
	my $is_controller = ($link_parms{is_controller}) ? 1 : 0;
	# check whether the link already exists
	my $subaddress = ($link_parms{data3}) ? $link_parms{data3} : '00';
	# get the address via lookup into the hash
	my $key = lc $device_id . $group . $is_controller;
	# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
	if (!($subaddress eq '00' or $subaddress eq '01'))
        {
		$key .= $subaddress;
	}
	if (defined $$self{aldb}{$key}{inuse})
        {
		&::print_log("[Insteon::ALDB_i1] WARN: attempt to add link to " . $$self{device}->get_object_name . " that already exists! "
			. "object=" . $insteon_object->get_object_name . ", group=$group, is_controller=$is_controller");
		if ($link_parms{callback})
                {
			package main;
			eval($link_parms{callback});
			&::print_log("[Insteon::ALDB_i1] failure occurred in callback eval for " . $$self{device}->get_object_name . ":" . $@)
				if $@ and $main::Debug{insteon};
			package Insteon::ALDB_i1;
		}
	}
        else
        {
		# strip optional % sign to append on_level
		my $on_level = $link_parms{on_level};
		$on_level =~ s/(\d)%?/$1/;
		$on_level = '100' unless defined($on_level); # 100% == on is the default
		# strip optional s (seconds) to append ramp_rate
		my $ramp_rate = $link_parms{ramp_rate};
		$ramp_rate =~ s/(\d)s?/$1/;
		$ramp_rate = '0.1' unless $ramp_rate; # 0.1s is the default
		# get the first available memory location
		my $address = $self->get_first_empty_address();
		$$self{_success_callback} = ($link_parms{callback}) ? $link_parms{callback} : undef;
		$$self{_failure_callback} = ($link_parms{failure_callback}) ? $link_parms{failure_callback} : undef;
                if ($address)
                {
			&::print_log("[Insteon::ALDB_i1] DEBUG2: adding link record " . $$self{device}->get_object_name
				. " light level controlled by " . $insteon_object->get_object_name
		       		. " and group: $group with on level: $on_level and ramp rate: $ramp_rate")
                                if $main::Debug{insteon} >= 2;
	       		my $data1 = &Insteon::DimmableLight::convert_level($on_level);
			my $data2 = ($$self{device}->isa('Insteon::DimmableLight')) ? &Insteon::DimmableLight::convert_ramp($ramp_rate) : '00';
			my $data3 = ($link_parms{data3}) ? $link_parms{data3} : '00';
			$$self{_mem_activity} = 'add';
			$self->_write_link($address, $device_id, $group, $is_controller, $data1, $data2, $data3);
			# TO-DO: ensure that pop'd address is restored back to queue if the transaction fails
                }
                else
                {
			&::print_log("[Insteon::ALDB_i1] ERROR: adding link record failed because "
                        	. $$self{device}->get_object_name
				. " does not have a record of the first empty ALDB record."
                                . " Please rescan this device's link table")
                                if $main::Debug{insteon};

                         if ($$self{_success_callback})
                         {
				package main;
				eval ($$self{_success_callback});
				&::print_log("[Insteon::ALDB_i1] WARN1: Error encountered during ack callback: " . $@)
			 		if $@ and $main::Debug{insteon} >= 1;
			 	package Insteon::AllLinkDatabase;
                         }

                }
	}
}

sub update_link
{
	my ($self, %link_parms) = @_;
	my $insteon_object = $link_parms{object};
	my $group = $link_parms{group};
	my $is_controller = ($link_parms{is_controller}) ? 1 : 0;
	# strip optional % sign to append on_level
	my $on_level = $link_parms{on_level};
	$on_level =~ s/(\d+)%?/$1/;
	# strip optional s (seconds) to append ramp_rate
	my $ramp_rate = $link_parms{ramp_rate};
	$ramp_rate =~ s/(\d)s?/$1/;
	&::print_log("[Insteon::ALDB_i1] updating " . $$self{device}->get_object_name . " light level controlled by " . $insteon_object->get_object_name
		. " and group: $group with on level: $on_level and ramp rate: $ramp_rate") if $main::Debug{insteon};
	my $data1 = sprintf('%02X',$on_level * 2.55);
	$data1 = 'ff' if $on_level eq '100';
	$data1 = '00' if $on_level eq '0';
	my $data2 = ($$self{device}->isa('Insteon::DimmableLight')) ? &Insteon::DimmableLight::convert_ramp($ramp_rate) : '00';
	my $data3 = ($link_parms{data3}) ? $link_parms{data3} : '00';
	my $deviceid = $insteon_object->device_id;
	my $subaddress = $data3;
	# get the address via lookup into the hash
	my $key = lc $deviceid . $group . $is_controller;
	# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
	if (!($subaddress eq '00' or $subaddress eq '01'))
        {
		$key .= $subaddress;
	}
	my $address = $$self{aldb}{$key}{address};
	$$self{_mem_activity} = 'update';
	$$self{_success_callback} = ($link_parms{callback}) ? $link_parms{callback} : undef;
	$$self{_failure_callback} = ($link_parms{failure_callback}) ? $link_parms{failure_callback} : undef;
	$self->_write_link($address, $deviceid, $group, $is_controller, $data1, $data2, $data3);
}


sub log_alllink_table
{
	my ($self) = @_;
	my %aldb;

	&::print_log("[Insteon::ALDB_i1] Link table for "
        	. $$self{device}->get_object_name
                . " health: " . $self->health);

	# We want to log links sorted by ALDB address. Since the ALDB
	# addresses are scattered throughout the %{$$self{aldb}} hash,
	# and it is not easy to obtain them in a linear manner,
	# we build a new data structure that will allow us to easily
	# traverse the ALDB by address in a sorted manner. The new
	# data structure is a bidimensional hash (%aldb) where rows
	# are the ALDB addresses and the columns can be "empty"
	# (indicates that the ALDB at the corresponding address is
	# empty), "duplicate" (indicates that the ALDB at the
	# corresponding address is a duplicate), or a hash key (which
	# indicates that the ALDB at corresponding address contains
	# a link).
	foreach my $aldbkey (keys %{$$self{aldb}})
        {
	    if ($aldbkey eq "empty")
            {
		foreach my $address (@{$$self{aldb}{empty}})
                {
		    $aldb{$address}{empty} = undef; # Any value will do
		}
	    }
            elsif ($aldbkey eq "duplicates")
            {
		foreach my $address (@{$$self{aldb}{duplicates}})
                {
		    $aldb{$address}{duplicate} = undef; # Any value will do
		}
	    }
            else
            {
		$aldb{$$self{aldb}{$aldbkey}{address} }{$aldbkey} = $$self{aldb}{$aldbkey};
	    }
	}

	# Finally traverse the ALDB, but this time sorted by ALDB address
        if ($self->health eq 'good')
        {
		foreach my $address (sort keys %aldb)
           	{
			my $log_msg = "[Insteon::ALDB_i1] [0x$address] ";

			if (exists $aldb{$address}{empty})
                        {
		    		$log_msg .= "is empty";
			}
                        elsif (exists $aldb{$address}{duplicate})
                        {
		    		$log_msg .= "holds a duplicate entry";
			}
                        else
                        {
		   		my ($key) = keys %{$aldb{$address} }; # There's only 1 key
		    		my $aldb_entry = $aldb{$address}{$key};
		    		my $is_controller = $aldb_entry->{is_controller};
		    		my $device;

		    		if ($$self{device}->interface()->device_id()
					&& ($$self{device}->interface()->device_id()
                                        eq $aldb_entry->{deviceid}))
                                {
			    		$device = $$self{device}->interface;
		    		}
                                else
                                {
			    		$device = &Insteon::get_object($aldb_entry->{deviceid},'01');
		    		}
		    		my $object_name = ($device) ? $device->get_object_name : $aldb_entry->{deviceid};

		    		my $on_level = 'unknown';
		    		if (defined $aldb_entry->{data1})
                                {
			    		if ($aldb_entry->{data1})
                                        {
				    		$on_level = int((hex($aldb_entry->{data1})*100/255) + .5) . "%";
			    		}
                                        else
                                        {
				    		$on_level = '0%';
			    		}
		    		}

		    		my $rspndr_group = $aldb_entry->{data3};
		    		$rspndr_group = '01' if $rspndr_group eq '00';

		    		my $ramp_rate = 'unknown';
		    		if ($aldb_entry->{data2})
                                {
			    		if (!($$self{device}->isa('Insteon::DimmableLight'))
                                        	or (!$is_controller and ($rspndr_group != '01')))
                                        {
				    		$ramp_rate = 'none';
				    		$on_level = $on_level eq '0%' ? 'off' : 'on';
			    		}
                                        else
                                        {
				    		$ramp_rate = &Insteon::DimmableLight::get_ramp_from_code($aldb_entry->{data2}) . "s";
			    		}
		    		}

		    		$log_msg .= $is_controller ? "contlr($aldb_entry->{group}) "
				    . "record to $object_name ($rspndr_group), "
				    . "(d1:$aldb_entry->{data1}, "
				    . "d2:$aldb_entry->{data2}, "
				    . "d3:$aldb_entry->{data3})"
				: "rspndr($rspndr_group) record to $object_name "
				    . "($aldb_entry->{group}): onlevel=$on_level "
				    . "and ramp=$ramp_rate "
				    . "(d3:$aldb_entry->{data3})";
			}

			&::print_log($log_msg);
		}
        }
        else
        {
        }
}

sub update_local_properties
{
	my ($self) = @_;
		$$self{_mem_activity} = 'update_local';
		$self->_peek('0032'); # 0032 is the address for the onlevel
}

sub update_flags
{
	my ($self, $flags) = @_;
	return unless defined $flags;

	$$self{_mem_activity} = 'update_flags';
	$$self{_operating_flags} = $flags;
	$self->_peek('0023');
}

sub get_link_record
{
	my ($self,$link_key) = @_;
	my %link_record = ();
	%link_record = %{$$self{aldb}{$link_key}} if $$self{aldb}{$link_key};
	return %link_record;
}



sub has_link
{
	my ($self, $insteon_object, $group, $is_controller, $subaddress) = @_;
	my $key = "";
	if ($insteon_object->isa('Insteon::BaseObject') || $insteon_object->isa('Insteon::BaseInterface'))
        {
            $key = lc $insteon_object->device_id . $group . $is_controller;
	}
        elsif ($insteon_object->isa('Insteon::AllLinkDatabase'))
        {
            $key = lc $$insteon_object{device}->device_id . $group . $is_controller;
	}
	$subaddress = '00' unless $subaddress;
	# append the device "sub-address" (e.g., a non-root button on a keypadlinc) if it exists
	if (!($subaddress eq '00' or $subaddress eq '01'))
        {
		$key .= $subaddress;
	}
	return (defined $$self{aldb}{$key}) ? 1 : 0;
}

sub _write_link
{
	my ($self, $address, $deviceid, $group, $is_controller, $data1, $data2, $data3) = @_;
	if ($address)
        {
		&::print_log("[Insteon::ALDB_i1] " . $$self{device}->get_object_name . " address: $address found for device: $deviceid and group: $group");
		# change address for start of change to be address + offset
		if ($$self{_mem_activity} eq 'update')
                {
			$address = sprintf('%04X',hex($address) + 5);
		}
		$$self{pending_aldb}{address} = $address;
		$$self{pending_aldb}{deviceid} = lc $deviceid;
		$$self{pending_aldb}{group} = lc $group;
		$$self{pending_aldb}{is_controller} = $is_controller;
		$$self{pending_aldb}{data1} = (defined $data1) ? lc $data1 : '00';
		$$self{pending_aldb}{data2} = (defined $data2) ? lc $data2 : '00';
		# Note: if device is a KeypadLinc, then $data3 must be assigned the value of the applicable button (01)
		if (($$self{device}->isa('Insteon::KeyPadLincRelay') or $$self{device}->isa('Insteon::KeyPadLinc')) and ($data3 eq '00'))
                {
			&::print_log("[Insteon::ALDB_i1] setting data3 to " . $$self{device}->group . " for this keypadlinc")
				if $main::Debug{insteon};
			$data3 = $$self{device}->group;
		}
		$$self{pending_aldb}{data3} = (defined $data3) ? lc $data3 : '00';
		$self->_peek($address);
	}
        else
        {
		&::print_log("[Insteon::ALDB_i1] WARN: " . $$self{device}->get_object_name
			. " write_link failure: no address available for record to device: $deviceid and group: $group" .
				" and is_controller: $is_controller");;
                if ($$self{_success_callback})
                {
			package main;
			eval ($$self{_success_callback});
			&::print_log("[Insteon::ALDB_i1] WARN1: Error encountered during ack callback: " . $@)
		 		if $@ and $main::Debug{insteon} >= 1;
		 	package Insteon::AllLinkDatabase;
                }
	}
}

sub _peek
{
	my ($self, $address, $extended) = @_;
	my $msb = substr($address,0,2);
	my $lsb = substr($address,2,2);
	if ($extended)
        {
        	my $message = $self->device->derive_message('peek','insteon_ext_send',
			$lsb . "0000000000000000000000000000");
                $self->interface->queue_message($message);

	}
        else
        {
		$$self{_mem_lsb} = $lsb;
		$$self{_mem_msb} = $msb;
		$$self{_mem_action} = 'aldb_peek';
		&::print_log("[Insteon::ALDB_i1] " . $$self{device}->get_object_name . " accessing memory at location: 0x" . $address);
                my $message = new Insteon::InsteonMessage('insteon_send', $$self{device}, 'set_address_msb');
                $message->extra($msb);
                $message->failure_callback($$self{_failure_callback});
                $self->_send_cmd($message);
#		$self->_send_cmd('command' => 'set_address_msb', 'extra' => $msb, 'is_synchronous' => 1);
	}
}



package Insteon::ALDB_i2;

use strict;
use Insteon;
use Insteon::Lighting;

@Insteon::ALDB_i2::ISA = ('Insteon::AllLinkDatabase');

sub new
{
	my ($class,$device) = @_;

	my $self = new Insteon::AllLinkDatabase($device);
	bless $self,$class;
	return $self;
}





package Insteon::ALDB_PLM;

use strict;
use Insteon;
use Insteon::Lighting;

@Insteon::ALDB_PLM::ISA = ('Insteon::AllLinkDatabase');

sub new
{
	my ($class,$device) = @_;

	my $self = new Insteon::AllLinkDatabase($device);
	bless $self,$class;
	return $self;
}

sub restore_string
{
	my ($self) = @_;
        my $restore_string = '';
	if ($$self{aldb})
        {
		my $link = '';
		foreach my $link_key (keys %{$$self{aldb}})
                {
			$link .= '|' if $link; # separate sections
			my %link_record = %{$$self{aldb}{$link_key}};
			my $record = '';
			foreach my $record_key (keys %link_record)
                        {
				next unless $link_record{$record_key};
				$record .= ',' if $record;
				$record .= $record_key . '=' . $link_record{$record_key};
			}
			$link .= $record;
		}
		$restore_string .= $$self{device}->get_object_name . "->_aldb->restore_linktable(q~$link~) if " . $$self{device}->get_object_name . "->_aldb;\n";
	}
	if (defined $self->scandatetime)
        {
		$restore_string .= $$self{device}->get_object_name . "->_aldb->scandatetime(q~" . $self->scandatetime . "~) if "
                        	. $$self{device}->get_object_name . "->_aldb;\n";
        }
	$restore_string .= $$self{device}->get_object_name . "->_aldb->health(q~" . $self->health . "~) if "
                        	. $$self{device}->get_object_name . "->_aldb;\n";
	return $restore_string;
}

sub restore_linktable
{
	my ($self, $links) = @_;
	if ($links)
        {
		foreach my $link_section (split(/\|/,$links))
                {
			my %link_record = ();
			my $deviceid = '';
			my $groupid = '01';
			my $is_controller = 0;
			foreach my $link_record (split(/,/,$link_section))
                        {
				my ($key,$value) = split(/=/,$link_record);
				$deviceid = $value if ($key eq 'deviceid');
				$groupid = $value if ($key eq 'group');
				$is_controller = $value if ($key eq 'is_controller');
				$link_record{$key} = $value if $key and defined($value);
			}
			my $linkkey = $deviceid . $groupid . $is_controller;
			%{$$self{aldb}{lc $linkkey}} = %link_record;
		}
#		$self->log_alllink_table();
	}
}

sub log_alllink_table
{
	my ($self) = @_;
        &::print_log("[Insteon::ALDB_PLM] Link table health: " . $self->health);
	foreach my $linkkey (sort(keys(%{$$self{aldb}}))) {
		my $data3 = $$self{aldb}{$linkkey}{data3};
		my $is_controller = $$self{aldb}{$linkkey}{is_controller};
		my $group = ($is_controller) ? $data3 : $$self{aldb}{$linkkey}{group};
		$group = '01' if $group eq '00';
                my $deviceid = $$self{aldb}{$linkkey}{deviceid};
		my $device = &Insteon::get_object($deviceid,$group);
		my $object_name = '';
                if ($device)
                {
                	$object_name = $device->get_object_name;
                }
                else
                {
                        $object_name = uc substr($deviceid,0,2) . '.' .
                        	       uc substr($deviceid,2,2) . '.' .
                                       uc substr($deviceid,4,2);
                }
		&::print_log("[Insteon::ALDB_PLM] " .
			(($is_controller) ? "cntlr($$self{aldb}{$linkkey}{group}) record to "
			. $object_name
			: "responder record to " . $object_name . "($$self{aldb}{$linkkey}{group})")
			. " (d1=$$self{aldb}{$linkkey}{data1}, d2=$$self{aldb}{$linkkey}{data2}, "
			. "d3=$data3)");
	}
}

sub parse_alllink
{
	my ($self, $data) = @_;
	if (substr($data,0,6))
        {
		my %link = ();
		my $flag = substr($data,0,1);
		$link{is_controller} = (hex($flag) & 0x04) ? 1 : 0;
		$link{flags} = substr($data,0,2);
		$link{group} = lc substr($data,2,2);
		$link{deviceid} = lc substr($data,4,6);
		$link{data1} = substr($data,10,2);
		$link{data2} = substr($data,12,2);
		$link{data3} = substr($data,14,2);
		my $key = $link{deviceid} . $link{group} . $link{is_controller};
		%{$$self{aldb}{lc $key}} = %link;
	}
}

sub get_first_alllink
{
	my ($self) = @_;
        $self->scandatetime(&main::get_tickcount);
        $self->health('corrupt'); # set as corrupt and allow acknowledge to set otherwise
	$$self{device}->queue_message(new Insteon::InsteonMessage('all_link_first_rec', $$self{device}));
}

sub get_next_alllink
{
	my ($self) = @_;
	$$self{device}->queue_message(new Insteon::InsteonMessage('all_link_next_rec', $$self{device}));
}

sub delete_orphan_links
{
	my ($self, $audit_mode) = @_;

        &::print_log("[Insteon::ALDB_PLM] #### NOW BEGINNING DELETE ORPHAN LINKS ####");

	@{$$self{delete_queue}} = (); # reset the work queue
	my $selfname = $$self{device}->get_object_name;
	my $num_deleted = 0;
	foreach my $linkkey (keys %{$$self{aldb}})
        {
		my $deviceid = lc $$self{aldb}{$linkkey}{deviceid};
		my $group = $$self{aldb}{$linkkey}{group};
		my $is_controller = $$self{aldb}{$linkkey}{is_controller};
		my $data3 = $$self{aldb}{$linkkey}{data3};
		my $device = &Insteon::get_object($deviceid,'01');
		# if a PLM link (regardless of responder or controller) exists to a device that is not known, then delete
		if (!($device))
                {
                	if ($audit_mode)
                        {
                        &::print_log("[Insteon::ALDB_PLM] (AUDIT) Delete Orphan Link to non-existant deviceid: " .
                                $deviceid . "; group:$group; "
                                . (($is_controller) ? "controller; data:$data3" : "responder"))
                                if $main::Debug{insteon};
                        }
                        else
                        {
				my %delete_req = (deviceid => $deviceid, group => $group, is_controller => $is_controller,
					callback => "$selfname->_aldb->_process_delete_queue(1)",
					linkdevice => $self, data3 => $data3);
				push @{$$self{delete_queue}}, \%delete_req;
                        }
		}
                else
                {
			my $is_invalid = 1;
			my $link = undef;
			if ($is_controller)
                        {
				# then, this is a PLM defined link; and, we won't care about responder links as we assume
				# they're ok given that they reference known devices
				$link = &Insteon::get_object('000000',$group);
				if (!($link))
                                {
					# a reference in the PLM's linktable does not match a scene member target
                                	if ($audit_mode)
                                        {
	                                        &::print_log("[Insteon::ALDB_PLM] (AUDIT) Delete Orphan PLM controller link ($group) to: "
                                                        . $device->get_object_name() . "($data3)")
                                                        if $main::Debug{insteon};
                                        }
                                        else
                                        {
				       		my %delete_req = (object => $device, group => $group, is_controller => 1,
								callback => "$selfname->_aldb->_process_delete_queue(1)",
								linkdevice => $self, data3 => $data3);
						push @{$$self{delete_queue}}, \%delete_req;
					}
				}
                                else
                                {
					# iterate over all of the members of the Insteon_Link item
					foreach my $member_ref (keys %{$$link{members}})
                                        {
						my $member = $$link{members}{$member_ref}{object};
						# member will correspond to a scene member item
						# and, if it is a light item, then get the real device
						if ($member->isa('Light_Item'))
                                                {
							my @lights = $member->find_members('Insteon::BaseLight');
							if (@lights)
                                                        {
								$member = @lights[0]; # pick the first
							}
						}
						if ($member->isa('Insteon::BaseDevice'))
                                                {
                                                	if ($member->isa('Insteon::RemoteLinc') or $member->isa('Insteon::MotionSensor'))
                                                        {
                                                               &::print_log("[Insteon::ALDB_PLM] ignoring link from PLM to " .
                                                               		$member->get_object_name);
                                                               $is_invalid = 0;
                                                        }
                                                        else
                                                        {
						       		my $linkmember = $member;
								# make sure that this is a root device
								if (!($member->is_root))
                                                        	{
									$member = $member->get_root;
								}
								if (lc $member->device_id eq $$self{aldb}{$linkkey}{deviceid})
                                                        	{
									# at this point, the forward link is ok; but, only if the reverse
									# link also exists.  So, check:
									if ($member->has_link($self, $group, 0, $data3))
                                                                	{
										$is_invalid = 0;
									}
							       		last;
								}
                                                        }
						}
                                                else
                                                {
							$is_invalid = 0;
						}
					} # foreach $$link{members}
					if ($is_invalid)
                                        {
						# then, there is a good chance that a reciprocal link exists; if so, delet it too
						if ($device->has_link($self,$group,0, $data3))
                                                {
                                                	if ($audit_mode)
                                                        {
                                                                &::print_log("[Insteon::ALDB_PLM] (AUDIT) Delete orphan controller link from PLM to "
                                                                	. $device->get_object_name()
                                                			. " because no SCENE_MEMBER entry could be found "
                                                                        . "in items.mht for INSTEON_ICONTROLLER: "
                                                                        . $link->get_object_name());

                                                        }
                                                        else
                                                        {
						       		my %delete_req = (object => $device, group => $group, is_controller => 1,
							       		callback => "$selfname->_aldb->_process_delete_queue(1)",
									linkdevice => $self, data3 => $data3);
								push @{$$self{delete_queue}}, \%delete_req;
                                                        }
						}
					}  # if $is_invalid
				} # else
			}
		}
	}

	$$self{delete_queue_processed} = 0; # reset the counter

	# iterate over all registered objects and compare whether the link tables match defined scene linkages in known Insteon_Links
	for my $obj (&Insteon::find_members('Insteon::BaseDevice'))
	{
		#Match on real objects only
		if (($obj->is_root))
		{
			my %delete_req = ('root_object' => $obj, 'audit_mode' => $audit_mode);
			push @{$$self{delete_queue}}, \%delete_req;
		}
	}

	$self->_process_delete_queue();
}

sub _process_delete_queue {
	my ($self, $p_num_deleted) = @_;
	$$self{delete_queue_processed} += $p_num_deleted if $p_num_deleted;
	my $num_in_queue = @{$$self{delete_queue}};
	if ($num_in_queue)
        {
		my $delete_req_ptr = shift(@{$$self{delete_queue}});
		my %delete_req = %$delete_req_ptr;
		# distinguish between deleting PLM links and processing delete orphans for a root item
		if ($delete_req{'root_object'})
                {
			$delete_req{'root_object'}->delete_orphan_links($delete_req{'audit_mode'});
		}
                else
                {
			if ($delete_req{linkdevice} eq $self)
                        {
				&::print_log("[Insteon::ALDB_PLM] now deleting orphaned link w/ details: "
					. (($delete_req{is_controller}) ? "controller" : "responder")
					. ", " . (($delete_req{object}) ? "object=" . $delete_req{object}->get_object_name
					: "deviceid=$delete_req{deviceid}") . ", group=$delete_req{group}")
					if $main::Debug{insteon};
				$self->delete_link(%delete_req);
			}
                        elsif ($delete_req{linkdevice})
                        {
				$delete_req{linkdevice}->delete_link(%delete_req);
			}
		}
	}
        else
        {
		&::print_log("[Insteon::ALDB_PLM] A total of $$self{delete_queue_processed} orphaned link records were deleted.");
        	&::print_log("[Insteon::ALDB_PLM] #### END DELETE ORPHAN LINKS ####");
	}

}

sub delete_link
{
	# linkkey is concat of: deviceid, group, is_controller
	my ($self, $parms_text) = @_;
	my %link_parms;
	if (@_ > 2)
        {
		shift @_;
		%link_parms = @_;
	}
        else
        {
		%link_parms = &main::parse_func_parms($parms_text);
	}
	my $num_deleted = 0;
	my $insteon_object = $link_parms{object};
	my $deviceid = ($insteon_object) ? $insteon_object->device_id : $link_parms{deviceid};
	my $group = $link_parms{group};
	my $is_controller = ($link_parms{is_controller}) ? 1 : 0;
	my $linkkey = lc $deviceid . $group . (($is_controller) ? '1' : '0');
	if (defined $$self{aldb}{$linkkey})
        {
		my $cmd = '80'
			. $$self{aldb}{$linkkey}{flags}
			. $$self{aldb}{$linkkey}{group}
			. $$self{aldb}{$linkkey}{deviceid}
			. $$self{aldb}{$linkkey}{data1}
			. $$self{aldb}{$linkkey}{data2}
			. $$self{aldb}{$linkkey}{data3};
		delete $$self{aldb}{$linkkey};
		$num_deleted = 1;
                my $message = new Insteon::InsteonMessage('all_link_manage_rec', $$self{device});
                if ($link_parms{callback})
                {
			$$self{_success_callback} = $link_parms{callback};
                }
                $message->interface_data($cmd);
		$$self{device}->queue_message($message);
	}
        else
        {
		&::print_log("[Insteon::ALDB_PLM] no entry in linktable could be found for linkkey: $linkkey");
		if ($link_parms{callback})
                {
			package main;
			eval ($link_parms{callback});
			&::print_log("[Insteon_PLM] error in add link callback: " . $@)
				if $@ and $main::Debug{insteon};
			package Insteon_PLM;
		}
	}
	return $num_deleted;
}

sub add_link
{
	my ($self, $parms_text) = @_;
	my %link_parms;
	if (@_ > 2)
        {
		shift @_;
		%link_parms = @_;
	}
        else
        {
		%link_parms = &main::parse_func_parms($parms_text);
	}
	my $device_id;
	my $group =  ($link_parms{group}) ? $link_parms{group} : '01';
	my $insteon_object = $link_parms{object};
	if (!(defined($insteon_object)))
        {
		$device_id = lc $link_parms{deviceid};
		$insteon_object = &Insteon::get_object($device_id, $group);
	}
        else
        {
		$device_id = lc $insteon_object->device_id;
	}
	my $is_controller = ($link_parms{is_controller}) ? 1 : 0;
	# first, confirm that the link does not already exist
	my $linkkey = lc $device_id . $group . $is_controller;
	if (defined $$self{aldb}{$linkkey})
        {
		&::print_log("[Insteon::ALDB_PLM] WARN: attempt to add link to PLM that already exists! "
			. "deviceid=" . $device_id . ", group=$group, is_controller=$is_controller");
		if ($link_parms{callback})
                {
			package main;
			eval ($link_parms{callback});
			&::print_log("[Insteon::ALDB_PLM] error in add link callback: " . $@)
				if $@ and $main::Debug{insteon};
			package Insteon_PLM;
		}
	}
        else
        {
		my $control_code = ($is_controller) ? '40' : '41';
		# flags should be 'a2' for responder and 'e2' for controller
		my $flags = ($is_controller) ? 'E2' : 'A2';
		my $data1 = (defined $link_parms{data1}) ? $link_parms{data1} : (($is_controller) ? '01' : '00');
		my $data2 = (defined $link_parms{data2}) ? $link_parms{data2} : '00';
		my $data3 = (defined $link_parms{data3}) ? $link_parms{data3} : '00';
		# from looking at manually linked records, data1 and data2 are both 00 for responder records
		# and, data1 is 01 and usually data2 is 00 for controller records

		my $cmd = $control_code
			. $flags
			. $group
			. $device_id
			. $data1
			. $data2
			. $data3;
		$$self{aldb}{$linkkey}{flags} = lc $flags;
		$$self{aldb}{$linkkey}{group} = lc $group;
		$$self{aldb}{$linkkey}{is_controller} = $is_controller;
		$$self{aldb}{$linkkey}{deviceid} = lc $device_id;
		$$self{aldb}{$linkkey}{data1} = lc $data1;
		$$self{aldb}{$linkkey}{data2} = lc $data2;
		$$self{aldb}{$linkkey}{data3} = lc $data3;
		$$self{aldb}{$linkkey}{inuse} = 1;
		$self->health('good') if($self->health() eq 'empty');
                my $message =  new Insteon::InsteonMessage('all_link_manage_rec', $$self{device});
                $message->interface_data($cmd);
                if ($link_parms{callback})
                {
			$$self{_success_callback} = $link_parms{callback};
                }
                $message->interface_data($cmd);
		$$self{device}->queue_message($message);
	}
}

sub has_link
{
	my ($self, $insteon_object, $group, $is_controller, $subaddress) = @_;
        # note, subaddress is IGNORED!!
	my $key = lc $insteon_object->device_id . $group . $is_controller;
	return (defined $$self{aldb}{$key}) ? 1 : 0;
}




1;
