
=head1 NAME

B<Thermostat.pm> - Insteon Thermostat

=head1 DESCRIPTION

Enables support for an Insteon Thermostat.

=head1 SYNOPSIS

In user code:

	$thermostat = new Insteon_Thermostat($myPLM, '12.34.56');
	
Additional i2CS specific objects:
	
	$thermostat_heating = new Insteon_Thermostat($myPLM, '12.34.56:02');
	$thermostat_high_humid = new Insteon_Thermostat($myPLM, '12.34.56:03');
	$thermostat_low_humid = new Insteon_Thermostat($myPLM, '12.34.56:04');
	$thermostat_broadcast = new Insteon_Thermostat($myPLM, '12.34.56:EF');

These devices will not have any states, but are only used for linking purposes.

In items.mht:

	INSTEON_THERMOSTAT, 12.34.56, thermostat, HVAC
	
Additional i2CS specific objects:
	
	INSTEON_THERMOSTAT, 12.34.56:02, thermostat_heating, HVAC
	INSTEON_THERMOSTAT, 12.34.56:03, thermostat_high_humid, HVAC
	INSTEON_THERMOSTAT, 12.34.56:04, thermostat_low_humid, HVAC
	INSTEON_THERMOSTAT, 12.34.56:EF, thermostat_broadcast, HVAC

These devices will not have any states, but are only used for linking purposes.

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

All of the states of the parent object that may be set by MH, you can use tie_event
to link specific actions to these states:
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
   status_change: Heating, Cooling, Dehumidifying, or Humidifying change (i2CS only)
      (call get_status() to get status).

I2CS Broadcast messages:

If a group EF device is defined, MH will receive broadcast changes from the 
thermostat.  When enabled, broadcast messages for changes in setpoint, mode,
temp, and humidity will be sent to MH.  When enabled, there is no reason to 
poll the thermostat, except for possibly at reboot.  To enable simply define
the EF group as described above and run sync links.

Broadcast messages are NOT sent when the heater turns on/off.  Broadcast
message are also NOT sent when the humidity setpoints are exceeded.  Instead,
you must define the heating, high_humid, and low_humid groups and link them
to MH.  (The base group 01 is the cooling group and should always be linked to
MH).  When linked, these groups will send on/off commands to MH when these events
occur.  Alternatively, you can periodically call request_status() to check 
the status of these attributes.

Linking:

I am not sure how or if the i1 device can be linked to other devices.

I2CS devices have 5 controllers, groups 01-04 plus the broadcast group EF.  At the
moment, MH only supports using the thermostat as a controller of another device.
To control another device, simply define it as a scene member of the desired 
thermostat group.  The groups are:

	01 - Cooling - Will send an ON/OFF command when the A/C is turned on/off.
	02 - Heating - Will send an ON/OFF command when the heater is turned on/off.
	03 - Humid High - Will send an ON/OFF command when the humidity exceeds the 
	humid high setpoint.
	04 - Humid Low - Will send an ON/OFF command when the humidity falls below the 
	humid low setpoint.
	EF - Broadcast - Other than MH, I do not know if any other device can 
	respond to these commands.

Tracking Child Objects:

For both, i1 and i2CS devices, optional child objects which track the states of the 
thermostat can be created in user code:
	
   $thermo_temp = new Insteon::Thermo_temp($thermostat);
   $thermo_fan = new Insteon::Thermo_fan($thermostat);
   $thermo_mode = new Insteon::Thermo_mode($thermostat);
   $thermo_setpoint_h = new Insteon::Thermo_setpoint_h($thermostat);
   $thermo_setpoint_c = new Insteon::Thermo_setpoint_c($thermostat);
   $thermo_humidity = new Insteon::Thermo_humidity($thermostat);  #Only available on i2CS devices
   $thermo_status = new Insteon::Thermo_status($thermostat);  #Only available on i2CS devices
   $thermo_humidity_setpoint_h = new Insteon::Thermo_setpoint_humid_h($thermostat);  #Only available on i2CS devices
   $thermo_humidity_setpoint_l = new Insteon::Thermo_setpoint_humid_l($thermostat);  #Only available on i2CS devices


where $thermostat is the parent object to track.  The state of these child objects
will be the state of the various attributes of the thermostat.  This makes the 
display of the various states easier within MH.  The child objects also make it 
easier to change the various states on the thermostat.

see code/examples/Insteon_thermostat.pl for more.

=head1 BUGS

This code has not been tested on older Venstar thermostats, however it is believed
that the basic functionality should work as it did in the old code.

=head1 AUTHOR

Initial Code by:
Gregg Liming <gregg@limings.net>
Brian Warren <brian@7811.net>

Enhanced to i2CS by:
Kevin Robert Keegan <kevin@krkeegan.com>

=head1 TODO

 - Enable Linking of the Thermostat as a Responder - The current design of MH 
   will not create valid links when the thermostat is the responder.  To enable
   this function, a reorganization of the add_link and update_link code at the
   BaseObject level needs to be performed.

=head1 INHERITS

B<Insteon::BaseDevice>

=head1 Methods

=over

=cut

package Insteon::Thermostat;

use strict;
use Insteon::BaseInsteon;

@Insteon::Thermostat::ISA = ('Insteon::BaseDevice');

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

our %message_types = (
    %Insteon::BaseDevice::message_types,
    thermostat_temp_up       => 0x68,
    thermostat_temp_down     => 0x69,
    thermostat_get_zone_info => 0x6a,
    thermostat_control       => 0x6b,
    thermostat_setpoint_cool => 0x6c,
    thermostat_setpoint_heat => 0x6d
);

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;
    my $self = new Insteon::BaseDevice( $p_deviceid, $p_interface );
    bless $self, $class;
    $$self{temp}     = undef;
    $$self{mode}     = undef;
    $$self{fan_mode} = undef;
    $$self{heat_sp}  = undef;
    $$self{cool_sp}  = undef;
    $self->restore_data( 'temp', 'mode', 'fan_mode', 'heat_sp', 'cool_sp' );
    $$self{m_pending_setpoint} = undef;
    $$self{message_types}      = \%message_types;
    $$self{is_responder}       = 0;
    return $self;
}

=item C<poll_mode()>

Causes thermostat to return mode; detected as state change if mode changes

=cut

sub poll_mode {
    my ($self) = @_;
    $$self{_control_action} = "mode";
    my $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, 'thermostat_control',
        '02' );
    $self->_send_cmd($message);
    return;
}

=item C<fan()>

Sets fan to 'on' or 'auto'

=cut

