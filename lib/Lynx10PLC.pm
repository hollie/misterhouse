
=head1 B<Lynx10PLC>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This module implements code to support the Marrick Lynx10-PLC controller. See http://www.marrickltd.com/LynX105.htm

Note: This module adds additional capability to the MisterHouse application written by Bruce Winter (winter@misterhouse.net).

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

use strict;

package Lynx10PLC;
require 5.000;
my $VERSION = "1.7";
my $ID      = "Lynx10PLC.pm";

########################################################################
# Lynx10-PLC Definitions

# Network ID Definitions
use constant NETID_NACK    => 0x00;
use constant NETID_ACK     => 0x01;
use constant NETID_UNDEF   => 0x02;
use constant NETID_X10     => 0x10;
use constant NETID_LYNXNET => 0xE0;

# Packet Offset Definitions
use constant NETID_OFFSET   => 0;
use constant NODEID_OFFSET  => 1;
use constant SEQNUM_OFFSET  => 2;
use constant PKTSIZE_OFFSET => 3;
use constant PAYLOAD_OFFSET => 4;
use constant PKTSIZE_MIN    => 5;

# LynxNet Commands
use constant LNCMD_FAILURE            => 0x00;
use constant LNCMD_SUCCESS            => 0x01;
use constant LNCMD_ENUMDEVICE         => 0x06;
use constant LNCMD_ENUMINTERFACE      => 0x07;
use constant LNCMD_ENUMPROTOCOL       => 0x08;
use constant LNCMD_MFGANDMODEL        => 0x09;
use constant LNCMD_SERIALNUM          => 0x0A;
use constant LNCMD_FIRMWAREREV        => 0x0B;
use constant LNCMD_READNVRAM          => 0x10;
use constant LNCMD_WRITENVRAM         => 0x11;
use constant LNCMD_FACTORYDEFAULTS    => 0xF0;
use constant LNCMD_FACTORYTESTEN      => 0xF6;
use constant LNCMD_RESETPROTOCOLSTACK => 0xFE;
use constant LNCMD_RESETDEVICE        => 0xFF;

# Lynx-X10 Commands
use constant X10_CMDFAILURE           => 0x00;
use constant X10_CMDSUCCESS           => 0x01;
use constant X10_STATUS               => 0x02;
use constant X10_MONITORDATA          => 0x04;
use constant X10_ANALYZERDATA         => 0x05;
use constant X10_UNITADDRESS          => 0x08;
use constant X10_ALLUNITSOFF          => 0x10;
use constant X10_ALLLIGHTSON          => 0x11;
use constant X10_ON                   => 0x12;
use constant X10_OFF                  => 0x13;
use constant X10_DIM                  => 0x14;
use constant X10_BRIGHT               => 0x15;
use constant X10_ALLLIGHTSOFF         => 0x16;
use constant X10_EXTENDEDCODETRANSFER => 0x17;
use constant X10_HAILREQUEST          => 0x18;
use constant X10_HAILACKNOWLEDGE      => 0x19;
use constant X10_PRESETDIM_1          => 0x1A;
use constant X10_PRESETDIM_2          => 0x1B;
use constant X10_EXTENDEDDATATRANSFER => 0x1C;
use constant X10_STATUS_ON            => 0x1D;
use constant X10_STATUS_OFF           => 0x1E;
use constant X10_STATUS_REQUEST       => 0x1F;
use constant X10_EVERYUNITOFF         => 0x20;
use constant X10_EVERYLIGHTOFF        => 0x21;
use constant X10_EVERYLIGHTON         => 0x22;
use constant X10_DIM_PRESET           => 0x29;
use constant X10_EXTENDED_CODE_1      => 0x31;
use constant X10_EXTENDED_CODE_2      => 0x32;
use constant X10_EXTENDED_CODE_3      => 0x33;
use constant X10_EXTENDED_CODE_4      => 0x34;
use constant X10_OPTIONS              => 0xF0;
use constant X10_CARRIERPRESENT       => 0xF1;
use constant X10_RD_STATCOUNTER       => 0xF2;
use constant X10_CLR_STATCOUNTER      => 0xF3;
use constant X10_RECEIVERSENSITIVITY  => 0xFC;
use constant X10_TRANSMITPOWER        => 0xFD;
use constant X10_SELECTCHANNEL        => 0xFE;
use constant X10_RAWPOWERLINEDATA     => 0xFF;
use constant X10_EOL                  => 0xFF;

# Stat Counter IDs. Used with
# X10_RD_STATCOUNTER and X10_CLR_STATCOUNTER commands
use constant STATCNTR_TRANSMIT_PKTS  => 0x00;
use constant STATCNTR_RECEIVED_PKTS  => 0x01;
use constant STATCNTR_RECEPTION_ERRS => 0x02;
use constant STATCNTR_TRANSMIT_ERRS  => 0x03;
use constant STATCNTR_COLLISIONS     => 0x04;
use constant STATCNTR_POWERFAILURES  => 0x05;

# Lynx10-PLC Hardware Register Definitions
use constant L10PLCREG_BAUDRATE             => 0x00;
use constant L10PLCREG_INTERFACEOPTIONS     => 0x01;
use constant L10PLCREG_X10OPTIONS           => 0x02;
use constant L10PLCREG_HOSTBUFTHRESH        => 0x08;
use constant L10PLCREG_X10BUFTHRESH         => 0x0D;
use constant L10PLCREG_X10RECVRSENS         => 0x0E;
use constant L10PLCREG_X10TRANSLEVEL        => 0x0F;
use constant L10PLCREG_X10XMITPREAMBLE      => 0x10;
use constant L10PLCREG_X10XMITPOSTAMBLE     => 0x11;
use constant L10PLCREG_X10RECVPREAMBLE      => 0x12;
use constant L10PLCREG_X10RECVPREAMBLEMASK  => 0x13;
use constant L10PLCREG_X10RECVPOSTAMBLE     => 0x14;
use constant L10PLCREG_X10RECVPOSTAMBLEMASK => 0x15;

# X10_STATUS Codes
use constant X10STATUS_OK            => 0x00;
use constant X10STATUS_BUFFERFULL    => 0x01;
use constant X10STATUS_RCVRDECODEERR => 0x10;
use constant X10STATUS_COLLISION     => 0x11;
use constant X10STATUS_COMONLINE     => 0x1E;
use constant X10STATUS_POWERFAILURE  => 0x1F;

