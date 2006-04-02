=begin comment


--------------------------

Note:  This code is has been retired in favor of X10_W800.pm.
It may work ok, but most people have better luck with the X10_W800 module.


--------------------------




X10_W800RF.pm

Written by Ross Towbin
E-mail Address: MisterHome@RossTowbin.com

Revision updates are at the end of the file

This is code will read X10 data received by the RF W800RF receiver
from http://www.wgldesigns.com . The W800RF is similar to the W800
and MR26 in that it receives the RF signal transmitted by various
X-10 wireless devices.  The W800RF is said to have a better range.
Comparison is here: http://www.wgldesigns.com/comments.htm

Use these mh.ini parameters to enable this code (replace 'COM1' with
the actual Serial port that the W800RF is connected to):

W800RF_module = X10_W800RF
W800RF_port   = COM1

For 'normal X-10' devices, this will set the 'normal' X10_Item with the
	appropriate state.  The format includes:
	-> "X" + HouseCode + UnitID + HouseCode + StateCode
	-> "X" + HouseCode + StateCode
		Where HouseCode (a singlletter A-P) and UnitID (one or
		two digits 1-16) are set on the wireless device and StateCode
		is a one character code representing "On", "Off", "Dim", etc.
		that is transmitted by the device.

	Examples:
		MS13A Motion and Light Sensor set to "A1"
			sensed motion -> XA1AJ			(sets the code for A1-On)
			motion timer elaspsed -> XA1AK	(A1-Off)
			light sensed -> XA2AJ			(A2-On)
			darkness sensed -> XA2AK		(A2-Off)

			(the MS13A uses two adjacent unit codes)

