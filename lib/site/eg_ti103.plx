#!/usr/bin/perl
# created from eg_cm11.plx by David H. Lynch Jr. <dhlii@dlasys.net>

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
    $port = shift @ARGV || "/dev/ttyS0";
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

my $reps = 2;
while ($reps-- > 0) {
    print "-------\n\n";
    receive_ti103($serial_port) ;

    print "Sending L1 On OFF\n";
    send_ti103($serial_port, 'L1');
    send_ti103($serial_port, 'LK');
    sleep 1;
    send_ti103($serial_port, 'LJ');
    sleep 2;
    send_ti103($serial_port, 'L1OFF');
    send_ti103($serial_port, 'L1ON');
    send_ti103($serial_port, 'L1LK');
    send_ti103($serial_port, 'L1LJ');

    print "Sending L2 On OFF\n";
    send_ti103($serial_port, 'L2');
    send_ti103($serial_port, 'LK');
    sleep 1;
    send_ti103($serial_port, 'LJ');
    sleep 2;
    send_ti103($serial_port, 'L2OFF');
    send_ti103($serial_port, 'L2ON');
    send_ti103($serial_port, 'L2LK');
    send_ti103($serial_port, 'L2LJ');

    print "Sending P3 On OFF\n";
    send_ti103($serial_port, 'P3');
    send_ti103($serial_port, 'PK');
    sleep 1;
    send_ti103($serial_port, 'PJ');
    sleep 2;
    send_ti103($serial_port, 'P3OFF');
    send_ti103($serial_port, 'P3ON');
    send_ti103($serial_port, 'P3PK');
    send_ti103($serial_port, 'P3PJ');

    print "Sending P5 On OFF\n";
    send_ti103($serial_port, 'P5');
    send_ti103($serial_port, 'PK');
    sleep 1;
    send_ti103($serial_port, 'PJ');
    sleep 2;
    send_ti103($serial_port, 'P5OFF');
    send_ti103($serial_port, 'P5ON');
    send_ti103($serial_port, 'P5PK');
    send_ti103($serial_port, 'P5PJ');


    print "Sending E1 On OFF\n";
    send_ti103($serial_port, 'E1');
    send_ti103($serial_port, 'EK');
    sleep 1;
    send_ti103($serial_port, 'EJ');
    sleep 2;
    send_ti103($serial_port, 'E1OFF');
    send_ti103($serial_port, 'E1ON');
    send_ti103($serial_port, 'E1EK');
    send_ti103($serial_port, 'E1EJ');

    print "Sending H1 On OFF\n";
    send_ti103($serial_port, 'H1');
    send_ti103($serial_port, 'HK');
    sleep 1;
    send_ti103($serial_port, 'HJ');
    sleep 2;
    send_ti103($serial_port, 'H1OFF');
    send_ti103($serial_port, 'H1ON');
    send_ti103($serial_port, 'H1HK');
    send_ti103($serial_port, 'H1HJ');
}

$serial_port->close || die "\nclose problem with $port\n";
undef $serial_port;
