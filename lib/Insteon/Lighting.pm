
=head1 B<Insteon::BaseLight>

=head2 DESCRIPTION

A generic base class for all Insteon lighting objects.

=head2 INHERITS

L<Insteon::BaseDevice|Insteon::BaseInsteon/Insteon::BaseDevice>

=head2 METHODS

=over

=cut

package Insteon::BaseLight;

use strict;
use Insteon::BaseInsteon;

@Insteon::BaseLight::ISA = ('Insteon::BaseDevice');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::BaseDevice( $p_deviceid, $p_interface );
    bless $self, $class;

    # include very basic states; off first so web interface up/down works
    $self->set_states( 'off', 'on' );

    return $self;
}

=item C<level(p_level)>

Takes the p_level, and stores it as a numeric level in memory.

=cut

sub level {
    my ( $self, $p_level ) = @_;
    if ( defined $p_level ) {
        my $level = 100;
        if ( $p_level eq 'off' ) {
            $level = 0;
        }
        $$self{level} = $level;
    }
    return $$self{level};

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
    my %voice_cmds  = (
        %{ $self->SUPER::get_voice_cmds },
        'on'  => "$object_name->set(\"on\")",
        'off' => "$object_name->set(\"off\")"
    );
    return \%voice_cmds;
}

=back

=head2 AUTHOR

Gregg Limming 

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::DimmableLight>

=head2 DESCRIPTION

A generic base class for all dimmable Insteon lighting objects.

=head2 INHERITS

L<Insteon::BaseLight|Insteon::Lighting/Insteon::BaseLight>

=head2 METHODS

=over

=cut

package Insteon::DimmableLight;

use strict;
use Insteon::BaseInsteon;

@Insteon::DimmableLight::ISA = ('Insteon::BaseLight');

my %message_types = (
    %SUPER::message_types,
    bright => 0x15,
    dim    => 0x16
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
    '0b' => 90,
    '0c' => 60,
    '0d' => 47,
    '0e' => 43,
    '0f' => 39,
    '10' => 34,
    '11' => 32,
    '12' => 30,
    '13' => 28,
    '14' => 26,
    '15' => 23.5,
    '16' => 21.5,
    '17' => 19,
    '18' => 8.5,
    '19' => 6.5,
    '1a' => 4.5,
    '1b' => 2,
    '1c' => .5,
    '1d' => .3,
    '1e' => .2,
    '1f' => .1
);

=item C<derive_link_state([state])>

Overrides routine in BaseObject. Takes the various states available to insteon 
devices and returns a derived state of on, off, or 0%-100%.

=cut

sub derive_link_state {
    my ( $self, $p_state ) = @_;

    #Convert Relative State to Absolute State
    if ( $p_state =~ /^([+-])(\d+)/ ) {
        my $rel_state  = $1 . $2;
        my $curr_state = '100';
        $curr_state = '0' if ( $self->state eq 'off' );
        $curr_state = $1  if $self->state =~ /(\d{1,3})/;
        $p_state    = $curr_state + $rel_state;
        $p_state    = 100 if ( $p_state > 100 );
        $p_state    = 0   if ( $p_state < 0 );
    }

    my $link_state = 'on';
    if ( grep( /$p_state/i, @{ [ 'on_fast', 'off', 'off_fast' ] } ) ) {
        $link_state = $p_state;
    }
    elsif ( $p_state =~ /(\d+)%?/ ) {
        if ( $1 == 0 ) {
            $link_state = 'off';
        }
        else {
            $link_state = $1 . '%';
        }
    }
    return $link_state;
}

=item C<convert_ramp(ramp_seconds)>

Takes ramp_seconds in numeric seconds and returns the hexadecimal value of that 
ramp rate or the next lowest value if the passed value doesn't exist.  Possible
ramp rates are:

540, 480, 420, 360, 300, 270, 240, 210, 180, 150, 120, 90, 60, 47, 43, 39, 34, 
32, 30, 28, 26, 23.5, 21.5, 19, 8.5, 6.5, 4.5, 2, .5, .3, .2, and  .1

=cut

sub convert_ramp {
    my ($ramp_in_seconds) = @_;
    if ($ramp_in_seconds) {
        foreach my $rampkey ( sort keys %ramp_h2n ) {
            return $rampkey if $ramp_in_seconds >= $ramp_h2n{$rampkey};
        }
    }
    else {
        return '1f';
    }
}

=item C<get_ramp_from_code(ramp_code)>

Takes ramp_code as a hexadecimal representation of the device's ramp rate and
returns the equivalent ramp rate in decimal seconds.

=cut

sub get_ramp_from_code {
    my ($ramp_code) = @_;
    if ($ramp_code) {
        return $ramp_h2n{$ramp_code};
    }
    else {
        return 0;
    }
}

=item C<convert_level(on_level)>

Takes on_level as an integer percentage and converts it to a hexadecimal 
representation of that on_level that is used by a device.

=cut

sub convert_level {
    my ($on_level) = @_;
    my $level = 'ff';
    if ( defined($on_level) ) {
        $on_level =~ s/(\d+)%?/$1/;
        $level = sprintf( '%02X', int( ( $on_level * 2.55 ) + .5 ) );
    }
    return $level;
}

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::BaseLight( $p_deviceid, $p_interface );
    bless $self, $class;

    if ( $main::config_parms{insteon_menu_states} ) {
        $self->set_states(
            split( ',', $main::config_parms{insteon_menu_states} ) );
    }

    return $self;
}

=item C<local_onlevel(level)>

Sets and returns the local onlevel for the device in MH only. Level is a 
percentage from 0%-100%.

