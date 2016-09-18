
=head1 B<Insteon_PLM>

=head2 SYNOPSIS

---Example Code and Usage---

=head2 DESCRIPTION

This is the base interface class for Insteon Power Line Modem (PLM)

=head2 INHERITS

L<Serial_Item|Serial_Item>,
L<Insteon::BaseInterface|Insteon::BaseInterface>

=head2 METHODS

=over

=cut

package Insteon_PLM;

use strict;
use Insteon;
use Insteon::BaseInterface;
use Insteon::BaseInsteon;
use Insteon::AllLinkDatabase;
use Insteon::MessageDecoder;

#@Insteon_PLM::ISA = ('Serial_Item','Socket_Item','Insteon::BaseInterface');
my $PLM_socket = undef;

my %prefix = (

    #PLM Serial Commands
    insteon_received        => '0250',
    insteon_ext_received    => '0251',
    x10_received            => '0252',
    all_link_complete       => '0253',
    plm_button_event        => '0254',
    plm_user_reset          => '0255',
    all_link_clean_failed   => '0256',
    all_link_record         => '0257',
    all_link_clean_status   => '0258',
    plm_info                => '0260',
    all_link_send           => '0261',
    insteon_send            => '0262',
    insteon_ext_send        => '0262',
    all_link_direct_cleanup => '0262',
    x10_send                => '0263',
    all_link_start          => '0264',
    all_link_cancel         => '0265',
    plm_reset               => '0267',
    all_link_first_rec      => '0269',
    all_link_next_rec       => '026a',
    plm_set_config          => '026b',
    plm_led_on              => '026d',
    plm_led_off             => '026e',
    all_link_manage_rec     => '026f',
    insteon_nak             => '0270',
    insteon_ack             => '0271',
    rf_sleep                => '0272',
    plm_get_config          => '0273'
);

=item C<serial_startup()>

Creates a new serial port connection.

=cut

sub serial_startup {
    my ($instance) = @_;
    my $PLM_use_tcp = 0;
    $PLM_use_tcp = $::config_parms{ $instance . "_use_TCP" };
    if ( $PLM_use_tcp == 1 ) { return; }

    my $port = $::config_parms{ $instance . "_serial_port" };
    if ( !defined($port) ) {
        main::print_log(
            "WARN: " . $instance . "_serial_port missing from INI params!" );
    }
    my $speed = 19200;

    &::print_log("[Insteon_PLM] serial:$port:$speed");
    &::serial_port_create( $instance, $port, $speed, 'none', 'raw' );

}

=item C<serial_restart()>

Attempt to restart/reconnect the serial port connection.

=cut

sub serial_restart {
    my ($self)      = @_;
    my $instance    = $$self{port_name};
    my $PLM_use_tcp = $::config_parms{ $instance . "_use_TCP" };

    # TCP Port gets reconnected elsewhere
    return if $PLM_use_tcp;

    ::print_log(
            "[Insteon_PLM] WARN: The PLM did not respond to the last command."
          . " The port may have closed, attempting to reopen the port." );

    #prep vars
    my $port  = $::config_parms{ $instance . "_serial_port" };
    my $speed = 19200;

    #close the port
    ::serial_port_close($instance);

    #Try and open it again
    ::serial_port_create( $instance, $port, $speed, 'none', 'raw' );
}

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $port_name, $p_deviceid ) = @_;
    $port_name = 'Insteon_PLM' if !$port_name;
    my $port        = $::config_parms{ $port_name . "_serial_port" };
    my $PLM_use_tcp = 0;
    $PLM_use_tcp = $::config_parms{ $port_name . "_use_TCP" };
    my $PLM_tcp_host = 0;
    my $PLM_tcp_port = 0;

    if ( $PLM_use_tcp == 1 ) {
        @Insteon_PLM::ISA = ( 'Socket_Item', 'Insteon::BaseInterface' );
        $PLM_tcp_host     = $::config_parms{ $port_name . "_TCP_host" };
        $PLM_tcp_port     = $::config_parms{ $port_name . "_TCP_port" };
        &::print_log(
            "[Insteon_PLM] 2412N using TCP,  tcp_host=$PLM_tcp_host,  tcp_port=$PLM_tcp_port"
        );
    }
    else {
        if ( !defined($port) ) {
            main::print_log( "WARN: "
                  . $port_name
                  . "_serial_port missing from INI params!" );
        }
        @Insteon_PLM::ISA = ( 'Serial_Item', 'Insteon::BaseInterface' );
        $PLM_use_tcp = 0;
        &::print_log("[Insteon_PLM] 2412[US] using serial,  serial_port=$port");
    }

    my $self = new Insteon::BaseInterface();
    $$self{state}                = '';
    $$self{said}                 = '';
    $$self{state_now}            = '';
    $$self{port_name}            = $port_name;
    $$self{port}                 = $port;
    $$self{use_tcp}              = $PLM_use_tcp;
    $$self{tcp_host}             = $PLM_tcp_host;
    $$self{tcp_port}             = $PLM_tcp_port;
    $$self{last_command}         = '';
    $$self{_prior_data_fragment} = '';
    bless $self, $class;
    $self->restore_data( 'debug', 'corrupt_count_log' );
    $$self{corrupt_count_log} = 0;
    $$self{aldb}              = new Insteon::ALDB_PLM($self);

    if ( $PLM_use_tcp == 1 ) {
        my $tcp_hostport = "$PLM_tcp_host:$PLM_tcp_port";

        $PLM_socket =
          new Socket_Item( undef, undef, $tcp_hostport, 'Insteon PLM 2412N',
            'tcp', 'raw' );
        start $PLM_socket;
        $$self{socket} = $PLM_socket;
    }

    &Insteon::add($self);

    $self->device_id($p_deviceid) if defined $p_deviceid;

    $$self{xmit_delay} = $::config_parms{Insteon_PLM_xmit_delay};
    $$self{xmit_delay} = 0.25
      unless defined $$self{xmit_delay};    # and $$self{xmit_delay} > 0.125;
    &::print_log(
        "[Insteon_PLM] setting default xmit delay to: $$self{xmit_delay}");
    $$self{xmit_x10_delay} = $::config_parms{Insteon_PLM_xmit_x10_delay};
    $$self{xmit_x10_delay} = 0.5
      unless defined $$self{xmit_x10_delay} and $$self{xmit_x10_delay} > 0.5;
    &::print_log(
        "[Insteon_PLM] setting x10 xmit delay to: $$self{xmit_x10_delay}");
    $self->_clear_timeout('xmit');
    $self->_clear_timeout('command');

    return $self;
}