# X10 Extended Code Commands
use constant EXCODE_PRESETDIM       => 0x31;    # Data 0-63
use constant EXCODE_OUTPUTSTATUSACK => 0x38;

########################################################################

my %table_hcodes = qw(0 A 1 B  2 C  3 D  4 E  5 F  6 G  7 H
  8 I 9 J 10 K 11 L 12 M 13 N 14 O 15 P);
my %table_ucodes = qw(0 1 1 2  2 3  3 4  4 5  5 6  6 7  7 8
  8 9 9 A 10 B 11 C 12 D 13 E 14 F 15 G
  OFF K ON J ALL_LIGHTS_ON O ALL_OFF P);

my %table_hcodes2 = qw(A 0 B 1 C  2 D  3 E  4 F  5 G  6 H  7
  I 8 J 9 K 10 L 11 M 12 N 13 O 14 P 15);
my %table_ucodes2 = qw(1 0 2 1 3  2 4  3 5  4 6  5 7  6 8  7
  9 8 A 9 B 10 C 11 D 12 E 13 F 14 G 15);

my %preset_dim_levels = qw(0 M  1 N  2 O  3 P  4 C  5 D  6 A  7 B
  8 E  9 F 10 G 11 H 12 K 13 L 14 I 15 J);

my %preset_dim_levels2 = qw(M 0 N 1 O 2 P 3 C 4 D 5 A 6 B 7
  E 8 F 9 G 10 H 11 K 12 L 13 I 14 J 15);

my @table_dcodes2 = qw(6 14 2 10 1 9 5 13 7 15 3 11 0 8 4 12);

my ( $_netid, $_nodeid, $_seqnum, $_payld, $_paysz, $_chksum, $_paycmd );
my ( $_cmds, %Lynx10PLC );
my ( $_queuedCmds, $_queuedCmdsTime, $multiDelay );
my ( $_queuedAddr, $_queuedAddrTime );
my ($logger);

my $serial_port;

my $error_detected;
$_queuedAddr = undef;

sub get_param {
    return 0 unless ( 1 == @_ );
    my ($param) = @_;
    return $Lynx10PLC{$param};
}

=item C<startup>

This code create the serial port and registers the callbacks we need

=cut

sub startup {
    $Lynx10PLC{SEQNUM}         = 0;
    $Lynx10PLC{NODEID}         = 0;
    $Lynx10PLC{STATUS_REQUEST} = "";

    &serial_startup;

    # Determine if the logger should be used
    $logger = $::config_parms{Lynx10PLC_LOGGER};

    # Determine amount of time to allow commands to be combined
    $multiDelay = $::config_parms{Lynx10PLC_MULTI_DELAY} || 250;

    # Add hook only if serial port was created ok
    if ($serial_port) {

        # Set receiver sensitivity
        my $level = $::config_parms{Lynx10PLC_RCVR_SENS} || 50;
        receiver_sensitivity($level);

        # Set transmit power
        $level = $::config_parms{Lynx10PLC_XMIT_PWR} || 50;
        transmit_power($level);

        &::MainLoop_pre_add_hook( \&Lynx10PLC::check_for_data, 1 );
    }
}

sub serial_startup {
    system("$logger Lynx10PLC::serial_startup") if $logger;

    if ( $::config_parms{Lynx10PLC_port} ) {
        my ($speed) = $::config_parms{Lynx10PLC_baudrate} || 9600;
        if (
            &::serial_port_create(
                'Lynx10PLC', $::config_parms{Lynx10PLC_port},
                $speed,      'none'
            )
          )
        {
            $serial_port = $::Serial_Ports{Lynx10PLC}{object};
            $serial_port->error_msg(0);

            #$serial_port->user_msg(1);
            $serial_port->debug(0);
            $serial_port->parity_enable(0);
            $serial_port->databits(8);
            $serial_port->parity("none");
            $serial_port->stopbits(1);
            $serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
            $serial_port->rts_active(0);
            $serial_port->write_settings;
            select( undef, undef, undef, .100 );    # Sleep a bit

            # Force LynxNet protocol and Legacy Dim Mode 1
            if ( &send( NETID_LYNXNET, pack( 'C3', LNCMD_WRITENVRAM, 1, 3 ) ) ==
                0 )
            {
                print "Lynx10-PLC is not responding, trying to reconfigure\n";
                configure_plc($speed);
                $serial_port->baudrate($speed);
                $serial_port->write_settings;
                select( undef, undef, undef, .100 );    # Sleep a bit
                &send( NETID_LYNXNET, pack( 'C3', LNCMD_WRITENVRAM, 1, 3 ) );
            }
        }
    }
}

sub receiver_sensitivity {
    return 0 unless ( 1 == @_ );
    my ($level) = @_;

    # Set receiver sensitivity
    $level = ( 256 * $level ) / 100;
    $level = 255 if ( $level > 255 );
    $level = 0 if ( $level < 0 );
    &send( NETID_X10, pack( 'C3', X10_RECEIVERSENSITIVITY, X10_EOL, $level ) );
}

sub transmit_power {
    return 0 unless ( 1 == @_ );
    my ($level) = @_;

    $level = ( 256 * $level ) / 100;

    # The maximum output power is around 3.6v at Transmitter Level 93% (0xEE#= 238)
    # This is the highest output power I've measured from the LynX-10 PLC.
    #	$level = 255 if ($level > 255);
    $level = 239 if ( $level > 239 );

    $level = 0 if ( $level < 0 );

    &send( NETID_X10, pack( 'C3', X10_TRANSMITPOWER, X10_EOL, $level ) );
}

sub configure_plc {
    return 0 unless ( 1 == @_ );
    print "Configuring Lynx10-PLC\n";

    my ($speed) = @_;

    # Assert break for 250msec. This puts the Lynx10-PLC at 1200
    # and legacy lynx-10 mode
    $serial_port->pulse_break_on(500);
    $serial_port->baudrate(1200);
    $serial_port->write_settings;

    # determine the correct baud rate value
    my $legacy = "00";
    $legacy = "01" if $speed == 2400;
    $legacy = "02" if $speed == 4800;
    $legacy = "03" if $speed == 9600;
    $legacy = "04" if $speed == 19200;
    $legacy = "05" if $speed == 38400;
    $legacy = "06" if $speed == 57600;
    $legacy = "07" if $speed == 115200;
    $serial_port->write( "M00=" . $legacy . "\r" );

    # Set Lynx-Net protocol
    $serial_port->write("M01=01\r");

    # Reboot the device
    $serial_port->write("R\r");

    # sleep a bit
    select( undef, undef, undef, 0.250 );

    $serial_port->baudrate($speed);
    return $serial_port->write_settings;
}

