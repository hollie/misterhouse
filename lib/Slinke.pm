
=head1 B<Slinke>

=head2 SYNOPSIS

  use Slinke;

  # Create a Slinke and read from the infrared port
  my $slinke = new Slinke;
  my $data = $slinke->requestInput();

  foreach my $i ( @$data ) {
     print "$i\n";
  }

The different port names are exported.  These are the following:

  PORT_SL0 PORT_SL1 PORT_SL2 PORT_SL3 PORT_IR PORT_PAR PORT_SER PORT_SYS

=head2 DESCRIPTION

Slink-e is a module to control the Slink-e product produced by Nirvis -
visit Nirvis at http://www.nirvis.com

Slink-e is a product that can speak to many different Sony products over
the S-Link port.  Also, it can receive and transmit infrared signals over
8 different transmitters/receivers.

For now, the bulk of this code deals with the transmission and reception
of these infrared signals.

Note that this code borrows heavily from C++ code from Colby Boles.  In
fact, sometimes I just copied his code and comments verbatim.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

package Slinke;

use strict;
use Exporter;
use Device::SerialPort qw( :PARAM :STAT 0.07 );
use vars qw( @ISA $VERSION @EXPORT );

$VERSION = 1.00;
@ISA     = qw(Exporter);

@EXPORT =
  qw( PORT_SL0 PORT_SL1 PORT_SL2 PORT_SL3 PORT_IR PORT_PAR PORT_SER PORT_SYS decodeIR );

$Slinke::SLINKE_NUMPORTS = 8;
$Slinke::SLINKE_CLK      = 20.0e6;
$Slinke::PORT_IR_MAXML   = 15;
$Slinke::IRSKEWADJUST    = -100e-6;
$Slinke::MAXDATABLOCK    = 30;     # largest block the slinke can handle at once

%Slinke::PORTS = (
    PORT_SL0 => 0,
    PORT_SL1 => 1,
    PORT_SL2 => 2,
    PORT_SL3 => 3,
    PORT_IR  => 4,
    PORT_PAR => 5,
    PORT_SER => 6,
    PORT_SYS => 7,
);

%Slinke::COMMANDS = (
    CMD_PORT_DONE => 0x00,
    CMD_PORT_SM   => 0x1F,

    # port commands
    # general
    CMD_DISABLE => 0x02, CMD_ENABLE => 0x03,

    # S-Link
    CMD_SENDBITMODE => 0x04,

    # ir
    CMD_SETIRFS        => 0x04,
    CMD_GETIRFS        => 0x05,
    CMD_SETIRCFS       => 0x06,
    CMD_GETIRCFS       => 0x07,
    CMD_SETIRTIMEOUT   => 0x0C,
    CMD_GETIRTIMEOUT   => 0x0D,
    CMD_SETIRMINLEN    => 0x0E,
    CMD_GETIRMINLEN    => 0x0F,
    CMD_SETIRTXPORTS   => 0x08,
    CMD_GETIRTXPORTS   => 0x13,
    CMD_SETIRRXPORTEN  => 0x09,
    CMD_GETIRRXPORTEN  => 0x12,
    CMD_SETIRPORTECHO  => 0x0A,
    CMD_GETIRPORTECHO  => 0x10,
    CMD_SETIRRXPORTPOL => 0x0B,
    CMD_GETIRRXPORTPOL => 0x11,

    # serial
    CMD_SETBAUD => 0x08, CMD_GETBAUD => 0x09,

    # parallel
    CMD_SETHSMODE => 0x10,
    CMD_GETHSMODE => 0x11,
    CMD_SETDIR    => 0x12,
    CMD_GETDIR    => 0x13,
    CMD_SAMPLE    => 0x14,

    # system
    CMD_GETVERSION   => 0x0B,
    CMD_GETSERIALNO  => 0x0C,
    CMD_SETSERIALNO  => 0x0D,
    CMD_SAVEDEFAULTS => 0x0E,
    CMD_LOADDEFAULTS => 0x0F,
    CMD_RESUME       => 0xAA,
    CMD_RESET        => 0xFF,

    # custom for SEG
    CMD_PLAYMACRO1  => 0x10,
    CMD_PLAYMACRO2  => 0x11,
    CMD_STOREMACRO1 => 0x12,
    CMD_STOREMACRO2 => 0x13,
);

%Slinke::RESPONSES = (    # port responses
    RSP_PORT_DONE => 0x00, RSP_PORT_SM => 0x1F,

    # port special messages
    # general
    RSP_DISABLE     => 0x02,
    RSP_ENABLE      => 0x03,
    RSP_TX_TIMEOUT  => 0x81,
    RSP_CMD_ILLEGAL => 0xFF,
    RSP_RX_ERROR    => 0x80,

    # S-Link
    RSP_RX_BITMODE => 0x04,

    # ir
    RSP_EQRXPORT      => 0x01,
    RSP_EQIRFS        => 0x04,
    RSP_EQIRCFS       => 0x06,
    RSP_EQIRPORTECHO  => 0x0A,
    RSP_EQIRTIMEOUT   => 0x0C,
    RSP_EQIRMINLEN    => 0x0E,
    RSP_EQIRRXPORTEN  => 0x09,
    RSP_EQIRRXPORTPOL => 0x0B,
    RSP_EQIRTXPORTS   => 0x08,
    RSP_IRFS_ILLEGAL  => 0x82,

    # serial
    RSP_EQBAUD              => 0x08,
    RSP_SERIALIN_OVERFLOW   => 0x83,
    RSP_SERIALIN_OVERRUN    => 0x86,
    RSP_SERIALIN_FRAMEERROR => 0x85,
    RSP_BAUD_ILLEGAL        => 0x84,

    # parallel
    RSP_EQHSMODE => 0x10, RSP_EQDIR => 0x12,

    # system
    RSP_EQVERSION      => 0x0B,
    RSP_EQSERIALNO     => 0x0C,
    RSP_DEFAULTSSAVED  => 0x0E,
    RSP_DEFAULTSLOADED => 0x0F,
    RSP_SEEPROMWRERR   => 0x8F,
);

%Slinke::INVPORTS = reverse %Slinke::PORTS;

foreach my $i ( keys %Slinke::RESPONSES ) {
    push @{ $Slinke::INVRESPONSES{ $Slinke::RESPONSES{$i} } }, $i;
}

%Slinke::COMMANDMAPS = (
    "CMD_GETBAUD"        => [ "PORT_SER", "RSP_EQBAUD" ],
    "CMD_SETBAUD"        => [ "PORT_SER", "RSP_EQBAUD" ],
    "CMD_GETSERIALNO"    => [ "PORT_SYS", "RSP_EQSERIALNO" ],
    "CMD_GETVERSION"     => [ "PORT_SYS", "RSP_EQVERSION" ],
    "CMD_ENABLE"         => [ undef,      "RSP_ENABLE" ],
    "CMD_DISABLE"        => [ undef,      "RSP_DISABLE" ],
    "CMD_GETIRFS"        => [ "PORT_IR",  "RSP_EQIRFS" ],
    "CMD_SETIRFS"        => [ "PORT_IR",  "RSP_EQIRFS" ],
    "CMD_GETIRCFS"       => [ "PORT_IR",  "RSP_EQIRCFS" ],
    "CMD_SETIRCFS"       => [ "PORT_IR",  "RSP_EQIRCFS" ],
    "CMD_GETIRTIMEOUT"   => [ "PORT_IR",  "RSP_EQIRTIMEOUT" ],
    "CMD_SETIRTIMEOUT"   => [ "PORT_IR",  "RSP_EQIRTIMEOUT" ],
    "CMD_GETIRMINLEN"    => [ "PORT_IR",  "RSP_EQIRMINLEN" ],
    "CMD_SETIRMINLEN"    => [ "PORT_IR",  "RSP_EQIRMINLEN" ],
    "CMD_GETIRTXPORTS"   => [ "PORT_IR",  "RSP_EQIRTXPORTS" ],
    "CMD_SETIRTXPORTS"   => ["PORT_IR"],
    "CMD_GETIRRXPORTEN"  => [ "PORT_IR",  "RSP_EQIRRXPORTEN" ],
    "CMD_SETIRRXPORTEN"  => [ "PORT_IR",  "RSP_EQIRRXPORTEN" ],
    "CMD_GETIRPORTECHO"  => [ "PORT_IR",  "RSP_EQIRPORTECHO" ],
    "CMD_SETIRPORTECHO"  => [ "PORT_IR",  "RSP_EQIRPORTECHO" ],
    "CMD_GETIRRXPORTPOL" => [ "PORT_IR",  "RSP_EQIRRXPORTPOL" ],
    "CMD_SETIRRXPORTPOL" => [ "PORT_IR",  "RSP_EQIRRXPORTPOL" ],
    "CMD_GETHSMODE"      => [ "PORT_PAR", "RSP_EQHSMODE" ],
    "CMD_SETHSMODE"      => [ "PORT_PAR", "RSP_EQHSMODE" ],
    "CMD_GETDIR"         => [ "PORT_PAR", "RSP_EQDIR" ],
    "CMD_SETDIR"         => [ "PORT_PAR", "RSP_EQDIR" ],
    "CMD_SAMPLE"         => ["PORT_PAR"],
    "CMD_RESUME"         => ["PORT_SYS"],
    "CMD_RESET"          => ["PORT_SYS"],
    "CMD_LOADDEFAULTS"   => [ "PORT_SYS", "RSP_DEFAULTSLOADED" ],
    "CMD_SAVEDEFAULTS"   => [ "PORT_SYS", "RSP_DEFAULTSSAVED" ],
);

