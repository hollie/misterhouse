
# This module implements code to send/receive X10 data to the marrick X10 interface
#  ... not tested and not fully implemented ....
#  ... not tested and not fully implemented ....
#  ... not tested and not fully implemented ....

# To use this interface, add the following lines (localized, of course)
# to your mh.ini file:

#Marrick_port=/dev/ttyS0
#Marrick_baudrate=19200


use strict;

package Marrick;

sub init {
# Nothing to init??
}

my %table_hcodes = qw(A 0  B 1  C 2  D 3  E 4  F 5  G 6  H 7
                      I 8  J 9  K A  L B  M C  N D  O E  P F);

my %table_dcodes = qw(1 0   2 1   3 2   4 3   5 4   6 5   7 6   8 7
                      9 8  10 9  11 A  12 B  13 C  14 D  15 E  16 F);

my %table_fcodes = qw(J N0   K F0   L M   M M);

sub send_X10 {
    my ($serial_port, $house_code) = @_;
    print "\ndb sending Marrick x10 code: $house_code\n" if lc $main::Debug{marrick};

# Incoming string looks like this:  XA1AK
    my ($house, $device, $code) = $house_code =~ /X(\S)(\S)\S(\S+)/;

    my $house_bits = $table_hcodes{$house};
    my $device_bits = $table_dcodes{$device};
    my $code_bits = $table_fcodes{$code};
    unless (defined $house_bits and defined $device_bits and defined $code_bits) {
        print "Error, invalid Marrick X10 data.  data=$house_code house=$house_bits device=$device_bits code=$code_bits\n";
        return;
    }
    
    my $header = $code_bits . $house_bits . $device_bits;
    print "db Marrick x10 command sent: $header\n" if lc($main::config_parms{debug}) eq 'marrick';

    my $sent = $serial_port->write($header . "\r");
    print "Bad Marrick X10 transmition sent=$sent\n" unless 5 == $sent;
}

return 1;           # for require

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
