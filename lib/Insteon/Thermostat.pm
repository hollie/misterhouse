=begin comment

AUTHORS 
Gregg Liming <gregg@limings.net>
Brian Warren <brian@7811.net>

INITIAL CONFIGURATION
In user code:
   $thermostat = new Insteon_Thermostat($myPLM, '12.34.56');

In items.mht:

IPLT, 12.34.56, thermostat, HVAC, plm

BUGS


EXAMPLE USAGE
see code/examples/Insteon_thermostat.pl for more.

Creating the object:

   $thermostat = new Insteon_Thermostat($myPLM, '12.34.56');


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

All of the functions available:
   mode(): 
      Sets system mode to argument: 'off', 'heat', 'cool', 'auto',
      'program_heat', 'program_cool', 'program_auto'
   poll_mode(): 
      Causes thermostat to return mode; detected as state change if mode changes
   get_mode(): 
      Returns the last mode returned by poll_mode().
   fan(): 
      Sets fan to 'on' or 'auto'
   get_fan_mode(): 
      Returns the current fan mode (fan_on or fan_auto)
   poll_setpoint(): 
      Causes thermostat to return setpoint(s); detected as state change if setpoint changes
      Returns setpoint based on mode, auto modes return both heat and cool.
   cool_setpoint(): 
      Sets a new cool setpoint.
   get_cool_sp(): 
      Returns the current cool setpoint.
   heat_setpoint(): 
      Sets a new heat setpoint.
   get_heat_sp(): 
      Returns the current heat setpoint.
   poll_temp(): 
      Causes thermostat to return temp; detected as state change
   get_temp(): 
      Returns the current temperature at the thermostat.


#TODO 
 - Look at possible bugs when starting from factory defaults
      There seemed to be an issue with the setpoints changing when changing modes until
      they were set programatically.
 - Test fan modes and associated state_changes
 - Manage aldb - should be able to adjust setpoints based on plm scene. <- may be overkill
=cut

use strict;

package Insteon_Thermostat;

@Insteon_Thermostat::ISA = ('Insteon_Device');


# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

sub new {
   my ($class, $p_interface, $p_deviceid, $p_devcat) = @_;

   my $self = $class->SUPER::new($p_interface, $p_deviceid, $p_devcat);
   bless $self, $class;
   $$self{temp} = undef; 
   $$self{mode} = undef; 
   $$self{fan_mode} = undef; 
   $$self{heat_sp}  = undef; 
   $$self{cool_sp}  = undef; 
   $self->restore_data('temp','mode','fan_mode','heat_sp','cool_sp');
   $$self{m_pending_setpoint} = undef; 
   return $self;
}

sub poll_mode {
   my ($self) = @_;
   my $subcmd = '02';
   $self->_send_cmd(command => 'thermostat_get_mode', type => 'standard', extra => $subcmd, 'is_synchronous' => 1);
   return;
}

sub mode{
	my ($self, $state) = @_;
	$state = lc($state);
	print "$::Time_Date: Insteon_Thermostat -> Mode $state\n" unless $main::config_parms{no_log} =~/Insteon_Thermostat/;
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
	} else {
		print "Insteon_Thermostat: Invalid Mode state: $state\n";
		return();
	}
   $self->_send_cmd(command => 'thermostat_control', type => 'standard', extra => $mode);
}

sub fan{
	my ($self, $state) = @_;
	$state = lc($state);
	print "$::Time_Date: Insteon_Thermostat -> Fan $state\n" unless $main::config_parms{no_log} =~/Insteon_Thermostat/;
	my $fan;
	if (($state eq 'on') or ($state eq 'fan_on')) {
		$fan = '07';
      $state = 'fan_on';
	} elsif ($state eq 'auto' or $state eq 'off' or $state eq 'fan_auto') {
		$fan = '08';
      $state = 'fan_auto';
	} else {
		print "Insteon_Thermostat: Invalid Fan state: $state\n";
		return();
	}
   $self->_send_cmd(command => 'thermostat_control', type => 'standard', extra => $fan);
}

sub cool_setpoint{
	my ($self, $temp) = @_;
      print "$::Time_Date: [Insteon_Thermostat] Cool setpoint -> $temp\n" unless $main::config_parms{no_log} =~/Insteon_Thermostat/;
      if($temp !~ /^\d+$/){
         print "$::Time_Date: [Insteon_Thermostat] ERROR: cool_setpoint $temp not numeric\n";
         return;
      }

      $self->_send_cmd(command => 'thermostat_setpoint_cool', type => 'standard', extra => sprintf('%02X',($temp*2)));
}

sub heat_setpoint{
	my ($self, $temp) = @_;
	print "$::Time_Date: [Insteon_Thermostat] Heat setpoint -> $temp\n" unless $main::config_parms{no_log} =~/Insteon_Thermostat/;
	if($temp !~ /^\d+$/){
		print "$::Time_Date: [Insteon_Thermostat] ERROR: heat_setpoint $temp not numeric\n";
		return;
	}

   $self->_send_cmd(command => 'thermostat_setpoint_heat', type => 'standard', extra => sprintf('%02X',($temp*2)));
}

sub poll_temp {
   my ($self) = @_;
   my $subcmd = '00';
   $self->_send_cmd(command => 'thermostat_get_zone_temp', type => 'standard', extra => $subcmd, 'is_synchronous' => 1);
   return;
}

sub get_temp() {
   my ($self) = @_;
   return $$self{'temp'};
}