This setting can be pushed to the device using C<update_local_properties>.

Parameters: level [0-100]

Returns: [0-100]

=cut

sub local_onlevel {
    my ( $self, $p_onlevel ) = @_;
    if ( defined $p_onlevel ) {
        my ($onlevel) = $p_onlevel =~ /(\d+)%?/;
        $$self{_onlevel} = $onlevel;
    }
    return $$self{_onlevel};
}

=item C<local_ramprate(rate)>

Sets and returns the local ramp rate for the device in MH only. Rate is a time
between .1 and 540 seconds.  Only 32 rate steps exist, to MH will pick a time
equal to of the closest below this time.

This setting can be pushed to the device using C<update_local_properties>.

Parameters: rate = ramp rate [.1s - 540s] see C<convert_ramp> for valid values

Returns: hexadecimal representation of the ramprate.

=cut

sub local_ramprate {
    my ( $self, $p_ramprate ) = @_;
    if ( defined $p_ramprate ) {
        $$self{_ramprate} = &Insteon::DimmableLight::convert_ramp($p_ramprate);
    }
    return $$self{_ramprate};

}

=item C<update_local_properties()>

Pushes the values set in C<local_onlevel()> and C<local_ramprate()> to the device.

I1 Devices:

The device will only reread these values when it is power-cycled.  This can be
done by pulling the air-gap for 4 seconds or unplugging the device.

I2 & I2CS Devices

The device will immediately read and update the values.

=cut

sub update_local_properties {
    my ($self) = @_;
    if ( $self->engine_version eq 'I1' ) {
        $self->_aldb->update_local_properties() if $self->_aldb;
    }
    else {
        #Queue Ramp Rate First
        my $extra = '000005' . $self->local_ramprate();
        $extra .= '0' x ( 30 - length $extra );
        my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $self,
            'extended_set_get', $extra );
        $self->_send_cmd($message);

        #Now queue on level
        $extra = '000006'
          . ::Insteon::DimmableLight::convert_level( $self->local_onlevel() );
        $extra .= '0' x ( 30 - length $extra );
        $message = new Insteon::InsteonMessage( 'insteon_ext_send', $self,
            'extended_set_get', $extra );
        $self->_send_cmd($message);
    }
}

=item C<level(p_level)>

Stores and returns the objects current on_level as a percentage. If p_level 
is ON and the device has a defined local_onlevel, the local_onlevel is stored 
as the numeric level in memory.

Returns [0-100]

=cut

sub level {
    my ( $self, $p_level ) = @_;
    if ( defined $p_level ) {
        my $level = undef;
        if ( $p_level eq 'on' ) {

            # set the level based on any locally defined on level
            $level = $self->local_onlevel if $self->can('local_onlevel');

            # set to 100 if a local on level is not defined
            $level = 100 unless defined($level);
        }
        elsif ( $p_level eq 'off' ) {
            $level = 0;
        }
        elsif ( $p_level =~ /^([1]?[0-9]?[0-9])%?$/ ) {
            if ( $1 < 1 ) {
                $level = 0;
            }
            else {
                $level = $1;
            }
        }
        $$self{level} = $level if defined $level;
    }
    return $$self{level};

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
    my ($self)              = @_;
    my $object_name         = $self->get_object_name;
    my $insteon_menu_states = $main::config_parms{insteon_menu_states}
      if $main::config_parms{insteon_menu_states};
    my %voice_cmds = (
        %{ $self->SUPER::get_voice_cmds },
        'update onlevel/ramprate' => "$object_name->update_local_properties"
    );
    if ($insteon_menu_states) {
        foreach my $state ( split( /,/, $insteon_menu_states ) ) {
            $voice_cmds{$state} = "$object_name->set(\"$state\")";
        }
    }
    return \%voice_cmds;
}

=back

=head2 AUTHOR

Gregg Limming 

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::ApplianceLinc>

=head2 SYNOPSIS

User code:

    use Insteon::ApplianceLinc;
    $appliance_device = new Insteon::ApplianceLinc('12.34.56',$myPLM);

In mht file:

    INSTEON_APPLIANCELINC, 12.34.56, appliance_device, appliance_group

=head2 DESCRIPTION

Provides support for the Insteon ApplianceLinc.

=head2 INHERITS

L<Insteon::BaseLight|Insteon::Lighting/Insteon::BaseLight>

=head2 METHODS

=over

=cut

package Insteon::ApplianceLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::ApplianceLinc::ISA = ('Insteon::BaseLight');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::BaseLight( $p_deviceid, $p_interface );
    bless $self, $class;
    return $self;
}

=back

=head2 AUTHOR

Gregg Limming 

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::LampLinc>

=head2 SYNOPSIS

User code:

    use Insteon::LampLinc;
    $lamp_device = new Insteon::LampLinc('12.34.56',$myPLM);

In mht file:

    INSTEON_LAMPLINC, 12.34.56, lamp_device, All_Lights

=head2 DESCRIPTION

Provides support for the Insteon LampLinc.

=head2 INHERITS

L<Insteon::DimmableLight|Insteon::Lighting/Insteon::DimmableLight>, 


=head2 METHODS

=over

=cut

package Insteon::LampLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::LampLinc::ISA = ('Insteon::DimmableLight');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::DimmableLight( $p_deviceid, $p_interface );
    bless $self, $class;
    return $self;
}

=back

=head2 AUTHOR

Gregg Limming 

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::SwitchLincRelay>

=head2 SYNOPSIS

User code:

    use Insteon::SwitchLincRelay;
    $light_device = new Insteon::SwitchLincRelay('12.34.56',$myPLM);