For 'security' devices or for the RF TV Remote (UR51A)
	For RF TV Remote returns : "R" + (2-character TV Remote ID) + Remote Function
		TV Remote ID is belived to be the value 0x77 or 0xEE (but this is untested)
		Remote Funciton is the code for the button on the remote.
		See tv_codes for the mapping.


	For Security Devices returns : "R" + (2-character SecurityID) + StateCode
		StateCode is a 2-character code sent by the device
		that may  represent "Normal", "Alert", or "panic"

	The "R" prefix can be changed to something else, see "$NonX10Prefix.

	The SecurityID can be retrieved by using the rf32.exe program that came with
	the W800RF. Start rf32.exe, then cause the device to send it's code (some
	devices have a "test" button) The SecurityID will be the third byte displayed.
	So as an example, if rf32.exe displays: "20 DF 41 B1" then use "41" as the
	securityID".  The 2-character SecurityID is in Hex.

	The actual StateCode varies by the device itself and the state of
	the device.  Either use "trial-and-error" to determine the codes,
	or the "dataformat.txt" file that came with the W800RF software
	has a list of some devices' codes.  These codes are 2 characters and
	are in Hex.  Current observations have all of these listed only as
	digits (0-9), but there does not seem to be any reason why they
	could not be letters (A-F)

	If you have a wireless Door/Window Sensors such as the DW534,
	(with a Security ID of "36") this code will set the "36" device
	to "20" (which is that device's code for "alert") when the device
	is activated.

	Examples
		DW534 Door/Window Sensor set to SecurityID "36":
			door opened -> R3620  (RF device "36" set to 0x20, alert)
			door closed -> R3621  (RF device "36" set to 0x21, normal)
		SH624 Large Security Remote set to SecurityID "88":
			Panic -> R8844	(RF device "88" set to 0x44, panic)


Past this point you only need to read if you want a bedtime story :-)

	If the "R" is replaced with "X" (look for the code
	"$state = "R".$security_id . $function;" below), the security
	device MAY be treated by many routines like a normal X-10 device
	(like a two-way wall switch sending it's ON signal when pressed),
	but the format is different.  Even if the SecurityID had a first
	character as A-P and the second character was 1-9 (X-10 past 9 would
	be '10' while SecurityID would be '0' or 'A'), the StateCode would
	not look like an X-10 StateCode (the two characters would have to
	be letters, but the Security device's StateCodes are numbers). To
	keep this straight so there could not be any confusion, I selected
	a different leading character (arbitrarily "R" -- selected for
	"RF" -- instead of "X").

        The following TV Remotes only send RF for X-10 codes, not for
        "TV" commands: UR19A, UR47A, JR20A.  The "TV" commands are
        sent via IR, not RF.  The X-10 codes are "normal" X-10 codes.

Coding not yet done:
	* Values for other normal X-10 functions such as
		(All Lights Off), (Hail Request) (Extended Data)
	* Values for RF devices that send extended data

	If someone can e-mail me a copy of the results from the W800RF
	test tool (rf32.exe) marked with what the RF device did to cause
	the entry, then I can add these to the code.


Data format info is based on the W800RF documentation at
	http://www.wgldesigns.com/dataformat.txt The documented swapping of
	bytes 1&3 and Bytes2&4 as well as the bit reversal is done
	so the documentation matches what the code here does.

Data is received as a binary stream.  It is converted it to HEX to make it
	easier to display.

   Byte 1      Byte 2      Byte 3     Byte 4
  n1   n2     n1   n2     n1   n2     n1   n2
 0000.0000 - 0000.0000 : 0000.0000 - 0000.0000
 abcd.efgh - (see note): qrst.uvwx - ijkL.mnop

 Notes (1) using upper case "L" to distinguish it from "1" (one)
	 (2) for 'normal' X10, Byte 2 is the complement of Byte 1 AND Byte 4
		is the complemnt of Byte 3

 bit(s)	: Description
 -----	: --------------------------------------------------------------
 abc		: 000     	almost always this is the code for 'normal' X10
				(some security devices also send this)
 		: NOT 000	frequently used for 'extended RF' (see
				http://www.wgldesigns.com/dataformat.txt for samples)

(1) "NORMAL" X-10 DEVICE

abc=000
if 	(abc) = (000)  AND
	(BYTE 1 is COMPLEMENT OF BYTE 2) AND
	(BYTE 3 is COMPLEMENT OF BYTE 4)

	(the Byte3-Byte4 complement test is required to separate out X-10
	data from a security device sharing the same abc=000 pattern.)

Then data is from "NORMAL" X-10 device.  Here are the BIT Definitions for
	 the X-10 device:

uvwx		: HOUSE code using the 'normal' binary patterns for X-10
			i.e. 0000=M, 0110=A

 h		: UNIT / FUNCTION FLAG
	h=0 (defh) is used for a UNIT information
	h=1 (defh) are used for a FUNCTION

h=0 (UNIT MODE)
 d		: bit-1 of UNIT
 e		: bit-0 of UNIT
 f		: 0=ON, 1=OFF
 g		: bit-2 of UNIT (see bit 't') - for newer RF devices
		  appears to be 0 when 't' is set

 s		: bit 3 of UNIT

 qr		: unknown (always 00?)

 t		: bit-2 of UNIT (see bit 'g') - for older RF devices
		: appears to be 0 when 'g is set

	sgde : UNIT code for 'newer' devices (such as HR12A, KR19A, SS13A)
	stde : UNIT code for 'older' devices (such as RW694, RW724, DR10A, KC674)


h=1 (FUNCTION MODE)

s	: bit 3 of UNIT
		although the UNIT isn't passed in
		this is clear when the UNIT is 1-8
		and set when the UNIT is 9-16

defg	: Function
 	000 : All Units Off
	001 : unknown
	010 : All Lights On
      011 : unknown
	100 : Bright (unit 1-8)
	101 : Bright (unit 9-16)
	110 : Dim (unit 1-8)
	111 : Dim (unit 9-16)
	it is assumed that the following are used for the
	remaining 'undefined' values of (def) but I don't
	know the values
	    : All Lights Off
	    : Hail Request
	    : Hail Ack
	    : Preset DIM1
	    : Preset DIM2
	    : Status On
	    : Status Off
	    : Extended Code
	    : Extended Data

g	unknown (set to 0)
	This is probably the "high bit" for the remaining
	functions listed above.

qrt	unknown (set to 0)

(2) "SECURITY" DEVICE
if	(BYTE 1 is COMPLEMENT OF BYTE 2) AND
 	(BYTE 3 NIBBLE 1 is COMPLEMENT OF BYTE 4 NIBBLE 1)  AND
	(BYTE 3 NIBBLE 2 is THE SAME AS BYTE 4 NIBBLE 2)

[note that there's no mention about bits (abc) in determining
if this is a 'security device'.  Bits (abc)are part of the device
function (AKA status)]

Then data is from a "SECURITY" device (and here are the following BIT
	Definitions

qrst.uvwx	: Security Device ID code
		If you use the rf32.exe tool to match this to a physical device
		this appears as BYTE3 in the tool.

mnop		: complement of uvxy
ijkL		: same as qrst

abcdefgh	: device "function" (status) of device
		specifics vary by device but here are some examples:

		Note: you can't tell the device from the pattern alone there are
		many "shared" codes".  You need to look at the ID # and know
		that that ID # goes with a particular physical device then
		look at that device's possible functions.

		example #1 : (DW534) and (30002) (see a few lines below) have the
			same pattern (of course, that's because they're internally
			the same transmitter, just designed with a different sensor)

		example #2 : (SH624) function [ARM AWAY (min)] is the same as
				 (KF574) function [ARM]

		DW534 Window/Door Sensor
			0000.0000 (00h)	DW534 : Alert (MAX)
			0000.0001 (01h)	DW534 : Normal (MAX)
			0010.0000 (20h)	DW534 : Alert (MIN)
			0010.0001 (21h)	DW534 : Normal (MIN)

		30001/30002/30003 Garage Door Status Module/Transmitter/Indicator
		(same as DW534 above, but uses a 'motion switch' instead of a
		'magnet' switch)
			0010.0000 (20h)	30002 : Alert
			0010.0001 (21h)	30002 : Normal

		DS10A NEW Window/Door Sensor (need to verify model #)
			0011.0000 (30h)	DS10A : Alert
			0011.0001 (31h)	DS10A : Normal

		KF574 Pendant
			0110.0000 (60h)	KF574 : Arm Away
			0110.0001 (61h)	KF574 : Disarm
			0110.0010 (62h)	KF574 : Lights On
			0110.0011 (63h)	KF574 : Lights Off

		SH624 Large Security Remote
			0111.0000 (70h)	SH624 : Arm Home (min)
			0110.0000 (60h)	SH624 : Arm Away (min)
			0101.0000 (50h)	SH624 : Arm Home(max)
			0100.0000 (40h)	SH624 : Arm Away (max)
			0100.0001 (41h)	SH624 : Disarm
			0100.0010 (42h)	SH624 : Sec Light On
			0100.0011 (43h)	SH624 : Sec Light Off
			0100.0100 (44h)	SH624 : Panic

		Other Security Devices
			let me know the patterns :-)

(3) OTHER DEVICE
All other situations

	The UR51A Universal Remote would probably fall here, but
	my UR51A is no longer functioning, so I can't test it.

	I assume this follows the same format that the security
	devices above are in. Based on the code in "X10_MR26.pm"
	the value of (qrst.uvwx) may be "EE", but I'm not sure.
	The "function" values are probably thoses listed in
	%vcodes (see X10_MR26.pm).  If someone has both the W800RF
	and UR51A can confirm this, I'll add the appropriate values
to this routine.

unknown bit definitions
let me know what falls in this category

=cut

use strict;

package X10_W800RF;

@X10_W800RF::ISA = ('Generic_Item');

sub startup {

&::print_log ("In W800RF (Startup)\n") if $main::Debug{w800};

   &main::serial_port_create('W800RF', $main::config_parms{W800RF_port}, 4800, 'none', 'raw');

                                # Add hook only if serial port was created ok
   &::MainLoop_pre_add_hook(  \&X10_W800RF::check_for_data, 1 ) if $main::Serial_Ports{W800RF}{object};
   &main::print_log ("W800RF adding X10_W800RF-check_for_data into pre_add_hook\n") if $main::Serial_Ports{W800RF}{object};
}

# Reverse the bits (source is in Hex)
my %hex_bit_reversal  = qw(0 0  1 8  2 4  3 C  4 2  5 A  6 6  7 E  8 1  9 9  A 5  B D  C 3  D B  E 7  F F  a 5  b D  c 3  d B  e 7  f F);

# Hex to Decimal conversion
my %hex_to_decimal  = qw(0 0  1 1  2 2  3 3  4 4  5 5  6 6  7 7  8 8  9 9  A 10  B 11  C 12  D 13  E 14  F 15  a 10  b 11  c 12  d 13  e 14  f 15);

# Decimal to Hex conversion
my %decimal_to_hex  = qw(0 0  1 1  2 2  3 3  4 4  5 5  6 6  7 7  8 8  9 9  10 A  11 B  12 C  13 D  14 E  15 F  16 G);

# Bit reversal (reverse the bits - 1100 becomes 0011
#my %hex_negation  = qw(0 F 1 E 2 D 3 C 4 B 5 A 6 9 7 8 8 7 9 6 A 5 B 4 C 3 D 2 E 1 F 0 a 5 b 4 c 3 d 2 e 1 f 0);

# House Codes "standard binary X-10 mapping"
my %house_codes  = qw(6 A E B 2 C A D   1 E 9 F 5 G D H   7 I F J 3 K B L   0 M 8 N 4 O C P );

# Command Codes (0=On/J,  1=Off/K)
my %command_codes  = qw(0 J 1 K);

# Additional Command Codes
# L = BRIGHT, M  = DIM,  (N=?) O = ALL_ON (All Units On), P = ALL_OFF (All Units Off,  Z = Extended Data)
# 	Extended Command Codes (not yet added)
# 	ALL_LIGHTS_OFF, EXTENDED_CODE, EXTENDED_DATA, HAIL_REQUEST
# 	HAIL_ACK, PRESET_DIM1, PRESET_DIM2, STATUS_ON, STATUS_OFF, STATUS
my %function_codes  = qw(1 P  5 O  9 L  13 M);
#my %function_codes  = qw(1 P  5 O  9 +20  13 -20);

#
# 2003-Jun-04 : This array was changed, based on comments from Bill Young <spamhole@cox.net>
#
my %security_codes = qw(00 Sensor:OpenMax     01 Sensor:ClosedMax 20 Sensor:OpenMin
				21 Sensor:ClosedMin   30 Sensor:Open      31 Sensor:Closed
				40 System:ArmAwayMin  41 System:Disarm    42 Control:LightsOn
				43 Control:LightsOff  44 System:Panic     50 System:ArmHomeMax
				60 System:ArmAwayMin  61 System:Disarm    62 Control:LightsOn
				63 Control:LightsOff  64 System:Panic     70 System:ArmHomeMin);

# UR51A Function codes:
#  - OK and Ent are same, PC and Subtitle are same,
#  - Chan buttons and Skip buttons are same
my %tv_codes = qw(0F Power	2B PC		6B Title	5C Display	4A Enter	1B Return
			AB Up		CB Down	4B Left	8B Right	6D Menu	93 Exit
			1C Rew	0D Play	1D FF		FF Record	0E Stop	4E Pause
			4F Recall	41 1		42 2		43 3		44 4		45 5
			46 6		47 7		48 8		49 9		5D AB		40 0
			02 Ch+	03 Ch-	07 Vol-	06 Vol+	05 Mute);

# when sent back to MisterHouse, a 'normal' X-10 code has
# the previx of "X".  This is the Prefix used for non-X10 codes
# such as a security device (or a TV remote such as the UR51A)
my $NonX10Prefix = "R";

my ($prev_data, $prev_time, $prev_loop, $prev_done);
$prev_data = $prev_time = $prev_done = 0;

sub check_for_data {
	my ($self) = @_;

	# used to hold 'progress text', useful for debugging
	my ($outputtext) = "W800RF";

	&main::check_for_generic_serial_data('W800RF');
	return unless $main::Serial_Ports{W800RF}{data};

	#
	# Data comes 4 bytes at a time (no break character)
	#
	# $data (and $remainder) are in binary format, so we don't really want to
	# be displaying it if we can help it.
	#
	my ($data, $remainder) = $main::Serial_Ports{W800RF}{data} =~ /(....)(.*)/;
	return unless $data;

	$main::Serial_Ports{W800RF}{data} = $remainder;

	# Data often gets sent multiple times
	#  - check time and loop count.  If mh paused (e.g. sending ir data)
	#    then we better also check loop count.
	my $time = &main::get_tickcount;

# Some users have experienced a duplication of transmissions.  Here are two
# solutions that may help:
# (1)  Per "Scott Reston" <scott@therestons.com> Wed, 04 Jun 2003 22:07:54 -0400
#       increase the x10_multireceive_delay value (mh.*.ini) to 5000
#(2) Per Bill Young <spamhole@cox.net> Sat, 07 Jun 2003 09:40:10 -0700
# 	Increase the tickcount delay from 600 to 1500 (and the loop count from 6 to 7)

#	return if $data eq $prev_data and ($time < $prev_time + 1500 or $main::Loop_Count < $prev_loop + 7);
##	return if $data eq $prev_data and ($time < $prev_time + 600 or $main::Loop_Count < $prev_loop + 6);
#	$prev_data = $data;
#	$prev_time = $time;
#	$prev_loop = $main::Loop_Count;

                                    # Process data only on the 2nd occurance
    my $repeat_time = $main::config_parms{W800_multireceive_delay} || 1500;
	my $repeat_data = ($data eq $prev_data) && ($time < $prev_time + $repeat_time or $main::Loop_Count < $prev_loop + 7);
	return if $repeat_data and $prev_done;
	$prev_data = $data;
	$prev_time = $time;
	$prev_loop = $main::Loop_Count;
	unless ($repeat_data) {     # UnSet flag and wait for 2nd occurance
	    $prev_done = 0;
	    return;
	}
	$prev_done = 1;             # Set flag and process data



#	&main::main::print_log("-------------\n)" if $main::Debug{w800};
#	&::respond("-------------") if $main::Debug{w800};

	my ($state, $state1, $state2, $errortext);
	my $hex = unpack "H*", $data;

	#
	# $hex is the "raw" data before the byte swapping and bit reversal is done.
	# unlike $data, $hex IS displayable
	#
	$outputtext .= " raw data: [$hex]";

	#
	# Break the data into individual nibbles
	#
	my ($b1o1, $b1o2, $b2o1, $b2o2, $b3o1, $b3o2, $b4o1, $b4o2);
	my ($b1h1, $b1h2, $b2h1, $b2h2, $b3h1, $b3h2, $b4h1, $b4h2);
	my ($b1d1, $b1d2, $b2d1, $b2d2, $b3d1, $b3d2, $b4d1, $b4d2);

	($b3o2, $b3o1,  $b4o2, $b4o1,  $b1o2, $b1o1, $b2o2, $b2o1) = $hex =~ /^(.)(.)(.)(.)(.)(.)(.)(.)$/;
	$b1h1 = $hex_bit_reversal{$b1o1};
	$b1h2 = $hex_bit_reversal{$b1o2};
	$b2h1 = $hex_bit_reversal{$b2o1};
	$b2h2 = $hex_bit_reversal{$b2o2};
	$b3h1 = $hex_bit_reversal{$b3o1};
	$b3h2 = $hex_bit_reversal{$b3o2};
	$b4h1 = $hex_bit_reversal{$b4o1};
	$b4h2 = $hex_bit_reversal{$b4o2};

	my ($output_hex) = $b1h1.$b1h2.":".$b2h1.$b2h2."-".$b3h1.$b3h2.":".$b4h1.$b4h2;
	$outputtext .= " Hex [$output_hex]";

	$b1d1 = $hex_to_decimal{$b1h1};
	$b1d2 = $hex_to_decimal{$b1h2};
	$b2d1 = $hex_to_decimal{$b2h1};
	$b2d2 = $hex_to_decimal{$b2h2};
	$b3d1 = $hex_to_decimal{$b3h1};
	$b3d2 = $hex_to_decimal{$b3h2};
	$b4d1 = $hex_to_decimal{$b4h1};
	$b4d2 = $hex_to_decimal{$b4h2};

	my ($output_decimal) = $b1d1.".".$b1d2.":".$b2d1.".".$b2d2."-".$b3d1.".".$b3d2.":".$b4d1.".".$b4d2;
#	$outputtext .= " Decimal [$output_decimal]";

	#
	# $output_hex and $output_decimal are the displayable byte swapped and bit reversed data.
	#

# the $b(#)h(#) variables hold the HEX value (acutally text, can display this)
# the $b(#)d(#) variables hold the decimal value (a number, can do math on this)
#	The first (#) is the byte number (1-based)
#	The second (#) is the nibble number (1-based)


	if ( !($b3o2, $b3o1,  $b4o2, $b4o1,  $b1o2, $b1o1, $b2o2, $b2o1))  {
		# at least one if the original 8 nibbles did not have any data
		# Since the nibbles are actually in 'text' (not numeric) format
		# we _should_ only get here if we didn't read one or more bytes
		# (actually 'nibble') of data.
		#
		# we didn't get values each of the 4 bytes

		$outputtext .= " UNPARSED RF SIGNAL";
		$state = "ZZZZ";	# arbitrary code

		# THIS CODE WAS TAKEN FROM THE ORIGINAL "X10_W800.PM" CODE
		# reset the buffer, in case it is not 4 bytes of data
		# Extended data may be > 4 bytes
		$main::Serial_Ports{W800RF}{data} = '';
	}
	else {
		my ($prefix_id) = ($b1d1 & 0xE);
		$outputtext .= " Prefix(abc)=($prefix_id)";

		# Prefix is bits (abc)
		my ($nibble1_complement) = $b3d1==$b4d1;
		my ($nibble2_complement) = $b3d2==$b4d2;
# &::respond(" * Nibble1_C=($nibble1_complement) Nibble2_C=($nibble2_complement)");

		if ( (!$prefix_id) and (!$nibble1_complement) and (!$nibble2_complement)) {
# NORMAL X-10 RF SIGNAL
# house = bits 'uvwx'
			$outputtext .= " NORMAL X-10 RF";

			my $house = $house_codes{$b3h2};

			my $unit;
			if (($b3d1 & 0x1) == 1) {
				# older RF code -- bits (stde), assuming bit (g) = 0
				$outputtext .= " older RF";
				$unit  = (($b3d1 & 0x2) << 2) + (($b3d1 & 0x1) << 2) + (($b1d1 & 0x1) << 1)  + (($b1d2 & 0x8) >>3);
			} else {
				# newer RF code -- bits (sgde), assuming bit (t) = 0
				$outputtext .= " newer RF";
				$unit  = (($b3d1 & 0x2) << 2) + (($b1d2 & 0x2) << 1) + (($b1d1 & 0x1) << 1)  + (($b1d2 & 0x8) >>3);
			}

			$unit++;
			$unit = $decimal_to_hex{$unit};	 # 2003-June-04 : unit should be in hex, not decimal

			my ($Unit_Function_Flag) = ($b1d2 & 0x1);

                  # check the "UNIT/FUNCTION" flag
			if (!$Unit_Function_Flag) {
# have UNIT code (ON, OFF)
				$state1 = ($b1d2 & 0x4) >> 2;
				$state2 = $command_codes{$state1};

				if (!$state2) {
					$errortext = " COMMAND CODE #($state1) NOT FOUND : HOUSE=($house) UNIT=($unit) DATA=($output_hex)";
#					&main::main::print_log("$errortext\n") if $main::Debug{w800};
				}

				$state = "X".$house.$unit.$house.$state2;

				$outputtext .= " [UNIT] : HOUSE=($house) UNIT=($unit) STATE=($state2) STATE1=($state1)";
			} # !Function_Flag

			else {
# have FUNCTION code (BRIGHT, DIM, ALL_LIGHTS_ON, ALL_UNITS_OFF)
				# for most of these qrst = 000 : (f) is flag to 'look at (qrst)'
				#           d (shifted to "a")     e (shifted to "b")     f (shifted to "c")     h (shifted to "d")
				#
	                  $state1 = (($b1d1 & 0x1) << 3) + (($b1d2 & 0x8) >> 1) + (($b1d2 & 0x4) >> 1) + (($b1d2 & 0x1) >> 0);
				$state2 = $function_codes{$state1};

				if (!$state2) {
					$errortext = " FUNCTION CODE #($state1) NOT FOUND : HOUSE=($house) DATA=($output_hex)";
#					&main::main::print_log("$errortext\n") if $main::Debug{w800};
				}

				# not that it should matter, but for DIM,
				# bit (s) is clear for UNITS 1-8 and set for UNITS 9-15
				# bits (qr and t) are unknown
				$state = "X".$house.$state2;

				$outputtext .= " [FUNCTION] : HOUSE=($house) FUNCTION=($unit) STATE=($state2) STATE1=($state1)";

                        if ($state2 eq "Z") {
# EXTENDED DATA

# THIS EXTENDED DATA SECTION IS NOT TESTED
#
# This code probably doesn't work correctly
# 1. it needs to "eat" the bytes that we use as extended data
#	so they're not used in the next pass through the code
# 2. it needs to send the "right" number of bytes back -- how is this determined?
#	how can we handle multiple length values for different devices?
#
					$outputtext .= " **EXTENDED DATA**";

                        	# Process the Extended Data
					my $hex2 = unpack "H*", $remainder;
					$outputtext .= " EXT-Raw-Hex: [$hex2]";

					if ( my ($x1o1, $x1o2,  $x2o1, $x2o2,  $x3o1, $x3o2, $x4o1, $x4o2) = $hex2 =~ /^(.)(.)(.)(.)(.)(.)(.)(.)$/)  {
					# which & how many nibbles should we be grabbing?

						# make the values printable
                                    $x1o1 = $hex_to_decimal{$hex_bit_reversal{$x1o1}};
                                    $x1o2 = $hex_to_decimal{$hex_bit_reversal{$x1o2}};
                                    $x2o1 = $hex_to_decimal{$hex_bit_reversal{$x2o1}};
                                    $x2o2 = $hex_to_decimal{$hex_bit_reversal{$x2o2}};
                                    $x3o1 = $hex_to_decimal{$hex_bit_reversal{$x3o1}};
                                    $x3o2 = $hex_to_decimal{$hex_bit_reversal{$x3o2}};
                                    $x4o1 = $hex_to_decimal{$hex_bit_reversal{$x4o1}};
                                    $x4o2 = $hex_to_decimal{$hex_bit_reversal{$x4o2}};

						$outputtext .= " EXT-Fixed-Hex=[".$x1o1.$x1o2.":".$x2o1.$x2o2."-".$x3o1.$x3o2.":".$x4o1.$x4o2."]";

                                    # append extended data to the "good data"
                                    $state .= $x1o1.$x1o2.$x2o1.$x2o2.$x3o1.$x3o2.$x4o1.$x4o2;

						$outputtext .= " EXT-State=($state)";
                                } # process extended bytes
				} # done with un-tested code

			} # else !Function_Flag

			&main::process_serial_data($state, undef, 'rf'); # Set states on X10_Items

			# Set state of all W800RF and X10_RF objects
			for my $name (&main::list_objects_by_type('X10_W800RF'), &main::list_objects_by_type('X10_RF_Receiver')) {
				my $object = &main::get_object_by_name($name);
				$object -> set($state);
			}

		} # done with 'normal' X-10

		elsif ((!$nibble1_complement) and ($nibble2_complement)) {
#
# We have a "special function" item.  These include:
#	* UR51A TV Remote
#	* Various Security Devices
#	* 30002 Garage Door Status Transmitter
#
			# TV Remote (UR51A) or  SECURITY RF SIGNAL

			my ($security_id) = $b3h1 . $b3h2;
			my ($function1, $function);

			$outputtext = " ID=($security_id) Fx=($function)";

			if ($security_id == 0xEE or $security_id == 0x77) {
				# The TV Remote "SecurityID" may be 77 or EE.  I'm not sure.
# TV Remote (UR51A)
# THIS CODE IS UN-TESTED
				$function1 = $b1h1;
				$function = $tv_codes{$function1};

				if (!$function) {
					$errortext = " TV REMOTE CODE #($function1) NOT FOUND : DATA=($output_hex)";
#					&main::main::print_log("$errortext\n") if $main::Debug{w800};
				}

				$outputtext .= " UR51A REMOTE ($function)";
				$state = $NonX10Prefix . $security_id . $function;

			} else { #not TV_remote, assume it's a security device
#Security Device
				$function1 = $b1h1 . $b1h2;

# OK -- here's a question : how should the security function be passed back?
# 	Option #1 : as text using an educated guess of the function (see 'security_codes')
#	Option #2 : as a 2-character code (the data in the first Byte) to be handled in later code

# For now selecting "Option #2"
#				$function = $security_codes{$function1};
				$function = $function1;

				if (!$function) {
					$errortext = " SECURITY CODE #($function1) NOT FOUND : DATA=($output_hex)";
				}

				$outputtext .= " SECURITY DEVICE ID#($security_id) FUNCTION=($function)";
				$state = $NonX10Prefix . $security_id . $function;
			} #if TV_remote / security device

			&main::process_serial_data($state, undef, 'rf'); # Set states on X10_Items

			# Set state of all W800RF and X10_RF objects
			for my $name (&main::list_objects_by_type('X10_W800RF')) {
#			for my $name (&main::list_objects_by_type('X10_W800RF'), &main::list_objects_by_type('X10_RF_Receiver')) {
				my $object = &main::get_object_by_name($name);
				$object -> set($state);
			} # for

		} # done with 'SECURITY DEVICE'

		else { # unknown device
			$outputtext .= " OTHER RF SIGNAL";
			$state = "XXXX";	# arbitrary code
		} # done with 'unknown device'

		$outputtext .= " RESULT=($state)";

	} # have data in all 8 nibbles

	&::print_log("$errortext\n") if $errortext;
	&::print_log("$outputtext\n") if $main::Debug{w800};
	&::respond($outputtext) if $main::Debug{w800};
}

############################################################################
#
# Notes:
#	1. The following is untested, but coded
#		(a) TV Remote
#		(b) Extended Data
#
#	2. The following is not coded
#		(a) X-10 Extended Functions such as "PRESET_DIM1" and "ALL_LIGHTS_OFF"
#			The appropriate information just needs to be filled out in
#			"%function_codes", but I don't know what the values are
#		(b) proper processing of Extended Data
#
#	3. The information that is passed back for "non X-10 devices"
#		(i.e. the "Security Devices") needs to be handled in additional
#		code elsewhere.
#
#		Bill Young <spamhole@cox.net> coded the security device in his
#		routines a little differently than I did.  This raises another good question:
#
#			How does the security "function" get passed back?
#
#		Bill selected to translate the "function" into text and pass back the text
#		I selected to pass the code-number (the first byte) back (in hex form)
#
#		My assumption was that different devices could have the same function code.
#		One such example is the DW534 and 30002 (Garage Door Status Transmitter)
#		(this is because they're the same device, but with different sensors)
#		The DW534 "senses" Open/Closed, while the 30002 "senses" Up/Down
#		(Yea, I know in this example it's a simple matter of semantics).
#
#		I was assuming a routine would be written for each security device and that
#		routine would "decode" it's own meaning of the code-number.
#
#		For now, I'll leave the code as returning a two-character value, and leave
#		the "text" translation (i.e. Bill's code) commented out.  Based on other
#		user's comments I don't have a problem changing this.
#
#		If text or a code is passed back, either way there needs to be additional
#		code to processes the value.  Any of the MH 'default' routines may not have
#		a clue how to handle the returned values because they don't start with
#		"X", but with "R" instead.
#
#	4. There seems to be a problem with DIM/BRIGHT.
#
#	5. Some users have experienced a duplication of transmitted codes. Two suggestions
#	   have been made:
#		a) per "Scott Reston" <scott@therestons.com> 2003-June-04, increase
#		   x10_multireceive_delay (in mh.ini / mh.private.ini) to 5000
#		b) per "Bill Young" <spamhole@cox.net> 2003-June-07,
#		   in this (and X10_W800.pm) module increase the tickcount delay
#		   from 600 to 1500 and the loop counter from 6 to 7.
#
# Revision History:
#
# 2003-June-18 - Updates bsaed on user feedback
#
#	1. Some users have experienced a duplication of transmissions.
#		I incorporated the comments from (Bill Young <spamhole@cox.net>
#		Sat, 07 Jun 2003 09:40:10 -0700).
#
#	2. from (Robert Mann <mh@easyway.com> 8 Jun 2003 15:53:58 -0700)
#	Fixed typo in "my %house_codes  =" ("f" should be "F")
#
# 2003-June-04 - Various updates based upon user feedback
#
#	1. From Bill Young <spamhole@cox.net>
#	the 'g' and 't' bits are better handled. Now both "new" and
#	"old" RF devices are handled correctly.
#	This has been tested on:
#		'newer' RF devices: HR12A, KR19A, SS13A
#		'older' RF devices: RW694, RW724, DR10A, KC674
#
#	2. Added better code to handle the TV Remote (UR51A)
#	this code is based on assumptions and is untested.
#
#	3. Added back in 'progress text'.  I had removed it for 'production', but
#	decided that other people looking at or using this code may find it as
#	useful as I do.
#
#	4. From Robert Mann <mh@easyway.com>
#	X-10 unit codes should be in hex, not decimal.
#	Unit "10" is now "A", and Unit "16" is now "G".
#
#	5. Rewrote a number of comments
#
#
# 2003-May-26 - Initial Revision
#
#

1;
