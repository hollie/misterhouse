
=head1 B<Insteon::EZIO8SA>

=head2 SYNOPSIS

In user code:

   use Insteon::EZIO8SA;
   $ezio_device = new Insteon::EZIO8SA('12.34.56:00', $myPLM);

In items.mht:

    INSTEON_EZIO8SA, 12.34.56:00, io_device, io_group

Creating the object:
	
    use Insteon::EZIO8SA;
    $ezio_device = new Insteon::EZIO8SA('12.34.56:00', $myPLM);

Turning on a relay:
	
    $v_relay_on = new Voice_Cmd "Turn on relay [1,2,3,4,5,6,7,8]";
    if (my $relay = state_now $v_relay_on) {
    	set_relay $ezio_device "$relay", "on";
    }

Turning off a relay:
	
    $v_relay_off = new Voice_Cmd "Turn off relay [1,2,3,4,5,6,7,8]";
    if (my $relay = state_now $v_relay_off) {
    	set_relay $ezio_device "$relay", "off";
    }

Requesting relay status:
	
    $v_relay_status = new Voice_Cmd "Request relay status";
    if (state_now $v_relay_status) {
    	request_status $ezio_device;
    }

=head2 DESCRIPTION

Provides basic support for the EZIO8SA.

=head2 INHERITS

L<Insteon::BaseDevice|Insteon::BaseInsteon/Insteon::BaseDevice>

=head2 METHODS

=over

=cut

use strict;
use Insteon::BaseInsteon;

package Insteon::EZIO8SA;

@Insteon::EZIO8SA::ISA = ('Insteon::BaseDevice');

our %message_types = (
    %Insteon::BaseDevice::message_types,
    output_relay_on   => 0x45,
    output_relay_off  => 0x46,
    write_output_port => 0x48,
    read_input_port   => 0x49,
    get_sensors_value => 0x4A,
    ezio_control      => 0x4F
);

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $p_deviceid, $p_interface ) = @_;

    my $self = new Insteon::BaseDevice( $p_deviceid, $p_interface );
    bless $self, $class;
    $$self{relay_1} = undef;
    $$self{relay_2} = undef;
    $$self{relay_3} = undef;
    $$self{relay_4} = undef;
    $$self{relay_5} = undef;
    $$self{relay_6} = undef;
    $$self{relay_7} = undef;
    $$self{relay_8} = undef;
    $self->restore_data( 'relay_1', 'relay_2', 'relay_3', 'relay_4', 'relay_5', 'relay_6', 'relay_7', 'relay_8' );
    $$self{message_types} = \%message_types;
    return $self;
}

=item C<request_status()>

Sends a message to the device requesting the relay status.  The response from the
device is printed to the log and stores the result in memory. 

=cut

sub request_status {
    my ( $self, $requestor ) = @_;
    my $subcmd = '02';
    my $message = new Insteon::InsteonMessage( 'insteon_send', $self, 'ezio_control', $subcmd );
    $self->_send_cmd($message);
    return;
}

#Deprecated Routine Name
sub poll_relay_status {
    my ($self) = @_;
    $self->request_status();
}

=item C<set_relay(relay_id, relay_state)>

Used to directly control relays.  Valve_id may be 1-8, relay_state may be on 
or off.

=cut

sub set_relay {
    my ( $self, $relay_id, $state ) = @_;
    my $subcmd = sprintf( "%02X", $relay_id - 1 );
    my $cmd = undef;
    if ( lc($state) eq 'on' ) {
        $cmd = 'output_relay_on';
    }
    elsif ( lc($state) eq 'off' ) {
        $cmd = 'output_relay_off';
    }
    unless ( $cmd and $subcmd ) {
        &::print_log("Insteon::EZIO8SA] ERROR: You must specify a relay number and a valid state (ON or OFF)")
          if $self->debuglevel( 1, 'insteon' );
        return;
    }
    my $message = new Insteon::InsteonMessage( 'insteon_send', $self, $cmd, $subcmd );
    $self->_send_cmd($message);
    return;
}

=item C<_is_info_request()>

Used to intercept and handle unique EZIO8SA messages, all others are passed on
to C<Insteon::BaseObject::_is_info_request()|Insteon::BaseInsteon/Insteon::BaseObject>.

=cut

sub _is_info_request {
    my ( $self, $cmd, $ack_setby, %msg ) = @_;
    my $is_info_request = 0;
    if (   $cmd eq 'ezio_control'
        or $cmd eq 'output_relay_on'
        or $cmd eq 'output_relay_off'
        or $cmd eq 'write_output_port'
        or $cmd eq 'read_input_port' )
    {
        $is_info_request = 1;
        $self->_process_status( $msg{extra} );
    }
    else {
        #Check if this was a generic info_request
        $is_info_request = $self->SUPER::_is_info_request( $cmd, $ack_setby, %msg );
    }
    return $is_info_request;

}