In mht file:

    INSTEON_SWITCHLINCRELAY, 12.34.56, light_device, All_Lights

=head2 DESCRIPTION

Provides support for the Insteon SwitchLinc Relay.

=head2 INHERITS

L<Insteon::BaseLight|Insteon::Lighting/Insteon::BaseLight>,


=head2 METHODS

=over

=cut

package Insteon::SwitchLincRelay;

use strict;
use Insteon::BaseInsteon;

@Insteon::SwitchLincRelay::ISA = ('Insteon::BaseLight');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::BaseLight( $p_deviceid, $p_interface );
    bless $self, $class;
    return $self;
}

=item C<link_data3>

Returns the data3 value that should be used when creating a link for this device.  
This sub overides the parent class to map group 01 to data3 01.  This is required 
by the I2CS In-LineLinc Relay.

=cut 

sub link_data3 {
    my ( $self, $group, $is_controller ) = @_;

    my $link_data3 = $self->SUPER::link_data3( $group, $is_controller );

    if ( !$is_controller ) {    #is_responder
            #For I2CS devices the default data3 for responder links is 01.
            #This is to support the I2CS In-LineLinc Relay.  There may be more
            #permutations of the 00 vs. 01 problem and I1 devices may have
            #the same requirement.  This code is a work in progress as more
            #information is gathered about Relay type devices.
        if ( $self->can('engine_version') && $self->engine_version eq 'I2CS' ) {

            #Default to 01 if no group was supplied
            #Otherwise just return the group
            $link_data3 = ($group) ? $group : '01';
        }
    }

    return $link_data3;
}

=back

=head2 AUTHOR

Gregg Limming 

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::SwitchLinc>

=head2 SYNOPSIS

User code:

    use Insteon::SwitchLinc;
    $light_device = new Insteon::SwitchLinc('12.34.56',$myPLM);

In mht file:

    INSTEON_SWITCHLINC, 12.34.56, light_device, All_Lights

=head2 DESCRIPTION

Provides support for the Insteon SwitchLinc.

=head2 INHERITS

L<Insteon::DimmableLight|Insteon::Lighting/Insteon::DimmableLight>, 


=head2 METHODS

=over

=cut

package Insteon::SwitchLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::SwitchLinc::ISA = ('Insteon::DimmableLight');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::DimmableLight( $p_deviceid, $p_interface );
    bless $self, $class;
    return $self;
}

=back

=head2 AUTHOR

Gregg Limming 

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::KeyPadLincRelay>

=head2 SYNOPSIS

User code:

    use Insteon::KeyPadLincRelay;
    $light_device = new Insteon::KeyPadLincRelay('12.34.56:01',$myPLM);
    $button1_device = new Insteon::KeyPadLincRelay('12.34.56:02',$myPLM);
    $button2_device = new Insteon::KeyPadLincRelay('12.34.56:03',$myPLM);

In mht file:

    INSTEON_KEYPADLINCRELAY, 12.34.56:01, light_device, All_Lights
    INSTEON_KEYPADLINCRELAY, 12.34.56:02, button1_device, All_Buttons
    INSTEON_KEYPADLINCRELAY, 12.34.56:03, button2_device, All_Buttons

=head2 DESCRIPTION

Provides support for the Insteon KeypadLinc Relay.

=head2 INHERITS

L<Insteon::BaseLight|Insteon::Lighting/Insteon::BaseLight>, 
,
L<Insteon::Insteon::MultigroupDevice|Insteon::BaseInsteon/Insteon::Insteon::MultigroupDevice>

=head2 METHODS

=over

=cut

package Insteon::KeyPadLincRelay;

use strict;
use Insteon::BaseInsteon;

@Insteon::KeyPadLincRelay::ISA =
  ( 'Insteon::BaseLight', 'Insteon::MultigroupDevice' );

our %operating_flags = (
    'program_lock_on'   => '00',
    'program_lock_off'  => '01',
    'led_on_during_tx'  => '02',
    'led_off_during_tx' => '03',
    'resume_dim_on'     => '04',
    'resume_dim_off'    => '05',
    '8_key_mode'        => '06',
    '6_key_mode'        => '07',
    'led_off'           => '08',
    'led_enabled'       => '09',
    'key_beep_enabled'  => '0a',
    'key_beep_off'      => '0b'
);

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;
    my $self = new Insteon::BaseLight( $p_deviceid, $p_interface );
    $$self{operating_flags} = \%operating_flags;
    bless $self, $class;
    return $self;
}

=item C<set(state[,setby,response])>

Handles setting and receiving states from the device and specifically its 
subordinate buttons.

=cut

sub set {
    my ( $self, $p_state, $p_setby, $p_respond ) = @_;
    if ( !( $self->is_root ) and !( ref $p_setby && $p_setby eq $self ) ) {
        if ( ref $$self{surrogate}
            && ( $$self{surrogate}->isa('Insteon::InterfaceController') ) )
        {
            $$self{surrogate}->set( $p_state, $p_setby, $p_respond );
        }
        else {
            ::print_log(
                "[Insteon::KeyPadLinc] You may not directly attempt to set a keypadlinc's button "
                  . "unless you have defined a reverse link with the \"surrogate\" keyword"
            );
        }
    }
    else {
        return $self->SUPER::set( $p_state, $p_setby, $p_respond );
    }
}

=item C<update_flags(flags)>

Can be used to set the button layout and light level on a keypadlinc.  Flag 
options include:

    '0a' - 8 button; backlighting dim
    '06' - 8 button; backlighting off
    '02' - 8 button; backlighting normal

    '08' - 6 button; backlighting dim
    '04' - 6 button; backlighting off
    '00' - 6 button; backlighting normal

