package iplcs; # Serial port

#package iplcu; # USB port
#package ControlX10::Serial::iplcs;
#package ControlX10::USB:iplcu; # iplc needs to be rewritten to handle a few ioctls

#-----------------------------------------------------------------------------
# 12/22/2005 - I added the routine chkxbit which checks to see if the X10
#              bit is clear. If it is then it's ok to send. Problem is I'm
#              now getting garbage out of the PLC! Grrrr!
#            - Fixed the problem, I remove a debug message that had a needed
#              function call in it (VERY BAD!).
#-----------------------------------------------------------------------------
#
# A Smarthome  interface, used by Misterhouse ( http://misterhouse.net )
#
# Probably Linux only at this point. I should convert over to use libusb as
# that's more portable.
#
# $garage_light                        =  new X10_Item('A1', iplcs);
#-----------------------------------------------------------------------------
#
# You need to do this for Versions 2.100 and earlier. I'll ask Bruce to add this
# to MH.
#
# Add iplcs.pm to ~mh/lib . For now I'm leaving it there. It may change later
# with the adding of Insteon support (which will be it's main purpose in life).
#
# OK to use this module you need to make the following changes to the following
# files:
#
# ~mh/bin/mh - around line 858 (just after the cm17_port)
#
#     # I guess there is not really much to do here
#     if ($config_parms{iplcs_port}) {
#         require 'iplcs.pm';
#         if (&serial_port_create('iplcs', $config_parms{iplcs_port}, 4800, 'none')) {
#             #$iplcs_objects{timer} = new Timer;
#             #$iplcs_objects{active} = new Generic_Item;
#         }
#     }
#
# ~mh/bin/mh.private.ini - at the end
#
# @ Insteon Stuff, just the serial stuff for right now
# iplcs_port=/dev/ttyM7
#
# ~mh/lib/Serial_Item.pm
#
#     elsif ($interface eq 'iplcs') {
#         # iplcs wants individual codes with X
#         &main::print_log("Using iplcs to send: $serial_data");
#         &iplcs::send($main::Serial_Ports{iplcs}{object}, $serial_data);
#     }
#
# ~mh/code/<Your_personal_code_dir>/x10.mht - After #Format = A
#
# X10A,        A1,    T_A1,                   XXX|Test,                    IPLCS
#
# To turn off the debug messages comment out the next line:
# $DEBUG = 1;
#
use strict;
use vars qw($VERSION $DEBUG @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $POWER_RESET $BACKLOG);
use Time::HiRes qw( usleep gettimeofday );

use constant IGNORE => 10;

require Exporter;

@ISA         = qw(Exporter);
@EXPORT      = qw( send_iplcs );
@EXPORT_OK   = qw();
%EXPORT_TAGS = (FUNC    => [qw( send_iplcs )]);

Exporter::export_ok_tags('FUNC');

$EXPORT_TAGS{ALL} = \@EXPORT_OK;

#### Package variable declarations ####

($VERSION) = q$Revision$ =~ /: (\S+)/; # Note: cvs version reset when we moved to sourceforge
my $Last_Dcode;

sub send_iplcs {
    return unless ( 2 == @_ );
    return iplcs::send ( @_ );
}

# ============================================================================
# To   device => S:
# From device <= R:
#
# Command sent:
# => S: 0x02 <CMD> <parameters>
# <= R: 0x02 <CMD> <data> 0x06	// Good data
#   or
# <= R: 0x02 <CMD> <data?> 0x15	// Bad data!
#
#
# To send X10:
#
# => S: 0x02
# <= R: 0x02
# => S: 0x02
# <= R: 0x02
#
# To receive X10:
#
# <= R: 0x02 0x4A 0x00 0x66 (A1)
# => S: 0x02
#
# <= R: 0x02 0x4A 0x01 0x63 (AOff)
# => S: 0x02
#
sub dim_decode_iplc {
    return unless ( 1 == @_ );
    return iplcs::dim_level_decode ( shift );
}

sub ping_iplc {
    return unless ( 1 == @_ );
    return iplcs::ping ( shift );
}

