=head1 NAME

B<Thermostat.pm> - Insteon Thermostat

=head1 DESCRIPTION

Enables support for an Insteon Thermostat.

=head1 SYNOPSIS

In user code:
	$thermostat = new Insteon_Thermostat($myPLM, '12.34.56');

In items.mht:
	INSTEON_THERMOSTAT, 12.34.56, thermostat, HVAC

Poll for temperature changes.

   if ( new_minute 5 && $Hour != 2 ) { # Skip the ALDB scanning hour
         $thermostat->poll_temp();
   }

Watch for temperature changes.

   if (state_now $thermostat eq 'temp_change') {
      my $temp = $thermostat->get_temp();
      print "Got new thermostat temperature: $temp\n";
   }

And, you can set the temperature and mode at will...

   if (state_changed $mode_vacation eq 'all') {
      $thermostat->mode('auto');
      $thermostat->heat_setpoint(60);
      $thermostat->cool_setpoint(89);
   }

All of the states that may be set:
   temp_change: Inside temperature changed 
      (call get_temp() to get value)
   heat_sp_change: Heat setpoint was changed
      (call get_heat_sp() to get value).
   cool_sp_change: Cool setpoint was changed
      (call get_cool_sp() to get value).
   mode_change: System mode changed
      (call get_mode() to get value).
   fan_mode_change: Fan mode changed
      (call get_fan_mode() to get value).

see code/examples/Insteon_thermostat.pl for more.

=head1 BUGS

Initial code for Venstar thermostats, which use Insteon engine version i1, only
provided basic features.  The new Insteon 2441TH thermostats use the i2cs engine
and only allow the polling, but not setting, of the thermostat attributes using
i2 code.  As such, I am unable to test or provide enhancements to certain i1 
only aspects.

=head1 AUTHOR

Initial Code by:
Gregg Liming <gregg@limings.net>
Brian Warren <brian@7811.net>

Enhanced to i2 by:
Kevin Rober Keegan <kevin@krkeegan.com>

=head1 TODO

 - Look at possible bugs when starting from factory defaults
      There seemed to be an issue with the setpoints changing when changing modes until
      they were set programatically.
 - Test fan modes and associated state_changes
 - Manage aldb - should be able to adjust setpoints based on plm scene. <- may be overkill

=head1 INHERITS

B<Insteon::DeviceController>

B<Insteon::BaseDevice>

=head1 Methods

=over
=cut

package Insteon::Thermostat;

use strict;
use Insteon::BaseInsteon;

@Insteon::Thermostat::ISA = ('Insteon::BaseDevice','Insteon::DeviceController');


# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

my %message_types = (
	%Insteon::BaseDevice::message_types,
	thermostat_temp_up => 0x68,
	thermostat_temp_down => 0x69,
	thermostat_get_zone_info => 0x6a,
	thermostat_control => 0x6b,
	thermostat_setpoint_cool => 0x6c,
	thermostat_setpoint_heat => 0x6d
);

sub new {
   my ($class, $p_deviceid, $p_interface) = @_;
   my $self = new Insteon::BaseDevice($p_deviceid,$p_interface);
   bless $self, $class;
   $$self{temp} = undef; 
   $$self{mode} = undef; 
   $$self{fan_mode} = undef; 
   $$self{heat_sp}  = undef; 
   $$self{cool_sp}  = undef; 
   $self->restore_data('temp','mode','fan_mode','heat_sp','cool_sp');
   $$self{m_pending_setpoint} = undef;
   $$self{message_types} = \%message_types;
   return $self;
}

=item C<poll_mode()>

Causes thermostat to return mode; detected as state change if mode changes
=cut
sub poll_mode {
   my ($self) = @_;
   $$self{_control_action} = "mode";
   my $message = new Insteon::InsteonMessage('insteon_send', $self, 'thermostat_control', '02');
   $self->_send_cmd($message);
   return;
}

=item C<mode()>

Sets system mode to argument: 'off', 'heat', 'cool', 'auto', 'program_heat', 
'program_cool', 'program_auto'.  The 2441TH thermostat does not have program_heat
 or program_cool.