=cut

sub update_flags {
    my ( $self, $flags ) = @_;
    return unless defined $flags;
    if ( $self->engine_version eq 'I1' ) {
        $self->_aldb->update_flags($flags) if $self->_aldb;
    }
    else {
        $flags = hex($flags);
        if ( $flags & 0x02 ) {
            $self->set_operating_flag('8_key_mode');
        }
        else {
            $self->set_operating_flag('6_key_mode');
        }
        if ( $flags & 0x04 ) {
            $self->set_operating_flag('led_off');
        }
        else {
            $self->set_operating_flag('led_enabled');
        }
        if ( $flags & 0x08 ) {
            $self->set_operating_flag('resume_dim_on');
        }
        else {
            $self->set_operating_flag('resume_dim_off');
        }
    }
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
            %voice_cmds,
            'set 8 button - backlight dim' =>
              "$object_name->update_flags(\"0a\")",
            'set 8 button - backlight off' =>
              "$object_name->update_flags(\"06\")",
            'set 8 button - backlight normal' =>
              "$object_name->update_flags(\"02\")",
            'set 6 button - backlight dim' =>
              "$object_name->update_flags(\"08\")",
            'set 6 button - backlight off' =>
              "$object_name->update_flags(\"04\")",
            'set 6 button - backlight normal' =>
              "$object_name->update_flags(\"00\")",
            'sync all device links'       => "$object_name->sync_all_links()",
            'AUDIT sync all device links' => "$object_name->sync_all_links(1)",
            'sync intradevice links' =>
              "$object_name->sync_intradevice_links()",
        );
    }
    return \%voice_cmds;
}

=item C<link_data3>

Returns the data3 value that should be used when creating a link for this device.  
This sub overides the parent class to map group 01 to data3 01.  This is required 
by all of the KeypadLinc family.

=cut 

sub link_data3 {
    my ( $self, $group, $is_controller ) = @_;

    my $link_data3 = $self->SUPER::link_data3( $group, $is_controller );

    #Default to 01 if no group was supplied
    #Otherwise just return the group
    $link_data3 = ($group) ? $group : '01' if ( !$is_controller );

    return $link_data3;
}

=item C<sync_intradevice_links()>

IntraDevice Links are links between buttons on the same KPL.  These links are
not stored in the same manner as InterDevice links. Therefore this routine can
be used to sync the IntraDevice links.  There are two types of IntraDevice Links
FOLLOW and OFF.

B<FOLLOW>

Follow links are links which cause one button to be a slave to a master button. 
The slave button will always follow the state of the master button whenever the
master button is pressed.  For example, if Button A is defined as the master
to the slave Button B, then any time button A is pressed button B will follow.
If button A is turned on, button B will turn on.  Same thing with Off.  However,
button B can still be independently controlled.  That is button B can be turned
on or off manually, without affecting button A.  That is unless a reverse master
-slave relationship is defined.

To define Follow links, simply define a normal Insteon scene definition where
the scene controller is the master button and the scene responder is the slave
button.  To enable the follow functionality the on_level must be defined as NOT
zero.  The ramp rate is ignored and on_level will be converted to 100%.

    SCENE_MEMBER, kpl_button_B, kpl_button_A, 100% #Button B will follow A
    #In the following pressing Button A will cause B, C & D to turn on.
    #SCENE_Build is not much help here.
    SCENE_BUILD, kpl_scene, kpl_button_A,   1,    0,    80%
    SCENE_BUILD, kpl_scene, kpl_button_B,   0,    1,    100%
    SCENE_BUILD, kpl_scene, kpl_button_C,   0,    1,    100%
    SCENE_BUILD, kpl_scene, kpl_button_D,   0,    1,    100%

B<OFF>

Off links are links in which turning ON a master button will cause all slave
buttons to turn OFF.  This is commonly used for "radio" style buttons to control
a fan.  The buttons may be defined as Off, Low, Med, & High.  We only want one
state to be active at any given time.  To accomplish this, we define a series
of master slave relationships between all of the buttons.  Notably, you these
type of definitions do not have to affect all buttons, you can define Off links
that only join 2 buttons.  Similar to Follow links, these also do not have to be
two way links.

To define Off links, simply define a normal Insteon scene definition where
the scene controller is the master button and the scene responder is the slave
button.  To enable the off functionality the on_level must be defined as ZERO.
The ramp rate is ignored.

    SCENE_MEMBER, kpl_button_B, kpl_button_A, 0% #Turning ON A will turn OFF B
    
The following is an example for how to enable radio buttons, where only one
button can be activated at a time.

    SCENE_BUILD, kpl_scene, kpl_button_A,   1,    1,    0%
    SCENE_BUILD, kpl_scene, kpl_button_B,   1,    1,    0%
    SCENE_BUILD, kpl_scene, kpl_button_C,   1,    1,    0%
    SCENE_BUILD, kpl_scene, kpl_button_D,   1,    1,    0%

B<SYNCING>

To sync these links, simply run this command after creating the necessary link
definitions.  This routine will perform both the "sync and delete" steps to
bring the links on the device into compliance with the definitions in 
MisterHouse.  There is no "scan" feature for IntraDevice links.

=cut

