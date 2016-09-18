#!/usr/bin/perl                                                                                 
#
#
#
#    Add these entries to your mh.ini file:
#
#    Xantech_serial_port=COM2
#
#    bsobel@vipmail.com
#    July 19, 2000
#
#    Modified for use on ZPR68-10 by lou@montulli.org
#    Sept 6, 2004
#    Added a bunch of setstate methods
#

use strict;

my @xantech_zone_object_list;
my ( @xantech_command_list, $trasnmitok, $temp );

package Xantech;

#
# This code create the serial port and registers the callbacks we need
#
sub serial_startup {
    if ( $::config_parms{Xantech_serial_port} ) {
        my ($speed) = $::config_parms{Xantech_baudrate} || 9600;
        if (
            &::serial_port_create(
                'Xantech', $::config_parms{Xantech_serial_port},
                $speed,    'none'
            )
          )
        {
            init( $::Serial_Ports{Xantech}{object} );

            # Add to the generic list so check_for_generic_serial_data is called for us automatically
            push( @::Generic_Serial_Ports, 'Xantech' );

            &::Reload_pre_add_hook( \&Xantech::reload_reset, 'persistent' );
            &::MainLoop_pre_add_hook( \&Xantech::check_for_data, 'persistent' );
        }
    }
}

sub init {
    my ($serial_port) = @_;
    $serial_port->error_msg(0);

    #$serial_port->user_msg(1);
    #$serial_port->debug(1);

    $serial_port->parity_enable(1);
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->stopbits(1);

    #$serial_port->is_handshake("none");         #&? Should this be DTR?

    $serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
    $serial_port->rts_active(0);
    select( undef, undef, undef, .100 );    # Sleep a bit
    ::print_log "Xantech init\n" if $main::Debug{xantech};

    $trasnmitok = 1;
}

sub check_for_data {
    if ( my $data = $::Serial_Ports{Xantech}{data_record} ) {
        $main::Serial_Ports{Xantech}{data_record} = undef;
        print "Xantech data=$data\n" if $main::Debug{xantech};

        my (
            $f1, $f2, $f3,  $f4,  $f5,  $f6, $f7,
            $f8, $f9, $f10, $f11, $f12, $f13
          )
          = $data =~
          /\s*(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)/;

        #        ::print_log "Xantech Data: " . $data . "\n";
        #        print "Xantech Decode: " . $f1 . $f2 . $f3 . " etc.\n";

        # Check for numeric response and all 13 fields decoded
        if ( $f1 > 0 and $f13 ne undef ) {

            # Loop thru each zone object
            for my $current_zone_object (@xantech_zone_object_list) {
                next unless $current_zone_object->{zone} == $f1;

                $current_zone_object->set_states_for_next_pass("input:$f2")
                  if ( $current_zone_object->{current_input} ne $f2 );
                $current_zone_object->set_states_for_next_pass("trim:$f3")
                  if ( $current_zone_object->{current_trim} ne $f3 );
                $current_zone_object->set_states_for_next_pass("volume:$f4")
                  if ( $current_zone_object->{current_volume} ne $f4 );
                $current_zone_object->set_states_for_next_pass(
                    "presetbalance:$f5")
                  if ( $current_zone_object->{preset_balance} ne $f5 );
                $current_zone_object->set_states_for_next_pass("balance:$f6")
                  if ( $current_zone_object->{current_balance} ne $f6 );
                $current_zone_object->set_states_for_next_pass(
                    "presettreble:$f7")
                  if ( $current_zone_object->{preset_treble} ne $f7 );
                $current_zone_object->set_states_for_next_pass("treble:$f8")
                  if ( $current_zone_object->{current_treble} ne $f8 );
                $current_zone_object->set_states_for_next_pass("presetbass:$f9")
                  if ( $current_zone_object->{preset_bass} ne $f9 );
                $current_zone_object->set_states_for_next_pass("bass:$f10")
                  if ( $current_zone_object->{current_bass} ne $f10 );
                $current_zone_object->set_states_for_next_pass(
                    $f11 == 1 ? 'on' : 'off' )
                  if ( $current_zone_object->{current_status} ne $f11 );
                $current_zone_object->set_states_for_next_pass(
                    $f12 == 1 ? 'mute:on' : 'mute:off' )
                  if ( $current_zone_object->{current_mute} ne $f12 );
                $current_zone_object->set_states_for_next_pass(
                    "maximumvolume:$f13")
                  if ( $current_zone_object->{maximum_volume} ne $f13 );

                # Apply settings for this zone
                $current_zone_object->{current_input}   = $f2;
                $current_zone_object->{current_trim}    = $f3;
                $current_zone_object->{current_volume}  = $f4;
                $current_zone_object->{preset_balance}  = $f5;
                $current_zone_object->{current_balance} = $f6;
                $current_zone_object->{preset_treble}   = $f7;
                $current_zone_object->{current_treble}  = $f8;
                $current_zone_object->{preset_bass}     = $f9;
                $current_zone_object->{current_bass}    = $f10;
                $current_zone_object->{current_status}  = $f11;
                $current_zone_object->{current_mute}    = $f12;
                $current_zone_object->{maximum_volume}  = $f13;
            }
        }
    }

    # Let's send any pending commands to the unit now.
    if (   @xantech_command_list > 0
        && $trasnmitok
        && !$::Serial_Ports{Xantech}{data} )
    {
        if ( @xantech_command_list > 0 ) {
            ( my $output ) = shift @xantech_command_list;
            print "Xantech Output: " . $output . "\n"
              if ( $main::Debug{xantech} );
            $::Serial_Ports{Xantech}{object}->write( $output . "\r" );
        }
    }

    # Every 30 seconds let's ask the unit to give us the status of all zones
    # We will use this information to keep the zone objects up to date.
    if ( $::New_Second and !( $::Second % 30 ) ) {
        $::Serial_Ports{Xantech}{object}->write("Z00\r");
    }
}

