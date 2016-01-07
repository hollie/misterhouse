
=begin comment

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	UPBPIM.pm

Description:
	This is the base interface class for Universal Powerline Bus (UPB), Powerline
	Interface Module (PIM).

	For more information about the UPB protocol:
		http://www.pcslighting.com/downloads.html

	For more information regarding the technical details of the PIM:
		http://www.pcslighting.com/downloads/pulseworx_specifications/PimComm1.5.pdf

Author(s):
    Jason Sharpee
    jason@sharpee.com

	Based loosely on the RCSsTR40.pm code:
	-	Initial version created by Chris Witte <cwitte@xmlhq.com>
	-	Expanded for TR40 by Kirk Bauer <kirk@kaybee.org>

License:
    This free software is licensed under the terms of the GNU public license.

Usage:
	Use these mh.ini parameters to enable this code:

	UPBPIM_serial_port=/dev/ttyS4
	UPBPIM_baudrate=4800
	UPBPIM_network=49
	UPBPIM_moduleid=30
	UPBPIM_password=34554


    Example initialization:

		$myPIM = new UPBPIM("UPBPIM",<networkid>,<networkpassword>,<pimmoduleid>);

		#Turn Light Module ID #0x66 On
		$myPIM->send_upb_cmd("09004466FF236400");
		#Turn Light Module ID #0x66 Off
		$myPIM->send_upb_cmd("09004466FF230000");
		#Turn Light Module ID #0x66 to 50% dim
		$myPIM->send_upb_cmd("09004466FF233200");

Notes:
    - However this code does establish communication sucessfully with the PIM,
      and adding functionality at this point will be somewhat trivial.
      ( The exhausting hardware / serial part for me is seemingly over ;) )

Special Thanks to:
    Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


=cut

use strict;

package UPBPIM;

@UPBPIM::ISA = ('Serial_Item');

my %UPBPIM_Data;

sub serial_startup {
    my ($instance) = @_;

    my $port  = $::config_parms{ $instance . "_serial_port" };
    my $speed = $::config_parms{ $instance . "_baudrate" };
    $UPBPIM_Data{$instance}{'serial_port'} = $port;

    &::serial_port_create( $instance, $port, $speed );
    if ( 1 == scalar( keys %UPBPIM_Data ) ) {    # Add hooks on first call only

        #      &::MainLoop_post_add_hook(\&UPBPIM::poll_all, 1);
        &::MainLoop_pre_add_hook( \&UPBPIM::check_for_data, 1 );
    }
}

sub poll_all {

}

