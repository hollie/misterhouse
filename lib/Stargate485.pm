
=head1 B<Stargate485>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

use strict;

# This needs to be available to both Stargate485 and StargateLCDKeypad
my @lcdkeypad_object_list;
my @thermostat_object_list;
my ( @stargate485_command_list, $transmitok, $temp );

package Stargate485;

my ($temp);

=item C<serial_startup>

This code create the serial port and registers the callbacks we need

=cut

sub serial_startup {
    if ( $::config_parms{Stargate485_serial_port} ) {
        my ($speed) = $::config_parms{Stargate485_baudrate} || 9600;
        if (
            &::serial_port_create(
                'Stargate485', $::config_parms{Stargate485_serial_port},
                $speed,        'none'
            )
          )
        {
            init( $::Serial_Ports{Stargate485}{object} );
            &::MainLoop_pre_add_hook( \&Stargate485::UserCodePreHook, 1 );
            &::MainLoop_post_add_hook( \&Stargate485::UserCodePostHook, 1 );
        }
    }
}

sub init {
    my ($serial_port) = @_;
    $::Serial_Ports{'Stargate485'}{process_data} = 1;

    $serial_port->error_msg(0);
    $serial_port->user_msg(1);

    #    $serial_port->debug(1);

    #    $serial_port->parity_enable(1);
    $serial_port->baudrate(9600);
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->parity_enable(0);
    $serial_port->stopbits(1);

    $serial_port->handshake("none");    #&? Should this be DTR?

    $serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
    $serial_port->rts_active(0);
    select( undef, undef, undef, .100 );    # Sleep a bit
    ::print_log "Stargate485 init\n" if $main::Debug{Stargate485};

    $transmitok = 1;
}

sub UserCodePreHook {

    # Special case startup but notifying already created objects about it and then return.
    if ($::Startup) {
        SetKeypadStates( 'all', 'startup' );
        return;
    }

    if ($::New_Msecond_100) {
        my $data;
        unless ( $data = $::Serial_Ports{'Stargate485'}{object}->input ) {

            # If we do not do this, we may get endless error messages.
            $::Serial_Ports{'Stargate485'}{object}->reset_error;
        }

        $::Serial_Ports{'Stargate485'}{data} .= $data if $data;

        print
          "  serial name=Stargate485 type=$::Serial_Ports{'Stargate485'}{datatype} data2=$::Serial_Ports{'Stargate485'}{data}...\n"
          if $data and ( $main::Debug{serial} or $main::Debug{Stargate485} );

        # Check to see if we have a carrage return yet
        if ( $::Serial_Ports{'Stargate485'}{data} ) {
            while ( my ( $record, $remainder ) =
                $::Serial_Ports{'Stargate485'}{data} =~ /(.+?)[\r\n]+(.*)/s )
            {
                &::print_log(
                    "Data from Stargate485: $record.  remainder=$remainder.")
                  if $main::Debug{Stargate485};
                $::Serial_Ports{'Stargate485'}{data_record} = $record;
                $::Serial_Ports{'Stargate485'}{data}        = $remainder;
                if ( $main::Debug{Stargate485} ) {
                    print "Data: " . $record . "\n"
                      unless substr( $record, 1, 2 ) eq 'TP'
                      and (substr( $record, 5, 1 ) eq 'Q'
                        or substr( $record, 6, 1 ) eq 'A' );
                }

                # Look something like '$TP01D2cff         11' ?
                if ( substr( $record, 0, 3 ) eq '$TP' ) {
                    ParseKeypadData($record);
                }

                # Next look for thermostat responses to our request for status
                elsif ( substr( $record, 0, 4 ) eq 'A=MH' ) {
                    ParseThermostatData($record);
                }
            }
        }
    }

    if ( $::New_Msecond_250 && @stargate485_command_list > 0 && $transmitok ) {
        if ( $::Serial_Ports{Stargate}{object} ) {

            #while(@stargate485_command_list > 0)
            #{
            ( my $output ) = shift @stargate485_command_list;
            print "Stargate COM1 to 485bus transmit: " . $output . "\n"
              if lc( $main::config_parms{debug} ) eq 'stargate485';
            &Stargate::send_command( $::Serial_Ports{Stargate}{object},
                "rs485", $output );

            #$::Serial_Ports{Stargate}{object}->write("##%a507" . $output . "\r");
            #}
        }
        elsif ( !$::Serial_Ports{'Stargate485'}{data} ) {
            $::Serial_Ports{Stargate485}{object}->rts_active(1);
            select( undef, undef, undef, .10 );    # Sleep a bit

            $::Serial_Ports{Stargate485}{object}->write("\r");

            #while(@stargate485_command_list > 0)
            #{
            ( my $output ) = shift @stargate485_command_list;
            print "Stargate 485bus transmit: " . $output . "\n"
              if lc( $main::config_parms{debug} ) eq 'stargate485';
            $::Serial_Ports{Stargate485}{object}->write( $output . "\r" );

            #}
            select( undef, undef, undef, .30 );    # Sleep a bit

            $::Serial_Ports{Stargate485}{object}->rts_active(0);
            select( undef, undef, undef, .10 );    # Sleep a bit
        }
    }
}

