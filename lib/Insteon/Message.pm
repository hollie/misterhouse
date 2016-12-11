
=head1 B<Insteon::BaseMessage>

=head2 DESCRIPTION

Generic base class for L<Insteon|Insteon> object messages, including 
L<Insteon::X10Message|Insteon::Message/Insteon::X10Message>.  Primarily just 
stores variables for the object.

=head2 INHERITS

Nothing

=head2 METHODS

=over

=cut

package Insteon::BaseMessage;

use strict;

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;

    $$self{queue_time}    = &main::get_tickcount;
    $$self{send_attempts} = 0;

    return $self;
}

=item C<interface_data(data)>

Save and retrieve the interface data defined by C<interface_data()>.

=cut

sub interface_data {
    my ( $self, $interface_data ) = @_;
    if ($interface_data) {
        $$self{interface_data} = $interface_data;
    }
    return $$self{interface_data};
}

=item C<queue_time(data)>

Stores the time at which a message was added to the queue.  Used for calculating
how long a message was delayed.

=cut

sub queue_time {
    my ( $self, $queue_time ) = @_;
    if ($queue_time) {
        $$self{queue_time} = $queue_time;
    }
    return $$self{queue_time};
}

=item C<callback(data)>

Data will be evaluated each time the message is sent.

=cut

sub callback {
    my ( $self, $callback ) = @_;
    if ($callback) {
        $$self{callback} = $callback;
    }
    return $$self{callback};
}

=item C<failure_callback(data)>

Data will be evaluated if the maximum number of retry attempts has been made 
and the message is not acknowledged.

=cut

sub failure_callback {
    my ( $self, $callback ) = @_;
    if ($callback) {
        $$self{failure_callback} = $callback;
    }
    return $$self{failure_callback};
}

=item C<success_callback(data)>

Data will be evaluated after the receipt of an ACK from the device for this command.

=cut

sub success_callback {
    my ( $self, $callback ) = @_;
    if ( defined $callback ) {
        $$self{success_callback} = $callback;
    }
    return $$self{success_callback};
}

=item C<send_attempts(data)>

Stores and retrieves the number of times Misterhouse has tried to send the message.

=cut

sub send_attempts {
    my ( $self, $send_attempts ) = @_;
    if ($send_attempts) {
        $$self{send_attempts} = $send_attempts;
    }
    return $$self{send_attempts};
}

=item C<setby(data)>

Stores and retrieves what the source of this message was.

=cut

sub setby {
    my ( $self, $setby ) = @_;
    if ($setby) {
        $$self{setby} = $setby;
    }
    return $$self{setby};
}

=item C<respond(data)>

Stores and retrieves respond variable.

=cut

sub respond {
    my ( $self, $respond ) = @_;
    if ($respond) {
        $$self{respond} = $respond;
    }
    return $$self{respond};
}

=item C<no_hop_increase(data)>

Stores and retrieves no_hop_increase variable, if set to true, when the message
is retried, no additional hops will be added.  Typically used where the failure 
to deliver the last message attempt was not caused by a failure of the object 
to receive the message such as when the PLM is too busy to even attempt sending
the message.

=cut

sub no_hop_increase {
    my ( $self, $no_hop_increase ) = @_;
    if ($no_hop_increase) {
        $$self{no_hop_increase} = $no_hop_increase;
    }
    return $$self{no_hop_increase};
}

=item C<retry_count(data)>

Stores and retrieves the number of times MisterHouse should try to deliver this 
message.  If B<Insteon_retry_count> is set in the ini parameters will default 
to that value, otherwise defaults to 5.  Some messages types have specific 
retry counts, such as L<Insteon::RemoteLinc|Insteon::Controller/Insteon::RemoteLinc>
battery level requests which are only sent once.

=cut

sub retry_count {
    my ( $self, $retry_count ) = @_;
    if ($retry_count) {
        $$self{retry_count} = $retry_count;
    }
    my $result_retry = 5;
    $result_retry = $::config_parms{'Insteon_retry_count'}
      if ( $::config_parms{'Insteon_retry_count'} );
    $result_retry = $$self{retry_count} if ( $$self{retry_count} );
    return $result_retry;
}