=item C<corrupt_count_log([type]>

Sets or gets the number of corrupt message that have arrived that could not be
associated with any device since the last time C<reset_message_stats> was called.
These are generally instances in which the from device ID is corrupt.

If type is set, to any value, will increment corrupt count by one.

Returns: current corrupt count.

=cut 

sub corrupt_count_log {
    my ( $self, $corrupt_count_log ) = @_;
    $$self{corrupt_count_log}++ if $corrupt_count_log;
    return $$self{corrupt_count_log};
}

=item C<reset_message_stats>

Resets the retry, fail, outgoing, incoming, and corrupt message counters.

=cut 

sub reset_message_stats {
    my ($self) = @_;
    $$self{corrupt_count_log} = 0;
}

=item C<restore_string()>

This is called by mh on exit to save the cached ALDB of a device to persistant data.

=cut

sub restore_string {
    my ($self) = @_;
    my $restore_string = $self->SUPER::restore_string();
    if ( $self->_aldb ) {
        $restore_string .= $self->_aldb->restore_string();
    }
    return $restore_string;
}

=item C<check_for_data()>

Called once per loop.  This checks for any data waiting on the serial port, if
data exists it is sent to C<_parse_data>.  If there is no data waiting, then
this checks to see if the timers for any previous commands have expired, if they
have, it calls C<retry_active_message()>.  Else, this checks to see if there
is any timeout preventing a transmission right now, if there is no timeout it
calles C<process_queue()>.

=cut

sub check_for_data {

    my ($self) = @_;
    my $PLM_use_tcp = 0;

    #$PLM_use_tcp    = $::config_parms{$self . "_use_TCP"};
    $PLM_use_tcp = $$self{use_tcp};
    my $port_name = $$self{port_name};
    my $data      = undef;
    if ( $PLM_use_tcp == 1 ) {
        if (    ( not active $PLM_socket)
            and ( ( $main::Second % 6 ) == 0 )
            and $::New_Second )
        {
            &::print_log("[Insteon PLM] resetting socket connection");
            start $PLM_socket;
        }
        $data = said $PLM_socket;

        #&::print_log("[Insteon PLM] data recieved $data") if $data;

    }
    else {
        &::check_for_generic_serial_data($port_name)
          if $::Serial_Ports{$port_name}{object};
        $data = $::Serial_Ports{$port_name}{data};
    }

    # always check for data first; if it exists, then process; otherwise check if pending commands exist
    if ($data) {

        # now, clear the serial port data so that any subsequent command processing doesn't result in an immediate filling/overwriting
        if ( length( $$self{_data_fragment} ) ) {

            #        		$main::Serial_Ports{$port_name}{data}=pack("H*",$$self{_data_fragment});
            # always clear the buffer since we're maintaining the fragment separately
            $main::Serial_Ports{$port_name}{data} = '';
        }
        else {
            $main::Serial_Ports{$port_name}{data} = '';
        }

        #lets turn this into Hex. I hate perl binary funcs
        my $data = unpack "H*", $data;

        $self->_parse_data($data);
    }
    elsif ( defined $self ) {

        # if no data being received, then check if any timeouts have expired
        if ( $self->_check_timeout('command') == 1 ) {
            $self->_clear_timeout('command');
            if ( $self->transmit_in_progress ) {

                #               &::print_log("[Insteon_PLM] WARN: No acknowledgement from PLM to last command requires forced abort of current command."
                #                  . " This may reflect a problem with your environment.");
                #               pop(@{$$self{command_stack2}}); # pop the active command off the queue
                $self->retry_active_message();
                $self->process_queue();
            }
            else {
                &::print_log(
                    "[Insteon_PLM] DEBUG2: PLM command timer expired but no transmission in place.  Moving on..."
                ) if $self->debuglevel( 2, 'insteon' );
                $self->clear_active_message();
                $self->process_queue();
            }
        }
        elsif ( $self->_check_timeout('xmit') == 1 ) {
            $self->_clear_timeout('xmit');
            if ( !( $self->transmit_in_progress ) ) {
                $self->process_queue();
            }
        }
    }
}

=item C<set()>

Used to send X10 messages, generates an X10 command and queues it.

=cut

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;

    my @x10_commands =
      &Insteon::X10Message::generate_commands( $p_state, $p_setby );
    foreach my $command (@x10_commands) {
        $self->queue_message( new Insteon::X10Message($command) );
    }
}

=item C<complete_linking_as_responder()>

Puts the PLM into linking mode as a responder.

=cut

sub complete_linking_as_responder {
    my ( $self, $group ) = @_;

    # it is not clear that group should be anything as the group will be taken from the controller
    $group = '01' unless $group;

    # set up the PLM as the responder
    my $cmd = '00';    # responder code
    $cmd .= $group;    # WARN - must be 2 digits and in hex!!
    my $message = new Insteon::InsteonMessage( 'all_link_start', $self );
    $message->interface_data($cmd);
    $self->queue_message($message);
}

=item C<log_alllink_table()>

Causes MisterHouse to dump its cache of the PLM link table to the log.

=cut

sub log_alllink_table {
    my ($self) = @_;
    $self->_aldb->log_alllink_table if $self->_aldb;
}

=item C<scan_link_table()>

Causes MisterHouse to scan the link table of the PLM only.

=cut

sub scan_link_table {
    my ( $self, $callback, $failure, $skip_unchanged ) = @_;

    #$$self{links} = undef; # clear out the old
    if ( $skip_unchanged && $self->_aldb->health =~ /(empty)|(unchanged)/ ) {
        ::print_log(
            '[Scan Link Tables] - PLM Link Table is unchanged, skipping.');

        package main;
        eval($callback);
        &::print_log(
            "[Insteon_PLM] WARN1: Error encountered during scan callback: "
              . $@ )
          if $@ and $self->debuglevel( 1, 'insteon' );

        package Insteon_PLM;
    }
    else {
        #ALDB Cache is unhealthy, or scan forced
        $$self{aldb}          = new Insteon::ALDB_PLM($self);
        $$self{_mem_activity} = 'scan';
        $$self{_mem_callback} = ($callback) ? $callback : undef;
        $self->_aldb->get_first_alllink();
    }
}