# ============================================================================
# Setup unit-command  codes:  e.g. XA1AJ, XA1AK, XA1+20
# Note: The 0%->100% states are handled directly in Serial_Item.pm
#
# C5CON & C5COFF
# 0x01 0x02 0x00 0x00 0x00 0x00 0x00 0x00
# 0x03 0x45 0x08 0x02 0x00 0x00 0x00 0x00
# 0x03 0x4a 0x00 0x65 0x00 0x00 0x00 0x00
# 0x01 0x02 0x00 0x00 0x00 0x00 0x00 0x00
# I *** Event X10 message received 0x00 0x00 0x00 0x00 0x00
# 0x04  R A07 64 2 Unit 7 0x00 0x00 0x00
# 0x01 0x02 0x00 0x00 0x00 0x00 0x00 0x00
# 0x01 0x45 0x00 0x00 0x00 0x00 0x00 0x00
# 0x03 0x08# R M13 4160 2 Unit 13 0x00 0x00
# 0x02 0x01 0x63 0x00 0x00 0x00 0x00 0x00
# 0x01 0x02 0x00 0x00 0x00 0x00 0x00 0x00
# 0x01 0x45 0x00 0x00 0x00 0x00 0x00 0x00
# 0x04 0x08 R M13 4160 2 Unit 13 0x00 0x00
# 0x01 0x21 0x00 0x00 0x00 0x00 0x00 0x00
# 0x01 0x02 0x00 0x00 0x00 0x00 0x00 0x00
# 0x03 0x45 0x08 0x02 0x00 0x00 0x00 0x00
# 0x03 0x4a 0x01 0x22 0x00 0x00 0x00 0x00
# 0x01 0x02 0x00 0x00 0x00 0x00 0x00 0x00
# I *** Event X10 message received 0x00 0x00 0x00 0x00 0x00
# 0x03 # R M13 4160 2 Unit 13 0x00 0x00 0x00
# 0x01 0x21 0x00 0x00 0x00 0x00 0x00 0x00
# 0x01 0x02 0x00 0x00 0x00 0x00 0x00 0x00
# 0x03 0x45 0x08 0x02 0x00 0x00 0x00 0x00
# 0x03 0x4a 0x00 0x21 0x00 0x00 0x00 0x00
# 0x01 0x02 0x00 0x00 0x00 0x00 0x00 0x00
# 0x01 0x45 0x00 0x00 0x00 0x00 0x00 0x00
# 0x04 0x08 R M17 4160 2 All Units Off 0x00 0x00
# 0x01 0x23 0x00 0x00 0x00 0x00 0x00 0x00
#
# 9.  X 10 Byte Received (0x4A)
#     This Serial Command requires a SALad application such as the SALad coreApp
#     Program to be running. After IBIOS fires an EVNT_XRX_MSG (0x08) or
#     EVNT_XRX_XMSG (0x09) (see IBIOS Event Details), The SALad app will report
#     the received X10 byte by sending this Serial Command.
#     The byte following the 0x4A command number tells whether the received X10
#     byte is an X10 Address (the byte is 0x00) or X10 Command (the byte is 0x01).
#     If you are receiving an X10 Extended Message, then this byte is irrelevant.
#     See IBIOS X10 Signaling for more information.
#
# X10 Byte | R: 0x02 0x4A 0x00 (X10 Address) <X10 Byte>
# Received |    0x02 0x4A 0x01 (X10 Command) <X10 Byte>
#
#
# Send X10
# Summary
#     In this example we will send X10 A1/AON over the powerline using a PLC and IBIOS
#     Serial Commands. First we will download the A1 X10 address into the X10 transmit
#     buffer. Then we will set the Request-to-Send X10 bit and clear the
#     Command/Address bit of the X10 Flags register with a Mask (0x46) IBIOS Serial
#     Command. Then we will download the AON X10 command into the X10 transmit
#     buffer, followed by setting both the Request-to-Send X10 and the Command/Address
#     bits with another Mask (0x46) command.
#     See IBIOS X10 Signaling for more information.
# Procedure
#     1. Use the Download (0x40) IBIOS Serial Command from the IBIOS Serial
#         Command Summary Table to load an X10 A1 address (0x66) into the X10
#         transmit buffer X10_TX at 0x0165 (see Flat Memory Map) by sending:
#             0x02 0x40 0x01 0x65 0x00 0x01 0xFF 0x33 0x66,
#         then check for the ASCII 0x06 (ACK) at the end of the echoed response:
#             0x02 0x40 0x01 0x65 0x00 0x01 0x06.
#     2. Use the Mask (0x46) IBIOS Serial Command to set the _X10_RTS flag (bit 7)
#         and clear the _X10_TXCOMMAND flag (bit 3) in the X10_FLAGS register at
#         0x0166 (see Flat Memory Map) via:
#             0x02 0x46 0x01 0x66 0x80 0xF7,
#         then check for the ASCII 0x06 (ACK) at the end of the echoed response:
#             0x02 0x46 0x01 0x66 0x80 0xF7 0x06.
#     3. The PLC will now send an A1 X10 address over the powerline.
#     4. As in Step 1, load an X10 AON command (0x62) into the X10 transmit buffer by
#         sending:
#             0x02 0x40 0x01 0x65 0x00 0x01 0xff 0x37 0x62,
#         and check for an appropriate response:
#             0x02 0x40 0x01 0x65 0x00 0x01 0x06.
#     5. As in Step 2, use the Mask command to set the _X10_RTS bit and set the
#         _X10_TXCOMMAND bit via:
#             0x02 0x46 0x01 0x66 0x88 0xff
#         then check for an appropriate response:
#             0x02 0x46 0x01 0x66 0x88 0xFF 0x06.
# 
# Send A1AON
#               STX  Dnld <--addr-> <Length-> <Chksum-> <A1>                                        
# X10 Byte | S: 0x02 0x40 0x01 0x65 0x00 0x01 0xFF 0x33 0x66 | R: 0x02 0x40 0x01 0x65 0x00 0x01 0x06
# Sent     | S: 0x02 0x46 0x01 0x66 0x80 0xF7                | R: 0x02 0x46 0x01 0x66 0x80 0xF7 0x06
#               STX  Dnld <--addr-> <Length-> <Chksum-> <AOn>     STX  Dnld <--addr-> <--Data-> ACK (a 0x15 is a NAK)
#          | S: 0x02 0x40 0x01 0x65 0x00 0x01 0xff 0x37 0x62 | R: 0x02 0x40 0x01 0x65 0x00 0x01 0x06
#          | S: 0x02 0x46 0x01 0x66 0x88 0xff                | R: 0x02 0x46 0x01 0x66 0x88 0xFF 0x06
#
# A1AON = 66 62 or 'A' = 6
#                  '1' = 6
#                  'A' = 6
#                  'On' = 2
#
my %table_hcodes  = qw(A  0110 B  1110 C  0010 D  1010
		       E  0001 F  1001 G  0101 H  1101
                       I  0111 J  1111 K  0011 L  1011
		       M  0000 N  1000 O  0100 P  1100);

