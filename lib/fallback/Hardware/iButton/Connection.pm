# $Date$
# $Revision$

package Hardware::iButton::Connection;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Hardware::iButton::Device;

require Exporter;
#require AutoLoader;

my $OS_win = ($^O eq "MSWin32") ? 1 : 0;
#use POSIX qw(:termios_h); 

if ($OS_win) {
    require Win32::SerialPort;
}
else {
    require Device::SerialPort;
}

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();

( $VERSION ) = '$Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Hardware::iButton - talk to DalSemi iButtons via a DS2480 serial widget

=head1 SYNOPSIS

  use Hardware::iButton::Connection;
  $c = new Hardware::iButton::Connection "/dev/ttyS0";
  @b = $c->scan();
  foreach $b (@b) {
      print "family: ",$b->family(), "serial number: ", $b->serial(),"\n";
      print "id: ",$b->id(),"\n"; # id = family . serial . crc
      print "reg0: ",$b->readreg(0),"\n";
  }

=head1 DESCRIPTION

This module talks to iButtons via the "active" serial interface (anything
using the DS2480, including the DS1411k and the DS 9097U). It builds up a list
of devices available, lets you read and write their registers, etc.

The connection object is an Hardware::iButton::Connection. The main
user-visible purpose of it is to provide a list of Hardware::iButton::Device
objects. These can be subclassed once their family codes are known to provide
specialized methods unique to the capabilities of that device. Those devices
will then be Hardware::iButton::Device::DS1920, etc.

iButtons and solder-mount Touch Memory devices are each identified with a
unique 64-bit number. This is broken up into 8 bits of a "family code", which
specifies the part number (and consequently the capabilities), then 48 bits
of device ID (which Dallas insures is globally unique), then 8 bits of CRC.
When you pass these IDs to and from this package, use hex strings like
"0123456789ab".

=head1 AUTHOR

Brian Warner, warner@lothar.com

=head1 SEE ALSO

http://www.ibutton.com, http://sof.mit.edu/ibuttonpunks/

=cut
# "Network Layer" constants
use constant READ_ROM => "\x33";
use constant SKIP_ROM => "\xcc";
use constant MATCH_ROM => "\x55";
use constant SEARCH_ROM => "\xF0";
use constant OD_SKIP_ROM => "\x3c";
use constant OD_MATCH_ROM => "\x69";
# "Transport Layer" constants
use constant READ_MEMORY => "\xf0";
use constant EXT_READ_MEMORY => "\xa5";
use constant READ_SUBKEY => "\x66";
use constant WRITE_SCRATCHPAD => "\x0f";
use constant READ_SCRATCHPAD => "\xaa";
use constant COPY_SCRATCHPAD => "\x55";
# etc..

# there are constants used by the DS2480 too.
use constant SET_DATA_MODE => "\xe1";
use constant SET_COMMAND_MODE => "\xe3";
use constant SEARCH_ACCEL_ON => "\xb1";
use constant SEARCH_ACCEL_OFF => "\xa1";

use constant DEBUG => 0;

# Mode Commands
use constant MODE_DATA                      => "\xE1";
use constant MODE_COMMAND                   => "\xE3";
use constant MODE_STOP_PULSE                => "\xF1";

# Return byte value 
use constant RB_CHIPID_MASK                 => "\x1C";
use constant RB_RESET_MASK                  => "\x03";
use constant RB_1WIRESHORT                  => "\x00";
use constant RB_PRESENCE                    => "\x01";
use constant RB_ALARMPRESENCE               => "\x02"; 
use constant RB_NOPRESENCE                  => "\x03";

use constant RB_BIT_MASK                    => "\x03";
use constant RB_BIT_ONE                     => "\x03";
use constant RB_BIT_ZERO                    => "\x00";

# Masks for all bit ranges 
use constant CMD_MASK                       => "\x80";
use constant FUNCTSEL_MASK                  => "\x60";
use constant BITPOL_MASK                    => "\x10";
use constant SPEEDSEL_MASK                  => "\x0C";
use constant MODSEL_MASK                    => "\x02";
use constant PARMSEL_MASK                   => "\x70";
use constant PARMSET_MASK                   => "\x0E";

# Command or config bit 
use constant CMD_COMM                       => "\x81";
use constant CMD_CONFIG                     => "\x01";

# Function select bits 
use constant FUNCTSEL_BIT                   => "\x00";
use constant FUNCTSEL_SEARCHON              => "\x30";
use constant FUNCTSEL_SEARCHOFF             => "\x20";
use constant FUNCTSEL_RESET                 => "\x40";
use constant FUNCTSEL_CHMOD                 => "\x60";

# Bit polarity/Pulse voltage bits 
use constant BITPOL_ONE                     => "\x10";
use constant BITPOL_ZERO                    => "\x00";
use constant BITPOL_5V                      => "\x00";
use constant BITPOL_12V                     => "\x10";

# One Wire speed bits 
use constant SPEEDSEL_STD                   => "\x00";
use constant SPEEDSEL_FLEX                  => "\x04";
use constant SPEEDSEL_OD                    => "\x08";
use constant SPEEDSEL_PULSE                 => "\x0C";

# Data/Command mode select bits 
use constant MODSEL_DATA                    => "\x00";
use constant MODSEL_COMMAND                 => "\x02";

# 5V Follow Pulse select bits (If 5V pulse
# will be following the next byte or bit.) 
use constant PRIME5V_TRUE                   => "\x02";
use constant PRIME5V_FALSE                  => "\x00";

# Parameter select bits 
use constant PARMSEL_PARMREAD               => "\x00";
use constant PARMSEL_SLEW                   => "\x10";
use constant PARMSEL_12VPULSE               => "\x20";
use constant PARMSEL_5VPULSE                => "\x30";
use constant PARMSEL_WRITE1LOW              => "\x40";
use constant PARMSEL_SAMPLEOFFSET           => "\x50";
use constant PARMSEL_ACTIVEPULLUPTIME       => "\x60";
use constant PARMSEL_BAUDRATE               => "\x70";