sub UserCodePostHook {
    #
    # Reset data for _now functions
    #
    $::Serial_Ports{Stargate485}{data_record} = '';
}

sub ParseKeypadData {
    my ($record) = @_;

    my $NewState;
    my $TargetLCD;

    # Extracr the keypad address
    $TargetLCD = substr( $record, 3, 2 );

    #print "Target: $TargetLCD\n";

    # Change it to 'D2cff         11'
    $record = substr( $record, 5 );

    #print "Record: $record\n";

    # Is this a MACRO?
    if ( substr( $record, 0, 3 ) eq 'D2c' ) {

        # Set the generic 'macro triggered' state
        #SetKeypadStates($TargetLCD,'MACRO');

        # Set the specific 'macro triggered' state
        my $MacroId = substr( $record, 3, 2 );

        #print "MacroID = $MacroId\n";
        # Hex to decimal
        $MacroId = hex($MacroId) + 1;

        #print "MacroID decoded as: " . $MacroId . "\n";
        SetKeypadStates( $TargetLCD, sprintf( 'macro%3.3d', $MacroId ) );
    }
    elsif ( substr( $record, 0, 2 ) eq '0A' ) {

        # Keyboard status alive response, ignore
    }
    elsif ( substr( $record, 0, 1 ) eq 'K' ) {

        # Extract Digit
        my $Digit = substr( $record, 1, 1 );
        SetKeypadStates( $TargetLCD, sprintf( 'digit%1.1d', $Digit ) );

        # Don't know what 2 additional characters are (checksum)?
    }
    else {
        print "Unknown keypad response lcd:$TargetLCD data:$record\n"
          if $record;    # if $main::Debug{Stargate485Keypad};
    }
}

sub SetKeypadStates {
    my ( $address, $state ) = @_;

    #print "SetKeypadStats: $address $state\n";

    my $object;
    foreach $object (@lcdkeypad_object_list) {
        if (   ( $address eq 'all' )
            or ( $object->{address} == 0 )
            or ( $object->{address} == $address ) )
        {
            $object->set($state);
        }
    }
}

