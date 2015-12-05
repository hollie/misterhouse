
=head1 B<Compool>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

The basic control packet allows the third party controller to

  - Toggle On/Off state of the Spa, Pool, Aux 1 - 7.
  - Enable or disable the Spa side remote(s).
  - Cancel any current circuit delays (not recommended).
  - Change/select heat source/method for Spa or Pool.
  - Change/set desired temperature for Spa and/or Pool.
  - Control Dimmers, (if unit has dimmers installed).
  - Change/set the current time of day in LX3xxx control units clock.

The basic acknowledge packet allows the third party to determine

  - Current state of Spa, Pool, Aux 1 - 7.
  - Current state of Heater and Solar for both Spa and Pool.
  - Whether LX3xxx is in Service mode (no commands should be sent).
  - Current state of Spa side remotes (enabled or not).
  - Current heat source selection.
  - Solar presence.
  - Freeze protection mode.
  - Current water and solar temperature for Spa and Pool.
  - Desired/set temperature for Spa and Pool.
  - Air Temperature (Freeze sensor, not intended offer an accurate )
                    (air temperature                               )
  - Status of temperature sensors.
  - Current time of day stored in LX3xxx unit.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#!/usr/bin/perl

use strict;

# This needs to be available to both Compool and Compool_Items
my @compool_item_list;

package Compool;

my ( %Compool_Data, @compool_command_list, $temp, $last_command_time );

#
# This code create the serial port and registers the callbacks we need
#
sub serial_startup {
    if ( $::config_parms{Compool_serial_port} ) {
        my ($speed) = $::config_parms{Compool_baudrate} || 9600;
        if (
            &::serial_port_create(
                'Compool', $::config_parms{Compool_serial_port},
                $speed, 'none', 'raw'
            )
          )
        {
            init( $::Serial_Ports{Compool}{object} );
            &::MainLoop_pre_add_hook( \&Compool::UserCodePreHook, 1 );

            #&::MainLoop_post_add_hook( \&Compool::UserCodePostHook, 1 );
        }
    }
}

sub init {
    my ($serial_port) = @_;
    $serial_port->error_msg(0);

    #$serial_port->user_msg(1);
    #$serial_port->debug(1);

    $serial_port->parity_enable(1);
    $serial_port->baudrate(9600);
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->stopbits(1);

    $serial_port->is_handshake("none");    #&? Should this be DTR?

    $serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
    $serial_port->rts_active(0);
    select( undef, undef, undef, .100 );    # Sleep a bit
    ::print_log "Compool init\n" if $main::Debug{compool};

    # Initial cleared data for _now commands
    $Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet} =
      "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Recent} = 0;
    $Compool_Data{$serial_port}{Last_Partial_Packet}               = "";

    # Debuging setup for equipment less development
    #$Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet} = "\xff\xaa\x0f\x16\x02\x10\x04\x14\x0F\x01\x10\x82\x00\x00\x00\x88\x99\x32\x00\x00\xf0\x80\x05\x55";
    #substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},8,1) = pack('C',unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},8,1)) ^ 255);
}