%Slinke::RESPONSEFORSL = (
    RSP_ENABLE  => 0,
    RSP_DISABLE => 0,
);

%Slinke::RESPONSEMAPS = (
    PORT_SL0 => \%Slinke::RESPONSEFORSL,
    PORT_SL1 => \%Slinke::RESPONSEFORSL,
    PORT_SL2 => \%Slinke::RESPONSEFORSL,
    PORT_SL3 => \%Slinke::RESPONSEFORSL,
    PORT_IR  => {
        RSP_ENABLE        => 0,
        RSP_DISABLE       => 0,
        RSP_EQIRFS        => 2,
        RSP_EQIRCFS       => 2,
        RSP_EQIRTIMEOUT   => 2,
        RSP_EQIRMINLEN    => 1,
        RSP_EQIRTXPORTS   => 1,
        RSP_EQRXPORT      => 1,
        RSP_EQIRRXPORTEN  => 1,
        RSP_EQIRRXPORTPOL => 1,
        RSP_EQIRPORTECHO  => 16,
    },
    PORT_PAR => {
        RSP_ENABLE   => 0,
        RSP_DISABLE  => 0,
        RSP_EQHSMODE => 1,
        RSP_EQDIR    => 1,
    },
    PORT_SYS => {
        RSP_ENABLE         => 0,
        RSP_DISABLE        => 0,
        RSP_EQVERSION      => 1,
        RSP_EQSERIALNO     => 8,
        RSP_DEFAULTSLOADED => 0,
        RSP_DEFAULTSSAVED  => 0,
    },
    PORT_SER => {
        RSP_EQBAUD => 1,

        # RSP_FLUSH        => 4,

    },
);

# Error codes
%Slinke::ERRORS = (
    RSP_RX_ERROR     => [ "Receive Error",                                  0 ],
    RSP_TX_TIMEOUT   => [ "Transmit Timeout Error - critical, will resume", 1 ],
    RSP_CMD_ILLEGAL  => [ "Illegal Command - critical, will resume",        1 ],
    RSP_IRFS_ILLEGAL => [ "Illegal Sample Period",                          0 ],
    RSP_SERIALIN_OVERFLOW => [ "Receive overflow - critical, will resume", 1 ],
    RSP_SERIALIN_OVERRUN  => [ "Receive overrun - critical, will resume",  1 ],
    RSP_SERIALIN_FRAMEERROR =>
      [ "Receive framing error - critical, will resume", 1 ],
    RSP_BAUD_ILLEGAL => [ "Illegal Baud Rate",   0 ],
    RSP_SEEPROMWRERR => [ "SEEPROM Write Error", 0 ],
);

=item C<new>

  $slinke = new Slinke( [ DEVICE => $device, SERIALPORT => $serialport ] );

Returns a newly created C<Slinke> object.

C<$device> is the name of the device that the Slink-e is connected to.

If no device is provided, a search is made on the following devices:
/dev/ttyS0 /dev/ttyS1 /dev/ttyS2 /dev/ttyS3

On windows, COM ports 1-8 are searched

If you would rather provide a SerialPort object, you can do that by
setting the SERIALPORT argument

=cut

sub new {
    my $class = shift;
    my %args  = @_;

    my $self;
    $self->{DEBUG}         = 0;
    $self->{RETURNONINPUT} = 0;
    bless( $self, $class );

    if ( $args{SERIALPORT} ) {
        $self->{SERIALPORT} = $args{SERIALPORT};
    }
    else {
        my $OS_win = ( $^O =~ "MSWin32" ) ? 1 : 0;
        my @portsToTry = qw( /dev/ttyS0 /dev/ttyS1 /dev/ttyS2 /dev/ttyS3 );
        @portsToTry = qw( COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 ) if $OS_win;

        if   ($OS_win) { require Win32::SerialPort; }
        else           { require Device::SerialPort; }

        if ( $args{DEVICE} ) {
            if ($OS_win) {
                $self->{SERIALPORT} = new Win32::SerialPort( $args{DEVICE} );
            }
            else {
                $self->{SERIALPORT} = new Device::SerialPort( $args{DEVICE} );
            }
        }
        else {
            foreach my $i (@portsToTry) {
                if ($OS_win) {
                    $self->{SERIALPORT} = new Win32::SerialPort($i);
                }
                else { $self->{SERIALPORT} = new Device::SerialPort($i); }
                next if !defined( $self->{SERIALPORT} );

                $self->initDevice();
                $self->loadInternals();
                my $baud = $self->requestBaud;
                if ( defined $baud && $baud > 0 ) {
                    $args{DEVICE} = $i;
                    last;
                }
                $self->{SERIALPORT}->close;
            }
            if ( !$args{DEVICE} ) {
                die(    "Can't find a Slink-e on any of the following: "
                      . join( " ", @portsToTry )
                      . "\n" );
            }
        }
    }

    $self->initDevice();
    $self->loadInternals();
    my $version = $self->requestFirmwareVersion;
    if ( !defined $version ) {
        die "Can't find a Slink-e on $args{ DEVICE }\n";
    }
    $self->{VERSION} = $version;

    return $self;
}

sub initDevice {
    my $this = shift;

    $this->{SERIALPORT}->baudrate(38400);
    $this->{SERIALPORT}->parity("none");
    $this->{SERIALPORT}->databits(8);
    $this->{SERIALPORT}->stopbits(1);
    $this->{SERIALPORT}->handshake("rts");
}

sub loadInternals {
    my $this = shift;

    $this->{BAUD} = $this->requestBaud();
    $this->setIRSamplingPeriod( 100 / 1e6 );
    $this->{IRSAMPLEPERIOD} = $this->requestIRSamplingPeriod();
}

sub debug {
    my $this = shift;

    $this->{DEBUG} = shift;
}

sub writeToPort {
    my $this = shift;

    my $string;
    while ( defined( my $s = shift ) ) {
        my $tmpString = $s;
        if ( $s =~ /^\d*$/ ) {
            $tmpString = sprintf( "%02x", $s );
            $s = chr($s);
        }
        $string .= $s;
        print $tmpString, " " if $this->{DEBUG};
    }
    print "\n" if $this->{DEBUG};
    my $count = $this->{SERIALPORT}->write($string);
    if ( !$count ) {
        warn "write failed\n";
        return undef;
    }
    elsif ( $count != length($string) ) {
        warn "write incomplete\n";
        return undef;
    }

    return 1;
}