# Pull down slew rate. 
use constant PARMSET_Slew15Vus              => "\x00";
use constant PARMSET_Slew2p2Vus             => "\x02";
use constant PARMSET_Slew1p65Vus            => "\x04";
use constant PARMSET_Slew1p37Vus            => "\x06";
use constant PARMSET_Slew1p1Vus             => "\x08";
use constant PARMSET_Slew0p83Vus            => "\x0A";
use constant PARMSET_Slew0p7Vus             => "\x0C";
use constant PARMSET_Slew0p55Vus            => "\x0E";

# 12V programming pulse time table 
use constant PARMSET_32us                   => "\x00";
use constant PARMSET_64us                   => "\x02";
use constant PARMSET_128us                  => "\x04";
use constant PARMSET_256us                  => "\x06";
use constant PARMSET_512us                  => "\x08";
use constant PARMSET_1024us                 => "\x0A";
use constant PARMSET_2048us                 => "\x0C";

# 5V strong pull up pulse time table 
use constant PARMSET_16p4ms                 => "\x00";
use constant PARMSET_65p5ms                 => "\x02";
use constant PARMSET_131ms                  => "\x04";
use constant PARMSET_262ms                  => "\x06";
use constant PARMSET_524ms                  => "\x08";
use constant PARMSET_1p05s                  => "\x0A";
use constant PARMSET_2p10s                  => "\x0C";
use constant PARMSET_infinite               => "\x0E";

# Write 1 low time 
use constant PARMSET_Write8us               => "\x00";
use constant PARMSET_Write9us               => "\x02";
use constant PARMSET_Write10us              => "\x04";
use constant PARMSET_Write11us              => "\x06";
use constant PARMSET_Write12us              => "\x08";
use constant PARMSET_Write13us              => "\x0A";
use constant PARMSET_Write14us              => "\x0C";
use constant PARMSET_Write15us              => "\x0E";

# Data sample offset and Write 0 recovery time
use constant PARMSET_SampOff3us             => "\x00";
use constant PARMSET_SampOff4us             => "\x02";
use constant PARMSET_SampOff5us             => "\x04";
use constant PARMSET_SampOff6us             => "\x06";
use constant PARMSET_SampOff7us             => "\x08";
use constant PARMSET_SampOff8us             => "\x0A";
use constant PARMSET_SampOff9us             => "\x0C";
use constant PARMSET_SampOff10us            => "\x0E";

# Active pull up on time 
use constant PARMSET_PullUp0p0us            => "\x00";
use constant PARMSET_PullUp0p5us            => "\x02";
use constant PARMSET_PullUp1p0us            => "\x04";
use constant PARMSET_PullUp1p5us            => "\x06";
use constant PARMSET_PullUp2p0us            => "\x08";
use constant PARMSET_PullUp2p5us            => "\x0A";
use constant PARMSET_PullUp3p0us            => "\x0C";
use constant PARMSET_PullUp3p5us            => "\x0E";
 
# Baud rate bits 
use constant PARMSET_9600                   => "\x00";
use constant PARMSET_19200                  => "\x02";
use constant PARMSET_57600                  => "\x04";
use constant PARMSET_115200                 => "\x06";

# DS2480 program voltage available
use constant DS2480PROG_MASK                => "\x20";

# mode bit flags
use constant MODE_NORMAL                    => "\x00";
use constant MODE_OVERDRIVE                 => "\x01";
use constant MODE_STRONG5                   => "\x02";
use constant MODE_PROGRAM                   => "\x04";
use constant MODE_BREAK                     => "\x08";

use constant WRITE_FUNCTION => 1;
use constant READ_FUNCTION  => 0;

my $ODDPARITY = [ 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0 ];
my $DSCRC_TABLE = [
        0, 94,188,226, 97, 63,221,131,194,156,126, 32,163,253, 31, 65,
      157,195, 33,127,252,162, 64, 30, 95,  1,227,189, 62, 96,130,220,
       35,125,159,193, 66, 28,254,160,225,191, 93,  3,128,222, 60, 98,
      190,224,  2, 92,223,129, 99, 61,124, 34,192,158, 29, 67,161,255,
       70, 24,250,164, 39,121,155,197,132,218, 56,102,229,187, 89,  7,
      219,133,103, 57,186,228,  6, 88, 25, 71,165,251,120, 38,196,154,
      101, 59,217,135,  4, 90,184,230,167,249, 27, 69,198,152,122, 36,
      248,166, 68, 26,153,199, 37,123, 58,100,134,216, 91,  5,231,185,
      140,210, 48,110,237,179, 81, 15, 78, 16,242,172, 47,113,147,205,
       17, 79,173,243,112, 46,204,146,211,141,111, 49,178,236, 14, 80,
      175,241, 19, 77,206,144,114, 44,109, 51,209,143, 12, 82,176,238,
       50,108,142,208, 83, 13,239,177,240,174, 76, 18,145,207, 45,115,
      202,148,118, 40,171,245, 23, 73,  8, 86,180,234,105, 55,213,139,
       87,  9,235,181, 54,104,138,212,149,203, 41,119,244,170, 72, 22,
      233,183, 85, 11,136,214, 52,106, 43,117,151,201, 74, 20,246,168,
      116, 42,200,150, 21, 75,169,247,182,232, 10, 84,215,137,107, 53 ];


sub new {
    my $class = shift;
    my $port = shift;
    my $DEBUG = shift || 0;
    my $TWEAK = shift || 0;
    my $LINELENGTH = shift || "LONG"; # SHORT is the only other valid option
    my $this;
    $this->{ PORTNAME } = $port;
    $this->{ DEBUG } = $DEBUG;
    $this->{ TWEAK } = $TWEAK;
    $this->{ LINELENGTH } = $LINELENGTH;
    bless $this, $class;

    $this->openPort;
    return $this;
}

