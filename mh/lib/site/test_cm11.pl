#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use lib './blib/lib','./lib';
use vars qw($OS_win $port %config_parms);

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..98\n"; }

END {print "not ok 1\n" unless $loaded;}
use ControlX10::CM11 qw( :FUNC 2.06 );
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use strict;

## emulate a CM11A and xx::SerialPort (test mode) for testing

package SerialStub;

sub reset_error	{ return 0; }

sub new {
    my $class = shift;
    my $self  = {};
    $self->{"_T_INPUT"}		= "";
    return bless ($self, $class);
}

sub write {
    return unless (@_ == 2);
    my $self = shift;
    my $wbuf = shift;
    my $response = "";
    return unless ($wbuf);
    my @loc_char = split (//, $wbuf);
    my $f_char = ord (shift @loc_char);
    if ($f_char == 0x00) {
	$response = chr(0x55);
	$self->lookclear($response);
	return 1;
    }
    elsif ($f_char == 0xc3) {
	$response = chr(0x05).chr(0x04).chr(0xe9).chr(0xe5).chr(0xe5).chr(0x58);
	    # example from protocol.txt
	$self->lookclear($response);
	return 1;
    }
    elsif (($f_char == 0xeb) or ($f_char == 0xeb)) {
	$response = chr($f_char);
	$self->lookclear($response);
	return 1;
    }
    else {
	my $ccount = 1;
	my $n_char = "";
	foreach $n_char (@loc_char) {
	    $f_char += ord($n_char);
	    $ccount++;
	}
	$response = chr($f_char & 0xff);
	$self->lookclear($response);
	return $ccount;
    }
}

sub lookclear {
    my $self = shift;
    return unless (@_);
    $self->{"_T_INPUT"} = shift;
    1;
}

sub input {
    return undef unless (@_ == 1);
    my $self = shift;
    my $result = "";

    if ($self->{"_T_INPUT"}) {
	$result = $self->{"_T_INPUT"};
	$self->{"_T_INPUT"} = "";
	return $result;
    }
}

######################### End CM11A emulator

package main;

use strict;
my $tc = 2;		# next test number after setup
my $fail = 0;

my $naptime = 0;	# pause between output pages
if (@ARGV) {
    $naptime = shift @ARGV;
    unless ($naptime =~ /^[0-5]$/) {
	die "Usage: perl test.pl [ page_delay (0..5) ]";
    }
}

sub is_ok {
    my $result = shift;
    printf (($result ? "" : "not ")."ok %d\n",$tc++);
    $fail++ unless $result;
    return $result;
}

sub is_zero {
    my $result = shift;
    if (defined $result) {
        return is_ok ($result == 0);
    }
    else {
        printf ("not ok %d\n",$tc++);
        $fail++;
    }
}

sub is_bad {
    my $result = shift;
    printf (($result ? "not " : "")."ok %d\n",$tc++);
    $fail++ if $result;
    return (not $result);
}

###############################################################

my $serial_port = SerialStub->new ();
$serial_port->lookclear("Test123");
$main::config_parms{debug} = "";

# end of preliminaries.
is_ok("Test123" eq read_cm11($serial_port, 1));		# 2
is_zero($ControlX10::CM11::DEBUG);			# 3
is_ok(send_cm11($serial_port, 'A1'));			# 4
is_zero($ControlX10::CM11::DEBUG);			# 5
is_ok(send_cm11($serial_port, 'AOFF'));			# 6

$main::config_parms{debug} = "X10";
is_ok(send_cm11($serial_port, 'bg'));			# 7
is_ok($ControlX10::CM11::DEBUG);			# 8

$main::config_parms{debug} = "";
is_ok(send_cm11($serial_port, 'B-25'));			# 9
is_ok(send_cm11($serial_port, 'BON'));			# 10

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(send_cm11($serial_port, 'B2'));			# 11
is_zero($ControlX10::CM11::DEBUG);			# 12
is_ok(send_cm11($serial_port, 'Bl'));			# 13

is_ok(send_cm11($serial_port, 'cStatus'));		# 14
is_ok(send_cm11($serial_port, 'DF'));			# 15
is_ok(send_cm11($serial_port, 'DALL_ON'));		# 16

is_bad(send_cm11($serial_port, 'A2B'));			# 17
is_bad(send_cm11($serial_port, 'AH'));			# 18
is_bad(send_cm11($serial_port, 'Q1'));			# 19
is_bad(send_cm11($serial_port, 'BAD'));			# 20
is_bad(send_cm11($serial_port, 'EQ'));			# 21
is_ok(ControlX10::CM11::send($serial_port, 'EE'));	# 22
is_ok(ControlX10::CM11::send($serial_port, 'EDIM'));	# 23

is_ok(send_cm11($serial_port, 'Fbright'));		# 24
is_ok(send_cm11($serial_port, 'GM'));			# 25

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(send_cm11($serial_port, 'HL'));			# 26
is_ok(send_cm11($serial_port, 'IK'));			# 27
is_ok(send_cm11($serial_port, 'JJ'));			# 28
is_ok(send_cm11($serial_port, 'KO'));			# 29
is_ok(send_cm11($serial_port, 'LP'));			# 30
is_ok(send_cm11($serial_port, 'mALL_OFF'));		# 31
is_ok(send_cm11($serial_port, 'NP'));			# 32

is_ok(send_cm11($serial_port, 'O3'));			# 33
is_ok(send_cm11($serial_port, 'P4'));			# 34
is_ok(send_cm11($serial_port, 'A5'));			# 35
is_ok(send_cm11($serial_port, 'B6'));			# 36
is_ok(send_cm11($serial_port, 'C7'));			# 37

is_ok(send_cm11($serial_port, 'd8'));			# 38
is_ok(send_cm11($serial_port, 'e9'));			# 39
is_ok(send_cm11($serial_port, 'fa'));			# 40
is_ok(send_cm11($serial_port, 'gb'));			# 41
is_ok(send_cm11($serial_port, 'hc'));			# 42

is_ok(send_cm11($serial_port, 'id'));			# 43
is_ok(send_cm11($serial_port, 'PALL_LIGHTS_OFF'));	# 44
is_ok(send_cm11($serial_port, 'AEXTENDED_CODE'));	# 45
is_ok(send_cm11($serial_port, 'BHAIL_REQUEST'));	# 46

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(send_cm11($serial_port, 'CHAIL_ACK'));		# 47
is_ok(send_cm11($serial_port, 'DPRESET_DIM1'));		# 48
is_ok(send_cm11($serial_port, 'PPRESET_DIM2'));		# 49
is_ok(send_cm11($serial_port, 'AEXTENDED_DATA'));	# 50
is_ok(send_cm11($serial_port, 'BSTATUS_ON'));		# 51
is_ok(send_cm11($serial_port, 'CSTATUS_OFF'));		# 52

is_ok(send_cm11($serial_port, 'i-10'));			# 53
is_ok(send_cm11($serial_port, 'P-20'));			# 54
is_ok(send_cm11($serial_port, 'A-30'));			# 55
is_ok(send_cm11($serial_port, 'B-40'));			# 56
is_ok(send_cm11($serial_port, 'C-50'));			# 57

is_ok(send_cm11($serial_port, 'i-60'));			# 58
is_ok(send_cm11($serial_port, 'P-70'));			# 59
is_ok(send_cm11($serial_port, 'A-80'));			# 60
is_ok(send_cm11($serial_port, 'B-90'));			# 61
is_bad(send_cm11($serial_port, 'C-100'));		# 62

is_bad(send_cm11($serial_port, 'A-0'));			# 63
is_ok(send_cm11($serial_port, 'P+20'));			# 64

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(send_cm11($serial_port, 'A+30'));			# 65
is_ok(send_cm11($serial_port, 'B+40'));			# 66
is_ok(send_cm11($serial_port, 'C+50'));			# 67
is_ok(send_cm11($serial_port, 'i+60'));			# 68
is_ok(send_cm11($serial_port, 'P+70'));			# 69
is_ok(send_cm11($serial_port, 'A+80'));			# 70
is_ok(send_cm11($serial_port, 'B+90'));			# 71
is_bad(send_cm11($serial_port, 'C+100'));		# 72

is_ok(send_cm11($serial_port, 'A+10'));			# 73
is_ok(send_cm11($serial_port, 'A-95'));			# 74
is_ok(send_cm11($serial_port, 'A+95'));			# 75
is_ok(send_cm11($serial_port, 'B+65'));			# 76
is_ok(send_cm11($serial_port, 'C-75'));			# 77

my $data = "";
my $response = "B6B7BMGE";
## $main::config_parms{debug} = "X10";
is_ok($data = receive_cm11($serial_port));		# 78
is_ok($data eq $response); 				# 79
is_ok(40 == dim_decode_cm11("GE"));			# 80

is_ok(45 == dim_decode_cm11("A3"));			# 81
is_ok(10 == dim_decode_cm11("E9"));			# 82
is_ok(60 == dim_decode_cm11("N3"));			# 83
is_ok(50 == dim_decode_cm11("ID"));			# 84
is_ok(0 == dim_decode_cm11("M5"));			# 85

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(35 == dim_decode_cm11("O4"));			# 86
is_ok(15 == dim_decode_cm11("C3"));			# 87
is_ok(75 == dim_decode_cm11("FA"));			# 88
is_ok(85 == dim_decode_cm11("L9"));			# 89
is_ok(95 == dim_decode_cm11("P4"));			# 90
is_ok(send_cm11($serial_port, 'C1&P25'));		# 91
is_bad(send_cm11($serial_port, 'C&P05'));		# 92
is_ok(send_cm11($serial_port, 'M4'));			# 93
## $main::config_parms{debug} = "X10";
is_ok(send_cm11($serial_port, 'OPRESET_DIM2'));		# 94
is_bad(send_cm11($serial_port, 'C1&P'));		# 95
is_bad(send_cm11($serial_port, 'C1&PA5'));		# 96
is_ok(send_cm11($serial_port, 'C1&P5'));		# 97
is_bad(send_cm11($serial_port, 'C1&P105'));		# 98

undef $serial_port;

print "Failures detected in test\n" if $fail;
