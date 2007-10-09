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
		if ($$self{members} && $$self{members}{$obj}) {
			print "[Insteon_Link] An object (" . $obj->{object_name} . ") already exists "
				. "in this scene.  Aborting add request.\n";
			return;
		}
		$on_level = '100%' unless $on_level;
		$$self{members}{$obj}{on_level} = $on_level;
		$$self{members}{$obj}{object} = $obj;
		$$self{members}{$obj}{ramp_rate} = $ramp_rate if defined $ramp_rate;
	}
}

sub _xlate_mh_insteon
{
	my ($self, $p_state, $p_type, $p_extra) = @_;
print "INSTEON_LINK state: $p_state\n";
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