sub check_for_data {

    #my $pkt = &read(1);
    my ($pkt) = @_;
    $pkt = &read(1) unless $pkt;

    $_cmds = undef;
    processPkt($pkt) if ($pkt);

    if ($_cmds) {
        $_queuedCmds .= $_cmds;
        $_queuedCmdsTime = &main::get_tickcount;
    }

    if ( $_queuedCmds
        && ( ( &main::get_tickcount - $_queuedCmdsTime ) >= $multiDelay ) )
    {
        &main::process_serial_data( "X" . $_queuedCmds );
        $_queuedCmds = undef;
    }

    # Force sending UNIT ADDRESS if timeout exceeded
    if ( $_queuedAddr
        && ( ( &main::get_tickcount - $_queuedAddrTime ) >= 300 ) )
    {
        print "Force sending command\n";
        my $payld = &cmd2payld( "XAFORCEADDR", undef );
        &send( NETID_X10, $payld ) if $payld;
    }
}

=item C<send_plc>

This function is used convert an X10 ASCII string into a Lynx-Net packet, and then sends it to the PLC.

Parameters:

  $serial_port : Interface to write the command to
  $cmd		 : ASCII string to parse

Returns: X10 Command in ASCII format

=cut

sub send_plc {

    # Make sure we are passed a pkt
    #return unless ( 3 == @_ );
    return unless ( @_ > 1 and @_ < 4 );

    my ( $self, $cmd, $module_type ) = @_;

    if ( $::config_parms{Lynx10PLC_port} =~ 'proxy' ) {
        print "using proxy, calling proxy_send\n" if $main::Debug{proxy};
        &main::proxy_send( 'Lynx10PLC', 'lynx10plc', 'send_plc', $cmd,
            $module_type );
        return;
    }

    debugPrint("******> $cmd") if $main::Debug{lynx10plc};

    return unless my $payld = &cmd2payld( $cmd, $module_type );
    &send( NETID_X10, $payld );
}

=item C<cmd2payld>

This function is used to convert an ASCII command into the LynxNet command payload.

Parameters:

  $cmd : ASCII command to convert

Returns: LynxNet payload in "packed" format

=cut

sub cmd2payld {
    return undef unless ( 2 == @_ );

    my ( $cmd, $module_type ) = @_;

    my $dim_intervals = ( $module_type =~ /(lm14|preset)/i ) ? 64 : 20;

    # Incoming string looks like this:  XA1AK
    my ( $house, $code ) = $cmd =~ /X(\S)(\S*)/;

    my $hc = $table_hcodes2{$house};
    my $uc = undef;

    my $payld = undef;

    # Save hc if not queued yet
    $_queuedAddr = pack( 'C1', $hc ) unless $_queuedAddr;

    # Command "K" is X10_OFF
    if ( $code =~ /^k/i ) {
        $payld = pack( 'C1', X10_OFF ) . $_queuedAddr . pack( 'C1', X10_EOL );
    }

    # Command "J" is X10_ON
    elsif ( $code =~ /^j/i ) {
        $payld = pack( 'C1', X10_ON ) . $_queuedAddr . pack( 'C1', X10_EOL );
    }

    # Command "L" is X10_BRIGHT
    elsif ( $code =~ /^l/i ) {
        $payld =
          pack( 'C1', X10_BRIGHT ) . $_queuedAddr . pack( 'C2', X10_EOL, 6 );
    }

    # Command "M" is X10_DIM
    elsif ( $code =~ /^m/i ) {
        $payld =
          pack( 'C1', X10_DIM ) . $_queuedAddr . pack( 'C2', X10_EOL, 6 );
    }

    # Command "&P#" is X10_EXTENDED_CODE_1
    elsif ( my ($extended_data) = $code =~ /&P(\d+)/ ) {
        if ( ( $extended_data > 0 ) && ( $extended_data <= 64 ) ) {
            --$extended_data;
            $payld =
                pack( 'C1', X10_EXTENDED_CODE_1 )
              . $_queuedAddr
              . pack( 'C3', X10_EOL, $extended_data, X10_EXTENDED_CODE_1 );
        }
    }

    # Command "-#" is X10_DIM
    elsif ( $code =~ /^-(\d+)$/ ) {
        my $dim = int( ( $1 / 100 ) * $dim_intervals );
        $payld =
          pack( 'C1', X10_DIM ) . $_queuedAddr . pack( 'C2', X10_EOL, $dim )
          if $dim;
    }

    # Command "+#" is X10_BRIGHT
    elsif ( $code =~ /^\+(\d+)$/ ) {
        my $dim = int( ( $1 / 100 ) * $dim_intervals );
        $payld =
          pack( 'C1', X10_BRIGHT ) . $_queuedAddr . pack( 'C2', X10_EOL, $dim )
          if $dim;
    }

    # Command STATUS
    elsif ( $code =~ /^STATUS$/ ) {
        $payld =
            pack( 'C1', X10_STATUS_REQUEST )
          . $_queuedAddr
          . pack( 'C1', X10_EOL );

        #+++ $Lynx10PLC{STATUS_REQUEST} = "$house";
        $Lynx10PLC{STATUS_REQUEST} = $Lynx10PLC{UNIT_ADDRESS};
    }

    # Preset Dim
    elsif ( my ($dim) = $code =~ /PRESET_DIM(\d)$/ ) {
        my $dim_level = $preset_dim_levels2{$house} + ( $dim - 1 ) * 16;
        $payld =
            pack( 'C1', X10_DIM_PRESET )
          . $_queuedAddr
          . pack( 'C2', X10_EOL, $dim_level );
    }

    # Command X10_ALL_LIGHTS_ON
    elsif ( $code =~ /^o/i ) {
        $payld =
          pack( 'C1', X10_ALLLIGHTSON ) . $_queuedAddr . pack( 'C1', X10_EOL );
    }

    # Command X10_ALL_OFF
    elsif ( $code =~ /^p/i ) {
        $payld =
          pack( 'C1', X10_ALLUNITSOFF ) . $_queuedAddr . pack( 'C1', X10_EOL );
    }
    elsif ( $code =~ /^FORCEADDR/i ) {
        $payld =
          pack( 'C1', X10_UNITADDRESS ) . $_queuedAddr . pack( 'C1', X10_EOL );
    }

    # just have house code and unit, no code.
    else {
        $_queuedAddr .= pack( 'C1', $table_ucodes2{$code} );
        $_queuedAddrTime = &main::get_tickcount;
        $Lynx10PLC{UNIT_ADDRESS} = "$house$code";
    }

    debugPrint( "cmd2payld: cmd=$cmd, payld=" . unpack( 'H*', $payld ) )
      if $main::Debug{lynx10plc} && $payld;
    &::logit(
        "$::config_parms{data_dir}/logs/x10.log",
        "out: $cmd, payld=" . unpack( 'H*', $payld ),
        "12"
    ) if $payld;
    $_queuedAddr = undef if $payld;
    return $payld;
}

