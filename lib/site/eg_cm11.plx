#!/usr/bin/perl
# formerly named test_cm11_xxx.plx with separate linux/win versions

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
use ControlX10::CM11 qw( send_cm11 receive_cm11 2.03 );
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
$serial_port->baudrate(4800);
$serial_port->parity("none");
$serial_port->stopbits(1);
$serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
$serial_port->handshake("none");
$serial_port->write_settings || die "Could not set up port\n";

my $reps = 2;
while ($reps-- > 0) {
    print "-------\n\n";
    receive_cm11($serial_port);
    print "Sending A1 On OFF\n";
    send_cm11($serial_port, 'A1');
    send_cm11($serial_port, 'AJ');
    sleep 1;
    send_cm11($serial_port, 'AK');
    sleep 2;
}

$serial_port->close || die "\nclose problem with $port\n";
undef $serial_port;
