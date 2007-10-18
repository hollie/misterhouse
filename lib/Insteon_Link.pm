=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Insteon_Link.pm

Description:
	Generic class implementation of a Insteon Device.

Author:
	Gregg Liming w/ significant code reuse from:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	$insteon_family_movie = new Insteon_Device($myPIM,30,1);

	$insteon_familty_movie->set("on");

Special Thanks to:
	Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use Insteon_Device;

use strict;
package Insteon_Link;

@Insteon_Link::ISA = ('Insteon_Device');


sub new
{
	my ($class,$p_interface,$p_deviceid) = @_;

	# note that $p_deviceid will be 00.00.00:<groupnum> if the link uses the interface as the controller
	my $self = $class->SUPER::new($p_interface,$p_deviceid);
	bless $self,$class;

	return $self;
}

sub add 
{
	my ($self, $obj, $on_level, $ramp_rate) = @_;
	if (ref $obj) {
	# TO-DO prevent objects other than Insteon_Device and Light_Item from being members
		if ($$self{members} && $$self{members}{$obj}) {
			print "[Insteon_Link] An object (" . $obj->{object_name} . ") already exists "
				. "in this scene.  Aborting add request.\n";
			return;
		}
		$on_level = '100%' unless $on_level;
		$$self{members}{$obj}{on_level} = $on_level;
		$$self{members}{$obj}{object} = $obj;
		$ramp_rate =~ s/s$//i;
		$$self{members}{$obj}{ramp_rate} = $ramp_rate if defined $ramp_rate;
	}
}

sub set
{
	my ($self, $p_state, $p_setby, $p_respond) = @_;
	# iterate over the members
	if ($$self{members}) {
		foreach my $member_ref (keys %{$$self{members}}) {
			my $member = $$self{members}{$member_ref}{object};
			my $on_state = $$self{members}{$member_ref}{on_level};
			$on_state = '100%' unless $on_state;
			my $local_state = $on_state;
			$local_state = 'on' if $local_state = '100%';
			$local_state = 'off' if $local_state = '0%';
			if ($member->isa('Light_Item')) {
			# if they are Light_Items, then set their on_dim attrib to the member on level
			#   and then "blank" them via the manual method for a tad over the ramp rate
			#   In addition, locate the Light_Item's Insteon_Device member and do the 
			#   same as if the member were an Insteon_Device
				my $ramp_rate = $$self{members}{$member_ref}{ramp_rate};
				$ramp_rate = 0 unless defined $ramp_rate;
				$ramp_rate = $ramp_rate + 2;
				my @lights = $member->find_members('Insteon_Device');
				if (@lights) {
					my $light = @lights[0];
					$member->manual($light, $ramp_rate);
					$light->set_receive($local_state,$self);
				} else {
					$member->manual(1, $ramp_rate);
				}
				$member->set_on_state($on_state);
			} elsif ($member->isa('Insteon_Device')) {
			# if they are Insteon_Device objects, then simply set_receive their state to 
			#   the member on level
				$member->set_receive($local_state,$self);
			}
		}
	}
	$self->SUPER::set($p_state, $p_setby, $p_respond);
}

sub update_members
{
	my ($self) = @_;
	# iterate over the members
	if ($$self{members}) {
		foreach my $member_ref (keys %{$$self{members}}) {
			my ($device);
			my $member = $$self{members}{$member_ref}{object};
			my $on_state = $$self{members}{$member_ref}{on_level};
			$on_state = '100%' unless $on_state;
			my $ramp_rate = $$self{members}{$member_ref}{ramp_rate};
			$ramp_rate = 0 unless defined $ramp_rate;
			if ($member->isa('Light_Item')) {
			# if they are Light_Items, then locate the Light_Item's Insteon_Device member
				my @lights = $member->find_members('Insteon_Device');
				if (@lights) {
					$device = @lights[0];
				} 
			} elsif ($member->isa('Insteon_Device')) {
				$device = $member;
			}
			if ($device) {
				my %current_record = $device->get_link_record($self->device_id . $self->group);
				if (%current_record) {
					&::print_log("[Insteon_Link] remote record: $current_record{data1}")
						if $::Debug{insteon};
				}
			}
		}
	}
}


sub initiate_linking_as_controller
{
	my ($self, $p_group) = @_;
	# iterate over the members
	if ($$self{members}) {
		foreach my $member_ref (keys %{$$self{members}}) {
			my $member = $$self{members}{$member_ref}{object};
			if ($member->isa('Light_Item')) {
			# if they are Light_Items, then set them to manual to avoid automation
			#   while manually setting light parameters
				$member->manual(1,120,120); # 120 seconds should be enough
			} 
		}
	}
	$self->interface()->initiate_linking_as_controller($p_group);
}

sub _xlate_mh_insteon
{
	my ($self, $p_state, $p_type, $p_extra) = @_;
	return $self->SUPER::_xlate_mh_insteon($p_state, 'broadcast', $p_extra);
}

sub request_status
{
	my ($self) = @_;
	&::print_log("[Insteon_Link] requesting status for members of " . $$self{object_name});
	foreach my $member (keys %{$$self{members}}) {
		$$self{members}{$member}{object}->request_status($self);
	}
}

1;