sub _process_status {
    my ( $self, $val ) = @_;
    $val              = hex($val);
    $$self{'relay_1'} = $val & 1;
    $$self{'relay_2'} = ( $val & 2 ) / 2;
    $$self{'relay_3'} = ( $val & 4 ) / 4;
    $$self{'relay_4'} = ( $val & 8 ) / 8;
    $$self{'relay_5'} = ( $val & 16 ) / 16;
    $$self{'relay_6'} = ( $val & 32 ) / 32;
    $$self{'relay_7'} = ( $val & 64 ) / 64;
    $$self{'relay_8'} = ( $val & 128 ) / 128;
    &::print_log( "[Insteon::EZIO8SA]"
          . " relay_1: $$self{'relay_1'}, relay_2: $$self{'relay_2'},"
          . " relay_3: $$self{'relay_3'}, relay_4: $$self{'relay_4'},"
          . " relay_5: $$self{'relay_5'}, relay_6: $$self{'relay_6'},"
          . " relay_7: $$self{'relay_7'}, relay_8: $$self{'relay_8'}" );
}

=item C<_process_message()>

Handles incoming messages from the device which are unique to this device, 
all other responses are handed off to the C<Insteon::BaseObject::_process_message()>.

=cut

sub _process_message {
    my ( $self, $p_setby, %msg ) = @_;
    my $clear_message = 0;
    my $pending_cmd   = ( $$self{_prior_msg} ) ? $$self{_prior_msg}->command : $msg{command};
    my $ack_setby     = ( ref $$self{m_status_request_pending} ) ? $$self{m_status_request_pending} : $p_setby;
    if ( $msg{is_ack} && $self->_is_info_request( $pending_cmd, $ack_setby, %msg ) ) {
        $clear_message = 1;
        $$self{m_status_request_pending} = 0;
        $self->_process_command_stack(%msg);
    }
    elsif ( $msg{type} eq 'broadcast' && $msg{cmd_code} eq '27' ) {

        #These are the broadcast status messages from the device.
        $self->_process_status( $msg{dev_attribs} );
        ::print_log("[Insteon::EZIO8SA] Received broadcast status update.")
          if $self->debuglevel( 2, 'insteon' );
        $self->_process_command_stack(%msg);
    }

    # The device uses cmd 0x41 differently depending on STD or EXT Msgs
    elsif ( $msg{command} eq "output_relay_off" && $msg{is_extended} ) {

        #Clear message from message queue
        $clear_message = 1;
        $self->_process_command_stack(%msg);
    }
    else {
        $clear_message = $self->SUPER::_process_message( $p_setby, %msg );
    }
    return $clear_message;
}

=back

=head2 AUTHOR

DoumP

The code is derived from the Irrigation module

=head2 SEE ALSO

L<http://smartenit.com/sandbox/downloads/EZIO8SA_Quick-Start.pdf>,
L<http://smartenit.com/sandbox/downloads/EZIO8SA_Combo_Quick-Start.pdf>

=head1 EZIO8SA_INPUT

=head2 DESCRIPTION

A child object for an ezio_device input.

=head2 SYNOPSIS

In items.mht:

    INSTEON_EZIO8SA_INPUT, $io_device:input_num, io_device, io_group

=over

=cut

=head1 EZIO8SA_RELAY

=head2 DESCRIPTION

A child object for an ezio_device relay.

=head2 SYNOPSIS

When defining the children, you need to identify who their parent is.

        $relay_1 = new Insteon::EZIO8SA_relay($ezio_device, 1);
        $relay_1->set(ON); #Turn ON the relay for the default time
        $relay_1->set('5 min'); #Turn ON the relay for 5 minutes only
        $relay_1->set_states('off', '5 min', 'on'); #set the states to display

In items.mht:

    INSTEON_EZIO8SA_RELAY, $ezio_device, relay_num, io_device, io_group

=head2 AUTHOR

DoumP

The code is derived from the Irrigation module

=head2 INHERITS

B<Generic_Item>

=head1 Methods

=over

=cut

package Insteon::EZIO8SA_relay;
use strict;

@Insteon::EZIO8SA_relay::ISA = ('Generic_Item');

sub new {
    my ( $class, $parent, $relay ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = $parent;
    $$self{relay}  = $relay;

    #	@{$$self{states}} = ('Off', '5 min', '15 min', ' 30 min', 'On');
    $$self{parent}{ 'child_relay_' . $relay } = $self;
    return $self;
}

=item C<set()>

Use just like the set function for any other descendant of a Generic_Item.

Accepts on and off commands.

=cut

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    ::print_log( "[Insteon::EZIO8SA] Received request to set " . $self->get_object_name . " $p_state." );
    $self->SUPER::set( $p_state, $p_setby, $p_response );
    $$self{parent}->set_relay( $$self{relay}, $p_state );
}

sub set2 {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( $p_state =~ /(on|off)/i ) {
        ::print_log( "[Insteon::EZIO8SA] Received request to set " . $self->get_object_name . " $p_state." . $$self{relay} );
        $$self{parent}->set_relay( $$self{relay}, $p_state );
    }
    else {
        ::print_log( "[Insteon::EZIO8SA] Cannot set " . $self->get_object_name . " to unknown state of $p_state." );
    }
}

sub set_receive {
    my ( $self, $p_state ) = @_;
    $self->SUPER::set($p_state);
}

=back

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;