my %table_dcodes  = qw(1  0110 2  1110 3  0010 4  1010
		       5  0001 6  1001 7  0101 8  1101
                       9  0111 10 1111 11 0011 12 1011
		       13 0000 14 1000 15 0100 16 1100
                               A  1111 B  0011 C  1011
		       D  0000 E  1000 F  0100 G  1100);

my %table_fcodes  = qw(J 0010  K 0011  M 0100  L 0101  O 0001  P 0000
                       ALL_OFF 0000
		       ALL_ON  0001
		       ON      0010
		       OFF     0011
		       DIM     0100
		       BRIGHT  0101
                       -10 0100 -20 0100 -30 0100 -40 0100
                       -15 0100 -25 0100 -35 0100 -45 0100
		       -5  0100 -50 0100 -60 0100 -70 0100
		       -80 0100 -90 0100 -55 0100 -65 0100
		       -75 0100 -85 0100 -95 0100 -100 0100
                       +10 0101 +20 0101 +30 0101 +40 0101
                       +15 0101 +25 0101 +35 0101 +45 0101
		       +5  0101 +50 0101 +60 0101 +70 0101
		       +80 0101 +90 0101 +55 0101 +65 0101
		       +75 0101 +85 0101 +95 0101 +100 0101
                       ALL_LIGHTS_OFF 0110
		       EXTENDED_CODE  0111
		       HAIL_REQUEST   1000
		       HAIL_ACK       1001
                       PRESET_DIM1    1010
		       PRESET_DIM2    1011
		       EXTENDED_DATA  1100
                       STATUS_ON      1101
		       STATUS_OFF     1110
		       STATUS         1111);

# 10. INSTEON Message Received (0x4F)
#     This Serial Command requires a SALad application such as the SALad coreApp
#     Program to be running. After IBIOS fires any of the events 0x01 through 0x07
#     (see IBIOS Event Details), The SALad app will report the INSTEON message
#     received by sending this Serial Command.
#     To determine if the INSTEON message's length is 9 bytes (Standard) or 23 bytes
#     (Extended), inspect the message's Extended Message Flag.
#
# ============================================================================

                       # These tables are used in receiving data
my %table_hcodes2 = qw(0110 A  1110 B  0010 C  1010 D
		       0001 E  1001 F  0101 G  1101 H
                       0111 I  1111 J  0011 K  1011 L
		       0000 M  1000 N  0100 O  1100 P);
my %table_dcodes2 = qw(0110 1  1110 2  0010 3  1010 4
		       0001 5  1001 6  0101 7  1101 8
                       0111 9  1111 A  0011 B  1011 C
		       0000 D  1000 E  0100 F  1100 G);
                       # Yikes!  L and M are swapped!   If we fix it here, we also
                       # have to fix it elsewhere (maybe only in bin/mh, $f_code test)
my %table_fcodes2 = qw(0010 J  0011 K  0100 L  0101 M
		       0001 O  0000 P  0111 Z
		       1010 PRESET_DIM1
		       1011 PRESET_DIM2
                       1101 STATUS_ON
		       1110 STATUS_OFF
		       1111 STATUS
                       0000 ALL_OFF 
		       0001 ALL_ON 
                       0110 ALL_LIGHTS_OFF 
		       0111 EXTENDED_CODE 
		       1000 HAIL_REQUEST 
		       1001 HAIL_ACK 
                       1010 PRESET_DIM1 
		       1011 PRESET_DIM2 
		       1100 EXTENDED_DATA 
                       1101 STATUS_ON 
		       1110 STATUS_OFF 
		       1111 STATUS 
);

# ============================================================================

sub lprint_log {
    my $data = "@_";

    print localtime() . " " . $data . "\n";
}

# ============================================================================
# Data comes in as a string A1 or AJ
# ============================================================================
# Return 2 byte string & if it's a address (0) or a function (1)
sub format_data {
    my ($house_code) = @_;

    if (exists $main::Debug{iplcs}) {
        $DEBUG = ($main::Debug{iplcs} >= 1) ? 1 : 0;
    }
    print "\nIPLC send data=$house_code" if $DEBUG;

    my ($house, $code, $house_bits, $header, $code_bits, $function, $dim_level);
    my ($extended, $extended_string, $extended_checksum);

    #                          HC  UC  HC  Command with no error checking
    #($HC, $UC, $HC2, $KC) = /(\w)(\w)(\w)(.*)/i; # ignore case
    ($house, $code) = $house_code =~ /(\S)(\S+)/;
    $house = uc($house);
    $code  = uc($code);

    #printf "House = $house, Code = $code\n" if $DEBUG;

    unless ($house_bits = $table_hcodes{$house}) {
        print "\nIPLC error, invalid house code: $house. data=$house_code";
        return;
    }

    # $code can be
    #    1-9,A-G  for Device code
    #    d_xyz.   for Extended code xyz for device d
    #    xyz      for Function codes, including +-## for bright/dim

    if ($code_bits = $table_dcodes{$code}) {
        $function = '0';
        $extended = '0';
        $dim_level = 0;
        $Last_Dcode = $code;    # This is desperate :)
    }                           # Test for function code
    elsif ($code_bits = $table_fcodes{$code}) {

        $function = '1';
        $extended = '0';
        if ($code eq 'DIM' or $code eq 'M' or $code eq 'BRIGHT' or $code eq 'L') {
            $dim_level = 34;    # Lets default to 3 bright/dims to go full swing
        }
        elsif ($code =~ /^[+-]\d\d$/) {
            $dim_level = abs($code);
        }
        else {
            $dim_level = 0;
        }
    } else {
        print "\nIPLC error, invalid iplc x10 code: $code" if $DEBUG;
        return;
    }

    # ------------------------------------------------------------------------
    # OK here is where we put together the bits of information
    # ------------------------------------------------------------------------
    #my $dim = int($dim_level * 22 / 100);   # 22 levels = 100%
    #$header = substr(unpack('B8', pack('C', $dim)), 3);

    #$header .= '1';             # Bit 2 is always set to a 1 to ensure synchronization
    #$header .= $function;       # 0 for address,  1 for function
    #$header .= $extended;       # 0 for standard, 1 for extended transmission

                                # Convert from bit to string
    #my $b1 = pack('B8', $header);
    my $b2 = pack('B8', $house_bits . $code_bits);

                                # Calculate checksum
    #my $b1d = unpack('C', $b1);
    #my $b2d = unpack('C', $b2);
    #my $checksum = ($b1d + $b2d) & 0xff;

    #my $data = $b1 . $b2;

    $b2 = unpack('H*', $b2);
    printf("\nIPLC hb=$house_bits cb=$code_bits rtn = %s",  $b2) if $DEBUG;
    return $b2, $function;
}