sub fan {
    my ( $self, $state ) = @_;
    $state = lc($state);
    main::print_log("[Insteon::Thermostat] Fan $state")
      if $self->debuglevel( 1, 'insteon' );
    my $fan;
    if ( ( $state eq 'on' ) or ( $state eq 'fan_on' ) ) {
        $fan   = '07';
        $state = 'fan_on';
    }
    elsif ( $state eq 'auto' or $state eq 'off' or $state eq 'fan_auto' ) {
        $fan   = '08';
        $state = 'fan_auto';
    }
    else {
        main::print_log(
            "[Insteon::Thermostat] ERROR: Invalid Fan state: $state");
        return ();
    }
    $self->_send_cmd( $self->simple_message( 'thermostat_control', $fan ) );
}

=item C<cool_setpoint()>

Sets a new cool setpoint.

=cut

sub cool_setpoint {
    my ( $self, $temp ) = @_;
    main::print_log("[Insteon::Thermostat] Cool setpoint -> $temp")
      if $self->debuglevel( 1, 'insteon' );
    if ( $temp !~ /^\d+$/ ) {
        main::print_log(
            "[Insteon::Thermostat] ERROR: cool_setpoint $temp not numeric");
        return;
    }
    $self->_send_cmd(
        $self->simple_message(
            'thermostat_setpoint_cool', sprintf( '%02X', ( $temp * 2 ) )
        )
    );
}

=item C<heat_setpoint()>

Sets a new heat setpoint.

=cut

sub heat_setpoint {
    my ( $self, $temp ) = @_;
    main::print_log("[Insteon::Thermostat] Heat setpoint -> $temp")
      if $self->debuglevel( 1, 'insteon' );
    if ( $temp !~ /^\d+$/ ) {
        main::print_log(
            "[Insteon::Thermostat] ERROR: heat_setpoint $temp not numeric");
        return;
    }
    $self->_send_cmd(
        $self->simple_message(
            'thermostat_setpoint_heat', sprintf( '%02X', ( $temp * 2 ) )
        )
    );
}

=item C<poll_temp()>

Causes thermostat to return temp; detected as state change.

=cut

sub poll_temp {
    my ($self) = @_;
    $$self{_zone_action} = "temp";
    my $message = new Insteon::InsteonMessage( 'insteon_send', $self,
        'thermostat_get_zone_info', '00' );
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
    my $message = new Insteon::InsteonMessage( 'insteon_send', $self,
        'thermostat_get_zone_info', '20' );
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
    my ( $self, $p_state ) = @_;
    if ( $p_state ne $self->get_heat_sp() ) {
        $self->set_receive('heat_setpoint_change');
        $$self{'heat_sp'} = $p_state;
    }
    return $$self{'heat_sp'};
}

sub _cool_sp() {
    my ( $self, $p_state ) = @_;
    if ( $p_state ne $self->get_cool_sp() ) {
        $self->set_receive('cool_setpoint_change');
        $$self{'cool_sp'} = $p_state;
    }
    return $$self{'cool_sp'};
}

sub _fan_mode() {
    my ( $self, $p_state ) = @_;
    if ( $p_state ne $self->get_fan_mode() ) {
        $self->set_receive('fan_mode_change');
        $$self{'fan_mode'} = $p_state;
    }
    return $$self{'fan_mode'};
}

sub _mode() {
    my ( $self, $p_state ) = @_;
    if ( $p_state ne $self->get_mode() ) {
        $self->set_receive('mode_change');
        $$self{'mode'} = $p_state;
    }
    return $$self{'mode'};
}

=item C<get_mode()>

Returns the last mode returned by C<poll_mode()>  I2CS devices will report auto for both auto and program_auto. 

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
    my ( $self, $cmd, $ack_setby, %msg ) = @_;
    my $is_info_request = ( $cmd eq 'thermostat_get_zone_info' ) ? 1 : 0;
    if ($is_info_request) {
        my $val = $msg{extra};
        main::print_log(
            "[Insteon::Thermostat] Processing is_info_request for $cmd with value: $val"
        ) if $self->debuglevel( 1, 'insteon' );
        if ( $$self{_zone_action} eq "temp" ) {
            $val = ( hex $val ) / 2;    # returned value is twice the real value
            if ( exists $$self{'temp'} and ( $$self{'temp'} != $val ) ) {
                $self->set_receive('temp_change');
            }
            $$self{'temp'} = $val;
        }
        elsif ( $$self{_zone_action} eq 'setpoint' ) {
            $val = ( hex $val ) / 2;    # returned value is twice the real value
              # in auto modes, expect direct message with cool_setpoint to follow
            if ( $self->get_mode() eq 'auto' or 'program_auto' ) {
                $self->_heat_sp($val);
                $$self{'m_pending_setpoint'} = 1;
            }
            elsif ( $self->get_mode() eq 'heat' or 'program_heat' ) {
                $self->_heat_sp($val);
                $$self{_zone_action} = undef;
            }
            elsif ( $self->get_mode() eq 'cool' or 'program_cool' ) {
                $self->_cool_sp($val);
                $$self{_zone_action} = undef;
            }
        }
    }
    else    #This was not a thermostat info_request
    {
        #Check if this was a generic info_request
        $is_info_request =
          $self->SUPER::_is_info_request( $cmd, $ack_setby, %msg );
    }
    return $is_info_request;

}

## Unique messages handled first, non-unique sent to SUPER
sub _process_message {
    my ( $self, $p_setby, %msg ) = @_;
    my $clear_message = 0;
    my $pending_cmd =
      ( $$self{_prior_msg} ) ? $$self{_prior_msg}->command : $msg{command};
    my $ack_setby =
      ( ref $$self{m_status_request_pending} )
      ? $$self{m_status_request_pending}
      : $p_setby;
    if (   $msg{is_ack}
        && $self->_is_info_request( $pending_cmd, $ack_setby, %msg ) )
    {
        $clear_message = 1;
        $$self{m_status_request_pending} = 0;
        $self->_process_command_stack(%msg);
    }
    elsif ( $msg{command} eq "thermostat_setpoint_cool" && $msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );
        main::print_log(
            "[Insteon::Thermostat] Received ACK of cool setpoint " . "for "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        $self->_cool_sp( ( hex( $msg{extra} ) / 2 ) );
        $clear_message = 1;
        $self->_process_command_stack(%msg);
    }
    elsif ( $msg{command} eq "thermostat_setpoint_heat" && $msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );
        main::print_log(
            "[Insteon::Thermostat] Received ACK of heat setpoint " . "for "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        $self->_heat_sp( ( hex( $msg{extra} ) / 2 ) );
        $clear_message = 1;
        $self->_process_command_stack(%msg);
    }
    elsif ( $$self{_zone_action} eq 'setpoint' && $$self{m_pending_setpoint} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );

        # we got our cool setpoint in auto mode
        main::print_log(
            "[Insteon::Thermostat] Processing data for $msg{command} with value: $msg{extra}"
        ) if $self->debuglevel( 1, 'insteon' );
        my $val = ( hex $msg{extra} ) / 2;
        $self->_cool_sp($val);
        $$self{m_setpoint_pending} = 0;
        $$self{_zone_action}       = undef;
        $clear_message             = 1;
        $self->_process_command_stack(%msg);
    }
    else {
        $clear_message = $self->SUPER::_process_message( $p_setby, %msg );
    }
    return $clear_message;
}

