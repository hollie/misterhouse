
# This is code will read the information coming out of a MP3 Remote Control
# receiver base unit (MR26A).
#
# This device issues 5 byte sequences when buttons on the MP3 Remote (UR51A)
# are pressed.  The MR26A also picks up standard X10 RF traffic, this code
# handles both.
#
# The bytes follow the following pattern:
# Byte Function
# 1-2  always  0xD5AA
# 3    the house code (and unit code 1-8 or 9-16 bit) 0xEE for UR15A functions
# 4    the unit code (and the ON or OFF bit) or the UR15A button code
# 5    always 0xAD
#
# TODO:
# -finish the code, right now it just reports the function, I need to
#  update the appropriate MH defined objects
# -create a table of 'ignore this house/unit code'. So we aren't handling
#  traffic already handled by TM751s or RR501s
# -handle multiply sent commands (most devices send the command more than once)
# -finish DEBUG code
# -better integrate into MH (if this makes sense)
# -learn more Perl to improve code (this is my first outing)
#
# To configure, include the following in your mh.private.ini file:
#serial_mp3_rmt_port=COM1
#serial_mp3_rmt_baudrate=9600
#serial_mp3_rmt_handshake=none
#serial_mp3_rmt_datatype=raw


#-House Codes (for units 1-8) -for units 9-16, OR with 04
#    1-8  9-16
#A   60   64
#B   70   74
#C   40   44
#D   50   54
#E   80   84
#F   90   94
#G   A0   A4
#H   B0   B4
#I   E0   E4
#J   F0   F4
#K   C0   C4
#L   D0   D4
#M   00   04
#N   10   14
#O   20   24
#P   30   34

#-Unit/Commands codes (for ON command)  -for OFF command, OR with 20
#ON command    OFF command
#1/9 00   20
#2/10     10   30
#3/11     08   28
#4/12     18   38
#5/13     40   60
#6/14     50   70
#7/15     48   68
#8/16     58   78

use strict;
use vars qw($DEBUG);

$DEBUG = 1;

# House codes A-P (only first nibble is used)
my %mp3rmt_hcodes = qw(0110 A 0111 B 0100 C 0101 D 1000 E 1001 F
                       1010 G 1011 H 1110 I 1111 J 1100 K 1101 L
                       0000 M 0001 N 0010 O 0011 P );

# Unit codes (only 1-8, 9-16 is indicated if 0x40 in the House Code)
my %mp3rmt_ucodes = qw(00000000 1 00010000 2 00001000 3 00011000 4
                       01000000 5 01010000 6 01001000 7 01011000 8
                 10010000 Lights_ON 10000000 All_OFF
                 10001000 DimUp 10011000 DimDown);
# UR51A Function codes:
# -OK and Ent are same
# -PC and Subtitle are same
# -Chan buttons and Skip buttons are same
# -'02' in hash for '0' button gives bad results, special test in code
my %mp3rmt_fcodes = qw(f0 Power d4 PC d6 Title 3a Display 52 OK\Ent d8 Return
                 d5 Up d3 Down d2 Left d1 Right b6 Menu c9 Exit 38 Rew
                 b0 Play b8 FF ff Rec 70 Stop 72 Pause f2 Recall
                 82 1 42 2 c2 3 22 4 a2 5 62 6 e2 7 12 8 92 9
                 ba AB 02 0 40 ChUP c0 ChDwn e0 VolDwn 60 VolUp a0 Mute);

my $mp3_rmt = new Serial_Item(undef, undef, 'serial_mp3_rmt');

my ($command, $house_code, $unit_code);

# There's no 'state' associated with the object, so just read when 'said'
if ( my $data = said $mp3_rmt ) {

    #my $dataHex = unpack('H*', $data);
    #print_log "mp3_rmt said: $dataHex" if $DEBUG;

    # partion bytes into an array
    my @bytes = split //, $data;

    my $header_data = shift @bytes;
    $header_data .= shift @bytes;
    my $header = unpack('H*', $header_data);

    my $house_data = shift @bytes;
    my $house = unpack('H*', $house_data);

    my $code_data = shift @bytes;
    my $code = unpack('H*', $code_data);

    my $trailer_data = shift @bytes;
    my $trailer = unpack('H*', $trailer_data);

    #print_log "header: $header, house: $house, code: $code, trailer:$trailer" if $DEBUG;

    # Handle UR51A function codes
    if ($house eq 'ee') {
     print_log "MP3_RMT error, not a valid function code: $code"
         unless $unit_code = $mp3rmt_fcodes{$code} or ($code == 02);
     print_log "MP3_RMT: Function code: $unit_code" if $DEBUG;
     return;
    }

    my $house_bits = unpack('B8', $house_data);
    my $house_bits_upper = substr($house_bits, 0, 4); # used to House Code
    my $house_bits_lower = substr($house_bits, 4, 4); # used for 1-8 vs 9-16 unit code

    #print_log "house_bits upper: $house_bits_upper, lower:$house_bits_lower" if $DEBUG;

    my $code_bits = unpack('B8', $code_data);
    my $code_bits_upper = substr($code_bits, 0, 4); # used for ON vs. OFF

    #print_log "code_bits: $code_bits" if $DEBUG;

    $command = ($code_bits_upper & 0x2) ? 'OFF' : 'ON' ;

    # set the unit code, strip ON/OFF bit 0x40
    print_log "MP3_RMT: Error, not a valid unit code: $code_bits"
                unless $unit_code = $mp3rmt_ucodes{$code_bits & '11011111'};

    # special unit code for: Lights ON, All OFF, DimUP, DimDown
    if (($code == 90 ) or ($code == 80) or
        ($code == 88 ) or ($code == 98)) {
        $command = 'N/A';
    } else {
        # must be a unit code, adjust for 1-8 or 9-16 bit
        $unit_code += ($house_bits_lower & 0x04) ? 8 : 0;
    }

    print_log "MP3_RMT: Error, not a valid house code: $house_bits"
        unless $house_code = $mp3rmt_hcodes{$house_bits_upper};

    print_log "MP3_RMT: House code: $house_code, " .
        "Unit code: $unit_code, " .
            "Command: $command" if $DEBUG;
}


