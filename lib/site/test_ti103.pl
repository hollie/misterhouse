#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
# created from test_cm11.pl by David H. Lynch Jr. <dhlii@dlasys.net>

use lib './blib/lib','./lib';
use vars qw($OS_win $port %config_parms);

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..98\n"; }

END {print "not ok 1\n" unless $loaded;}
use ControlX10::TI103 qw( :FUNC 0.01 );
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use strict;

## emulate a TI103 and xx::SerialPort (test mode) for testing

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
	return unless ($wbuf);
	my @loc_char = split (//, $wbuf);
	my $ccount = 0;
	my $n_char = "";
	foreach $n_char (@loc_char) {
	    print $n_char ;
	    $ccount++;
	}
	$self->lookclear("$<2800!4B#");
	return $ccount;
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

######################### End TI103 emulator

package main;

use strict;
my $tc = 2;		# next test number after setup
my $fail = 0;

sub logit {
    my $file =  shift;
    my $err =  shift;
    print "$file:$err\n";
}
my $naptime = 0;	# pause between output pages
if (@ARGV) {
    $naptime = shift @ARGV;
    unless ($naptime =~ /^[0-5]$/) {
	die "Usage: perl test.pl [ page_delay (0..5) ]";
    }
}

###############################################################

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
is_ok("Test123" eq read_ti103($serial_port, 1));	# 2
# ok 2
is_zero($ControlX10::TI103::DEBUG);			# 3
# ok 3
is_ok(send_ti103($serial_port, 'A1'));			# 4
# ok 4 $>28001A01A01A1#
is_zero($ControlX10::TI103::DEBUG);			# 5
# ok 5
is_ok(send_ti103($serial_port, 'AOFF'));		# 6
# ok 6 $>28001AOFFAOFF95#

$main::config_parms{debug} = "x10";
is_ok(send_ti103($serial_port, 'bg'));			# 7
# ok 7 $>28001B16B16AF#
is_ok($ControlX10::TI103::DEBUG);			# 8
#! not ok 8

$main::config_parms{debug} = "";
is_ok(send_ti103($serial_port, 'B-25'));		# 9
# ok 9 $>28001BD25BD2537#

is_ok(send_ti103($serial_port, 'BON'));			# 10
# ok 10 $>28001BONBON1B#

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(send_ti103($serial_port, 'B2'));			# 11
# ok 11 $>28001B02B02A5#

is_zero($ControlX10::TI103::DEBUG);			# 12
# ok 12
is_ok(send_ti103($serial_port, 'Bl'));			# 13
# this OK but probably not what we want.
#! ok 13 $>28001BB40BB402D#

is_ok(send_ti103($serial_port, 'cStatus'));		# 14
# ok 14 $>28001CSRQCSRQCF#
is_ok(send_ti103($serial_port, 'DF'));			# 15
# ok 15 $>28001D15D15B1#

is_ok(send_ti103($serial_port, 'DALL_ON'));		# 16
# ok 16 $>28001DAUNDAUNAD#

is_bad(send_ti103($serial_port, 'A2B'));		# 17
# ok 17

is_bad(send_ti103($serial_port, 'AH'));			# 18
# ok 18
is_bad(send_ti103($serial_port, 'Q1'));			# 19
# ok 19

is_bad(send_ti103($serial_port, 'BAD'));		# 20
# ok 20

is_bad(send_ti103($serial_port, 'EQ'));			# 21
# ok 21

is_ok(ControlX10::TI103::send($serial_port, 'EE'));	# 22
# ok 22 $>28001E14E14B1#

is_ok(ControlX10::TI103::send($serial_port, 'EDIM'));	# 23
# ok 23 $>28001ED40ED4037#

is_ok(send_ti103($serial_port, 'Fbright'));		# 24
# ok 24 $>28001FB40FB4035#

is_ok(send_ti103($serial_port, 'GM'));			# 25
# ok 25 $>28001GD40GD403B#

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(send_ti103($serial_port, 'HL'));			# 26
# ok 26 $>28001HB40HB4039#
is_ok(send_ti103($serial_port, 'IK'));			# 27
# ok 27 $>28001IOFFIOFFA5#
is_ok(send_ti103($serial_port, 'JJ'));			# 28
# ok 28 $>28001JONJON2B#
is_ok(send_ti103($serial_port, 'KO'));			# 29
# ok 29 $>28001KAUNKAUNBB#
is_ok(send_ti103($serial_port, 'LP'));			# 30
# ok 30 $>28001LAUFLAUFAD#
is_ok(send_ti103($serial_port, 'mALL_OFF'));		# 31
# ok 31 $>28001MAUFMAUFAF#

is_ok(send_ti103($serial_port, 'NP'));			# 32
# ok 32 $>28001NAUFNAUFB1#

is_ok(send_ti103($serial_port, 'O3'));			# 33
# ok 33 $>28001O03O03C1#

is_ok(send_ti103($serial_port, 'P4'));			# 34
# 34 $>28001P04P04C5#
is_ok(send_ti103($serial_port, 'A5'));			# 35
# ok 35 $>28001A05A05A9#

is_ok(send_ti103($serial_port, 'B6'));			# 36
# ok 36 $>28001B06B06AD#

is_ok(send_ti103($serial_port, 'C7'));			# 37
# ok 37 $>28001C07C07B1#

is_ok(send_ti103($serial_port, 'd8'));			# 38
# ok 38 $>28001D08D08B5#

is_ok(send_ti103($serial_port, 'e9'));			# 39
# ok 39 $>28001E09E09B9#

is_ok(send_ti103($serial_port, 'fa'));			# 40
# ok 40 $>28001F10F10AB#

is_ok(send_ti103($serial_port, 'gb'));			# 41
# ok 41 $>28001G11G11AF#

is_ok(send_ti103($serial_port, 'hc'));			# 42
# ok 42 $>28001H12H12B3#

is_ok(send_ti103($serial_port, 'id'));			# 43
# ok 43 $>28001I13I13B7#

is_ok(send_ti103($serial_port, 'PALL_LIGHTS_OFF'));	# 44
# ok 44 $>28001PAUFPAUFB5#

is_ok(send_ti103($serial_port, 'AEXTENDED_CODE'));	# 45
# ok 45 $>280015D#

is_ok(send_ti103($serial_port, 'BHAIL_REQUEST'));	# 46
# ok 46 $>28001BHRQBHRQB7#

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(send_ti103($serial_port, 'CHAIL_ACK'));		# 47
# ok 47 $>28001CHAKCHAK8B#

is_ok(send_ti103($serial_port, 'DPRESET_DIM1'));	# 48
# ok 48 $>28001DIM05DIM05DB#

is_ok(send_ti103($serial_port, 'PPRESET_DIM2'));	# 49
# ok 49 $>28001DIM19DIM19E5#

is_ok(send_ti103($serial_port, 'AEXTENDED_DATA'));	# 50
# ok 50 $>280015D#

is_ok(send_ti103($serial_port, 'BSTATUS_ON'));		# 51
# ok 51 $>28001BSONBSONC1#

is_ok(send_ti103($serial_port, 'CSTATUS_OFF'));		# 52
# ok 52 $>28001CSOFCSOFB3#

is_ok(send_ti103($serial_port, 'i-10'));		# 53
# ok 53 $>28001ID10ID1039#

is_ok(send_ti103($serial_port, 'P-20'));		# 54
# ok 54 $>28001PD20PD2049#

is_ok(send_ti103($serial_port, 'A-30'));		# 55
# ok 55 $>28001AD30AD302D#

is_ok(send_ti103($serial_port, 'B-40'));		# 56
# ok 56 $>28001BD40BD4031#

is_ok(send_ti103($serial_port, 'C-50'));		# 57
# ok 57 $>28001CD50CD5035#

is_ok(send_ti103($serial_port, 'i-60'));		# 58
# ok 58 $>28001ID60ID6043#

is_ok(send_ti103($serial_port, 'P-70'));		# 59
# ok 59 $>28001PD70PD7053#

is_ok(send_ti103($serial_port, 'A-80'));		# 60
# ok 60 $>28001AD80AD8037#

is_ok(send_ti103($serial_port, 'B-90'));		# 61
# ok 61 $>28001BD90BD903B#

is_bad(send_ti103($serial_port, 'C-100'));		# 62
# ok 62

is_bad(send_ti103($serial_port, 'A-0'));		# 63
# ok 63

is_ok(send_ti103($serial_port, 'P+20'));		# 64
# ok 64 $>28001PB20PB2045#

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(send_ti103($serial_port, 'A+30'));		# 65
# ok 65 $>28001AB30AB3029#

is_ok(send_ti103($serial_port, 'B+40'));		# 66
# ok 66 $>28001BB40BB402D#

is_ok(send_ti103($serial_port, 'C+50'));		# 67
# ok 67 $>28001CB50CB5031#

is_ok(send_ti103($serial_port, 'i+60'));		# 68
# ok 68 $>28001IB60IB603F#

is_ok(send_ti103($serial_port, 'P+70'));		# 69
# ok 69 $>28001PB70PB704F#

is_ok(send_ti103($serial_port, 'A+80'));		# 70
# ok 70 $>28001AB80AB8033#

is_ok(send_ti103($serial_port, 'B+90'));		# 71
# ok 71 $>28001BB90BB9037#

is_bad(send_ti103($serial_port, 'C+100'));		# 72
# ok 72

is_ok(send_ti103($serial_port, 'A+10'));		# 73
# ok 73 $>28001AB10AB1025#

is_ok(send_ti103($serial_port, 'A-95'));		# 74
# ok 74 $>28001AD95AD9543#

is_ok(send_ti103($serial_port, 'A+95'));		# 75
# ok 75 $>28001AB95AB953F#

is_ok(send_ti103($serial_port, 'B+65'));		# 76
# ok 76 $>28001BB65BB653B#

is_ok(send_ti103($serial_port, 'C-75'));		# 77
# ok 77 $>28001CD75CD7543#

my $data = "";
my $response = "B6B7BMGE";
## $main::config_parms{debug} = "x10";
is_ok($data = receive_ti103($serial_port));		# 78
#! not ok 78
is_ok($data eq $response); 				# 79
#! not ok 79
is_ok(40 == dim_decode_ti103("GE"));			# 80
# ok 80

is_ok(45 == dim_decode_ti103("A3"));			# 81
# ok 81

is_ok(10 == dim_decode_ti103("E9"));			# 82
# ok 82

is_ok(60 == dim_decode_ti103("N3"));			# 83
# ok 83

is_ok(50 == dim_decode_ti103("ID"));			# 84
# ok 84

is_ok(0 == dim_decode_ti103("M5"));			# 85
# ok 85

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(35 == dim_decode_ti103("O4"));			# 86
# ok 86

is_ok(15 == dim_decode_ti103("C3"));			# 87
# ok 87

is_ok(75 == dim_decode_ti103("FA"));			# 88
# ok 88

is_ok(85 == dim_decode_ti103("L9"));			# 89
# ok 89

is_ok(95 == dim_decode_ti103("P4"));			# 90
# ok 90

is_ok(send_ti103($serial_port, 'C1&P25'));		# 91
#! not ok 91

is_bad(send_ti103($serial_port, 'C&P05'));		# 92
#! not ok 92 $>28001CX0005CX00051D#

is_ok(send_ti103($serial_port, 'M4'));			# 93
# ok 93 $>28001M04M04BF#

## $main::config_parms{debug} = "x10";
is_ok(send_ti103($serial_port, 'OPRESET_DIM2'));	# 94
# ok 94 $>28001DIM18DIM18E3#

is_bad(send_ti103($serial_port, 'C1&P'));		# 95
# ok 95

is_bad(send_ti103($serial_port, 'C1&PA5'));		# 96
# ok 96

is_ok(send_ti103($serial_port, 'C1&P5'));		# 97
#! not ok 97

is_bad(send_ti103($serial_port, 'C1&P105'));		# 98
# ok 98

undef $serial_port;

print "Failures detected in test\n" if $fail;
