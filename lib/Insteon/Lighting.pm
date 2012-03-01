package Insteon::BaseLight;

use strict;
use Insteon::BaseInsteon;

@Insteon::BaseLight::ISA = ('Insteon::BaseDevice');

sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::BaseDevice($p_deviceid,$p_interface);
	bless $self,$class;
        # include very basic states
        @{$$self{states}} = ('on','off');

	return $self;
}

sub level
{
	my ($self, $p_level) = @_;
	if (defined $p_level) {
		my $level = 100;
		if ($p_level eq 'off')
		{
			$level = 0;
		}
		$$self{level} = $level;
	}
	return $$self{level};

}

package Insteon::DimmableLight;

use strict;
use Insteon::BaseInsteon;

@Insteon::DimmableLight::ISA = ('Insteon::BaseLight');

my %message_types = (
	%SUPER::message_types,
	bright => 0x15,
	dim => 0x16
);

my %ramp_h2n = (
						'00' => 540,
						'01' => 480,
						'02' => 420,
						'03' => 360,
						'04' => 300,
						'05' => 270,
						'06' => 240,
						'07' => 210,
						'08' => 180,
						'09' => 150,
						'0a' => 120,
						'0b' =>  90,
						'0c' =>  60,
						'0d' =>  47,
						'0e' =>  43,
						'0f' =>  39,
						'10' =>  34,
						'11' =>  32,
						'12' =>  30,
						'13' =>  28,
						'14' =>  26,
						'15' =>  23.5,
						'16' =>  21.5,
						'17' =>  19,
						'18' =>   8.5,
						'19' =>   6.5,
						'1a' =>   4.5,
						'1b' =>   2,
						'1c' =>    .5,
						'1d' =>    .3,
						'1e' =>    .2,
						'1f' =>    .1
);

sub convert_ramp
{
	my ($ramp_in_seconds) = @_;
	if ($ramp_in_seconds) {
		foreach my $rampkey (sort keys %ramp_h2n) {
			return $rampkey if $ramp_in_seconds >= $ramp_h2n{$rampkey};
		}
	} else {
		return '1f';
	}
}

sub get_ramp_from_code
{
	my ($ramp_code) = @_;
	if ($ramp_code) {
		return $ramp_h2n{$ramp_code};
	} else {
		return 0;
	}
}

sub convert_level
{
	my ($on_level) = @_;
	my $level = 'ff';
	if (defined ($on_level)) {
		if ($on_level eq '100') {
			$level = 'ff';
		} elsif ($on_level eq '0') {
			$level = '00';
		} else {
			$level = sprintf('%02X',$on_level * 2.55);
		}
	}
	return $level;
}

sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::BaseLight($p_deviceid,$p_interface);
	bless $self,$class;
	return $self;
}

sub level
{
	my ($self, $p_level) = @_;
	if (defined $p_level) {
		my $level = undef;
		if ($p_level eq 'on')
		{
			# set the level based on any locally defined on level
			$level = $self->local_onlevel if $self->can('local_onlevel');
			# set to 100 if a local on level is not defined
			$level=100 unless defined($level);
		} elsif ($p_level eq 'off')
		{
			$level = 0;
		} elsif ($p_level =~ /^([1]?[0-9]?[0-9])%?$/)
		{
			if ($1 < 1) {
				$level = 0;
			} else {
				$level = $1;
			}
		}
		$$self{level} = $level if defined $level;
	}
	return $$self{level};

}


package Insteon::ApplianceLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::ApplianceLinc::ISA = ('Insteon::BaseLight');

sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::BaseLight($p_deviceid,$p_interface);
	bless $self,$class;
	return $self;
}

sub set
{
	my ($self, $p_state, $p_setby, $p_respond) = @_;

	my $link_state = &Insteon::BaseObject::derive_link_state($p_state);

	return $self->Insteon::BaseDevice::set($link_state, $p_setby, $p_respond);
}


package Insteon::LampLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::LampLinc::ISA = ('Insteon::DimmableLight');


sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::DimmableLight($p_deviceid,$p_interface);
	bless $self,$class;
	return $self;
}

package Insteon::SwitchLincRelay;

use strict;
use Insteon::BaseInsteon;

@Insteon::SwitchLincRelay::ISA = ('Insteon::BaseLight','Insteon::DeviceController');


sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::BaseLight($p_deviceid,$p_interface);
	bless $self,$class;
	return $self;
}

sub set
{
	my ($self, $p_state, $p_setby, $p_respond) = @_;

	my $link_state = &Insteon::BaseObject::derive_link_state($p_state);

	return $self->Insteon::DeviceController::set($link_state, $p_setby, $p_respond);
}

package Insteon::SwitchLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::SwitchLinc::ISA = ('Insteon::DimmableLight','Insteon::DeviceController');

sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::DimmableLight($p_deviceid,$p_interface);
	bless $self,$class;
	return $self;
}

sub set
{
	my ($self, $p_state, $p_setby, $p_respond) = @_;

	return $self->Insteon::DeviceController::set($p_state, $p_setby, $p_respond);
}

package Insteon::KeyPadLincRelay;

use strict;
use Insteon::BaseInsteon;

@Insteon::KeyPadLincRelay::ISA = ('Insteon::BaseLight','Insteon::DeviceController');


sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::BaseLight($p_deviceid,$p_interface);
	bless $self,$class;
	return $self;
}

sub set
{
	my ($self, $p_state, $p_setby, $p_respond) = @_;

	my $link_state = &Insteon::BaseObject::derive_link_state($p_state);

	if (!($self->is_root))
	{
		my $rslt_code = $self->Insteon::BaseController::set($p_state, $p_setby, $p_respond);
		return $rslt_code if $rslt_code;

		if (ref $p_setby and $p_setby->isa('Insteon::BaseDevice'))
		{
			$self->Insteon::BaseObject::set($p_state, $p_setby, $p_respond);
		}
		elsif (ref $$self{surrogate} && ($$self{surrogate}->isa('Insteon::InterfaceController')))
		{
			$$self{surrogate}->set($link_state, $p_setby, $p_respond)
				unless ref $p_setby and $p_setby eq $self;
		}
		else
		{
			&::print_log("[Insteon::KeyPadLinc] You may not directly attempt to set a keypadlinc's button "
				. "unless you have defined a reverse link with the \"surrogate\" keyword");
		}
	}
	else
	{
		return $self->Insteon::DeviceController::set($link_state, $p_setby, $p_respond);
	}

	return 0;

}


package Insteon::KeyPadLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::KeyPadLinc::ISA = ('Insteon::DimmableLight','Insteon::DeviceController');


sub new
{
	my ($class,$p_deviceid,$p_interface) = @_;

	my $self = new Insteon::DimmableLight($p_deviceid,$p_interface);
	bless $self,$class;
	return $self;
}

sub set
{
	my ($self, $p_state, $p_setby, $p_respond) = @_;

	if (!($self->is_root))
	{
		my $rslt_code = $self->Insteon::BaseController::set($p_state, $p_setby, $p_respond);
		return $rslt_code if $rslt_code;

		my $link_state = &Insteon::BaseObject::derive_link_state($p_state);

		if (ref $p_setby and $p_setby->isa('Insteon::BaseDevice'))
		{
			$self->Insteon::BaseObject::set($p_state, $p_setby, $p_respond);
		}
		elsif (ref $$self{surrogate} && ($$self{surrogate}->isa('Insteon::InterfaceController')))
		{
			$$self{surrogate}->set($link_state, $p_setby, $p_respond)
				unless ref $p_setby and $p_setby eq $self;
		}
		else
		{
			&::print_log("[Insteon::KeyPadLinc] You may not directly attempt to set a keypadlinc's button "
				. "unless you have defined a reverse link with the \"surrogate\" keyword");
		}
	}
	else
	{
		return $self->Insteon::DeviceController::set($p_state, $p_setby, $p_respond);
	}

	return 0;

}

1