=item C<send(p_interface)>

Sends this message using the interface p_interface.  If C<send_attempts> is 
greater than 0 then 
L<Insteon::BaseObject::default_hop_count|Insteon::BaseInsteon/Insteon::BaseObject> 
is increase by one.  Calls C<callback()>
when the message is sent.  

Returns 1 if message sent or 0 if message retry count exceeds C<retry_count()>.

=cut

sub send {
    my ( $self, $interface ) = @_;
    if ( $self->send_attempts < $self->retry_count ) {

        if ( $self->send_attempts > 0 ) {
            if (
                (
                    ref $self->setby && $self->setby->debuglevel( 1, 'insteon' )
                )
                || ( ( !ref $self->setby ) && $::Debug{'insteon'} )
              )
            {
                ::print_log( "[Insteon::BaseMessage] WARN: now resending "
                      . $self->to_string()
                      . " after "
                      . $self->send_attempts
                      . " attempts." );
            }

            # revise default hop count to reflect retries
            if (   ref $self->setby
                && $self->setby->isa('Insteon::BaseObject')
                && !defined( $$self{no_hop_increase} ) )
            {
                $self->setby->retry_count_log(1)
                  if $self->setby->can('retry_count_log');
                if ( $self->setby->default_hop_count < 3 ) {
                    $self->setby->default_hop_count(
                        $self->setby->default_hop_count + 1 );
                }
            }
            elsif (defined( $$self{no_hop_increase} )
                && ref $self->setby
                && $self->setby->isa('Insteon::BaseObject') )
            {
                &main::print_log(
                        "[Insteon::BaseMessage] Hop count not increased for "
                      . $self->setby->get_object_name
                      . " because no_hop_increase flag was set." )
                  if $self->setby->debuglevel( 1, 'insteon' );
                $$self{no_hop_increase} = undef;
            }

            # If No PLM-Receipt has been received for this message
            # then check to see if we are supposed to restart the PLM
            if ( !$self->plm_receipt ) {
                if ( $self->is_plm_down($interface) <= 0 ) {
                    $interface->serial_restart();
                }
            }
        }

        # need to set timeout as a function of retries; also need to alter hop count
        if ( $self->send_attempts <= 0 && ref $self->setby ) {
            $self->setby->outgoing_count_log(1)
              if $self->setby->can('outgoing_count_log');
            $self->setby->outgoing_hop_count( $self->setby->default_hop_count )
              if $self->setby->can('outgoing_hop_count');
        }

        # Clear PLM-Receipt Flag
        $self->plm_receipt(0);

        $self->send_attempts( $self->send_attempts + 1 );
        $interface->_send_cmd( $self, $self->send_timeout );
        if ( $self->callback ) {

            package main;
            eval $self->callback;
            &::print_log("[Insteon::BaseMessage] problem w/ retry callback: $@")
              if $@;

            package Insteon::Message;
        }
        return 1;
    }
    else {
        return 0;
    }

}

=item C<seconds_delayed()>

Returns the number of seconds that elapsed between time set in C<queue_time>
and when this routine was called.

=cut

sub seconds_delayed {
    my ($self)            = @_;
    my $current_tickcount = &main::get_tickcount;
    my $delay_time        = $current_tickcount - $self->queue_time;
    if ( $self->queue_time > $current_tickcount ) {
        return 'unknown';
    }

    $delay_time = $delay_time / 1000;
    return $delay_time;
}

=item C<send_timeout(p_timeout)>

Stores and returns the number of milliseconds, p_timeout, that MisterHouse
should wait before retrying this message again.

=cut

sub send_timeout {
    my ( $self, $timeout ) = @_;
    $$self{send_timeout} = $timeout if defined $timeout;
    return $$self{send_timeout};
}

=item C<to_string()>

Returns the hexadecimal representation of the message.