=item C<initiate_linking_as_controller([p_group])>

Puts the PLM into linking mode as a controller, if p_group is specified the
controller will be added for this group, otherwise it will be for group 00.

=cut

sub initiate_linking_as_controller {
    my ( $self, $group, $success_callback, $failure_callback ) = @_;

    $group = '00' unless $group;

    # set up the PLM as the responder
    my $cmd = '01';    # controller code
    $cmd .= $group;    # WARN - must be 2 digits and in hex!!
    my $message = new Insteon::InsteonMessage( 'all_link_start', $self );
    $message->interface_data($cmd);
    $message->success_callback($success_callback);
    $message->failure_callback($failure_callback);
    $self->queue_message($message);
}

=item C<initiate_unlinking_as_controller([p_group])>

Puts the PLM into unlinking mode, if p_group is specified the PLM will try
to unlink any devices linked to that group that identify themselves with a set
button press.

=cut

sub initiate_unlinking_as_controller {
    my ( $self, $group ) = @_;

    $group = 'FF' unless $group;

    # set up the PLM as the responder
    my $cmd = 'FF';    # controller code
    $cmd .= $group;    # WARN - must be 2 digits and in hex!!
    my $message = new Insteon::InsteonMessage( 'all_link_start', $self );
    $message->interface_data($cmd);
    $self->queue_message($message);
}

=item C<cancel_linking()>

Cancels any pending linking session that has not completed.

=cut

sub cancel_linking {
    my ($self) = @_;
    $self->queue_message(
        new Insteon::InsteonMessage( 'all_link_cancel', $self ) );
}

=item C<_aldb()>

Returns the PLM's aldb object.

=cut

sub _aldb {
    my ($self) = @_;
    return $$self{aldb};
}

=item C<_send_cmd()>

Causes a message to be sent to the serial port.

=cut

sub _send_cmd {
    my ( $self, $message, $cmd_timeout ) = @_;
    my $instance    = $$self{port_name};
    my $PLM_use_tcp = $$self{use_tcp};
    if ( $PLM_use_tcp == 1 ) {

        #stop $PLM_socket;
        if ( not connected $PLM_socket) {
            &::print_log("[Insteon PLM] starting socket connection ");
            start $PLM_socket;
        }
    }
    else {
        if ( !( ref $main::Serial_Ports{$instance}{object} ) ) {
            print "WARN: Insteon_PLM serial port not initialized!\n";
            return;
        }
    }
    unshift( @{ $$self{command_history} }, $::Time );
    $self->transmit_in_progress(1);

    my $command = $message->interface_data;
    my $delay   = $$self{xmit_delay};

    # determine the delay from the point that the message was created to
    # the point that it is queued
    my $incurred_delay_time = $message->seconds_delayed;

    if ( $message->isa('Insteon::X10Message') ) {    # is x10; so, be slow
        &main::print_log( "[Insteon_PLM] DEBUG2: Sending "
              . $message->to_string
              . " incurred delay of "
              . sprintf( '%.2f', $incurred_delay_time )
              . " seconds" )
          if $self->debuglevel( 2, 'insteon' );
        $command = $prefix{x10_send} . $command;
        $delay   = $$self{xmit_x10_delay};
        $self->_set_timeout( 'command', '1000' )
          ; # a commmand needs to be PLM ack'd w/i 1 seconds or a retry is attempted
         # clear command timeout so that we don't wait for an insteon ack before sending the next command
    }
    else {
        my $command_type = $message->command_type;
        &main::print_log(
                "[Insteon_PLM] DEBUG2: Sending "
              . $message->to_string
              . " incurred delay of "
              . sprintf( '%.2f', $incurred_delay_time )
              . " seconds; starting hop-count: "
              . (
                (
                    ref $message->setby
                      && $message->setby->isa('Insteon::BaseObject')
                ) ? $message->setby->default_hop_count : "?"
              )
        ) if $message->setby->debuglevel( 2, 'insteon' );
        $command = $prefix{$command_type} . $command;
        if (   $command_type eq 'all_link_send'
            or $command_type eq 'insteon_send'
            or $command_type eq 'insteon_ext_send'
            or $command_type eq 'all_link_direct_cleanup' )
        {
            $self->_set_timeout( 'command', $cmd_timeout )
              ; # a commmand needs to be ack'd by device w/i $cmd_timeout or a retry is attempted
        }
    }
    my $is_extended = ( $message->can('command_type')
          && $message->command_type eq "insteon_ext_send" ) ? 1 : 0;
    if (
        length($command) != (
            Insteon::MessageDecoder::insteon_cmd_len( substr( $command, 0, 4 ),
                0, $is_extended ) * 2
        )
      )
    {
        &::print_log( "[Insteon_PLM]: ERROR!! Command sent to PLM "
              . lc($command)
              . " is of an incorrect length.  Message not sent." );
        $self->clear_active_message();
    }
    else {
        my $debug_obj = $self;
        $debug_obj = $message->setby
          if ( $message->can('setby') && ref $message->setby );
        &::print_log(
            "[Insteon_PLM] DEBUG3: Sending  PLM raw data: " . lc($command) )
          if $debug_obj->debuglevel( 3, 'insteon' );
        &::print_log( "[Insteon_PLM] DEBUG4:\n"
              . Insteon::MessageDecoder::plm_decode($command) )
          if $debug_obj->debuglevel( 4, 'insteon' );
        my $data = pack( "H*", $command );
        if ( $PLM_use_tcp == 1 ) {
            my $port_name = $PLM_socket->{port_name};
            my $sentBytes = $main::Socket_Ports{$port_name}{sock}->send($data)
              if $main::Socket_Ports{$port_name}{sock};

            #print "Insteon_2412N $sentBytes bytes sent ($data)[$command]\n";
        }
        else {
            $main::Serial_Ports{$instance}{object}->write($data)
              if $main::Serial_Ports{$instance};
        }

        if ($delay) {
            $self->_set_timeout( 'xmit', $delay * 1000 );
        }
        $$self{'last_change'} = $main::Time;
    }
}

=item C<_parse_data()>

