
=head1 B<Marrick>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This module implements code to send/receive X10 data via the Marrick Lynx10 serial interface

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Marrick;

my ( $_cmds, %Marrick );
my $Mserial_port;

my %dimref = qw(M 0 N 1 O 2 P 3 A 4 B 5 C 6 D 7 E 8 F 9 G A H B I C J D
  K E L F);

my %dimrev = qw(0 M 1 N 2 O 3 P 4 A 5 B 6 C 7 D 8 E 9 F A G B H C I D J
  E K F L);

my %table_hcodes = qw(A 0  B 1  C 2  D 3  E 4  F 5  G 6  H 7
  I 8  J 9  K A  L B  M C  N D  O E  P F);

my %table_dcodes = qw(1 0   2 1   3 2   4 3   5 4   6 5   7 6   8 7
  9 8  A 9  B A  C B  D C  E D  F E  G F);

my %table_rhcodes = qw(0 A  1 B  2 C  3 D  4 E  5 F  6 G  7 H
  8 I  9 J  A K  B L  C M  D N  E O  F P);

my %table_rdcodes = qw(0 1   1 2   2 3   3 4   4 5   5 6   6 7   7 8
  8 9   9 A   A B   B C   C D   D E   E F   F G);

my %table_fcodes = qw(J N0   K F0   L M   M M PRESET_DIM1 A PRESET_DIM2 B);

my $readBuf  = ();
my @ReplyBuf = ();

