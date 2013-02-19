
package Insteon::BaseMessage;

use strict;
use Insteon;

sub new
{
	my ($class) = @_;
	my $self={};
	bless $self,$class;

        $$self{queue_time} = &main::get_tickcount;
        $$self{send_attempts} = 0;

        return $self;
}

sub interface_data
{
	my ($self, $interface_data) = @_;
        if ($interface_data)
        {
        	$$self{interface_data} = $interface_data;
        }
        return $$self{interface_data};
}

sub queue_time
{
	my ($self, $queue_time) = @_;
        if ($queue_time)
        {
        	$$self{queue_time} = $queue_time;
        }
        return $$self{queue_time};
}

sub callback
{
	my ($self, $callback) = @_;
        if ($callback)
        {
        	$$self{callback} = $callback;
        }
        return $$self{callback};
}

sub failure_callback
{
	my ($self, $callback) = @_;
        if ($callback)
        {
        	$$self{failure_callback} = $callback;
        }
        return $$self{failure_callback};
}

sub send_attempts
{
	my ($self, $send_attempts) = @_;
        if ($send_attempts)
        {
        	$$self{send_attempts} = $send_attempts;
        }
        return $$self{send_attempts};
}

sub setby
{
	my ($self, $setby) = @_;
        if ($setby)
        {
        	$$self{setby} = $setby;
        }
        return $$self{setby};
}

sub respond
{
	my ($self, $respond) = @_;
        if ($respond)
        {
        	$$self{respond} = $respond;
        }
        return $$self{respond};
}

sub send
{
        my ($self, $interface) = @_;
        if ($self->send_attempts < ($::config_parms{'Insteon_retry_count'} || 5))
        {

        	if ($self->send_attempts > 0)
                {
                	&::print_log("[Insteon::BaseMessage] WARN: now resending "
                        	. $self->to_string() . " after " . $self->send_attempts
                        	. " attempts.") if $main::Debug{insteon};
                        # revise default hop count to reflect retries
                        if (ref $self->setby && $self->setby->isa('Insteon::BaseObject'))
                        {
                        	if ($self->setby->default_hop_count < 3)
                                {
                                	$self->setby->default_hop_count($self->setby->default_hop_count + 1);
					&main::print_log("[Insteon::Message] Now adding hop count of "
                                                . $self->setby->default_hop_count . " to hop history of "
						. $self->setby->get_object_name);
                                }
                        }
                }

                # need to set timeout as a function of retries; also need to alter hop count
                $self->send_attempts($self->send_attempts + 1);
		$interface->_send_cmd($self, $self->send_timeout);
		if ($self->callback)
                {
			package main;
			eval $self->callback;
			&::print_log("[Insteon::BaseMessage] problem w/ retry callback: $@") if $@;
			package Insteon::Message;
		}
                return 1;
        }
        else
        {
                return 0;
        }

}

sub seconds_delayed
{
	my ($self) = @_;
	my $current_tickcount = &main::get_tickcount;
        my $delay_time = $current_tickcount - $self->queue_time;
       	if ($self->queue_time > $current_tickcount)
       	{
        	return 'unknown';
       	}

        $delay_time = $delay_time / 1000;
        return $delay_time;
}

sub send_timeout
{
	my ($self, $timeout) = @_;
        $$self{send_timeout} = $timeout if defined $timeout;
        return $$self{send_timeout};
}

sub to_string
{
	my ($self) = @_;
        return $self->interface_data;
}

package Insteon::InsteonMessage;
use strict;
use Insteon;

@Insteon::InsteonMessage::ISA = ('Insteon::BaseMessage');

sub new
{
	my ($class, $command_type, $setby, $command, $extra) = @_;
	my $self= new Insteon::BaseMessage();
	bless $self,$class;

        $self->command_type($command_type);
        $self->setby($setby);
        $self->command($command);
        $self->extra($extra);
        $self->send_timeout(2000);

        return $self;
}

