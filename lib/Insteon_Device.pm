=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Insteon_Device.pm

Description:
	Generic class implementation of an Insteon Device.

Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	$ip_patio_light = new Insteon_Device($myPLM,"33.44.55");

	$ip_patio_light->set("ON");

Special Thanks to:
	Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Insteon_Device;

@Insteon_Device::ISA = ('Generic_Item');

my %message_types = (
						assign_to_group => 0x01,
						delete_from_group => 0x02,
						ping => 0x10,
						on => 0x11,
						off => 0x13,
						bright => 0x15,
						dim => 0x16,
						start_manual_change => 0x17,
						stop_manual_change => 0x18,
						status_request => 0x19,
						do_read_ee => 0x24,
						set_address_msb => 0x28,
						poke => 0x29,
						poke_extended => 0x2a,
						peek => 0x2b,
						peek_internal => 0x2c,
						poke_internal => 0x2d
);

sub new
{
	my ($class,$p_interface,$p_deviceid) = @_;
	my $self={};
	bless $self,$class;

	$self->interface($p_interface) if defined $p_interface;
	$self->device_id($p_deviceid) if defined $p_deviceid;
	$self->initialize();
	$self->rate(undef);
	$$self{flag} = "0F";
	$$self{ackMode} = "1";
	$$self{interface}->add($self);
	return $self;
}

sub initialize
{
	my ($self) = @_;
}

sub interface
{
	my ($self,$p_interface) = @_;
	$$self{interface} = $p_interface if defined $p_interface;
	return $$self{interface};
}

sub device_id
{
	my ($self,$p_device_id) = @_;

	if (defined $p_device_id)
	{
		$p_device_id =~ /(\w\w)\W?(\w\w)\W?(\w\w)/;
		$$self{device_id}=$1 . $2 . $3;
	}
	return $$self{device_id};
}

sub rate
{
	my ($self,$p_rate) = @_;
	$$self{rate} = $p_rate if defined $p_rate;
	return $$self{rate};
}

sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;

    # prevent reciprocal sets that can occur because of this method's state
    # propogation
    return if (ref $p_setby and $p_setby->can('get_set_by') and
        $p_setby->{set_by} eq $self);

   &::print_log($self->get_object_name() . "::set($p_state, $p_setby)");

	if ($p_setby eq $self->interface())
	{
   		my $source=substr($p_state,0,6);
   		my $destination=substr($p_state,6,6);
		my $l_state = $p_state;
		$p_state = undef;
		if ( $source eq $self->device_id() or $destination eq 'FFFFFF' )
		{
			$p_state = $self->_xlate_insteon_mh($l_state);
		    &::print_log($self->get_object_name() . "::set($p_state, $p_setby)");
		}
	} else {
		$$self{interface}->set($self->_xlate_mh_insteon($p_state),$self);
	    &::print_log($self->get_object_name() . "::set($p_state, $p_setby)");
	}
	$self->SUPER::set($p_state,$p_setby,$p_response) if defined $p_state;
}

sub _xlate_insteon_mh
{
	my ($self,$p_state) = @_;

   	my $destination = substr($p_state,0,6);
   	my $source = substr($p_state,6,6);
	my $flags = substr($p_state,12,2);
	my $cmd1 = substr($p_state,14,2);
	my $cmd2 = substr($p_state,16,2);
	my $state=undef;

	&::print_log("XLATE:$cmd1:");
	for my $key (keys %message_types){
		if (pack("C",$message_types{$key}) eq pack("H*",$cmd1))
		{
			&::print_log("FOUND: $key");
			$state=$key;
			last;
		}
	}

	return $state;
}

sub _xlate_mh_insteon
{
	my ($self,$p_state) = @_;
	my $cmd;
	my @args;
	my $msg;
	my $level;

	#msg id
	$msg=$p_state;
	$msg=~ s/\:.*$//;
	$msg=lc($msg);
#	&::print_log("XLATE:$msg:$p_state:");


	if ($msg eq 'on')
	{
		$level=255;
	} elsif ($msg eq 'off')
	{
		$level = 0;
	} elsif ($msg=~/^([1]?[0-9]?[0-9])/)
	{
		$level = $1 * 2.5;
		$msg='on';
	}

=begin
	#Fuzzy logic find message
	for my $key (keys %message_types)
	{
		if ($key=~/$msg/i)
		{
			$msg = $message_types{$key};
			last;
		}
	}
=cut

#####lets not be device specific
#	$cmd="0262";

	$cmd='';
	$cmd.=$self->device_id();
	$cmd.=$$self{flag};
	$cmd.= unpack("H*",pack("C",$message_types{$msg}));
	if ($msg eq 'on')
	{
		$cmd.= sprintf("%02X",$level);
	} else {
		$cmd.='00';
	}
	return $cmd;
}
1;