sub sync_intradevice_links {
    my ($self) = @_;
    $self = $self->get_root();

    # First Calculate the value of all bytes
    my %byte_hash;    #Key is the lsb of the byte location
    my $lsb;          #used to store the lsb address

    ::print_log( '[Insteon::KeyPadLinc] '
          . $self->get_object_name
          . 'will be '
          . 'programmed with the following IntraDevice Links:' );

    # Find all subgroup items check groups from 1 - 8;
    for ( my $dec_group = 1; $dec_group <= 8; $dec_group++ ) {
        my $group = sprintf( "%02X", $dec_group );
        my $subgroup_object = Insteon::get_object( $self->device_id, $group );
        if ( ref $subgroup_object ) {

            #SubGroup Object Exists, Now Look for IntraDevice Link on Object
            foreach my $member_ref ( keys %{ $$subgroup_object{members} } ) {
                my $member = $$subgroup_object{members}{$member_ref}{object};
                my $member_group = hex( $member->group );
                my $member_root  = $member->get_root;
                if ( $member_root eq $self ) {

                    #This is an IntraDevice Link, Set button mask
                    $lsb = sprintf( "%02X", 64 + $dec_group );
                    $byte_hash{$lsb} |= 0b1 << ( $member_group - 1 );
                    my $tgt_on_level =
                      $$subgroup_object{members}{$member_ref}{on_level};
                    $tgt_on_level = '100' unless defined $tgt_on_level;
                    $tgt_on_level =~ s/(\d+)%?/$1/;
                    my $link_type = "FOLLOW";
                    if ( $tgt_on_level <= 0 ) {

                        #This is an Off Link, Set type
                        $lsb = sprintf( "%02X", 73 + $dec_group );
                        $byte_hash{$lsb} |= 0b1 << ( $member_group - 1 );
                        $link_type = "TURN OFF";
                    }
                    ::print_log(
                            "[Insteon::KeyPadLinc] Group $member_group will "
                          . "$link_type when Group $dec_group is pressed." );
                }
            }
        }
    }

    # Now write those bytes to the device
    if ( $self->engine_version eq 'I1' ) {

        #send to ALDB and use peek/poke commands there
        $self->_aldb->update_intradevice_links( \%byte_hash );
    }
    else {
        $self->_write_intradevice_links( \%byte_hash, 1, 2 );
    }
}

=item C<_write_intradevice_links()>

The i2 routine for writing the IntraDevice links to i2 devices.  Should not be
called directly.

=cut

sub _write_intradevice_links {
    my ( $self, $intradevice_hash_ref, $group, $sub ) = @_;
    $$self{_intradevice_hash_ref} = $intradevice_hash_ref
      if $intradevice_hash_ref ne '';

    # Create Key Value
    my $enable_key = sprintf( "%02X", 64 + $group );
    my $type_key   = sprintf( "%02X", 73 + $group );

    # Convert i1 style masks to i2 style masks, it appears i2 masks work diff
    my $enable_mask = $$self{_intradevice_hash_ref}{$enable_key};
    my $type_mask   = $$self{_intradevice_hash_ref}{$type_key};
    $enable_mask = 0 if $enable_mask eq '';
    $type_mask   = 0 if $type_mask eq '';
    my $mask = $enable_mask ^ $type_mask;    #follow mask
    if ( $sub == 3 ) {
        $mask = $enable_mask & $type_mask;    #Off mask
    }

    # Define our callbacks
    my $next_group = ( $sub == 2 ) ? $group : $group + 1;
    my $next_sub   = ( $sub == 2 ) ? 3      : 2;
    my $success_callback = $self->get_object_name
      . "->_write_intradevice_links('',$next_group,$next_sub)";
    my $failure_callback =
        "::print_log('[Insteon::KeyPadLinc] ERROR - Syncing"
      . "IntraDevice Links to "
      . $self->get_object_name
      . " failed.')";
    if ( $group == 8 && $sub == 3 ) {
        $success_callback =
            "::print_log('[Insteon::KeyPadLinc] Successfully wrote "
          . "IntraDevice links for "
          . $self->get_object_name . "')";
    }

    # Now write values to device
    my $extra =
      "00" . sprintf( "%02X", $group ) . "0" . $sub . sprintf( "%02X", $mask );
    my $message = $self->simple_message( 'extended_set_get', $extra );
    $message->failure_callback($failure_callback);
    $message->success_callback($success_callback);
    $self->_send_cmd($message);
}

## Creates an Extended Message, and Pads it with 0s to proper length
sub simple_message {
    my ( $self, $type, $extra ) = @_;
    my $message;
    $extra .= '0' x ( 30 - length $extra );
    $message =
      new Insteon::InsteonMessage( 'insteon_ext_send', $self, $type, $extra );
    return $message;
}

=back

=head2 AUTHOR

Gregg Limming, Kevin Robert Keegan 

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::KeyPadLinc>

=head2 SYNOPSIS

User code:

    use Insteon::KeyPadLinc;
    $light_device = new Insteon::KeyPadLinc('12.34.56:01',$myPLM);
    $button1_device = new Insteon::KeyPadLinc('12.34.56:02',$myPLM);
    $button2_device = new Insteon::KeyPadLinc('12.34.56:03',$myPLM);

In mht file:

    INSTEON_KEYPADLINC, 12.34.56:01, light_device, All_Lights
    INSTEON_KEYPADLINC, 12.34.56:02, button1_device, All_Buttons
    INSTEON_KEYPADLINC, 12.34.56:03, button2_device, All_Buttons

=head2 DESCRIPTION

Provides support for the Insteon KeypadLinc.

=head2 INHERITS

L<Insteon::DimmableLight|Insteon::Lighting/Insteon::DimmableLight>, 


=head2 METHODS

=over

=cut

package Insteon::KeyPadLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::KeyPadLinc::ISA =
  ( 'Insteon::KeyPadLincRelay', 'Insteon::DimmableLight' );

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;
    my $self = new Insteon::DimmableLight( $p_deviceid, $p_interface );
    $$self{operating_flags} = \%Insteon::KeyPadLincRelay::operating_flags;
    bless $self, $class;
    return $self;
}