This routine parses data comming in from the serial port.  In many cases
multiple messages or fragments of messages may arrive at once.  This routine 
attempts to parse this string of data into individual messages, unfortunately
the PLM does not have a unique message delimiter.  Instead, all PLM messages 
start with 02XX where XX is a two digit code corresponding to the message type.

The one caveat, is that the PLM may send simple 15 to indicate that it is busy.

This routine uses a First-In-First-Out (FIFO) style for processing the data
stream by following this procedure:

        1. Prepend any prior data fragment left over from the last run
        2. Trim off any PLM busy messages
        3. Locate the first valid PLM prefix in the message
        4. Look for PLM ACK, NACK and BadCmd Responses
        5. Look for known Insteon message types
        6. Dispose of stale data that doesn't match known message types
        7. Save whatever data fragments remain for the next pass

Based on the type of message, it is then passed off to higher level message 
handling routines.

=cut

sub _parse_data {
    my ( $self, $data ) = @_;
    my $process_next_command = 1;
    my $debug_obj            = $self;
    $debug_obj = $self->active_message->setby
      if ( ref $self->active_message
        && $self->active_message->can('setby')
        && ref $self->active_message->setby );

    ::print_log("[Insteon_PLM] DEBUG3: Received PLM raw data: $data")
      if $self->debuglevel( 3, 'insteon' );

    # STEP 1 Prepend any prior unprocessed data fragment
    if ( $$self{_data_fragment} ) {
        ::print_log( "[Insteon_PLM] DEBUG3: Prepending prior data fragment"
              . ": $$self{_data_fragment}" )
          if $self->debuglevel( 3, 'insteon' );
        $data = $$self{_data_fragment} . $data;
    }

    # Continue to Process Data until we can't
    my $process_data = 1;
    while ($process_data) {
        ::print_log("[Insteon_PLM] DEBUG3: Processing PLM raw data: $data")
          if $self->debuglevel( 3, 'insteon' );

        # Step 2 Is this a PLM Busy Message?
        if ( substr( $data, 0, 2 ) eq '15' ) {

            # The PLM can't receive any more commands at the moment
            if ( $self->active_message ) {
                my $nack_delay =
                  ( $::config_parms{Insteon_PLM_disable_throttling} )
                  ? 0.3
                  : 1.0;
                ::print_log(
                    "[Insteon_PLM] DEBUG3: Interface extremely busy. Resending command"
                      . " after delaying for $nack_delay second" )
                  if $self->debuglevel( 3, 'insteon' );
                $self->_set_timeout( 'xmit', $nack_delay * 1000 );
                $self->active_message->no_hop_increase(1);
                $process_next_command = 0;
            }
            else {
                ::print_log( "[Insteon_PLM] DEBUG3: Interface extremely busy."
                      . " No message to resend." )
                  if $self->debuglevel( 3, 'insteon' );
            }

            #Remove the leading NACK bytes and place whatever remains into fragment for next read
            $data =~ s/^(15)*//;
        }

        # STEP 3 Does $data start with a valid prefix?
        my $record_type = substr( $data, 0, 4 );
        unless ( grep( /$record_type/, values(%prefix) ) ) {
            $data = $self->_next_valid_prefix($data);
            ::print_log( "[Insteon_PLM] ERROR: Received data did not start "
                  . "with a valid prefix.  Trimming to: $data" );
            $record_type = substr( $data, 0, 4 );
        }

        # STEP 4a Is this a PLM Response to a command we sent? Prep Vars
        my ( $is_ack, $is_nack, $is_badcmd ) = (0) x 3;
        my ( $ackcmd, $nackcmd, $badcmd )    = ("") x 3;
        my $pending_message = $self->active_message;

        if ($pending_message) {

            # Prep Variables
            my $prev_cmd = lc $pending_message->interface_data;
            my $prev_cmd_length = length($prev_cmd);    # Used to get msg data

            # Add PLM Prefix to Prior Command
            if ( $pending_message->isa('Insteon::X10Message') ) {
                $prev_cmd = $prefix{x10_send} . $prev_cmd;
            }
            else {
                my $command_type = $pending_message->command_type;
                $prev_cmd = $prefix{$command_type} . $prev_cmd;
            }

            # Add ACK, NACK and BadCmd Suffixes
            $ackcmd  = $prev_cmd . '06';
            $nackcmd = $prev_cmd . '15';
            $badcmd  = $prev_cmd . '0f';

            # Does Data start with any of these messages?
            $is_ack    = 1 if ( $data =~ /^($ackcmd)/ );
            $is_nack   = 1 if ( $data =~ /^($nackcmd)/ );
            $is_badcmd = 1 if ( $data =~ /^($badcmd)/ );
        }

        # Step 4b Check if this is a unique PLM Response
        if ( $record_type eq $prefix{plm_info} and ( length($data) >= 18 ) ) {

            #Note Receipt of PLM Response
            $pending_message->plm_receipt(1);

            ::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $self->debuglevel( 4, 'insteon' );

            $self->device_id( substr( $data, 4, 6 ) );
            $self->firmware( substr( $data, 14, 2 ) );
            $self->on_interface_info_received();

            $data = substr( $data, 18 );
        }
        elsif ( $record_type eq $prefix{plm_get_config}
            and ( length($data) >= 12 ) )
        {
            #Note Receipt of PLM Response
            $pending_message->plm_receipt(1);

            ::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $self->debuglevel( 4, 'insteon' );
            my $message_data = substr( $data, 4, 8 );
            $self->on_interface_config_received($message_data);
            $data = substr( $data, 18 );
        }

        # STEP 4c Is this a PLM Response to a command MH sent?
        elsif ($is_ack) {

            #Note Receipt of PLM ACK
            $pending_message->plm_receipt(1);

            ::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $debug_obj->debuglevel( 4, 'insteon' );

            ::print_log( "[Insteon_PLM] DEBUG3: Received PLM acknowledge: "
                  . $pending_message->to_string )
              if $debug_obj->debuglevel( 3, 'insteon' );

            # Handle PLM ALDB Messages (Should these be here???)
            if (   $record_type eq $prefix{all_link_first_rec}
                or $record_type eq $prefix{all_link_next_rec} )
            {
                $$self{_next_link_ok} = 1;
            }
            elsif ( $record_type eq $prefix{all_link_start} ) {
                if ( $self->active_message->success_callback ) {

                    package main;
                    eval( $self->active_message->success_callback );
                    &::print_log(
                        "[Insteon_PLM] WARN1: Error encountered during ack callback: "
                          . $@ )
                      if (
                           $@
                        && $self->active_message->can('setby')
                        && ref $self->active_message->setby
                        && $self->active_message->setby->debuglevel(
                            1, 'insteon'
                        )
                      );

                    package Insteon_PLM;
                }

                # clear the active message because we're done
                $self->clear_active_message();
            }
            elsif ( $record_type eq $prefix{all_link_manage_rec} ) {

                # Managing the PLM's ALDB
                $self->clear_active_message();

                my $callback;
                if ( $self->_aldb->{_success_callback} ) {
                    $callback = $self->_aldb->{_success_callback};
                    $self->_aldb->{_success_callback} = undef;
                }
                elsif ( $$self{_mem_callback} ) {
                    $callback =
                      $pending_message->callback();    #$$self{_mem_callback};
                    $$self{_mem_callback} = undef;
                }
                if ($callback) {

                    package main;
                    eval($callback);
                    &::print_log(
                        "[Insteon_PLM] WARN1: Error encountered during ack callback: "
                          . $@ )
                      if (
                           $@
                        && $self->active_message->can('setby')
                        && ref $self->active_message->setby
                        && $self->active_message->setby->debuglevel(
                            1, 'insteon'
                        )
                      );

                    package Insteon_PLM;
                }
            }
            elsif ( $record_type eq $prefix{x10_send} ) {

                # The PLM ACK is all we get for X10
                $self->_clear_timeout('command');
                $self->clear_active_message();
            }
            elsif ( $record_type eq $prefix{plm_set_config} ) {

                # The PLM ACK is all we get in response to
                # setting the config parameters
                $self->clear_active_message();
            }

            $data =~ s/^$ackcmd//;
        }
        elsif ($is_nack) {

            #Note Receipt of PLM NAK
            $pending_message->plm_receipt(1);

            ::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $debug_obj->debuglevel( 4, 'insteon' );

            # regardless, we're not retrying as we'll just get the same
            $self->clear_active_message();

            # More PLM ALDB Messages (Again should these be here???)
            if (   $record_type eq $prefix{all_link_first_rec}
                or $record_type eq $prefix{all_link_next_rec} )
            {
                # both of these conditions are ok as it just means
                # we've reached the end of the memory
                $$self{_next_link_ok} = 0;
                $$self{_mem_activity} = undef;
                if ( $record_type eq $prefix{all_link_first_rec} ) {
                    $self->_aldb->health("empty");
                }
                else {
                    $self->_aldb->health("unchanged");
                }
                $self->_aldb->scandatetime(&main::get_tickcount);
                &::print_log( "[Insteon_PLM] "
                      . $self->get_object_name
                      . " completed link memory scan. Status: "
                      . $self->_aldb->health() )
                  if $self->debuglevel( 1, 'insteon' );
                if ( $$self{_mem_callback} ) {
                    my $callback = $$self{_mem_callback};
                    $$self{_mem_callback} = undef;

                    package main;
                    eval($callback);
                    &::print_log(
                        "[Insteon_PLM] WARN1: Error encountered during nack callback: "
                          . $@ )
                      if $@ and $self->debuglevel( 1, 'insteon' );

                    package Insteon_PLM;
                }
            }
            elsif ( $record_type eq $prefix{all_link_send} ) {
                &::print_log(
                    "[Insteon_PLM] WARN: PLM ALDB does not have a link for this scene defined: "
                      . $pending_message->to_string
                      . $@ );
            }
            elsif ( $record_type eq $prefix{all_link_start} ) {
                &::print_log(
                        "[Insteon_PLM] WARN: PLM unable to enter linking mode: "
                      . $pending_message->to_string
                      . $@ );
            }
            elsif ( $record_type eq $prefix{all_link_manage_rec} ) {

                # parse out the data
                my $failed_cmd_code =
                  substr( $pending_message->interface_data(), 0, 2 );
                my $failed_cmd = 'unknown';
                if ( $failed_cmd_code eq '40' ) {
                    $failed_cmd = 'update/add controller record';
                }
                elsif ( $failed_cmd_code eq '41' ) {
                    $failed_cmd = 'update/add responder record';
                }
                elsif ( $failed_cmd_code eq '80' ) {
                    $failed_cmd = 'delete record';
                }
                my $failed_group =
                  substr( $pending_message->interface_data(), 4, 2 );
                my $failed_deviceid =
                  substr( $pending_message->interface_data(), 6, 6 );
                &::print_log(
                        "[Insteon_PLM] WARN: PLM unable to complete requested "
                      . "PLM link table update ($failed_cmd) for "
                      . "group: $failed_group and deviceid: $failed_deviceid" );
                my $callback;
                if ( $self->_aldb->{_success_callback} ) {
                    $callback = $self->_aldb->{_success_callback};
                    $self->_aldb->{_success_callback} = undef;
                }
                elsif ( $$self{_mem_callback} ) {
                    $callback =
                      $pending_message->callback();    #$$self{_mem_callback};
                    $$self{_mem_callback} = undef;
                }
                if ($callback) {

                    package main;
                    eval($callback);
                    &::print_log(
                        "[Insteon_PLM] WARN1: Error encountered during ack callback: "
                          . $@ )
                      if $@ and $self->debuglevel( 1, 'insteon' );

                    package Insteon_PLM;
                }
            }
            else {
                &::print_log( "[Insteon_PLM] WARN: received NACK from PLM for "
                      . $pending_message->to_string() );
            }
            $data =~ s/^$nackcmd//;
        }
        elsif ($is_badcmd) {

            #Note Receipt of PLM Bad Cmd
            $pending_message->plm_receipt(1);

            ::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $debug_obj->debuglevel( 4, 'insteon' );

            ::print_log( "[Insteon_PLM] WARN: received Bad Command Error"
                  . " from PLM for "
                  . $pending_message->to_string() );

            $data =~ s/^$badcmd//;
        }
        elsif ($pending_message
            && $data =~
            /^($prefix{insteon_send}\w{12}06)|($prefix{insteon_send}\w{12}15)|($prefix{insteon_send}\w{12}0f)/
          )
        {
            # This looks like a garbled PLM Response
            my $unknown_deviceid  = substr( $data, 4,  6 );
            my $unknown_msg_flags = substr( $data, 10, 2 );
            my $unknown_command   = substr( $data, 12, 2 );
            my $unknown_data      = substr( $data, 14, 2 );
            my $unknown_obj = &Insteon::get_object( $unknown_deviceid, '01' );
            if ($unknown_obj) {
                &::print_log( "[Insteon_PLM] DEBUG4:\n"
                      . Insteon::MessageDecoder::plm_decode($data) )
                  if $unknown_obj->debuglevel( 4, 'insteon' );
                &::print_log(
                    "[Insteon_PLM] WARN: encountered garbled PLM data '$data'"
                      . " but expected '$ackcmd'. Attempting to find next valid"
                      . " message." );
            }
            else {
                &::print_log( "[Insteon_PLM] DEBUG4:\n"
                      . Insteon::MessageDecoder::plm_decode($data) )
                  if $self->debuglevel( 4, 'insteon' );
                &::print_log(
                    "[Insteon_PLM] ERROR: encountered garbled PLM data '$data' "
                      . "that does not match any known device ID (expected '$ackcmd')."
                      . " Attempting to find next valid message." );
            }
            $self->active_message->no_hop_increase(1);

            # Because this was an unexpected response, find next
            # possible prefix and process from there.  Maybe this
            # message was something else
            $data = $self->_next_valid_prefix($data);
        }

        # STEP 5 Is this valid data received from the network?
        elsif ( $record_type eq $prefix{insteon_received}
            and ( length($data) >= 22 ) )
        {
            #Insteon Standard Received
            my $message_data = substr( $data, 4, 18 );
            my $find_obj = Insteon::get_object( substr( $data, 4, 6 ), '01' );
            if ( ref $find_obj ) {
                ::print_log( "[Insteon_PLM] DEBUG4:\n"
                      . Insteon::MessageDecoder::plm_decode($data) )
                  if $find_obj->debuglevel( 4, 'insteon' );
            }
            else {
                ::print_log( "[Insteon_PLM] DEBUG4:\n"
                      . Insteon::MessageDecoder::plm_decode($data) )
                  if $self->debuglevel( 4, 'insteon' );
            }
            $self->on_standard_insteon_received($message_data);

            $data = substr( $data, 22 );
        }
        elsif ( $record_type eq $prefix{insteon_ext_received}
            and ( length($data) >= 50 ) )
        {
            #Insteon Extended Received
            my $message_data = substr( $data, 4, 46 );
            my $find_obj = Insteon::get_object( substr( $data, 4, 6 ), '01' );
            if ( ref $find_obj ) {
                ::print_log( "[Insteon_PLM] DEBUG4:\n"
                      . Insteon::MessageDecoder::plm_decode($data) )
                  if $find_obj->debuglevel( 4, 'insteon' );
            }
            else {
                ::print_log( "[Insteon_PLM] DEBUG4:\n"
                      . Insteon::MessageDecoder::plm_decode($data) )
                  if $self->debuglevel( 4, 'insteon' );
            }
            $self->on_extended_insteon_received($message_data);

            $data = substr( $data, 50 );
        }
        elsif ( $record_type eq $prefix{x10_received}
            and ( length($data) >= 8 ) )
        {
            #X10 Received
            my $message_data = substr( $data, 4, 4 );
            ::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $self->debuglevel( 4, 'insteon' );
            my $message_data = substr( $data, 0, 8 );
            my $x10_message  = new Insteon::X10Message($message_data);
            my $x10_data     = $x10_message->get_formatted_data();
            ::print_log("[Insteon_PLM] DEBUG3: received x10 data: $x10_data")
              if $self->debuglevel( 3, 'insteon' );
            ::process_serial_data( $x10_data, undef, $self );

            $data = substr( $data, 8 );
        }
        elsif ( $record_type eq $prefix{all_link_complete}
            and ( length($data) >= 20 ) )
        {
            #ALL-Linking Completed
            my $message_data = substr( $data, 4, 16 );
            ::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $self->debuglevel( 4, 'insteon' );
            my $link_address = substr( $message_data, 4, 6 );
            ::print_log(
                "[Insteon_PLM] DEBUG2: ALL-Linking Completed with $link_address ($message_data)"
            ) if $self->debuglevel( 2, 'insteon' );
            my $device_object = Insteon::get_object($link_address);
            $device_object->devcat( substr( $message_data, 10, 4 ) );
            $device_object->firmware( substr( $message_data, 14, 2 ) );

            #Insert the record into MH cache of the PLM's link table
            my $data1 = substr( $device_object->devcat, 0, 2 );
            my $data2 = substr( $device_object->devcat, 2, 2 );
            my $data3 = $device_object->firmware;
            my $type  = substr( $message_data,          0, 2 );
            my $group = substr( $message_data,          2, 2 );

            #Select type of link (00 - responder, 01 - master, ff - delete)
            if ( $type eq '00' ) {
                $self->_aldb->add_link_to_hash( 'A2', $group, '0',
                    $link_address, $data1, $data2, $data3 );
            }
            elsif ( $type eq '01' ) {
                $self->_aldb->add_link_to_hash( 'E2', $group, '1',
                    $link_address, $data1, $data2, $data3 );
            }
            elsif ( lc($type) eq 'ff' ) {

                # This is a delete request.
                # The problem is that the message from the PLM
                # does not identify whether the link deleted was
                # a responder or controller.  We could guess, b/c
                # it is unlikely that d1-d3 would be identical.
                # However, that seems sloppy.  For the time being
                # simply mark PLM aldb as unhealthy, and move on.
                if ( ref $self->active_message
                    && $self->active_message->success_callback )
                {
                    # This is LIKELY a delete in response to a MH
                    # request.  This is a bad way to check for
                    # this, but not sure what else to do.
                    # As a result, don't change health status
                }
                else {
                    $self->_aldb->health('changed');
                }
            }

            #Run success callback if it exists
            if ( ref $self->active_message ) {
                if ( $self->active_message->success_callback ) {
                    main::print_log(
                        "[Insteon::Insteon_PLM] DEBUG4: Now calling message success callback: "
                          . $self->active_message->success_callback )
                      if $self->debuglevel( 4, 'insteon' );

                    package main;
                    eval $self->active_message->success_callback;
                    ::print_log(
                        "[Insteon::Insteon_PLM] problem w/ success callback: $@"
                    ) if $@;

                    package Insteon::BaseObject;
                }

                #Clear awaiting_ack flag
                $self->active_message->setby->_process_command_stack(0);
                $self->clear_active_message();
            }
            $data = substr( $data, 20 );
        }
        elsif ( $record_type eq $prefix{all_link_clean_failed}
            and ( length($data) >= 12 ) )
        {
            #ALL-Link Cleanup Failure Report
            my $message_data = substr( $data, 4, 8 );
            if ( $self->active_message ) {

                # extract out the pertinent parts of the message for display purposes
                # bytes 0-1 - group; 2-7 device address
                my $failure_group  = substr( $message_data, 0, 2 );
                my $failure_device = substr( $message_data, 2, 6 );
                my $failed_object =
                  &Insteon::get_object( $failure_device, '01' );
                if ( ref $failed_object ) {
                    ::print_log( "[Insteon_PLM] DEBUG4:\n"
                          . Insteon::MessageDecoder::plm_decode($data) )
                      if $failed_object->debuglevel( 4, 'insteon' );
                    ::print_log(
                        "[Insteon_PLM] DEBUG2: Received all-link cleanup failure from "
                          . $failed_object->get_object_name
                          . " for all link group: $failure_group. Trying a direct cleanup."
                    ) if $failed_object->debuglevel( 2, 'insteon' );
                    my $message = new Insteon::InsteonMessage(
                        'all_link_direct_cleanup',      $failed_object,
                        $self->active_message->command, $failure_group
                    );
                    push( @{ $$failed_object{command_stack} }, $message );
                    $failed_object->_process_command_stack();
                }
                else {
                    ::print_log( "[Insteon_PLM] DEBUG4:\n"
                          . Insteon::MessageDecoder::plm_decode($data) )
                      if $self->debuglevel( 4, 'insteon' );
                    ::print_log(
                        "[Insteon_PLM] Received all-link cleanup failure from an unkown device id: "
                          . "$failure_device and for all link group: $failure_group. You may "
                          . "want to run delete orphans to remove this link from your PLM"
                    );
                }
            }
            else {
                ::print_log( "[Insteon_PLM] DEBUG4:\n"
                      . Insteon::MessageDecoder::plm_decode($data) )
                  if $self->debuglevel( 4, 'insteon' );
                ::print_log(
                    "[Insteon_PLM] DEBUG2: Received all-link cleanup failure."
                      . " But there is no pending message." )
                  if $self->debuglevel( 2, 'insteon' );
            }

            $data = substr( $data, 12 );
        }
        elsif ( $record_type eq $prefix{all_link_record}
            and ( length($data) >= 20 ) )
        {
            #Note Receipt of PLM Response
            $pending_message->plm_receipt(1);

            #ALL-Link Record Response
            my $message_data = substr( $data, 4, 16 );
            &::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $self->debuglevel( 4, 'insteon' );
            &::print_log(
                "[Insteon_PLM] DEBUG2: ALL-Link Record Response:$message_data")
              if $self->debuglevel( 2, 'insteon' );
            $self->_aldb->parse_alllink($message_data);

            # before doing the next, make sure that the pending command
            #   (if it sitll exists) is pulled from the queue
            $self->clear_active_message();
            $self->_aldb->get_next_alllink();

            $data = substr( $data, 20 );
        }
        elsif ( $record_type eq $prefix{plm_user_reset}
            and ( length($data) >= 4 ) )
        {
            &::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $self->debuglevel( 4, 'insteon' );
            main::print_log(
                "[Insteon_PLM] Detected PLM user reset to factory defaults");
            $self->_aldb->health('changed');
            $data = substr( $data, 4 );
        }
        elsif ( $record_type eq $prefix{plm_reset} and ( length($data) >= 6 ) )
        {
            &::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $self->debuglevel( 4, 'insteon' );
            if ( substr( $data, 4, 2 ) eq '06' ) {
                ::print_log(
                    "[Insteon_PLM] Received ACK to software reset request");
                $self->_aldb->health('changed');
            }
            else {
                ::print_log(
                    "[Insteon_PLM] ERROR Received NACK to software reset request"
                );
            }

            $data = substr( $data, 6 );
        }
        elsif ( $record_type eq $prefix{all_link_clean_status}
            and ( length($data) >= 6 ) )
        {
            #ALL-Link Cleanup Status Report
            my $message_data = substr( $data, 4, 2 );
            ::print_log( "[Insteon_PLM] DEBUG4:\n"
                  . Insteon::MessageDecoder::plm_decode($data) )
              if $self->debuglevel( 4, 'insteon' );
            my $cleanup_ack = substr( $message_data, 0, 2 );
            if ( ref $self->active_message ) {
                if ( $cleanup_ack eq '15' ) {
                    &::print_log(
                        "[Insteon_PLM] WARN1: All-link cleanup failure for scene: "
                          . $self->active_message->setby->get_object_name
                          . ". Retrying in 1 second." )
                      if $self->active_message->setby->debuglevel( 1,
                        'insteon' );

                    # except that we should cause a bit of a delay to let things settle out
                    $self->_set_timeout( 'xmit', 1000 );
                    $process_next_command = 0;
                }
                else {
                    my $message_to_string =
                      ( $self->active_message )
                      ? $self->active_message->to_string()
                      : "";
                    &::print_log(
                        "[Insteon_PLM] Received all-link cleanup success: $message_to_string"
                      )
                      if $self->active_message->setby->debuglevel( 1,
                        'insteon' );
                    if (   ref $self->active_message
                        && ref $self->active_message->setby )
                    {
                        my $object = $self->active_message->setby;
                        $object->is_acknowledged(1);
                        $object->_process_command_stack();
                    }
                    $self->clear_active_message();
                }
            }

            $data = substr( $data, 6 );
        }
        else {
            # No more processing can be done now, wait for more data
            $process_data = 0;
        }

        # Step 6 Dispose of bad messages
        # If this is a new fragment, reset the timer
        if ( length( $$self{_data_fragment} ) == 0
            or ( index( $data, $$self{_data_fragment} ) != 0 ) )
        {
            $$self{_data_time} = time;
        }

        # If the timer has expired, Find next message
        if ( $$self{_data_time} < ( time - 1 ) && length($data) ) {
            ::print_log(
                    "[Insteon_PLM] DEBUG3: ERROR: Could not process message."
                  . " Removing stale data from queue." )
              if ( $self->debuglevel( 3, 'insteon' ) );

            # Dump 1 character from data
            $data = substr( $data, 1 );

            # Find next legitimate prefix
            $data = $self->_next_valid_prefix($data);

            # Try and process next message, maybe it is all here
            $process_data = 1;
        }

        # Stop processing if nothing to do
        $process_data = 0 if ( length($data) == 0 );
    }

    # STEP 7 Save whatever fragment remains for future processing
    if ( length($data) > 0 ) {
        ::print_log( "[Insteon_PLM] DEBUG3: Saving data fragment: " . $data )
          if ( $self->debuglevel( 3, 'insteon' ) );
    }
    $$self{_data_fragment} = $data;

    # Should we be moving on in the queue?
    if ($process_next_command) {
        $self->process_queue();
    }
    else {
        $self->retry_active_message();
    }

}