=cut

sub to_string {
    my ($self) = @_;
    return $self->interface_data;
}

=item C<plm_receipt()>

Used to track whether the PLM has acknowledged receiving this message, either
an ACK or NAK.  This is used to determine situations in which the serial
connection to the PLM may have collapsed and may need to be restarted.

=cut

sub plm_receipt {
    my ( $self, $receipt ) = @_;
    $$self{plm_receipt} = $receipt if defined $receipt;
    return $$self{plm_receipt};
}

=item C<is_plm_down()>

Used to determine whether the PLM needs to be restarted.  The PLM should ACK the
receipt of every command MisterHouse sends to it.  If no ACK is received then
plm_receipt is zero on the retry attempt.  If the number of sequential no ACK 
instances for a specific command reaches the defined number, MisterHouse will 
attempt to reconnect the PLM port.  You can set the threshold to any number you 
like, but if the no ACK number is higher than your retry number, which defaults 
to 5, then the PLM will never be restarted.  The no ACK number can be set using
the ini key:

B<Insteon_PLM_reconnect_count>

by default this number will be set to 99, which in will prevent the PLM from 
being restarted.  If you have PLM disconnect issues, try setting this to 2 or 3.
The restart code has been known to be incompatible with certain perl installations.

=cut

sub is_plm_down {
    my ( $self, $interface ) = @_;
    my $instance        = $$interface{port_name};
    my $reconnect_count = 99;
    $reconnect_count = $::config_parms{ $instance . "_reconnect_count" }
      if defined $::config_parms{ $instance . "_reconnect_count" };
    $$self{is_plm_down} = $reconnect_count unless defined $$self{is_plm_down};
    $$self{is_plm_down} -= 1;
    return $$self{is_plm_down};
}

=back

=head2 INI PARAMETERS

=over

=item Insteon_retry_count

Sets the number of times MisterHouse will attempt to resend a message that has
not been acknowledged.  The default setting is 5.

=back

=head2 AUTHOR

Gregg Limming, Kevin Robert Keegan

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::InsteonMessage>

=head2 DESCRIPTION

Main class for all L<Insteon|Insteon> messages.

=head2 INHERITS

L<Insteon::BaseMessage|Insteon::Message/Insteon::BaseMessage>

=head2 METHODS

=over

=cut

package Insteon::InsteonMessage;
use strict;

@Insteon::InsteonMessage::ISA = ('Insteon::BaseMessage');

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $command_type, $setby, $command, $extra ) = @_;
    my $self = new Insteon::BaseMessage();
    bless $self, $class;

    $self->command_type($command_type);
    $self->setby($setby);
    $self->command($command);
    $self->extra($extra);
    $self->send_timeout(2000);

    return $self;
}

=item C<command_to_hash(msg)>

Takes msg, a hexadecimal message, and returns a hash of the message details.

=cut