#Used to update the state of child objects
sub parent_event {
    my ( $self, $p_state ) = @_;
    if ( $p_state eq 'mode_change' ) {
        $$self{child_mode}->set_receive( $self->get_mode() );
    }
    elsif ( $p_state eq 'temp_change' ) {
        $$self{child_temp}->set_receive( $self->get_temp(), $self );
    }
    elsif ( $p_state eq 'heat_setpoint_change' ) {
        $$self{child_setpoint_h}->set_receive( $self->get_heat_sp(), $self );
    }
    elsif ( $p_state eq 'cool_setpoint_change' ) {
        $$self{child_setpoint_c}->set_receive( $self->get_cool_sp(), $self );
    }
    elsif ( $p_state eq 'fan_mode_change' ) {
        $$self{child_fan}->set_receive( $self->get_fan_mode(), $self );
    }
    elsif ( $p_state eq 'humid_change' ) {
        $$self{child_humidity}->set_receive( $$self{humid}, $self );
    }
    elsif ( $p_state eq 'status_change' ) {
        $$self{child_status}->set_receive( $self->get_status(), $self );
    }
    elsif ( $p_state eq 'low_humid_setpoint_change' ) {
        $$self{child_setpoint_humid_l}
          ->set_receive( $self->get_low_humid_sp(), $self );
    }
    elsif ( $p_state eq 'high_humid_setpoint_change' ) {
        $$self{child_setpoint_humid_h}
          ->set_receive( $self->get_high_humid_sp(), $self );
    }
}

# Overload methods we don't use, but would otherwise cause Insteon traffic.
sub request_status { return 0 }

sub level { return 0 }

=back

=head1 NAME

B<Thermo_i1> - Insteon Thermo_I1

=head1 DESCRIPTION

Enables support for Insteon Thermostat version i1.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Insteon::Thermostat>

=head1 Methods

=over

=cut

package Insteon::Thermo_i1;
use strict;

@Insteon::Thermo_i1::ISA = ('Insteon::Thermostat');

=item C<mode()>

Sets system mode to argument: 'off', 'heat', 'cool', 'auto', 'program_heat', 
'program_cool', 'program_auto'.  The 2441TH thermostat does not have program_heat
 or program_cool.

=cut

sub mode {
    my ( $self, $state ) = @_;
    $state = lc($state);
    main::print_log("[Insteon::Thermostat] Mode $state")
      if $self->debuglevel( 1, 'insteon' );
    my $mode;
    if ( $state eq 'off' ) {
        $mode = "09";
    }
    elsif ( $state eq 'heat' ) {
        $mode = "04";
    }
    elsif ( $state eq 'cool' ) {
        $mode = "05";
    }
    elsif ( $state eq 'auto' ) {
        $mode = "06";
    }
    elsif ( $state eq 'program_heat' ) {
        $mode = "0a";
    }
    elsif ( $state eq 'program_cool' ) {
        $mode = "0b";
    }
    elsif ( $state eq 'program_auto' ) {
        $mode = "0c";
    }
    else {
        main::print_log(
            "[Insteon::Thermostat] ERROR: Invalid Mode state: $state");
        return ();
    }
    $$self{_control_action} = "mode";
    $self->_send_cmd( $self->simple_message( 'thermostat_control', $mode ) );
}

sub _is_info_request {
    my ( $self, $cmd, $ack_setby, %msg ) = @_;
    my $is_info_request;
    if ( $cmd eq 'thermostat_control' && $$self{_control_action} eq "mode" ) {
        my $val = $msg{extra};
        main::print_log(
            "[Insteon::Thermo_i1] Processing is_info_request for $cmd with value: $val"
        ) if $self->debuglevel( 1, 'insteon' );
        if ( $val eq '00' ) {
            $self->_mode('off');
        }
        elsif ( $val eq '01' ) {
            $self->_mode('heat');
        }
        elsif ( $val eq '02' ) {
            $self->_mode('cool');
        }
        elsif ( $val eq '03' ) {
            $self->_mode('auto');
        }
        elsif ( $val eq '04' ) {
            $self->_fan_mode('fan_on');
        }
        elsif ( $val eq '05' ) {
            $self->_mode('program_auto');
        }
        elsif ( $val eq '06' ) {
            $self->_mode('program_heat');
        }
        elsif ( $val eq '07' ) {
            $self->_mode('program_cool');
        }
        elsif ( $val eq '08' ) {
            $self->_fan_mode('fan_auto');
        }
        $$self{_control_action} = undef;
        $is_info_request = 1;
    }
    else    #This was not a thermo_1 info_request
    {
        #Check if this was a generic info_request
        $is_info_request =
          $self->SUPER::_is_info_request( $cmd, $ack_setby, %msg );
    }
    return $is_info_request;
}

## Creates a simple Standard Message
sub simple_message {
    my ( $self, $type, $extra ) = @_;
    my $message;
    $message =
      new Insteon::InsteonMessage( 'insteon_send', $self, $type, $extra );
    return $message;
}

=back

=head1 NAME

B<Thermo_i2> - Insteon Thermo_i2

=head1 DESCRIPTION

Enables support for Insteon Thermostat version i2.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Insteon::Thermostat>

=head1 Methods

=over

=cut

package Insteon::Thermo_i2CS;
use strict;

@Insteon::Thermo_i2CS::ISA =
  ( 'Insteon::Thermostat', 'Insteon::MultigroupDevice' );

our %message_types = (
    %Insteon::Thermostat::message_types,
    extended_set_get => 0x2e,
    status_temp      => 0x6e,
    status_humid     => 0x6f,
    status_mode      => 0x70,
    status_cool      => 0x71,
    status_heat      => 0x72
);