=item C<_next_valid_prefix()>

Looks for the first instance of a valid PLM prefix is a string of data and
returns that prefix and all subsequent data.

=cut

sub _next_valid_prefix {
    my ( $self, $data ) = @_;
    my $lowest_index = length($data);
    for ( values(%prefix) ) {
        if (   ( $lowest_index > index( $data, $_, 1 ) )
            && ( index( $data, $_, 1 ) >= 0 ) )
        {
            $lowest_index = index( $data, $_, 1 );
        }
    }
    return substr( $data, $lowest_index );
}

=item C<add_id_state()>

Dummy sub required to support the X10 integrtion, does nothing.

=cut

sub add_id_state {

    # do nothing
}

=item C<firmware()>

Stores and returns the firmware version of the PLM.

=cut

sub firmware {
    my ( $self, $p_firmware ) = @_;
    $$self{firmware} = $p_firmware if defined $p_firmware;
    return $$self{firmware};
}

=item C<link_data3>

Returns the data3 value that should be used when creating a link for this device.  
This sub was modivated by the need to return unique values for data3 on responder 
links for group 01.  The PLM will store the responder's devcat data for controller 
entries.  That's fundamentally hard so just do the same as for other devices for 
now.  Can make this smarter in the future if needed.

=cut 

sub link_data3 {
    my ( $self, $group, $is_controller ) = @_;

    my $link_data3;

    if ($is_controller) {

        #Default to 01 if no group was supplied
        #Otherwise just return the group
        $link_data3 = ($group) ? $group : '01';
    }
    else {    #is_responder
              #Default to 01 if no group was supplied
        $link_data3 = ($group) ? $group : '01';
    }

    return $link_data3;
}

