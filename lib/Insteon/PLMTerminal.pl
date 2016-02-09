#!/usr/bin/perl -w

=head1 NAME

B<PLMTerminal.pl> - A standalone way to test an Insteon PLM (2412/2413) 

=head1 SYNOPSIS

PLMTerminal.pl [OPTIONS] serialport

 serialport
   May be windows or linux serial port device
   (e.g. COM1, /dev/ttyS0, /dev/ttyUSB0, etc)

 Options:
   -nochecksum, -c               Disable i2CS checksums
   -h, -?, --help                Brief help message
   --man                         Full documentation

=head1 DESCRIPTION

PLMTerminal.pl is a simple serial terminal application designed to 
interact with an Insteon PLM.  This tool is handy for studying how 
the PLM interacts with the Insteon network.  It will display all 
PLM messages received on the serial port and decode those messages 
using the Insteon::MessageDecoder module.  The tool will also 
collect any key presses in the [0-9a-fA-F] range and interpret 
those key presses as a hex string sent to the PLM after the user 
presses enter.  The string will be decoded before being sent to 
the PLM.

If the user types an extended Insteon message (PLM command 0x62), a 
checksum will be automatically added to the D14 byte for compliance 
with i2CS devices. This can be disabled with the --nochecksum option.

Pressing Ctl-C will exit the program.

=head1 EXAMPLE

    perl insteon_test.pl /dev/ttyS1
    
    perl insteon_test.pl COM1
    
=head1 EXAMPLE PLM COMMANDS

To get started try typing some of these PLM commands.  The first 
example 0x60 is a great command to verify that the PLM is working. 
If you do not get a response then you may be using the wrong serial 
port device or the PLM may not be working.  In the examples replace 
xxyyzz with the device ID from the device label.
    
    0260 - Get PLM Info
    0262xxyyzz0f0d00 - Get Insteon Engine Version of device with zzyyzz id
    0262xxyyzz1f2e000100000000000000000000000000 - Get config request

=head1 BUGS

There are probably many bugs.  The script was written and tested 
with a 2413U PLM v1.7(9b) under Debian Woody linux (perl 5.10) and 
under Windows ActiveState Perl (perl 5.12).  It "should" work with 
other PLMs but the decoder may not decode some messages correctly.  
For help undestanding the decoded PLM messages see the 
Insteon::MessageDecoder documentation. 

=head1 OPTIONS AND ARGUMENTS

=over 8

=item B<-nochecksum, -c>

Will not overwrite D14 with the user data checksum on extended messages. 
Use this option if you are sending extended messages to non-i2CS devices 
and the extended command needs the D14 byte.  This should not be necessary.

=item B<-h, -?, --help>

Prints a brief help message and exits.

=item B<--man>

Prints the everything you ever wanted to know about the script and exits.

=back

=head1 SEE ALSO

L<http://www.insteon.net/pdf/INSTEON_Command_Tables_20070925a.pdf>

PLM command details can be found in the 2412S Developers Guide.  This 
document is not supplied by SmartHome but may be available through an 
internet search.

=cut

use strict;
use lib '..', '../site';
use Insteon::MessageDecoder;
use Term::ReadKey;
use Getopt::Long;
use Pod::Usage;

use constant {
    RX_BLOCKTIME => 100,    #block for 100ms
    RX_TIMEOUT   => 20,     #100ms * 20 = 2 seconds
};

our $parms = getParameters();

my $device;
my $port;
$port = $parms->{'port'};
if ( $^O eq "MSWin32" ) {
    print "Windows; opening Win32 serial port\n";
    require Win32::SerialPort;
    die "$@\n" if ($@);
    $port = 'COM1' unless $port;
    $device = Win32::SerialPort->new($port) or die "Can't start $port\n";
}
else {
    print "Not Windows; opening linux serial port\n";
    require Device::SerialPort;
    die "$@\n" if ($@);
    $port = '/dev/ttyS0' unless $port;
    $device = Device::SerialPort->new($port) or die "Can't start $port\n";
}
print "Using port=$port\n";

$device->error_msg(1);    # use built-in error messages
$device->user_msg(0);
$device->databits(8);
$device->baudrate(19200);
$device->parity("none");
$device->stopbits(1);
$device->dtr_active(1) or warn "Could not set dtr_active(1)";
$device->handshake("none");
$device->read_char_time(0);    # don't wait for each character
$device->read_const_time(RX_BLOCKTIME)
  ;    # wait RX_BLOCKTIME (ms) per unfulfilled "read" call
$device->write_settings || die "Could not set up port\n";
print "Done setting port parameters\n";

our $ctlc = 0;
$SIG{INT} = \&handler_ctlc;

sub handler_ctlc {
    $SIG{INT} = \&handler_ctlc;
    $ctlc++;
}