sub swrite {
    my ($device, $data, $verbose) = @_;

    # this logic will seem to be a bit crazy. It's to support the calls
    # where I haven't added the verbose arguement
    if ($DEBUG) {
	if (defined($verbose) && $verbose != 1) {
	    $verbose = 0; # defined and IGNORE
	} else {
	    $verbose = 1; # $verbose not define or it's set to IGNORE
	}
    } else {
	$verbose = 0;
    }

    my $b   = pack('H*',$data);	# Convert from string to bin

    if($verbose) {
	my $l   = do { use bytes; length($b) }; # Get it's length
	printf("\nT = %s (%d)", unpack('H*', $b), $l);
    }
    $device->write($b);
    sread($device, $b, 9, $verbose)
}

sub nwrite {
    my ($device, $data, $verbose) = @_;

    # this logic will seem to be a bit crazy. It's to support the calls
    # where I haven't added the verbose arguement
    if ($DEBUG) {
	if (defined($verbose) && $verbose != 1) {
	    $verbose = 0; # defined and IGNORE
	} else {
	    $verbose = 1; # $verbose not define or it's set to IGNORE
	}
    } else {
	$verbose = 0;
    }

    my $b   = pack('H*',$data);	# Convert from string to bin

    if($verbose) {
	my $l   = do { use bytes; length($b) }; # Get it's length
	printf("\nt = %s (%d)", unpack('H*', $b), $l);
    }

    $device->write($b);
}

# =[ sread ]==================================================================

use constant STX => 0x02;
use constant OK  => 0x06;

# I'm really supposed to read in $n bytes but this is no where near that
sub sread {
    my ($device, $n, $verbose) = @_;

    my ($in, $c, $e, $buf, $tmp);
    my (@list, @buffer);

    # this logic will seem to be a bit crazy. It's to support the calls
    # where I haven't added the verbose arguement
    if ($DEBUG) {
	if (defined($verbose) && $verbose != 1) {
	    $verbose = 0; # defined and IGNORE
	} else {
	    $verbose = 1; # $verbose not define or it's set to IGNORE
	}
    } else {
	$verbose = 0;
    }

    # 2083us is the time it takes for 10 bits to be sent
    # 5000us is just a nice round number, a little less than 2 charater lengths
    usleep(5000); # Give the PLC time to process the request

    # The second nibble is the number of bytes (0 - 7)
    my $i = 10;
    $tmp = "";

    while($i) {
	#if($c = sysread($device, $buf, 8)) {
	#if($c = $device->read( $buf, $n )) {
	if($buf = $device->input) {
	    #$tmp = $tmp . $buf;
	    $in = unpack('H*', $buf);
	    #@list = unpack("A2" x 8, $in);
	    printf("\nR <= %s (%d)", $in, length($buf)) if $verbose;
	    return $buf, $in;
	}
	#printf(" (%d)", $c) if $verbose;
	usleep(5000);
	$i--;
    }
    print "\n" if $verbose;
    return ;
}

sub chksum {
    my($str, $byte) = @_;
    substr($str, 16, 2,) = $byte;

    my @c = split(/(\w.)/,$str);

    #print ">@c\n";
    shift @c; # Get rid of the STX
    shift @c; # Get rid of the empty string
    #print ">@c\n";
    shift @c; # Get rid of the CMD
    shift @c; # Get rid of the empty string
    #print ">@c\n";

    my $chksum = 0;
    for my $i ( @c ) {
	if($i) {
	    #printf "[$i] %x\n", hex($i);
	    $chksum = ( $chksum + hex($i) ) & 0xffff;
	    #printf " %02x - %04x\n", hex($i), $chksum;
	}
    }
    $chksum = (0xffff -($chksum)+1);

    #printf ">> %04x\n", $chksum & 0xffff;
    substr($str, 12, 4,) = sprintf("%04x", $chksum & 0xffff);

    return $str;
}

#
# How to handle 'flow control'
#
#  The flag you can check is the _I_Transmit flag (0x0142, bit 4) it
#  is the same flag you set to send an insteon message. The Salad
#  engine will clear the flag when it is ready to accept another
#  insteon message. Similarily, for X10 you can check the _X10_RTS
#  flag  (0x0166, bit 7). The 0x80 at 0x0142, bit 7 is a flag not
#  documented in the SDK since it is used by the salad engine
#  internally, but if you are curious, it is set when a unique
#  insteon acknowledge is received.
#