sub init {
    my ($self) = @_;
    $$self{message_types} = \%message_types;

    #Set saved state unique to i2CS devices
    $self->restore_data(
        'humid',         'cooling',       'heating', 'humidifying',
        'dehumidifying', 'high_humid_sp', 'low_humid_sp'
    );
    if ( $self->group eq '01' ) {
        $self->tie_event('$object->_cooling("$state")');
    }
    elsif ( $self->group eq '02' ) {
        $self->tie_event('$object->_heating("$state")');
    }
    elsif ( $self->group eq '03' ) {
        $self->tie_event('$object->_dehumidifying("$state")');
    }
    elsif ( $self->group eq '04' ) {
        $self->tie_event('$object->_humidifying("$state")');
    }
}

=item C<derive_link_state([state])>

Overrides routine in BaseObject. Takes state and checks to see if it is a valid
state for the object.  Returns state if valid, otherwise returns __.

=cut

sub derive_link_state {
    my ( $self, $p_state ) = @_;
    my $link_state;
    if ( $self->group eq '01' ) {
        $link_state = 'off';    #default to off if bad state
        my @allowed_states = (
            'on',                        'off',
            'temp_change',               'status_change',
            'humid_change',              'high_humid_setpoint_change',
            'low_humid_setpoint_change', 'heat_setpoint_change',
            'cool_setpoint_change',      'fan_mode_change',
            'mode_change'
        );
        if ( grep( /$p_state/i, @allowed_states ) ) {
            $link_state = $p_state;
        }
    }
    else {
        #for all other objects use BaseObject routine.
        $link_state = $self->Insteon::BaseObject::derive_link_state($p_state);
    }
    return $link_state;
}

sub sync_links {
    my ( $self, $audit_mode, $callback, $failure_callback ) = @_;
    my $dev_id = $self->device_id();
    my $bcast_obj = Insteon::get_object( $self->device_id(), 'EF' );
    if ( !$audit_mode && ref $bcast_obj && $self->is_root ) {

        #Make sure thermostat is set to broadcast changes
        ::print_log(
            "[Insteon::Thermo_i2CS] (sync_links) Enabling thermostat broadcast setting."
        ) unless $audit_mode;
        my $extra = "000008";
        my $message = $self->simple_message( 'extended_set_get', $extra );
        $$self{_ext_set_get_action} = 'set';
        $self->_send_cmd($message);
    }

    # Call the main sync_links code
    return $self->SUPER::sync_links( $audit_mode, $callback,
        $failure_callback );
}

=item C<_poll_simple()>

Requests the status of all Thermostat data points (temp, fan, mode ...) in a single
request.  Called by C<request_status>, you likely don't need to call this directly
Only available for I2CS devices.

=cut

sub _poll_simple {
    my ( $self, $success_callback, $failure_callback ) = @_;
    my $extra = "02";
    my $message = $self->simple_message( 'extended_set_get', $extra );
    $$message{add_crc16} = 1;
    $message->failure_callback($failure_callback);
    $message->success_callback($success_callback);
    $self->_send_cmd($message);
}

=item C<get_status()>

Returns a text string describing the current status of the thermostat. May include
a combination of "Heating; Cooling; Dehumidifying; Humidifying; or Off." Only
available for I2CS devices.

=cut

sub get_status() {
    my ($self) = @_;
    my $root   = $self->get_root();
    my $output = "";
    $output .= "Heating, "       if ( $$root{heating} eq 'on' );
    $output .= "Cooling, "       if ( $$root{cooling} eq 'on' );
    $output .= "Dehumidifying, " if ( $$root{dehumidifying} eq 'on' );
    $output .= "Humidifying"     if ( $$root{humidifying} eq 'on' );
    $output = 'Off' if ( $output eq '' );
    return $output;
}

=item C<print_status()>

Prints the currently known status to the log as a text string.

=cut

sub print_status() {
    my ($self) = @_;
    my $root = $self->get_root();
    my $output =
        "[Insteon:Thermo_i2CS] The status of "
      . $root->get_object_name
      . " is:\n";
    $output .= "Mode: ";
    $output .= $root->get_mode();
    $output .= "; Status: ";
    my $output_status = '';
    $output_status .= "Heating, "       if ( $$root{heating} eq 'on' );
    $output_status .= "Cooling, "       if ( $$root{cooling} eq 'on' );
    $output_status .= "Dehumidifying, " if ( $$root{dehumidifying} eq 'on' );
    $output_status .= "Humidifying"     if ( $$root{humidifying} eq 'on' );
    $output_status .= 'Off'             if ( $output_status eq '' );
    $output        .= $output_status;
    $output        .= "; Temp: ";
    $output        .= $root->get_temp();
    $output        .= "; Humid: ";
    $output        .= $root->get_humid();
    $output        .= "; Heat SP: ";
    $output        .= $root->get_heat_sp();
    $output        .= "; Cool SP: ";
    $output        .= $root->get_cool_sp();
    $output        .= "; High Humid SP: ";
    $output .= $root->get_high_humid_sp();
    $output .= "; Low Humid SP: ";
    $output .= $root->get_low_humid_sp();
    ::print_log($output);
}

=item C<get_humid()>

Returns the current humidity at the thermostat. 

=cut

sub get_humid() {
    my ($self) = @_;
    return $$self{'humid'};
}

sub request_status {
    my ($self) = @_;
    $self = $self->get_root();
    my $self_name = $self->get_object_name;
    my $failure_callback =
      "::print_log('[Insteon:Thermo_i2CS] ERROR: Failed to get status for $self_name.');";
    my $print_callback = $self_name . "->print_status";
    my $humid_callback = $self_name
      . "->_poll_humid_setpoints(\'$print_callback\', \"$failure_callback\")";
    $self->_poll_simple( $humid_callback, $failure_callback );
}