# The subgroup items are not dimmable, so call BaseInsteon for them

sub derive_link_state {
    my ( $self, $p_state ) = @_;
    if ( $self->group eq '01' ) {
        return $self->SUPER::derive_link_state($p_state);
    }
    else {
        return $self->Insteon::BaseObject::derive_link_state($p_state);
    }
}

=back

=head2 AUTHOR

Gregg Limming 

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=head1 B<Insteon::MicroSwitchRelay>

=head2 SYNOPSIS

User code:

    use Insteon::MicroSwitchRelay;
    $light_device = new Insteon::MicroSwitchRelay('12.34.56',$myPLM);

In mht file:

    INSTEON_MICROSWITCHRELAY, 12.34.56, light_device, All_Lights

=head2 DESCRIPTION

Provides support for the Insteon Micro On/Off Module.

=head2 INHERITS

L<Insteon::DimmableLight|Insteon::Lighting/Insteon::DimmableLight>, 


=head2 METHODS

=over

=cut

package Insteon::MicroSwitchRelay;

use strict;
use Insteon::BaseInsteon;

@Insteon::MicroSwitchRelay::ISA = ('Insteon::BaseLight');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;
    my $self = new Insteon::DimmableLight( $p_deviceid, $p_interface );
    $$self{operating_flags} = \%Insteon::MicroSwitchRelay::operating_flags;
    bless $self, $class;
    return $self;
}

our %operating_flags = (
    'momentary'        => '21',
    'dual'             => '1f',
    'latching'         => '20',
    'single'           => '1e',
    '3-way'            => '22',
    '1-way'            => '23',
    'blink_traffic'    => '02',
    'no_blink_traffic' => '03',
    'no_blink_error'   => '14',
    'blink_error'      => '15',
    'beep_button'      => '0a',
    'no_beep_button'   => '0b',
    'p_lock'           => '00',
    'p_unlock'         => '01'
);

=item C<set_mode(mode)>

Can be used to set the mode of the device.  Options are:

Latching, Single_Momentary, Dual_Momentary

=cut

sub set_mode {
    my ( $self, $mode ) = @_;
    return unless defined $mode;
    my $name = $self->get_object_name;

    ::print_log("[Insteon::MicroSwitch] Setting mode of $name to $mode.");

    if ( $mode =~ /momentary/i ) {
        $self->set_operating_flag('momentary');
    }
    else {
        $self->set_operating_flag('latching');
    }
    if ( $mode =~ /dual/i ) {
        $self->set_operating_flag('dual');
    }
    else {
        $self->set_operating_flag('single');
    }
}

=item C<enable_3_way(boolean)>

Only has an effect in latching mode.  If set to true enables three way.

=cut

sub enable_3_way {
    my ( $self, $is_true ) = @_;
    return unless defined $is_true;
    my $name = $self->get_object_name;

    if ($is_true) {
        ::print_log("[Insteon::MicroSwitch] Setting $name to 3-way.");
        $self->set_operating_flag('3-way');
    }
    else {
        ::print_log("[Insteon::MicroSwitch] Setting $name to 1-way.");
        $self->set_operating_flag('1-way');
    }
}

=item C<enable_blink_traffic(boolean)>

If boolean is true, LED will blink on traffic.

=cut

sub enable_blink_traffic {
    my ( $self, $is_true ) = @_;
    return unless defined $is_true;
    my $name = $self->get_object_name;

    if ($is_true) {
        ::print_log( "[Insteon::MicroSwitch] Setting LED on $name to"
              . " blink on traffic." );
        $self->set_operating_flag('blink_traffic');
    }
    else {
        ::print_log( "[Insteon::MicroSwitch] Setting LED on $name to"
              . " not blink on traffic." );
        $self->set_operating_flag('no_blink_traffic');
    }
}

=item C<enable_blink_error(boolean)>

If boolean is true, LED will blink on error.

=cut

sub enable_blink_error {
    my ( $self, $is_true ) = @_;
    return unless defined $is_true;
    my $name = $self->get_object_name;

    if ($is_true) {
        ::print_log( "[Insteon::MicroSwitch] Setting LED on $name to"
              . " blink on error." );
        $self->set_operating_flag('blink_error');
    }
    else {
        ::print_log( "[Insteon::MicroSwitch] Setting LED on $name to"
              . " not blink on error." );
        $self->set_operating_flag('no_blink_error');
    }
}

=item C<enable_beep_button(boolean)>

If boolean is true, a beep will sound when button is pressed.

=cut

sub enable_beep_button {
    my ( $self, $is_true ) = @_;
    return unless defined $is_true;
    my $name = $self->get_object_name;

    if ($is_true) {
        ::print_log( "[Insteon::MicroSwitch] Setting $name to"
              . " beep on button press." );
        $self->set_operating_flag('beep_button');
    }
    else {
        ::print_log( "[Insteon::MicroSwitch] Setting $name to"
              . " not beep on button press." );
        $self->set_operating_flag('no_beep_button');
    }
}

=item C<led_level([0-100])>

Sets the LED to brightness percentage.

=cut