sub UserCodePreHook {
    if ($::New_Msecond_100) {
        if ( $::Serial_Ports{Compool}{object} ) {
            my $serial_port = $::Serial_Ports{Compool}{object};
            my $data, my $packetsize = 0;

            my $protocol_debugging = 0;
            $protocol_debugging = 1
              if $main::Debug{compool} and $main::Debug{compool} >= 3;
            $protocol_debugging = 1
              if $main::Debug{compool}
              and $main::Debug{compool} >= 2
              and @compool_command_list > 0;

            $serial_port->reset_error
              unless $data = &Compool::read_packet($serial_port);

            # Get any left over data and prepend to packet
            $data = $Compool_Data{$serial_port}{Last_Partial_Packet} . $data;

            # Check for the minimum packet size
            if ( length($data) >= 9 ) {
                print "Compool debug data=" . unpack( 'H*', $data ) . "\n"
                  if $protocol_debugging;

                my $index = index( $data, "\xFF\xAA" );
                if ( $index >= 0 ) {
                    my $packet = substr( $data, $index, 24 );

                    if (
                        length($packet) >=
                        9 )    # 9 is the minimum length required
                    {
                        if (   substr( $packet, 4, 1 ) eq "\x02"
                            && substr( $packet, 5, 1 ) eq "\x10"
                            && length($packet) >= 24 )
                        {
                            print "BAP packet detected\n"
                              if $main::Debug{compool}
                              and $main::Debug{compool} >= 2;

                            # Remove bytes from the received data to account for this packet
                            $packetsize = 24;

                            my $Checksum =
                              unpack( '%16C*', substr( $packet, 0, 22 ) )
                              % 65536;
                            my $Checksum = pack( "CC",
                                ( ( $Checksum >> 8 ) & 0xFF ),
                                ( $Checksum & 0xFF ) );

                            #
                            # Check if this is tagged as a basic acknowledge packet (Opcode == 2 && InfoFieldLengh == 10h)
                            #
                            if ( $Checksum eq substr( $packet, 22, 2 ) ) {
                                print "Compool BAP data : "
                                  . unpack( 'H*', $packet ) . "\n"
                                  if $main::Debug{compool}
                                  and $main::Debug{compool} >= 3;

                                # If first packet then we must initialize the Next_ data for the equipment to be in the opposite bit states
                                # as the data inidicates so we fire the first get_device_now triggers.

                                if ( $Compool_Data{$serial_port}
                                    {Last_Basic_Acknowledgement_Packet} eq
                                    undef )
                                {
                                    print
                                      "Compool initializing _now data bit fields\n"
                                      if $main::Debug{compool}
                                      and $main::Debug{compool} >= 2;
                                    substr(
                                        $Compool_Data{$serial_port}
                                          {Now_Basic_Acknowledgement_Packet},
                                        8,
                                        1
                                      )
                                      = pack(
                                        'C',
                                        (
                                            unpack( 'C',
                                                substr( $packet, 8, 1 ) ) ^ 255
                                        )
                                      );
                                    substr(
                                        $Compool_Data{$serial_port}
                                          {Now_Basic_Acknowledgement_Packet},
                                        9,
                                        1
                                      )
                                      = pack(
                                        'C',
                                        (
                                            unpack( 'C',
                                                substr( $packet, 9, 1 ) ) ^ 255
                                        )
                                      );
                                }
                                $Compool_Data{$serial_port}
                                  {Last_Basic_Acknowledgement_Packet} = $packet;
                                $Compool_Data{$serial_port}
                                  {Last_Basic_Acknowledgement_Recent} = 1;

                                if (
                                    substr(
                                        $Compool_Data{$serial_port}
                                          {Last_Basic_Acknowledgement_Packet},
                                        8,
                                        10
                                    ) ne substr(
                                        $Compool_Data{$serial_port}
                                          {Now_Basic_Acknowledgement_Packet},
                                        8,
                                        10
                                    )
                                  )
                                {
                                    print "Compool change detected\n"
                                      if $main::Debug{compool}
                                      and $main::Debug{compool} >= 2;

                                    # WES handle object invocation.  Loop thru all current commands and
                                    # set tied objects to the corosponding state.
                                    my $object;
                                    foreach $object (@compool_item_list) {
                                        my $newstate =
                                          $object->GetDeviceState();
                                        print "Compool checking "
                                          . $object->{object_name} . " is "
                                          . $object->state()
                                          . " new '$newstate'\n"
                                          if $main::Debug{compool}
                                          and $main::Debug{compool} >= 2;
                                        if ( $newstate ne undef
                                            and
                                            ( $object->state() ne $newstate ) )
                                        {
                                            print "Compool "
                                              . $object->{object_name} . " was "
                                              . $object->state()
                                              . " now $newstate\n"
                                              if $main::Debug{compool};
                                            $object->set_states_for_next_pass(
                                                $newstate);
                                        }
                                    }

                                    # Update the NOW packet so later compares will match
                                    $Compool_Data{$serial_port}
                                      {Now_Basic_Acknowledgement_Packet} =
                                      $Compool_Data{$serial_port}
                                      {Last_Basic_Acknowledgement_Packet};
                                    print "Compool change done\n"
                                      if $main::Debug{compool}
                                      and $main::Debug{compool} >= 2;
                                }
                            }
                            else {
                                print
                                  "Compool BAP packet recieved with invalid checksum, ignoring\n"
                                  if $main::Debug{compool};
                            }
                        }

                        # Another controllers command packet
                        elsif (substr( $packet, 4, 1 ) eq "\x82"
                            && substr( $packet, 5, 1 ) eq "\x09"
                            && length($packet) >= 17 )
                        {
                            # Remove bytes from the received data to account for this packet
                            $packetsize = 17;
                            print "Compool command packet recieved\n"
                              if $main::Debug{compool};
                        }

                        # Ack packet received
                        elsif (substr( $packet, 4, 1 ) eq "\x01"
                            && substr( $packet, 5, 1 ) eq "\x01"
                            && length($packet) >= 9 )
                        {
                            # Remove bytes from the received data to account for this packet
                            $packetsize = 9;
                            print "Compool ACK packet recieved\n"
                              if $main::Debug{compool};

                            # Remove any command at the head of the queue (but only if it's been sent)
                            if ( @compool_command_list[2] > 0 ) {
                                remove_command();
                            }
                        }

                        # Nak packet received
                        elsif (substr( $packet, 4, 1 ) eq "\x00"
                            && substr( $packet, 5, 1 ) eq "\x01"
                            && length($packet) >= 9 )
                        {
                            # Remove bytes from the received data to account for this packet
                            $packetsize = 9;

                            # Reset the last command time to we resend immediately
                            $last_command_time = 0;

                            print "Compool NAK packet recieved\n"
                              if $main::Debug{compool};
                        }
                        else {
                            # Default packetsize to 1 so we move pass the found FFAA if no packet match is performed (next
                            # pass will jump to the next start of packet detected).  Only do this if we've read enough bytes
                            # to account for the largest packet we can handle.
                            if ( length($packet) >= 24 ) {
                                $packetsize = 1;
                            }
                            print "Compool unchecked data   : "
                              . unpack( 'H*', $packet ) . "\n"
                              if $protocol_debugging;
                        }
                    }
                    else {
                        print "Compool partial command received\n";
                    }

                    # Adjust the packetsize to account for where the found packet started
                    $packetsize = $index + $packetsize;
                }

                # Failsafe case, in case we are ready wrong data from a non-compool device (or wrong baud, etc).  96 bytes is 3 times the bap packet size
                elsif ( length($data) > 96 ) {
                    $packetsize = 1;
                }

                # Store remaining data for next pass
                $Compool_Data{$serial_port}{Last_Partial_Packet} =
                  substr( $data, $packetsize );
                print "Packetsize=$packetsize Length1="
                  . length($data)
                  . " Length2="
                  . length( substr( $data, $packetsize ) ) . "\n"
                  if $main::Debug{compool}
                  and $main::Debug{compool} >= 3
                  and length( substr( $data, $packetsize ) ) > 0;
                print "Compool debug remaining data="
                  . unpack( 'H*', substr( $data, $packetsize ) ) . "\n"
                  if $protocol_debugging;
            }

            # Require a recent status packet and at least 2 seconds between commands (delay in order to avoid blowing any circuit breakers by
            # turning on too many items at once.
            if (
                (
                    $Compool_Data{$serial_port}
                    {Last_Basic_Acknowledgement_Recent} == 1
                )
                and ( @compool_command_list > 0 )
                and ( time - $last_command_time > 3 )
              )
            {
                # Increment our retry count
                @compool_command_list[2]++;

                # If we've already attempted to turn this item on 4 times, it's time to abort
                if ( @compool_command_list[2] > 4 ) {
                    print "Compool removing queued command (too many retries)\n"
                      if $main::Debug{compool};
                    remove_command();
                }
                else {
                    # If this is an device set command (these toggle the state) make sure the state isn't already where it was requested
                    # before continuing.
                    if (
                        ( @compool_command_list[3] ne undef )
                        and (
                            get_device(
                                @compool_command_list[0],
                                @compool_command_list[3]
                            ) eq @compool_command_list[4]
                        )
                      )
                    {
                        print "Compool removing queued command (device "
                          . @compool_command_list[3]
                          . " already "
                          . @compool_command_list[4] . ")\n"
                          if $main::Debug{compool};
                        remove_command();
                    }
                    else {
                        send_command(
                            @compool_command_list[0],
                            @compool_command_list[1]
                        );

                        # We are about to get a new BAP packet, nuke any holdover data
                        $Compool_Data{ @compool_command_list[0] }
                          {Last_Partial_Packet} = "";
                        $Compool_Data{$serial_port}
                          {Last_Basic_Acknowledgement_Recent} = 0;
                    }
                }
            }
        }
    }
}

