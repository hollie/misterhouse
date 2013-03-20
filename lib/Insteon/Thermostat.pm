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

our %message_types = (
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
   my $is_info_request = ($cmd eq 'thermostat_get_zone_info') ? 1 : 0;
   if ($is_info_request) {
      my $val = $msg{extra};
      main::print_log("[Insteon::Thermostat] Processing is_info_request for $cmd with value: $val") if $main::Debug{insteon}; 
      if ($$self{_zone_action} eq "temp") {
         $val = (hex $val) / 2; # returned value is twice the real value
         if (exists $$self{'temp'} and ($$self{'temp'} != $val)) {
            $self->set_receive('temp_change');
         }
         $$self{'temp'} = $val;
      } elsif ($$self{_zone_action} eq 'setpoint') {
         $val = (hex $val) / 2; # returned value is twice the real value
         # in auto modes, expect direct message with cool_setpoint to follow 
         if ($self->get_mode() eq 'auto' or 'program_auto') {
            $self->_heat_sp($val);
            $$self{'m_pending_setpoint'} = 1;
         } elsif ($self->get_mode() eq 'heat' or 'program_heat') {
            $self->_heat_sp($val);
            $$self{_zone_action} = undef;
         } elsif ($self->get_mode() eq 'cool' or 'program_cool') {
            $self->_cool_sp($val);
            $$self{_zone_action} = undef;
         }
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
	if ($msg{command} eq "thermostat_setpoint_cool" && $msg{is_ack}){
		main::print_log("[Insteon::Thermostat] Received ACK of cool setpoint ".
			"for ". $self->get_object_name) if $main::Debug{insteon};	
		$self->_cool_sp((hex($msg{extra})/2));
		$clear_message = 1;
	}
	elsif ($msg{command} eq "thermostat_setpoint_heat" && $msg{is_ack}){
		main::print_log("[Insteon::Thermostat] Received ACK of heat setpoint ".
			"for ". $self->get_object_name) if $main::Debug{insteon};	
		$self->_heat_sp((hex($msg{extra})/2));
		$clear_message = 1;
	}
	elsif ($$self{_zone_action} eq 'setpoint' && $$self{m_pending_setpoint}) {
		# we got our cool setpoint in auto mode
		main::print_log("[Insteon::Thermostat] Processing data for $msg{command} with value: $msg{extra}") if $main::Debug{insteon};
		my $val = (hex $msg{extra})/2;
		$self->_cool_sp($val);
		$$self{m_setpoint_pending} = 0;
		$$self{_zone_action} = undef;
		$clear_message = 1;
	} else {
		$clear_message = $self->SUPER::_process_message($p_setby,%msg);
	}
	return $clear_message;
}

# Overload methods we don't use, but would otherwise cause Insteon traffic.
sub request_status { return 0 }

sub level { return 0 }


package Insteon::Thermo_i1;
use strict;

@Insteon::Thermo_i1::ISA = ('Insteon::Thermostat');

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
	} else {
		main::print_log("[Insteon::Thermostat] ERROR: Invalid Mode state: $state");
		return();
	}
	$$self{_control_action} = "mode";
	$self->_send_cmd($self->simple_message('thermostat_control', $mode));
}

sub _is_info_request {
	my ($self, $cmd, $ack_setby, %msg) = @_;
	my $is_info_request;
	if ($cmd eq 'thermostat_control' && $$self{_control_action} eq "mode") {
		my $val = $msg{extra};
		main::print_log("[Insteon::Thermo_i1] Processing is_info_request for $cmd with value: $val") if $main::Debug{insteon}; 
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
		$is_info_request = 1;
	}
	else #This was not a thermo_1 info_request
	{
		#Check if this was a generic info_request
		$is_info_request = $self->SUPER::_is_info_request($cmd, $ack_setby, %msg);
	}
	return $is_info_request;
}

## Creates a simple Standard Message
sub simple_message {
	my ($self,$type,$extra) = @_;
	my $message;
	$message = new Insteon::InsteonMessage('insteon_send', $self, $type, $extra);
	return $message;
}