sub command_to_hash {
    my ($p_state) = @_;
    my %msg = ();
    my $hopflag = hex( uc substr( $p_state, 13, 1 ) );
    $msg{maxhops}  = $hopflag & 0b0011;
    $msg{hopsleft} = $hopflag >> 2;
    my $msgflag = hex( uc substr( $p_state, 12, 1 ) );
    $msg{is_extended} = ( 0x01 & $msgflag ) ? 1 : 0;
    $msg{cmd_code} = substr( $p_state, 14, 2 );
    $msg{crc_valid} = 1;

    if ( $msg{is_extended} ) {
        $msg{type}        = 'direct';
        $msg{source}      = substr( $p_state, 0, 6 );
        $msg{destination} = substr( $p_state, 6, 6 );
        $msg{extra}       = substr( $p_state, 16, length($p_state) - 16 );
        $msg{crc_valid} =
          ( calculate_checksum( $msg{cmd_code} . $msg{extra} ) eq '00' );
    }
    else {
        $msg{source} = substr( $p_state, 0, 6 );
        $msgflag = $msgflag >> 1;
        if ( $msgflag == 4 ) {
            $msg{type}        = 'broadcast';
            $msg{devcat}      = substr( $p_state, 6, 4 );
            $msg{firmware}    = substr( $p_state, 10, 2 );
            $msg{is_master}   = substr( $p_state, 14, 2 );
            $msg{dev_attribs} = substr( $p_state, 16, 2 );
        }
        elsif ( $msgflag == 6 ) {
            $msg{type}  = 'alllink';
            $msg{group} = substr( $p_state, 10, 2 );
            $msg{extra} = substr( $p_state, 16, 2 )
              if ( length($p_state) >= 18 );
        }
        else {
            $msg{destination} = substr( $p_state, 6, 6 );
            if ( $msgflag == 2 ) {
                $msg{type} = 'cleanup';
                $msg{group} = substr( $p_state, 16, 2 );
            }
            elsif ( $msgflag == 3 ) {
                $msg{type}   = 'cleanup';
                $msg{is_ack} = 1;

                # the "extra" value will contain the controller's group ID
                $msg{extra} = substr( $p_state, 16, 2 );
            }
            elsif ( $msgflag == 7 ) {
                $msg{type}    = 'cleanup';
                $msg{is_nack} = 1;
                $msg{extra}   = substr( $p_state, 16, 2 );
            }
            elsif ( $msgflag == 0 ) {
                $msg{type} = 'direct';
                $msg{extra} = substr( $p_state, 16, 2 );
            }
            elsif ( $msgflag == 1 ) {
                $msg{type}   = 'direct';
                $msg{is_ack} = 1;
                $msg{extra}  = substr( $p_state, 16, 2 );
            }
            elsif ( $msgflag == 5 ) {
                $msg{type}    = 'direct';
                $msg{is_nack} = 1;
                $msg{extra}   = substr( $p_state, 16, 2 );
            }
        }
    }

    return %msg;
}

=item C<command(data)>

Stores and retrieves the Cmd1 value for this message.

=cut

sub command {
    my ( $self, $command ) = @_;
    $$self{command} = $command if $command;
    return $$self{command};
}

=item C<command_type(data)>

Stores and retrieves the Command Type value for this message.

=cut

sub command_type {
    my ( $self, $command_type ) = @_;
    $$self{command_type} = $command_type if $command_type;
    return $$self{command_type};
}

=item C<extra(data)>

Stores and retrieves the extra value for this message.  For standard messages
extra is Cmd2.  For extended messages extra is Cmd2 + D1-D14.

=cut

sub extra {
    my ( $self, $extra ) = @_;
    $$self{extra} = $extra if $extra;
    return $$self{extra};
}

=item C<send_timeout()>

Calculates and returns the number of milliseconds that MisterHouse should wait
for this message to be delivered.  The time is based on message type, command type, 
and hop count.

    Peek Related Messages = 4000
    PLM Scene Commands    = 3000
          Ext   /  Std
    0 Hop 2220    1400
    1 Hop 2690    1700
    2 Hop 3000    1900
    3 Hop 3170    2000

These times were intially calculated by Gregg Limming and appear to have been 
calculated based on experience.  In reality each hop of a standard message 
should take 50 ms and 108 for extended messages.  Each time needs to be at least
doubled to compensate for the return hops as well.

In reality, the PLM and even some Insteon devices appear to react much slower
than the spec defines.  These settings generally appear to work without causing 
errors or too much undue delay.

=cut