#sub UserCodePostHook
#{
#    #
#    # Reset data for _now functions
#    #
#    my $serial_port = $::Serial_Ports{Compool}{object};
#    unless ($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet} eq undef)
#    {
#        $Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet} = $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet};
#    }
#}

sub set_time {
    my ($serial_port) = @_;
    my ( $Second, $Minute, $Hour, $Mday, $Month, $Year, $Wday, $Yday, $isdst )
      = localtime time;
    my $Compool_Time = pack( "CC", $Minute, $Hour );
    print "Compool set_time setting time to current local time\n"
      if $main::Debug{compool};
    return queue_command( $serial_port,
        $Compool_Time . "\x00\x00\x00\x00\x00\x00\x03" );
}

sub get_time {
    my ( $serial_port, $nowstate ) = @_;
    unless (
        length(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}
        ) == 24
      )
    {
        if ( $main::Debug{compool} ) {
            ::print_log "Compool get_time no status packet received\n";
        }
        return undef, undef;
    }

    if (
        $nowstate
        and (
            substr(
                $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},
                6,
                2
            ) eq substr(
                $Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},
                6, 2
            )
        )
      )
    {
        return undef;
    }
    else {
        return
          substr(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},
            7, 1 ),
          substr(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},
            6, 1 );
    }
}