package Insteon::Thermo_i2;
use strict;

@Insteon::Thermo_i2::ISA = ('Insteon::Thermostat');

our %message_types = (
	%Insteon::Thermostat::message_types,
	extended_set_get => 0x2e,
	status_temp	=> 0x6e,
	status_humid	=> 0x6f,
	status_mode	=> 0x70,
	status_cool	=> 0x71,
	status_heat	=> 0x72
);

sub init {
	my ($self) = @_;
	$$self{message_types} = \%message_types;
	
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
	my @child_objs = ('mode_item', 'fan_item', 'temp_item', 'humidity_item',
		'setpoint_h_item', 'setpoint_c_item');
	foreach my $obj (@child_objs) {
		$$self{$obj} = new Insteon::Thermo_i2_mode() if ($obj eq 'mode_item');
		$$self{$obj} = new Insteon::Thermo_i2_fan() if ($obj eq 'fan_item');
		$$self{$obj} = new Insteon::Thermo_i2_temp() if ($obj eq 'temp_item');
		$$self{$obj} = new Insteon::Thermo_i2_humidity() if ($obj eq 'humidity_item');
		$$self{$obj} = new Insteon::Thermo_i2_setpoint_h() if ($obj eq 'setpoint_h_item');
		$$self{$obj} = new Insteon::Thermo_i2_setpoint_c() if ($obj eq 'setpoint_c_item');

		# Register child object with MH
		&main::register_object_by_name('$' . $self->get_object_name ."{$obj}",$$self{$obj});
		$$self{$obj}->{object_name} = '$' . $self->get_object_name ."{$obj}";
		$$self{$obj}{parent} = $self;
		
		#Add child to the same groups as parent
		foreach my $parent_group (::list_groups_by_object($self,1)){
			$parent_group->add($$self{$obj});
		}
	}
	#Set saved state unique to i2
	$self->restore_data('humid');

	#Set child saved states
	$$self{temp_item}->set_receive($self->get_temp());
	$$self{setpoint_h_item}->set_receive($self->get_heat_sp());
	$$self{setpoint_c_item}->set_receive($self->get_cool_sp());
	$$self{fan_item}->set_receive($self->get_fan_mode());
	$$self{mode_item}->set_receive($self->get_mode());
	$$self{humidity_item}->set_receive($$self{humid});
		
	#Tie changes in parent item to children
	$self -> tie_event ('Insteon::Thermo_i2::parent_event(\''.$$self{object_name} . '\', "$state")');
}

sub sync_links{
	my ($self, $audit_mode, $callback, $failure_callback) = @_;
	#Make sure thermostat is set to broadcast changes
	::print_log("[Insteon::Thermo_i2] (sync_links) Enabling thermostat broadcast setting.") unless $audit_mode;
	my $extra = "000008000000000000000000000000";
	my $message = new Insteon::InsteonMessage('insteon_ext_send', $self, 'extended_set_get', $extra);
	$$self{_ext_set_get_action} = 'set';
	$self->_send_cmd($message);
	# Call the main sync_links code
	return $self->SUPER::sync_links($audit_mode, $callback, $failure_callback);
}

sub parent_event {
	my ($self, $p_state) = @_;
	$self = ::get_object_by_name($self);
	if ($p_state eq 'temp_change'){
		$$self{temp_item}->set_receive($self->get_temp());
	}
	elsif ($p_state eq 'heat_setpoint_change'){
		$$self{setpoint_h_item}->set_receive($self->get_heat_sp());
	}
	elsif ($p_state eq 'cool_setpoint_change'){
		$$self{setpoint_c_item}->set_receive($self->get_cool_sp());
	}
	elsif ($p_state eq 'fan_mode_change'){
		$$self{fan_item}->set_receive($self->get_fan_mode());
	}
	elsif ($p_state eq 'mode_change'){
		$$self{mode_item}->set_receive($self->get_mode());
	}
	elsif ($p_state eq 'humid_change'){
		$$self{humidity_item}->set_receive($$self{humid});
	}
}

