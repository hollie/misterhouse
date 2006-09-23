=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	UPB_Device.pm

Description:
	Generic class implementation of a UPB Device.

Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	$upb_patio_light = new UPB_Device($myPIM,30,1);

	$upb_patio_light->set("ON");

Special Thanks to:
	Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package UPB_Device;

@UPB_Device::ISA = ('Generic_Item');

my %message_types = ( 	
						null => 0x00,
						write_enable => 0x01,
						write_protect => 0x02,
						start_setup => 0x03,
						stop_setup => 0x04,
						setup_timer => 0x05,
						auto_address => 0x06,
						device_status => 0x07,
						device_control => 0x08,
						add_link => 0x0B,
						delete_link => 0x0C,
						transmit_message => 0x0D,
						reset => 0x0E,
						device_signature => 0x0F,
						get_register => 0x10,
						set_register => 0x11,
						activate_link => 0x20,
						deactivate_link => 0x21,
						goto => 0x22,
						fade_start => 0x23, 
						fade_stop =>0x24,
						blink => 0x25,
						indicate => 0x26,
						toggle => 0x27,
						report => 0x30,
						store => 0x31						
 );

sub new
{
	my ($class,$p_interface,$p_networkid,$p_deviceid) = @_;
	my $self={};
	bless $self,$class;

	$self->interface($p_interface) if defined $p_interface;
	$self->network_id($p_networkid) if defined $p_networkid;
	$self->device_id($p_deviceid) if defined $p_deviceid;
	$self->initialize();
	$self->rate(0);
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

sub network_id
{
	my ($self,$p_network_id) = @_;
	$$self{network_id} = $p_network_id if defined $p_network_id;
	return $$self{network_id};	
}

sub device_id
{
	my ($self,$p_device_id) = @_;
	$$self{device_id} = $p_device_id if defined $p_device_id;
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

	$$self{interface}->set($self->_xlate($p_state));
	$self->SUPER::set($p_state,$p_setby,$p_response);
}

sub _xlate
{
	my ($self,$p_state) = @_;
	my $cmd;

	#control word
	$cmd="0900";
	#network id;
	$cmd.= sprintf("%02X",$self->network_id());
	#destination;
	$cmd.= sprintf("%02X",$self->device_id());
	#source
	$cmd.= sprintf("%02X",$self->interface()->device_id());
	#msg id
	if (uc($p_state) eq 'ON')
	{	
		$cmd.= sprintf("%02X",$message_types{goto});
		$cmd.= sprintf("%02X",100);
		$cmd.= sprintf("%02X",$self->rate());
	} elsif (uc($p_state) eq 'OFF')
	{	
		$cmd.= sprintf("%02X",$message_types{goto});
		$cmd.= sprintf("%02X",0);
		$cmd.= sprintf("%02X",$self->rate());
	} elsif ($p_state=~/^[1]?[0-9]?[0-9]/)
	{	
		$cmd.= sprintf("%02X",$message_types{goto});
		$cmd.= sprintf("%02X",$p_state=~/^([1]?[0-9]?[0-9])/);
		$cmd.= sprintf("%02X",$self->rate());
	}
	
	return $cmd;
}

1;