sub openPort {
    my $this = shift;

    if ( !$this->connected ) {
	my $port = $this->{ PORTNAME };
	
	my $s;
	if ( $OS_win ) {
	    $s = new Win32::SerialPort( $port ) or die "\n\nCan't open serial port $port: $^E\n\n";
	}
	else {
	    $s = new Device::SerialPort ($port) or die "\n\nCan't open serial port $port: $^E\n\n";
	}
	$s->baudrate( 9600 );
	
	$s->databits(8) if $s->can_databits;
	$s->parity("none");
	$s->handshake( "none" );
	$s->stopbits( 1 );
	
				# From Jukka Br on 6/2004. 
	if ( $this->{ TWEAK } == 2 ) {
	    $s->read_interval(100);     # max time between read char (milliseconds)
	    $s->read_char_time(50);     # avg time between read char
	    $s->read_const_time(1000);  # total = (avg * bytes) + const 
	    $s->write_char_time(5);
	    $s->write_const_time(1000);
	}
	

	#    $s->{C_IFLAG} &= ~(BRKINT|ICRNL|IGNCR|INLCR|INPCK|ISTRIP|IXON|IXOFF|PARMRK);
	#    $s->{C_IFLAG} |= IGNBRK|IGNPAR;
	#    $s->{C_OFLAG} &= ~(OPOST);
	#    $s->{C_CFLAG} &= ~(CSIZE|HUPCL|PARENB);
	#    $s->{C_CFLAG} |= (CLOCAL|CS8|CREAD);
	#    $s->{C_LFLAG} &= ~(ECHO|ECHOE|ECHOK|ECHONL|ICANON|IEXTEN|ISIG);
	#    $s->{C_VMIN} = 0;
	#    $s->{C_VTIME} = 3;
	
	$s->write_settings;
	$s->purge_all;
	
	$this->{ SERIALPORT } = $s;
	$this->DS2480Detect();
        
        # Search out and store device objects for any on-lan microlan couplers(1-wire hubs)
        $this->DS2409Detect();
    }
    return $this->{ SERIALPORT };
}

#--------------------------------------------------------------------------
# Set the baud rate on the com port. 
#
# 'new_baud'  - new baud rate defined as
# PARMSET_9600     0x00
# PARMSET_19200    0x02
# PARMSET_57600    0x04
# PARMSET_115200   0x06
# 
sub setBaud {
    my $this = shift;
    my $baud = shift;
    my $newBaud;

    return undef if !$this->connected();

    if    ( $baud eq PARMSET_9600 )   { $newBaud =   9600 }
    elsif ( $baud eq PARMSET_19200 )  { $newBaud =  19200 }
    elsif ( $baud eq PARMSET_57600 )  { $newBaud =  57600 }
    elsif ( $baud eq PARMSET_115200 ) { $newBaud = 115200 }

    $this->{ 'baud' } = $baud;
    $this->{ SERIALPORT }->baudrate( $newBaud );
    $this->{ SERIALPORT }->write_settings();
}

sub closePort {
    my $this = shift;

    if ( $this->connected() ) {
	delete $this->{ SERIALPORT };
    }
}

sub connected {
    my $this = shift;
    
    return exists $this->{ SERIALPORT } ? 1 : 0;
}

sub purge_all {
    my $this = shift;
    return undef if !$this->connected();
    $this->{ SERIALPORT }->purge_all;
}
   

# Search/map any DS2409 microlan couplers attached to a port
# 
#---------------------------------------------------------------------------
sub DS2409Detect {
    my $this = shift;

    print "Searching for DS2409 Microlan Couplers\n   ";
    $this->{'DS2409Current'} = -1; # -1= NONE, All Off    
    $this->{'DS2409State'} = 'OFF';
    $this->{'DS2409Count'} = 0;

    my @devices = $this->scan('1f');
    my $CouplerCount=0;
    for my $ib (@devices) {
       print $ib->model."  ";
       $ib->set_coupler('OFF');
       my $TmpStr = join('','DS2409_',$CouplerCount);
       $this->{$TmpStr} = $ib;
       $CouplerCount++;
    }

    if ($CouplerCount == 0) { return(0); }

    print $CouplerCount, " devices found\n";
    $this->{'DS2409Count'} = $CouplerCount;

    # Turn all couplers off
    my $i;
    for($i=0;$i<$this->{'DS2409Count'};$i++) {
       my $TmpStr = join('','DS2409_',$i);
    }
   
    $this->{'DS2409State'} = 'OFF';
    $this->{'DS2409Current'} = 'DS2409_0';
    
    my @foo = $this->scan();

return $CouplerCount;
}