sub chkxbit {
    my ($device) = @_;

    my ($cmd, $in, $i, $c, $tmp);
    my (@buf);

    # Loop until it's OK to send
    # Ask for the byte at 0x0166
    # Send => 02 42 0166 0001
    $cmd = "024201660001"; #Send address
    nwrite($device, $cmd, IGNORE); # Write out the string (without read like swrite)

    # was 5000 but that seemed to cause problems
    usleep(500); # Give the PLC time to process the request (208.3 us / 10 bits)

    # Rcv: <= 02 42 0166 0001 <dd> <Sum Hi><Sum Lo> 06 read 0x0A bytes
    ($cmd, $in) = sread($device, 10, IGNORE);
    $c = length($cmd);

    if($c > 0) {
	#print "We have something to read $c\n" if $DEBUG;

	@buf = unpack('(C2)*', $cmd);
	#$in = unpack('H*', $cmd);
	#printf("r <= %s (0x%02x)\n", $in, $c) if $DEBUG;

	if($buf[0] == STX){
	    #printf("Got an STX\n") if $DEBUG;
	    # I should probably check the checksum
	    if($buf[9] == OK) {
		if(!($buf[6] & 0x80)) {
		    return 0; # Bit is clear
		}
		#usleep(2500); # Give the PLC time to process the request
	    }
	}
    }
    #print "\nWaiting to send X10";
    return 1; # Bit is set
}

# Send A1
#
# Send the packet to the Insteon and expect a reply back.
#               STX  Dnld <--addr-> <Length-> <Chksum-> <A1>                                        
# X10 Byte | S: 0x02 0x40 0x01 0x65 0x00 0x01 0xFF 0x33 0x66 | R: 0x02 0x40 0x01 0x65 0x00 0x01 0x06
# Sent     | S: 0x02 0x46 0x01 0x66 0x80 0xF7                | R: 0x02 0x46 0x01 0x66 0x80 0xF7 0x06
#
# What gets sent here depends on what is sent from Serial_Item.pm
# My understanding is that it's 'XA1' or 'XAJ' (address or command)
# I made the mistake of leaving it as XA1 (in Serial_Item.pm) so now I need to trim the X here

# ----------------------------------------------------------------------------
# This needs to be rewritten! With 2.12 the PLC now echo's every character
# sent (for pacing). Also is we send and expect a reply we need to get that
# ACK or NAK.
# ----------------------------------------------------------------------------
my $t0 = 0;

sub send {
    my ($checksum, $cmd, $i, $x);
    my ($serial_port, $house_code) = @_;


    # Temporary, this just catches non-X10 commands for now
    if(uc $house_code =~ /^XZ./) {
	lprint_log("Not X10 command $house_code (" . $i . ")");
	return 1; # Yeah it's not an error (yet)
    }

    lprint_log("IPLCS Send start $house_code(" . $i . ")");

    if (exists $main::Debug{iplcs}) {
        $DEBUG = ($main::Debug{iplcs} >= 1) ? 1 : 0;
    }

=begin comment
    # OK this needs work but this is what I want to do.
    if(isInsteon()) {
	send_Insteon();
    } else {
	send_X10();
    }
=cut
    #my ($tleft, $t1) =  gettimeofday; # $t1 is what I'm interested in, $tleft is just a dummy here

    #$tleft = $t1 - $t0;
    #if($tleft < 50000) { # It takes 1/2 a second for X10 commands to transmit
    #   usleep($tleft);  # so wait here.
    #}

    $i = 0;
    # Wait for the X10 bit to clear (means the PLC is done sending X10)
    lprint_log("Start chkxbit");
    while(($x = chkxbit($serial_port)) && ($i < 100000)) { $i++; usleep(1000); } #;
    lprint_log("Finish chkxbit");

    # I made the mistake of leaving it as XA1 so not I need to trim the X
    $house_code = substr($house_code, 1);

    # OK this is a bit confusing, I asked on the mail list what get sent here with
    # a set $Garage on;
    # I was told it was A1AJ (or possibly A1AOn)
    # It really looks like it A1 or AJ (each sent separately)
    # So it's just House and a Code, where code is either a Unit code or
    # Function code

    # return the formated data and $key = 0 for HU (Address) $key = 1 for $HF (Function)
    my ($data_snd, $key) = &format_data($house_code);
    return unless $data_snd;

    if($DEBUG) {
	my $str = ($key?"Function":"Address");
	printf( "\nIPLCS $str send:0x%02x", $data_snd);
    }

    # ------------------------------------------------------------------------
    # pack('H2',"46016680F7") converts the string 46 to binary, ASCII F (0x46)
    # pack('H*',"46016680F7") converts the string to binary
    #                         like a string to a serial port
    # unpack('H*', $l) converts a binary sequence (like that from a serial
    #                  port) to a string
    # ------------------------------------------------------------------------
    $cmd = "024001650001000000";
    $cmd = chksum($cmd, $data_snd);
    swrite($serial_port, $cmd);

    # we should check for a proper ACK and retransmit as necessary
    # but what can I do with it here? I'll work on that later.
    sread($serial_port, 9);

    if($key) {
	# If true it's a function such as on or off
	#          | S: 0x02 0x46 0x01 0x66 0x88 0xff                | R: 0x02 0x46 0x01 0x66 0x88 0xFF 0x06
	$cmd = "0246016688ff"; # Send command
    } else {
	# If false it's and X10 address such as A1
        # Sent     | S: 0x02 0x46 0x01 0x66 0x80 0xF7                | R: 0x02 0x46 0x01 0x66 0x80 0xF7 0x06
	$cmd = "0246016680f7"; #Send address
    }
    swrite($serial_port, $cmd);
    # we should check for a proper ACK and retransmit as necessary
    # but what can I do with it here? I'll work on that.
    sread($serial_port, 9);

    lprint_log("IPLCS Send finish");

    return 1;
}