sub poll_simple{
	my ($self) = @_;
	my $extra = "020000000000000000000000000000";
	my $message = new Insteon::InsteonMessage('insteon_ext_send', $self, 'extended_set_get', $extra);
	$$message{add_crc16} = 1;
	$self->_send_cmd($message);
}

sub _process_message {
	my ($self,$p_setby,%msg) = @_;
	my $clear_message = 0;
	if ($msg{command} eq "extended_set_get" && $msg{is_ack}){
		#If this was a get request don't clear until data packet received
		main::print_log("[Insteon::Thermo_i2] Extended Set/Get ACK Received for " . $self->get_object_name) if $main::Debug{insteon};
		if ($$self{_ext_set_get_action} eq 'set'){
			main::print_log("[Insteon::Thermo_i2] Clearing active message") if $main::Debug{insteon};
			$clear_message = 1;
			$$self{_ext_set_get_action} = undef;
			$self->_process_command_stack(%msg);	
		}
	} 
	elsif ($msg{command} eq "extended_set_get" && $msg{is_extended}) {
		if (substr($msg{extra},0,4) eq "0201") {
			main::print_log("[Insteon::Thermo_i2] Extended Set/Get Data ".
				"Received for ". $self->get_object_name) if $main::Debug{insteon};
			#0 = 2				#14 = Cool SP 
			#2 = 1				#16 = humidity
			#3 = day			#18 = temp in Celsius High byte
			#6 = hour			#20 = temp low byte
			#8 = minute			#22 = status flag
			#10 = second			#24 = Heat SP
			#12 = Sys_mode * 16 + Fan_mode
			my $mode = hex(substr($msg{extra}, 12, 2)); 
			my $fan_mode = ($mode % 16);
			$self->dec_mode(($mode - $fan_mode) / 16);
			$self->dec_fan($fan_mode);
			$self->hex_cool(substr($msg{extra}, 14, 2));
			$self->hex_humid(substr($msg{extra}, 16, 2));
			$self->hex_long_temp(substr($msg{extra}, 18, 4));
			$self->hex_status(substr($msg{extra}, 22, 2));
			$self->hex_heat(substr($msg{extra}, 24, 2));			
			$clear_message = 1;
			$self->_process_command_stack(%msg);
		} else {
			main::print_log("[Insteon::Thermo_i2] WARN: Corrupt Extended "
				."Set/Get Data Received for ". $self->get_object_name) if $main::Debug{insteon};
		}
	}
	elsif ($msg{command} eq "status_temp" && !$msg{is_ack}){
		main::print_log("[Insteon::Thermo_i2] Received Status Temp Message ".
			"for ". $self->get_object_name) if $main::Debug{insteon};	
		$self->hex_short_temp($msg{extra});
	}
	elsif ($msg{command} eq "status_mode" && !$msg{is_ack}){
		main::print_log("[Insteon::Thermo_i2] Received Status Mode Message ".
			"for ". $self->get_object_name) if $main::Debug{insteon};	
		$self->status_mode($msg{extra});
	}
	elsif ($msg{command} eq "status_cool" && !$msg{is_ack}){
		main::print_log("[Insteon::Thermo_i2] Received Status Cool Message ".
			"for ". $self->get_object_name) if $main::Debug{insteon};	
		$self->hex_cool($msg{extra});
	}
	elsif ($msg{command} eq "status_humid" && !$msg{is_ack}){
		main::print_log("[Insteon::Thermo_i2] Received Status Humid Message ".
			"for ". $self->get_object_name) if $main::Debug{insteon};	
		$self->hex_humid($msg{extra});
	}
	elsif ($msg{command} eq "status_heat" && !$msg{is_ack}){
		main::print_log("[Insteon::Thermo_i2] Received Status Heat Message ".
			"for ". $self->get_object_name) if $main::Debug{insteon};	
		$self->hex_heat($msg{extra});
	}
	else {
		$clear_message = $self->SUPER::_process_message($p_setby,%msg);
	}
	return $clear_message;
}