sub send_timeout {
    my ( $self, $ignore ) = @_;
    my $hop_count =
      ( ref $self->setby and $self->setby->isa('Insteon::BaseObject') )
      ? $self->setby->default_hop_count
      : $self->send_attempts;
    my $timeout = 1400;
    if ( $self->command eq 'peek' || $self->command eq 'set_address_msb' ) {
        $timeout = 4000;
    }
    elsif ( $self->command_type eq 'all_link_send' ) {

        # note, the following was set to 2000 and that was insufficient
        $timeout = 3000;
    }
    elsif ( $self->command_type eq 'insteon_ext_send' ) {
        if ( $hop_count == 0 ) {
            $timeout = 2220;
        }
        elsif ( $hop_count == 1 ) {
            $timeout = 2690;
        }
        elsif ( $hop_count == 2 ) {
            $timeout = 3000;
        }
        elsif ( $hop_count >= 3 ) {
            $timeout = 3170;
        }
    }
    else {
        if ( $hop_count == 0 ) {
            $timeout = 1400;
        }
        elsif ( $hop_count == 1 ) {
            $timeout = 1700;
        }
        elsif ( $hop_count == 2 ) {
            $timeout = 1900;
        }
        elsif ( $hop_count >= 3 ) {
            $timeout = 2000;
        }
    }
    if ( ref $self->setby and $self->setby->isa('Insteon::BaseObject') ) {
        $timeout = int( $timeout * $self->setby->timeout_factor );
    }
    return $timeout;
}

=item C<to_string()>

Returns text based human readable representation of the message.

=cut

sub to_string {
    my ($self) = @_;
    my $result = '';
    if ( $self->setby ) {
        $result .= 'obj=' . $self->setby->get_object_name;
    }
    if ($result) {
        $result .= '; ';
    }
    if ( $self->command ) {
        $result .= 'command=' . $self->command;
    }
    else {
        $result .= 'interface_data=' . $self->interface_data;
    }
    if ( $self->extra ) {
        $result .= '; extra=' . $self->extra;
    }

    return $result;
}

=item C<interface_data(data)>

Stores data as the hexadecimal message, or if data is not specified, then derives
the hexadecimal message and returns it.

=cut

sub interface_data {
    my ( $self, $interface_data ) = @_;
    my $result = $self->SUPER::interface_data($interface_data);
    if (
        !($result)
        && (   ( $self->command_type eq 'insteon_send' )
            or ( $self->command_type eq 'insteon_ext_send' )
            or ( $self->command_type eq 'all_link_send' )
            or ( $self->command_type eq 'all_link_direct_cleanup' ) )
      )
    {
        return $self->_derive_interface_data();
    }
    else {
        return $result;
    }
}

=item C<_derive_interface_data()>

Converts all of the attributes set for this message into a hexadecimal message
that can be sent to the PLM.  Will add checksums and crcs when necessary.

=cut

sub _derive_interface_data {

    my ($self) = @_;
    my $cmd = '';
    my $level;
    if ( $self->command_type =~ /all_link_send/i ) {
        $cmd .= $self->setby->group;
    }
    else {
        my $hop_count = $self->setby->default_hop_count;
        $cmd .= $self->setby->device_id();
        if ( $self->command_type =~ /insteon_ext_send/i ) {
            if ( $hop_count == 0 ) {
                $cmd .= '10';
            }
            elsif ( $hop_count == 1 ) {
                $cmd .= '15';
            }
            elsif ( $hop_count == 2 ) {
                $cmd .= '1A';
            }
            elsif ( $hop_count >= 3 ) {
                $cmd .= '1F';
            }
        }
        elsif ( $self->command_type =~ /all_link_direct_cleanup/i ) {
            if ( $hop_count == 0 ) {
                $cmd .= '40';
            }
            elsif ( $hop_count == 1 ) {
                $cmd .= '45';
            }
            elsif ( $hop_count == 2 ) {
                $cmd .= '4A';
            }
            elsif ( $hop_count >= 3 ) {
                $cmd .= '4F';
            }
        }
        else {
            if ( $hop_count == 0 ) {
                $cmd .= '00';
            }
            elsif ( $hop_count == 1 ) {
                $cmd .= '05';
            }
            elsif ( $hop_count == 2 ) {
                $cmd .= '0A';
            }
            elsif ( $hop_count >= 3 ) {
                $cmd .= '0F';
            }
        }
    }
    $cmd .=
      unpack( "H*",
        pack( "C", $self->setby->message_type_code( $self->command ) ) );
    if ( $self->extra ) {
        $cmd .= $self->extra;
    }
    elsif ( $self->command_type eq 'insteon_send' )
    {    # auto append '00' if no extra defined for a standard insteon send
        $cmd .= '00';
    }

    if ( $self->command_type eq 'insteon_ext_send' and $$self{add_crc16} ) {
        if ( length($cmd) < 40 ) {
            main::print_log( "[Insteon::InsteonMessage] WARN: insert_crc16 "
                  . "failed; cmd to short: $cmd" );
        }
        else {
            $cmd =
              substr( $cmd, 0, 36 ) . calculate_crc16( substr( $cmd, 8, 28 ) );
        }
    }
    elsif ( $self->command_type eq 'insteon_ext_send'
        and $self->setby->engine_version eq 'I2CS' )
    {
        #$message is the entire insteon command (no 0262 PLM command)
        # i.e. '02622042d31f2e000107110000000000000000000000'
        #                     111111111122222222223333333333
        #           0123456789012345678901234567890123456789
        #          '2042d31f2e000107110000000000000000000000'
        if ( length($cmd) < 40 ) {
            main::print_log( "[Insteon::InsteonMessage] WARN: insert_checksum "
                  . "failed; cmd to short: $cmd" );
        }
        else {
            $cmd = substr( $cmd, 0, 38 )
              . calculate_checksum( substr( $cmd, 8, 30 ) );
        }
    }

    return $cmd;

}