sub led_level {
    my ( $self, $level ) = @_;
    return unless defined $level;
    my $name = $self->get_object_name;

    ::print_log(
        "[Insteon::MicroSwitch] Setting LED level of $name to" . " $level." );

    #For whatever reason 100% = 127 and 50% = 64
    $level = $level * 1.28;
    $level = 127 if $level > 127;
    $level = 0 if $level < 0;

    my $extra = '000107' . sprintf( '%02X', $level );
    $extra .= '0' x ( 30 - length $extra );
    my $message = new Insteon::InsteonMessage( 'insteon_ext_send', $self,
        'extended_set_get', $extra );
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
            %voice_cmds,
            'set latching mode' => "$object_name->set_mode(\"latching\")",
            'set single momentary mode' =>
              "$object_name->set_mode(\"single_momentary\")",
            'set dual momentary mode' =>
              "$object_name->set_mode(\"dual_momentary\")",
            'set to 3-way' => "$object_name->enable_3_way(1)",
            'set to 1-way' => "$object_name->enable_3_way(0)",
            'set LED to blink on traffic' =>
              "$object_name->enable_blink_traffic(1)",
            'set LED to not blink on traffic' =>
              "$object_name->enable_blink_traffic(0)",
            'set LED to blink on error' =>
              "$object_name->enable_blink_error(1)",
            'set LED to not blink on error' =>
              "$object_name->enable_blink_error(0)",
            'set device to beep on button press' =>
              "$object_name->enable_beep_button(1)",
            'set device to not beep on button press' =>
              "$object_name->enable_beep_button(0)",
            'set LED to 100%' => "$object_name->led_level(100)",
            'set LED to 50%'  => "$object_name->led_level(50)",
            'set LED to 0%'   => "$object_name->led_level(\"0\")",
        );
    }
    return \%voice_cmds;
}

=back

=head2 AUTHOR

Kevin Robert Keegan

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=head1 B<Insteon::MicroSwitch>

=head2 SYNOPSIS

User code:

    use Insteon::MicroSwitch;
    $light_device = new Insteon::MicroSwitch('12.34.56',$myPLM);

In mht file:

    INSTEON_MICROSWITCH, 12.34.56, light_device, All_Lights

=head2 DESCRIPTION

Provides support for the Insteon Micro Dimmer Module.

=head2 INHERITS

L<Insteon::DimmableLight|Insteon::Lighting/Insteon::DimmableLight>, 


=head2 METHODS

=over

=cut

package Insteon::MicroSwitch;

use strict;
use Insteon::BaseInsteon;

@Insteon::MicroSwitch::ISA =
  ( 'Insteon::MicroSwitchRelay', 'Insteon::DimmableLight' );

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;
    my $self = new Insteon::DimmableLight( $p_deviceid, $p_interface );
    $$self{operating_flags} = \%Insteon::MicroSwitchRelay::operating_flags;
    bless $self, $class;
    return $self;
}

=back

=head2 AUTHOR

Kevin Robert Keegan

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::FanLinc>

=head2 SYNOPSIS

User code:

    use Insteon::FanLinc;
    $light_device = new Insteon::FanLinc('12.34.56:01',$myPLM);
    $fan_device = new Insteon::FanLinc('12.34.56:02',$myPLM);

In mht file:

    INSTEON_FANLINC, 12.34.56:01, light_device, All_Lights
    INSTEON_FANLINC, 12.34.56:02, fan_device, All_Fans

=head2 DESCRIPTION

Provides support for the Insteon FanLinc.

=head2 INHERITS

L<Insteon::DimmableLight|Insteon::Lighting/Insteon::DimmableLight>, 
,
L<Insteon::Insteon::MultigroupDevice|Insteon::BaseInsteon/Insteon::Insteon::MultigroupDevice>

=head2 METHODS

=over

=cut

package Insteon::FanLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::FanLinc::ISA =
  ( 'Insteon::DimmableLight', 'Insteon::MultigroupDevice' );

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;
    my $self = new Insteon::DimmableLight( $p_deviceid, $p_interface );
    bless $self, $class;
    return $self;
}

=item C<derive_message([command,extra])>

Generates set commands for the fan, light requests are passed to BaseObject

=cut

sub derive_message {
    my ( $self, $p_command, $p_extra ) = @_;
    if ( $self->is_root ) {
        $self->SUPER::derive_message( $p_command, $p_extra );
    }
    else {
        my $level;

        #msg id
        my ( $command, $subcommand ) = split( /:/, $p_command, 2 );
        $command = lc($command);

        if ( $command eq 'on' ) {
            $command = '100';
        }
        elsif ( $command eq 'off' ) {
            $command = '00';
        }
        $command = ::Insteon::DimmableLight::convert_level($command);
        my $extra = $command . "0200000000000000000000000000";
        my $message =
          new Insteon::InsteonMessage( 'insteon_ext_send', $self, 'on',
            $extra );
        return $message;
    }
}

=item C<request_status()>

Will request the status of the device.  For the light device, the process is 
handed off to the L<Insteon::BaseObject::request_status()|Insteon::BaseInsteon/Insteon::BaseObject> routine.  This routine
specifically handles the fan request.

=cut

sub request_status {
    my ( $self, $requestor ) = @_;
    if ( $self->is_root() ) {
        return $self->SUPER::request_status($requestor);
    }
    else {
        # Setting Fan Level
        my $parent = $self->get_root();
        $$parent{child_status_request_pending} = $self->group;
        $$self{m_status_request_pending} = ($requestor) ? $requestor : 1;
        my $message = new Insteon::InsteonMessage( 'insteon_send', $parent,
            'status_request', '03' );
        $parent->_send_cmd($message);
    }
}

=item C<_is_info_request()>

Handles incoming messages from the device which are unique to the FanLinc, 
specifically this handles the C<request_status()> response for the Fan device, 
all other responses are handed off to the C<Insteon::BaseObject::request_status()>.

=cut