=item C<processPkt>

This function is used to process a valid LynxNet packet received from the PLC

Parameters:

  $pkt : Lynx-Net packet to process

Returns: 1

=cut

sub processPkt {

    # Get pkt and pktlen
    my ($pkt) = @_;
    my $pktlen = length($pkt);

    &splitPkt($pkt);

    debugPrint( "<-- processPkt: netid="
          . sprintf( "%02X", $_netid )
          . ", payld: len=$_paysz, data="
          . unpack( 'H*', $_payld ) )
      if $main::Debug{lynx10plc};

    &processPkt_X10     if ( $_netid == NETID_X10 );
    &processPkt_LYNXNET if ( $_netid == NETID_LYNXNET );

    return 1;
}

sub processPkt_LYNXNET {
    return unless $_netid == NETID_LYNXNET;
    my $msg = "";

    if ( $_paycmd == LNCMD_MFGANDMODEL ) {
        $msg = "Mfg="
          . unpack( 'H*', substr( $_payld, 1, 2 ) )
          . ", Model="
          . unpack( 'H*', substr( $_payld, 3, 2 ) )
          if $_paysz == 5;
    }
    elsif ( $_paycmd == LNCMD_SERIALNUM ) {
        $msg = "Serial Number=" . unpack( 'H*', substr( $_payld, 1, 8 ) )
          if $_paysz == 9;
    }
    elsif ( $_paycmd == LNCMD_FIRMWAREREV ) {
        $msg = "Firmware Rev=" . unpack( 'H*', substr( $_payld, 1, 2 ) )
          if $_paysz == 3;
    }
    debugPrint("LynxNet $msg") if $msg;
}