#sub UserCodePostHook
#{
#    #
#    # Reset data for _now functions
#    #
#    $::Serial_Ports{Xantech}{data_record} = '';
#}

sub reload_reset {

    #undef @xantech_zone_object_list;
}

1;

#
# Item object version (this lets us use object links and events)
#
package Xantech_Zone;
@Xantech_Zone::ISA = ('Generic_Item');

sub new {
    my ( $class, $zone ) = @_;

    # see if this zone is already in the object list
    # if it is then return the exiting one
    for my $current_zone_object (@xantech_zone_object_list) {
        if ( $current_zone_object->{zone} == $zone ) {
            return $current_zone_object;
        }
    }

    my $self = { zone => $zone };
    bless $self, $class;

    push( @xantech_zone_object_list, $self );

    #
    # This is data we get from the zone query, default it here and then fill it in
    #
    $self->{current_input}   = "00";
    $self->{current_trim}    = "00";
    $self->{current_volume}  = "00";
    $self->{preset_balance}  = "00C";
    $self->{current_balance} = "00C";
    $self->{preset_treble}   = "06";
    $self->{current_treble}  = "06";
    $self->{preset_bass}     = "06";
    $self->{current_bass}    = "06";
    $self->{current_status}  = "0";
    $self->{current_mute}    = "0";
    $self->{maximum_volume}  = "40";

    my $output = sprintf( "Z%2.2d", $zone );
    push( @xantech_command_list, $output );

    push(
        @{ $$self{states} },
        'on',            'off',        'volume:max',
        'volume:normal', 'volume:min', 'volume:+',
        'volume:-',      'input:+',    'input:-'
    );

    return $self;
}

sub NextInput {
    my ($self) = @_;
    my $Return = $self->{current_input} + 1;
    return $Return > 8 ? 1 : $Return;
}

sub PrevInput {
    my ($self) = @_;
    my $Return = $self->{current_input} - 1;
    return $Return < 1 ? 8 : $Return;
}

sub getstate_mute {
    my ( $self, $substate ) = @_;

    return $self->{current_mute};
}

sub ToggleMute {
    my ($self) = @_;

    print "mute is : $self" . $self->{current_mute} . "\n";
    return $self->{current_mute} > 0 ? 'N' : 'Y';
}