# Use when commands are X10 commands
sub send_X10 {
}

# Use when commands are Insteon commands
sub send_Insteon {
}

sub dim_level_decode {
    my ($code) = @_;

    my %table_hcodes = qw(A 0110  B 1110  C 0010  D 1010  E 0001  F 1001  G 0101  H 1101
                          I 0111  J 1111  K 0011  L 1011  M 0000  N 1000  O 0100  P 1100);
    my %table_dcodes = qw(1 0110  2 1110  3 0010  4 1010  5 0001  6 1001  7 0101  8 1101
                          9 0111 10 1111 11 0011 12 1011 13 0000 14 1000 15 0100 16 1100
                          A 1111  B 0011  C 1011  D 0000  E 1000  F 0100  G 1100);


                                # Convert bit string to decimal
    my $level_b = $table_hcodes{substr($code, 0, 1)} . $table_dcodes{substr($code, 1, 1)};
    my $level_d = unpack('C', pack('B8', $level_b));
                                # Varies from 36 to 201, by 11, then to 210 as a max.
                                # 16 different values.  Round to nearest 5%, max of 95.
    my $level_p = int(100 * $level_d / 211); # Do not allow 100% ... not a valid state?
    ## print "IPLCS debug1: levelb=$level_b level_p=$level_p\n" if $DEBUG;
    $level_p = $level_p - ($level_p % 5);
    print "\nIPLCS debug: dim_code=$code leveld=$level_d level_p=$level_p" if $DEBUG;
    return $level_p;
}

return 1;           # for require
__END__

=pod

=head1 NAME

iplcs - Perl extension for Smarthome Serial PowerLinc V2 controller

=head1 SYNOPSIS

  use iplcs;

=head1 DESCRIPTION

The Serial PowerLinc V2 is a bi-directional Insteon and X10 controller
that connects to a serial port and transmits commands via AC power
line to Insteon and X10 devices. This module translates human-readable
commands (eg. 'A2', 'AJ') into the Interface Communication Protocol
accepted by the PowerLinc V2.

=over 4

=item send command

=head1 COPYRIGHT

Copyright (C) 2005 Neil Cherry. All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. December 5 2005

=cut

=begin comment

12/22/05 09:24:19 AM XA3: xA3 manual
  serial name=iplcs type= data2=
EJc
---
iplcs Chk: (024508024a0163)
Event 08024a0163
iplcs Chk: (024a0163)
X10 Command A K XAK (3)
State = XAK
12/22/05 09:24:19 AM XA3AK: xA3 off
12/22/05 09:24:19 AM XA3AK:  XA3AK

##############################################################################

12/22/05 09:24:20 AM Using iplcs to send: XO1

t = 024201660001 (6)
R <= 0242016600011cff7c06 (10)
Clear to send X10 (0x1c)
IPLC send data=O1
IPLC hb=0100 cb=0110 rtn = 46
IPLCS Address send:0x2e
T = 024001650001ff5346 (9)
R <= 02400165000106 (7)

T = 0246016680f7 (6)
R <= 0246016680f706 (7)
12/22/05 09:24:20 AM Using iplcs to send: XOK

t = 024201660001 (6)
R <= 02420166000105ff9306 (10)
Clear to send X10 (0x05)
IPLC send data=OK
IPLC hb=0100 cb=0011 rtn = 43
IPLCS Function send:0x2b
T = 024001650001ff5643 (9)
R <= 02400165000106 (7)

T = 0246016688ff (6)
R <= 0246016688ff06 (7)

##############################################################################

12/22/05 09:24:20 AM Using iplcs to send: XO2

t = 024201660001 (6)
R <= 0242016600011dff7b06 (10)
Clear to send X10 (0x1d)
IPLC send data=O2
IPLC hb=0100 cb=1110 rtn = 4e
IPLCS Address send:0x04
T = 024001650001ff4b4e (9)
R <= 02400165000106 (7)

T = 0246016680f7 (6)
R <= 0246016680f706 (7)

# ----------------------------------------------------------------------------

12/22/05 09:24:20 AM Using iplcs to send: XOK