=item C<calculate_checksum( string )>

Calculates a checksum of all hex bytes in the string.  Returns two hex nibbles
that represent the checksum in hex.  One useful characteristic of the checksum
is that summing over all the bytes "including" the checksum will always equal 00. 
This makes it very easy to validate a checksum.

=cut

sub calculate_checksum {
    my ($string) = @_;

    #returns 2 characters as hex nibbles (e.g. AA)
    my $sum = 0;
    $sum += hex($_) for ( unpack( '(A2)*', $string ) );
    return unpack( 'H2', chr( ( ~$sum + 1 ) & 0xff ) );
}

=item C<calculate_crc16( string )>

Calculates a two byte CRC value of string.  This two byte CRC differs from the 
one byte checksum used in other extended commands. This CRC calculation is known
to be used by the 2441TH Insteon Thermostat as well as the iMeter INSTEON device. 
It may be used by other devices in the future.
 
The calculation if the crc value involves data bytes from command 1 to the data 12 
byte. This function will return two bytes, which are generally added to the 
data 13 & 14 bytes in an extended message.

To add a crc16 to a message set the $$message{add_crc16} flag to true.

=cut

sub calculate_crc16 {

    #This function is nearly identical to the C++ sample provided by
    #smartlabs, with only minor modifications to make it work in perl
    my ($string) = @_;
    my $crc = 0;
    for ( unpack( '(A2)*', $string ) ) {
        my $byte = hex($_);

        for ( my $bit = 0; $bit < 8; $bit++ ) {
            my $fb = $byte & 1;
            $fb = ( $crc & 0x8000 ) ? $fb ^ 1 : $fb;
            $fb = ( $crc & 0x4000 ) ? $fb ^ 1 : $fb;
            $fb = ( $crc & 0x1000 ) ? $fb ^ 1 : $fb;
            $fb = ( $crc & 0x0008 ) ? $fb ^ 1 : $fb;
            $crc = ( ( $crc << 1 ) & 0xFFFF ) | $fb;
            $byte = $byte >> 1;
        }
    }
    return uc( sprintf( "%x", $crc ) );
}

=back

=head2 AUTHOR

Gregg Limming, Kevin Robert Keegan, Michael Stovenour

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<Insteon::X10Message>

=head2 DESCRIPTION

Main class for all L<Insteon|Insteon> X10 messages.

=head2 INHERITS

L<Insteon::BaseMessage|Insteon::Message/Insteon::BaseMessage>

=head2 METHODS

=over

=cut

package Insteon::X10Message;
use strict;

@Insteon::X10Message::ISA = ('Insteon::BaseMessage');

