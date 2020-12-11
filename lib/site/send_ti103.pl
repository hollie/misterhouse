#!/usr/bin/perl
# created from send_cm11.pl by David H. Lynch Jr. <dhlii@dlasys.net>

use lib './blib/lib','./lib';
use vars qw($OS_win $port);

######################### We start with some black magic to print on failure.

BEGIN { $| = 1;
        $OS_win = ($^O eq "MSWin32") ? 1 : 0;

            # This must be in a BEGIN in order for the 'use' to be conditional
        if ($OS_win) {
            eval "use Win32::SerialPort 0.17";
	    die "$@\n" if ($@);

        }
        else {
            eval "use Device::SerialPort 0.06";
	    die "$@\n" if ($@);
        }
} # End BEGIN

END {print "not ok\n" unless $loaded;}
use ControlX10::TI103 qw( send_ti103 receive_ti103 0.01 );
$loaded = 1;

######################### End of black magic.

use strict;

my $serial_port;

if ($OS_win) {
    $port = shift @ARGV || "COM1";
    $serial_port = Win32::SerialPort->new ($port,1);
}
else {
    $port = "/dev/ttyS0";
    # $port = shift @ARGV || "/dev/ttyS0";
    $serial_port = Device::SerialPort->new ($port,1);
}
die "Can't open serial port $port: $^E\n" unless ($serial_port);

$serial_port->error_msg(1);	# use built-in error messages
$serial_port->user_msg(0);
$serial_port->databits(8);
$serial_port->baudrate(19200);
$serial_port->parity("none");
$serial_port->stopbits(1);
$serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
$serial_port->handshake("none");
$serial_port->write_settings || die "Could not set up port\n";

receive_ti103($serial_port) ;

my $arg ;

foreach $arg (@ARGV) {
	my $reps = 2;
	while ($reps-- > 0) {
		send_ti103($serial_port, $arg);
	}
}

$serial_port->close || die "\nclose problem with $port\n";
undef $serial_port;
