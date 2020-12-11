#!/usr/bin/perl
# formerly named test_cm17_xxx.plx with separate linux/win versions

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
use ControlX10::CM17 qw( send_cm17 0.05 );
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

$serial_port->databits(8);
$serial_port->baudrate(4800);
$serial_port->parity("none");
$serial_port->stopbits(1);
$serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
$serial_port->handshake("none");
$serial_port->write_settings || die "Could not set up port\n";

# CM17 does not care about parameters unless pass-through port used

my $reps = 2;
while ($reps-- > 0) {
    print "-------\n\n";
    print "Sending A1 and A2 ON\n";
    send_cm17($serial_port, 'A1J');
    sleep 1;
    send_cm17($serial_port, 'A2J');
    sleep 2;
    print "Sending A2 DIM\n";
    send_cm17($serial_port, 'AM');
    send_cm17($serial_port, 'AM');
    send_cm17($serial_port, 'AM');
    send_cm17($serial_port, 'AM');
    send_cm17($serial_port, 'AM');
    sleep 2;
    print "Sending A1 and A2 OFF\n";
    send_cm17($serial_port, 'A1K');
    sleep 1;
    send_cm17($serial_port, 'A2K');
    sleep 1;
}

$serial_port->close || die "\nclose problem with $port\n";
undef $serial_port;