sub _is_info_request {
    my ( $self, $cmd, $ack_setby, %msg ) = @_;
    my $is_info_request = 0;
    my $parent          = $self->get_root();
    if ( $$parent{child_status_request_pending} ) {
        $is_info_request++;
        my $child_obj = Insteon::get_object( $self->device_id, '02' );
        my $child_state = $child_obj->derive_link_state( hex( $msg{extra} ) );
        &::print_log( "[Insteon::FanLinc] received status for "
              . $child_obj->{object_name}
              . " of: $child_state "
              . "hops left: $msg{hopsleft}" )
          if $self->debuglevel( 1, 'insteon' );
        $ack_setby = $$child_obj{m_status_request_pending}
          if ref $$child_obj{m_status_request_pending};
        $child_obj->SUPER::set( $child_state, $ack_setby );
        delete( $$parent{child_status_request_pending} );
    }
    else {
        $is_info_request =
          $self->SUPER::_is_info_request( $cmd, $ack_setby, %msg );
    }
    return $is_info_request;
}

=item C<is_acknowledged()>

Handles command acknowledgement messages received from the device that are 
unique to the FanLinc, specifically the acknowledgement of commands sent to the
fan device.  All other instances are handed off to the C<Insteon::BaseObject>.

=cut

sub is_acknowledged {
    my ( $self, $p_ack ) = @_;
    my $parent = $self->get_root();
    if ( $p_ack && $$parent{child_pending_state} ) {
        my $child_obj = Insteon::get_object( $self->device_id, '02' );
        $child_obj->set_receive(
            $$child_obj{pending_state},
            $$child_obj{pending_setby},
            $$child_obj{pending_response}
        ) if defined $$child_obj{pending_state};
        $$child_obj{is_acknowledged}  = $p_ack;
        $$child_obj{pending_state}    = undef;
        $$child_obj{pending_setby}    = undef;
        $$child_obj{pending_response} = undef;
        $$parent{child_pending_state} = undef;
        &::print_log(
            "[Insteon::FanLinc] received command/state acknowledge from "
              . $child_obj->{object_name} )
          if $self->debuglevel( 1, 'insteon' );
        return $$self{is_acknowledged};
    }
    else {
        return $self->SUPER::is_acknowledged($p_ack);
    }
}

=item C<enable_led(boolean)>

If boolean is true, status LEDs will be enabled.

=cut

sub enable_led {
    my ( $self, $is_true ) = @_;
    return unless defined $is_true;
    my $name = $self->get_object_name;

    if ($is_true) {
        ::print_log(
            "[Insteon::FanLinc] Enabling LEDs on $name. After doing this, you may have to turn both the fan and the light on/off in order for the change to take effect."
        );
        $self->set_operating_flag('led_enabled');
    }
    else {
        ::print_log(
            "[Insteon::FanLinc] Disabling LEDs on $name. After doing this, you may have to turn both the fan and the light on/off in order for the change to take effect."
        );
        $self->set_operating_flag('led_off');
    }
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
            %voice_cmds,
            'enable status LEDs'          => "$object_name->enable_led(1)",
            'disable status LEDs'         => "$object_name->enable_led(0)",
            'sync all device links'       => "$object_name->sync_all_links()",
            'AUDIT sync all device links' => "$object_name->sync_all_links(1)"
        );
    }
    return \%voice_cmds;
}

=back

=head2 AUTHOR 

Kevin Robert Keegan 

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::BulbLinc>

=head2 SYNOPSIS

User code:

    use Insteon::BulbLinc;
    $bulb_device = new Insteon::BulbLinc('12.34.56',$myPLM);

In mht file:

    INSTEON_BULBLINC, 12.34.56, bulb_device, All_Lights

=head2 DESCRIPTION

Provides support for the Insteon BulbLinc.

=head3 FEATURES

The BulbLinc has no physical set button; therefore, linking is initiated by cutting and restoring power to the device.  This feature can be disabled for environments where all links are configured via software means and this behavior is unnecessary.  The 'enable_linking_on_powerup' command provides for this option.

=head2 INHERITS

L<Insteon::DimmableLight|Insteon::Lighting/Insteon::DimmableLight>, 

=head2 METHODS

=over

=cut

package Insteon::BulbLinc;

use strict;
use Insteon::BaseInsteon;

@Insteon::BulbLinc::ISA = ('Insteon::DimmableLight');

our %operating_flags = (
    'linking_on_powerup_on'  => '01',
    'linking_on_powerup_off' => '00'
);

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::DimmableLight( $p_deviceid, $p_interface );
    $$self{operating_flags} = \%operating_flags;
    bless $self, $class;
    return $self;
}

=item C<enable_linking_on_powerup(boolean)>

If boolean is true, the BulbLinc will perform a "complete linking as responder" on every power-up.

=cut

sub enable_linking_on_powerup {
    my ( $self, $is_true ) = @_;
    return unless defined $is_true;
    my $name = $self->get_object_name;

    if ($is_true) {
        ::print_log("[Insteon::BulbLinc] Enabling Linking on Startup on $name");
        $self->set_operating_flag('linking_on_powerup_on');
    }
    else {
        ::print_log(
            "[Insteon::BulbLinc] Disabling Linking on Startup on $name");
        $self->set_operating_flag('linking_on_powerup_off');
    }
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
            %voice_cmds,
            'set linking on powerup on' =>
              "$object_name->enable_linking_on_powerup(1)",
            'set linking on powerup off' =>
              "$object_name->enable_linking_on_powerup(0)"
        );
    }
    return \%voice_cmds;
}

=back

=head2 AUTHOR

Jared J. Fernandez

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1