=cut
sub mode{
	my ($self, $state) = @_;
	$state = lc($state);
	main::print_log("[Insteon::Thermostat] Mode $state") if  $main::Debug{insteon};
	my $mode;
	if ($state eq 'off') {
		$mode = "09";
	} elsif ($state eq 'heat') {
		$mode = "04";
	} elsif ($state eq 'cool') {
		$mode = "05";
	} elsif ($state eq 'auto') {
		$mode = "06";
	} elsif ($state eq 'program_heat') {
		$mode = "0a";
	} elsif ($state eq 'program_cool') {
		$mode = "0b";
	} elsif ($state eq 'program_auto') {
		$mode = "0c";
		$mode = "0a" if $self->_aldb->isa('Insteon::ALDB_i2');
	} else {
		main::print_log("[Insteon::Thermostat] ERROR: Invalid Mode state: $state");
		return();
	}
	$self->_send_cmd($self->simple_message('thermostat_control', $mode));
}

=item C<fan()>

Sets fan to 'on' or 'auto'
=cut
sub fan{
	my ($self, $state) = @_;
	$state = lc($state);
	main::print_log("[Insteon::Thermostat] Fan $state") if $main::Debug{insteon};
	my $fan;
	if (($state eq 'on') or ($state eq 'fan_on')) {
		$fan = '07';
		$state = 'fan_on';
	} elsif ($state eq 'auto' or $state eq 'off' or $state eq 'fan_auto') {
		$fan = '08';
		$state = 'fan_auto';
	} else {
		main::print_log("[Insteon::Thermostat] ERROR: Invalid Fan state: $state");
		return();
	}
   $self->_send_cmd($self->simple_message('thermostat_control', $fan));
}

=item C<cool_setpoint()>

Sets a new cool setpoint.
=cut
sub cool_setpoint{
	my ($self, $temp) = @_;
      main::print_log("[Insteon::Thermostat] Cool setpoint -> $temp") if $main::Debug{insteon};
      if($temp !~ /^\d+$/){
         main::print_log("[Insteon::Thermostat] ERROR: cool_setpoint $temp not numeric");
         return;
      }
	$self->_send_cmd($self->simple_message('thermostat_setpoint_cool', sprintf('%02X',($temp*2))));
}

=item C<heat_setpoint()>

Sets a new heat setpoint.
=cut
sub heat_setpoint{
	my ($self, $temp) = @_;
	main::print_log("[Insteon::Thermostat] Heat setpoint -> $temp") if $main::Debug{insteon};
	if($temp !~ /^\d+$/){
		main::print_log("[Insteon::Thermostat] ERROR: heat_setpoint $temp not numeric");
		return;
	}
	$self->_send_cmd($self->simple_message('thermostat_setpoint_heat', sprintf('%02X',($temp*2))));
}

=item C<poll_temp()>

Causes thermostat to return temp; detected as state change.
=cut
sub poll_temp {
   my ($self) = @_;
   $$self{_zone_action} = "temp";
   my $message = new Insteon::InsteonMessage('insteon_send', $self, 'thermostat_get_zone_info', '00');
   $self->_send_cmd($message);
   return;
}

=item C<get_temp()>

Returns the current temperature at the thermostat. 
=cut
sub get_temp() {
   my ($self) = @_;
   return $$self{'temp'};
}

=item C<poll_setpoint()>

Causes thermostat to return setpoint(s); detected as state change if setpoint changes. 
Returns setpoint based on mode, auto modes return both heat and cool. 
=cut
# The setpoint is returned in 2 messages while in the auto modes.
# The heat setpoint is returned in the ACK, which is followed by 
# a direct message containing the cool setpoint.  Because of this,
# we want to make sure we know how the mode is currently set.
sub poll_setpoint {
   my ($self) = @_;
   $self->poll_mode();
   $$self{_zone_action} = "setpoint";
   my $message = new Insteon::InsteonMessage('insteon_send', $self, 'thermostat_get_zone_info', '20');
   $self->_send_cmd($message);
   return;
}

=item C<get_heat_sp()>

Returns the current heat setpoint. 
=cut
sub get_heat_sp() {
   my ($self) = @_;
   return $$self{'heat_sp'};
}

=item C<get_cool_sp()>

Returns the current cool setpoint. 
=cut
sub get_cool_sp() {
   my ($self) = @_;
   return $$self{'cool_sp'};
}