=back

=head2 INI PARAMETERS

=over 

=item Insteon_PLM_serial_port

Identifies the port on which the PLM is attached.  Example:

    Insteon_PLM_serial_port=/dev/ttyS4

=item Insteon_PLM_use_TCP

Setting this to 1, will enable MisterHouse to use a networked PLM such as the
Insteon Hub.  This functionality seems fairly stable, but has not been 
extensively tested.

You will also need to set values for C<Insteon_PLM_TCP_host> and 
C<Insteon_PLM_TCP_port>.

There are a few quirks when using a networked PLM, they include:

The communication may be slightly slower with the network PLM.  In order to
prevent MisterHouse from clobbering the device it is recommended that you
set the C<Insteon_PLM_xmit_delay> to 1 second.  Testing may reveal that slightly
lower delays are also acceptable.

Changes made using the hub's web interface will not be understood by MisterHouse.
Device states may become out of sync. (It is possible that future coding may
be able to overcome this limiation)

=item Insteon_PLM_TCP_host

If using a network PLM, set this to the IP address of the PLM.  See 
C<Insteon_PLM_use_TCP>.

=item Insteon_PLM_TCP_port

If using a network PLM, set this to the port address of the PLM.  Generally, the
port number is 9761.  See C<Insteon_PLM_use_TCP>.