t = 024201660001 (6)
R <= 02420101 (4)
Waiting to send X10
t = 024201660001 (6)
R <= 02420100580430510000000fc542 (14)
Waiting to send X10
t = 024201660001 (6)
R <= 00bcd0011d (5)
Waiting to send X10
t = 024201660001 (6)
R <= 040000454500900101000000 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0007ffff0002fd02fefe04 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 00008800700080401c000000 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 000000000000004c000000 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 000002200000000000000000 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 00000000003c3c0f400000 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 5201be050c1604071a0b4043 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 00634e94a8000000010000 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 00ffffff000c0200010178e7 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 805195a317780201005884 (11)
Waiting to send X10
t = 024201660001 (6)
R <= f6230000000fc53100080000 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 009500000000002047bc77 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 080000ab0000000000000000 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0000000000000000000000 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 000000000000000000000000 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0000000000000000000000 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 000000000000000000000000 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 000000000000bc26e8f00000 (12)
Waiting to send X10
t = 024201660001 (6)
R <= bce800bc00000001024201 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0001422424000c02000101f8 (12)
Waiting to send X10
t = 024201660001 (6)
R <= e7805195a327e15000ceb4 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 040029a300ffffffffffffff (12)
Waiting to send X10
t = 024201660001 (6)
R <= 02300434a1540664ffffff (11)
Waiting to send X10
t = 024201660001 (6)
R <= ffffffffffffffffffffffff (12)
Waiting to send X10
t = 024201660001 (6)
R <= ffffffffffffffffff03cc (11)
Waiting to send X10
t = 024201660001 (6)
R <= fe00005d0303ccfdf9002814 (12)
Waiting to send X10
t = 024201660001 (6)
R <= c8ff3b07c700ff11c7d0ff (11)
Waiting to send X10
t = 024201660001 (6)
R <= 3303e87db10007c407ff2901c8ff2401c7d0ff20c7007dabc401 (26)
Waiting to send X10
t = 024201660001 (6)
R <= ff (1)
Waiting to send X10
t = 024201660001 (6)
R <= 18010039008a008a008a008a (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0052008a007600bc00eb00 (11)
Waiting to send X10
t = 024201660001 (6)
R <= ef00f300fb01120116011a01 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 1e01260122004e002a0e03 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 45020000032b0312033e000a (12)
Waiting to send X10
t = 024201660001 (6)
R <= 022cfea0cf0050fd8e0e01 (11)
Waiting to send X10
t = 024201660001 (6)
R <= ab0e00e30e03da0e032b020e (12)
Waiting to send X10
t = 024201660001 (6)
R <= 032102ccfd7af91504c3fb (11)
Waiting to send X10
t = 024201660001 (6)
R <= d00302ccfd6ff90a18fee608 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 03ecfed9f900170103ecfe (11)
Waiting to send X10
t = 024201660001 (6)
R <= d1f8f80901050effe306cf00 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 50fd4fcb0005040e020c0c (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0004050effcf0e02e118f8de (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0a0e001a0e02d70e02d402 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0e00070e02cd0e02ca0204c3 (12)
Waiting to send X10
t = 024201660001 (6)
R <= fbd00c0e000a0104c3fbd0 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 1a0e000101010e02b3c702fd (12)
Waiting to send X10
t = 024201660001 (6)
R <= 27c74afd2405ccfe31fd20 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 14fe2f0ac701fd170e029a0c (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0007c7005611061515024201 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 66000194ff040602420166 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 000194ff04060242016600 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0194ff040602420166000194 (12)
Waiting to send X10
t = 024201660001 (6)
R <= ff040602420166000194ff04 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff0406 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 02420166000194ff04060242 (12)
Dang bit set to send X10 (0x94)
Waiting to send X10
t = 024201660001 (6)
R <= 0166000194ff0406024201 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 66000194ff04060242016600 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0194ff0406024201660001 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 94ff040602420166000194ff (12)
Waiting to send X10
t = 024201660001 (6)
R <= 040602420166000194ff04 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff04 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff04 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff04 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff (9)
Waiting to send X10
t = 024201660001 (6)
R <= 040602420166000105ff93 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff9306 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 02420166000105ff9306 (10)
Clear to send X10 (0x05)
IPLC send data=OK
IPLC hb=0100 cb=0011 rtn = 43
IPLCS Function send:0x2b
T = 024001650001ff5643 (9)
R <= 02420166000105ff93 (9)
R <= 0602400165000106 (8)
T = 0246016688ff (6)
R <= 0246016688ff06 (7)

##############################################################################

12/22/05 09:24:20 AM Using iplcs to send: XO3

t = 024201660001 (6)
R <= 0242016600011dff7b06 (10)
Clear to send X10 (0x1d)
IPLC send data=O3
IPLC hb=0100 cb=0010 rtn = 42
IPLCS Address send:0x2a
T = 024001650001ff5742 (9)
R <= 02400165000106 (7)

T = 0246016680f7 (6)
R <= 0246016680f706 (7)
12/22/05 09:24:20 AM Using iplcs to send: XOK

t = 024201660001 (6)
R <= 02 42 0166 0001 94 ff04 06 (10)
Dang bit set to send X10 (0x94)
Waiting to send X10

t = 024201660001 (6)
R <= 02420166 (4)
Waiting to send X10

t = 024201660001 (6)
R <= 02 42 9504 0000 0001000000ffffff (14) <- Yipes!
Waiting to send X10

t = 024201660001 (6)
R <= 00 (1)
Waiting to send X10
t = 024201660001 (6)
R <= 0c0280010178e7804395a308 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 340201005884f60300 (9)
Waiting to send X10
t = 024201660001 (6)
R <= 00000fc5310008000000 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 950000000000204702ff08 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0000ab000000000000000000 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0000000000000000000000 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 000000000000000000000000 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0000000000000000000000 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0000000000000000000000000000000000bc26e8f00000bce800 (26)
Waiting to send X10
t = 024201660001 (6)
R <= bc00000001024201660001101000 (14)
Waiting to send X10
t = 024201660001 (6)
R <= 0c (1)
Waiting to send X10
t = 024201660001 (6)
R <= 02800101f8e7804395a318 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 665000ceb4040029a300ffff (12)
Waiting to send X10
t = 024201660001 (6)
R <= ffffffffff02300434a154 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0664ffffffffffffffffffff (12)
Waiting to send X10
t = 024201660001 (6)
R <= ffffffffffffffffffffff (11)
Waiting to send X10
t = 024201660001 (6)
R <= ffffff03ccfe00005d0303cc (12)
Waiting to send X10
t = 024201660001 (6)
R <= fdf9002814c8ff3b07c700 (11)
Waiting to send X10
t = 024201660001 (6)
R <= ff11c7d0ff3303e87db10007 (12)
Waiting to send X10
t = 024201660001 (6)
R <= c407ff2901c8ff2401c7d0 (11)
Waiting to send X10
t = 024201660001 (6)
R <= ff20c7007dabc401ff180100 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 39008a008a008a008a0052 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 008a007600bc00eb00ef00f3 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 00fb01120116011a011e01 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 260122004e002a0e03450200 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 00032b0312033e000a022c (11)
Waiting to send X10
t = 024201660001 (6)
R <= fea0cf0050fd8e0e01ab0e00 (12)
Waiting to send X10
t = 024201660001 (6)
R <= e30e03da0e032b020e032102 (12)
Waiting to send X10
t = 024201660001 (6)
R <= ccfd7af91504c3fbd00302 (11)
Waiting to send X10
t = 024201660001 (6)
R <= ccfd6ff90a18fee60803ecfe (12)
Waiting to send X10
t = 024201660001 (6)
R <= d9f900170103ecfed1f8f8 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0901050effe306cf0050fd4f (12)
Waiting to send X10
t = 024201660001 (6)
R <= cb0005040e020c0c000405 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0effcf0e02e118f8de0a0e00 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 1a0e02d70e02d4020e0007 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0e02cd0e02ca0204c3fbd00c (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0e000a0104c3fbd01a0e00 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0101010e02b3c702fd27c74a (12)
Waiting to send X10
t = 024201660001 (6)
R <= fd2405ccfe31fd2014fe2f (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0ac701fd170e029a0c0007c7 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 00fd0d0e029004c3005004 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0e0288020e0284020e028c02 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 030d01090e027802030401 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 8780fe0407030915040c0004 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 030955020e0261020e025d (11)
Waiting to send X10
t = 024201660001 (6)
R <= 020e0259020e0255020e0251 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 020e024d020e02490205cf (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0050fc9f0efea5c400fdc34f (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0007fc93038f016000b550 (11)
Waiting to send X10
t = 024201660001 (6)
R <= ce0602420166000194ff0406 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 02420166000194ff040602 (11)
Dang bit set to send X10 (0x94)
Waiting to send X10
t = 024201660001 (6)
R <= 420166000194ff040602420166000194ff040602420166000194 (26)
Waiting to send X10
t = 024201660001 (6)
R <= ff04 (2)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff0406 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 02420166000194ff040602 (11)
Dang bit set to send X10 (0x94)
Waiting to send X10
t = 024201660001 (6)
R <= 420166000194ff0406024201 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 66000194ff040602420166 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 000194ff0406024201660001 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 94ff040602420166000194 (11)
Waiting to send X10
t = 024201660001 (6)
R <= ff040602420166000194ff04 (12)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff04 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff04 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff04 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff04 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff (9)
Waiting to send X10
t = 024201660001 (6)
R <= 040602420166000194ff (10)
Waiting to send X10
t = 024201660001 (6)
R <= 040602420166000194ff04 (11)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000194ff04 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000105ff93 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 0602420166000104ff94 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 06 02 42 0166 0001 04 ff94 (10)
Waiting to send X10
t = 024201660001 (6)
R <= 06 02420166000104ff9406 02 42 0166 0001 04 ff94 06 (21)
Waiting to send X10
t = 024201660001 (6)
R <= 02420166000104ff9406 (10)
Clear to send X10 (0x04)
IPLC send data=OK
IPLC hb=0100 cb=0011 rtn = 43
IPLCS Function send:0x2b
T = 024001650001ff5643 (9)
R <= 02400165000106 (7)

T = 0246016688ff (6)
R <= 0246016688ff06 (7)
12/22/05 09:24:20 AM Using iplcs to send: XO4

t = 024201660001 (6)
R <= 0242016600011dff7b06 (10)
Clear to send X10 (0x1d)
IPLC send data=O4
IPLC hb=0100 cb=1010 rtn = 4a
IPLCS Address send:0x04
T = 024001650001ff4f4a (9)
R <= 02400165000106 (7)

T = 0246016680f7 (6)
R <= 0246016680f706 (7)
12/22/05 09:24:20 AM Using iplcs to send: XOK

t = 024201660001 (6)
R <= 02420166000105ff9306 (10)
Clear to send X10 (0x05)
IPLC send data=OK
IPLC hb=0100 cb=0011 rtn = 43
IPLCS Function send:0x2b
T = 024001650001ff5643 (9)
R <= 02400165000106 (7)

T = 0246016688ff (6)
R <= 0246016688ff06 (7)
12/22/05 09:24:20 AM Using iplcs to send: XO5

t = 024201660001 (6)
R <= 0242016600011dff7b06 (10)
Clear to send X10 (0x1d)
IPLC send data=O5
IPLC hb=0100 cb=0001 rtn = 41
IPLCS Address send:0x29
T = 024001650001ff5841 (9)
R <= 02400165000106 (7)

T = 0246016680f7 (6)
R <= 0246016680f706 (7)
12/22/05 09:24:20 AM Using iplcs to send: XOK

t = 024201660001 (6)
R <= 02420166000105ff9306 (10)
Clear to send X10 (0x05)
IPLC send data=OK
IPLC hb=0100 cb=0011 rtn = 43
IPLCS Function send:0x2b
T = 024001650001ff5643 (9)
R <= 02400165000106 (7)

T = 0246016688ff (6)
R <= 0246016688ff06 (7)
12/22/05 09:24:20 AM mh paused for 7 seconds (volume=23)

=cut

#
# $Log: iplcs.pm,v $
# Revision 1.1  2006/01/30 00:08:28  winter
# *** empty log message ***
#
#
