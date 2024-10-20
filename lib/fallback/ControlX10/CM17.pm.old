package ControlX10::CM17;

use strict;
use vars qw($VERSION $DEBUG @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT= qw();
@EXPORT_OK= qw( send_cm17 );
$VERSION = '0.06';
$DEBUG = 0;

#-----------------------------------------------------------------------------
#
# An X10 firecracker interface, used by Misterhouse ( http://misterhouse.net )
#
# Uses the Windows or Posix SerialPort.pm functions by Bill Birthisel,
#    available on CPAN
# Protocol documented at: http://www.x10.com/manuals/cm17a_proto.txt
#                         http://www.excel.net/~dpeterse/cm17a.htm
#
#-----------------------------------------------------------------------------

my %table_hcodes = qw(A 01100 B 01110 C 01000 D 01010 E 10000 F 10010 G 10100 H 10110 
                      I 11100 J 11110 K 11000 L 11010 M 00000 N 00010 O 00100 P 00110);

my %table_dcodes = qw(1J 00000000000 1K 00000100000 2J 00000010000 2K 00000110000
                      3J 00000001000 3K 00000101000 4J 00000011000 4K 00000111000
                      5J 00001000000 5K 00001100000 6J 00001010000 6K 00001110000
                      7J 00001001000 7K 00001101000 8J 00001011000 8K 00001111000
                      9J 10000000000 9K 10000100000 AJ 10000010000 AK 10000110000
                      BJ 10000001000 BK 10000101000 CJ 10000011000 CK 10000111000
                      DJ 10001000000 DK 10001100000 EJ 10001010000 EK 10001110000
                      FJ 10001001000 FK 10001101000 GJ 10001011000 GK 10001111000 
                      L  00010001000 M  00010011000 O  00010010000 N  00010100000 P 00010000000);

sub send_cm17 {
    return unless ( 2 == @_ );
    return ControlX10::CM17::send (@_);
}

sub send {
    my ($serial_port, $house_code) = @_;
    
    my ($house, $code) = $house_code =~ /(\S)(\S+)/;

    if (defined $main::config_parms{debug}) {
        $DEBUG = ($main::config_parms{debug} eq 'X10') ? 1 : 0;
    }
    print "CM17: $serial_port house=$house code=$code\n" if $DEBUG;
    
    my $data = $table_hcodes{$house};
    unless ($data) {
        print "CM17.pm error. Invalid house code: $house\n";
        return;
    }
                                # Check for +-## brighten/dim commands (e.g. 7+5  F-95)
                                # Looks like it takes 7 levels to go full bright/dim (14%).
    if ($code =~ /(\S)([\+\-])(\d+)/) {
        my $device= $1;
        my $dir   = $2;
        my $level = $3;
	my $ok;
        print "Running CM17 dim/bright loop: device=$device $dir=$dir level=$level\n" if $DEBUG;
                                # The CM17 dim/bright has not device address, so we must first
                                # address the device (need to make sure it is on anyway)
        &send($serial_port, $house . $device . 'J');
        my $code = ($dir eq '+') ? 'L' : 'M';
        while ($level >= 0) {
            $ok = &send($serial_port, $house . $code);
            $level -= 14;
        }
        return $ok;
    }

                                # Check for #J/#K or L/M/O/N
    my $data2 = $table_dcodes{$code};
    $data2 = $table_dcodes{substr($code, 1)} unless $data2;

    unless ($data2) {
        print "CM17.pm error. Invalid device code: $code.\n";
        return;
    }
                                # Header + data + footer = 40 bits
    &send_bits($serial_port, '1101010110101010' . $data . $data2 . '10101101'); 
}

sub send_bits {
    my ($serial_port, $bits) = @_;
    my @bits = split //, $bits;

                                # Reset the device
    $serial_port->dtr_active(0);
    $serial_port->rts_active(0);
    select (undef, undef, undef, .100); # How long??


                                # Turn the device on
    $serial_port->dtr_active(1);
    $serial_port->rts_active(1);
    select (undef, undef, undef, .20);  # How long??

    print "CM17: Sending: " if $DEBUG;
    while (@bits) {
        my $bit = shift @bits;
        
        if ($bit) {
            $serial_port->pulse_dtr_off(1);
            print "1" if $DEBUG;
        }
        else {
            $serial_port->pulse_rts_off(1);
            print "0" if $DEBUG;
        }
    }
                                # Leave the device on till switch occurs ... emperically derived 
                                #  - 50->70  ms seemed to be the minnimum
    $serial_port->dtr_active(1);
    $serial_port->rts_active(1);
    select (undef, undef, undef, .150);

    print " done\n" if $DEBUG;

                                # Turn the device off
    $serial_port->dtr_active(0);
    $serial_port->rts_active(0);

}

1;           # for require
__END__

=head1 NAME

ControlX10::CM17 - Perl extension for 'FireCracker' RF Transmitter

=head1 SYNOPSIS

  use ControlX10::CM17;

    # $serial_port is an object created using Win32::SerialPort
    #     or Device::SerialPort depending on OS
    # my $serial_port = setup_serial_port('COM10', 4800);

  &ControlX10::CM17::send($serial_port, 'A1J');
    # Turns device A1 On
  &ControlX10::CM17::send($serial_port, 'A1K');
    # Turns device A1 Off
  &ControlX10::CM17::send($serial_port, 'BO');
    # Turns All lights on house code B off

=head1 DESCRIPTION

The FireCracker (CM17A) is a send-only X10 controller that connects
to a serial port and transmits commands via RF to X10 transceivers.

The FireCracker derives its power supply from either the RTS or
DTR signals from the serial port. At least one of these signals
must be high at all times to ensure that power is not lost from
the FireCracker. The signals are pulsed to transmit a bit (DTR
for '1' and RTS for '0'). The normal rx/tx read/write lines are
not used by the device - but are passed through to allow another
serial device to be connected (as long as it does not require
hardware handshaking).

A 40-bit command packet consists of a constant 16 bit header, a constant
8 bit footer, and 16 data bits. The data is subdivided into a 5 bit
address I<$house> code (A-P) and an 11 bit I<$operation>. There are "ON"
commands for 16 units per I<$house> code (1J, 2J...FJ, GJ) and similar "OFF"
commands (1K, 2K...FK, GK). A B<send> decodes a parameter string that
combines B<$house$operation> into a single instruction. In addition to
I<$operation> commands that act on individual units, there are some that
apply to the entire I<$house> code or to previous commands.

	$operation	FUNCTION
	    L		Brighten Last Light Programmed 14%
	    M		Dim Last Light Programmed 14%
	    N		All Lights Off
	    O		All Lights On
	    P		All Units Off

Starting with Version 0.6, a series of Brighten or Dim Commands may be
combined into a single I<$operation> by specifying a signed amount of
change desired after the unit code. An "ON" command will be sent to
select the unit followed by at least one Brighten/Dim. The value will
round to the next larger magnitude if not a multiple of 14%.
	
  &ControlX10::CM17::send($serial_port, 'A3-10');
      # outputs 'A3J','AM' - at least one dim

  &ControlX10::CM17::send($serial_port, 'A3-42');
      # outputs 'A3J','AM','AM','AM' - even multiple of 14

  &ControlX10::CM17::send($serial_port, 'AF-45');
      # outputs 'AFJ','AL','AL','AL','AL' - round up if remainer

=head1 EXPORTS

Nothing is exported by default. A B<send_cm17> subroutine can be exported
on request. It is identical to C<&ControlX10::CM17::send()>, and
accepts the same parameters.

  use ControlX10::CM17 qw( send_cm17 0.05 );
  send_cm17($serial_port, 'A1J');

=head1 AUTHORS

Bruce Winter  bruce@misterhouse.net  http://misterhouse.net

CPAN packaging by Bill Birthisel wcbirthisel@alum.mit.edu
http://members.aol.com/bbirthisel

=head1 SEE ALSO

mh can be download from http://misterhouse.net

You can subscribe to the mailing list at http://www.onelist.com/subscribe.cgi/misterhouse

You can view the mailing list archive at http://www.onelist.com/archives.cgi/misterhouse

perl(1).

Win32::SerialPort and Device::SerialPort

=head1 COPYRIGHT

Copyright (C) 1999 Bruce Winter. All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. 11 October 1999.

=cut