#---------------------------------------------------------------------------
# Attempt to resyc and detect a DS2480
#
# Returns:  TRUE  - DS2480 detected successfully
#           FALSE - Could not detect DS2480
#
sub DS2480Detect {
    my $this = shift;
    return 0 if !$this->connected();

#    print join( " ", caller( 1 ) ), "\n";
#    print join( " ", caller( 2 ) ), "\n";
#    print join( " ", caller( 3 ) ), "\n";

    $this->{ 'mode' } = MODSEL_COMMAND;
    $this->{ 'speed' } = SPEEDSEL_FLEX;
    $this->{ 'level' } = MODE_NORMAL;

    # set the baud rate to 9600
    $this->setBaud( PARMSET_9600 );

    # send a break to reset the DS2480
    $this->{ SERIALPORT }->pulse_break_on( 2 );

    # delay to let line settle 
    select( undef, undef, undef, .002 );

    # flush the buffers
    $this->purge_all();

    # send the timing byte 
    return 0 if !$this->write( "\xC1" );

    my $send;
    # set the FLEX configuration parameters
    # default PDSRC = 1.37Vus
    if ( $this->{ LINELENGTH } eq "SHORT" ) {
	$send .= chr( ord(CMD_CONFIG) | ord(PARMSEL_SLEW) | ord(PARMSET_Slew1p37Vus) );
    }
    else {
	$send .= chr( ord(CMD_CONFIG) | ord(PARMSEL_SLEW) | ord(PARMSET_Slew0p83Vus) );
    }

    # default W1LT = 8us
    if ( $this->{ LINELENGTH } eq "SHORT" ) {
	$send .= chr( ord(CMD_CONFIG) | ord(PARMSEL_WRITE1LOW) | ord(PARMSET_Write8us) );
    }
    else {
	$send .= chr( ord(CMD_CONFIG) | ord(PARMSEL_WRITE1LOW) | ord(PARMSET_Write12us) );
    }
    # default DSO/WORT = 10us
    $send .= chr( ord(CMD_CONFIG) | ord(PARMSEL_SAMPLEOFFSET) | ord(PARMSET_SampOff10us) );

    # construct the command to read the baud rate (to test command block) 
    $send .= chr( ord(CMD_CONFIG) | ord(PARMSEL_PARMREAD) | (ord(PARMSEL_BAUDRATE) >> 3) );

    # also do 1 bit operation (to test 1-Wire block)
    $send .= chr( ord(CMD_COMM) | ord(FUNCTSEL_BIT) | ord($this->{ 'baud' }) | ord(BITPOL_ONE) );

    # flush the buffers
    $this->purge_all();

    # send the packet 
    if ($this->write( $send ) ) {
	# read back the response 
	my $result = $this->read( 5 );
	if ( $result && length($result) == 5 ) {
	    my ( $r1, $r2 ) = $result =~ /...(.)(.)/;
	    $r1 = ord( $r1 );
	    $r2 = ord( $r2 );
	    # look at the baud rate and bit operation
	    # to see if the response makes sense
	    return 1 if ((($r1 & 0xF1) == 0x00) && 
			 (($r1 & 0x0E) == ord($this->{ 'baud' })) && 
			 (($r2 & 0xF0) == 0x90) &&                
			 (($r2 & 0x0C) == ord($this->{ 'baud' }) ) );
	}
    }

    return 0;
}

sub write { 
    my $this = shift; 
    my $string = shift;
    return undef if !$this->connected();

    if ( $this->{ DEBUG } ) {
	my @debug = map { uc(unpack("H*", $_ )) } split //, $string;
	my $debugString = join( " ", @debug );
	warn( "WROTE: $debugString\n" );
    } 
    my $count = $this->{ SERIALPORT }->write( $string ); 

                                # 11ms  added by Thomas Stoll on 10.4.2001 20:50 in Modul Connection.pm
                                # This caused problems for several other users, so made it optional
    if ( $this->{ TWEAK } == 1 ) {
        select undef, undef, undef, (11*1000 / 10**6);
    }

    if ( !$count ) { 
        warn "write failed\n"; 
        return undef; 
    } 
    elsif ( $count != length($string) ) { 
        warn "write incomplete\n"; 
        return undef; 
    } 

    if ($OS_win) {
	$this->{ SERIALPORT }->write_done( 1 );
    }
    else {
	$this->{ SERIALPORT }->write_drain;
    }

    return 1; 
} 