sub processPkt_X10 {
    return unless $_netid == NETID_X10;
    my $msg = "";

    # Start by spliting the payld into individual fields
    my @data = unpack( 'C*', $_payld );

    debugPrint( sprintf "paycmd=%02X (%s)", $_paycmd, PayCmdName($_paycmd) )
      if $main::Debug{lynx10plc};

    if ( $_paycmd == X10_UNITADDRESS ) {
        if ( $_paysz >= 3 ) {
            $_cmds = $table_hcodes{ $data[1] } . $table_ucodes{ $data[2] };
            $Lynx10PLC{UNITADDRESS}    = $_cmds;
            $Lynx10PLC{STATUS_REQUEST} = "";
        }
    }
    elsif ( $_paycmd == X10_OFF ) {
        $_cmds = $table_hcodes{ $data[1] } . $table_ucodes{OFF}
          if ( $_paysz >= 2 );
    }
    elsif ( $_paycmd == X10_ON ) {
        $_cmds = $table_hcodes{ $data[1] } . $table_ucodes{ON}
          if ( $_paysz >= 2 );
    }
    elsif ( $_paycmd == X10_DIM ) {
        my $val = unpack( 'C', substr( $_payld, -1, 1 ) );
        if ( $val > 0 ) {
            $_cmds = "-" . $val if ( $_paysz >= 2 );
        }
    }
    elsif ( $_paycmd == X10_BRIGHT ) {
        my $val = unpack( 'C', substr( $_payld, -1, 1 ) );
        if ( $val > 0 ) {
            $_cmds = "+" . $val if ( $_paysz >= 2 );
        }
    }
    elsif ( $_paycmd == X10_PRESETDIM_1 ) {
        $_cmds = $preset_dim_levels{ $data[1] } . "PRESET_DIM1";
    }
    elsif ( $_paycmd == X10_PRESETDIM_2 ) {
        $_cmds = $preset_dim_levels{ $data[1] } . "PRESET_DIM2";
    }
    elsif ( $_paycmd == X10_RD_STATCOUNTER ) {
        if ( $_paysz == 5 ) {
            my $cntr = unpack( 'C', substr( $_payld, 2, 1 ) );
            my $stat =
              unpack( 'C', substr( $_payld, 3, 1 ) ) * 256 +
              unpack( 'C', substr( $_payld, 4, 1 ) );
            my $cntrname = &StatCntrName($cntr);
            $msg = sprintf( "LynxNet X10 %-15s: $stat", $cntrname );
            $Lynx10PLC{$cntrname} = $stat;
        }
    }
    elsif ( $_paycmd == X10_CARRIERPRESENT ) {
        if ( $_paysz == 7 ) {
            my $days =
              unpack( 'C', substr( $_payld, 2, 1 ) ) * 256 +
              unpack( 'C', substr( $_payld, 3, 1 ) );
            my $hours = unpack( 'C', substr( $_payld, 4, 1 ) );
            my $mins  = unpack( 'C', substr( $_payld, 5, 1 ) );
            my $secs  = unpack( 'C', substr( $_payld, 6, 1 ) );

            my $totsecs = ( $days * 24 + $hours ) * 3600 + $mins * 60 + $secs;
            $Lynx10PLC{CARRIERPRESENT} = $totsecs;

            $msg = "LynxNet X10 Uptime         : $days days, $hours:"
              . sprintf( "%02d:%02d", $mins, $secs );
        }
    }
    elsif ( $_paycmd == X10_RECEIVERSENSITIVITY ) {
        if ( $_paysz == 3 ) {
            my $val = unpack( 'C', substr( $_payld, 2, 1 ) );
            $Lynx10PLC{RECEIVERSENSITIVITY} = $val;
            my $percent = int( 100 * ( $val / 255 ) );
            $msg = "LynxNet X10 Receiver Sensitivity = $percent%";
        }
    }
    elsif ( $_paycmd == X10_TRANSMITPOWER ) {
        if ( $_paysz == 3 ) {
            my $val = unpack( 'C', substr( $_payld, 2, 1 ) );
            $Lynx10PLC{TRANSMITPOWER} = $val;
            my $percent = int( 100 * ( $val / 255 ) );
            $msg = "LynxNet X10 Transmit Power = $percent%";
        }
    }
    elsif ( $_paycmd == X10_STATUS ) {
        if ( $_paysz == 2 ) {
            my $status = unpack( 'C', substr( $_payld, 1, 1 ) );
            $msg = "Unknown status";

            $msg = "Ready for commands"   if $status == X10STATUS_OK;
            $msg = "Transmit buffer full" if $status == X10STATUS_BUFFERFULL;
            $msg = "Receiver Decoder Error"
              if $status == X10STATUS_RCVRDECODEERR;
            $msg = "Collision Detected" if $status == X10STATUS_COLLISION;
            $msg = "X-10 Communications Online"
              if $status == X10STATUS_COMONLINE;
            $msg = "Power Failure" if $status == X10STATUS_POWERFAILURE;
            $msg = "X10Status: $msg";

            $error_detected = 1 if $status == X10STATUS_COLLISION;
            $error_detected = 1 if $status == X10STATUS_RCVRDECODEERR;
        }
    }
    elsif ( $_paycmd == X10_STATUS_OFF ) {
        if ( $_paysz == 3 ) {
            my $hc = unpack( 'C', substr( $_payld, 1, 1 ) );
            $hc    = $table_hcodes{$hc};
            $_cmds = $Lynx10PLC{STATUS_REQUEST} . $hc . "STATUS_OFF";

            #+++			$_cmds = $Lynx10PLC{STATUS_REQUEST} . "STATUS_OFF"
            #			if $Lynx10PLC{STATUS_REQUEST} =~ /^$hc/;
        }
    }
    elsif ( $_paycmd == X10_STATUS_ON ) {
        if ( $_paysz == 3 ) {
            my $hc = unpack( 'C', substr( $_payld, 1, 1 ) );
            $hc    = $table_hcodes{$hc};
            $_cmds = $Lynx10PLC{STATUS_REQUEST} . $hc . "STATUS_ON"

              #			$_cmds = $Lynx10PLC{STATUS_REQUEST} . "STATUS_ON"
              #			if $Lynx10PLC{STATUS_REQUEST} =~ /^$hc/;
        }
    }

    elsif ( $_paycmd == X10_EXTENDED_CODE_1 ) {
        if ( $_paysz == 6 ) {
            my ( $foo, $hc, $uc, $eol, $data, $command ) =
              unpack( 'C6', $_payld );
            $hc = $table_hcodes{$hc};
            $uc = $table_ucodes{$uc};

            debugPrint(
                "paysz=$_paysz, hc=$hc, uc=$uc, data=$data, command=$command")
              if $main::Debug{lynx10plc};

            #extended output status
            if ( $command == EXCODE_OUTPUTSTATUSACK ) {

                # B7  1=Load connected
                # B6  0=Lamp, 1=appliance
                # B5-B0 dim level
                my $dim_level = $data & 0x3f;    #bits 0-5
                debugPrint(
                    sprintf "dim_level:$dim_level (%d%%)",
                    int( 100 * $dim_level / 63 ) + 1
                ) if $main::Debug{lynx10plc};
                $_cmds = $hc . $uc . "&P" . $dim_level;
            }
            else {
                $_cmds .= $hc
                  . sprintf( "Z%02x%02x%02x",
                    $table_dcodes2[ $table_ucodes2{$uc} ],
                    $data, $command );
            }
        }
    }
    elsif ( $_paycmd == X10_ALLUNITSOFF ) {
        $_cmds .= "X" . $table_hcodes{ $data[1] } . $table_ucodes{ALL_OFF}
          if ( $_paysz >= 2 );
    }
    elsif ( $_paycmd == X10_ALLLIGHTSON ) {
        $_cmds .= "X" . $table_hcodes{ $data[1] } . $table_ucodes{ALL_LIGHTS_ON}
          if ( $_paysz >= 2 );
    }
    elsif ( $main::Debug{lynx10plc} ) {
        printf "LynxNet X10 unhandled command: %02X\n", $_paycmd;
    }

    debugPrint($msg) if $msg;

    # Sleep for a 1/2 second if a collision detected
    select( undef, undef, undef, 0.500 ) if $msg =~ /Collision/;

    debugPrint( "Lynx10PLC::processPkt_X10: _cmds= " . $_cmds )
      if $main::Debug{lynx10plc} && $_cmds;

    &::logit(
        "$::config_parms{data_dir}/logs/x10.log",
        "in:  $_cmds, payld=" . unpack( 'H*', $_payld ),
        "12"
    ) if $_cmds;
}

=item C<splitPkt>

This function is to extract all of the fields from a packet and store them in global variables. Because of this, the function is NOT re-entrant.

Parameters:

  $pkt : Packet in "packed" format to anaylze

Returns: nothing

=cut

sub splitPkt {

    # Get pkt and pktlen
    my ($pkt) = @_;

    my $pktlen = length($pkt);

    $_netid  = unpack( 'C', substr( $pkt, NETID_OFFSET,  1 ) );
    $_nodeid = unpack( 'C', substr( $pkt, NODEID_OFFSET, 1 ) );
    $_seqnum = unpack( 'C', substr( $pkt, SEQNUM_OFFSET, 1 ) );
    $_payld  = substr( $pkt, PAYLOAD_OFFSET, length($pkt) - PKTSIZE_MIN );
    $_paysz  = length($_payld);
    $_chksum = unpack( 'C', substr( $pkt, $pktlen - 1 ) );
    $_paycmd = unpack( 'C', $_payld ) if $_paysz;
}

=item C<checksum>