sub SendCommand() {
    my ( $self, $command ) = @_;

    # Queue command
    my $output = "!" . sprintf( "%2.2d", $self->{zone} ) . $command . "+";
    push( @xantech_command_list, $output );

    # Queue query for zone settings so object is updated
    $output = "Z" . sprintf( "%2.2d", $self->{zone} );
    push( @xantech_command_list, $output );
}

#
# Set functions...
#

sub getstate_zone {
    my ( $self, $substate ) = @_;

    return $self->{zone};
}

sub setstate_off {
    my ( $self, $substate ) = @_;
    print "Xantech received set_off with '$substate' substate\n";
    $self->SendCommand("CN");
}

sub setstate_on {
    my ( $self, $substate ) = @_;
    print "Xantech received set_on with '$substate' substate\n";
    $self->SendCommand( sprintf( "I%1.1d", $self->{current_input} ) );
}

sub setstate_mute {
    my ( $self, $substate ) = @_;
    print "Xantech received set_on with '$substate' substate\n";
    $self->SendCommand( "Q" . $self->ToggleMute() );
}

sub setstate_quiet {
    my ( $self, $substate ) = @_;
    print "Xantech received set_on with '$substate' substate\n";
    $self->SendCommand("QY");
}

sub setstate_unquiet {
    my ( $self, $substate ) = @_;
    print "Xantech received set_on with '$substate' substate\n";
    $self->SendCommand("QN");
}

sub getstate_volume {
    my ( $self, $substate ) = @_;

    return $self->{current_volume};
}

sub setstate_volume {
    my ( $self, $substate ) = @_;
    if ( $substate eq 'up' or $substate eq '+' ) {
        $self->SendCommand("LU");
    }
    elsif ( $substate eq 'down' or $substate eq '-' ) {
        $self->SendCommand("LD");
    }
    elsif ( $substate eq 'max' ) {
        $self->SendCommand("V40");
    }
    elsif ( $substate eq 'min' ) {
        $self->SendCommand("V00");
    }
    elsif ( $substate eq 'normal' ) {
        $self->SendCommand("V30");
    }
    else {
        # Presume this is a volume command (check for numeric in substate?)
        $self->SendCommand( sprintf( "V%2.2d", $substate ) );
    }
}

sub setstate_up {
    my ( $self, $substate ) = @_;
    $self->set_volume('up');
}

sub setstate_down {
    my ( $self, $substate ) = @_;
    $self->set_volume('up');
}

sub getstate_input {
    my ( $self, $substate ) = @_;

    return $self->{current_input};
}

sub setstate_input {
    my ( $self, $substate ) = @_;
    if ( $substate eq 'next' or $substate eq '+' ) {
        $self->SendCommand( "I" . $self->NextInput() );
    }
    elsif ( $substate eq 'prev' or $substate eq '-' ) {
        $self->SendCommand( "I" . $self->PrevInput() );
    }
    else {
        $self->SendCommand( sprintf( "I%1.1d", $substate ) );
    }
}

sub setstate_next {
    my ( $self, $substate ) = @_;
    $self->set_input('next');
}

sub setstate_prev {
    my ( $self, $substate ) = @_;
    $self->set_input('prev');
}

sub getstate_treble {
    my ( $self, $substate ) = @_;

    return $self->{current_treble};
}

sub setstate_treble {
    my ( $self, $substate ) = @_;
    $self->SendCommand( sprintf( "T%2.2d", $substate ) );
}

sub getstate_bass {
    my ( $self, $substate ) = @_;

    return $self->{current_bass};
}

sub setstate_bass {
    my ( $self, $substate ) = @_;
    $self->SendCommand( sprintf( "B%2.2d", $substate ) );
}

sub default_setstate {
    my ( $self, $state ) = @_;
    if ( $state eq '+' ) {
        $self->set_volume('up');
    }
    elsif ( $state eq '-' ) {
        $self->set_volume('down');
    }
    else {
        print "$self unknown state request $state\n";
    }
}

sub default_getstate {
    my ( $self, $state ) = @_;
    return $self->{state} if $state eq undef;
    return undef if ( $self->{zone} == 0 );

    if ( $self->{current_status} == 1 ) {
        return 'on';
    }
    else {
        return 'off';
    }
}

1;