# The setpoint is returned in 2 messages while in the auto modes.
# The heat setpoint is returned in the ACK, which is followed by 
# a direct message containing the cool setpoint.  Because of this,
# we want to make sure we know how the mode is currently set.
sub poll_setpoint {
   my ($self) = @_;
   $self->poll_mode();
   my $subcmd = '20';
   $self->_send_cmd(command => 'thermostat_get_zone_setpoint', type => 'standard', extra => $subcmd, 'is_synchronous' => 1);
   return;
}

sub get_heat_sp() {
   my ($self) = @_;
   return $$self{'heat_sp'};
}

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

sub get_mode() {
   my ($self) = @_;
   return $$self{'mode'};
}

sub get_fan_mode() {
   my ($self) = @_;
   return $$self{'fan_mode'};
}

sub _is_info_request {
   my ($self, $cmd, $ack_setby, %msg) = @_;
   my $is_info_request = ($cmd eq 'thermostat_get_zone_temp'
   	or $cmd eq 'thermostat_get_zone_setpoint' or $cmd eq 'thermostat_get_zone_humidity'
   	or $cmd eq 'thermostat_get_mode' or $cmd eq 'thermostat_get_temp') ? 1 : 0;
   if ($is_info_request) {
      my $val = $msg{extra};
      &::print_log("[Insteon_Thermostat] Processing data for $cmd with value: $val") if $main::Debug{insteon}; 
      if ($cmd eq 'thermostat_get_temp' or $cmd eq 'thermostat_get_zone_temp') {
         $val = (hex $val) / 2; # returned value is twice the real value
         if (exists $$self{'temp'} and ($$self{'temp'} != $val)) {
            $self->set_receive('temp_change');
         }
         $$self{'temp'} = $val;
      } elsif ($cmd eq 'thermostat_get_mode') {
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
      } elsif ($cmd eq 'thermostat_get_zone_setpoint') {
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
      }

   }

   return $is_info_request;

}

# Need to handle some of these messages differently than Insteon_Device
# Trimming what I know we don't need, leaving what I'm unsure of. Still an excess
# of duplicated code.
sub _process_message
{
	my ($self,$p_setby,%msg) = @_;
	my $p_state = undef;
#   &::print_log("[Insteon_Thermostat] _process_message Type: ".$msg{type}.
#         "  Command: (" . $msg{command} . "  CMD2: " .$msg{extra}) if $main::Debug{insteon}; #XXX

	# the current approach assumes that links from other controllers to some responder
	# would be seen by the plm by also direct linking the controller as a responder
	# and not putting the plm into monitor mode.  This means that updating the state
	# of the responder based upon the link controller's request is handled
	# by Insteon_Link.
	$$self{m_is_locally_set} = 1 if $msg{source} eq lc $self->device_id;
	if ($msg{is_ack}) {
		if ($$self{awaiting_ack}) {
			my $pending_cmd = ($$self{_prior_msg}) ? $$self{_prior_msg}{command} : $msg{command};
			my $ack_setby = (ref $$self{m_status_request_pending}) 
				? $$self{m_status_request_pending} : $p_setby;
			if ($self->_is_info_request($pending_cmd,$ack_setby,%msg)) {
				$self->is_acknowledged(1);
				$$self{m_status_request_pending} = 0;
				$self->_process_command_stack(%msg);
			} else {
				$self->is_acknowledged(1);
				# signal receipt of message to the command stack in case commands are queued
				$self->_process_command_stack(%msg);
				&::print_log("[Insteon_Thermostat] received command/state (awaiting) acknowledge from " . $self->{object_name} 
					. ": $pending_cmd and data: $msg{extra}") if $main::Debug{insteon};
			} 
		} else {
			$self->is_acknowledged(1);
			# signal receipt of message to the command stack in case commands are queued
			$self->_process_command_stack(%msg);
			&::print_log("[Insteon_Thermostat] received command/state acknowledge from " . $self->{object_name} 
				. ": " . (($msg{command}) ? $msg{command} : "(unknown)")
				. " and data: $msg{extra}") if $main::Debug{insteon};
		}
	} elsif ($msg{is_nack}) {
		if ($$self{awaiting_ack}) {
			&::print_log("[Insteon_Thermostat] WARN!! encountered a nack message for " . $self->{object_name} 
				. " ... waiting for retry");
		} else {
			&::print_log("[Insteon_Thermostat] WARN!! encountered a nack message for " . $self->{object_name} 
				. " ... skipping");
			$self->is_acknowledged(0);
			$self->_process_command_stack(%msg);
		}
   } elsif ($msg{type} eq 'broadcast') {
      $self->devcat($msg{devcat});
      &::print_log("[Insteon_Thermostat] device category: $msg{devcat} received for " . $self->{object_name});
      #stop ping timer now that we have a devcat; possibly may want to change this behavior to allow recurring pings
      $$self{ping_timer}->stop();
   } elsif ($msg{command} eq 'thermostat_get_zone_setpoint' && $$self{m_pending_setpoint}) {
      # we got our cool setpoint in auto mode
      my $val = (hex $msg{extra})/2;
      $self->_cool_sp($val);
      $$self{m_setpoint_pending} = 0;
	} else {
		## TO-DO: make sure that the state passed by command is something that is reasonable to set
		$p_state = $msg{command};
		$$self{_pending_cleanup} = 1 if $msg{type} eq 'alllink';
#		$self->set($p_state, $p_setby) unless (lc($self->state) eq lc($p_state)) and 
		$self->set($p_state, $self) unless (lc($self->state) eq lc($p_state)) and 
			($msg{type} eq 'cleanup' and $$self{_pending_cleanup});
		$$self{_pending_cleanup} = 0 if $msg{type} eq 'cleanup';
	}
}

# Overload methods we don't use, but would otherwise cause Insteon traffic.
sub request_status { return 0 }

1;