my %x10_house_codes = (
    a => 0x6,
    b => 0xE,
    c => 0x2,
    d => 0xA,
    e => 0x1,
    f => 0x9,
    g => 0x5,
    h => 0xD,
    i => 0x7,
    j => 0xF,
    k => 0x3,
    l => 0xB,
    m => 0x0,
    n => 0x8,
    o => 0x4,
    p => 0xC
);

my %mh_house_codes = (
    '6' => 'a',
    'e' => 'b',
    '2' => 'c',
    'a' => 'd',
    '1' => 'e',
    '9' => 'f',
    '5' => 'g',
    'd' => 'h',
    '7' => 'i',
    'f' => 'j',
    '3' => 'k',
    'b' => 'l',
    '0' => 'm',
    '8' => 'n',
    '4' => 'o',
    'c' => 'p'
);

my %x10_unit_codes = (
    1  => 0x6,
    2  => 0xE,
    3  => 0x2,
    4  => 0xA,
    5  => 0x1,
    6  => 0x9,
    7  => 0x5,
    8  => 0xD,
    9  => 0x7,
    10 => 0xF,
    a  => 0xF,
    11 => 0x3,
    b  => 0x3,
    12 => 0xB,
    c  => 0xB,
    13 => 0x0,
    d  => 0x0,
    14 => 0x8,
    e  => 0x8,
    15 => 0x4,
    f  => 0x4,
    16 => 0xC,
    g  => 0xC

);

my %mh_unit_codes = (
    '6' => '1',
    'e' => '2',
    '2' => '3',
    'a' => '4',
    '1' => '5',
    '9' => '6',
    '5' => '7',
    'd' => '8',
    '7' => '9',
    'f' => 'a',
    '3' => 'b',
    'b' => 'c',
    '0' => 'd',
    '8' => 'e',
    '4' => 'f',
    'c' => 'g'
);

my %x10_commands = (
    on             => 0x2,
    j              => 0x2,
    off            => 0x3,
    k              => 0x3,
    bright         => 0x5,
    l              => 0x5,
    dim            => 0x4,
    m              => 0x4,
    preset_dim1    => 0xA,
    preset_dim2    => 0xB,
    all_off        => 0x0,
    p              => 0x0,
    all_lights_on  => 0x1,
    o              => 0x1,
    all_lights_off => 0x6,
    status         => 0xF,
    status_on      => 0xD,
    status_off     => 0xE,
    hail_ack       => 0x9,
    ext_code       => 0x7,
    ext_data       => 0xC,
    hail_request   => 0x8
);

my %mh_commands = (
    '2' => 'J',
    '3' => 'K',
    '5' => 'L',
    '4' => 'M',
    'a' => 'preset_dim1',
    'b' => 'preset_dim2',

    #						'0' => 'all_off',
    '0' => 'P',

    #						'1' => 'all_lights_on',
    '1' => 'O',
    '6' => 'all_lights_off',
    'f' => 'status',
    'd' => 'status_on',
    'e' => 'status_off',
    '9' => 'hail_ack',
    '7' => 'ext_code',
    'c' => 'ext_data',
    '8' => 'hail_request'
);

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $interface_data ) = @_;
    my $self = new Insteon::BaseMessage();
    bless $self, $class;

    $self->interface_data($interface_data);
    $self->send_timeout(2000);

    return $self;
}

=item C<get_formatted_data()>

Converts an X10 message from the interface into the generic humand readable X10 
message format.

=cut