sub receive {
    my $this          = shift;
    my %args          = @_;
    my $timeout       = $args{TIMEOUT} || 60;
    my $returnOnInput = $args{RETURNONINPUT} || 0;
    my $expectInput   = $args{EXPECTINPUT} || 0;

    $this->{SERIALPORT}->read_const_time($timeout);
    while ( my ( $count, $rch ) = $this->{SERIALPORT}->read(1) ) {
        if ( $count != 1 ) {

            #	    warn "read of device and datalen unsuccessful\n";
            return undef if !$expectInput;
            next;
        }

        $rch = ord($rch);

        my $device  = $rch >> 5;
        my $datalen = $rch & 0x1F;
        my $response;
        my $data;

        if ( exists $Slinke::INVPORTS{$device} ) {
            $device = $Slinke::INVPORTS{$device};
        }
        else {
            warn "Unknown device: $device\n";
            return undef;
        }

        if ( $datalen != $Slinke::RESPONSES{RSP_PORT_SM} ) {
            my $finished = 0;
            if ( $datalen == 0 ) {
                if ( $device ne "PORT_IR" ) {
                    my @t;
                    my $str = $this->{PORTDATA}{$device};
                    while ($str) {
                        my $hex;
                        ( $hex, $str ) = $str =~ /^(..)(.*)/;
                        push @t, hex($hex);
                    }
                    push @{ $this->{RECEIVED} },
                      {
                        PORT => $device,
                        DATA => [@t],
                      };
                    $this->{PORTDATA}{$device} = "";
                    $finished = 1;
                }
                elsif ( $this->{VERSION} < 2.0 ) {
                    my $str = $this->cleanupRLC(
                        substr( $this->{PORTDATA}{$device}, 0, -1 ) );
                    my @t = split / /, $str;
                    push @{ $this->{RECEIVED} },
                      {
                        PORT   => $device,
                        DATA   => [@t],
                        TIME   => $this->{PORTTIME}{$device},
                        IRPORT => 0x01,
                      };

                    $this->{PORTTIME}{$device} = 0;
                    $this->{PORTDATA}{$device} = "";
                    $finished                  = 1;
                }
            }
            else {
                # we'll be a lot more patient since we know data is coming
                $this->{SERIALPORT}->read_const_time(100);

                ( $count, $rch ) = $this->{SERIALPORT}->read($datalen);
                if ( $count != $datalen ) {
                    warn
                      "read of $device unsuccessful - read $count expected $datalen\n";
                    return undef;
                }
                if ( $device eq "PORT_IR" ) {
                    if ( !defined( $this->{PORTTIME}{$device} )
                        || $this->{PORTTIME}{$device} < 1.0 )
                    {
                        my ( $rlc, $timing ) = $this->int8ToRLC($rch);
                        $this->{PORTDATA}{$device} .= $rlc;
                        $this->{PORTTIME}{$device} += $timing;
                    }
                }
                else {
                    $rch = unpack( "H*", $rch ) if defined $rch;
                    $this->{PORTDATA}{$device} .= $rch;
                }
            }

            next;
            if ( $finished && $returnOnInput ) {
                return ( $device, $response, $data );
            }
            else {
                next;
            }
        }

        if ( !exists $Slinke::RESPONSEMAPS{$device} ) {
            warn( __PACKAGE__
                  . " package does not handle device '$device' yet\n" );
            $this->{SERIALPORT}->input();
            return undef;
        }

        ( $count, $response ) = $this->{SERIALPORT}->read(1);
        if ( $count != 1 ) {
            warn "read of $device unsuccessful (datalen = $datalen)\n";
            return undef;
        }

        $response = ord($response);
        if ( !exists $Slinke::INVRESPONSES{$response} ) {
            warn "Error on device '$device' - Unknown response: $response\n";
            return undef;
        }

        # Since the hex codes can mean different things, we have to
        # check a list of reponses to get the correct inverse response;
        my $responseFound = 0;
        foreach my $i ( @{ $Slinke::INVRESPONSES{$response} } ) {
            if (   exists $Slinke::RESPONSEMAPS{$device}{$i}
                || exists $Slinke::ERRORS{$i} )
            {
                $response      = $i;
                $responseFound = 1;
                last;
            }
        }

        if ( exists $Slinke::ERRORS{$response} ) {
            warn
              "ERROR $response on $device: $Slinke::ERRORS{ $response }->[0]\n";
            if ( $Slinke::ERRORS{$response}->[1] ) {
                $this->resume();
            }
        }

        if ( !$responseFound ) {
            if ( $#{ $Slinke::INVRESPONSES{$response} } == 0 ) {
                $response = @{ $Slinke::INVRESPONSES{$response} }[0];
            }
            else {
                $response = "0x" . uc( sprintf( "%02x", $response ) );
            }

            warn( __PACKAGE__
                  . " package does not handle response '$response' on device '$device' yet\n"
            );
            $this->{SERIALPORT}->input();
            return undef;
        }

        my $bytesToRead = $Slinke::RESPONSEMAPS{$device}{$response};
        if ($bytesToRead) {
            ( $count, $data ) = $this->{SERIALPORT}->read($bytesToRead);
            if ( $count != $bytesToRead ) {
                warn "Read of $response on $device unsuccessful\n";
                return undef;
            }

            $data = unpack( "H*", $data ) if defined $data;
        }

        if ( $device eq "PORT_IR" && $response eq "RSP_EQRXPORT" ) {
            my $str =
              $this->cleanupRLC( substr( $this->{PORTDATA}{$device}, 0, -1 ) );
            my @t = split / /, $str;
            my $irport = 1 << $data;
            push @{ $this->{RECEIVED} },
              {
                PORT   => $device,
                DATA   => [@t],
                TIME   => $this->{PORTTIME}{$device},
                IRPORT => $irport,
              };

            $this->{PORTDATA}{$device} = "";
            $this->{PORTTIME}{$device} = 0;

            next if !$returnOnInput;
        }

        return ( $device, $response, $data );
    }
}