sub set_temp {
    my ( $serial_port, $targetdevice, $targettemp ) = @_;
    my $Compool_Target_Temp =
      pack( "C", int( ( ( ( $targettemp + .9 ) - 32 ) * 4 ) / 1.8 ) );

    SWITCH: for ($targetdevice) {
        /pooldesiredtemp/i && do {
            return queue_command( $serial_port,
                    "\x00\x00\x00\x00\x00"
                  . $Compool_Target_Temp
                  . "\x00\x00\x20" );
        };
        /pooldesired/i && do {
            return queue_command( $serial_port,
                    "\x00\x00\x00\x00\x00"
                  . $Compool_Target_Temp
                  . "\x00\x00\x20" );
        };
        /pool/i && do {
            return queue_command( $serial_port,
                    "\x00\x00\x00\x00\x00"
                  . $Compool_Target_Temp
                  . "\x00\x00\x20" );
        };
        /spadesiredtemp/i && do {
            return queue_command( $serial_port,
                    "\x00\x00\x00\x00\x00\x00"
                  . $Compool_Target_Temp
                  . "\x00\x40" );
        };
        /spadesired/i && do {
            return queue_command( $serial_port,
                    "\x00\x00\x00\x00\x00\x00"
                  . $Compool_Target_Temp
                  . "\x00\x40" );
        };
        /spa/i && do {
            return queue_command( $serial_port,
                    "\x00\x00\x00\x00\x00\x00"
                  . $Compool_Target_Temp
                  . "\x00\x40" );
        };
        ::print_log "Compool set_temp unknown device\n";
    }
    return -1;
}

sub get_temp {
    my ( $serial_port, $targetdevice, $comparison, $limit, $nowstate ) = @_;
    unless (
        length(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}
        ) == 24
      )
    {
        if ( $main::Debug{compool} ) {
            ::print_log "Compool get_temp no status packet received\n";
        }
        return undef;
    }

    my $PacketOffset;

    SWITCH: for ($targetdevice) {
        /pooldesiredtemp/i && do { $PacketOffset = 15; last SWITCH; };
        /pooldesired/i     && do { $PacketOffset = 15; last SWITCH; };
        /poolsolartemp/i   && do { $PacketOffset = 12; last SWITCH; };
        /poolsolar/i       && do { $PacketOffset = 12; last SWITCH; };
        /pooltemp/i        && do { $PacketOffset = 11; last SWITCH; };
        /pool/i            && do { $PacketOffset = 11; last SWITCH; };
        /spadesiredtemp/i  && do { $PacketOffset = 16; last SWITCH; };
        /spadesired/i      && do { $PacketOffset = 16; last SWITCH; };
        /spasolartemp/i    && do { $PacketOffset = 14; last SWITCH; };
        /spasolar/i        && do { $PacketOffset = 14; last SWITCH; };
        /spatemp/i
          && do { $PacketOffset = 11; last SWITCH; }; # This is 13 on the 3830 controller.  Detect from byte 21 and autoswitch
        /spa/i
          && do { $PacketOffset = 11; last SWITCH; }; # This is 13 on the 3830 controller.  Detect from byte 21 and autoswitch

        #   /spatemp/i 	        && do { $PacketOffset = 13; last SWITCH; };
        #   /spa/i 	        && do { $PacketOffset = 13; last SWITCH; };
        /airtemp/i && do { $PacketOffset = 17; last SWITCH; };
        /air/i     && do { $PacketOffset = 17; last SWITCH; };
        ::print_log "Compool get_temp unknown device", return 0;
    }

    if (
        $nowstate
        and (
            substr(
                $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},
                $PacketOffset,
                1
            ) eq substr(
                $Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},
                $PacketOffset, 1
            )
        )
      )
    {
        return undef;
    }
    else {
        if (
            unpack(
                'C',
                substr(
                    $Compool_Data{$serial_port}
                      {Last_Basic_Acknowledgement_Packet},
                    $PacketOffset,
                    1
                )
            ) == 0
          )
        {
            return 0;
        }
        else {
            # Solar and Air temperature are given in 0.5 degrees C increments (not 0.25 like the others)
            my $divisor =
              ( ( $PacketOffset == 12 ) or ( $PacketOffset == 17 ) ) ? 2 : 4;

            my $temp = int(
                (
                    (
                        unpack(
                            'C',
                            substr(
                                $Compool_Data{$serial_port}
                                  {Last_Basic_Acknowledgement_Packet},
                                $PacketOffset,
                                1
                            )
                        ) / $divisor
                    ) * 1.8
                ) + 32
            );

            # If the spa temp is reading 0, then return the pool temp as they are the same
            $temp = get_temp("pool") if $temp == 0 and $PacketOffset == 13;

            return $temp if ( $comparison eq undef );
            return ( ( $temp < $limit )  ? 1 : 0 ) if ( $comparison eq '<' );
            return ( ( $temp > $limit )  ? 1 : 0 ) if ( $comparison eq '>' );
            return ( ( $temp == $limit ) ? 1 : 0 ) if ( $comparison eq '=' );
        }
        return undef;
    }
}