sub _process_message {
    my ( $self, $p_setby, %msg ) = @_;
    my $clear_message = 0;
    my $pending_cmd =
      ( $$self{_prior_msg} ) ? $$self{_prior_msg}->command : $msg{command};
    my $ack_setby =
      ( ref $$self{m_status_request_pending} )
      ? $$self{m_status_request_pending}
      : $p_setby;
    if (   $msg{is_ack}
        && $self->_is_info_request( $pending_cmd, $ack_setby, %msg ) )
    {
        $clear_message = 1;
        $$self{m_status_request_pending} = 0;
        $self->_process_command_stack(%msg);
    }
    elsif ( $msg{command} eq "extended_set_get" && $msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );

        #If this was a get request don't clear until data packet received
        main::print_log(
            "[Insteon::Thermo_i2CS] Extended Set/Get ACK Received for "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        if ( $$self{_ext_set_get_action} eq 'set' ) {
            main::print_log("[Insteon::Thermo_i2CS] Clearing active message")
              if $self->debuglevel( 1, 'insteon' );
            $clear_message = 1;
            $$self{_ext_set_get_action} = undef;
            $self->_process_command_stack(%msg);
        }
        elsif ( $$self{_ext_set_get_action} eq 'set_high_humid' ) {
            main::print_log(
                    "[Insteon::Thermostat] Received ACK of high humid setpoint "
                  . "for "
                  . $self->get_object_name )
              if $self->debuglevel( 1, 'insteon' );
            $self->_high_humid_sp( $$self{_high_humid_pending} );
            $clear_message              = 1;
            $$self{_ext_set_get_action} = undef;
            $$self{_high_humid_pending} = undef;
            $self->_process_command_stack(%msg);
        }
        elsif ( $$self{_ext_set_get_action} eq 'set_low_humid' ) {
            main::print_log(
                    "[Insteon::Thermostat] Received ACK of low humid setpoint "
                  . "for "
                  . $self->get_object_name )
              if $self->debuglevel( 1, 'insteon' );
            $self->_low_humid_sp( $$self{_low_humid_pending} );
            $clear_message              = 1;
            $$self{_ext_set_get_action} = undef;
            $$self{_low_humid_pending}  = undef;
            $self->_process_command_stack(%msg);
        }
    }
    elsif ( $msg{command} eq "extended_set_get" && $msg{is_extended} ) {
        if ( substr( $msg{extra}, 0, 4 ) eq "0201" ) {
            $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );
            main::print_log( "[Insteon::Thermo_i2CS] Extended Set/Get Data "
                  . "Received for "
                  . $self->get_object_name )
              if $self->debuglevel( 1, 'insteon' );

            #0 = 2				#14 = Cool SP
            #2 = 1				#16 = humidity
            #3 = day			#18 = temp in Celsius High byte
            #6 = hour			#20 = temp low byte
            #8 = minute			#22 = status flag
            #10 = second			#24 = Heat SP
            #12 = Sys_mode * 16 + Fan_mode
            my $mode = hex( substr( $msg{extra}, 12, 2 ) );
            my $fan_mode = ( $mode % 16 );
            $self->dec_mode( ( $mode - $fan_mode ) / 16 );
            $self->dec_fan($fan_mode);
            $self->hex_cool( substr( $msg{extra}, 14, 2 ) );
            $self->hex_humid( substr( $msg{extra}, 16, 2 ) );
            $self->hex_long_temp( substr( $msg{extra}, 18, 4 ) );
            $self->hex_status( substr( $msg{extra}, 22, 2 ) );
            $self->hex_heat( substr( $msg{extra}, 24, 2 ) );
            $clear_message = 1;
            $self->_process_command_stack(%msg);

            if ( $$self{sync_time} ) {

                #This poll was requested as part of sync_time
                my $message;
                my $extra;
                my @time_array = localtime(time);
                my @req_items  = (
                    $time_array[6], $time_array[2],
                    $time_array[1], $time_array[0]
                );
                my $time_str = '';
                foreach (@req_items) {
                    $time_str .= sprintf( "%02x", $_ );
                }
                $extra =
                  $extra . "0202" . $time_str . substr( $msg{extra}, 12, 18 );

                #This will include the prior CRC16 message, but it will
                #get overwritten with the correct value in Message.pm
                $message =
                  new Insteon::InsteonMessage( 'insteon_ext_send', $self,
                    'extended_set_get', $extra );
                $$message{add_crc16}        = 1;
                $$self{_ext_set_get_action} = 'set';
                $$self{sync_time}           = undef;
                $self->_send_cmd($message);
            }
        }
        elsif ( substr( $msg{extra}, 0, 8 ) eq "00000101" ) {
            $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );

            #0 = 00				#14 = Cool SP
            #2 = 00				#16 = Heat SP
            #4 = 01	Response		#18 = RF Offset
            #6 = 01	Data Set 2		#20 = Energy Saving Setback
            #8 = humid low			#22 = External TempOffset
            #10 = humid high		#24 = 1 = Status Report Enabled
            #12 = firmware			#26 = 1 = External Power On
            #28 = 1 = Int, 2=Ext Temp
            $self->_high_humid_sp( hex( substr( $msg{extra}, 8, 2 ) ) );
            $self->_low_humid_sp( hex( substr( $msg{extra}, 10, 2 ) ) );

            #Humidifying and Dehumidifying are only reported by the
            #thermostat as scene-commands.  When a user calls
            #request_status, we manually check the values and update
            #as appropriate
            if ( $self->get_high_humid_sp > $self->get_humid ) {
                $self->_dehumidifying('off');
            }
            else {
                $self->_dehumidifying('on');
            }
            if ( $self->get_low_humid_sp < $self->get_humid ) {
                $self->_humidifying('off');
            }
            else {
                $self->_humidifying('on');
            }
            $clear_message = 1;
            $self->_process_command_stack(%msg);
        }
        else {
            main::print_log( "[Insteon::Thermo_i2CS] WARN: Unknown Extended "
                  . "Set/Get Data Received for "
                  . $self->get_object_name )
              if $self->debuglevel( 1, 'insteon' );
        }
    }
    elsif ( $msg{command} eq "status_temp" && !$msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );
        main::print_log(
            "[Insteon::Thermo_i2CS] Received Temp Change Message " . "from "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        $self->hex_short_temp( $msg{extra} );
    }
    elsif ( $msg{command} eq "status_mode" && !$msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );
        main::print_log(
            "[Insteon::Thermo_i2CS] Received Mode Change Message " . "from "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        $self->status_mode( $msg{extra} );
    }
    elsif ( $msg{command} eq "status_cool" && !$msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );
        main::print_log(
                "[Insteon::Thermo_i2CS] Received Cool Setpoint Change Message "
              . "from "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        $self->hex_cool( $msg{extra} );
    }
    elsif ( $msg{command} eq "status_humid" && !$msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );
        main::print_log(
            "[Insteon::Thermo_i2CS] Received Humidity Change Message " . "from "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        $self->hex_humid( $msg{extra} );
    }
    elsif ( $msg{command} eq "status_heat" && !$msg{is_ack} ) {
        $self->default_hop_count( $msg{maxhops} - $msg{hopsleft} );
        main::print_log(
                "[Insteon::Thermo_i2CS] Received Heat Setpoint Change Message "
              . "from "
              . $self->get_object_name )
          if $self->debuglevel( 1, 'insteon' );
        $self->hex_heat( $msg{extra} );
    }
    else {
        $clear_message = $self->SUPER::_process_message( $p_setby, %msg );
    }
    return $clear_message;
}