sub read {
    my $this = shift;
    my $bytes = shift;
    return undef if !$this->connected();

    $this->{ SERIALPORT }->read_char_time( $OS_win ? 20 : 10 );

    while ( my ( $count, $string ) = $this->{ SERIALPORT }->read( $bytes ) ) { 
        if ( $count != $bytes ) { 
	    warn "read of device and datalen unsuccessful\n" if $this->{ DEBUG };
            return $string;
        } 
 
	if ( $this->{ DEBUG } ) {
	  my $tmpString = join( " ", map { uc(unpack( "H*", $_ )) } split( //, $string ));
	  warn( " READ: $tmpString\n" );
	}
	return $string;
      }
}


#--------------------------------------------------------------------------
# Update the Dallas Semiconductor One Wire CRC (utilcrc8) from the global
# variable utilcrc8 and the argument.  
#
# 'utilcrc8' - last value of utilcrc8
# 'x'        - data byte to calculate the 8 bit crc from
#
# Returns: the updated utilcrc8.
#
sub docrc8 {
    my $this = shift;
    my $utilcrc8 = 0;

    my @data = unpack( "C*", shift );

    foreach my $x ( @data ) {
	$utilcrc8 = $DSCRC_TABLE->[ $utilcrc8 ^ $x ];
    }

    return $utilcrc8;
}

#--------------------------------------------------------------------------
# Calculate a new CRC16 from the input data shorteger.  Return the current
# CRC16 and also update the global variable CRC16.
#
# 'data'     - data to perform a CRC16 on
#
# Returns: the current CRC16
#
sub docrc16 {
    my $this = shift;
    my $prevcrc16 = shift;
    my $data = shift;

    my @data = unpack( "C*", $data );
    foreach my $x ( @data ) {
	$x = ($x ^ ($prevcrc16 & 0xff)) & 0xff;
	$prevcrc16 >>= 8;

	$prevcrc16 ^= 0xc001 if $ODDPARITY->[$x & 0xf] ^ $ODDPARITY->[$x >> 4];
	
	$x <<= 6;
	$prevcrc16 ^= $x;
	$x <<= 1;
	$prevcrc16 ^= $x;
    }

    return $prevcrc16;
}

sub mode {
    my $this = shift;
    my $newmode = shift;

    if ( $this->{'mode'} ne $newmode) {
	$this->{'mode'} = $newmode;
	if    ( $newmode eq MODSEL_COMMAND ) { return MODE_COMMAND; }
	elsif ( $newmode eq MODSEL_DATA    ) { return MODE_DATA;    }
    }
    return "";
}


#--------------------------------------------------------------------------
# Set the 1-Wire Net line level.  The values for new_level are
# as follows:
#
# 'level' - new level defined as
#                MODE_NORMAL     0x00
#                MODE_STRONG5    0x02
#                MODE_PROGRAM    0x04
#                MODE_BREAK      0x08 (not supported)
#
# Returns:  current 1-Wire Net level  
#
sub level {
    my $this = shift;
    my $level = shift;
    my $send;
    my $rt = 0;

    # check if need to change level
    if ( !defined( $this->{ "level" } ) || $level ne $this->{ "level" } ) {
	# check if just putting back to normal
	if ( $level eq MODE_NORMAL) {
	    # check if correct mode 
	    $send .= $this->mode( MODSEL_COMMAND );

	    # stop pulse command
	    $send .= MODE_STOP_PULSE;
   
	    # flush the buffers
	    $this->purge_all();

	    # send the packet 
	    if ($this->write( $send ) ) {
		# read back the 1 byte response 
		my $result = $this->read( 1 );
		if ( length( $result ) == 1 ) {
		    # check response byte
		    if ((ord($result) & 0xE0) == 0xE0) {
			$rt = 1;
			$this->{ "level" } = MODE_NORMAL;
		    }
		}
	    }
	}
	else {
	    # set new level
	    # check if correct mode 
	    $send .= $this->mode( MODSEL_COMMAND );

	    # strong 5 volts
	    if ( $level eq MODE_STRONG5) {
		# set the SPUD time value 
		$send .= chr( ord(CMD_CONFIG) | ord(PARMSEL_5VPULSE) | ord(PARMSET_infinite) );
		# add the command to begin the pulse
		$send .= chr( ord(CMD_COMM) | ord(FUNCTSEL_CHMOD) | ord(SPEEDSEL_PULSE) | ord(BITPOL_5V) );
	    }
	    # 12 volts
	    elsif ( $level eq MODE_PROGRAM ) {
		# check if programming voltage available
		return MODE_NORMAL if !$this->{ "ProgramAvailable" };

		# set the PPD time value 
		$send .= chr( ord(CMD_CONFIG) | ord(PARMSEL_12VPULSE) | ord(PARMSET_infinite) );
		# add the command to begin the pulse
		$send .= chr( ord(CMD_COMM) | ord(FUNCTSEL_CHMOD) | ord(SPEEDSEL_PULSE) | ord(BITPOL_12V) );
	    }

	    # flush the buffers
	    $this->purge_all();
	    
	    # send the packet 
	    if ( $this->write( $send ) ) {
		# read back the 1 byte response from setting time limit
		my $result = $this->read( 1 );
		if ( length( $result ) == 1 ) {
		    # check response byte
		    if ((ord($result) & 0x81) == 0) {
			$this->{ "level" } = $level;
			$rt = 1;
		    }
		}
	    }
	}

	# if lost communication with DS2480 then reset 
	$this->DS2480Detect() if !$rt;
    }

    # return the current level
    return $this->{ "level" };
}


sub reset {
    my $this = shift;
    my $send;
    return undef if !$this->connected();

    # make sure normal level
    $this->level(MODE_NORMAL);

    # check if correct mode 
    $send .= $this->mode( MODSEL_COMMAND );

    # construct the command
    $send .= chr( ord(CMD_COMM) | ord(FUNCTSEL_RESET) | ord($this->{ "speed" }) );

    # flush the buffers
    $this->purge_all();

    # send the packet 
    if ( $this->write( $send ) ) {
	# read back the 1 byte response from setting time limit
	my $result = $this->read( 1 );
	if ( length( $result ) == 1 ) {
	    my $oresult = ord( $result );
	    # make sure this byte looks like a reset byte
	    if ((($oresult & ord(RB_RESET_MASK)) == ord(RB_PRESENCE)) ||
		(($oresult & ord(RB_RESET_MASK)) == ord(RB_ALARMPRESENCE))) {
		# check if programming voltage available
		$this->{ "ProgramAvailable" } = (($oresult & 0x20) == 0x20) ? 1 : 0; 
		return 1;
	    }
	    else {
		return 0;
	    }
	}
    }

    # an error occured so re-sync with DS2480
    $this->DS2480Detect();

    return 0;
}

#--------------------------------------------------------------------------
# The 'owNext' function does a general search.  This function
# continues from the previos search state. The search state
# can be reset by using the 'owFirst' function.
# This function contains one parameter 'alarm_only'.  
# When 'alarm_only' is TRUE (1) the find alarm command 
# 0xEC is sent instead of the normal search command 0xF0.
# Using the find alarm command 0xEC will limit the search to only
# 1-Wire devices that are in an 'alarm' state. 
#
# 'RESET'      - TRUE (1) perform reset before search, FALSE (0) do not
#                perform reset before search. 
#                DEFAULT = TRUE
# 'ALARM'      - TRUE (1) the find alarm command 0xEC is 
#                sent instead of the normal search command 0xF0
#                DEFAULT = FALSE;
# Returns:   TRUE (1) : when a 1-Wire device was found and it's 
#                       Serial Number placed in the global SerialNum
#            FALSE (0): when no new device was found.  Either the
#                       last search was the last device or there
#                       are no devices on the 1-Wire Net.
# 
sub owNext {
    my $this = shift;
    my %ARGS = @_;
    
    my $reset = defined $ARGS{ RESET } ? $ARGS{ RESET } : 1;
    my $alarm = $ARGS{ ALARM } || 0;
    my $send;

   # if the last call was the last one 
    if ( $this->{ "LastDevice" } ) {
	# reset the search
	$this->{ "LastDiscrepancy" } = 0;
	$this->{ "LastDevice" } = 0;
	$this->{ "LastFamilyDiscrepancy" } = 0;
        if ($this->{ 'DS2409Count' } > 0) {
            $this->{'DS2409Current'}='DS2409_0';
            $this->{'DS2409State'}='OFF';
        }
	return undef;
    }

    # check if reset first is requested
    if ( $reset ) {
	# reset the 1-wire 
	# if there are no parts on 1-wire, return FALSE
	if (!$this->reset() ) {
	    # reset the search
	    $this->{ "LastDiscrepancy" } = 0;
	    $this->{ "LastFamilyDiscrepancy" } = 0;
	    return undef;
	}
    }

    # build the command stream
    # call a function that may add the change mode command to the buff
    # check if correct mode 
    $send .= $this->mode( MODSEL_DATA );

    # search command
    $send .= $alarm ? "\xEC" : "\xF0";

    # change back to command mode
    $send .= $this->mode( MODSEL_COMMAND );

    # search mode on
    $send .= chr( ord(CMD_COMM) | ord(FUNCTSEL_SEARCHON) | ord($this->{ speed }) );

    # change back to data mode
    $send .= $this->mode( MODSEL_DATA );

    # set the temp Last Descrep to none
    my $tmp_last_desc = 0xFF;  

    # add the 16 bytes of the search
    my @tmpSend = ( 0 ) x ( 16 * 8 );
    # only modify bits if not the first search
    if ( $this->{ "LastDiscrepancy" } != 0xFF) {
	my @tmpSerial = split //, unpack( "b*", $this->{ "SerialNum" } );
	# set the bits in the added buffer
	foreach my $i ( 0..63 ) {
	    # before last discrepancy
	    if ($i < $this->{ "LastDiscrepancy" } - 1) {
		$tmpSend[2*$i + 1] = $tmpSerial[$i];
	    }
	    # at last discrepancy
	    elsif ($i == $this->{ "LastDiscrepancy" } - 1 ) {
		$tmpSend[2*$i + 1] = 1;
	    }
	    # after last discrepancy so leave zeros
	}
    }
    $send .= pack( "b*", join( "", @tmpSend ) );

    # change back to command mode
    $send .= $this->mode( MODSEL_COMMAND );

    # search OFF
    $send .= chr( ord(CMD_COMM) | ord(FUNCTSEL_SEARCHOFF) | ord($this->{ "speed" }) );

    # flush the buffers
    $this->purge_all();

    # send the packet 
    if ( $this->write( $send ) ) {
	# read back the 17 byte response from setting time limit
	my $result = $this->read( 17 );
	if ( $result && length( $result ) == 17 ) {
	    my @result = split //, unpack( "b*", substr( $result, 1 ) );
	    my @tmpSerialNum = ( 0 ) x ( 16 * 8 );
	    # interpret the bit stream
	    foreach my $i ( 0..63 ) {
		# get the SerialNum bit
		$tmpSerialNum[$i] = $result[2*$i + 1];
		# check LastDiscrepancy
		if ( $result[2*$i] && !$result[2*$i + 1] ) {
		    $tmp_last_desc = $i + 1;  
		    # check LastFamilyDiscrepancy
		    $this->{ "LastFamilyDiscrepancy" } = $i + 1 if $i < 8;
		}
	    }
	    my $tmpSerial = pack( "b*", join( "", @tmpSerialNum[0..63] ) );

	    # do dowcrc
	    my $lastcrc = $this->docrc8( $tmpSerial );

	    # check results 
	    if (($lastcrc != 0) || ($this->{ "LastDiscrepancy" } == 63) || (!ord(substr($tmpSerial, 0, 1)))) {
		# error during search 
		# reset the search
		$this->{ "LastDiscrepancy" } = 0;
		$this->{ "LastDevice" } = 0;
		$this->{ "LastFamilyDiscrepancy" } = 0;
		return undef;
	    }
	    else {
             
	      # successful search
		# check for lastone
		if (($tmp_last_desc == $this->{ "LastDiscrepancy" }) || ($tmp_last_desc == 0xFF)) {
                     if ($this->{ 'DS2409Count' } > 0) {
                     my $CurrentDS = $this->{'DS2409Current'};
                     #print "Current=$CurrentDS ";
                     #print "State=",$this->{'DS2409State'}," ";
                     #print "\n";
                     
                       if ($this->{ 'DS2409State' } eq 'MAIN') {
                         $this->{ $CurrentDS }->set_coupler('AUX');
                         $this->{ 'DS2409State' } = 'AUX';
                       }
                       elsif ( $this->{'DS2409State'} eq 'AUX') {
                         $this->{$CurrentDS }->set_coupler('OFF');
                         $this->{'DS2409State'} = 'OFF';

                         my $LastDS2409 = join('','DS2409_',$this->{'DS2409Count'}-1);

                         if ($LastDS2409 eq $this->{ 'DS2409Current' }) {
                            $this->{'DS2409Current'}='DS2409_0'; 
		            $this->{ "LastDevice" } = 1;
                            print "LastDevice\n";
                         } else {
                            # Step to next device
                            my $myDevNum = substr($this->{'DS2409Current'},7,1);
                            $myDevNum++;
                            $this->{'DS2409Current'}=join('','DS2409_',$myDevNum);
                            $this->{'DS2409State'}='MAIN';
                            $this->{ $this->{'DS2409Current'} }->set_coupler('MAIN');
                         }
                       }
                       elsif ($this->{'DS2409State'} eq 'OFF') {
                          $this->{'DS2409State'} = 'MAIN';
                       }

                     } else { $this->{ "LastDevice" } = 1; }
		}

		# copy the SerialNum to the buffer
		$this->{ "SerialNum" } = $tmpSerial;
                #print "DEV $tmpSerial $this->{'DS2409State'} $this->{'DS2409Current'} ";
                my $cacheentry = join ('',$this->{'DS2409Current'},'-',$this->{'DS2409State'});
                my $tmp = unpack('H*',$tmpSerial);
                $tmp .= 'CE';
                if (substr($tmp,0,2) eq '1f') { $cacheentry = ''; }
                if ($this->{'DS2409State'} eq 'OFF') { $cacheentry=''; }
                $this->{$tmp}=$cacheentry;
               
         
		# set the count
		$this->{ "LastDiscrepancy" } = $tmp_last_desc;
		return length( $tmpSerial ) == 8 ? $tmpSerial : undef;
	    }
	}
    }

    # an error occured so re-sync with DS2480
    $this->DS2480Detect();

    # reset the search
    $this->{ "LastDiscrepancy" } = 0;
    $this->{ "LastDevice" } = 0;
    $this->{ "LastFamilyDiscrepancy" } = 0;          

    return undef;
}

#----------------------------------------------------------------------
# Search for devices 
#
# 'FAMILY'    - Find devices with only this family code
#               If no family is present, all devices are returned
# 'SERIAL'    - Find this serial number on the 1-wire net
# 'ALARM'     - Search for devices that are in an alarm state
#
# Returns: An array of serial numbers matching the serach criteria
#
sub FindDevices {
    my $this = shift;
    my %ARGS = @_;

    $this->reset();
    if ( defined $ARGS{ SERIAL } ) {
	my $alarm_only = $ARGS{ ALARM } || 0;
	my @serialNum = @{$ARGS{ SERIAL }};

	my $serial;
	foreach my $i ( @serialNum ) {
	    $serial .= chr( $i );
	}
	my @tmpSerial = split //, unpack( "b*", $serial );
	my $send;

	# construct the search rom 
	$send .= $alarm_only ? "\xEC" : "\xF0";

	my @tmpSend = ( 1 ) x (24 * 8);

	# now set or clear apropriate bits for search 
	foreach my $i ( 0..63 ) {
	    $tmpSend[3*($i+1)-1] = $tmpSerial[$i];
	}

	$send .= pack( "b*", join( "", @tmpSend ) );

	# send/recieve the transfer buffer   
	$this->reset();
	my $result = $this->owBlock( $send );
	if ( $result ) {
	    # check results to see if it was a success 
	    my @result = split //, unpack( "b*", substr( $result, 1 ) );
	    my $cnt = 0;
	    my $goodbits = 0;
	    for (my $i = 0; $i < 192; $i += 3) {
		my $tst = ( $result[$i] << 1 ) | $result[$i+1];
		my $s = $tmpSerial[$cnt++];
		
		if ($tst == 0x03) {
		    # no device on line 
		    $goodbits = 0;    # number of good bits set to zero 
		    last;     # quit 
		}
		
		if ( ( $s == 0x01 && $tst == 0x02 ) ||
		     ( $s == 0x00 && $tst == 0x01 ) ) {
		    # correct bit 
		    $goodbits++;  # count as a good bit 
		}
	    }
	    
	    # check too see if there were enough good bits to be successful 
	    return ( [ @serialNum ] ) if $goodbits >= 8;
	}

	# block fail or device not present
	return ();
    }
    # find the devices
    # set the search to first find that family code
    if ( defined $ARGS{ FAMILY } ) {
	$this->{ "SerialNum" } = chr( $ARGS{ FAMILY } ) . ("\x00" x 7 );
	$this->{ "LastDiscrepancy" } = 64;
	$this->{ "LastDevice" } = 0;
        $this->{ 'DS2409Current' } = 'DS2409_0';
        $this->{ 'DS2409State' } = 'OFF';
    }
    else {
	$this->{ "SerialNum" } = "\x00" x 8;
	$this->{ "LastDiscrepancy" } = 0;
	$this->{ "LastDevice" } = 0;
	$this->{ "LastFamilyDiscrepancy" } = 0;
        $this->{ 'DS2409Current' } = 'DS2409_0';
        $this->{ 'DS2409State' } = 'OFF';
    }

    my @devices;
    # loop to find all of the devices up to MAXDEVICES
    while ( my $serial = $this->owNext( %ARGS ) ) {
	my @serial = unpack( "C*", $serial );
        #if ($serial[0] != 0x1f) {
	push @devices, [ @serial ] if !defined $ARGS{ FAMILY } || $serial[0] == $ARGS{ FAMILY };
        #}
    }
    return @devices;
}

#--------------------------------------------------------------------------
# The 'owBlock' transfers a block of data to and from the 
# 1-Wire Net with an optional reset at the begining of communication.
# The result is returned in the same buffer.
#
# 'DATA'     - reference to an array of data to be sent
#
# Supported devices: all 
#
# Returns:   TRUE (1) : The optional reset returned a valid 
#                       presence (do_reset == TRUE) or there
#                       was no reset required.
#            FALSE (0): The reset did not return a valid prsence
#                       (do_reset == TRUE).
#
#  The maximum tran_length is 64
#
sub owBlock {
    my $this = shift;
    my $data = shift;
    my $datalen = length( $data );
    my $send;

    # check for a block too big
    return undef if $datalen > 64;

    if ( $this->send( $data ) ) {
	# read back the response
	
	my $result = $this->read( $datalen );
	return $result if $result && length( $result ) == $datalen;
    }

    # an error occured so re-sync with DS2480
    $this->DS2480Detect();

    return undef;
}

sub send {
    my $this = shift;
    my $data = shift;
    my $datalen = length( $data );
    my $send;

    # check for a block too big
    return 0 if $datalen > 64;

    # make sure normal level
    $this->level(MODE_NORMAL);

    # construct the packet to send to the DS2480
    # check if correct mode 
    $send .= $this->mode( MODSEL_DATA );

    $data =~ s/\xe3/\xe3\xe3/g;
    $send .= $data;

    # flush the buffers
    $this->purge_all();

    # send the packet 
    return $this->write( $send );
}


#--------------------------------------------------------------------------
# The 'select' function resets the 1-Wire and sends a MATCH Serial 
# Number command followed by the current SerialNum code. After this 
# function is complete the 1-Wire device is ready to accept device-specific
# commands. 
#
# Returns:   TRUE (1) : reset indicates present and device is ready
#                       for commands.
#            FALSE (0): reset does not indicate presence or echos 'writes'
#                       are not correct.
#
sub select {
    my $this = shift;
    my $serial = pack( "b*", shift );
    my $send;

      if ($this->{'DS2409Count'} > 0) {
         my $cacheIndex = unpack("H*",$serial);
            $cacheIndex .= 'CE';
         if ($this->{$cacheIndex} ne '') {
         my $coupler;
         my $state;
         ($coupler,$state) = split('-',$this->{$cacheIndex});
         #Aprint "<< ".$this->{$cacheIndex}.">>";
         $this->{$coupler}->set_coupler($state);
         }
      }
          
        # reset the 1-wire 
        if ($this->reset()) {
	    # create a buffer to use with block function      
	    # match Serial Number command 0x55 
	    $send .= "\x55";

	    # Serial Number
	    $send .= $serial;
	    # send/recieve the transfer buffer   
	    my $result = $this->owBlock( $send );
            if ($result eq $send) { return(1); }
        }

    return(0);
}
sub crc {
    my($crc, @newbytes) = @_;
    
    sub addbit {
	my($crc, $bit) = @_;
	#printf("addbit($bit): 0x%02x -> ",$crc);;
	my $in = ($crc & 1) ^ $bit;
	$crc ^= 0x18 if $in;
	$crc >>= 1;
	$crc |= 0x80 if $in;
	#printf("0x%02x\n",$crc);
	return $crc;
    }
    
    foreach my $byte (@newbytes) {
	my $bits = unpack("b8", $byte);
	my(@bits) = split(//,$bits);
	foreach (@bits) {
	    $crc = addbit($crc, $_);
	}
    }
    return $crc;
}

sub scan {
    my($self, $family_code, $serial) = @_;
    my(@buttons);

    my %ARGS = ( ALARM => 0 );
    $ARGS{ FAMILY } = hex($family_code) if defined $family_code;

    my @serial = unpack( "C*", pack( "b*", $serial ) ) if defined $serial;
    $ARGS{ SERIAL } = [ @serial ] if defined $serial;

    my @raw_ids = $self->FindDevices( %ARGS );

    print "ibutton Connection.pm scan: fc=$family_code s=$serial id=@raw_ids\n"  if $self->{ DEBUG };

    foreach my $i (@raw_ids) {
	my $j;
	foreach my $k ( @{$i}[0,6,5,4,3,2,1,7] ) {
	    $j .= sprintf( "%02X", $k );
	}
	my $raw_id = pack 'H16', $j;
	my $family = substr($raw_id, 0, 1);
	my $serial = substr($raw_id, 1, 6);
	my $crc    = substr($raw_id, 7, 1);
	
	$raw_id = unpack('b8', $family) . scalar(reverse(unpack('B48', $serial)));
	$raw_id .= unpack('b8', $crc);
	# $raw_id is a 64 character string of "0" and "1"
        #if ((hex(unpack('h2',$family)) ne 0xf1) || ($family_code eq '1f'))
        #Search for a matching raw ID
        my $Duplicated = 0;
        for my $compid (@buttons) {
           if ($compid->raw_id() eq $raw_id) { $Duplicated=1; }
        }
        if ($Duplicated == 0)
        {
	    my $button = Hardware::iButton::Device->new($self, $raw_id);
    #        print $button->serial()." ".$button->{'connection'}->{'DS2409Current'}." ".$button->{'connection'}->{'DS2409State'}." ";
	    push(@buttons, $button);
        }
    }

    return @buttons;
}

sub scan_alarm {
    my($self, $family_code, $serial) = @_;
    my(@buttons);

    my %ARGS = ( ALARM => 1 );
    $ARGS{ FAMILY } = hex($family_code) if defined $family_code;

    my @serial = unpack( "C*", pack( "b*", $serial ) ) if defined $serial;
    $ARGS{ SERIAL } = [ @serial ] if defined $serial;

    my @raw_ids = $self->FindDevices( %ARGS );

    foreach my $i (@raw_ids) {
	my $j;
	foreach my $k ( @{$i}[0,6,5,4,3,2,1,7] ) {
	    $j .= sprintf( "%02X", $k );
	}
	my $raw_id = pack 'H16', $j;
	my $family = substr($raw_id, 0, 1);
	my $serial = substr($raw_id, 1, 6);
	my $crc    = substr($raw_id, 7, 1);
	
	$raw_id = unpack('b8', $family) . scalar(reverse(unpack('B48', $serial)));
	$raw_id .= unpack('b8', $crc);
	# $raw_id is a 64 character string of "0" and "1"
	my $button = Hardware::iButton::Device->new($self, $raw_id);
	#print "id: ",$button->id(),"\n";
	push(@buttons, $button);
    }

    return @buttons;
}

sub id_on_wire {
    my $self = shift;
    my $id = uc(shift);

    my @x;
    while ( $id =~ m/(..)/g ) {
	push @x, hex( $1 );
    }

    my $foundID = 0;
    my @buttons = $self->FindDevices( SERIAL => [ @x[ 0, 6, 5, 4, 3, 2, 1, 7 ] ] );
    foreach my $i ( @buttons ) {
	my $button = "";
	foreach my $j ( @$i[0, 6, 5, 4, 3, 2, 1, 7 ] ) {
	    $button .= sprintf( "%02X", $j );
	}
	if ( $id eq $button ) {
	    $foundID = 1;
	    last;
	}
    }
    
    return $foundID;
}

sub get_coupler {
    my $self = shift;
    my $id = uc(shift);
    print "miID $id ";

    my $send = "\x55";
       $send .= $id;

    # send/recieve the transfer buffer   
    my $result = $self->owBlock( $send );
    if ($result eq $send) {print "HIT"; return(1); }
    print "NOPE";
    return(0);
}


1;