This function is used to calculate a 8-bit checksum for a given buffer.

Parameters:

  $buf  : Buffer in "packed" format to calculate checksum on
  $len  : number of bytes to calculate checksum on

Returns: checksum

=cut

sub checksum {
    my ( $buf, $len ) = @_;

    my $sum = 0;
    my @data = unpack( 'C*', $buf );

    for ( my $idx = 0; $idx < $len; ++$idx ) {
        $sum += $data[$idx];
    }

    return $sum & 0xff;
}

=item C<buildPkt>

This function is used to generate a LynxNet packet based upon the packet_type and payload.

Parameters:

  $pkt_type	: Type of packet to send
  $payld	   : Lynx-Net payload

Returns: packet in "pack" format

=cut

sub buildPkt {
    my ( $netid, $payld ) = @_;

    # Get the packet sequnce number
    my $seqnum = $Lynx10PLC{SEQNUM}++ & 0x7F;

    my $pkt = pack( 'C4', $netid, $Lynx10PLC{NODEID}, $seqnum, length($payld) );
    $pkt .= $payld;
    $pkt .= pack( 'C', checksum( $pkt, length($pkt) ) );
    return $pkt;
}

=item C<read>

This function is used to read data from the serial interface, and will return with a complete Lynx-Net packet. If the checksum of the packet is bad, an error message is displayed, and the packet is tossed.

Parameters:

  $no_block	: 0, timeout is 100*50msec=5secs
                  1, timeout is 0secs

Returns: packet in pack format, or undef if no packet was read.

=cut

my $readBuf = ();

sub read {
    my ($no_block) = @_;

    my $tries = ($no_block) ? 1 : 100;

    while ( $tries-- ) {
        my $data;

        # read data from serial port
        if ( $data = $serial_port->input ) {

            # Data was read, so append it to the readBuf
            $readBuf .= $data;

            print "Data rcvd: len="
              . length($data)
              . ", data="
              . unpack( 'H*', $data ) . "\n"
              if $main::Debug{serial};
        }
        else {
            # No data read, so reset errors if any
            $serial_port->reset_error;
        }

        while ( length($readBuf) ) {
            my $id = unpack( 'C', $readBuf );

            # Make sure NetID is valid
            last if $id == NETID_NACK;
            last if $id == NETID_ACK;
            last if $id == NETID_UNDEF;
            last if $id == NETID_X10;
            last if $id == NETID_LYNXNET;

            # NetID is unknown, so toss it in the bitbucket
            print "Unexpected NetID=" . sprintf( "%02X", $id ) . ". Skipping\n";
            $readBuf = substr( $readBuf, 1 );
        }

        print "readBuf=" . unpack( 'H*', $readBuf ) . "\n"
          if length($readBuf) && $main::Debug{serial};

        # See if we have a complete packet
        if ( length($readBuf) >= PKTSIZE_MIN ) {

            # split the buffer into individual characters
            my @data = unpack( 'C*', $readBuf );

            # Calculate the pktlen based upon information in the packet
            my $pktlen = $data[PKTSIZE_OFFSET] + PKTSIZE_MIN;

            # Make sure we have enough data for this packet
            if ( length($readBuf) >= $pktlen ) {

                # Extract the packet from the readBuf
                my $pkt = substr( $readBuf, 0, $pktlen );
                $readBuf = substr( $readBuf, $pktlen );

                # Calculate the checksum of the packet. Keep in mind
                # that the last byte in the packet is the act checksum
                my $sum = &checksum( $pkt, $pktlen - 1 );

                # Extract fields from packet
                &splitPkt($pkt);

                my $status = ();
                $status = sprintf( "  Chksum Failed, act=%02X", $sum )
                  if $sum != $_chksum;

                my $msg =
                    "RD pkt: len="
                  . sprintf( "%2d", length($pkt) )
                  . ", data="
                  . unpack( 'H*', $pkt )
                  . ", payld="
                  . unpack( 'H*', $_payld )
                  . $status;
                $msg .= "(" . PayCmdName($_paycmd) . ")"
                  if $_paycmd and $_payld;
                print "$msg\n" if $main::Debug{serial};
                system("$logger \"$msg\"") if $logger;

                #debugPrint ($msg) if $main::Debug{lynx10plc};

                return $pkt if $sum == $_chksum;
            }
        }
        select undef, undef, undef, 50 / 1000 if ($tries);
    }
    return undef;
}

=item C<send>

This function is used to send a Lynx-Net packet to the serial interface. After the packet is sent, the function will wait for both the "received", and "completed" packets to return.  If a packet other that these two are recieved, it will be processed at this time.  If the packet is not completed within an defined timeout, it will be resent, and the process will repeat, until the retry limit has been exhausted.

Parameters:

  $pkt_type	: Type of packet to send
  $payld	   : Lynx-Net payload to write

Returns:  1 for SUCCESS, 0 for FAILURE

=cut

sub send {
    my ( $pkt_type, $payld ) = @_;

    my $tries = 0;

    RETRY:
    $error_detected = 0;
    print "Lynx10PLC::send: resending packet\n" if $tries;
    return 0 if $tries++ > 2;

    # Construct the packet to send
    my $pkt = &buildPkt( $pkt_type, $payld );

    # Extract the expected sequence number from the packet
    &splitPkt($pkt);
    my ( $exp_seqnum, $exp_netid ) = ( $_seqnum, $_netid );

    my $msg =
        "WR pkt: len="
      . sprintf( "%2d", length($pkt) )
      . ", data="
      . unpack( 'H*', $pkt )
      . ", payld="
      . unpack( 'H*', $payld );
    $msg .= "(" . PayCmdName($_paycmd) . ")" if $_paycmd;
    print "$msg\n" if $main::Debug{serial};
    system("$logger \"$msg\"") if $logger;

    # write packet to serial interface
    if ( length($pkt) != $serial_port->write($pkt) ) {
        print "Bad Lynx10PLC data send transmition\n";
        goto RETRY;
    }

    ACK_PKT:

    # Read packet from interface
    goto RETRY unless $pkt = &read();

    if ( $exp_seqnum != $_seqnum ) {
        processPkt($pkt);
        goto ACK_PKT;
    }

    # We are expecting an ACK packet at this time
    goto RETRY if ( NETID_ACK != $_netid );

    DONE_PKT:

    # Read packet from interface
    goto RETRY unless $pkt = &read();

    if ( ( $exp_seqnum != $_seqnum ) || ( $_paysz != 1 ) ) {
        processPkt($pkt);
        goto DONE_PKT;
    }

    # We are expecting a DONE packet at this time.

    # Retry if the NETID is not ours. This is a bad thing at this time.
    goto RETRY if ( $exp_netid != $_netid );
    goto RETRY if ( unpack( 'C', $_payld ) != LNCMD_SUCCESS );

    # Resend the packet if an error  was detected during the send
    goto RETRY if $error_detected;

    return 1;
}