sub _is_info_request {
    my ( $self, $cmd, $ack_setby, %msg ) = @_;
    my $is_info_request;
    if ( $cmd eq 'thermostat_control' && $$self{_control_action} eq "mode" ) {
        my $val = $msg{extra};
        main::print_log(
            "[Insteon::Thermo_i2CS] Processing is_info_request for $cmd with value: $val"
        ) if $self->debuglevel( 1, 'insteon' );
        if ( $val eq '09' ) {
            $self->_mode('Off');
        }
        elsif ( $val eq '04' ) {
            $self->_mode('Heat');
        }
        elsif ( $val eq '05' ) {
            $self->_mode('Cool');
        }
        elsif ( $val eq '06' ) {
            $self->_mode('Auto');
        }
        elsif ( $val eq '0a' ) {
            $self->_mode('Program');
        }
        $$self{_control_action} = undef;
        $is_info_request = 1;
    }
    else    #This was not a thermo_i2CS info_request
    {
        #Check if this was a generic info_request
        $is_info_request =
          $self->SUPER::_is_info_request( $cmd, $ack_setby, %msg );
    }
    return $is_info_request;
}

sub dec_mode {
    my ( $self, $dec_mode ) = @_;
    my $mode;
    $mode = 'Off'     if ( $dec_mode == 0 );
    $mode = 'Auto'    if ( $dec_mode == 1 );
    $mode = 'Heat'    if ( $dec_mode == 2 );
    $mode = 'Cool'    if ( $dec_mode == 3 );
    $mode = 'Program' if ( $dec_mode == 4 );
    $self->_mode($mode);
}

sub status_mode {
    my ( $self, $status_mode ) = @_;
    my $mode;
    my $conv_mode = ( hex($status_mode) % 16 );
    $mode = 'Off'     if ( $conv_mode == 0 );
    $mode = 'Heat'    if ( $conv_mode == 1 );
    $mode = 'Cool'    if ( $conv_mode == 2 );
    $mode = 'Auto'    if ( $conv_mode == 3 );
    $mode = 'Program' if ( $conv_mode == 4 );
    $self->_mode($mode);
    my $fan_mode;
    $fan_mode = ( hex($status_mode) >= 16 ) ? 'Always On' : 'Auto';
    $self->_fan_mode($fan_mode);
}

sub dec_fan {
    my ( $self, $dec_fan ) = @_;
    my $fan;
    $fan = 'Auto'      if ( $dec_fan == 0 );
    $fan = 'Always On' if ( $dec_fan == 1 );
    $self->_fan_mode($fan);
}

sub hex_cool {
    my ( $self, $hex_cool ) = @_;
    $self->_cool_sp( hex($hex_cool) );
}

sub hex_humid {
    my ( $self, $hex_humid ) = @_;
    $self->_humid( hex($hex_humid) );
}

sub hex_long_temp {
    my ( $self, $hex_temp ) = @_;
    my $temp_cel = ( hex($hex_temp) / 10 );
    ## ATM I am going to assume farenheit b/c that is what I have
    # in future, can pull setting bit from thermometer
    # Extra .5 since sprintf doesn't round
    $$self{temp} = sprintf( "%d", ( ( $temp_cel * 9 ) / 5 + 32 + .5 ) );
    $self->set_receive('temp_change');
}

sub hex_short_temp {
    my ( $self, $hex_temp ) = @_;
    $$self{temp} = ( hex($hex_temp) / 2 );
    $self->set_receive('temp_change');
}

sub hex_status {
    my ( $self, $hex_status ) = @_;

    # Bit 	Value	Bit	Value
    # 0	Cooling	4	1??
    # 1	Heating	5	0??
    # 2	0??	6	1??
    # 3	0??	7	0??
    # Sadly, dehumidifying and humidifying do not appear to be reported here
    my ( $pre_cooling, $pre_heating ) = ( $$self{cooling}, $$self{heating} );
    $$self{cooling} = ( $hex_status & 0x01 ) ? 'on' : 'off';
    $$self{heating} = ( $hex_status & 0x02 ) ? 'on' : 'off';
    if (   ( $pre_cooling ne $$self{cooling} )
        || ( $pre_heating ne $$self{heating} ) )
    {
        $self->set_receive('status_change');
    }
}

sub hex_heat {
    my ( $self, $hex_heat ) = @_;
    $self->_heat_sp( hex($hex_heat) );
}

sub _humid {
    my ( $self, $p_state ) = @_;
    if ( $p_state ne $$self{humid} ) {
        $$self{humid} = $p_state;
        $self->set_receive('humid_change');
    }
    return $$self{humid};
}

sub _cooling {
    my ( $self, $p_state ) = @_;
    my $root = $self->get_root();

    #The root object state contains both the state of the cooling object
    #as well as the general bucket for all status messages.
    if ( grep( /$p_state/i, @{ [ 'on', 'off' ] } ) ) {
        $$root{cooling} = $p_state;
        $root->set_receive('status_change');
    }
    return $$root{cooling};
}

sub _heating {
    my ( $self, $p_state ) = @_;
    my $root = $self->get_root();
    $$root{heating} = $p_state;
    $root->set_receive('status_change');
    return $$root{heating};
}

sub _dehumidifying {
    my ( $self, $p_state ) = @_;
    my $root = $self->get_root();
    if ( $p_state ne $$root{dehumidifying} ) {
        $$root{dehumidifying} = $p_state;
        $root->set_receive('status_change');
    }
    return $$root{dehumidifying};
}

sub _humidifying {
    my ( $self, $p_state ) = @_;
    my $root = $self->get_root();
    if ( $p_state ne $$root{humidifying} ) {
        $$root{humidifying} = $p_state;
        $root->set_receive('status_change');
    }
    return $$root{humidifying};
}

sub _high_humid_sp {
    my ( $self, $p_state ) = @_;
    if ( $p_state ne $$self{high_humid_sp} ) {
        $$self{high_humid_sp} = $p_state;
        $self->set_receive('high_humid_setpoint_change');
    }
    return $$self{high_humid_sp};
}

sub _low_humid_sp {
    my ( $self, $p_state ) = @_;
    if ( $p_state ne $$self{low_humid_sp} ) {
        $$self{low_humid_sp} = $p_state;
        $self->set_receive('low_humid_setpoint_change');
    }
    return $$self{low_humid_sp};
}

=item C<get_high_humid_sp()>

Returns the current high humidity setpoint. 

=cut

sub get_high_humid_sp {
    my ($self) = @_;
    return $$self{high_humid_sp};
}

=item C<get_low_humid_sp()>

Returns the current low humidity setpoint. 

=cut

sub get_low_humid_sp {
    my ($self) = @_;
    return $$self{low_humid_sp};
}

=item C<mode()>