=item Insteon_PLM_xmit_delay

Sets the minimum amount of seconds that must elapse between sending Insteon messages 
to the PLM.  Defaults to 0.25.

=item Insteon_PLM_xmit_x10_delay

Sets the minimum amount of seconds that must elapse between sending X10 messages 
to the PLM.  Defaults to 0.50.

=item Insteon_PLM_disable_throttling

Periodically, the PLM will report that it is too busy to accept a message from
MisterHouse.  When this happens, MisterHouse will wait 1 second before trying
to send a message to the PLM.  If this is set to 1, downgrades the delay to only
.3 seconds.  Most of the issues which caused the PLM to overload have been handled
it is unlikely that you would need to set this.

=item Insteon_PLM_reconnect_count

The PLM acknowledges the receipt of a command from MisterHouse with an ACK 
message.  It is very rare for a well functioning PLM to fail to send the ACK
message.  In many cases, the failure to receive an ACK message from the PLM
is a sign that the connection between MisterHouse and the PLM (Serial or USB)
has died.

This setting defines the number of missed ACK messages that must occur for
MisterHouse to deem the PLM connection lost.  The number of missed ACK messages
must all occur while sending a single Insteon command.  So if you want this 
to do anything, this number needs to be less than or equal to the 
Insteon_retry_count.  Once the number of missed ACK messages occurs, MisterHouse
will attempt to reconnect the PLM.  For some people, the reconnect routine
causes errors, so you may want to test this out by manually pulling the
connection cable to the PLM to see how your system will react.

By default, this is set to 99, essentially disabling an automatic restart.

Note the ACK messages discussed here refer to PLM ACK messages not the ACK
messages received from an Insteon device in response to a command.

=back

=head2 NOTES

Special Thanks to:

Brian Warren for significant testing and patches

Bruce Winter - MH

=head2 AUTHOR

Jason Sharpee / jason@sharpee.com, Gregg Liming / gregg@limings.net, Kevin Robert Keegan, Michael Stovenour

=head2 SEE ALSO

For more information regarding the technical details of the PLM:
L<Insteon PLM Dev Guide|http://www.smarthome.com/manuals/2412sdevguide.pdf>

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;