# Takes a hexadecimal string and calculates the checksum in a hexadecimal string
sub get_checksumHex {
    my ($msg) = @_;
    my $bmsg;
    $bmsg = pack( "H*", $msg );
    my @bytes = unpack 'C*', $bmsg;
    my $checksum = 0;
    foreach ( @bytes[ 0 .. $#bytes ] ) {
        $checksum += $_;
    }
    $checksum = ~$checksum;
    $checksum++;
    $checksum &= 0xff;
    $checksum = sprintf( "%02X", $checksum );

    return $checksum;
}

sub check_for_data {
    for my $port_name ( keys %UPBPIM_Data ) {
        &::check_for_generic_serial_data($port_name)
          if $::Serial_Ports{$port_name}{object};
        my $data = $::Serial_Ports{$port_name}{data_record};
        next if !$data;

        #      main::print_log("$port_name got: [$::Serial_Ports{$port_name}{data_record}]");
        $UPBPIM_Data{$port_name}{'obj'}->_parse_data($data);

        $main::Serial_Ports{$port_name}{data_record} = '';

=begin
      if (($UPBPIM_Data{$port_name}{'obj'}->{'last_change'} + 5) == $main::Time) {
         $UPBPIM_Data{$port_name}{'obj'}->{'last_change'} = 0;
         $UPBPIM_Data{$port_name}{'obj'}->_poll();
      }
=cut

    }
}

sub new {
    my ( $class, $port_name, $network_id, $network_password, $device_id ) = @_;
    $port_name = 'UPBPIM' if !$port_name;

    my $self = {};
    $$self{state}            = '';
    $$self{said}             = '';
    $$self{state_now}        = '';
    $$self{port_name}        = $port_name;
    $$self{last_command}     = '';
    $$self{xmit_in_progress} = 0;
    @{ $$self{command_stack} } = ();
    bless $self, $class;
    $UPBPIM_Data{$port_name}{'obj'} = $self;

    #   $UPBPIM_Data{$port_name}{'send_count'} = 0;
    #   push(@{$$self{states}}, 'on', 'off');
    #   $self->_poll();

    #we just turned on the device, lets wait a bit
    $self->set_dtr(1);
    select( undef, undef, undef, 0.15 );

    $self->set_message_mode();
    $self->network_id($network_id)             if defined $network_id;
    $self->network_password($network_password) if defined $network_password;
    $self->device_id($device_id)               if defined $device_id;
    $self->update_registers();
    return $self;
}

sub set_message_mode {
    my ($self) = @_;
    return $self->_send_cmd("\x1770028E\x0D");

}

sub update_registers {
    my ( $self, $start, $end ) = @_;
    my $cmd;
    $start = 0   if not defined $start;
    $end   = 255 if not defined $end;
    $cmd = sprintf( "%02X%02X", $start, $end );
    $cmd .= get_checksumHex($cmd);
    return $self->_send_cmd( "\x12" . $cmd . "\x0D" );
}

sub get_register {
    my ( $self, $start, $end ) = @_;
    $start = 0 if !defined $start;
    $end   = 1 if !defined $end;

    my $response;
    for ( my $index = $start; $index < $start + $end; $index++ ) {
        $response .= sprintf( "%02X", $$self{'registers'}->[$index] );
    }
    return $response;
}

sub get_firwmare_version {
    my ($self) = @_;
    return $self->get_register(10) . $self->get_register(11);
}

sub send_upb_cmd {
    my ( $self, $cmd ) = @_;

    #queue any new commands
    unshift( @{ $$self{command_stack} }, $cmd ) if defined $cmd;

    #	&::print_log("UPB Command stack:@{$$self{command_stack}}:");
    #we dont transmit on top of another xmit
    if ( $$self{xmit_in_progress} != 1 ) {
        $$self{xmit_in_progress} = 1;

        #always send the oldest command first
        $cmd = pop( @{ $$self{command_stack} } );
        if ( defined $cmd ) {

            #put the command back into the stack.. Its not our job to tamper with this array
            push( @{ $$self{command_stack} }, $cmd );
            $cmd .= get_checksumHex($cmd);
            return $self->_send_cmd( "\x14" . $cmd . "\x0D" );
        }
    }
    else {
        return;
    }
}

sub set_register {
    my ( $self, $start, $val ) = @_;
    my $cmd;
    return if !defined $start;

    $cmd = sprintf( "%02X%02X", $start, $val );
    $cmd .= get_checksumHex($cmd);
    return $self->_send_cmd( "\x17" . $cmd . "\x0D" );
}

sub network_id {
    my ( $self, $val ) = @_;
    $self->set_register( 0, $val ) if defined $val;
    return $self->get_register(0);
}

sub device_id {
    my ( $self, $val ) = @_;
    $self->set_register( 1, $val ) if defined $val;
    return $self->get_register(1);
}

sub network_password {
    my ( $self, $val ) = @_;
    $self->set_register( 2, $val ) if defined $val;
    return $self->get_register(2);
}

sub _send_cmd {
    my ( $self, $cmd ) = @_;
    my $instance = $$self{port_name};

    #	print "$::Time_Date: UPBPIM: Executing command $cmd\n" unless $main::config_parms{no_log} =~/UPBPIM/;
    my $data = $cmd;

    #print "PN:$instance:";
    $main::Serial_Ports{$instance}{object}->write($data);
### Dont overrun the controller.. Its easy, so lets wait a bit
    select( undef, undef, undef, 0.15 );
    $$self{'last_change'} = $main::Time;

    #	$self->_poll();
}

sub _poll {
    my ($self) = @_;
    my $instance = $self->{port_name};
}

sub _parse_data {
    my ( $self, $data ) = @_;
##   return if (($$self{'last_change'} + 5) > $main::Time);
    my ( $name, $val );
    $data =~ s/^\s*//;
    $data =~ s/\s*$//;

    #  &::print_log( "UPBPIM: Parsing serial data: $data\n") unless $main::config_parms{no_log} =~/UPBPIM/;

    #PIM to Host Message
    if ( uc( substr( $data, 0, 1 ) ) eq 'P' ) {

        #Confirm that the PIM message has more parts to it
        if ( length($data) >= 2 ) {

            #Register Dump
            if ( uc( substr( $data, 1, 1 ) ) eq 'R' ) {

                #get offset
                my $offset;
                my $bRegisters;
                my @Registers;
                $offset = substr( $data, 2, 2 );
                $offset = hex($offset);
                if ( $offset != 0 ) {

                    # Im too lazy to store this at an offset instead of replacing it entirely
                    &::print_log("Partial Register update not supported");
                }
                else {
                    #Convert to a binary quantity
                    $bRegisters =
                      pack( "H*", substr( $data, 4, length($data) - 4 ) );

                    #Convert to a byte array and replace whole register array
                    @Registers = unpack( "C*", $bRegisters );
                    @{ $$self{'registers'} } = @Registers;
                }
            }

            #UPB Incoming Message
            elsif ( uc( substr( $data, 1, 1 ) ) eq 'U' ) {
                $self->delegate( substr( $data, 2, length($data) ) );
            }

            #UPB Accept command
            elsif ( uc( substr( $data, 1, 1 ) ) eq 'A' ) {

                #dont really care
            }

            #UPB Busy
            elsif ( uc( substr( $data, 1, 1 ) ) eq 'B' ) {
                $$self{xmit_in_progress} = 0;
            }

            #UPB Acknowledgement
            elsif ( uc( substr( $data, 1, 1 ) ) eq 'K' ) {
                $$self{xmit_in_progress} = 0;
                pop( @{ $$self{command_stack} } );
                select( undef, undef, undef, .15 );
                $self->process_command_stack();
            }

            #UPB No Acknowledgement
            elsif ( uc( substr( $data, 1, 1 ) ) eq 'N' ) {
                $$self{xmit_in_progress} = 0;
                &::print_log(
                    "$self->object_name: Reports device does not respond");
                pop( @{ $$self{command_stack} } );
                select( undef, undef, undef, .15 );
                $self->process_command_stack();
            }
        }
    }
}

sub process_command_stack {
    my ($self) = @_;
    ## send any remaining commands in stack
    my $stack_count = @{ $$self{command_stack} };

    #			&::print_log("UPB Command stack2:$stack_count:@{$$self{command_stack}}:");
    if ( $stack_count > 0 ) {

        #send any remaining commands.
        $self->send_upb_cmd();
    }
}

sub add {
    my ( $self, @p_objects ) = @_;

    my @l_objects;

    for my $l_object (@p_objects) {
        if ( $l_object->isa('Group_Item') ) {
            @l_objects = $$l_object{members};
            for my $obj (@l_objects) {
                $self->add($obj);
            }
        }
        else {
            $self->add_item($l_object);
        }
    }
}

sub add_item {
    my ( $self, $p_object ) = @_;

    #    $p_object->tie_items($self);
    push @{ $$self{objects} }, $p_object;

    #request an initial state from the device
    if ( !$p_object->isa('UPB_Link') ) {
        $p_object->set("report");
    }
    return $p_object;
}

sub remove_all_items {
    my ($self) = @_;

    if ( ref $$self{objects} ) {
        foreach ( @{ $$self{objects} } ) {

            #        $_->untie_items($self);
        }
    }
    delete $self->{objects};
}

sub add_item_if_not_present {
    my ( $self, $p_object ) = @_;

    if ( ref $$self{objects} ) {
        foreach ( @{ $$self{objects} } ) {
            if ( $_ eq $p_object ) {
                return 0;
            }
        }
    }
    $self->add_item($p_object);
    return 1;
}

sub remove_item {
    my ( $self, $p_object ) = @_;

    if ( ref $$self{objects} ) {
        for ( my $i = 0; $i < scalar( @{ $$self{objects} } ); $i++ ) {
            if ( $$self{objects}->[$i] eq $p_object ) {
                splice @{ $$self{objects} }, $i, 1;

                #           $p_object->untie_items($self);
                return 1;
            }
        }
    }
    return 0;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    $self->send_upb_cmd($p_state);
}

sub delegate {
    my ( $self, $p_data ) = @_;
    my $network     = unpack( "C", pack( "H*", substr( $p_data, 4, 2 ) ) );
    my $destination = unpack( "C", pack( "H*", substr( $p_data, 6, 2 ) ) );
    my $source      = unpack( "C", pack( "H*", substr( $p_data, 8, 2 ) ) );
    my $isLink      = 0;
    my $transeq     = unpack( "C", pack( "h*", substr( $p_data, 3, 1 ) ) );
    my $count       = $transeq & 0b1100;
    $count = $count >> 2;
    my $sequence = $transeq & 0b0011;

    if ( ( 8 & unpack( "C", pack( "h*", substr( $p_data, 0, 1 ) ) ) ) == 8 ) {
        $isLink = 1;
    }

    # If a packet is being sent with a xmit count greater than 1
    # then make sure we only delagate one packet and not the repeats
    if ( $count > 0 ) {
        my $packet = substr( $p_data, 4, length($p_data) - 6 );
        if (
            $packet ne $$self{last_command}
            or (   $packet eq $$self{last_command}
                && $sequence <= $$self{last_sequence} )
          )
        {
            $$self{last_command}  = $packet;
            $$self{last_sequence} = $sequence;
        }
        else {
            #			&::print_log("UPBPIM: duplicate packet, ignore!");
            return;
        }
    }

    #	&::print_log ("DELEGATE:$network:$source:$destination:$isLink:");
    for my $obj ( @{ $$self{objects} } ) {

        #Match on UPB objects only
        if ( $obj->isa("UPB_Device") or $obj->isa("UPB_Link") ) {

            #networks match
            if ( $network == 0 or $obj->network_id() == $network ) {
                if ( $destination == 0 or $obj->device_id() == $destination ) {

                    #if UPB_Device
                    if ( $obj->isa("UPB_Link") and $isLink == 1 ) {
                        $obj->set( $p_data, $self );
                    }
                    elsif ( !$obj->isa("UPB_Link") and $isLink == 0 ) {
                        $obj->set( $p_data, $self );
                    }
                }
            }
        }
    }
}

## WIP
sub sset {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;

=begin
    # prevent reciprocal sets that can occur because of this method's state
    # propogation
	return if (ref $p_setby and $p_setby->can('get_set_by') and
        $p_setby->{set_by} eq $self);
=cut

    #  	&::print_log($self->get_object_name() . "::set($p_state, $p_setby)");

    # ensure the setting object is associated w/ the current object before
    #  iterating over the children.  At a minimum, main::set_by_to_target
    #  requires current "set_by" to properly navigate the set_by "chain"
    $self->{set_by} = $p_setby;

=begin
	# Propogate states to all member items
	if ( defined $$self{objects} ) {
		my @l_objects = @{$$self{objects}};
		for my $obj (@l_objects) {
			if ( $obj ne $p_setby and $obj ne $self ) { # Dont loop
#               &::print_log($self->get_object_name() . "::set($p_state, $p_setby) -> $$obj{object_name}") if $main::Debug{occupancy};
			        $obj->set($p_state,$self,$p_response);
				}
			}
		}
	}
=cut

    $self->SUPER::set( $p_state, $p_setby, $p_response );
    ## if we called ourselves, then dont send the command out on the bus
    return
      if (  ref $p_setby
        and $p_setby->can('get_set_by')
        and $p_setby->{set_by} eq $self );
    $self->send_upb_cmd($p_state);
}

sub is_member {
    my ( $self, $p_object ) = @_;

    my @l_objects = @{ $$self{objects} };
    for my $l_object (@l_objects) {
        if ( $l_object eq $p_object ) {
            return 1;
        }
    }
    return 0;
}

sub find_members {
    my ( $self, $p_type ) = @_;

    my @l_found;
    my @l_objects = @{ $$self{objects} };
    for my $l_object (@l_objects) {
        if ( $l_object->isa($p_type) ) {
            push @l_found, $l_object;
        }
    }
    return @l_found;
}

=begin
sub default_getstate
{
	my ($self,$p_state) = @_;
	return $$self{m_obj}->state();
}
=cut

1;