sub ParseThermostatData {
    my ($record) = @_;

    my $address = $1 if $record =~ /\sO=(\d+)/;

    my $object;
    foreach $object (@thermostat_object_list) {
        if ( $object->{address} == $address ) {

            # For multi zoned systems we will need to loop thru the responses and get
            # the zone specific ones.  We apply the system settings to all zones.
            # This is not yet implemented (we don't have a multizoned system to
            # test any code against)

            if ( $record =~ /\sT=(\d+)/ ) {
                $object->set_states_for_next_pass("temp")
                  if ( $object->{temp} ne $1 );
                $object->set_states_for_next_pass("temp:$1")
                  if ( $object->{temp} ne $1 );
                $object->{temp} = $1;
            }

            if ( $record =~ /\sSP=(\d+)/ ) {
                $object->set_states_for_next_pass("setpoint")
                  if ( $object->{setpoint} ne $1 );
                $object->set_states_for_next_pass("setpoint:$1")
                  if ( $object->{setpoint} ne $1 );
                $object->{setpoint} = $1;
            }

            if ( $record =~ /\sM=(O|H|C|A|I)/ ) {
                $object->set_states_for_next_pass("zonemode")
                  if ( $object->{zonemode} ne $1 );
                $object->set_states_for_next_pass("zonemode:$1")
                  if ( $object->{zonemode} ne $1 );
                $object->{zonemode} = $1;
            }

            if ( $record =~ /\sFM=(\d+)/ ) {
                $object->set_states_for_next_pass("zonefanmode")
                  if ( $object->{zonefanmode} ne $1 );
                $object->set_states_for_next_pass(
                    "zonefanmode:" . &StargateRCSThermostat::ReturnString($1) )
                  if ( $object->{zonefanmode} ne $1 );
                $object->{zonefanmode} = $1;
            }

            if ( $record =~ /\sH1A=(\d+)/ ) {
                $object->set_states_for_next_pass("heatingstage1")
                  if ( $object->{heatingstage1} ne $1 );
                $object->set_states_for_next_pass( "heatingstage1:"
                      . &StargateRCSThermostat::ReturnString($1) )
                  if ( $object->{heatingstage1} ne $1 );
                $object->{heatingstage1} = $1;
            }

            if ( $record =~ /\sH2A=(\d+)/ ) {
                $object->set_states_for_next_pass("heatingstage2")
                  if ( $object->{heatingstage2} ne $1 );
                $object->set_states_for_next_pass( "heatingstage2:"
                      . &StargateRCSThermostat::ReturnString($1) )
                  if ( $object->{heatingstage2} ne $1 );
                $object->{heatingstage2} = $1;
            }

            if ( $record =~ /\sC1A=(\d+)/ ) {
                $object->set_states_for_next_pass("coolingstage1")
                  if ( $object->{coolingstage1} ne $1 );
                $object->set_states_for_next_pass( "coolingstage1:"
                      . &StargateRCSThermostat::ReturnString($1) )
                  if ( $object->{coolingstage1} ne $1 );
                $object->{coolingstage1} = $1;
            }

            if ( $record =~ /\sC2A=(\d+)/ ) {
                $object->set_states_for_next_pass("coolingstage2")
                  if ( $object->{coolingstage2} ne $1 );
                $object->set_states_for_next_pass( "coolingstage2:"
                      . &StargateRCSThermostat::ReturnString($1) )
                  if ( $object->{coolingstage2} ne $1 );
                $object->{coolingstage2} = $1;
            }

            if ( $record =~ /\sFA=(\d+)/ ) {
                $object->set_states_for_next_pass("fanstatus")
                  if ( $object->{fanstatus} ne $1 );
                $object->set_states_for_next_pass(
                    "fanstatus:" . &StargateRCSThermostat::ReturnString($1) )
                  if ( $object->{fanstatus} ne $1 );
                $object->{fanstatus} = $1;
            }

            if ( $record =~ /\sSCP=(\d+)/ ) {
                $object->set_states_for_next_pass("shortcycle")
                  if ( $object->{shortcycle} ne $1 );
                $object->set_states_for_next_pass(
                    "shortcycle:" . &StargateRCSThermostat::ReturnString($1) )
                  if ( $object->{shortcycle} ne $1 );
                $object->{shortcycle} = $1;
            }

            if ( $record =~ /\sSM=(O|H|C|A|I)/ ) {
                $object->set_states_for_next_pass("systemmode")
                  if ( $object->{systemmode} ne $1 );
                $object->set_states_for_next_pass(
                    "systemmode:" . &StargateRCSThermostat::ReturnString($1) )
                  if ( $object->{systemmode} ne $1 );
                $object->{systemmode} = $1;
            }

            if ( $record =~ /\sSF=(\d+)/ ) {
                $object->set_states_for_next_pass("fancommand")
                  if ( $object->{fancommand} ne $1 );
                $object->set_states_for_next_pass(
                    "fancommand:" . &StargateRCSThermostat::ReturnString($1) )
                  if ( $object->{fancommand} ne $1 );
                $object->{fancommand} = $1;
            }
        }
    }
}

1;

=back

=head2 INI PARAMETERS

Stargate485_serial_port=COM2

=head2 AUTHOR

bsobel@vipmail.com' July 11, 2000

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateLCDKeypad>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Item object version (this lets us use object links and events)

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

# $TP from keypad.  01 address
#$TP01D2cff         11

package StargateLCDKeypad;
@StargateLCDKeypad::ISA = ('Generic_Item');