print("Ready to send command.  Looking for messages. Use Ctl-C to quit.\n\n");
my $RxMessage = '';
my $RxTimeout = RX_TIMEOUT;
my $TxMessage = '';
ReadMode(3);    #set a consistent readmode for both linux and windows
$| = 1;
while ( !$ctlc ) {

    #Read data from serial port
    #Blocks for RX_BLOCKTIME (ms); set above
    my ( $count, $buffer ) = $device->read(25);
    for ( my $i = 0; $i < $count; $i++ ) {
        $RxMessage .= substr( $buffer, $i, 1 );

        #		print("RXMessage=>".unpack( 'H*', $RxMessage)."\n");
        #Check to see if an entire message was received
        if ( plmValidMessage($RxMessage) ) {
            print "PLM=>" . unpack( 'H*', $RxMessage ) . "\n";
            print Insteon::MessageDecoder::plm_decode(
                unpack( 'H*', $RxMessage ) )
              . "\n";
            $RxMessage = '';
            $RxTimeout = RX_TIMEOUT;
        }
    }

    #Once message reception starts check for receive timeout.
    #Will only occur if there is message corruption or if the
    #PLM sends a message type that is not in the messageLength hash below.
    $RxTimeout-- if ( $RxMessage ne '' );
    if ( $RxTimeout == 0 ) {
        print("RX Timeout; command not parsed\n");
        print( "Dumping:  " . unpack( 'H*', $RxMessage ) . "\n" );
        print Insteon::MessageDecoder::plm_decode( unpack( 'H*', $RxMessage ) )
          . "\n";

        $RxMessage = '';
        $RxTimeout = RX_TIMEOUT;
    }

    #collect keypresses from user
    #Ignore zero length messages (i.e. user just hits enter)
    #  but print a new line for visual separation
    my $key;
    while ( defined( $key = ReadKey(-1) ) ) {
        if ( ( $key eq "\n" or $key eq "\r" ) and $TxMessage ne '' ) {   # enter
            $TxMessage = insertChecksum($TxMessage)
              if ( !$parms->{'nochecksum'} );
            print "\nPLM<=" . $TxMessage . "\n";
            print Insteon::MessageDecoder::plm_decode($TxMessage) . "\n";
            $device->write( pack( 'H*', $TxMessage ) );
            $TxMessage = '';
        }
        elsif ( ( $key =~ /[0-9a-fA-F]/ ) ) {
            $TxMessage .= $key;
            print $key;
        }
        elsif ( $key eq "\n" or $key eq "\r" ) {
            print "\n";
        }
        else {    #else just drop the key
        }
    }
}    #while(!$ctlc)

print "Closing device port\n";
$device->close || die "\nclose problem with $port\n";
ReadMode(0);

sub plmValidMessage {
    my ($message) = @_;

    #Need at least 2 bytes to get started
    return 0 if ( length($message) < 2 );

    my %messageLength = (
        '50' => 11,
        '51' => 25,
        '52' => 4,
        '53' => 10,
        '54' => 3,
        '55' => 2,
        '56' => 13,
        '57' => 10,
        '58' => 3,
        '60' => 9,
        '61' => 6,
        '62' => 23,  # could get 9 or 23 (Standard or Extended Message received)
        '63' => 5,
        '64' => 5,
        '65' => 3,
        '66' => 6,
        '67' => 3,
        '68' => 4,
        '69' => 3,
        '6A' => 3,
        '6B' => 4,
        '6C' => 3,
        '6D' => 3,
        '6E' => 3,
        '6F' => 12,
        '70' => 4,
        '71' => 5,
        '72' => 3,
        '73' => 6,
    );

    #look up hex code of message in %messageLength
    #	print("Looking up command=>".unpack('H*',substr($message,1,1))."\n");
    my $validLength =
      $messageLength{ unpack( 'H*', substr( $message, 1, 1 ) ) };

    #override for '62' and standard message flag
    if ( ord( substr( $message, 1, 1 ) ) == 0x62 ) {

        #need 6 bytes to check insteon message type (standard/extended)
        return 0 if ( length($message) < 6 );

        #Use message flags to determine
        $validLength = 9
          if ( !( ord( substr( $message, 5, 1 ) ) & 0b00010000 ) );
    }

    #Will return false always if PLM message code is not in hash above
    #Eventually the RX_TIMEOUT should declare end of message unless
    #the bus is very busy.  Multiple messages could get concatinated.
    #	print("\$validLength=$validLength; length(\$message)=".length($message)."\n");
    return -1 if ( defined($validLength) and length($message) == $validLength );
    return 0;
}

sub insertChecksum {
    my ($message) = @_;

    #Only processes a PLM 0x62 Insteon send
    # i.e. 0262 toaddr flags cmd1 cmd2 d1 ... d14
    #Must be a string of hex nibbles
    #                 1111111111222222222233333333334444
    #       01234567890123456789012345678901234567890123
    # i.e. '02622042d31f2e000107110000000000000000000000'
    #Verify it is 0x62 extended message (leave others alone)
    return $message
      if ( substr( $message, 2, 2 ) ne '62'
        or !( hex( substr( $message, 10, 1 ) ) & 0b0001 ) );

    #Mask off D14 incase one was already set
    $message = substr( $message, 0, 42 ) . "00";
    my $sum = 0;
    $sum += hex($_) for ( unpack( '(A2)*', substr( $message, 12 ) ) );
    $sum = ( ~$sum + 1 ) & 0xff;
    $message = substr( $message, 0, 42 ) . unpack( 'H2', chr($sum) );
    return $message;
}

sub getParameters {

    my $parms = {};

    my $nochecksum = 0;

    #	my $port = "";
    my $help = 0;
    my $man  = 0;

    GetOptions(
        "nochecksum|c" => \$nochecksum,

        #		"port|p:s"         => \$port,
        #		"verbose:i"        => \$VERBOSE,
        #		"version|v"        => sub {die( "\n$0:  Version:  $VERSION\n");},
        "help|h|?" => \$help,
        "man"      => \$man,
    );

    pod2usage( -verbose => 1 ) if ($help);
    pod2usage( -verbose => 2 ) if ($man);

    if ( !defined( $ARGV[0] ) ) {
        print("Serial port must be specified (e.g. COM1 or /dev/ttyS0)\n\n");
        pod2usage( -verbose => 1 );
    }

    #Build the hash of command line parameters
    $parms->{'nochecksum'} = $nochecksum;

    #	$parms->{'port'} = $port;
    $parms->{'port'} = $ARGV[0];

    return $parms;
}

=head1 AUTHOR

Michael Stovenour

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Michael Stovenour

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, 
MA  02110-1301, USA.

=cut
