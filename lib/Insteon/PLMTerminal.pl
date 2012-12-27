#!/usr/bin/perl -w

# Use this as a stand-alone (outside of mh) way to
# test an Insteon PLM (2412/2413)
# Example:
#   perl insteon_test.pl /dev/ttyS1
#   perl insteon_test.pl COM1
#
# script will loop showing all received PLM messages
# User input is collected until user presses return
#  then string of hex is sent to PLM
#

$| = 1;

use strict;
use lib '..', '../site';
use Insteon::MessageDecoder;
use Term::ReadKey;
use constant {
	RX_BLOCKTIME => 100, #block for 100ms
	RX_TIMEOUT => 20,    #100ms * 20 = 2 seconds
};
my ($device, $port);

$port = shift;
if ($^O eq "MSWin32") {
	print "Windows; opening Win32 serial port\n";
	require Win32::SerialPort;
	die "$@\n" if ($@);
	$port = 'COM1' unless $port;
	$device = Win32::SerialPort->new ($port) or die "Can't start $port\n";
#	&Win32::SerialPort::debug(1);
}
else {
	print "Not Windows; opening linux serial port\n";
	require Device::SerialPort;
	die "$@\n" if ($@);
	$port = '/dev/ttyS0' unless $port;
	$device = Device::SerialPort->new ($port) or die "Can't start $port\n";
#	Device::SerialPort::debug(1);
}
print "Using port=$port\n";

$device->error_msg(1);	# use built-in error messages
$device->user_msg(0);
$device->databits(8);
$device->baudrate(19200);
$device->parity("none");
$device->stopbits(1);
$device->dtr_active(1);
$device->handshake("none");
$device->read_char_time(0);    # don't wait for each character
$device->read_const_time(RX_BLOCKTIME); # wait RX_BLOCKTIME (ms) per unfulfilled "read" call
$device->write_settings || die "Could not set up port\n";
print "Done setting port parameters\n";

our $ctlc = 0;
$SIG{INT} = \&handler_ctlc;
sub handler_ctlc {
	$SIG{INT} = \&handler_ctlc;
	$ctlc++;
}

print( "Ready to send command.  Looking for messages.\n\n");
my $RxMessage='';
my $RxTimeout=RX_TIMEOUT;
my $TxMessage='';
while(!$ctlc) {
	#Read data from serial port
	#Blocks for RX_BLOCKTIME (ms); set above
	my ($count, $buffer) = $device->read(25);
	for( my $i = 0; $i < $count; $i++) {
		$RxMessage .= substr($buffer,$i,1);
#		print("RXMessage=>".unpack( 'H*', $RxMessage)."\n");
		#Check to see if an entire message was received
		if( plmValidMessage($RxMessage)) {
			print "PLM=>".unpack( 'H*', $RxMessage)."\n";
			print Insteon::MessageDecoder::plm_decode(unpack( 'H*', $RxMessage))."\n";
			$RxMessage = '';
			$RxTimeout=RX_TIMEOUT;
		}
	}

	#Once message reception starts check for receive timeout.  
	#Will only occur if there is message corruption or if the 
	#PLM sends a message type that is not in the messageLength hash below.
	$RxTimeout-- if($RxMessage ne '');
	if( $RxTimeout == 0) {
		print("RX Timeout; command not parsed\n");
		print("Dumping:  ".unpack('H*',$RxMessage)."\n");
		print Insteon::MessageDecoder::plm_decode(unpack( 'H*', $RxMessage))."\n";

		$RxMessage = '';
		$RxTimeout=RX_TIMEOUT;
	}

	#collect keypresses from user
	#Ignore zero length messages (i.e. user just hits enter)
	my $key;
	while( defined ($key = ReadKey(-1))) {
		if( $key eq "\n" and $TxMessage ne '') { # enter
			$TxMessage = insertChecksum($TxMessage);
			print "PLM<=".$TxMessage."\n";
			print Insteon::MessageDecoder::plm_decode($TxMessage)."\n";
			$device->write( pack( 'H*', $TxMessage));
			$TxMessage = '';
		} else {
			$TxMessage .= $key if($key ne "\n");
		}
	}
} #while(!$ctlc)

print "Closing device port\n";
$device->close || die "\nclose problem with $port\n";

sub plmValidMessage {
	my ($message) = @_;
	
	#Need at least 2 bytes to get started
	return 0 if(length($message)<2);
	
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
	'62' => 23, # could get 9 or 23 (Standard or Extended Message received)
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
	my $validLength = $messageLength{unpack('H*',substr($message,1,1))};

	#override for '62' and standard message flag
	if( ord(substr($message,1,1)) == 0x62) {
		#need 6 bytes to check insteon message type (standard/extended)
		return 0 if(length($message)<6);
		#Use message flags to determine
		$validLength = 9 if( !(ord(substr($message,5,1))&0b00010000));
	}

	#Will return false always if PLM message code is not in hash above
	#Eventually the RX_TIMEOUT should declare end of message unless
	#the bus is very busy.  Multiple messages could get concatinated.
#	print("\$validLength=$validLength; length(\$message)=".length($message)."\n");
	return -1 if( defined($validLength) and length($message) == $validLength);
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
	return $message if( substr($message,2,2) ne '62' or !(hex(substr($message,10,1))&0b0001));
	#Mask off D14 incase one was already set
	$message = substr($message,0,42)."00";
#	print "      Checksumming=>$message\n";
	#sum starting with cmd1
#	print "but just this part=>".substr($message,12)."\n";
	my $sum = 0;
	$sum += hex($_) for (unpack('(A2)*', substr($message,12)));
#	print sprintf("          Checksum=>%x", $sum) . "\n";
	$sum = (~$sum + 1) & 0xff;
#	print sprintf("     2s compliment=>%x", $sum) . "\n";
	$message = substr($message,0,42).unpack( 'H2', chr($sum));
#	print "       New message=>$message\n";
#	my $check_the_checksum;
#	$check_the_checksum += hex($_) for (unpack('(A2)*', substr($message,12)));
#	$check_the_checksum &= 0xff;
#	print "      check result=>$check_the_checksum\n";
	return $message
}