sub new {
    my ( $class, $address ) = @_;

    my $self = { address => $address };
    bless $self, $class;

    push( @lcdkeypad_object_list, $self );

    return $self;
}

sub ClearScreen {
    my ($self) = @_;
    my $output = "!TP" . sprintf( "%2.2xC", $self->{address} );
    push( @stargate485_command_list, $output );
}

sub GoToMenu {
    my ( $self, $menu ) = @_;
    my $output = "!TP" . sprintf( "%2.2xG%2.2x", $self->{address}, $menu - 1 );
    push( @stargate485_command_list, $output );
}

sub WriteText {
    my ( $self, $row, $text ) = @_;
    my $output = "!TP"
      . sprintf( "%2.2xT%2.2x0a%-10.10s00", $self->{address}, $row - 1, $text );
    push( @stargate485_command_list, $output );
}

sub ChangeText {
    my ( $self, $menu, $row, $text ) = @_;

    my $output = "!TP"
      . sprintf( "%2.2xm%2.2x%2.2x80%-10.10s00",
        $self->{address}, $menu - 1, $row - 1, $text );
    push( @stargate485_command_list, $output );
}

sub InvertText {
    my ( $self, $menu, $row ) = @_;

    my $output = "!TP"
      . sprintf( "%2.2xm%2.2x%2.2x30          30",
        $self->{address}, $menu - 1, $row - 1 );
    push( @stargate485_command_list, $output );
}

sub UnInvertText {
    my ( $self, $menu, $row ) = @_;

    my $output = "!TP"
      . sprintf( "%2.2xm%2.2x%2.2x30          00",
        $self->{address}, $menu - 1, $row - 1 );
    push( @stargate485_command_list, $output );
}
1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

bsobel@vipmail.com' July 11, 2000

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<StargateRCSThermostat>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Item object version (this lets us use object links and events)

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package StargateRCSThermostat;
@StargateRCSThermostat::ISA = ('Generic_Item');

sub new {
    my ( $class, $address, $zone ) = @_;

    $zone = 1 if $zone == undef;
    my $self = { address => $address, zone => $zone };
    bless $self, $class;

    push( @thermostat_object_list, $self );

    #
    # This is data we get from our queries, default it here and then fill it in.  These map
    # closely to the RCS 485 thermostats but should be able to be updated for others.
    #
    $self->{temp}          = undef;    # T=74
    $self->{setpoint}      = undef;    # SP=77
    $self->{zonemode}      = undef;    # M=0
    $self->{zonefanmode}   = undef;    # FM=0
    $self->{heatingstage1} = undef;    # H1A=0
    $self->{heatingstage2} = undef;    # H2A=0
    $self->{coolingstage2} = undef;    # C1A=0
    $self->{coolingstage2} = undef;    # C2A=0
    $self->{fanstatus}     = undef;    # FA=0
    $self->{shortcycle}    = undef;    # SCP=0
    $self->{systemmode}    = undef;
    ;                                  # SM=A
    $self->{fancommand} = undef;       # SF=0

    # Set available commands here
    # push(@{$$self{states}}, 'on','off','volume:max', 'volume:normal', 'volume:min','volume:+','volume:-','input:+','input:-');

    return $self;
}