sub command_to_hash
{
	my ($p_state) = @_;
	my %msg = ();
	my $hopflag = hex(uc substr($p_state,13,1));
	$msg{maxhops} = $hopflag&0b0011;
	$msg{hopsleft} = $hopflag >> 2;
	my $msgflag = hex(uc substr($p_state,12,1));
	$msg{is_extended} = (0x01 & $msgflag) ? 1 : 0;
	if ($msg{is_extended})
        {
		$msg{source} = substr($p_state,0,6);
		$msg{destination} = substr($p_state,6,6);
		$msg{extra} = substr($p_state,16,16);
	}
        else
        {
		$msg{source} = substr($p_state,0,6);
		$msgflag = $msgflag >> 1;
		if ($msgflag == 4)
                {
			$msg{type} = 'broadcast';
			$msg{devcat} = substr($p_state,6,4);
			$msg{firmware} = substr($p_state,10,2);
			$msg{is_master} = substr($p_state,16,2);
			$msg{dev_attribs} = substr($p_state,18,2);
		}
                elsif ($msgflag ==6)
                {
			$msg{type} = 'alllink';
			$msg{group} = substr($p_state,10,2);
		}
                else
                {
			$msg{destination} = substr($p_state,6,6);
			if ($msgflag == 2)
                        {
				$msg{type} = 'cleanup';
				$msg{group} = substr($p_state,16,2);
			}
                        elsif ($msgflag == 3)
                        {
				$msg{type} = 'cleanup';
				$msg{is_ack} = 1;
                                # the "extra" value will contain the controller's group ID
				$msg{extra} = substr($p_state,16,2);
			}
                        elsif ($msgflag == 7)
                        {
				$msg{type} = 'cleanup';
				$msg{is_nack} = 1;
				$msg{extra} = substr($p_state,16,2);
			}
                        elsif ($msgflag == 0)
                        {
				$msg{type} = 'direct';
				$msg{extra} = substr($p_state,16,2);
			}
                        elsif ($msgflag == 1)
                        {
				$msg{type} = 'direct';
				$msg{is_ack} = 1;
				$msg{extra} = substr($p_state,16,2);
			}
                        elsif ($msgflag == 5)
                        {
				$msg{type} = 'direct';
				$msg{is_nack} = 1;
				$msg{extra} = substr($p_state,16,2);
			}
		}
	}
	$msg{cmd_code} = substr($p_state,14,2);

	return %msg;
}


sub command
{
      my ($self, $command) = @_;
      $$self{command} = $command if $command;
      return $$self{command};
}

sub command_type
{
      my ($self, $command_type) = @_;
      $$self{command_type} = $command_type if $command_type;
      return $$self{command_type};
}

sub extra
{
      my ($self, $extra) = @_;
      $$self{extra} = $extra if $extra;
      return $$self{extra};
}

sub send_timeout
{
# hop timing in seconds; this method returns timeout in millisconds
# hops    standard   extended
# ----    --------   --------
#  0       1.40       2.22
#  1       1.70       2.69
#  2       1.90       3.01
#  3       2.00       3.17

	my ($self, $ignore) = @_;
        my $hop_count = (ref $self->setby and $self->setby->isa('Insteon::BaseObject')) ?
        			$self->setby->default_hop_count : $self->send_attempts;
	if($self->command eq 'peek' || $self->command eq 'set_address_msb')
	{
		return 4000;
	}
        if ($self->command_type eq 'all_link_send')
        {
        	# note, the following was set to 2000 and that was insufficient
        	return 3000;
        }
        elsif ($self->command_type eq 'insteon_ext_send')
        {
        	if ($hop_count == 0)
                {
                	return   2220;
                }
                elsif ($hop_count == 1)
                {
                	return   2690;
                }
                elsif ($hop_count == 2)
                {
                	return   3000;
                }
                elsif ($hop_count >= 3)
                {
                	return   3170;
                }
        }
        else
        {
        	if ($hop_count == 0)
                {
                	return   1400;
                }
                elsif ($hop_count == 1)
                {
                	return   1700;
                }
                elsif ($hop_count == 2)
                {
                	return   1900;
                }
                elsif ($hop_count >= 3)
                {
                	return   2000;
                }
        }
}

sub to_string
{
	my ($self) = @_;
        my $result = '';
        if ($self->setby)
        {
        	$result .= 'obj=' . $self->setby->get_object_name;
        }
        if ($result)
        {
        	$result .= '; ';
        }
        if ($self->command)
        {
        	$result .= 'command=' . $self->command;
        }
        else
        {
        	$result .= 'interface_data=' . $self->interface_data;
        }
        if ($self->extra)
        {
        	$result .= '; extra=' . $self->extra;
        }

        return $result;
}

sub interface_data
{
	my ($self, $interface_data) = @_;
        my $result = $self->SUPER::interface_data($interface_data);
        if (!($result) &&
        	(($self->command_type eq 'insteon_send')
                or ($self->command_type eq 'insteon_ext_send')
                or ($self->command_type eq 'all_link_send')
                or ($self->command_type eq 'all_link_direct_cleanup')))
        {
        	return $self->_derive_interface_data();
        }
        else
        {
        	return $result;
        }
}