sub _is_info_request {
	my ($self, $cmd, $ack_setby, %msg) = @_;
	my $is_info_request;
	if ($cmd eq 'thermostat_control' && $$self{_control_action} eq "mode") {
		my $val = $msg{extra};
		main::print_log("[Insteon::Thermo_i2] Processing is_info_request for $cmd with value: $val") if $main::Debug{insteon}; 
		if ($val eq '09') {
			$self->_mode('Off');
		} elsif ($val eq '04') {
			$self->_mode('Heat');
		} elsif ($val eq '05') {
			$self->_mode('Cool');
		} elsif ($val eq '06') {
			$self->_mode('Auto');
		} elsif ($val eq '0a') {
			$self->_mode('Program');
		}
		$$self{_control_action} = undef;
		$is_info_request = 1;
	}
	else #This was not a thermo_i2 info_request
	{
		#Check if this was a generic info_request
		$is_info_request = $self->SUPER::_is_info_request($cmd, $ack_setby, %msg);
	}
	return $is_info_request;
}

sub dec_mode{
	my ($self, $dec_mode) = @_;
	my $mode;
	$mode = 'Off' if ($dec_mode == 0);
	$mode = 'Auto' if ($dec_mode == 1); 
	$mode = 'Heat' if ($dec_mode == 2); 
	$mode = 'Cool' if ($dec_mode == 3);  
	$mode = 'Program' if ($dec_mode == 4);
	$self->_mode($mode);
}

sub status_mode{
	my ($self, $status_mode) = @_;
	my $mode;
	my $conv_mode = (hex($status_mode)%16);
	$mode = 'Off' if ($conv_mode == 0);
	$mode = 'Heat' if ($conv_mode == 1); 
	$mode = 'Cool' if ($conv_mode == 2); 
	$mode = 'Auto' if ($conv_mode == 3);  
	$mode = 'Program' if ($conv_mode == 4);
	$self->_mode($mode);
	my $fan_mode;
	$fan_mode = (hex($status_mode) >= 16) ? 'Always On' : 'Auto';
	$self->_fan_mode($fan_mode);
}

sub dec_fan{
	my ($self, $dec_fan) = @_;
	my $fan;
	$fan = 'Auto' if ($dec_fan == 0);
	$fan = 'Always On' if ($dec_fan == 1); 
	$self->_fan_mode($fan);
}

sub hex_cool{
	my ($self, $hex_cool) = @_;
	$self->_cool_sp(hex($hex_cool));
}
sub hex_humid{
	my ($self, $hex_humid) = @_;
	$self->_humid(hex($hex_humid));
}
sub hex_long_temp{
	my ($self, $hex_temp) = @_;
	my $temp_cel = (hex($hex_temp)/10);
	## ATM I am going to assume farenheit b/c that is what I have
	# in future, can pull setting bit from thermometer
	$$self{temp} = (($temp_cel*9)/5 +32);
	$self->set_receive('temp_change');
}

sub hex_short_temp{
	my ($self, $hex_temp) = @_;
	$$self{temp} = (hex($hex_temp)/2);
	$self->set_receive('temp_change');
}

sub hex_status{
	### Not sure about this one yet, was 80 when set to auto but no activity
}
sub hex_heat{
	my ($self, $hex_heat) = @_;
	$self->_heat_sp(hex($hex_heat));	
}

sub _humid {
	my ($self,$p_state) = @_;
	if ($p_state ne $$self{humid}) {
		$$self{humid} = $p_state;
		$self->set_receive('humid_change');
	}
	return $$self{humid};
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
	} elsif ($state eq 'program') {
		$mode = "0a" if $self->_aldb->isa('Insteon::ALDB_i2');
	} else {
		main::print_log("[Insteon::Thermostat] ERROR: Invalid Mode state: $state");
		return();
	}
	$$self{_control_action} = "mode";
	$self->_send_cmd($self->simple_message('thermostat_control', $mode));
}