sub default_setstate {
    my ( $self, $device, $state ) = @_;
    return -1 if ( $self->{zone} == 0 );

    #my ($device,$state) = $setstate =~ /\s*(\w+)\s*:*\s*(\w*)/;
    #$self->SUPER::set($device);
    #$self->SUPER::set($device . ":" . $state);

    SWITCH: for ($device) {

        # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
        /^setpoint/i
          && do { return $self->SendTheromostatCommand( "SP", $state ) };

        # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
        /^heatpoint/i && do {
            return $self->SendTheromostatCommand( "SP", $state )
              if $self->{zonemode} eq 'H';
        };

        # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
        /^coolpoint/i && do {
            return $self->SendTheromostatCommand( "SP", $state )
              if $self->{zonemode} eq 'C';
        };

        # Valid setpoint $state is a temperature value or +/- to increment/decrement current setpoint by one degree
        /^autopoint/i && do {
            return $self->SendTheromostatCommand( "SP", $state )
              if $self->{zonemode} eq 'A';
        };

        # Valid mode $state is 0/O for off 1/H for heat, 2/C for cool, and 3/A for auto
        /^zonemode/i && do {
            return $self->SendTheromostatCommand( "M",
                uc( substr( $state, 1 ) ) );
        };

        # Valid mode $state is 0 or 1
        /^zonefanmode/i && do {
            return $self->SendTheromostatCommand( "F", ReturnCommand($state) );
        };

        # Valid mode $state is 0/O for off 1/H for heat, 2/C for cool, and 3/A for auto
        /^systemmode/i && do {
            return $self->SendTheromostatCommand( "SM",
                uc( substr( $state, 1 ) ) );
        };

        # Valid mode $state is 0 or 1
        /^systemfanmode/i && do {
            return $self->SendTheromostatCommand( "SF", ReturnCommand($state) );
        };

        # Valid mode $state is 0 or 1
        /^ventdamper/i && do {
            return $self->SendTheromostatCommand( "V", ReturnCommand($state) );
        };

        # Valid mode $state is a temperature value
        /^outside/i
          && do { return $self->SendTheromostatCommand( "OT", $state ) };

        # Valid mode $state is a temperature value
        /^remote/i
          && do { return $self->SendTheromostatCommand( "RT", $state ) };

        # Valid mode $state is 0 or 1
        /^setback/i && do {
            return $self->SendTheromostatCommand( "BF", ReturnCommand($state) );
        };

        # Valid mode $state is 0 or 1
        /^text/i && do {
            return $self->SendTheromostatCommand( "TM", '"' . $state . '"' );
        };
    }

    return undef;
}

sub state {
    my ( $self, $device ) = @_;

    return $self->SUPER::state() unless defined $device;
    return undef if ( $self->{zone} == 0 );

    SWITCH: for ($device) {
        /^address/i && do { return $self->{address} };
        /^zone/i    && do { return $self->{zone} };

        /^temp/i        && do { return $self->{temp} };
        /^temperature/i && do { return $self->{temp} };
        /^setpoint/i    && do { return $self->{setpoint} };
        /^zonemode/i    && do { return ReturnString( $self->{zonemode} ) };
        /^zonefanmode/i && do { return ReturnString( $self->{zonefanmode} ) };
        /^fanmode/i     && do { return ReturnString( $self->{zonefanmode} ) };

        /^heatingstage1/i
          && do { return ReturnString( $self->{heatingstage1} ) };
        /^heatingstage2/i
          && do { return ReturnString( $self->{heatingstage2} ) };
        /^coolingstage1/i
          && do { return ReturnString( $self->{coolingstage2} ) };
        /^coolingstage2/i
          && do { return ReturnString( $self->{coolingstage2} ) };

        /^fanstatus/i  && do { return ReturnString( $self->{fanstatus} ) };
        /^shortcycle/i && do { return ReturnString( $self->{shortcycle} ) };
        /^scp/i        && do { return ReturnString( $self->{shortcycle} ) };

        /^systemmode/i && do { return ReturnString( $self->{systemmode} ) };
        /^mode/i       && do { return ReturnString( $self->{systemmode} ) };
        /^fancommand/i && do { return ReturnString( $self->{fancommand} ) };
    }

    return undef;
}

sub ReturnString {
    my ($data) = @_;

    SWITCH: for ($data) {
        /0/ && do { return "off" };
        /1/ && do { return "on" };
        /H/ && do { return "heat" };
        /C/ && do { return "cool" };
        /A/ && do { return "auto" };
        /I/ && do { return "invalid" };
    }
    return "unknown";
}

sub ReturnCommand {
    my ($data) = @_;

    SWITCH: for ($data) {
        /on/i  && do { return "1" };
        /1/    && do { return "1" };
        /0/    && do { return "0" };
        /off/i && do { return "0" };

        #       /h/i                && do { return "1"};
        #       /c/i                && do { return "2"};
        #       /a/i                && do { return "3"};
    }
    return undef;
}

sub SendTheromostatCommand {
    my ( $self, $device, $state ) = @_;
    return undef unless defined $state;
    my $output = sprintf( "A=%u Z=%u O=MH %s=%s",
        $self->{address}, $self->{zone}, $device, $state );
    print "StargateThermostat output $output\n" if $main::Debug{Stargate485};
    push( @stargate485_command_list, $output );
    return 1;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

bsobel@vipmail.com' July 11, 2000

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