sub _derive_interface_data
{

	my ($self) = @_;
	my $cmd = '';
	my $level;
        if ($self->command_type =~ /all_link_send/i)
        {
		$cmd.=$self->setby->group;
	}
        else
        {
       		my $hop_count = $self->send_attempts + $self->setby->default_hop_count - 1;
		$cmd.=$self->setby->device_id();
		if ($self->command_type =~ /insteon_ext_send/i)
                {
                        if ($hop_count == 0)
			{
				$cmd.='10';
			}
			elsif ($hop_count == 1)
                        {
				$cmd.='15';
                        }
                        elsif ($hop_count == 2)
                        {
				$cmd.='1A';
                        }
                        elsif ($hop_count >= 3)
                        {
				$cmd.='1F';
                        }
		} elsif ($self->command_type =~ /all_link_direct_cleanup/i){
			if ($hop_count == 0)
			{
				$cmd.='40';
			}
			elsif ($hop_count == 1)
                        {
				$cmd.='45';
                        }
                        elsif ($hop_count == 2)
                        {
				$cmd.='4A';
                        }
                        elsif ($hop_count >= 3)
                        {
				$cmd.='4F';
                        }
		}
                else
                {
                        if ($hop_count == 0)
			{
				$cmd.='00';
			}
			elsif ($hop_count == 1)
                        {
				$cmd.='05';
                        }
                        elsif ($hop_count == 2)
                        {
				$cmd.='0A';
                        }
                        elsif ($hop_count >= 3)
                        {
				$cmd.='0F';
                        }
		}
	}
	$cmd.= unpack("H*",pack("C",$self->setby->message_type_code($self->command)));
	if ($self->extra)
	{
		$cmd.= $self->extra;
	}
        elsif ($self->command_type eq 'insteon_send')
        { # auto append '00' if no extra defined for a standard insteon send
        	$cmd .= '00';
        }

	return $cmd;

}

package Insteon::X10Message;
use strict;
use Insteon;

@Insteon::X10Message::ISA = ('Insteon::BaseMessage');

my %x10_house_codes = (
						a => 0x6,
						b => 0xE,
						c => 0x2,
						d => 0xA,
						e => 0x1,
						f => 0x9,
						g => 0x5,
						h => 0xD,
						i => 0x7,
						j => 0xF,
						k => 0x3,
						l => 0xB,
						m => 0x0,
						n => 0x8,
						o => 0x4,
						p => 0xC
);

my %mh_house_codes = (
						'6' => 'a',
						'e' => 'b',
						'2' => 'c',
						'a' => 'd',
						'1' => 'e',
						'9' => 'f',
						'5' => 'g',
						'd' => 'h',
						'7' => 'i',
						'f' => 'j',
						'3' => 'k',
						'b' => 'l',
						'0' => 'm',
						'8' => 'n',
						'4' => 'o',
						'c' => 'p'
);

my %x10_unit_codes = (
						1 => 0x6,
						2 => 0xE,
						3 => 0x2,
						4 => 0xA,
						5 => 0x1,
						6 => 0x9,
						7 => 0x5,
						8 => 0xD,
						9 => 0x7,
						10 => 0xF,
						a => 0xF,
						11 => 0x3,
						b => 0x3,
						12 => 0xB,
						c => 0xB,
						13 => 0x0,
						d => 0x0,
						14 => 0x8,
						e => 0x8,
						15 => 0x4,
						f => 0x4,
						16 => 0xC,
						g => 0xC

);

my %mh_unit_codes = (
						'6' => '1',
						'e' => '2',
						'2' => '3',
						'a' => '4',
						'1' => '5',
						'9' => '6',
						'5' => '7',
						'd' => '8',
						'7' => '9',
						'f' => 'a',
						'3' => 'b',
						'b' => 'c',
						'0' => 'd',
						'8' => 'e',
						'4' => 'f',
						'c' => 'g'
);

my %x10_commands = (
						on => 0x2,
						j => 0x2,
						off => 0x3,
						k => 0x3,
						bright => 0x5,
						l => 0x5,
						dim => 0x4,
						m => 0x4,
						preset_dim1 => 0xA,
						preset_dim2 => 0xB,
						all_off => 0x0,
                                                p => 0x0,
						all_lights_on => 0x1,
                                                o => 0x1,
						all_lights_off => 0x6,
						status => 0xF,
						status_on => 0xD,
						status_off => 0xE,
						hail_ack => 0x9,
						ext_code => 0x7,
						ext_data => 0xC,
						hail_request => 0x8
);