sub set_device {
    my ( $serial_port, $targetdevice, $targetstate ) = @_;

    # Handle 'toggle' state
    if ( $targetstate eq 'toggle' ) {
        $targetstate =
          ( get_device( $serial_port, $targetdevice ) eq 'on' ) ? 'off' : 'on';
    }

    if ( $targetstate eq 'on' or $targetstate eq 'ON' or $targetstate eq '1' ) {
        $targetstate = 1;
    }
    elsif ($targetstate eq 'off'
        or $targetstate eq 'OFF'
        or $targetstate eq '0' )
    {
        $targetstate = 0;
    }
    else {
        print "Invalid state $targetstate passed to Compool::_set_device\n";
        return;
    }

    my $targetprimary;
    my $targetbit = 0;
    my $byteuseenable;

    #    my $comparebit;

    SWITCH: for ($targetdevice) {
        $targetprimary = 8;
        $byteuseenable = 4;
        /spa/i  && do { $targetbit = 1;   last SWITCH; };
        /pool/i && do { $targetbit = 2;   last SWITCH; };
        /aux1/i && do { $targetbit = 4;   last SWITCH; };
        /aux2/i && do { $targetbit = 8;   last SWITCH; };
        /aux3/i && do { $targetbit = 16;  last SWITCH; };
        /aux4/i && do { $targetbit = 32;  last SWITCH; };
        /aux5/i && do { $targetbit = 64;  last SWITCH; };
        /aux6/i && do { $targetbit = 128; last SWITCH; };
        $targetprimary = 9;
        $byteuseenable = 8;
        /remote/i      && do { $targetbit = 1; last SWITCH; };
        /display/i     && do { $targetbit = 2; last SWITCH; };
        /delaycancel/i && do { $targetbit = 4; last SWITCH; };
        /spare1/i      && do { $targetbit = 8; last SWITCH; };
        /aux7/i   && do { $targetbit = 16;  $byteuseenable = 4; last SWITCH; };
        /spare2/i && do { $targetbit = 32;  last SWITCH; };
        /spare3/i && do { $targetbit = 64;  last SWITCH; };
        /spare4/i && do { $targetbit = 128; last SWITCH; };
        ::print_log "Compool set_device unknown device", return -1;
    }

    my $currentstate;

    $currentstate = unpack(
        'C',
        substr(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},
            $targetprimary, 1
        )
    );

    #
    # Determine if we need to toggle the device to get it into the right state.
    #
    #//&? These bits are wrong for the secondary equipment.  Removing check and letting queuing handle it
    #    if(($targetstate == 0) && (($currentstate & $targetbit) == 0))
    #    {
    #        return 0;
    #    }
    #    elsif(($targetstate == 1) && (($currentstate & $targetbit) == $targetbit))
    #    {
    #        return 0;
    #    }

    # Sending to primary equipment field or secondary equipment field?
    ( $targetprimary == 8 )
      ? return queue_command(
        $serial_port,
        "\x00\x00"
          . pack( "C", $targetbit )
          . "\x00\x00\x00\x00\x00"
          . pack( "C", $byteuseenable ),
        $targetdevice,
        $targetstate == 1 ? "on" : "off"
      )
      : return queue_command(
        $serial_port,
        "\x00\x00\x00"
          . pack( "C", $targetbit )
          . "\x00\x00\x00\x00"
          . pack( "C", $byteuseenable ),
        $targetdevice,
        $targetstate == 1 ? "on" : "off"
      );
}

sub get_device {
    my ( $serial_port, $targetdevice, $nowstate ) = @_;
    unless (
        length(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}
        ) == 24
      )
    {
        if ( $main::Debug{compool} ) {
            ::print_log "Compool get_device no status packet received\n";
        }
        return undef;
    }

    my $targetprimary;
    my $targetbit = 0;

    SWITCH: for ($targetdevice) {
        $targetprimary = 8;
        /spa/i  && do { $targetbit = 1;   last SWITCH; };
        /pool/i && do { $targetbit = 2;   last SWITCH; };
        /aux1/i && do { $targetbit = 4;   last SWITCH; };
        /aux2/i && do { $targetbit = 8;   last SWITCH; };
        /aux3/i && do { $targetbit = 16;  last SWITCH; };
        /aux4/i && do { $targetbit = 32;  last SWITCH; };
        /aux5/i && do { $targetbit = 64;  last SWITCH; };
        /aux6/i && do { $targetbit = 128; last SWITCH; };
        $targetprimary = 9;
        /service/i    && do { $targetbit = 1;   last SWITCH; };
        /heater/i     && do { $targetbit = 2;   last SWITCH; };
        /solar/i      && do { $targetbit = 4;   last SWITCH; };
        /remote/i     && do { $targetbit = 8;   last SWITCH; };
        /display/i    && do { $targetbit = 16;  last SWITCH; };
        /allowsolar/i && do { $targetbit = 32;  last SWITCH; };
        /aux7/i       && do { $targetbit = 64;  last SWITCH; };
        /freeze/i     && do { $targetbit = 128; last SWITCH; };
        ::print_log "Compool get_device unknown device", return undef;
    }

    if (
        $nowstate
        and (
            int(
                unpack(
                    'C',
                    substr(
                        $Compool_Data{$serial_port}
                          {Last_Basic_Acknowledgement_Packet},
                        $targetprimary,
                        1
                    )
                )
            ) & $targetbit
        ) == (
            int(
                unpack(
                    'C',
                    substr(
                        $Compool_Data{$serial_port}
                          {Now_Basic_Acknowledgement_Packet},
                        $targetprimary,
                        1
                    )
                )
            ) & $targetbit
        )
      )
    {
        return undef;
    }
    else {
        (
            unpack(
                'C',
                substr(
                    $Compool_Data{$serial_port}
                      {Last_Basic_Acknowledgement_Packet},
                    $targetprimary,
                    1
                )
            ) & $targetbit
        ) ? return "on" : return "off";
    }
}

