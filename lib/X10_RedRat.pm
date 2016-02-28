#$Id$

=head1 DESCRIPTION


This is the first beta release of a module interfacing with the RedRat2 infra
red device from Chris Dodge (http://www.redrat.co.uk). The device was
originally meant for sending and receiving IR signals, but with a lot of help
from Dave Houston (http://www.laser.com/dhouston) I was able to generate X10
RF signals with it. In order for X10 RF devices to pick the result up you need
either a bax standard IR extender kit transmitting on the same frequence as
X10 RF or Dave Houston's IR/RF converter. The description for the IR/RF con-
verter can be found at http://www.laser.com/dhouston/ir2rf.htm .

I originally wrote this module to find a no-cost solution for my two phase
problem. Instead of buying a coupler I am using this to send RF. On each
phase I have one TM13U-AH which receives X10RF for all house codes
(http://www.letsautomate.com/10680.cfm?CFID=19174&CFTOKEN=41245603).
As I already head all the devices I didn't have to buy anything. I hope
this might be of use to somebody else as well.

The module hooks itself into X10 send, generates the RedRat codes and then
passes the codes to the RedRat.pm module.

This module is based on the example code example_interface.pm, X10_BX24.pm
and some hints from Bruce Winter about his new send_x10_data hook.
MANY THANKS TO THE AUTHORS!

		Marc Mosthav, October 7th 2002

=head1 .INI PARAMETERS

Use these mh.ini parameters to enable the code:

  RedRat_module = X10_RedRat
  RedRat_port   = /dev/ttyS1

=cut

use strict;

package X10_RedRat;

@X10_RedRat::ISA = ('Generic_Item');

my $ir_x10;

sub startup {
    $ir_x10 = new RedRat;
    &::Serial_Item::send_x10_data_add_hook( \&SendX10, 1 );

}

sub gen_X10RR {
    my $x10 = shift;
    my @x10;
    my $ir;

    my $temp = "0100" . "00";
    while ( length($x10) ) {
        $x10 =~ s/^(.)(.*)/$2/;
        if ( $1 == 1 ) {
            $temp .= "1" . "0111";
        }
        else {
            $temp .= "1" . "1";
        }
    }
    $temp .= "1";
    my $rest = length($temp) % 8;
    if ($rest) {
        $rest = 8 - $rest;
        $temp .= "0" x $rest;
    }
    $ir = "F67L82F6413F083F1884X";
    while ( length($temp) ) {
        $temp =~ s/^(....)(.*)/$2/;
        my $x = eval "0b$1";
        if ( $x > 10 ) {
            $x = chr( ord("A") + $x - 10 );
        }
        $ir .= "$x";
    }
    $ir .= "P4E20R01";
    return "[P$ir]";
}

my %X10RR;

sub X10RR_send {
    my $cmd = shift;
    my @buffer;

    my ( $house, $unit, $func, $lev ) = ( $cmd =~ /X(.)(..)(.)(..)/ );
    my $fullunit = $unit;

    $buffer[0] = (
        0x60, 0x70, 0x40, 0x50, 0x80, 0x90, 0xA0, 0xB0,
        0xE0, 0xF0, 0xC0, 0xD0, 0x00, 0x10, 0x20, 0x30
    )[ ord($house) - ord('A') ];
    if ( $unit > 8 ) {
        $buffer[0] |= 4;
        $unit -= 8;
    }
    if ($unit) {
        $buffer[1] =
          ( 0x00, 0x10, 0x08, 0x18, 0x40, 0x50, 0x48, 0x58 )[ $unit - 1 ];
    }
    else {
        $buffer[1] = 0x90 if $func eq "N";
        $buffer[1] = 0x80 if $func eq "F";
    }

    if ( $func eq "N" ) {    # send ON
        if ( not $X10RR{ "$house$fullunit" . "ON" } ) {
            $X10RR{ "$house$fullunit" . "ON" } = gen_X10RR(
                sprintf "%08b%08b%08b%08b",
                $buffer[0], $buffer[0] ^ 0xff,
                $buffer[1], $buffer[1] ^ 0xff
            );
            $ir_x10->add( "$house$fullunit" . "ON",
                $X10RR{ "$house$fullunit" . "ON" } );
        }
        $ir_x10->set( "$house$fullunit" . "ON" );
    }
    elsif ( $func eq "F" ) {    # send OFF
        $buffer[1] |= 0x20 if $fullunit ne "00";    # set "OFF" bit
        if ( not $X10RR{ "$house$fullunit" . "OFF" } ) {
            $X10RR{ "$house$fullunit" . "OFF" } = gen_X10RR(
                sprintf "%08b%08b%08b%08b",
                $buffer[0], $buffer[0] ^ 0xff,
                $buffer[1], $buffer[1] ^ 0xff
            );
            $ir_x10->add( "$house$fullunit" . "OFF",
                $X10RR{ "$house$fullunit" . "OFF" } );
        }
        $ir_x10->set( "$house$fullunit" . "OFF" );
    }
    elsif ( $func eq "B" ) {

        # send ON code
        if ( not $X10RR{ "$house$fullunit" . "ON" } ) {
            $X10RR{ "$house$fullunit" . "ON" } = gen_X10RR(
                sprintf "%08b%08b%08b%08b",
                $buffer[0], $buffer[0] ^ 0xff,
                $buffer[1], $buffer[1] ^ 0xff
            );
            $ir_x10->add( "$house$fullunit" . "ON",
                $X10RR{ "$house$fullunit" . "ON" } );
        }
        $ir_x10->set( "$house$fullunit" . "ON" );
        $buffer[0] &= 0xFB;
        $buffer[1] = 0x98;
        if ( not $X10RR{ "$house" . "B" } ) {
            $X10RR{ "$house" . "B" } = gen_X10RR(
                sprintf "%08b%08b%08b%08b",
                $buffer[0], $buffer[0] ^ 0xff,
                $buffer[1], $buffer[1] ^ 0xff
            );
            $ir_x10->add( "$house" . "B", $X10RR{ "$house" . "B" } );
        }
        while ( $lev > 0 ) {
            $lev -= 5;
            $ir_x10->set( "$house" . "B" );
        }
    }
    elsif ( $func eq "D" ) {
        if ( not $X10RR{ "$house$fullunit" . "ON" } ) {
            $X10RR{ "$house$fullunit" . "ON" } = gen_X10RR(
                sprintf "%08b%08b%08b%08b",
                $buffer[0], $buffer[0] ^ 0xff,
                $buffer[1], $buffer[1] ^ 0xff
            );
            $ir_x10->add( "$house$fullunit" . "ON",
                $X10RR{ "$house$fullunit" . "ON" } );
        }
        $ir_x10->set( "$house$fullunit" . "ON" );
        $buffer[0] &= 0xFB;
        $buffer[1] = 0x98;
        if ( not $X10RR{ "$house" . "D" } ) {
            $X10RR{ "$house" . "D" } = gen_X10RR(
                sprintf "%08b%08b%08b%08b",
                $buffer[0], $buffer[0] ^ 0xff,
                $buffer[1], $buffer[1] ^ 0xff
            );
            $ir_x10->add( "$house" . "D", $X10RR{ "$house" . "D" } );
        }
        while ( $lev > 0 ) {
            $lev -= 5;
            $ir_x10->set( "$house" . "D" );
        }
    }
    elsif ( $func eq "X" ) {
        $house = ( 6, 14, 2, 10, 1, 9, 5, 13, 7, 15, 3, 11, 0, 8, 4, 12 )
          [ ord($house) - ord('A') ];
        $unit =
          ( 6, 14, 2, 10, 1, 9, 5, 13, 7, 15, 3, 11, 0, 8, 4, 12 )[ $unit - 1 ];
        my $code = 16 * $house + $unit;
        if ( not $X10RR{ "$house" . "X$lev" } ) {
            $X10RR{ "$house" . "X$lev" } = gen_X10RR(
                sprintf "%08b%08b%08b%08b",
                $code, $code ^ 0xf0,
                $lev, $lev ^ 0xff
            );
            $ir_x10->add( "$house" . "X$lev", $X10RR{ "$house" . "X$lev" } );
        }
        $ir_x10->set( "$house" . "X$lev" );
    }
    else {
        return;    # Preset or Error
    }
}

my $prev_X10 = '';
my %X10Unit  = (
    "1" => "01",
    "2" => "02",
    "3" => "03",
    "4" => "04",
    "5" => "05",
    "6" => "06",
    "7" => "07",
    "8" => "08",
    "9" => "09",
    "A" => "10",
    "B" => "11",
    "C" => "12",
    "D" => "13",
    "E" => "14",
    "F" => "15",
    "G" => "16"
);

sub SendX10 {

    # this will receive command to be sent to the CM11a via a regular X10_Item call
    # this subroutine could be call twice before sending the command
    # the first call will be the house code/Unit if non "all unit"
    # the second call will be the command
    # doesn't support all unit preset/dim/bright

    # The BX24 is expecting the following code to drive the CM11A
    # XHUUFLL
    # X    Tell the system it's a X10 Command
    # H  = Housecode A-P
    # UU = Unit 01-16
    # F  = FUNCTION  (only on/off for now)
    #      N = On
    #      F = Off
    #      D = Dim
    #      B = Bright
    #      X = Extended Dim
    # LL = Level (always 00 for On/off)
    # LL = Level (+-00/99 for Bright/Dim)
    # LL = Level (00/63 for Extended Dim)

    my $HouseUnit;
    if ( scalar(@_) != 1 ) {
        &main::print_log("X10_RedRat call - Invalid parameter [@_]");
        return;
    }

    my $NewX10 = shift @_;
    $NewX10 = uc($NewX10);

    if ( $NewX10 !~ /^X/ ) {
        &main::print_log("X10_RedRat Invalid call doesn't start by X");
        return;
    }

    # print "DEBUG RedRat Received X10 cmd [$NewX10]\n";
    # did we receive a House/Unit code, or an action
    # The house/Unix will have a second charater 1-9 A-G
    my ( $XChar, $House, $X10Type, @X10Value ) = split( //, $NewX10 );
    my $Cmd;
    if ( uc($House) !~ /[A-P]/ ) {
        print "X10_RedRat invalid house code [$House]\n";
        $prev_X10 = '';
        return;
    }
    if ( $X10Type =~ /[1-9A-GOP]/ ) {
        if ( $X10Type eq "O" ) {
            $Cmd = "X" . $House . "00L00";    # All light On   mh=XAO
        }
        elsif ( $X10Type eq "P" ) {
            $Cmd = "X" . $House . "00U00";    # All light off  mh=XAP
        }
        else {
            $prev_X10 = "X" . $House . $X10Unit{$X10Type};

            # print "DEBUG RedRat sub SendX10 Preserving X10 house/unit $prev_X10\n";
            return;
        }
    }
    elsif ( $X10Type =~ /[JKLM\-\+\&]/ ) {
        if ( $prev_X10 eq '' ) {
            print "X10_RedRat invalid command, no housecode defined  [@_]\n";
            return;
        }
        if ( $X10Type eq "J" ) {    # ON
            $Cmd = $prev_X10 . "N00";
        }
        elsif ( $X10Type eq "K" ) {    # Off
            $Cmd = $prev_X10 . "F00";
        }
        elsif ( $X10Type eq "+" ) {    # Bright with Value (+20)
            my $Bright =
              ( join( '', @X10Value ) eq '' ) ? 33 : join( '', @X10Value );
            my $Bright = ( $Bright < 10 ) ? "0" . $Bright : $Bright;
            $Cmd = $prev_X10 . "B" . $Bright;
        }
        elsif ( $X10Type eq "-" ) {    # Dim with value    (-20)
            my $Dim =
              ( join( '', @X10Value ) eq '' ) ? 33 : join( '', @X10Value );
            my $Dim = ( $Dim < 10 ) ? "0" . $Dim : $Dim;
            $Cmd = $prev_X10 . "D" . $Dim;
        }
        elsif ( $X10Type eq "&" ) {    # Preset (1-63)
            my $Preset = join( '', @X10Value );
            $Preset =~ s/P//;
            $Cmd = $prev_X10 . "X$Preset";
        }
        elsif ( $X10Type eq "L" ) {    # Brighten as per Misterhouse way (+40)
            $Cmd = $prev_X10 . "B40";
        }
        elsif ( $X10Type eq "M" ) {    # Dimmer as per Misterhouse way (-40)
            $Cmd = $prev_X10 . "D40";
        }

        # print "DEBUG X10_RedRat sub SendX10 Complete X10 command received [$Cmd]\n";
        $prev_X10 = '';
    }
    else {
        print "X10_RedRat invalid command [@_]\n";
        $prev_X10 = '';
        return;
    }

    # print "X10_RedRat Sending CM11a command [$Cmd]\n";
    X10RR_send($Cmd);

    return;

}

1;