sub _heat_sp() {
   my ($self,$p_state) = @_;
   if ($p_state ne $self->get_heat_sp()) {
      $self->set_receive('heat_setpoint_change');
      $$self{'heat_sp'} = $p_state;
   }
   return $$self{'heat_sp'};
}

sub _cool_sp() {
   my ($self,$p_state) = @_;
   if ($p_state ne $self->get_cool_sp()) {
      $self->set_receive('cool_setpoint_change');
      $$self{'cool_sp'} = $p_state;
   }
   return $$self{'cool_sp'};
}

sub _fan_mode() {
   my ($self,$p_state) = @_;
   if ($p_state ne $self->get_fan_mode()) {
      $self->set_receive('fan_mode_change');
      $$self{'fan_mode'} = $p_state;
   }
   return $$self{'fan_mode'};
}

sub _mode() {
   my ($self,$p_state) = @_;
   if ($p_state ne $self->get_mode()) {
      $self->set_receive('mode_change');
      $$self{'mode'} = $p_state;
   }
   return $$self{'mode'};
}

=item C<get_mode()>

Returns the last mode returned by C<poll_mode()>  I2 devices will report auto for both auto and program_auto. 
=cut
sub get_mode() {
   my ($self) = @_;
   return $$self{'mode'};
}

=item C<get_fan_mode()>

Returns the current fan mode (fan_on or fan_auto) 
=cut
sub get_fan_mode() {
   my ($self) = @_;
   return $$self{'fan_mode'};
}

sub _is_info_request {
   my ($self, $cmd, $ack_setby, %msg) = @_;
   my $is_info_request = ($cmd eq 'thermostat_get_zone_info'
   	or $cmd eq 'thermostat_control') ? 1 : 0;
   if ($is_info_request) {
      my $val = $msg{extra};
      main::print_log("[Insteon::Thermostat] Processing data for $cmd with value: $val") if $main::Debug{insteon}; 
      if ($$self{_zone_action} eq "temp") {
         $val = (hex $val) / 2; # returned value is twice the real value
         if (exists $$self{'temp'} and ($$self{'temp'} != $val)) {
            $self->set_receive('temp_change');
         }
         $$self{'temp'} = $val;
      } elsif ($$self{_control_action} eq "mode") {
         if ($val eq '00') {
            $self->_mode('off');
         } elsif ($val eq '01') {
            $self->_mode('heat');
         } elsif ($val eq '02') {
            $self->_mode('cool');
         } elsif ($val eq '03') {
            $self->_mode('auto');
         } elsif ($val eq '04') {
            $self->_fan_mode('fan_on');
         } elsif ($val eq '05') {
            $self->_mode('program_auto');
         } elsif ($val eq '06') {
            $self->_mode('program_heat');
         } elsif ($val eq '07') {
            $self->_mode('program_cool');
         } elsif ($val eq '08') {
            $self->_fan_mode('fan_auto');
         }
         $$self{_control_action} = undef;
      } elsif ($$self{_zone_action} eq 'setpoint') {
         $val = (hex $val) / 2; # returned value is twice the real value
         # in auto modes, expect direct message with cool_setpoint to follow 
         if ($self->get_mode() eq 'auto' or 'program_auto') {
            $self->_heat_sp($val);
            $$self{'m_pending_setpoint'} = 1;
         } elsif ($self->get_mode() eq 'heat' or 'program_heat') {
            $self->_heat_sp($val);
         } elsif ($self->get_mode() eq 'cool' or 'program_cool') {
            $self->_cool_sp($val);
         }
         $$self{_zone_action} = undef;
      } elsif ($$self{'m_pending_setpoint'} == 1) {
	#This is the second message with the cool_setpoint
	$val = (hex $val) / 2;
	$self->_cool_sp($val);
	$$self{'m_pending_setpoint'} = undef;
      }
   } 
   else #This was not a thermostat info_request
   {
   	#Check if this was a generic info_request
   	$is_info_request = $self->SUPER::_is_info_request($cmd, $ack_setby, %msg);
   }
   return $is_info_request;

}