sub get_version {
    my ( $serial_port, $targetdevice ) = @_;
    unless (
        length(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}
        ) == 24
      )
    {
        if ( $main::Debug{compool} ) {
            ::print_log "Compool get_version no status packet received\n";
        }
        return undef;
    }
    return
      substr( $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},
        3, 1 );
}

sub get_delay {
    my ( $serial_port, $targetdevice, $nowstate ) = @_;
    unless (
        length(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}
        ) == 24
      )
    {
        if ( $main::Debug{compool} ) {
            ::print_log "Compool get_delay no status packet received\n";
        }
        return undef;
    }

    my $targetbit = 0;

    SWITCH: for ($targetdevice) {
        /spadelay/i     && do { $targetbit = 1; last SWITCH; };
        /spa/i          && do { $targetbit = 1; last SWITCH; };
        /pooldelay/i    && do { $targetbit = 2; last SWITCH; };
        /pool/i         && do { $targetbit = 2; last SWITCH; };
        /cleanerdelay/i && do { $targetbit = 4; last SWITCH; };
        /cleaner/i      && do { $targetbit = 4; last SWITCH; };
        ::print_log "Compool get_delay unknown device", return undef;
    }

    if (
        $nowstate
        and (
            int(
                unpack(
                    'C',
                    substr(
                        $Compool_Data{$serial_port}
                          {Last_Basic_Acknowledgement_Packet},
                        10,
                        1
                    )
                )
            ) & $targetbit
        ) == (
            int(
                unpack(
                    'C',
                    substr(
                        $Compool_Data{$serial_port}
                          {Now_Basic_Acknowledgement_Packet},
                        10,
                        1
                    )
                )
            ) & $targetbit
        )
      )
    {
        return undef;
    }
    else {
        (
            unpack(
                'C',
                substr(
                    $Compool_Data{$serial_port}
                      {Last_Basic_Acknowledgement_Packet},
                    10,
                    1
                )
            ) & $targetbit
        ) ? return "on" : return "off";
    }
}

sub get_solar_present {
    my ( $serial_port, $targetdevice ) = @_;
    unless (
        length(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}
        ) == 24
      )
    {
        if ( $main::Debug{compool} ) {
            ::print_log "Compool get_solar_present no status packet received\n";
        }
        return undef;
    }

    (
        unpack(
            'C',
            substr(
                $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},
                10,
                1
            )
        ) & 8
    ) ? return "yes" : return "no";
}

sub set_heatsource {
    print "&? Compool set_heatsource needs to be implemented\n";
    return undef;
}

sub get_heatsource {
    my ( $serial_port, $targetdevice, $nowstate ) = @_;
    unless (
        length(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}
        ) == 24
      )
    {
        if ( $main::Debug{compool} ) {
            ::print_log "Compool get_heatsource no status packet received\n";
        }
        return undef;
    }

    my $targetbit  = 0;
    my $targetbyte = unpack(
        'C',
        substr(
            $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},
            10, 1
        )
    );
    my $targetshift = 0;

    SWITCH: for ($targetdevice) {
        /spaheatsource/i && do {
            $targetbit = 0xC0;
            $targetbyte &= 0xC0;
            $targetshift = 6;
            last SWITCH;
        };
        /spa/i && do {
            $targetbit = 0xC0;
            $targetbyte &= 0xC0;
            $targetshift = 6;
            last SWITCH;
        };
        /poolheatsource/i && do {
            $targetbit = 0x30;
            $targetbyte &= 0x30;
            $targetshift = 4;
            last SWITCH;
        };
        /pool/i && do {
            $targetbit = 0x30;
            $targetbyte &= 0x30;
            $targetshift = 4;
            last SWITCH;
        };
        ::print_log "Compool get_heatsource unknown device\n", return undef;
    }

    if (
        $nowstate
        and (
            int(
                unpack(
                    'C',
                    substr(
                        $Compool_Data{$serial_port}
                          {Last_Basic_Acknowledgement_Packet},
                        10,
                        1
                    )
                )
            ) & $targetbit
        ) == (
            int(
                unpack(
                    'C',
                    substr(
                        $Compool_Data{$serial_port}
                          {Now_Basic_Acknowledgement_Packet},
                        10,
                        1
                    )
                )
            ) & $targetbit
        )
      )
    {
        return undef;
    }
    else {
        if ( $targetbyte >> $targetshift == 0 ) {
            return "off";
        }
        elsif ( $targetbyte >> $targetshift == 1 ) {
            return "heater";
        }
        elsif ( $targetbyte >> $targetshift == 2 ) {
            return "solarpriority";
        }
        elsif ( $targetbyte >> $targetshift == 3 ) {
            return "solar";
        }
        ::print_log "Compool get_heatsource unknown state\n", return undef;
    }
}