sub ShrinkReplyBuf {
    my @NewReply = ();
    foreach my $rp1 (@ReplyBuf) {
        if ( $rp1 ne "" ) { $NewReply[ $#NewReply + 1 ] = $rp1; }
    }
    @ReplyBuf = @NewReply;
}

sub read {
    my $len = 0;
    do {
        my $data;
        $len = 0;
        if ( $data = $Mserial_port->read(255) ) {
            $readBuf .= $data;
            my $hexd = unpack( "H*", $data );
            $len = length($data);
            &main::print_log("Marrick - We got [$len] bytes: $hexd")
              if $main::Debug{marrick};
        }
    } while ( $len > 0 );
    while ( $readBuf =~ /^([^\r,^\n]*)[\n,\r]+(.*)$/sig ) {
        my $found    = $1;
        my $restline = $2;
        if ( $found ne "" ) {
            &main::print_log("Marrick - Appending to Reply buffer: $found")
              if $main::Debug{marrick};
            $ReplyBuf[ $#ReplyBuf + 1 ] = $found;
        }
        $readBuf = $restline;
    }
    return undef;
}

sub init {

    # Nothing to init??
    ($Mserial_port) = @_;

    #$Mserial_port->debug(0);
    $Mserial_port->reset_error;
    $Mserial_port->databits(8);
    $Mserial_port->stopbits(1);
    $Mserial_port->parity("none");
    $Mserial_port->buffers( 4096, 4096 );
    @ReplyBuf = ();
    $Mserial_port->write("M00=00\r")
      ;    # Setting to 0 for old dim modes (needed for TXB16)
    sleep(1);
    &read();
    @ReplyBuf = ();
    $Mserial_port->write("V0\r");    # Get the version of Marrick firmware
    sleep(1);
    &read();

    foreach my $l1 (@ReplyBuf) {
        if ( $l1 =~ /^V.+/ ) {
            $Marrick{VERSION} = $l1;
        }
    }
    @ReplyBuf = ();
    $Mserial_port->write("V1\r");
    sleep(1);
    &read();
    foreach my $l1 (@ReplyBuf) {
        if ( $l1 =~ /Copyright/ ) {
            $Marrick{COPYRIGHT} = $l1;
        }
    }
    @ReplyBuf = ();
    if ( ( $Marrick{VERSION} ne "" ) and ( $Marrick{COPYRIGHT} ne "" ) ) {
        &::MainLoop_pre_add_hook( \&Marrick::check_for_data, 1 );
        &main::print_log("Marrick unit serial has been initialized.")
          if $main::Debug{marrick};
        &main::print_log("Marrick Reports: $Marrick{COPYRIGHT}")
          if $main::Debug{marrick};
        &main::print_log("Marrick Version: $Marrick{VERSION}")
          if $main::Debug{marrick};
        $Marrick{SENABLE} = 1;
    }
}

sub startup {

    # Initialize Module Stuff (RWT)
    $Marrick{COPYRIGHT}      = "";
    $Marrick{VERSION}        = "";
    $Marrick{SEQNUM}         = 0;
    $Marrick{NODEID}         = 0;
    $Marrick{HOUSEID}        = "";
    $Marrick{UNITID}         = "";
    $Marrick{SENABLE}        = 0;
    $Marrick{STATUS_REQUEST} = "";
    @ReplyBuf                = ();
    &main::print_log(
        "Marrick unit has been started - Main events processor initialized.")
      if $main::Debug{marrick};

}

sub GetReply {
    &read();
    my $GReply = "";
    foreach my $rpc ( 0 .. $#ReplyBuf ) {
        my $rp1 = $ReplyBuf[$rpc];
        if ( ( $rp1 =~ /^[E,e,\*].*/ ) and ( $GReply eq "" ) ) {
            $GReply = $rp1;
            delete $ReplyBuf[$rpc];
        }
    }
    if ( $GReply ne "" ) { &ShrinkReplyBuf; }
    return $GReply;
}

sub ClearReplies {
    foreach my $rpc ( 0 .. $#ReplyBuf ) {
        my $rp1 = $ReplyBuf[$rpc];
        if ( $rp1 =~ /^[E,e,\*].*/ ) {
            delete $ReplyBuf[$rpc];
        }
    }
    &ShrinkReplyBuf;
}

sub GetEvent {
    &read();
    my $GReply = "";
    foreach my $rpc ( 0 .. $#ReplyBuf ) {
        my $rp1 = $ReplyBuf[$rpc];
        if ( ( $rp1 =~ /^[X,x].*/ ) and ( $GReply eq "" ) ) {
            $GReply = $rp1;
            delete $ReplyBuf[$rpc];
        }
    }
    if ( $GReply ne "" ) { &ShrinkReplyBuf; }
    return $GReply;
}

sub Process_Event {
    my $INevent;
    ($INevent) = @_;
    &main::print_log("Marrick - Checking for Event Processing - \"$INevent\".")
      if $main::Debug{marrick};
    if ( $INevent =~ /^X(\S)(\S)(\S)/ ) {
        if ( $1 eq "0" ) {
            $Marrick{HOUSEID} = $table_rhcodes{$2};
            $Marrick{UNITID}  = $table_rdcodes{$3};
            return undef;
        }
        elsif ( $1 eq "1" ) {
            if ( $3 eq "0" ) {
                my $rslt = "";
                $Marrick{HOUSEID} = $table_rhcodes{$2};
                foreach my $unit ( "1" .. "G" ) {
                    $rslt .=
                      "X" . $Marrick{HOUSEID} . $unit . $Marrick{HOUSEID} . "K";
                }
                return $rslt;
            }
            elsif ( $3 eq "1" ) {
                my $rslt = "";
                $Marrick{HOUSEID} = $table_rhcodes{$2};
                foreach my $unit ( "1" .. "G" ) {
                    $rslt .=
                      "X" . $Marrick{HOUSEID} . $unit . $Marrick{HOUSEID} . "J";
                }
                return $rslt;
            }
            elsif ( $3 eq "2" ) {
                my $rslt = "";
                $Marrick{HOUSEID} = $table_rhcodes{$2};
                $rslt .= "X"
                  . $Marrick{HOUSEID}
                  . $Marrick{UNITID}
                  . $Marrick{HOUSEID} . "J";
                return $rslt;
            }
            elsif ( $3 eq "3" ) {
                my $rslt = "";
                $Marrick{HOUSEID} = $table_rhcodes{$2};
                $rslt .= "X"
                  . $Marrick{HOUSEID}
                  . $Marrick{UNITID}
                  . $Marrick{HOUSEID} . "K";
                return $rslt;
            }
            elsif ( $3 eq "A" ) {
                my $rslt = "X"
                  . $Marrick{HOUSEID}
                  . $Marrick{UNITID}
                  . $table_rhcodes{$2}
                  . "PRESET_DIM1";
                return $rslt;
            }
            elsif ( $3 eq "B" ) {
                my $rslt = "X"
                  . $Marrick{HOUSEID}
                  . $Marrick{UNITID}
                  . $table_rhcodes{$2}
                  . "PRESET_DIM2";
                return $rslt;
            }
        }
    }
    else {
        return undef;
    }
}

sub check_for_data {
    my $Event;
    &read();
    do {
        $Event = &GetEvent();
        if ( $Event ne "" ) {
            &main::print_log("Marrick - Received Event: $Event")
              if $main::Debug{marrick};
            my $Cmmd = &Process_Event($Event);
            &main::print_log("Marrick - Processed_Event Returned : $Cmmd")
              if $main::Debug{marrick};
            if ( $Cmmd ne "" ) {
                &main::process_serial_data($Cmmd);
            }
        }
    } while ( $Event ne "" );
}

sub send_X10 {
    my ( $serial_port, $house_code ) = @_;
    my $header = "";
    &main::print_log("Sending Marrick x10 code: $house_code")
      if $main::Debug{marrick};

    # Incoming string looks like this:  XA1AK
    my ( $house, $device, $level, $code ) = $house_code =~ /X(\S)(\S)(\S)(\S+)/;
    my $house_bits  = $table_hcodes{$house};
    my $device_bits = $table_dcodes{$device};
    my $code_bits   = $table_fcodes{$code};
    if ( $code =~ /PRESET_DIM/ ) {
        $header = "X0" . $house_bits . $device_bits;
        $header .= "X1" . $table_hcodes{$level} . $code_bits;
        &main::print_log(
            "DIM PRESET Encoded House: $house, Unit: $device Code: $code Level: $level"
        ) if $main::Debug{marrick};
        &main::print_log("DIM PRESET SENT Code: $header")
          if $main::Debug{marrick};
    }
    else {
        unless (defined $house_bits
            and defined $device_bits
            and defined $code_bits )
        {
            &main::print_log(
                "Error, invalid Marrick X10 data.  data=$house_code house=$house_bits device=$device_bits code=$code_bits"
            );
            return;
        }
        $header = $code_bits . $house_bits . $device_bits;
    }
    &ClearReplies;
    &main::print_log("Marrick x10 command sent: $header")
      if $main::Debug{marrick};
    retrns:
    my $slen = length($header) + 1;
    my $sent = $serial_port->write( $header . "\r" );
    my $rslt = "";
    while ( $rslt eq "" ) {
        $rslt = &GetReply();
    }
    if ( $rslt =~ /E.*/ ) {
        &main::print_log(
            "Marrick - Error received when sending command $header to X10.");
        goto retrns;
    }
    elsif ( $rslt =~ /\*/ ) {
        &main::print_log("Marrick - Command accepted by X10.")
          if $main::Debug{marrick};
    }
    &main::print_log("Bad Marrick X10 transmition sent=$sent expected=$slen")
      unless $sent == $slen;
}

return 1;    # for require

__END__

Marrick CODE OVERVIEW

HOUSE CODES: 0-F (Hexadecimal representation of house codes A through P)

ADDRESSES: 0-F (Hexadecimal representation of unit codes 1 through 16)

COMMANDS:
	F : OFF
	N : ON
	D : DIM
	S : STATUS (REQ & ACK)
	X : SEND RAW X10 CODE (ANY CODE)
	H : HAIL REQUEST (CHECKS FOR OTHER CONTROLLERS)
	R : RESET X-10 CONTROLLER (RESETS BOARD)
	T : REQUEST TIME SINCE POWER ON OR RESET

DATA FOR COMMANDS

CMD	DATA BYTE

F :	0 : Turn off single unit
	    Example: F01F (Turns off unit B16)
	1 : Turn off all lights this house code
	    Example: F10 (Turns off all lights on house code A)
	2 : Turn off all units this house code
	    Example: F24 (Turns off all units on house code E)
	3 : Turn off all lights, all house codes
	    Example: F3 (Turns off all lights on house codes A through P)
	4 : Turn off all units, all house codes
	    Example: F4 (Tums off all lights on house codes A through P)
	5-F : (RESERVED)

N :	0 : Turn on this unit
	    Example: N0A2 (Turns on unit K3)
	1 : Turn on all units this house code
	    Example: N1F (Turns on all units on house code P)
	2 : Turn on all units, All house codes
	    Example: N2 (Turns of all units on house codes A through P)
	3-F : (RESERVED)

D :	0-F : Light level of Dim (0 = OFF, F = FULL, 8=MEDIUM)
	    Example: D422 (Dims light to level 4)

S :	0 : Send OFF status for unit
	    Example: S000 (Status of unit A1 is OFF)
	1 : Send ON status for unit
	    Example: S100 (Status of unit A1 is ON)
	2 : Request status of unit
	    Example: S200 (What is status of unit A1 )
	3-F : (RESERVED)

X :	0 : Number code: HC = 0-F (Unit number 1-15 Respectively)
	    Example: X011 (Send house code B unit 2 code)

	1 : Cmd Code: HC =
	    0 : ALL UNITS OFF
	    1 : ALL LIGHTS ON
	    2 : ON
	    3 : OFF
	    4 : DIM
	    5 : BRIGHT
	    6 : ALL LIGHTS OFF
	    7 : EXTENDEDCODE
	    8 : HAIL REQUEST
	    9 : HAIL ACKNOWLEDGE
	    A : PRE SET DIM 0
	    B : PRE SET DIM 1
	    C : EXTENDED DATA
	    D : STATUS = ON
	    E : STATUS = OFF
	    F : STATUS REQUEST
	    Example: X112 (Send house code B command ON code)

H :	0 : Hail this house code
	    Example: H9 (Hail house code J)
	1-F : (RESERVED)

R :	X : RESET SYSTEM (FORCES INTERNAL CODE RESET)
	    Example: R (Resets controller)

T :	X : Time since power up or RESET. (Returns length of time)
	    Example: T (Gets run time in format DDD/HH/MM/SS)

#
# $Log: Marrick.pm,v $
# Revision 1.3  2003/02/08 05:29:23  winter
#  - 2.78 release
#
# Revision 1.2  2000/08/19 01:22:36  winter
# - 2.27 release
#
#

# Modified by Rob Taylor Jan 27, 2005 - Added code for Receive
# Modified by Rob Taylor Sep 22, 2005 - Added code for Preset dim

=back

=head2 INI PARAMETERS

To use this interface, add the following lines (localized, of course) to your mh.ini file:

  Lynx10_module=Lynx10
  Lynx10_port=/dev/ttyS0
  Lynx10_baudrate=1200

for debugging, set debug in mh.ini to include marrick

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