sub debugPrint {
    my ($msg) = @_;
    printf "%02d:%02d:%02d %s\n", $main::Hour, $main::Minute, $main::Second,
      $msg;
}

sub StatCntrName {
    my ($cntr) = @_;

    return "TRANSMIT_PKTS"  if ( $cntr == STATCNTR_TRANSMIT_PKTS );
    return "RECEIVED_PKTS"  if ( $cntr == STATCNTR_RECEIVED_PKTS );
    return "RECEPTION_ERRS" if ( $cntr == STATCNTR_RECEPTION_ERRS );
    return "TRANSMIT_ERRS"  if ( $cntr == STATCNTR_TRANSMIT_ERRS );
    return "COLLISIONS"     if ( $cntr == STATCNTR_COLLISIONS );
    return "POWERFAILURES"  if ( $cntr == STATCNTR_POWERFAILURES );
    return "UNKNOWN";
}

sub PayCmdName {
    my ($cmd) = @_;
    return "X10_CMDFAILURE"           if ( $cmd == X10_CMDFAILURE );
    return "X10_CMDSUCCESS"           if ( $cmd == X10_CMDSUCCESS );
    return "X10_STATUS"               if ( $cmd == X10_STATUS );
    return "X10_MONITORDATA"          if ( $cmd == X10_MONITORDATA );
    return "X10_ANALYZERDATA"         if ( $cmd == X10_ANALYZERDATA );
    return "X10_UNITADDRESS"          if ( $cmd == X10_UNITADDRESS );
    return "X10_ALLUNITSOFF"          if ( $cmd == X10_ALLUNITSOFF );
    return "X10_ALLLIGHTSON"          if ( $cmd == X10_ALLLIGHTSON );
    return "X10_ON"                   if ( $cmd == X10_ON );
    return "X10_OFF"                  if ( $cmd == X10_OFF );
    return "X10_DIM"                  if ( $cmd == X10_DIM );
    return "X10_BRIGHT"               if ( $cmd == X10_BRIGHT );
    return "X10_ALLLIGHTSOFF"         if ( $cmd == X10_ALLLIGHTSOFF );
    return "X10_EXTENDEDCODETRANSFER" if ( $cmd == X10_EXTENDEDCODETRANSFER );
    return "X10_HAILREQUEST"          if ( $cmd == X10_HAILREQUEST );
    return "X10_HAILACKNOWLEDGE"      if ( $cmd == X10_HAILACKNOWLEDGE );
    return "X10_PRESETDIM_1"          if ( $cmd == X10_PRESETDIM_1 );
    return "X10_PRESETDIM_2"          if ( $cmd == X10_PRESETDIM_2 );
    return "X10_EXTENDEDDATATRANSFER" if ( $cmd == X10_EXTENDEDDATATRANSFER );
    return "X10_STATUS_ON"            if ( $cmd == X10_STATUS_ON );
    return "X10_STATUS_OFF"           if ( $cmd == X10_STATUS_OFF );
    return "X10_STATUS_REQUEST"       if ( $cmd == X10_STATUS_REQUEST );
    return "X10_EVERYUNITOFF"         if ( $cmd == X10_EVERYUNITOFF );
    return "X10_EVERYLIGHTOFF"        if ( $cmd == X10_EVERYLIGHTOFF );
    return "X10_EVERYLIGHTON"         if ( $cmd == X10_EVERYLIGHTON );
    return "X10_DIM_PRESET"           if ( $cmd == X10_DIM_PRESET );
    return "X10_OPTIONS"              if ( $cmd == X10_OPTIONS );
    return "X10_CARRIERPRESENT"       if ( $cmd == X10_CARRIERPRESENT );
    return "X10_RD_STATCOUNTER"       if ( $cmd == X10_RD_STATCOUNTER );
    return "X10_CLR_STATCOUNTER"      if ( $cmd == X10_CLR_STATCOUNTER );
    return "X10_RECEIVERSENSITIVITY"  if ( $cmd == X10_RECEIVERSENSITIVITY );
    return "X10_TRANSMITPOWER"        if ( $cmd == X10_TRANSMITPOWER );
    return "X10_SELECTCHANNEL"        if ( $cmd == X10_SELECTCHANNEL );
    return "X10_RAWPOWERLINEDATA"     if ( $cmd == X10_RAWPOWERLINEDATA );
    return "X10_EOL"                  if ( $cmd == X10_EOL );
    return "X10_EXTENDED_CODE_1"      if ( $cmd == X10_EXTENDED_CODE_1 );
    return "X10_EXTENDED_CODE_2"      if ( $cmd == X10_EXTENDED_CODE_2 );
    return "X10_EXTENDED_CODE_3"      if ( $cmd == X10_EXTENDED_CODE_3 );
    return "X10_EXTENDED_CODE_4"      if ( $cmd == X10_EXTENDED_CODE_4 );
    return "UNKNOWN";
}

sub ReadStatCntr {
    my ($cntr) = @_;

    &send( NETID_X10, pack( 'C3', X10_RD_STATCOUNTER, X10_EOL, $cntr ) );
    return $Lynx10PLC{ &StatCntrName($cntr) };
}

sub ClrStatCntr {
    my ($cntr) = @_;

    &send( NETID_X10, pack( 'C3', X10_CLR_STATCOUNTER, X10_EOL, $cntr ) );
}

my @stat_cntrs = (
    STATCNTR_TRANSMIT_PKTS,  STATCNTR_RECEIVED_PKTS,
    STATCNTR_RECEPTION_ERRS, STATCNTR_TRANSMIT_ERRS,
    STATCNTR_COLLISIONS,     STATCNTR_POWERFAILURES
);