sub queue_command {
    my ( $serial_port, $command, $targetdevice, $targetstate ) = @_;
    push( @compool_command_list, $serial_port );
    push( @compool_command_list, $command );

    # Add a retry count to the list
    push( @compool_command_list, 0 );

    # For devices, add the device and requested state to the ilst
    push( @compool_command_list, $targetdevice );
    push( @compool_command_list, $targetstate );

    return 1;
}

sub remove_command {
    if ( @compool_command_list > 0 ) {

        # Pop the serial port, command, and retry count off the list
        shift @compool_command_list;
        shift @compool_command_list;
        shift @compool_command_list;
        shift @compool_command_list;
        shift @compool_command_list;
    }
}

sub send_command {
    my ( $serial_port, $command ) = @_;

    return if $serial_port == undef;

    my $Compool_Command_Header = "\xFF\xAA\x00\x01\x82\x09";

    my $Checksum =
      unpack( "%16C*", $Compool_Command_Header . $command ) % 65536;
    my $Checksum =
      pack( "CC", ( ( $Checksum >> 8 ) & 0xFF ), ( $Checksum & 0xFF ) );

    print "Compool send data: "
      . unpack( 'H*', $Compool_Command_Header . $command . $Checksum ) . "\n"
      if $main::Debug{compool};

    ( my $BlockingFlags, my $InBytes, my $OutBytes, my $LatchErrorFlags ) =
      $serial_port->is_status || warn "could not get port status\n";
    my $ClearedErrorFlags = $serial_port->reset_error;

    # The API resets errors when reading status, $LatchErrorFlags
    # is all $ErrorFlags since they were last explicitly cleared

    #$serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
    $serial_port->rts_active(1);

    #   select (undef, undef, undef, .05); # Sleep a bit
    select( undef, undef, undef, .04 );    # Sleep a bit
    if (
        17 == (
            $temp = $serial_port->write(
                $Compool_Command_Header . $command . $Checksum
            )
        )
      )
    {
        #      select (undef, undef, undef, .02); # Sleep a bit
        select( undef, undef, undef, .025 );    # Sleep a bit
             #$serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
        $serial_port->rts_active(0);
        print "Compool send command ok\n"
          if $main::Debug{compool} and $main::Debug{compool} >= 3;

        # Store the last time that we actually sent data to the wire so we don't do it more than every X seconds.
        $last_command_time = time;

        return 1;
    }
    else {
        #       select (undef, undef, undef, .02); # Sleep a bit
        select( undef, undef, undef, .05 );    # Sleep a bit
             #$serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
        $serial_port->rts_active(0);
        print "Compool send command failed sent " . $temp . " bytes\n";
        return -1;
    }
}

sub read_packet {
    my ($serial_port) = @_;
    my $result = "";

    my $ok    = 0;
    my $got_p = " " x 4;
    my ( $bbb, $wanted, $ooo, $eee ) = $serial_port->status;
    return "" if ($eee);
    return "" unless $wanted;

    my $got = $serial_port->read_bg($wanted);

    if ( $got != $wanted ) {

        # Abort
        $serial_port->purge_rx;
        $serial_port->read_done(0);
    }
    else {
        ( $ok, $got, $result ) = $serial_port->read_done(0);
    }
    return $got ? $result : "";
}

1;

#
# Item object version (this lets us use object links and events)
#
package Compool_Item;

@Compool_Item::ISA = ('Generic_Item');

sub new {
    my ( $class, $device, $comparison, $limit, $serial_port ) = @_;
    $serial_port = $::Serial_Ports{Compool}{object}
      if ( $serial_port == undef );

    if (    ( $comparison ne undef )
        and
        ( $comparison ne '<' and $comparison ne '>' and $comparison ne '=' ) )
    {
        print "Invalid comparison operator (<>= valid) in Compool_Item\n";
        return;
    }

    my $self = {
        device      => $device,
        comparison  => $comparison,
        limit       => $limit,
        serial_port => $serial_port
    };
    bless $self, $class;

    push( @compool_item_list, $self );

    SWITCH: for ( $self->{device} ) {
        /pooltemp/i && do {
            push(
                @{ $$self{states} },
                '64', '66', '68', '70', '72',  '74',  '76',
                '78', '80', '82', '84', '86',  '88',  '90',
                '92', '94', '96', '98', '100', '102', '104'
            );
            last SWITCH;
        };
        /spatemp/i && do {
            push(
                @{ $$self{states} },
                '64', '66', '68', '70', '72',  '74',  '76',
                '78', '80', '82', '84', '86',  '88',  '90',
                '92', '94', '96', '98', '100', '102', '104'
            );
            last SWITCH;
        };

        /spaheatsource/i && do {
            push( @{ $$self{states} },
                'off', 'solar', 'heater', 'solarpriority' );
            last SWITCH;
        };
        /poolheatsource/i && do {
            push( @{ $$self{states} },
                'off', 'solar', 'heater', 'solarpriority' );
            last SWITCH;
        };

        /spa/i && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /pool/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /aux1/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /aux2/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /aux3/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /aux4/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /aux5/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /aux6/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /heater/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /solar/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /remote/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /display/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /delaycancel/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /spare1/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /aux7/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /spare2/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /spare3/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
        /spare4/i
          && do { push( @{ $$self{states} }, 'on', 'off' ); last SWITCH; };
    }

    return $self;
}