my %mh_commands = (
						'2' => 'J',
						'3' => 'K',
						'5' => 'L',
						'4' => 'M',
						'a' => 'preset_dim1',
						'b' => 'preset_dim2',
#						'0' => 'all_off',
                                                '0' => 'P',
#						'1' => 'all_lights_on',
                                                '1' => 'O',
						'6' => 'all_lights_off',
						'f' => 'status',
						'd' => 'status_on',
						'e' => 'status_off',
						'9' => 'hail_ack',
						'7' => 'ext_code',
						'c' => 'ext_data',
						'8' => 'hail_request'
);

sub new
{
	my ($class, $interface_data) = @_;
	my $self= new Insteon::BaseMessage();
	bless $self,$class;

        $self->interface_data($interface_data);
        $self->send_timeout(2000);

        return $self;
}

sub get_formatted_data
{
	my ($self) = @_;

        my $data = $self->interface_data;

	my $msg=undef;
	if (uc(substr($data,length($data)-2,2)) eq '00')
	{
		$msg = "X";
		$msg.= uc($mh_house_codes{substr($data,4,1)});
		$msg.= uc($mh_unit_codes{substr($data,5,1)});
		for (my $index =6; $index<length($data)-2; $index+=2)
		{
   	        $msg.= uc($mh_house_codes{substr($data,$index,1)});
		    $msg.= uc($mh_commands{substr($data,$index+1,1)});
		}
	} elsif (uc(substr($data,length($data)-2,2)) eq '80')
	{
		$msg = "X";
		$msg.= uc($mh_house_codes{substr($data,4,1)});
		$msg.= uc($mh_commands{substr($data,5,1)});
		for (my $index =6; $index<length($data)-2; $index+=2)
		{
   	        $msg.= uc($mh_house_codes{substr($data,$index,1)});
		    $msg.= uc($mh_commands{substr($data,$index+1,1)});
		}
	}

	return $msg;
}

sub generate_commands
{
	my ($p_state, $p_setby) = @_;

        my @data = ();

        my $cmd=$p_state;
        $cmd=~ s/\:.*$//;
        $cmd=lc($cmd);
        my $msg;

	my $id=lc($p_setby->{id_by_state}{$cmd});

	my $hc = lc(substr($p_setby->{x10_id},1,1));
	my $uc = lc(substr($p_setby->{x10_id},2,1));

	if ($hc eq undef) {
	    &main::print_log("[Insteon::Message] Object:$p_setby Doesnt have an x10 id (yet)");
		return undef;
	}

	if ($uc eq undef) {
	    &main::print_log("[Insteon::Message] Message is for entire HC") if $main::Debug{insteon};
	}
	else {

	    #Every X10 message starts with the House and unit code
	    $msg = substr(unpack("H*",pack("C",$x10_house_codes{substr($id,1,1)})),1,1);
	    $msg.= substr(unpack("H*",pack("C",$x10_unit_codes{substr($id,2,1)})),1,1);
	    $msg.= "00";
	    &main::print_log("[Insteon_PLM] x10 sending code: " . uc($hc . $uc) . " as insteon msg: "
			     . $msg) if $main::Debug{insteon};

            push @data, $msg;
	}

	my $ecmd;
	#Iterate through the rest of the pairs of nibbles
	my $spos = 3;
	if ($uc eq undef) {$spos=1;}
#	&::print_log("PLM:PAIR:$id:$spos:$ecmd:");
	for (my $pos = $spos; $pos<length($id); $pos++) {
	    $msg = substr(unpack("H*",pack("C",$x10_house_codes{substr($id,$pos,1)})),1,1);
	    $pos++;

	    #look for an explicit command
	    $ecmd = substr($id,$pos,length($id)-$pos);
	    my $x10_arg = $ecmd;
	    if (defined $x10_commands{$ecmd} )
	    {
		$msg.= substr(unpack("H*",pack("C",$x10_commands{$ecmd})),1,1);
		$pos+=length($id)-$pos-1;
	    } else {
		$x10_arg = $x10_commands{substr($id,$pos,1)};
		$msg.= substr(unpack("H*",pack("C",$x10_commands{substr($id,$pos,1)})),1,1);
	    }
	    $msg.= "80";

     	    &main::print_log("[Insteon_PLM] x10 sending code: " . uc($hc . $x10_arg) . " as insteon msg: "
			     . $msg) if $main::Debug{insteon};

            push @data, $msg;

	}

        return @data;
}

1;