## Creates an Extended Message
sub simple_message {
	my ($self,$type,$extra) = @_;
	my $message;
	$extra = $extra . "0000000000000000000000000000";
	$message = new Insteon::InsteonMessage('insteon_ext_send', $self, $type, $extra);
	return $message;
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
	@{$$self{states}} = ('Off', 'Heat', 'Cool', 'Auto', 'Program');
	return $self;
}

sub set {
	my ($self, $p_state, $p_setby, $p_response) = @_;
	my $found_state = 0;
	foreach my $test_state (@{$$self{states}}){
		if (lc($test_state) eq lc($p_state)){
			$found_state = 1;
		}
	}
	if ($found_state){
		::print_log("[Insteon::Thermo_i2] Received set mode request to "
			. $p_state . " for device " . $self->get_object_name);
		$$self{parent}->mode($p_state);
	}
}

sub set_receive {
	my ($self, $p_state) = @_;
	$self->SUPER::set($p_state);
}

package Insteon::Thermo_i2_fan;
use strict;

@Insteon::Thermo_i2_fan::ISA = ('Generic_Item');

sub new {
	my ($class) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	@{$$self{states}} = ('Auto', 'On');
	return $self;
}

sub set {
	my ($self, $p_state, $p_setby, $p_response) = @_;
	my $found_state = 0;
	foreach my $test_state (@{$$self{states}}){
		if (lc($test_state) eq lc($p_state)){
			$found_state = 1;
		}
	}
	if ($found_state){
		::print_log("[Insteon::Thermo_i2] Received set fan to "
			. $p_state . " for device " . $self->get_object_name);
		$$self{parent}->fan($p_state);
	}
}

sub set_receive {
	my ($self, $p_state) = @_;
	$self->SUPER::set($p_state);
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

sub set_receive {
	my ($self, $p_state) = @_;
	$self->SUPER::set($p_state);
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

sub set_receive {
	my ($self, $p_state) = @_;
	$self->SUPER::set($p_state);
}

package Insteon::Thermo_i2_setpoint_h;
use strict;

@Insteon::Thermo_i2_setpoint_h::ISA = ('Generic_Item');

sub new {
	my ($class) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	@{$$self{states}} = ('Cooler' , 'Warmer');
	return $self;
}

sub set {
	my ($self, $p_state, $p_setby, $p_response) = @_;
	my $found_state = 0;
	foreach my $test_state (@{$$self{states}}){
		if (lc($test_state) eq lc($p_state)){
			$found_state = 1;
		}
	}
	if ($found_state){
		::print_log("[Insteon::Thermo_i2] Received request to set heat setpoint "
			. $p_state . " for device " . $self->get_object_name);
		if (lc($p_state) eq 'cooler'){
			$$self{parent}->heat_setpoint($$self{parent}->get_heat_sp - 1);
		}
		elsif (lc($p_state) eq 'warmer'){
			$$self{parent}->heat_setpoint($$self{parent}->get_heat_sp + 1);
		}
	}
}

sub set_receive {
	my ($self, $p_state) = @_;
	$self->SUPER::set($p_state);
}

package Insteon::Thermo_i2_setpoint_c;
use strict;

@Insteon::Thermo_i2_setpoint_c::ISA = ('Generic_Item');

sub new {
	my ($class) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	@{$$self{states}} = ('Cooler', 'Warmer');
	return $self;
}

sub set {
	my ($self, $p_state, $p_setby, $p_response) = @_;
	my $found_state = 0;
	foreach my $test_state (@{$$self{states}}){
		if (lc($test_state) eq lc($p_state)){
			$found_state = 1;
		}
	}
	if ($found_state){
		::print_log("[Insteon::Thermo_i2] Received request to set cool setpoint "
			. $p_state . " for device " . $self->get_object_name);
		if (lc($p_state) eq 'cooler'){
			$$self{parent}->cool_setpoint($$self{parent}->get_cool_sp - 1);
		}
		elsif (lc($p_state) eq 'warmer'){
			$$self{parent}->cool_setpoint($$self{parent}->get_cool_sp + 1);
		}
	}
}

sub set_receive {
	my ($self, $p_state) = @_;
	$self->SUPER::set($p_state);
}
1;
=back

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
=cut