sub GetDeviceState {
    my ($self) = @_;

    SWITCH: for ( $self->{device} ) {
        /pooltemp/i && do {
            return &Compool::get_temp(
                $self->{serial_port}, $self->{device},
                $self->{comparison},  $self->{limit}
            );
        };
        /poolsolartemp/i && do {
            return &Compool::get_temp(
                $self->{serial_port}, $self->{device},
                $self->{comparison},  $self->{limit}
            );
        };
        /pooldesiredtemp/i && do {
            return &Compool::get_temp(
                $self->{serial_port}, $self->{device},
                $self->{comparison},  $self->{limit}
            );
        };
        /spatemp/i && do {
            return &Compool::get_temp(
                $self->{serial_port}, $self->{device},
                $self->{comparison},  $self->{limit}
            );
        };
        /spasolartemp/i && do {
            return &Compool::get_temp(
                $self->{serial_port}, $self->{device},
                $self->{comparison},  $self->{limit}
            );
        };
        /spadesiredtemp/i && do {
            return &Compool::get_temp(
                $self->{serial_port}, $self->{device},
                $self->{comparison},  $self->{limit}
            );
        };
        /airtemp/i && do {
            return &Compool::get_temp(
                $self->{serial_port}, $self->{device},
                $self->{comparison},  $self->{limit}
            );
        };

        /spadelay/i && do {
            return &Compool::get_delay( $self->{serial_port}, $self->{device} );
        };
        /pooldelay/i && do {
            return &Compool::get_delay( $self->{serial_port}, $self->{device} );
        };
        /cleanerdelay/i && do {
            return &Compool::get_delay( $self->{serial_port}, $self->{device} );
        };

        /spaheatsource/i && do {
            return &Compool::get_heatsource( $self->{serial_port},
                $self->{device} );
        };
        /poolheatsource/i && do {
            return &Compool::get_heatsource( $self->{serial_port},
                $self->{device} );
        };

        /spa/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /pool/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /aux1/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /aux2/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /aux3/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /aux4/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /aux5/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /aux6/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /heater/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /solar/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /remote/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /display/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /delaycancel/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /spare1/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /aux7/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /spare2/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /spare3/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /spare4/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
        /service/i && do {
            return &Compool::get_device( $self->{serial_port},
                $self->{device} );
        };
    }
    print "Compool Item: state_now device item $self->{device}\n";
    return undef;
}

sub default_setstate {
    my ( $self, $state ) = @_;

    SWITCH: for ( $self->{device} ) {
        /pooltemp/i && do {
            &Compool::set_temp( $self->{serial_port}, $self->{device}, $state );
            return -1;
        };
        /poolsolartemp/i && do {
            &Compool::set_temp( $self->{serial_port}, $self->{device}, $state );
            return -1;
        };
        /spatemp/i && do {
            &Compool::set_temp( $self->{serial_port}, $self->{device}, $state );
            return -1;
        };
        /spasolartemp/i && do {
            &Compool::set_temp( $self->{serial_port}, $self->{device}, $state );
            return -1;
        };
        /pooldesiredtemp/i && do {
            &Compool::set_temp( $self->{serial_port}, $self->{device}, $state );
            return -1;
        };
        /spadesiredtemp/i && do {
            &Compool::set_temp( $self->{serial_port}, $self->{device}, $state );
            return -1;
        };
        /airtemp/i && do {
            &Compool::set_temp( $self->{serial_port}, $self->{device}, $state );
            return -1;
        };

        /spaheatsource/i && do {
            &Compool::set_heatsource( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /poolheatsource/i && do {
            &Compool::set_heatsource( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };

        /spa/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /pool/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /aux1/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /aux2/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /aux3/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /aux4/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /aux5/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /aux6/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /remote/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /display/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /delaycancel/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /spare1/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /aux7/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /spare2/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /spare3/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
        /spare4/i && do {
            &Compool::set_device( $self->{serial_port}, $self->{device},
                $state );
            return -1;
        };
    }
    print "Compool Item: state unknown or invalid device $self->{device}\n";
    return -1;
}

1;

=back

=head2 INI PARAMETERS

Compool_serial_port=COM2

=head2 AUTHOR

bsobel@vipmail.com May 16, 2000

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