sub get_formatted_data {
    my ($self) = @_;

    my $data = $self->interface_data;

    my $msg = undef;
    if ( uc( substr( $data, length($data) - 2, 2 ) ) eq '00' ) {
        $msg = "X";
        $msg .= uc( $mh_house_codes{ substr( $data, 4, 1 ) } );
        $msg .= uc( $mh_unit_codes{ substr( $data, 5, 1 ) } );
        for ( my $index = 6; $index < length($data) - 2; $index += 2 ) {
            $msg .= uc( $mh_house_codes{ substr( $data, $index, 1 ) } );
            $msg .= uc( $mh_commands{ substr( $data, $index + 1, 1 ) } );
        }
    }
    elsif ( uc( substr( $data, length($data) - 2, 2 ) ) eq '80' ) {
        $msg = "X";
        $msg .= uc( $mh_house_codes{ substr( $data, 4, 1 ) } );
        $msg .= uc( $mh_commands{ substr( $data, 5, 1 ) } );
        for ( my $index = 6; $index < length($data) - 2; $index += 2 ) {
            $msg .= uc( $mh_house_codes{ substr( $data, $index, 1 ) } );
            $msg .= uc( $mh_commands{ substr( $data, $index + 1, 1 ) } );
        }
    }

    return $msg;
}

=item C<generate_commands()>

Generates and returns the X10 hexadecimal message for sending to the PLM.

=cut

sub generate_commands {
    my ( $p_state, $p_setby ) = @_;

    my @data = ();

    my $cmd = $p_state;
    $cmd =~ s/\:.*$//;
    $cmd = lc($cmd);
    my $msg;

    my $id = lc( $p_setby->{id_by_state}{$cmd} );

    my $hc = lc( substr( $p_setby->{x10_id}, 1, 1 ) );
    my $uc = lc( substr( $p_setby->{x10_id}, 2, 1 ) );

    if ( $hc eq undef ) {
        &main::print_log(
            "[Insteon::Message] Object:$p_setby Doesnt have an x10 id (yet)");
        return undef;
    }

    if ( $uc eq undef ) {
        &main::print_log("[Insteon::Message] Message is for entire HC")
          if ( ref $p_setby && $p_setby->debuglevel( 1, 'insteon' ) );
    }
    else {

        #Every X10 message starts with the House and unit code
        $msg = substr(
            unpack(
                "H*", pack( "C", $x10_house_codes{ substr( $id, 1, 1 ) } )
            ),
            1, 1
        );
        $msg .= substr(
            unpack( "H*", pack( "C", $x10_unit_codes{ substr( $id, 2, 1 ) } ) ),
            1, 1
        );
        $msg .= "00";
        &main::print_log( "[Insteon_PLM] x10 sending code: "
              . uc( $hc . $uc )
              . " as insteon msg: "
              . $msg )
          if ( ref $p_setby && $p_setby->debuglevel( 1, 'insteon' ) );

        push @data, $msg;
    }

    my $ecmd;

    #Iterate through the rest of the pairs of nibbles
    my $spos = 3;
    if ( $uc eq undef ) { $spos = 1; }

    #	&::print_log("PLM:PAIR:$id:$spos:$ecmd:");
    for ( my $pos = $spos; $pos < length($id); $pos++ ) {
        $msg = substr(
            unpack(
                "H*", pack( "C", $x10_house_codes{ substr( $id, $pos, 1 ) } )
            ),
            1, 1
        );
        $pos++;

        #look for an explicit command
        $ecmd = substr( $id, $pos, length($id) - $pos );
        my $x10_arg = $ecmd;
        if ( defined $x10_commands{$ecmd} ) {
            $msg .=
              substr( unpack( "H*", pack( "C", $x10_commands{$ecmd} ) ), 1, 1 );
            $pos += length($id) - $pos - 1;
        }
        else {
            $x10_arg = $x10_commands{ substr( $id, $pos, 1 ) };
            $msg .= substr(
                unpack(
                    "H*", pack( "C", $x10_commands{ substr( $id, $pos, 1 ) } )
                ),
                1, 1
            );
        }
        $msg .= "80";

        &main::print_log( "[Insteon_PLM] x10 sending code: "
              . uc( $hc . $x10_arg )
              . " as insteon msg: "
              . $msg )
          if ( ref $p_setby && $p_setby->debuglevel( 1, 'insteon' ) );

        push @data, $msg;

    }

    return @data;
}

=back

=head2 AUTHOR

Gregg Limming

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;