Sets system mode to argument: 'off', 'heat', 'cool', 'auto', 'program_heat', 
'program_cool', 'program_auto'.  The 2441TH thermostat does not have program_heat
 or program_cool.

=cut

sub mode {
    my ( $self, $state ) = @_;
    $state = lc($state);
    main::print_log("[Insteon::Thermostat] Mode $state")
      if $self->debuglevel( 1, 'insteon' );
    my $mode;
    if ( $state eq 'off' ) {
        $mode = "09";
    }
    elsif ( $state eq 'heat' ) {
        $mode = "04";
    }
    elsif ( $state eq 'cool' ) {
        $mode = "05";
    }
    elsif ( $state eq 'auto' ) {
        $mode = "06";
    }
    elsif ( $state eq 'program' ) {
        $mode = "0a" if $self->_aldb->isa('Insteon::ALDB_i2');
    }
    else {
        main::print_log(
            "[Insteon::Thermostat] ERROR: Invalid Mode state: $state");
        return ();
    }
    $$self{_control_action} = "mode";
    $self->_send_cmd( $self->simple_message( 'thermostat_control', $mode ) );
}

## Creates an Extended Message
sub simple_message {
    my ( $self, $type, $extra ) = @_;
    my $message;
    $extra = $extra . "0000000000000000000000000000";
    $message =
      new Insteon::InsteonMessage( 'insteon_ext_send', $self, $type, $extra );
    return $message;
}

=item C<sync_time()>

Sets the data and time of the thermostat based on the time of the MH server.

=cut

sub sync_time {
    my ($self) = @_;

    #In order to set the time, we need to know the current value of other data
    #points such as mode and what not becuase we can't just set the time without
    #setting these variables too.
    $$self{sync_time} = 1;
    $self->_poll_simple();
}

=item C<high_humid_setpoint()>

Sets the high humidity setpoint.

=cut

sub high_humid_setpoint {
    my ( $self, $value ) = @_;
    main::print_log(
        "[Insteon::Thermo_i2CS] Setting high humid setpoint -> $value")
      if $self->debuglevel( 1, 'insteon' );
    if ( $value !~ /^\d+$/ ) {
        main::print_log(
            "[Insteon::Thermo_i2CS] ERROR: Setpoint $value not numeric");
        return;
    }
    if ( $value > 99 || $value < 1 ) {
        main::print_log(
            "[Insteon::Thermo_i2CS] ERROR: Setpoint must be between 1-99, not $value"
        );
        return;
    }
    my $extra = "00000B" . sprintf( "%02x", $value );
    $extra .= '0' x ( 30 - length $extra );
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $self,
        'extended_set_get', $extra );
    $$self{_ext_set_get_action} = 'set_high_humid';
    $$self{_high_humid_pending} = $value;
    $self->_send_cmd($message);
}

=item C<low_humid_setpoint()>

Sets the low humidity setpoint.

=cut

sub low_humid_setpoint {
    my ( $self, $value ) = @_;
    main::print_log(
        "[Insteon::Thermo_i2CS] Setting low humid setpoint -> $value")
      if $self->debuglevel( 1, 'insteon' );
    if ( $value !~ /^\d+$/ ) {
        main::print_log(
            "[Insteon::Thermo_i2CS] ERROR: Setpoint $value not numeric");
        return;
    }
    if ( $value > 99 || $value < 1 ) {
        main::print_log(
            "[Insteon::Thermo_i2CS] ERROR: Setpoint must be between 1-99, not $value"
        );
        return;
    }
    my $extra = "00000C" . sprintf( "%02x", $value );
    $extra .= '0' x ( 30 - length $extra );
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $self,
        'extended_set_get', $extra );
    $$self{_ext_set_get_action} = 'set_low_humid';
    $$self{_low_humid_pending}  = $value;
    $self->_send_cmd($message);
}

=item C<_poll_humid_setpoints()>

Retreives and prints the current humidity high and low setpoints.  Only available for I2CS devices.

=cut

sub _poll_humid_setpoints {
    my ( $self, $success_callback, $failure_callback ) = @_;
    my $extra = "00000001";
    $extra .= '0' x ( 30 - length $extra );
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $self,
        'extended_set_get', $extra );
    $$self{_ext_set_get_action} = 'get';
    $message->failure_callback($failure_callback);
    $message->success_callback($success_callback);
    $self->_send_cmd($message);
}

=item C<get_voice_cmds>

Returns a hash of voice commands where the key is the voice command name and the
value is the perl code to run when the voice command name is called.

Higher classes which inherit this object may add to this list of voice commands by
redefining this routine while inheriting this routine using the SUPER function.

This routine is called by L<Insteon::generate_voice_commands> to generate the
necessary voice commands.

=cut 

sub get_voice_cmds {
    my ($self)      = @_;
    my $object_name = $self->get_object_name;
    my %voice_cmds  = ( %{ $self->SUPER::get_voice_cmds } );
    if ( $self->is_root ) {
        %voice_cmds = (
            %{ $self->SUPER::get_voice_cmds },
            'sync time'                   => "$object_name->sync_time()",
            'sync all device links'       => "$object_name->sync_all_links()",
            'AUDIT sync all device links' => "$object_name->sync_all_links(1)"
        );
    }
    return \%voice_cmds;
}

=back

=head1 NAME

B<Thermo_mode> - Insteon Thermo_mode

=head1 DESCRIPTION

A child object that contains the mode state of the thermostat.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Thermo_mode;
use strict;

@Insteon::Thermo_mode::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    @{ $$self{states} } = ( 'Off', 'Heat', 'Cool', 'Auto', 'Program' );
    $$self{parent}{child_mode} = $self;
    $$self{parent}
      ->tie_event( '$object->parent_event("$state")', "mode_change" );
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $found_state = 0;
    foreach my $test_state ( @{ $$self{states} } ) {
        if ( lc($test_state) eq lc($p_state) ) {
            $found_state = 1;
        }
    }
    if ($found_state) {
        ::print_log( "[Insteon::Thermo_i2CS] Received set mode request to "
              . $p_state
              . " for device "
              . $self->get_object_name );
        $$self{parent}->mode($p_state);
    }
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head1 NAME

B<Thermo_fan> - Insteon Thermo_fan

=head1 DESCRIPTION

A child object that contains the fan state of the thermostat.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Thermo_fan;
use strict;

@Insteon::Thermo_fan::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    @{ $$self{states} } = ( 'Auto', 'On' );
    $$self{parent}{child_fan} = $self;
    $$self{parent}
      ->tie_event( '$object->parent_event("$state")', "fan_mode_change" );
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $found_state = 0;
    foreach my $test_state ( @{ $$self{states} } ) {
        if ( lc($test_state) eq lc($p_state) ) {
            $found_state = 1;
        }
    }
    if ($found_state) {
        ::print_log( "[Insteon::Thermo_i2CS] Received set fan to "
              . $p_state
              . " for device "
              . $self->get_object_name );
        $$self{parent}->fan($p_state);
    }
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head1 NAME