sub cleanupRLC {
    my $this = shift;
    my @data = split / /, shift;

    # let's make sure that we alternate even and odd numbers
    my @newdata;
    push @newdata, shift @data;
    while ( defined( my $i = shift @data ) ) {
        if (   ( $i > 0 && $newdata[$#newdata] > 0 )
            || ( $i < 0 && $newdata[$#newdata] < 0 ) )
        {
            $newdata[$#newdata] += $i;
        }
        else {
            push @newdata, $i;
        }
    }

    return join( " ", @newdata );
}

sub int8ToRLC {
    my $this = shift;
    my $data = shift;

    my $oldsign = 33;    # don't use 0x00 or 0x80

    my $numtime   = 0;
    my $num       = 0;
    my $signallen = 0;
    my $sign      = 1;
    my $numstr;

    foreach my $i ( split / */, $data ) {
        $i    = ord($i);
        $sign = $i & 0x80;
        $i &= 0x7f;

        if ( $sign != $oldsign ) {

            # signal change
            if ( $oldsign != 33 ) {

                # write out num first
                $num = -$num if $sign == 0x80;  # use sign to indicate 0 periods

                $numtime =
                  $num * $this->{IRSAMPLEPERIOD} + $Slinke::IRSKEWADJUST;
                $numstr .=
                  sprintf( "%.1lf ", $numtime * 1e6 ); # convert to microseconds
                $signallen += abs($numtime);
            }

            $oldsign = $sign;
            $num     = $i;
        }
        else {
            # same signal
            $num += $i;
        }
    }

    # write out the last one
    $num = -$num if !$sign;    # use sign to indicate 0 periods;

    $numtime = $num * $this->{IRSAMPLEPERIOD} + $Slinke::IRSKEWADJUST;
    $numstr .= sprintf( "%.1lf ", $numtime * 1e6 );    # convert to microseconds
    $signallen += abs($numtime);

    return ( $numstr, $signallen );
}

sub rlcToInt8 {
    my $this = shift;
    my $data = shift;

    my $outsum  = 0.0;
    my $truesum = 0;
    my @bin;

    foreach my $i (@$data) {
        my $sign = $i < 0 ? 0 : 0x80;
        $i = abs($i);

        $truesum += $i;

        # convert microseconds into the current IR sampling period of the Slink-e
        $i =
          int( ( $truesum - $outsum ) / $this->{IRSAMPLEPERIOD} / 1e6 + 0.5 );
        $outsum += $i * $this->{IRSAMPLEPERIOD} * 1e6;

        # break into smaller segments if necessary
        while ( $i > 0 ) {
            my $binnum = $i < 127 ? $i : 127;
            $i -= $binnum;
            push @bin, ( $binnum + $sign );
        }
    }

    return @bin;
}

=item C<requestInput>

  $slinke->requestInput();

This function returns any input from the S-Link ports, the IR ports or the Parallel port

The returned element is a hash reference.  

C<PORT> is always set, and it will contain the port that returned the data

C<DATA> is a reference to an array of values.

C<TIME> is set for data coming from the IR port and this lists the total amount
of time that was needed to produce the IR signal

C<IRPORT> is set for data coming from the IR port.  It tells which IR receiver (1-8) the
data was received on.  Note that you must have a Slink-e of version 2.0 or higher for
IRPORT to be greater than 0

=cut

sub requestInput {
    my $this = shift;

    if ( $#{ $this->{RECEIVED} } < 0 ) {
        $this->receive( RETURNONINPUT => 1 );
    }

    return shift @{ $this->{RECEIVED} };
}

=item C<requestSerialNumber>

  $slinke->requestSerialNumber()

Returns the 8 byte serial number of the Slink-e.

=cut

sub requestSerialNumber {
    my $this = shift;

    return ( $this->txrx( COMMAND => "CMD_GETSERIALNO" ) )[2];
}

=item C<requestBaud>

  $slinke->requestBaud()

Returns the baud rate in bps of the Slink-e.

=cut

sub requestBaud {
    my $this = shift;

    $this->resume();
    my $data = ( $this->txrx( COMMAND => "CMD_GETBAUD" ) )[2];

    if ( defined $data ) {
        $data = hex($data);
        $data = 2400 * ( 1 << $data );
        return $data;
    }
    $this->{SERIALPORT}->input;

    for ( my $i = 4; $i >= 0; $i-- ) {
        $this->{SERIALPORT}->baudrate( 2400 * ( 1 << $i ) );

        $this->resume();
        my $data = ( $this->txrx( COMMAND => "CMD_GETBAUD" ) )[2];

        if ( defined $data ) {
            $data = hex($data);
            $data = 2400 * ( 1 << $data );
            return $data;
        }
        else {
            $this->{SERIALPORT}->input;
        }
    }

    return undef;
}

=item C<setBaud>

  $slinke->setBaud()

Sets the baud rate in bps of the Slink-e.

=cut

sub setBaud {
    my $this = shift;
    my $baud = shift;

    my $bn;

    if    ( $baud == 2400 )  { $bn = 0; }
    elsif ( $baud == 4800 )  { $bn = 1; }
    elsif ( $baud == 9600 )  { $bn = 2; }
    elsif ( $baud == 19200 ) { $bn = 3; }
    elsif ( $baud == 38400 ) { $bn = 4; }
    else {
        warn("$baud is an invalid baud rate.\n");
        return undef;
    }

    my $data = (
        $this->txrx(
            COMMAND => "CMD_SETBAUD",
            ARGS    => [$bn],
        )
    )[2];
    $this->{SERIALPORT}->input();

    if ( defined $data ) {
        $data         = hex($data);
        $data         = 2400 * ( 1 << $data );
        $this->{BAUD} = $data;
        $this->{SERIALPORT}->baudrate($data);
        $this->resume;
    }
    return $data;
}

=item C<requestFirmwareVersion>

  $slinke->requestFirmwareVersion()

Returns the firmware version of the Slink-e

=cut

sub requestFirmwareVersion {
    my $this = shift;

    my $data = ( $this->txrx( COMMAND => "CMD_GETVERSION" ) )[2];

    if ( defined $data ) {
        $data = hex($data);
        $data = ( $data >> 4 ) + 0.1 * ( $data & 0xF );
    }
    return $data;
}

=item C<enablePort>

  $slinke->enablePort( $port )

Enables reception on specified port.  If port == C<PORT_SYS> I<all ports are not enabled>,
instead each port is returned to its enabled/disabled state previous to the global
disablement.

=cut

sub enablePort {
    my $this = shift;
    my $port = shift;

    if ( !defined $Slinke::PORTS{$port} ) {
        warn "Unrecognized port: $port\n";
        return undef;
    }

    if ( $port eq "PORT_SER" ) {
        warn "Can't enable port '$port'\n";
        return undef;
    }

    my ( $device, $response ) = $this->txrx(
        COMMAND => "CMD_ENABLE",
        PORT    => $port,
    );

    if ( $device eq $port ) {
        return 1;
    }
    else {
        warn "Error trying to enable $port\n";
        return undef;
    }
}

=item C<disablePort>

  $slinke->disablePort( $port )

Disables reception on specified port.  If port == C<PORT_SYS>, all ports are
disabled.  Disabling a port does not prevent the host from sending messages out
the port, only receiving them.

=cut

sub disablePort {
    my $this = shift;
    my $port = shift;

    if ( !defined $Slinke::PORTS{$port} ) {
        warn "Unrecognized port: $port\n";
        return undef;
    }

    if ( $port eq "PORT_SER" ) {
        warn "Can't disable port '$port'\n";
        return undef;
    }

    my ( $device, $response ) = $this->txrx(
        COMMAND => "CMD_DISABLE",
        PORT    => $port,
    );

    if ( $device eq $port ) {
        return 1;
    }
    else {
        warn "Error trying to disable $port\n";
        return undef;
    }
}

=item C<requestIRSamplingPeriod>

  $slinke->requestIRSamplingPeriod()

This returns the infrared sampling period of the Slink-e.  Values can
range from 50 microseconds to 1 millisecond.

The IR sampling period determines the maximum timing resolution which
can be achieved when decoding IR signals.  In general, the sampling
period should be at least 3 times shorter than the shortest pulse you
wish to detect.  Short sampling periods are necessary when acquiring
timing information about new remote signals, but are not necessarily
need to output known remote signals since the sampling period need only
be the least common multiple of the pulse widths in the signal.

The IR sampling period is also used as a timebase for parallel port
output signals.

=cut

sub requestIRSamplingPeriod {
    my $this = shift;
    my $data = ( $this->txrx( COMMAND => "CMD_GETIRFS" ) )[2];

    if ( defined $data ) {
        my ( $d1, $d2 ) = $data =~ /(..)(..)/;
        $d1   = hex($d1);
        $d2   = hex($d2);
        $data = ( $d1 * 256.0 + $d2 ) / ( $Slinke::SLINKE_CLK / 4.0 );
    }

    return $data;
}

=item C<setIRSamplingPeriod>

  $slinke->setIRSamplingPeriod( $time )

This sets the infrared sampling period of the Slink-e.  Values can
range from 50 microseconds to 1 millisecond in 1/5 microsecond
steps.  Upon success, this function will return the sampling period.
On value, it will return undef.

The IR sampling period determines the maximum timing resolution which
can be achieved when decoding IR signals.  In general, the sampling
period should be at least 3 times shorter than the shortest pulse you
wish to detect.  Short sampling periods are necessary when acquiring
timing information about new remote signals, but are not necessarily
need to output known remote signals since the sampling period need only
be the least common multiple of the pulse widths in the signal.

The IR sampling period is also used as a timebase for parallel port
output signals.

=cut

sub setIRSamplingPeriod {
    my $this       = shift;
    my $sampleRate = shift;

    my $baud = $this->{BAUD};

    my $minper = 1.0 / $baud;
    $minper = 49.0e-6 if 49.0e-6 > $minper;

    if ( $sampleRate < $minper ) {
        $sampleRate *= 1e6;
        $minper     *= 1e6;

        warn
          "$sampleRate is too short of a sampling period ($minper is the shortest at this baud rate)\n";
        return undef;
    }

    my $maxper = 1e-3;
    if ( $sampleRate > $maxper ) {
        $sampleRate *= 1e6;
        $maxper     *= 1e6;
        warn
          "$sampleRate is too long of a sampling period ($maxper is the longest)\n";
        return undef;
    }

    my $count = $Slinke::SLINKE_CLK / 4 * $sampleRate + 0.5;

    my $d1 = $count >> 8;
    my $d2 = $count % 256;

    my $data = (
        $this->txrx(
            COMMAND => "CMD_SETIRFS",
            ARGS    => [ $d1, $d2 ],
        )
    )[2];

    if ( defined $data ) {
        my ( $d1, $d2 ) = $data =~ /(..)(..)/;
        $d1   = hex($d1);
        $d2   = hex($d2);
        $data = ( $d1 * 256.0 + $d2 ) / ( $Slinke::SLINKE_CLK / 4.0 );

        if ( $data != $sampleRate ) {
            warn "Tried setting samplerate of $sampleRate - $data set\n";
            return undef;
        }
        else {
            $this->{IRSAMPLEPERIOD} = $data;
        }
    }
    return $data;
}

=item C<requestIRCarrier>

  $slinke->requestIRCarrier()

This returns the IR carrier frequency of the Slink-e.

=cut

sub requestIRCarrier {
    my $this = shift;
    my $data = ( $this->txrx( COMMAND => "CMD_GETIRCFS" ) )[2];

    if ( defined $data ) {
        my ( $d1, $d2 ) = $data =~ /(..)(..)/;

        $d1 = hex($d1);
        $d2 = hex($d2);

        if ( $d1 == 0 && $d2 == 0 ) {
            $data = 0;
        }
        else {
            $data =
              ( $Slinke::SLINKE_CLK / 4 ) / ( ( 1 << $d1 ) * ( $d2 + 1 ) );
        }
    }

    return $data;
}

=item C<setIRCarrier>

  $slinke->setIRCarrier( $frequency )

This sets the IR carrier frequency of the Slink-e.  Note that because
of the way that the frequency gets set, it will be very unlikely that
you will be able to set the exact frequency that you want.  However,
the Slink-e should be able to handle your frequency within several
hundred hertz.

Upon success, the frequency that the Slink-e is using will be returned.

Upon failure, C<undef> is returned.

=cut

sub setIRCarrier {
    my $this      = shift;
    my $frequency = shift;

    my $d1 = 0;
    my $d2 = 0;

    if ( $frequency != 0.0 ) {
        my $count = $Slinke::SLINKE_CLK / 4.0 / $frequency;
        if ( $count == 0 ) {
            my $max = $Slinke::SLINKE_CLK / 4.0;
            warn
              "$frequency is too high of a carrier frequency ($max is the max)\n";
            return undef;
        }
        elsif ( $count > 8 * 256 ) {
            my $min = $Slinke::SLINKE_CLK / 4.0 / 8.0 / 256.0;
            warn
              "$frequency is too low of a carrier frequency ($min is the minimum)\n";
            return undef;
        }

        if ( $count < 256 ) {
            $d1 = 0;
        }
        else {
            $d1 = POSIX::ceil( log( ( $count >> 8 ) ) / log(2.0) );
        }

        $d2 = int( $count / ( 1 << $d1 ) );
        $d2--;
    }

    my $data = (
        $this->txrx(
            COMMAND => "CMD_SETIRCFS",
            ARGS    => [ $d1, $d2 ],
        )
    )[2];

    if ( defined $data ) {
        my ( $t1, $t2 ) = $data =~ /(..)(..)/;
        $t1 = hex($t1);
        $t2 = hex($t2);

        if ( $t1 == 0 && $t2 == 0 ) {
            $data = 0;
        }
        else {
            $data =
              ( $Slinke::SLINKE_CLK / 4 ) / ( ( 1 << $t1 ) * ( $t2 + 1 ) );
        }

        if ( $d1 != $t1 || $d2 != $t2 ) {
            warn "Tried setting frequency of $frequency - $data set\n";
            return undef;
        }

    }
    return $data;

}

=item C<requestIRTimeoutPeriod>

 $slinke->requestIRTimeoutPeriod()

This returns the IR timeout period of the Slink-e as measured in sample
periods.  The timeout period defines how ling the IR receiver module must
be inactive for the Slink-e to consider a message to be completed.

=cut

sub requestIRTimeoutPeriod {
    my $this = shift;
    my $data = ( $this->txrx( COMMAND => "CMD_GETIRTIMEOUT" ) )[2];

    if ( defined $data ) {
        my ( $d1, $d2 ) = $data =~ /(..)(..)/;

        $d1 = hex($d1);
        $d2 = hex($d2);

        $data = $d1 * 256 + $d2;
    }

    return $data;
}

=item C<setIRTimeoutPeriod>

  $slinke->setIRTimeoutPeriod( $sample_periods )

This returns the IR timeout period of the Slink-e as measured in sample
periods.  The timeout period defines how ling the IR receiver module must
be inactive for the Slink-e to consider a message to be completed.
Most IR remotes repeat commands many times for one keypress.  If you want
to see each command as a separate message, set the timeout period to be
less than the off time between commands.  If you to see the keypress as
one long message with repeated commands, set the timeout period to be
longer than the off time between commands.  The latter mode is particularly
useful for initially determining the timing information for a new remote.

On success, the new value of the timeout period will be returned.

On failure, C<undef> is returned.

=cut

sub setIRTimeoutPeriod {
    my $this   = shift;
    my $period = int(shift);

    if ( $period == 0 ) {
        warn "$period sample periods is too short of a timeout period.\n";
        return undef;
    }

    if ( $period > 65536 ) {
        warn
          "$period sample periods is too long of a timeout period (65536 periods is the longest)\n";
        return undef;
    }

    my $d1 = $period >> 8;
    my $d2 = $period % 256;

    my $data = (
        $this->txrx(
            COMMAND => "CMD_SETIRTIMEOUT",
            ARGS    => [ $d1, $d2 ],
        )
    )[2];

    if ( defined $data ) {
        my ( $d1, $d2 ) = $data =~ /(..)(..)/;

        $d1 = hex($d1);
        $d2 = hex($d2);

        $data = $d1 * 256 + $d2;
        if ( $data != $period ) {
            warn "Tried setting timeout period of $period - $data set\n";
            return undef;
        }
    }

    return $data;
}

=item C<requestIRMinimumLength>

  $slinke->requestIRMinimumLength()

This returns the length of the shortest IR receive message in bytes which
will be considered a valid message.  

=cut

sub requestIRMinimumLength {
    my $this = shift;
    my $data = ( $this->txrx( COMMAND => "CMD_GETIRMINLEN" ) )[2];

    $data = hex($data) if defined $data;

    return $data;
}

=item C<setIRMinimumLength>

  $slinke->setIRMinimumLength( $bytes )

This set the length of the shortest IR receive message in bytes which
will be considered a valid message.  IR receiver modules such as the one
on the Slink-e tend to be very sensitive to both optical and electrical
noise, causing them to occasionally generate false pulses when there is
no actual IR signal.  The false pulses are generally of short duration 
and do not contain the large number of on/off alternations present in a
true IR remote signal.  By setting a minimum message length, false pulses
will be ignored and not reported to the host.  The minimum length can
range from 0 to 15 bytes.

Upon success, the new minimum message length is returned.

Upon failure, C<undef> is returned.

=cut

sub setIRMinimumLength {
    my $this   = shift;
    my $length = shift;

    if ( $length < 0 ) {
        warn
          "$length is too short of a minimum message length (0 is the shortest)\n";
        return undef;
    }

    if ( $length > $Slinke::PORT_IR_MAXML ) {
        warn
          "$length is too long of a minimum message length ($Slinke::PORT_IR_MAXML is the longest)\n";
        return undef;
    }

    my $data = (
        $this->txrx(
            COMMAND => "CMD_SETIRMINLEN",
            ARGS    => [$length],
        )
    )[2];

    $data = hex($data) if defined $data;

    if ( $data != $length ) {
        warn "Tried setting IR minimum message length of $length - $data set\n";
        return undef;
    }

    return $data;
}

=item C<requestIRTransmitPorts>

  $slinke->requestIRTransmitPorts()

This returns the value of the ports that the Slink-e uses for IR transmissions.
The bits represent the 8 IR ports, IR0 being the LSB, IR7 the MSB.  A "1" indicates
the port will be used.

I<This command requires a firmware version of 2.0 and above>

=cut

sub requestIRTransmitPorts {
    my $this = shift;

    if ( $this->{VERSION} < 2.0 ) {
        warn
          "Current Slink-e version is $this->{VERSION} (need 2.0 or greater)\n";
        return undef;
    }

    return hex( ( $this->txrx( COMMAND => "CMD_GETIRTXPORTS" ) )[2] );
}

=item C<setIRTransmitPorts>

  $slinke->setIRTransmitPorts( $ports )

This sets the ports that the Slink-e uses for IR transmissions.  The bits represent 
the 8 IR ports, IR0 being the LSB, IR7 the MSB.  A "1" indicates the port will be used.

I<This command requires a firmware version of 2.0 and above>

=cut

sub setIRTransmitPorts {
    my $this = shift;
    my $port = shift;

    if ( $this->{VERSION} < 2.0 ) {
        warn
          "Current Slink-e version is $this->{VERSION} (need 2.0 or greater)\n";
        return undef;
    }

    if ( $port < 0 || $port > 255 ) {
        warn "$port is not a valid port (0-0xFF is the acceptable range)\n";
        return undef;
    }

    $this->txrx(
        COMMAND => "CMD_SETIRTXPORTS",
        ARGS    => [$port],
    );

}

=item C<requestIRPolarity>

  $slinke->requestIRPolarity()

Reports the polarity sense of each of the IR ports. These settings will also 
affect the IR routing system. The bits of the response represent the 8 IR ports, 
IR0 being the LSB, IR7 the MSB. A "1" bit indicates that the input is active-low
(when the  input goes to 0 Volts), a "0" bit indicates that the input is 
active-high (when the input goes to 5 Volts). All ports are active-low by default 
so that they will work correctly with the IR receiver modules. If you have some 
other low-speed serial device which is active-high (e.g. a Control-S input) that 
you would like to connect, you will want to change the polarity on that port. 
Be careful with this option - if you set the wrong polarity for a port, the 
Slink-e will be locked into a constant receive state and will become unresponsive. 

I<This command requires a firmware version of 2.0 and above>

=cut

sub requestIRPolarity {
    my $this = shift;

    if ( $this->{VERSION} < 2.0 ) {
        warn
          "Current Slink-e version is $this->{VERSION} (need 2.0 or greater)\n";
        return undef;
    }

    return hex( ( $this->txrx( COMMAND => "CMD_GETIRRXPORTPOL" ) )[2] );
}

=item C<setIRPolarity>

  $slinke->setIRPolarity( $ports )

Sets the polarity sense of each of the IR ports. These settings will also affect 
the IR routing system. The bits of $ports represent the 8 IR ports, IR0 being the LSB,
IR7 the MSB. A "1" bit indicates that the input is active-low (when the input goes 
to 0 Volts), a "0" bit indicates that the input is active-high (when the input 
goes to 5 Volts). All ports are active-low by default so that they will work
correctly with the IR receiver modules. If you have some other low-speed serial 
device which is active-high (e.g. a Control-S input) that you would like to connect,
you will want to change the polarity on that port. Be careful with this option - if 
you set the wrong polarity for a port, the Slink-e will be locked into a constant 
receive state and will become unresponsive.

I<This command requires a firmware version of 2.0 and above>

=cut

sub setIRPolarity {
    my $this = shift;
    my $port = shift;

    if ( $this->{VERSION} < 2.0 ) {
        warn
          "Current Slink-e version is $this->{VERSION} (need 2.0 or greater)\n";
        return undef;
    }

    if ( $port < 0 || $port > 255 ) {
        warn "$port is not a valid port (0-0xFF is the acceptable range)\n";
        return undef;
    }

    my $data = hex(
        (
            $this->txrx(
                COMMAND => "CMD_SETIRRXPORTEN",
                ARGS    => [$port],
            )
        )[2]
    );

    if ( $data != $port ) {
        my $p = "0x" . uc( sprintf( "%02x", $port ) );
        my $d = "0x" . uc( sprintf( "%02x", $data ) );
        warn "Tried setting IR receive polarity of $p - $d set\n";
        return undef;
    }

    return $data;
}

=item C<requestIRReceivePorts>

  $slinke->requestIRReceivePorts()

This returns the value of the ports that the Slink-e uses for IR reception.
The bits represent the 8 IR ports, IR0 being the LSB, IR7 the MSB.  A "1" indicates
the port will be used.

I<This command requires a firmware version of 2.0 and above>

=cut

sub requestIRReceivePorts {
    my $this = shift;

    if ( $this->{VERSION} < 2.0 ) {
        warn
          "Current Slink-e version is $this->{VERSION} (need 2.0 or greater)\n";
        return undef;
    }

    return hex( ( $this->txrx( COMMAND => "CMD_GETIRRXPORTEN" ) )[2] );
}

=item C<setIRReceivePorts>

  $slinke->setIRReceivePorts( $ports )

This sets the ports that the Slink-e uses for IR reception.  The bits represent 
the 8 IR ports, IR0 being the LSB, IR7 the MSB.  A "1" indicates the port will be used.

I<This command requires a firmware version of 2.0 and above>

Upon success, this returns the ports that the Slink-e is using for IR reception.

Upon failure, C<undef> is returned.

=cut

sub setIRReceivePorts {
    my $this = shift;
    my $port = shift;

    if ( $this->{VERSION} < 2.0 ) {
        warn
          "Current Slink-e version is $this->{VERSION} (need 2.0 or greater)\n";
        return undef;
    }

    if ( $port < 0 || $port > 255 ) {
        warn "$port is not a valid port (0-0xFF is the acceptable range)\n";
        return undef;
    }

    my $data = hex(
        (
            $this->txrx(
                COMMAND => "CMD_SETIRRXPORTEN",
                ARGS    => [$port],
            )
        )[2]
    );

    if ( $data != $port ) {
        my $p = "0x" . uc( sprintf( "%02x", $port ) );
        my $d = "0x" . uc( sprintf( "%02x", $data ) );
        warn "Tried setting IR receive port of $p - $d set\n";
        return undef;
    }

    return $data;
}

=item C<requestIRRoutingTable>

  $slinke->requestIRRoutingTable()

This response describes the IR routing table. The routelist byte for each 
IRRX port specifies which IRTX ports the received signal will be echoed to. 
The format for this byte is the same as the Set IR transmit ports command.
The carrier byte specifes the carrier frequency to be used in the routed 
signals from a given IRRX port. This byte is equivalent to the CC byte in 
the Set IR carrier command. To reduce data storage requirements, no
prescaler value can be specified and the prescaler is defaulted to 0 
instead. This means that 15.7khz is the lowest available carrier frequency 
for IR routing.

I<This command requires a firmware version of 2.0 and above>

=cut

sub requestIRRoutingTable {
    my $this = shift;

    if ( $this->{VERSION} < 2.0 ) {
        warn
          "Current Slink-e version is $this->{VERSION} (need 2.0 or greater)\n";
        return undef;
    }

    my $data = ( $this->txrx( COMMAND => "CMD_GETIRPORTECHO" ) )[2];

    my @data;

    while ($data) {
        my $i;
        ( $i, $data ) = $data =~ /(..)(.*)/;

        push @data, hex($i);

        ( $i, $data ) = $data =~ /(..)(.*)/;
        push @data, ( $Slinke::SLINKE_CLK / 4 ) / ( hex($i) + 1 );
    }

    return @data;
}

=item C<setIRRoutingTable>

  $slinke->setIRRoutingTable( @data )

This command sets up the IR routing table. The routelist byte for each 
IRRX port specifies which IRTX ports the received signal will be echoed to. 
The format for this byte is the same as the Set IR transmit ports command.
The carrier byte specifes the carrier frequency to be used in the routed 
signals from a given IRRX port. This byte is equivalent to the CC byte 
in the Set IR carrier command. To reduce data storage requirements, no
prescaler value can be specified and the prescaler is defaulted to 0 
instead. This means that 15.7khz is the lowest available carrier frequency 
for IR routing.

I<This command requires a firmware version of 2.0 and above>

=cut

sub setIRRoutingTable {
    my $this = shift;
    my @data = @_;

    if ( $this->{VERSION} < 2.0 ) {
        warn
          "Current Slink-e version is $this->{VERSION} (need 2.0 or greater)\n";
        return undef;
    }

    for ( my $i = 1; $i <= $#data; $i += 2 ) {
        my $freq = $data[$i];

        if ($freq) {
            my $count = int( $Slinke::SLINKE_CLK / 4.0 / $freq );
            if ( !$count ) {
                my $max = $Slinke::SLINKE_CLK / 4.0;
                warn
                  "$freq is too high of a carrier frequency ($max is the max)\n";
                return undef;
            }
            elsif ( $count >= 256 ) {
                my $min = $Slinke::SLINKE_CLK / 4.0 / 256.0;
                warn
                  "$freq is too low of a carrier frequency ($min is the minimum)\n";
                return undef;
            }

            $data[$i] = $count - 1;
        }
        else {
            $data[$i] = 0;    # indicate no carrier
        }
    }

    my $data = (
        $this->txrx(
            COMMAND => "CMD_SETIRPORTECHO",
            ARGS    => [@data]
        )
    )[2];

    my @tmpdata;
    my @newdata;
    while ($data) {
        my $i;
        ( $i, $data ) = $data =~ /(..)(.*)/;

        push @newdata, hex($i);
        push @tmpdata, hex($i);

        ( $i, $data ) = $data =~ /(..)(.*)/;
        push @tmpdata, hex($i);
        push @newdata, ( $Slinke::SLINKE_CLK / 4 ) / ( hex($i) + 1 );
    }

    for ( my $i = 0; $i <= $#data; $i++ ) {
        if ( $data[$i] != $tmpdata[$i] ) {
            warn "Did not get proper return value\n";
            return undef;
        }
    }

    return @newdata;
}

=item C<requestHandshaking>

  $slinke->requestHandshaking()

Reports the input and output handshaking mode for the Parallel Port. 

As a binary number, the output looks as follows: C<[0 0 0 0 0 0 in out]>

Only the bits in and out are used. 

in = 0 : Disable Input Handshaking (default at startup). Disable the use 
of DISTB/DIO7 as a handshaking pin, in turn freeing it for general I/O use. 
When input handshaking is enabled, rising edges on the DISTB input cause 
the Parallel Port data to be sampled and sent to the host in the form of a port
receive message. When disabled, sampling of the Parallel Port only occurs when a  
sample port message is issued.

in = 1 : Enable Input Handshaking  Enables the use of DISTB/DIO7 as a handshaking 
pin, in turn removing it from general I/O use. When input handshaking is enabled, 
rising edges on the DISTB input cause the Parallel Port data to be sampled and 
sent to the host in the form of a port receive message. When disabled, sampling 
of the Parallel Port only occurs when a  sample port message is issued.

out= 0 : Disable Output Handshaking (default at startup). Disable the use of 
DOSTB/DIO6 as a handshaking pin, in turn freeing it for general I/O use. When 
output handshaking is enabled, each data byte sent out the Parallel Port using 
the port send command will be accompanied by a positive DOSTB pulse lasting one 
IR sampling period.

out = 1 : Enable Output Handshaking Enable the use of DOSTB/DIO6 as a handshaking 
pin, in turn removing it from general I/O use. When output handshaking is enabled, 
each data byte sent out the Parallel Port using the port send command will be 
accompanied by a positive DOSTB pulse lasting one IR sampling period.

=cut

sub requestHandshaking {
    my $this = shift;

    return hex( ( $this->txrx( COMMAND => "CMD_GETHSMODE" ) )[2] );
}

=item C<setHandshaking>

  $slinke->setHandshaking( $handshaking )

Sets the input and output handshaking mode for the Parallel Port. 

As a binary number, C<$handshaking> looks as follows: C<[0 0 0 0 0 0 in out]>

Only the bits in and out are used. 

in = 0 : Disable Input Handshaking (default at startup). Disable the use of 
DISTB/DIO7 as a handshaking pin, in turn freeing it for general I/O use. When 
input handshaking is enabled, rising edges on the DISTB input cause the Parallel 
Port data to be sampled and sent to the host in the form of a port receive message. 
When disabled, sampling of the Parallel Port only occurs when a sample port message 
is issued.

in = 1 : Enable Input Handshaking  Enables the use of DISTB/DIO7 as a handshaking 
pin, in turn removing it from general I/O use. When input handshaking is enabled,
rising edges on the DISTB input cause the Parallel Port data to be sampled and sent 
to the host in the form of a port receive message. When disabled, sampling of the 
Parallel Port only occurs when a  sample port message is issued.

out= 0 : Disable Output Handshaking (default at startup). Disable the use of 
DOSTB/DIO6 as a handshaking pin, in turn freeing it for general I/O use. When
output handshaking is enabled, each data byte sent out the Parallel Port using 
the port send command will be accompanied by a positive DOSTB pulse lasting one 
IR sampling period.

out = 1 : Enable Output Handshaking Enable the use of DOSTB/DIO6 as a handshaking 
pin, in turn removing  it from general I/O use. When output handshaking is enabled, 
each data byte sent out the Parallel Port using the port send command will be 
accompanied by a positive DOSTB pulse lasting one IR sampling period.

Upon success, the new handshaking setting is returned

Upon failure, C<undef> is returned.

=cut

sub setHandshaking {
    my $this        = shift;
    my $handshaking = shift;

    if ( $handshaking < 0 || $handshaking > 3 ) {
        warn
          "$handshaking is not a valid port (0-0x03 is the acceptable range)\n";
        return undef;
    }

    my $data = hex(
        (
            $this->txrx(
                COMMAND => "CMD_SETHSMODE",
                ARGS    => [$handshaking],
            )
        )[2]
    );

    if ( $data != $handshaking ) {
        my $p = "0x" . uc( sprintf( "%02x", $handshaking ) );
        my $d = "0x" . uc( sprintf( "%02x", $data ) );
        warn "Tried setting handshaking mode of $p - $d set\n";
        return undef;
    }

    return $data;
}

=item C<requestDirection>

  $slinke->requestDirection()

Reports which parallel port lines are inputs or outputs. The bits d7:d0 in 
the output correspond 1 to 1 with the Parallel Port I/O lines DIO7:DIO0. 
Setting a direction bit to 1 assigns the corresponding DIO line as an
input, while setting it to 0 make it an output. At startup, all DIO 
lines are configured as inputs. The use of handshaking on lines DISTB/DIO7 
and DOSTB/DIO6 overrides the direction configuration for these lines while
enabled.

=cut

sub requestDirection {
    my $this = shift;

    return hex( ( $this->txrx( COMMAND => "CMD_GETDIR" ) )[2] );
}

=item C<setDirection>

  $slinke->setDirection( $direction )

Configures the parallel port lines as inputs or outputs. The bits d7:d0 
in the direction byte correspond 1 to 1 with the Parallel Port I/O lines 
DIO7:DIO0. Setting a direction bit to 1 assigns the corresponding DIO line 
as an input, while setting it to 0 make it an output. At startup, all DIO
lines are configured as inputs. The use of handshaking on lines DISTB/DIO7 
and DOSTB/DIO6 overrides the direction configuration for these lines while
enabled. Slink-e will return a configuration direction equals response to 
verify your command.

=cut

sub setDirection {
    my $this      = shift;
    my $direction = shift;

    if ( $direction < 0 || $direction > 255 ) {
        warn
          "$direction is not a valid direction setting (0-0xFF is the acceptable range)\n";
        return undef;
    }

    my $data = hex(
        (
            $this->txrx(
                COMMAND => "CMD_SETDIR",
                ARGS    => [$direction],
            )
        )[2]
    );

    if ( $data != $direction ) {
        my $p = "0x" . uc( sprintf( "%02x", $direction ) );
        my $d = "0x" . uc( sprintf( "%02x", $data ) );
        warn "Tried setting parallel direction configuration of $p - $d set\n";
        return undef;
    }

    return $data;
}

=item C<sampleParPort>

  $slinke->sampleParPort()

Causes the Slink-e to sample the Parallel Port inputs just as if it had 
seen a rising edge on DISTB when input handshaking is enabled. This command 
works whether input handshaking is enabled or not. The Slink-e will
respond with a port receive message containing the Parallel Port data.

Note that this function does I<not> actually return the parallel port data.
To get that, you must call the C<requestInput> function.

=cut

sub sampleParPort {
    my $this = shift;

    $this->txrx( COMMAND => "CMD_SAMPLE" );
}

=item C<sendIR>

  $slinke->sendIR( DATA => $data [, IRPORT => $ports ] )

This function allows you to send IR signals.  The C<DATA> element should be
an array reference of run length coded signals.  If you wish to send the
IR on specific ports, set the C<IRPORT> element.  

This function will automatically mute the IR Receivers while data is
being sent so that the receiver will not capture what the transmitter
is sending.

=cut

sub sendIR {
    my $this = shift;
    my %args = @_;
    my $oldTX;
    my $oldRX;

    if ( $this->{VERSION} >= 2.0 ) {
        if ( defined $args{IRPORT} ) {
            $oldTX = $this->requestIRTransmitPorts;
            $this->setIRTransmitPorts( $args{IRPORT} );
        }

        $oldRX = $this->requestIRReceivePorts;
        $this->setIRReceivePorts(0x00);
    }

    my @data = $this->rlcToInt8( $args{DATA} );

    for ( my $i = 0; $i <= $#data; $i += $Slinke::MAXDATABLOCK ) {
        my $end =
            $i + $Slinke::MAXDATABLOCK < $#data
          ? $i + $Slinke::MAXDATABLOCK - 1
          : $#data;
        my @dp = @data[ $i .. $end ];

        my $time = 0;
        foreach my $j ( @dp[ 0 .. $#dp - 2 ] ) {
            $time += abs($j);
        }

        my $init = ( $Slinke::PORTS{PORT_IR} << 5 ) + $end - $i + 1;

        my $status = $this->writeToPort( $init, @dp );
        if ( !defined($status) ) {
            warn "Error in sending IR\n";
            return undef;
        }
    }

    my $init   = ( $Slinke::PORTS{PORT_IR} << 5 );
    my $status = $this->writeToPort($init);
    if ( !defined($status) ) {
        warn "Error in sending end of IR\n";
        return undef;
    }

    if ( $this->{VERSION} >= 2.0 ) {
        $this->setIRReceivePorts($oldRX);
        $this->setIRTransmitPorts($oldTX) if defined $args{IRPORT};
    }
}

=item C<sendData>

  $slinke->sendData( DATA => $data, PORT => $port )

This allows data to be sent over a S-Link port or the parallel port.
The C<PORT> element must be set to either C<PORT_SL0>, C<PORT_SL1>,
C<PORT_SL2> or C<PORT_PAR>.  The data element should be an array
reference of the data to be sent.

=cut

sub sendData {
    my $this = shift;
    my %args = @_;

    if ( !defined( $args{PORT} ) ) {
        warn "Must set PORT argument\n";
        return undef;
    }

    if (   $args{PORT} ne "PORT_SL0"
        && $args{PORT} ne "PORT_SL1"
        && $args{PORT} ne "PORT_SL2"
        && $args{PORT} ne "PORT_SL3"
        && $args{PORT} ne "PORT_PAR" )
    {
        warn
          "PORT must be one of either: PORT_SL0, PORT_SL1, PORT_SL2, PORT_SL3 or PORT_PAR\n";
        return undef;
    }

    my @data = @{ $args{DATA} };

    for ( my $i = 0; $i <= $#data; $i += $Slinke::MAXDATABLOCK ) {
        my $end =
            $i + $Slinke::MAXDATABLOCK < $#data
          ? $i + $Slinke::MAXDATABLOCK - 1
          : $#data;
        my @dp = @data[ $i .. $end ];

        my $init = ( $Slinke::PORTS{ $args{PORT} } << 5 ) + $end - $i + 1;

        my $status = $this->writeToPort( $init, @dp );
        if ( !defined($status) ) {
            warn "Error in sending data\n";
            return undef;
        }
    }

    my $init   = ( $Slinke::PORTS{ $args{PORT} } << 5 );
    my $status = $this->writeToPort($init);

    if ( !defined($status) ) {
        warn "Error in sending end of data\n";
        return undef;
    }

}

sub txrx {
    my $this = shift;
    my %args = @_;

    my $command = $args{COMMAND};
    my $port    = $args{PORT};
    if ( !defined $port ) {
        if ( !exists $Slinke::COMMANDMAPS{$command} ) {
            warn "Unknown command: $command\n";
            return undef;
        }
        $port = $Slinke::COMMANDMAPS{$command}->[0];
    }

    my $init = ( $Slinke::PORTS{$port} << 5 ) + $Slinke::COMMANDS{CMD_PORT_SM};
    my $cmd  = $Slinke::COMMANDS{$command};

    my $expectedResponse = $Slinke::COMMANDMAPS{$command}->[1];

    my $status = $this->writeToPort( $init, $cmd, @{ $args{ARGS} } );
    if ( !defined($status) ) {
        return undef;
    }

    if ( defined $expectedResponse ) {
        my ( $device, $response, $data ) = $this->receive(
            EXPECTINPUT => ( $expectedResponse eq "RSP_EQBAUD" ? 0 : 1 ) );

        if ( $expectedResponse ne $response ) {
            my $str;
            $str .= $device  if $device;
            $str .= " $data" if $data;
            warn "Expected '$expectedResponse' - Received '$response' ($str)\n";
            return undef;
        }

        return ( $device, $response, $data );
    }
    else {
        return $status;
    }

}

sub resume {
    my $this = shift;

    # sending a single EOM character which won't hurt anything
    # and will insure word alignment
    $this->writeToPort(0x00);
    $this->txrx( COMMAND => "CMD_RESUME" );
}

=item C<reset>

  $slinke->reset()

Warm-boots the Slink-e, resetting all defaults including the baud 
rate. In version 2.0 or greater, these defaults are loaded from 
an EEPROM which is user programmable.

=cut

sub reset {
    my $this = shift;

    $this->txrx( COMMAND => "CMD_RESET" );
    $this->loadInternals;
}

=item C<loadDefaults>

  $slinke->loadDefaults()

Causes the Slink-e to load all of the current user settings from EEPROM 
memory so that they are returned to their default values, Be wary of the 
fact that the baud rate stored in EEPROM could be different than the
current baud rate. In this case communications will be lost until the 
host detects the new baud rate. If successful, the Slink-e will send a 
defaults loaded response. 

I<This command requires a firmware version of 2.0 and above>

=cut

sub loadDefaults {
    my $this = shift;

    if ( $this->{VERSION} < 2.0 ) {
        warn
          "Current Slink-e version is $this->{VERSION} (need 2.0 or greater)\n";
        return undef;
    }

    $this->txrx( COMMAND => "CMD_LOADDEFAULTS" );
    $this->loadInternals;
}

=item C<saveDefaults>

  $slinke->saveDefaults()

Causes the Slink-e to save all of the current user settings to EEPROM
memory so that they will become the defaults the next time the Slink-e 
is reset or powered-up. If successful, the Slink-e will send a defaults 
saved response. 

I<This command requires a firmware version of 2.0 and above>

=cut

sub saveDefaults {
    my $this = shift;

    if ( $this->{VERSION} < 2.0 ) {
        warn
          "Current Slink-e version is $this->{VERSION} (need 2.0 or greater)\n";
        return undef;
    }

    $this->txrx( COMMAND => "CMD_SAVEDEFAULTS" );
}

=item C<decodeIR>

  decodeIR( @data )

This will take the data returned by requestInput and attempt to convert it
to a bit string.  This function returns a hash reference.

Elements of the hash reference

   HEAD => The wakeup call for the device.  These are typically the first two
           bytes in the data array.  This is an array reference.

   CODE => This is a bit string indicating the command that was sent.
           For Sony devices, a "P" is thrown in when a pause in the data array
           is detected.

   TAIL => The bytes that indicate the end of the data string.  These are 
           typically the last five bytes of the data array.  This is an array
           reference.

   ENCODING => This is an array reference of two array references that describes
           how zeroes and ones are encoded.

=cut

my %lastSignal;

sub decodeIR {
    my @data   = @_;
    my $CUTOFF = 6000;

    if ( $#data < 6 ) {
        return \%lastSignal;
    }
    return undef unless $#data > 6;

    my @head = @data[ 0 .. 1 ];
    @data = @data[ 2 .. $#data ];

    my @d = @data;
    my @d1;
    my @d2;
    my $d1avg;
    my $d2avg;

    while ( $#d >= 0 ) {
        my $t1 = shift @d;
        last if !defined $t1;
        last if abs($t1) > $CUTOFF;

        my $t2 = shift @d;
        last if !defined $t2;
        last if abs($t2) > $CUTOFF;

        push @d1, $t1;
        $d1avg += $t1;

        push @d2, $t2;
        $d2avg += $t2;
    }

    @d1 = sort @d1;
    @d2 = sort @d2;

    my $d1med = $d1[ int( $#d1 / 2 + 0.5 ) ];
    $d1avg = $d1avg / ( $#d1 + 1 );

    my $d2med = $d2[ int( $#d2 / 2 + 0.5 ) ];
    $d2avg = $d2avg / ( $#d2 + 1 );

    $d1avg = .0001 if !$d1avg;
    my $d1dif = 0;
    my $d2dif = 0;
    if ( abs( ( $d1med - $d1avg ) / $d1avg ) > .15 ) {
        $d1dif = 1;
    }
    $d2avg = .0001 if !$d2avg;
    if ( abs( ( $d2med - $d2avg ) / $d2avg ) > .15 ) {
        $d2dif = 1;
    }

    @d = @data;

    my $avg = $d1avg + $d2avg;
    my $str;

    my @const;
    my @var0;
    my @var1;
    my $constSum;
    my $var0Sum;
    my $var1Sum;
    my @pause;
    my $pauseSum;

    while ( $#d >= 0 ) {
        my $pauseFlag = 0;
        my $t1        = shift @d;
        if ( !defined $t1 ) {
            last;
        }
        if ( abs($t1) > $CUTOFF ) {
            if ( $#d > 6 ) {
                $pauseFlag = 1;
                push @pause, $t1;
                $pauseSum += $t1;
            }
            else {
                unshift @d, $t1;
                last;
            }
        }

        my $t2 = shift @d;
        if ( !defined $t2 ) {
            unshift @d, $t1;
            last;
        }
        if ( abs($t2) > $CUTOFF ) {
            if ( $#d > 6 ) {
                $pauseFlag = 1;
                push @pause, $t2;
                $pauseSum += $t2;
            }
            else {
                unshift @d, $t2;
                unshift @d, $t1;
                last;
            }
        }

        if ($d1dif) {
            if ( abs($t2) < $CUTOFF ) {
                push @const, $t2;
                $constSum += $t2;
            }
            if ( $t1 > $d1avg ) {
                if ( abs($t1) < $CUTOFF ) {
                    push @var1, $t1;
                    $var1Sum += $t1;
                }
                $str .= ( $pauseFlag ? "P" : 1 );
            }
            else {
                if ( abs($t1) < $CUTOFF ) {
                    push @var0, $t1;
                    $var0Sum += $t1;
                }
                $str .= ( $pauseFlag ? "p" : 0 );
            }
        }
        else {
            if ( abs($t1) < $CUTOFF ) {
                push @const, $t1;
                $constSum += $t1;
            }

            if ( $t2 < $d2avg ) {
                if ( abs($t2) < $CUTOFF ) {
                    push @var1, $t2;
                    $var1Sum += $t2;
                }
                $str .= ( $pauseFlag ? "P" : 1 );
            }
            else {
                if ( abs($t2) < $CUTOFF ) {
                    push @var0, $t2;
                    $var0Sum += $t2;
                }
                $str .= ( $pauseFlag ? "p" : 0 );
            }
        }

        if ($pauseFlag) {

            # remove the head again
            shift @d;
            shift @d;
        }
    }

    my @zeroSeq;
    my @oneSeq;

    if ($d1dif) {
        push @zeroSeq, $var0Sum /  ( $#var0 + 1 );
        push @zeroSeq, $constSum / ( $#const + 1 );
        push @oneSeq,  $var1Sum /  ( $#var1 + 1 );
        push @oneSeq,  $constSum / ( $#const + 1 );
    }
    else {
        push @zeroSeq, $constSum / ( $#const + 1 );
        push @zeroSeq, $var0Sum /  ( $#var0 + 1 );
        push @oneSeq,  $constSum / ( $#const + 1 );
        push @oneSeq,  $var1Sum /  ( $#var1 + 1 );
    }

    $str =~ s/[pP]*$//g;

    if ( $str =~ /[pP]/ ) {
        $lastSignal{PAUSETIME} = $pauseSum / ( $#pause + 1 );
        my $repeat = 0;
        while ( $str =~ /[pP]/g ) { $repeat++ }
        $lastSignal{REPEAT} = $repeat;

        if ( $oneSeq[1] == $zeroSeq[1] ) {
            $lastSignal{PAUSETIME} -= $oneSeq[1];
            $str =~ s/p/0p/g;
            $str =~ s/P/1P/g;
        }

        $str =~ s/[pP].*//g;
    }

    $lastSignal{HEAD}     = \@head;
    $lastSignal{TAIL}     = \@d;
    $lastSignal{CODE}     = $str;
    $lastSignal{ENCODING} = [ \@zeroSeq, \@oneSeq ];

    return \%lastSignal;
}

sub PORT_SLO { return "PORT_SLO"; }
sub PORT_SL1 { return "PORT_SL1"; }
sub PORT_SL2 { return "PORT_SL2"; }
sub PORT_SL3 { return "PORT_SL3"; }
sub PORT_IR  { return "PORT_IR"; }
sub PORT_PAR { return "PORT_PAR"; }
sub PORT_SER { return "PORT_SER"; }
sub PORT_SYS { return "PORT_SYS"; }

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Brian Paulsen <Brian@ThePaulsens.com>

=head2 SEE ALSO

For further information about the Slink-e, visit http://www.nirvis.com

=head2 LICENSE

Copyright 2000, Brian Paulsen.  All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

