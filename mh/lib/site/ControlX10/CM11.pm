package ControlX10::CM11;
#-----------------------------------------------------------------------------
#
# An X10 ActiveHome interface, used by Misterhouse ( http://misterhouse.net )
#
# Uses the Windows or Posix SerialPort.pm functions by Bill Birthisel,
#     available on CPAN
#
#-----------------------------------------------------------------------------
use strict;
use vars qw($VERSION $DEBUG @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

require Exporter;

@ISA = qw(Exporter);
@EXPORT= qw();
@EXPORT_OK= qw();
%EXPORT_TAGS = (FUNC    => [qw( send_cm11   receive_cm11
                                read_cm11   dim_decode_cm11 )]);

Exporter::export_ok_tags('FUNC');

$EXPORT_TAGS{ALL} = \@EXPORT_OK;

#### Package variable declarations ####

$VERSION = '2.07';
$DEBUG = 0;
my $Last_Dcode;

sub send_cm11 {
    return unless ( 2 == @_ );
    return ControlX10::CM11::send ( @_ );
}

sub receive_cm11 {
    return unless ( 1 == @_ );
    return ControlX10::CM11::receive_buffer ( shift );
}

sub read_cm11 {
    return unless ( 2 == @_ );
    return ControlX10::CM11::read ( @_ );
}

sub dim_decode_cm11 {
    return unless ( 1 == @_ );
    return ControlX10::CM11::dim_level_decode ( shift );
}

                                # These tables are used in sending data
my %table_hcodes  = qw(A 0110  B 1110  C 0010  D 1010  E 0001  F 1001  G 0101  H 1101
                       I 0111  J 1111  K 0011  L 1011  M 0000  N 1000  O 0100  P 1100);
my %table_dcodes  = qw(1 0110  2 1110  3 0010  4 1010  5 0001  6 1001  7 0101  8 1101
                       9 0111 10 1111 11 0011 12 1011 13 0000 14 1000 15 0100 16 1100
                       A 1111  B 0011  C 1011  D 0000  E 1000  F 0100  G 1100);
my %table_fcodes  = qw(J 0010  K 0011  M 0100  L 0101  O 0001  P 0000
                       ALL_OFF 0000  ALL_ON  0001  ON 0010 OFF 0011 DIM 0100 BRIGHT 0101 
                       -10 0100 -20 0100 -30 0100 -40 0100 
                       -15 0100 -25 0100 -35 0100 -45 0100 -5  0100
                       -50 0100 -60 0100 -70 0100 -80 0100 -90 0100 
                       -55 0100 -65 0100 -75 0100 -85 0100 -95 0100 
                       +10 0101 +20 0101 +30 0101 +40 0101 
                       +15 0101 +25 0101 +35 0101 +45 0101 +5  0101
                       +50 0101 +60 0101 +70 0101 +80 0101 +90 0101
                       +55 0101 +65 0101 +75 0101 +85 0101 +95 0101
                       ALL_LIGHTS_OFF 0110 EXTENDED_CODE 0111 HAIL_REQUEST 1000 HAIL_ACK 1001
                       PRESET_DIM1 1010 PRESET_DIM2 1011 EXTENDED_DATA 1100
                       STATUS_ON 1101 STATUS_OFF 1110 STATUS 1111);


                                # These tables are used in receiving data
my %table_hcodes2 = qw(0110 A  1110 B  0010 C  1010 D  0001 E  1001 F  0101 G  1101 H
                       0111 I  1111 J  0011 K  1011 L  0000 M  1000 N  0100 O  1100 P);
my %table_dcodes2 = qw(0110 1  1110 2  0010 3  1010 4  0001 5  1001 6  0101 7  1101 8
                       0111 9  1111 A  0011 B  1011 C  0000 D  1000 E  0100 F  1100 G);
my %table_fcodes2 = qw(0010 J  0011 K  0100 L  0101 M  0001 O  0000 P 
                       0111 Z 1010 PRESET_DIM1 1011 PRESET_DIM2
                       1101 STATUS_ON   1110 STATUS_OFF 1111 STATUS);


sub receive_buffer {
    my ($serial_port) = @_;

    if (defined $main::config_parms{debug}) {
        $DEBUG = ($main::config_parms{debug} eq 'X10') ? 1 : 0;
    }

    my $pc_ready = pack('C', 0xc3);
    print "Bad cm11 pc_ready transmition\n" unless 1 == $serial_port->write($pc_ready);

    # Lets not wait for data (use no_block option), or we loop too long and mh slows way down

    # let the 0xc3 ack take hold ... emperically derived ... 1/2 misses at 20 ms
    select undef, undef, undef, 40 / 1000;


    my $data;
    return undef unless $data = &read($serial_port, 1); 
#   my $data = &read($serial_port);

    my @bytes = split //, $data;

    my $length = shift @bytes;
    my $mask   = shift @bytes;

    $length = unpack('C', $length);
    $mask   = unpack('B8', $mask);
    my $data_h = unpack('H*',  $data);
    print "receive buffer length=$length, mask=$mask, data_h=$data_h.\n" if $DEBUG;

    my ($house, $function, $device, $i, $extended_count);

    undef $data;
    foreach my $byte (@bytes) {
              # Send extended data into MH as untranslated hex.           
        if ($extended_count) {
           $data .= unpack('H*', $byte);
           --$extended_count;
           ++$i;
        }
        else {
           my $bits = unpack('B8', $byte);
           my $house_bits = substr($bits, 0, 4);
           my $code_bits  = substr($bits, 4, 4);
           print "CM11 error, not a valid house code: $house_bits\n" unless $house = $table_hcodes2{$house_bits};
           if (substr($mask, -(++$i), 1)) {
               print "CM11 error, not a valid function code: $code_bits at byte $i value $bits\n" unless $function = $table_fcodes2{$code_bits};
#          print "function=$house$function\n";

                                   # Add device code back in, since this is not included in status :(
               $function = $Last_Dcode . $function if $function =~ /^STATUS/;
                                   # Handle Vehicle Interface RF Receiver extended code - assume length of 3 for extended
               $extended_count = 3 if $function == 'Z';

               $data .= $house . $function;
                 print "CM11 db: data=$data\n" if $DEBUG;
           }
           else {
               print "CM11 error, not a valid device code: $code_bits\n" unless $device = $table_dcodes2{$code_bits};
#          print "device=$house$device\n";
               $data .= $house . $device;
           }
        }
#       print "byte=$byte, $bits\n";
    }
    return $data;
}

sub format_data {
    my ($house_code) = @_;

    print "CM11 send data=$house_code\n" if $DEBUG;

    my ($house, $code, $house_bits, $header, $code_bits, $function, $dim_level);
    my ($extended, $extended_string, $extended_checksum);

    ($house, $code) = $house_code =~ /(\S)(\S+)/;
    $house = uc($house);
    $code  = uc($code);

    unless ($house_bits = $table_hcodes{$house}) {
        print "CM11 error, invalid house code: $house\n";
        return;
    }

# $code can be
#    1-9,A-G  for Device code
#    d_xyz.   for Extended code xyz for device d
#    xyz      for Function codes, including +-## for bright/dim

                                # Test for extended code
                                #  - format is D&P## where D is device code and ## is the preset dim level
    if (my($dcode, $extended_data) = $code =~ /(\S)&P(\d+)/) {
        unless ($code_bits = $table_dcodes{$dcode}) {
            print "CM11 error, invalid device in extended code.  device=$dcode code=$code\n";
            return;
        }
        unless (($extended_data >= 0) && ($extended_data < 65)) {
            print "CM11 error, invalid extended code. code=$code\n";
            return;
        }
        $code_bits = '0111';    # Extended code
#       print "db cb=$code_bits\n";
        $function = '1';        # Extended transmitions are a function
        $extended = '1';
        $dim_level = 0;         # Dim level is not applicable to extended transmitions.

                                # Hard codeded preset for now ... 

        my $extended_junk = '00000101'; # This is not documented, so I have no idea why it is needed! 
                                        # Emperically derived by looking at ActiveHome errata.

        my $extended_code = '00110001'; # Type=3 => Control Modules  Func=1 => Preset Receiver

                                # Convert from bit to string
        my $b3 = pack('B8', $extended_junk);
        my $b4 = pack('C1', $extended_data);
        my $b5 = pack('B8', $extended_code);
        $extended_string = $b3 . $b4 . $b5;
        my $b3c = unpack('C', $b3);
        my $b4c = unpack('C', $b4);
        my $b5c = unpack('C', $b5);
        $extended_checksum = $b3c + $b4c + $b5c;
        printf ("CM11 ed=%d, b345=0x%0.2x,0x%0.2x,0x%0.2x ex=%s cs=0x%0.2x\n",
	        $extended_data, $b3c, $b4c, $b5c, $extended_string,
	        $extended_checksum) if $DEBUG;
    }
                                # Test for device code
    elsif ($code_bits = $table_dcodes{$code}) {
        $function = '0';
        $extended = '0';
        $dim_level = 0;
        $Last_Dcode = $code;    # This is desperate :)
    }
                                # Test for function code
    elsif ($code_bits = $table_fcodes{$code}) {
        $function = '1';
        $extended = '0';
        if ($code eq 'DIM' or $code eq 'M' or $code eq 'BRIGHT' or $code eq 'L') {
            $dim_level = 50;
        }
        elsif ($code =~ /^[+-]\d\d$/) {
            $dim_level = abs($code);
        }
        else {
            $dim_level = 0;
        }
    }
    else {
        print "CM11 error, invalid cm11 x10 code: $code\n";
        return;
    }

    my $dim = int($dim_level * 22 / 100);   # 22 levels = 100%
    $header = substr(unpack('B8', pack('C', $dim)), 3);

    $header .= '1';             # Bit 2 is always set to a 1 to ensure synchronization
    $header .= $function;       # 0 for address,  1 for function
    $header .= $extended;       # 0 for standard, 1 for extended transmition
    
                                # Convert from bit to string
    my $b1 = pack('B8', $header);
    my $b2 = pack('B8', $house_bits . $code_bits);

                                # Calculate checksum
    my $b1d = unpack('C', $b1);
    my $b2d = unpack('C', $b2);
    my $checksum = ($b1d + $b2d) & 0xff;

    my $data = $b1 . $b2;

    if ($extended) {
        $data .= $extended_string;
        $checksum = ($checksum + $extended_checksum) & 0xff;
    }

    printf("CM11 dim=$dim header=$header hb=$house_bits cb=$code_bits " .
           "bd=0x%0.2x,0x%0.2x checksum=0x%0.2x\n", 
           $b1d, $b2d, $checksum) if $DEBUG;

    return $data, $checksum;
    
}    

sub send {
    my ($serial_port, $house_code) = @_;

    if (defined $main::config_parms{debug}) {
        $DEBUG = ($main::config_parms{debug} eq 'X10') ? 1 : 0;
#       &Win32::SerialPort::debug(1) if $DEBUG;
    }

    my ($data_snd, $checksum) = &format_data($house_code);
    return unless $data_snd;

    my $retry_cnt = 0;
  RETRY:
    print "CM11 send: ", unpack('H*', $data_snd), "\n" if $DEBUG;

    print "Bad cm11 data send transmition\n" unless length($data_snd) == $serial_port->write($data_snd);
    my $data_rcv = &read($serial_port);
    my $data_d = unpack('C', $data_rcv);

                                # Unrelated incoming data ... process and re-start
                                # Note:  Some checksums will be 0x5a or 0xa5 ... skip this test if so
    if (($data_d == 0x5a or $data_d == 0xa5) and !($checksum == 0x5a or $checksum == 0xa5)) {
        print "Data received while xmiting data ... will receive and retry\n";
        &receive_buffer($serial_port);
        goto RETRY if $retry_cnt++ < 3;
    }

    if ($checksum != $data_d) {
        print "Bad checksum in cm11 send: cs1=$checksum cs2=$data_d.  Will retry\n";
        goto RETRY if $retry_cnt++ < 3;
    }

    print "CM11 ack\n" if $DEBUG;
    my $pc_ok    = pack('C', 0x00);
    print "Bad cm11 acknowledge send transmition\n" unless 1 == $serial_port->write($pc_ok);

    $data_rcv = &read($serial_port);
    my $data_d = unpack('C', $data_rcv);

    if ($data_d == 0x55) {
        print "CM11 done\n" if $DEBUG;
    }
    # Unrelated incoming data ... process
    elsif ($data_d == 0x5a or $data_d == 0xa5) {
        print "Data received while xmiting data ... receive and retry\n";
        &receive_buffer($serial_port);
        goto RETRY if $retry_cnt++ < 3;
    }

    if (defined $main::config_parms{debug}) {
#       &Win32::SerialPort::debug(0) if $DEBUG;
    }

    return $data_d;
}

sub read {
    my ($serial_port, $no_block) = @_;
    my $data;
                                # Note ... for dim commands > 20, this will time out after 20*40=1 seconds 
                                # No harm done, but we would rather not wait :)
    my $tries = ($no_block) ? 1 : 20;

    if (defined $main::config_parms{debug}) {
        $DEBUG = ($main::config_parms{debug} eq 'X10') ? 1 : 0;
    }

    while ($tries--) {
        print "." if $DEBUG and !$no_block;
        if ($data = $serial_port->input) {
            my $data_d = unpack('C', $data);
#           printf("rcv data=%s, %x.\n", $data, $data_d);
#           my $pc_ready = pack('C', 0xc3);
#           $serial_data = "$pc_ready";
#           print "serial1 out=$serial_data results=", $serial_port->write($serial_data), ".\n" if $DEBUG;
            printf("\nCM11 data=%s hex=%0.2lx\n", $data_d, $data_d) if $DEBUG;

                                # If we received the power-fail string (0xa5), reset with a blank macro command
                                #  - Protocol.txt says to send macros string, but that did not work.
            if ($data_d == 165) {

#55 to 48   timer download header (0x9b)
#47 to 40   Current time (seconds)
#39 to 32   Current time (minutes ranging from 0 to 119)
#31 to 23   Current time (hours/2, ranging from 0 to 11)
#23 to 16   Current year day (bits 0 to 7)
#15 Current year day (bit 8)
#14 to 8        Day mask (SMTWTFS)
#7 to 4     Monitored house code
#3      Reserved
#2      Battery timer clear flag
#1      Monitored status clear flag
#0      Timer purge flag

                my ($Second, $Minute, $Hour, $Mday, $Month, $Year, $Wday, $Yday) = localtime time;
                my $localtime = localtime time;
                $Wday = 2 ** (7 - $Wday);
                if ($Yday > 255) {
                    $Yday -= 256;
                    $Wday *= 2;
                }
                my $power_reset = pack('C7', 0x9b, 
                                       $Second,
                                       $Minute,
                                       $Hour,  
                                       $Yday,  
                                       $Wday,
                                       0x03);    # Not sure what is best here.  x10d.c did this.
            
                print "\nCM11 power fail detected.  Reseting the CM11 clock with:\n $localtime\n $power_reset.\n";
                print "  results:", $serial_port->write($power_reset), ".\n";
                select undef, undef, undef, 50 / 1000;
                my $checksum = $serial_port->input; # Receive, but ignore, checksum
                print "  checksum=$checksum.\n";
                my $pc_ok = pack('C', 0x00);
                print "Bad cm11 checksum acknowledge\n" unless 1 == $serial_port->write($pc_ok);
#                undef $data;
            }

            return $data;
        }
                # If we do not do this, we may get endless error messages.
        else {
            $serial_port->reset_error;
        }
        
        if ($tries) {
            select undef, undef, undef, 50 / 1000;
        }
    }

    print "No data received from cm11\n" if ($DEBUG and !$no_block);
    return undef;
}

sub dim_level_decode {
    my ($code) = @_;

    my %table_hcodes = qw(A 0110  B 1110  C 0010  D 1010  E 0001  F 1001  G 0101  H 1101
                          I 0111  J 1111  K 0011  L 1011  M 0000  N 1000  O 0100  P 1100);
    my %table_dcodes = qw(1 0110  2 1110  3 0010  4 1010  5 0001  6 1001  7 0101  8 1101
                          9 0111 10 1111 11 0011 12 1011 13 0000 14 1000 15 0100 16 1100
                          A 1111  B 0011  C 1011  D 0000  E 1000  F 0100  G 1100);

    if (defined $main::config_parms{debug}) {
        $DEBUG = ($main::config_parms{debug} eq 'X10') ? 1 : 0;
    }

                                # Convert bit string to decimal
    my $level_b = $table_hcodes{substr($code, 0, 1)} . $table_dcodes{substr($code, 1, 1)};
    my $level_d = unpack('C', pack('B8', $level_b));
                                # Varies from 36 to 201, by 11, then to 210 as a max.
                                # 16 different values.  Round to nearest 5%, max of 95.
    my $level_p = int(100 * $level_d / 211); # Do not allow 100% ... not a valid state?
    ## print "CM11 debug1: levelb=$level_b level_p=$level_p\n" if $DEBUG;
    $level_p = $level_p - ($level_p % 5);
    print "CM11 debug: dim_code=$code leveld=$level_d level_p=$level_p\n" if $DEBUG;
    return $level_p;
}

return 1;           # for require
__END__

=pod

=head1 NAME

ControlX10::CM11 - Perl extension for X10 'ActiveHome' Controller

=head1 SYNOPSIS

  use ControlX10::CM11;

    # $serial_port is an object created using Win32::SerialPort
    #     or Device::SerialPort depending on OS
    # my $serial_port = setup_serial_port('COM10', 4800);

  $data = &ControlX10::CM11::receive_buffer($serial_port);
  $data = &ControlX10::CM11::read($serial_port, $no_block);
  $percent = &ControlX10::CM11::dim_level_decode('GE'); # 40%

  &ControlX10::CM11::send($serial_port, 'A1'); # Address device A1
  &ControlX10::CM11::send($serial_port, 'AJ'); # Turn device ON
    # House Code 'A' present in both send() calls

  &ControlX10::CM11::send($serial_port, 'B'.'ALL_OFF');
    # Turns All lights on house code B off

=head1 DESCRIPTION

The CM11A is a bi-directional X10 controller that connects to a serial
port and transmits commands via AC power line to X10 devices. This
module translates human-readable commands (eg. 'A2', 'AJ') into the
Interface Communication Protocol accepted by the CM11A.

=over 4

=item send command

This transmits a two-byte message containing dim and house information
and either an address or a function. Checksum and acknowledge handshaking
is automatic. The command accepts a string parameter. The first character
in the string must be a I<House Code> in the range [A..P] and the rest of
the string determines the type of message. Intervening whitespace is not
currently permitted between the I<House Code> and the I<Operation>. This
may change in the future.

    STRING  ALTERNATE_STRING    FUNCTION
     1..9               Unit Address
     A..G               Unit Address
       J        ON      Turn Unit On
       K        OFF     Turn Unit Off
       L        BRIGHT      Brighten Last Light Programmed 5%
       M        DIM     Dim Last Light Programmed 5%
       O        ALL_ON      All Units On
       P        ALL_OFF     All Units Off

There are also functions without "shortcut" letter commands:

    ALL_LIGHTS_OFF  EXTENDED_CODE   EXTENDED_DATA
    HAIL_REQUEST    HAIL_ACK    PRESET_DIM1
    PRESET_DIM2 STATUS_ON   STATUS_OFF
    STATUS

Dim and Bright functions can also take a signed value in the
range [-95,-90,...,-10,-5,+5,+10,...,+90,+95].

  ControlX10::CM11::send($serial_port,'A1'); # Address device A1
  ControlX10::CM11::send($serial_port,'AJ'); # Turn device ON
  ControlX10::CM11::send($serial_port,'A-25'); # Dim to 25%

=item send extended function

Starting in version 2.04, extended commands may be sent to devices that
support the enhanced X10 protocol. If you have one of the newer (more
expensive) LM14A/PLM21 2 way X10 pro lamp modules, you can set it directly
to a specific brightness level using a Preset Dim extended code.

The 64 extended X10 Preset Dim codes are commanded by appending C<&##> to
the unit address where C<##> is a number between 1 and 63.

  ControlX10::CM11::send($serial_port,'A5&P16'); # Dim A5 to 25%

A partial translation list for the most important levels:

	&P##	 %		&P##	 %		&P##	 %
	  0	  0		 13	 20		 44	 70
	  1	  2		 16	 25		 47	 75
	  2	  4		 19	 30		 50	 80
	  3	  5		 25	 40		 57	 90
	  6	 10		 31	 50		 61	 95
	  9	 15		 38	 60		 63	100

There is another set of Preset Dim commands that are used by some modules
(e.g. the RCS TX15 thermostat). These 32 non-extended Preset Dim codes can
be coded directly, using the following table:

      0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15   PRESET_DIM1
      M  N  O  P  C  D  A  B  E  F  G  H  K  L  I  J

      16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  PRESET_DIM2
      M  N  O  P  C  D  A  B  E  F  G  H  K  L  I  J

This usage, and the responses assigned to each command, are device specific.
For example, the following commands enable preset value 18:

  ControlX10::CM11::send($serial_port,'M4');           # Address thermostat
  ControlX10::CM11::send($serial_port,'OPRESET_DIM2'); # Select preset 18


Starting in version 2.07, incoming extended data is also processed.
The first character will be the I<House Code> in the range [A..P].
The next character will be I<Z>, indicating extended data.
The remaining data will be the extended data.


=item read

This checks for an incoming transmission. It will return "" for no input.
It also tests for a received a "power fail" message (0xa5). If it detects
one, it automatically sends the command/data to reset the CM11 clock. If
the C<$no_block> parameter is FALSE (0, "", or undef), the B<read> will retry
for up to a second at 50 millisecond intervals. With C<$no_block> TRUE,
the B<read> checks one time for available data.

  $data = &ControlX10::CM11::read($serial_port, $no_block);

=item receive_buffer

This command handles the upload response to an "Interface Poll Signal"
message (0x5a) B<read> from the CM11. The module sends "ready" (0xc3) and
receives up to 10 bytes. The first two bytes are size and description of
the remaining bytes. These are used to decode the data bytes, but are not
returned by the B<receive_buffer> function. Each of the data bytes is
decoded as if it was a B<send> command from an external CM11 or equivalent
external source (such as an RF keypad).

  $data = &ControlX10::CM11::receive_buffer($serial_port);
      # $data eq "A2AK" after an external device turned off A2

Multiple house and unit addresses can appear in a single buffer.

  if ($data eq "B1BKA2AJ") {
      print "B1 off, A2 on\n";
  }

=item dim_level_decode

When the external command includes dim/bright information in addition to
the address and function, the B<dim_level_decode> function converts that
data byte (as processed by the B<receive_buffer> command) into percent.

  $data = &ControlX10::CM11::receive_buffer($serial_port);
      # $data eq "A2AMGE" after an external device dimmed A2 to 40%
  $percent = &ControlX10::CM11::dim_level_decode("GE");
      # $percent == 40

A more complex C<$data> input is possible.

  if ($data eq "B1B3B5B7B9BLLE") {
      print "House B Inputs 1,3,5,7,9 Brightened to 85%\n";
  }

The conversion between text_data and percent makes more sense to the code
than to humans. The following table gives representative values. Others
may be received from a CM11 and will be properly decoded.

        Percent Text        Percent Text
            0    M7        50    AA
            5    ED        55    I6
           10    EC        60    NF
           15    C7        65    N2
           20    KD        70    F6
           25    K4        75    DB
           30    O7        80    D2
           35    OA        85    LE
           40    G6        90    PB
           45    AF        95    P8

=back
    
=head1 EXPORTS

Nothing is exported by default. The B<send_cm11>, B<receive_cm11>,
B<read_cm11>, and B<dim_decode_cm11> functions can be exported on request
with the tag C<:FUNC>. They are identical to the "fully-qualified" names
and accept the same parameters.

  use ControlX10::CM11 qw( :FUNC 2.06 );
  send_cm11($serial_port, 'A1');            # send() - address
  send_cm11($serial_port, 'AJ');            # send() - function
  $data = receive_cm11($serial_port);           # receive_buffer()
  $data = read_cm11($serial_port, $no_block);       # read()
  $percent = dim_decode_cm11('GE');         # dim_level_decode()

=head1 AUTHORS

Bruce Winter  bruce@misterhouse.net  http://misterhouse.net

CPAN packaging by Bill Birthisel wcbirthisel@alum.mit.edu
http://members.aol.com/bbirthisel

=head1 SEE ALSO

mh can be download from http://misterhouse.net

You can subscribe to the mailing list at http://www.onelist.com/subscribe.cgi/misterhouse

You can view the mailing list archive at http://www.onelist.com/archives.cgi/misterhouse

Win32::SerialPort and Device::SerialPort from CPAN

CM11A Protocol documentation available at http://www.x10.com

perl(1).

=head1 COPYRIGHT

Copyright (C) 1999 Bruce Winter. All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. 20 December 1999.

=cut