B<Thermo_temp> - Insteon Thermo_temp

=head1 DESCRIPTION

A child object that contains the ambient temperature of the thermostat.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Thermo_temp;
use strict;

@Insteon::Thermo_temp::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    $$self{parent}{child_temp} = $self;
    $$self{parent}
      ->tie_event( '$object->parent_event("$state")', "temp_change" );
    return $self;
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head1 NAME

B<Thermo_humidity> - Insteon Thermo_humidity

=head1 DESCRIPTION

A child object that contains the ambient humidity of the thermostat.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Thermo_humidity;
use strict;

@Insteon::Thermo_humidity::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    $$self{parent}{child_humidity} = $self;
    $$self{parent}
      ->tie_event( '$object->parent_event("$state")', "humid_change" );
    return $self;
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head1 NAME

B<Thermo_setpoint_h> - Insteon Thermo_setpoint_h

=head1 DESCRIPTION

A child object that contains the heat setpoint of the thermostat.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Thermo_setpoint_h;
use strict;

@Insteon::Thermo_setpoint_h::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    @{ $$self{states} } = ( 'Cooler', 'Warmer' );
    $$self{parent}{child_setpoint_h} = $self;
    $$self{parent}
      ->tie_event( '$object->parent_event("$state")', "heat_setpoint_change" );
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $found_state = 0;
    foreach my $test_state ( @{ $$self{states} } ) {
        if ( lc($test_state) eq lc($p_state) ) {
            $found_state = 1;
        }
    }
    if ($found_state) {
        ::print_log(
                "[Insteon::Thermo_i2CS] Received request to set heat setpoint "
              . $p_state
              . " for device "
              . $self->get_object_name );
        if ( lc($p_state) eq 'cooler' ) {
            $$self{parent}->heat_setpoint( $$self{parent}->get_heat_sp - 1 );
        }
        elsif ( lc($p_state) eq 'warmer' ) {
            $$self{parent}->heat_setpoint( $$self{parent}->get_heat_sp + 1 );
        }
    }
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head1 NAME

B<Thermo_setpoint_c> - Insteon Thermo_setpoint_c

=head1 DESCRIPTION

A child object that contains the cool setpoint of the thermostat.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Thermo_setpoint_c;
use strict;

@Insteon::Thermo_setpoint_c::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    @{ $$self{states} } = ( 'Cooler', 'Warmer' );
    $$self{parent}{child_setpoint_c} = $self;
    $$self{parent}
      ->tie_event( '$object->parent_event("$state")', "cool_setpoint_change" );
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $found_state = 0;
    foreach my $test_state ( @{ $$self{states} } ) {
        if ( lc($test_state) eq lc($p_state) ) {
            $found_state = 1;
        }
    }
    if ($found_state) {
        ::print_log(
                "[Insteon::Thermo_i2CS] Received request to set cool setpoint "
              . $p_state
              . " for device "
              . $self->get_object_name );
        if ( lc($p_state) eq 'cooler' ) {
            $$self{parent}->cool_setpoint( $$self{parent}->get_cool_sp - 1 );
        }
        elsif ( lc($p_state) eq 'warmer' ) {
            $$self{parent}->cool_setpoint( $$self{parent}->get_cool_sp + 1 );
        }
    }
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head1 NAME

B<Thermo_status> - Insteon Thermo_status

=head1 DESCRIPTION

A child object that contains the status (heating, cooling, ...) state of the
thermostat.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Thermo_status;
use strict;

@Insteon::Thermo_status::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    $$self{parent}{child_status} = $self;
    $$self{parent}
      ->tie_event( '$object->parent_event("$state")', "status_change" );
    return $self;
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head1 NAME

B<Thermo_setpoint_humid_h> - Insteon Thermo_humid_h

=head1 DESCRIPTION

A child object that contains the high numidity setpoint of the thermostat.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Thermo_setpoint_humid_h;
use strict;

@Insteon::Thermo_setpoint_humid_h::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    @{ $$self{states} } = ( 'Lower', 'Higher' );
    $$self{parent}{child_setpoint_humid_h} = $self;
    $$self{parent}->tie_event( '$object->parent_event("$state")',
        "high_humid_setpoint_change" );
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $found_state = 0;
    foreach my $test_state ( @{ $$self{states} } ) {
        if ( lc($test_state) eq lc($p_state) ) {
            $found_state = 1;
        }
    }
    if ($found_state) {
        ::print_log(
            "[Insteon::Thermo_i2CS] Received request to set high humidity setpoint to "
              . $p_state
              . " for device "
              . $self->get_object_name );
        if ( lc($p_state) eq 'lower' ) {
            $$self{parent}
              ->high_humid_setpoint( $$self{parent}->get_high_humid_sp - 1 );
        }
        elsif ( lc($p_state) eq 'higher' ) {
            $$self{parent}
              ->high_humid_setpoint( $$self{parent}->get_high_humid_sp + 1 );
        }
    }
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head1 NAME

B<Thermo_humid_l> - Insteon Thermo_humid_l

=head1 DESCRIPTION

A child object that contains the low humidity setpoint of the thermostat.

=head1 SYNOPSIS

=head1 AUTHOR

Kevin Robert Keegan <kevin@krkeegan.com>

=head1 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::Thermo_setpoint_humid_l;
use strict;

@Insteon::Thermo_setpoint_humid_l::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    @{ $$self{states} } = ( 'Lower', 'Higher' );
    $$self{parent}{child_setpoint_humid_l} = $self;
    $$self{parent}->tie_event( '$object->parent_event("$state")',
        "low_humid_setpoint_change" );
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $found_state = 0;
    foreach my $test_state ( @{ $$self{states} } ) {
        if ( lc($test_state) eq lc($p_state) ) {
            $found_state = 1;
        }
    }
    if ($found_state) {
        ::print_log(
            "[Insteon::Thermo_i2CS] Received request to set low humidity setpoint to "
              . $p_state
              . " for device "
              . $self->get_object_name );
        if ( lc($p_state) eq 'lower' ) {
            $$self{parent}
              ->low_humid_setpoint( $$self{parent}->get_low_humid_sp - 1 );
        }
        elsif ( lc($p_state) eq 'higher' ) {
            $$self{parent}
              ->low_humid_setpoint( $$self{parent}->get_low_humid_sp + 1 );
        }
    }
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

1;

=back

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
=cut
