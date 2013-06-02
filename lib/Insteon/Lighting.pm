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
		$on_level =~ s/(\d+)%?/$1/;
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

@Insteon::LampLinc::ISA = ('Insteon::DimmableLight','Insteon::DeviceController');


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

package Insteon::FanLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::FanLinc::ISA = ('Insteon::DimmableLight','Insteon::DeviceController');

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
	if ($self->is_root()){
		return $self->Insteon::DeviceController::set($p_state, $p_setby, $p_respond);
	} else {
		if ($self->_is_valid_state($p_state)) {
			# always reset the is_locally_set property unless set_by is the device
			$$self{m_is_locally_set} = 0 unless ref $p_setby and $p_setby eq $self;

			# handle invalid state for non-dimmable devices
			my $level = $p_state;
			if ($p_state eq 'dim' or $p_state eq 'bright') {
				$p_state = 'on';
			}
			elsif ($p_state eq 'toggle')
			{
				$p_state = 'off' if ($self->state eq 'on');
				$p_state = 'on' if ($self->state eq 'off');
			}
			$level = '00' if ($p_state eq 'off');
			$level = 'ff' if ($p_state eq 'on');
			# Setting Fan Level
			my $setby_name = $p_setby;
			$setby_name = $p_setby->get_object_name() if (ref $p_setby and $p_setby->can('get_object_name'));
			my $parent = $self->get_root();
			$level = ::Insteon::DimmableLight::convert_level($level) if ($level ne '00' && $level ne 'ff');
			my $extra = $level ."0200000000000000000000000000";
			my $message = new Insteon::InsteonMessage('insteon_ext_send', $parent, 'on', $extra);
			$parent->_send_cmd($message);
			::print_log("[Insteon::FanLinc] " . $self->get_object_name() . "::set($p_state, $setby_name)")
				if $main::Debug{insteon};
			$self->is_acknowledged(0);
			$$self{pending_state} = $p_state;
			$$self{pending_setby} = $p_setby;
			$$self{pending_response} = $p_respond;
			$$parent{child_pending_state} = $self->group();
		} else {
			::print_log("[Insteon::FanLinc] failed state validation with state=$p_state");
		}	
	}
}

sub request_status
{
	my ($self,$requestor) = @_;
	if ($self->is_root()){
		return $self->SUPER::request_status($requestor);
	} else {
		# Setting Fan Level
		my $parent = $self->get_root();
		$$parent{child_status_request_pending} = $self->group;
		$$self{m_status_request_pending} = ($requestor) ? $requestor : 1;
		my $message = new Insteon::InsteonMessage('insteon_send', $parent, 'status_request', '03');
		$parent->_send_cmd($message);
	}
}

sub _is_info_request
{
	my ($self, $cmd, $ack_setby, %msg) = @_;
	my $is_info_request = 0;
	my $parent = $self->get_root();
	if ($$parent{child_status_request_pending}) {
		$is_info_request++;
		my $child_obj = Insteon::get_object($self->device_id, '02');
		my $child_state = &Insteon::BaseObject::derive_link_state(hex($msg{extra}));
		&::print_log("[Insteon::FanLinc] received status for " .
			$child_obj->{object_name} . " of: $child_state "
			. "hops left: $msg{hopsleft}") if $main::Debug{insteon};
		$ack_setby = $$child_obj{m_status_request_pending} if ref $$child_obj{m_status_request_pending};
		$child_obj->SUPER::set($child_state, $ack_setby);
		delete($$parent{child_status_request_pending});
	} else {
		$is_info_request = $self->SUPER::_is_info_request($cmd, $ack_setby, %msg);
	}
	return $is_info_request;
}

sub is_acknowledged
{
	my ($self, $p_ack) = @_;
	my $parent = $self->get_root();
        if ($p_ack && $$parent{child_pending_state})
        {
        	my $child_obj = Insteon::get_object($self->device_id, '02');
		$child_obj->set_receive($$child_obj{pending_state},$$child_obj{pending_setby}, $$child_obj{pending_response}) if defined $$child_obj{pending_state};
		$$child_obj{is_acknowledged} = $p_ack;
		$$child_obj{pending_state} = undef;
		$$child_obj{pending_setby} = undef;
		$$child_obj{pending_response} = undef;
		$$parent{child_pending_state} = undef;
		&::print_log("[Insteon::FanLinc] received command/state acknowledge from " . $child_obj->{object_name}) if $main::Debug{insteon};
		return $$self{is_acknowledged};
	} else {
		return $self->SUPER::is_acknowledged($p_ack);
	}
}


1