sub clearAllStats {
    foreach my $cntr (@stat_cntrs) {
        &ClrStatCntr($cntr);
    }
}

sub readAllStats {
    foreach my $cntr (@stat_cntrs) {
        my $val = &ReadStatCntr($cntr);
    }

    my @other = (X10_CARRIERPRESENT);

    while ( scalar @other ) {
        &send( NETID_X10, pack( 'C2', shift @other, X10_EOL ) );
    }

    #	&sendExtendedCode($table_hcodes2{'M'}, $table_ucodes2{'E'}, EXCODE_PRESETDIM, 0x25);
}

sub readDeviceInfo {
    my @cmds = ( LNCMD_MFGANDMODEL, LNCMD_SERIALNUM, LNCMD_FIRMWAREREV );
    while ( scalar @cmds ) {
        &send( NETID_LYNXNET, pack( 'C1', shift @cmds ) );
    }
    &send( NETID_LYNXNET, pack( 'C2', LNCMD_READNVRAM, 01 ) );

    my @other = ( X10_RECEIVERSENSITIVITY, X10_TRANSMITPOWER );
    while ( scalar @other ) {
        &send( NETID_X10, pack( 'C2', shift @other, X10_EOL ) );
    }
}

sub sendExtendedCode {
    return unless ( 4 == @_ );
    my ( $hc, $uc, $cmd, $data ) = @_;

    &send( NETID_X10,
        pack( 'C6', X10_EXTENDED_CODE_1, $hc, $uc, X10_EOL, $data, $cmd ) );
}

sub sendX10On {
    return unless ( 2 == @_ );
    my ( $hc, $uc ) = @_;

    &send( NETID_X10, pack( 'C4', X10_ON, $hc, $uc, X10_EOL ) );
}

sub sendX10ff {
    return unless ( 2 == @_ );
    my ( $hc, $uc ) = @_;

    &send( NETID_X10, pack( 'C4', X10_OFF, $hc, $uc, X10_EOL ) );
}

sub sendPresetDim {
    return unless ( 3 == @_ );
    my ( $hc, $uc, $level ) = @_;

    &send( NETID_X10, pack( 'C5', X10_DIM_PRESET, $hc, $uc, X10_EOL, $level ) );
}

sub sendDim {
    return unless ( 3 == @_ );
    my ( $hc, $uc, $level ) = @_;

    &send( NETID_X10, pack( 'C5', X10_DIM, $hc, $uc, X10_EOL, $level ) );
}

sub sendBright {
    return unless ( 3 == @_ );
    my ( $hc, $uc, $level ) = @_;

    &send( NETID_X10, pack( 'C5', X10_BRIGHT, $hc, $uc, X10_EOL, $level ) );
}

sub sendStatusRequest {
    return unless ( 2 == @_ );
    my ( $hc, $uc ) = @_;

    &send( NETID_X10, pack( 'C4', X10_STATUS_REQUEST, $hc, $uc, X10_EOL ) );
}

sub sendUnitCode {
    return unless ( 2 == @_ );
    my ( $hc, $uc ) = @_;

    &send( NETID_X10, pack( 'C4', X10_UNITADDRESS, $hc, $uc, X10_EOL ) );
}
return 1;    # for require

=cut

Revision History

 Version 1.0 12/4/2001 - Initial release

 Version 1.1 2/1/2002  - Added code to reconfigure the device if it
                                                 is not responding to Lynx-Net commands. The
                                                 device comes from the factory set at legacy
                                                 lynx-10 protocol and 1200 baud. This change
                                                 no longer requires that the device be programmed
                                                 using the Lynx10-PLC Setup utility under windows
 Version 1.2 9/24/2002 - Changed logging to syslog for linux systems.
                                                 Added parameters to set gains for transmit and receive.
 Version 1.3 2/25/2003 - Added two way support to module.
                                                 Updated file to use new mh debug mechanism ($main::Debug)

 Version 1.4 4/25/2003 - Updates from Craig Schaeffer to support PRESET_DIM[12] commands.
                                                 cmd2payld parser now expects XA1AK command format instead of
                                                   previously wanting XA1K. (Need updated Serial_Item.pm)
                                                 Added mode debug output.
                                                 Moved stat counter update on the hour to Lynx10PLC.pl (code/common dir)
                                                 Added support for Unit Address, and Extended Code 1
                                                 Added a number of API methods to allow users to access low level
                                                  commands on the Lynx10PLC without having to understand the devices
                                                  API.

 Version 1.5 5/4/2003  - Fixed bug with DIM/BRIGHT command where level was parsed incorrectly after
                          switching to the XA1AK command format.

 Version 1.6 11/10/2005- Added support for all EXTENDED_CODE_1 commands
                                                 Added Lynx10PLC_MULTI_DELAY keyword and support that allows multiple packets
                                                 to be combined together if they come in seperate, but within the specified
                                                 time of each other.

 Version 1.7 5/18/2006 - Added support to handle individual commands instead of requiring pairs. This
                         allows the module to support the "group" capability similar to the CM11.


=back

=head2 INI PARAMETERS

Use these mh.ini parameters to enable the code:

  Lynx10PLC_module = Lynx10PLC
  Lynx10PLC_port=/dev/ttyS0
  Lynx10PLC_baudrate=19200

These parameters allow you to override the default transmit and receive gain values

  Lynx10PLC_XMIT_PWR=75
  Lynx10PLC_RCVR_SENS=50

This parameter will enable the module to log data using syslogd. This example will log
data to local5 facility, with priority set to info

  Lynx10PLC_LOGGER=/usr/bin/logger -p local5.info --

This parameter will allow you to specify the amount of delay time after a packet has been
received before sending it onto MH. This allows multiple commands to be glued together.
This time is in milliseconds

  Lynx10PLC_MULTI_DELAY = 250

=head2 AUTHOR

Joe Blecher  misterhouse@blecherfamily.net

=head2 SEE ALSO

NONE

=head2 LICENSE

Copyright (c) 2001-2005 Joe Blecher. All rights reserved.
This program is free software.  You may modify and/or
distribute it under the same terms as Perl itself.
This copyright notice must remain attached to the file.

LEGAL DISCLAIMER:

  This software is provided as-is.  Use it at your own risk.  The
  author takes no responsibility for any damages or losses directly
  or indirectly caused by this software.

=cut

