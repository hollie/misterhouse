#!/usr/bin/perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use lib './blib/lib','../blib/lib','./lib','../lib';
# can run from here or distribution base
use vars qw(%config_parms);

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..29\n"; }

END {print "not ok 1\n" unless $loaded;}
use ControlX10::CM17 qw( send_cm17 0.06 );
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use strict;

## emulate a CM17A and xx::SerialPort (test mode) for testing

package SerialStub;

sub new {
    my $class = shift;
    my $self  = {};
    $self->{bits} = "";
    return bless ($self, $class);
}

sub dtr_active {1}

sub rts_active {1}

sub pulse_dtr_off {
    my $self = shift;
    $self->{bits} .= "1";
    return shift;	# false unless nonzero time
}

sub pulse_rts_off {
    my $self = shift;
    $self->{bits} .= "0";
    return shift;	# false unless nonzero time
}

	# emulator only - not in xx::SerialPort
sub read_back_cmd {
    my $self = shift;
    my $count = 40 * (shift||1);
    my $size = length $self->{bits};
    unless ($count == $size) {
	print "Output wrong number of bits ($count) : $size\n";
        $self->{bits} = "";
	return;
    }
	# parse headers, etc.
    $self->{bits} = "";
    1;
}

######################### End CM17A emulator

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
$main::config_parms{debug} = "";

# end of preliminaries.

is_zero($ControlX10::CM17::DEBUG);			# 2
is_ok(send_cm17($serial_port, 'A1J'));			# 3
is_zero($ControlX10::CM17::DEBUG);			# 4
is_ok($serial_port->read_back_cmd);			# 5

$main::config_parms{debug} = "X10";
is_ok(send_cm17($serial_port, 'A9J'));			# 6
is_ok($ControlX10::CM17::DEBUG);			# 7
is_ok($serial_port->read_back_cmd);			# 8

$main::config_parms{debug} = "";
is_ok(send_cm17($serial_port, 'AGJ'));			# 9
is_zero($ControlX10::CM17::DEBUG);			# 10
is_ok($serial_port->read_back_cmd);			# 11

is_bad(send_cm17($serial_port, 'A2B'));			# 12
is_bad(send_cm17($serial_port, 'AHJ'));			# 13
is_bad(send_cm17($serial_port, 'Q1J'));			# 14
is_ok(ControlX10::CM17::send($serial_port, 'A1K'));	# 15
is_ok($serial_port->read_back_cmd);			# 16

if ($naptime) {
    print "++++ page break\n";
    sleep $naptime;
}

is_ok(send_cm17($serial_port, 'A2J'));			# 17
is_ok(send_cm17($serial_port, 'AM'));			# 18
is_ok(send_cm17($serial_port, 'AL'));			# 19
is_ok(send_cm17($serial_port, 'A1K'));			# 20
is_ok($serial_port->read_back_cmd(4));			# 21

is_ok(send_cm17($serial_port, 'AN'));			# 22
is_ok(send_cm17($serial_port, 'AO'));			# 23
is_ok(send_cm17($serial_port, 'AP'));			# 24
is_ok($serial_port->read_back_cmd(3));			# 25

## $main::config_parms{debug} = "X10";
is_ok(send_cm17($serial_port, 'A3-50'));		# 26
is_ok($serial_port->read_back_cmd(5));			# 27
is_ok(send_cm17($serial_port, 'AF+10'));		# 28
is_ok($serial_port->read_back_cmd(2));			# 29

undef $serial_port;

print "Failures detected in test\n" if $fail;