## Unique messages handled first, non-unique sent to SUPER
sub _process_message
{
	my ($self,$p_setby,%msg) = @_;
	my $clear_message = 0;
	if ($$self{_zone_action} eq 'setpoint' && $$self{m_pending_setpoint}) {
		# we got our cool setpoint in auto mode
		my $val = (hex $msg{extra})/2;
		$self->_cool_sp($val);
		$$self{m_setpoint_pending} = 0;
		$clear_message = 1;
	} else {
		$clear_message = $self->SUPER::_process_message($p_setby,%msg);
	}
	return $clear_message;
}

## Creates either a Standard or Extended Message depending on the device type
## Can be used to create different classes later
sub simple_message {
	my ($self,$type,$extra) = @_;
	my $message;
	if ($self->_aldb->isa('Insteon::ALDB_i2')){
		$extra = $extra . "0000000000000000000000000000";
		$message = new Insteon::InsteonMessage('insteon_ext_send', $self, $type, $extra);
	} else {
		$message = new Insteon::InsteonMessage('insteon_send', $self, $type, $extra);
	}
	return $message;
}

# Overload methods we don't use, but would otherwise cause Insteon traffic.
sub request_status { return 0 }

sub level { return 0 }


package Insteon::Thermo_i1;
use strict;

@Insteon::Thermo_i1::ISA = ('Insteon::Thermostat');


package Insteon::Thermo_i2;
use strict;

@Insteon::Thermo_i2::ISA = ('Insteon::Thermostat');

sub init {
	my ($self) = @_;
	
	## Create the broadcast dummy item
	my $dev_id = $self->device_id();
	$dev_id =~ /(\w\w)(\w\w)(\w\w)/;
	$dev_id = "$1.$2.$3";
	$$self{bcast_item} = new Insteon::Thermo_i2_bcast("$dev_id".':EF');

	# Add bcast object to list of Insteon objects
	Insteon::add($$self{bcast_item});

	# Register bcast object with MH
	&main::register_object_by_name('$' . $self->get_object_name ."{bcast_item}",$$self{bcast_item});
	$$self{bcast_item}->{object_name} = '$' . $self->get_object_name ."{bcast_item}";
	
	## Create the child objects
	my @child_objs = ("mode", "fan", "temp", "humidity", "setpoint_h", "setpoint_c");
	#my $obj_group = ::get_object_by_name('HVAC');
	#$obj_group->add($$self{bcast});
	#&main::register_object_by_name($self->get_object_name ."{bcast}",$$self{bcast});
	#$$self{bcast}->{category} = "sample";
	#$$self{bcast}->{filename} = "sample";
	#$$self{bcast}->{object_name} = '$' . $self->get_object_name ."{bcast}";
}

package Insteon::Thermo_i2_bcast;
use strict;

@Insteon::Thermo_i2_bcast::ISA = ('Insteon::BaseDevice', 'Insteon::DeviceController');

###This is basically a dummy object, it is designed to allow a link from group
###EF to be added as part of sync links.  Group EF is the broadcast group used
###by the 2441th thermostat to announce changes.

sub new {
   my ($class, $p_deviceid) = @_;
   my $self = new Insteon::BaseDevice($p_deviceid);
   bless $self, $class;
   return $self;
}

package Insteon::Thermo_i2_mode;
use strict;

@Insteon::Thermo_i2_mode::ISA = ('Generic_Item');

sub new {
	my ($class) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	return $self;
}

package Insteon::Thermo_i2_fan;
use strict;

@Insteon::Thermo_i2_fan::ISA = ('Generic_Item');

sub new {
	my ($class) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	return $self;
}

package Insteon::Thermo_i2_temp;
use strict;

@Insteon::Thermo_i2_temp::ISA = ('Generic_Item');

sub new {
	my ($class) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	return $self;
}

package Insteon::Thermo_i2_humidity;
use strict;

@Insteon::Thermo_i2_humidity::ISA = ('Generic_Item');

sub new {
	my ($class) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	return $self;
}

package Insteon::Thermo_i2_setpoint_h;
use strict;

@Insteon::Thermo_i2_setpoint_h::ISA = ('Generic_Item');

sub new {
	my ($class) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	return $self;
}

package Insteon::Thermo_i2_setpoint_c;
use strict;

@Insteon::Thermo_i2_setpoint_c::ISA = ('Generic_Item');

sub new {
	my ($class) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	return $self;
}

1;
=back

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
=cut
