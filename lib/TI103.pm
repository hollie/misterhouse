package ControlX10::TI103;

#-----------------------------------------------------------------------------
#
# An X10 ACT TI-103 interface, used by Misterhouse ( http://misterhouse.net )
#
# Uses the Windows or Posix SerialPort.pm functions by Bill Birthisel,
#    available on CPAN
#
#-----------------------------------------------------------------------------
use strict;
use vars
  qw($VERSION $LOGFILE $DEBUG @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $POWER_RESET);

require Exporter;

@ISA    = qw(Exporter);
@EXPORT = qw( send_ti103 receive_ti103 read_ti103 dim_decode_ti103 ping_ti103);
@EXPORT_OK   = qw();
%EXPORT_TAGS = (
    FUNC => [
        qw( send_ti103   receive_ti103
          read_ti103   dim_decode_ti103
          ping_ti103   send_buffer )
    ]
);

Exporter::export_ok_tags('FUNC');

$EXPORT_TAGS{ALL} = \@EXPORT_OK;
($VERSION) = q$Revision$ =~ /: (\S+)/; # Note: cvs version reset when we moved to sourceforge
$DEBUG   = 0;
$LOGFILE = "$main::config_parms{data_dir}/logs/TI103.log";

#### Package variable declarations ####

sub send_ti103 {

    #    print "\$";
    return unless ( 2 == @_ );

    #    print ">";
    return ControlX10::TI103::send(@_);
}

sub receive_ti103 {
    return unless ( 1 == @_ );
    return ControlX10::TI103::receive_buffer(shift);
}

sub read_ti103 {
    return unless ( 2 == @_ );
    return ControlX10::TI103::read(@_);
}

sub dim_decode_ti103 {
    return unless ( 1 == @_ );
    return ControlX10::TI103::dim_level_decode(shift);
}

sub ping_ti103 {
    return unless ( 1 == @_ );
    return ControlX10::TI103::ping(shift);
}

sub receive_buffer {
    my ($serial_port) = @_;

    $LOGFILE =
      "$main::config_parms{data_dir}/logs/TI103.$main::Year_Month_Now.log";
    if ( exists $main::Debug{x10} ) {
        $DEBUG = ( $main::Debug{x10} >= 1 ) ? 1 : 0;
    }

    # Lets not wait for data (use no_block option), or we loop too long and mh slows way down

    # let the 0xc3 ack take hold ... emperically derived ... 1/2 misses at 20 ms
    #   - increase from 40 to 80, based on other TI103s.
    select undef, undef, undef, 80 / 1000;

    my $data;
    return undef unless $data = &read( $serial_port, 1 );

    my @bytes = split //, $data;

    print "receive buffer data=$data.\n" if $DEBUG;

    return $data;
}

my %X10Preset2 = (
    "M" => 0,
    "N" => 1,
    "O" => 2,
    "P" => 3,
    "C" => 4,
    "D" => 5,
    "A" => 6,
    "B" => 7,
    "E" => 8,
    "F" => 9,
    "G" => 10,
    "H" => 11,
    "K" => 12,
    "L" => 13,
    "I" => 14,
    "J" => 15,
);

my %X10Preset = (
    "M7" => 0,
    "ED" => 5,
    "EC" => 10,
    "C7" => 15,
    "KD" => 20,
    "K4" => 25,
    "O7" => 30,
    "OA" => 35,
    "G6" => 40,
    "AF" => 45,
    "AA" => 50,
    "I6" => 55,
    "NF" => 60,
    "N2" => 65,
    "F6" => 70,
    "DB" => 75,
    "D2" => 80,
    "LE" => 85,
    "PB" => 90,
    "P8" => 95
);

my %X10Unit = (
    "1" => "01",
    "2" => "02",
    "3" => "03",
    "4" => "04",
    "5" => "05",
    "6" => "06",
    "7" => "07",
    "8" => "08",
    "9" => "09",
    "A" => "10",
    "B" => "11",
    "C" => "12",
    "D" => "13",
    "E" => "14",
    "F" => "15",
    "G" => "16",
    "J" => "ON",
    "K" => "OFF",
    "O" => "AUN",
    "P" => "AUF"
);

sub x10dup {
    my ($str) = @_;
    return $str . $str;
}

sub buffer_blk {
    my ( $serial_port, $str ) = @_;
    push @{ $serial_port->{buffer} }, $str;

    # Only send if this is the start of a new queue,
    #  otherwise, let the queue drain once a second
    #  via check_ti103_...
    if ( $#{ $serial_port->{buffer} } == 0 ) {
        &send_buffer($serial_port);
    }
    else {
        print &main::print_log("TI103 buffering $str") if $DEBUG;
    }

    return 1;
}

sub send_buffer {
    my ($serial_port) = @_;
    my ( $data, $ok );

    $ok = ( $#{ $serial_port->{buffer} } > -1 );

    while ($ok) {
        $data = ${ $serial_port->{buffer} }[0];
        print &main::print_log("TI103 sending buffer: $data") if $DEBUG;
        $ok = &sendblk( $serial_port, $data );

        if ( $ok == 1 ) {
            print &main::print_log("TI103 buffered item sent ok") if $DEBUG;
            shift @{ $serial_port->{buffer} };
            $ok = ( $#{ $serial_port->{buffer} } > -1 );
        }
        elsif ( $ok == 0 ) {

            # No info back from controller - erase buffer
            print &main::print_log("TI103 - no response after send - bad")
              if $DEBUG;
            undef @{ $serial_port->{buffer} };
        }
        else {
            # Received a '2', aka TI103 full
            print &main::print_log("TI103 - full, held buffer") if $DEBUG;
            $ok = 0;
        }
    }
}

sub sendblk {
    my ( $serial_port, $str ) = @_;
    my $data     = "\$>28001" . $str;
    my $retval   = 1;
    my $cksum    = 0;
    my $n_char   = "";
    my @loc_char = split( //, $data );
    foreach $n_char (@loc_char) {
        $cksum += ord($n_char);
    }
    $data = sprintf( "%s%02X#", $data, $cksum % 256 );
    return 0 unless $data;
    print &main::print_log("TI103 send: $data") if $DEBUG;
    print &main::print_log("Bad ti103 data send transmition")
      unless length($data) == $serial_port->write($data);
    print &main::print_log("send:$data") if $DEBUG;

    $data = &read( $serial_port, 0, 1 );
    print &main::print_log("TI103 recv: $data") if $DEBUG;

    if ( $data eq "" ) { $retval = 0; }    # 0 = no data	        ('perm' err)
    if ( $data =~ /\!S0..#/ ) {
        $retval = 2;
    }                                      # 2 = buf err, buffer full (tmp err)
    if ( $data =~ /\?..#/ ) {
        $retval = 2;
    }                                      # 2 = CRC err, retransmit  (tmp err)
                                           # else 1=success           (no err)

    return $retval;
}

#
# the TI103 can take X10 commands in fragments.
#  So just parse the command string in peices and send each peice individually.
#
sub send {
    my ( $serial_port, $X10String ) = @_;

    my $X10Cmd = "";
    my $ret    = 1;

    &main::print_log("TI103.pm: X10Command[$X10String]") if $DEBUG;

    $X10String = uc($X10String);

    $X10String =~ s/ALL_LIGHTS_OFF/#01/;
    $X10String =~ s/EXTENDED_CODE/#02/;
    $X10String =~ s/EXTENDED_DATA/#03/;
    $X10String =~ s/HAIL_REQUEST/#04/;
    $X10String =~ s/HAIL_ACK/#05/;
    $X10String =~ s/PRESET_DIM1/#06/;
    $X10String =~ s/PRESET_DIM2/#07/;
    $X10String =~ s/STATUS_ON/#08/;
    $X10String =~ s/STATUS_OFF/#9/;
    $X10String =~ s/STATUS/#10/;
    $X10String =~ s/ALL_LIGHTS_ON/#11/;

    $X10String =~ s/BRIGHT/L/;
    $X10String =~ s/DIM/M/;
    $X10String =~ s/ALL_ON/O/;
    $X10String =~ s/ALL_OFF/P/;
    $X10String =~ s/ON/J/;
    $X10String =~ s/OFF/K/;

    $LOGFILE =
      "$main::config_parms{data_dir}/logs/TI103.$main::Year_Month_Now.log";
    if ( exists $main::Debug{x10} ) {
        $DEBUG = ( $main::Debug{x10} >= 1 ) ? 1 : 0;
    }
    my $Cmd = "";

    my @str = split( //, $X10String );
    my $ii = 0;
    while ( $str[$ii] ) {
        $Cmd = "";
        my $House = $str[ $ii++ ];

        # need to log an error here
        return unless $str[$ii];    # report incomplete data error
        if ( $House !~ /[A-P]/ ) {
            &main::print_log("TI103.pm: invalid house code [$House]") if $DEBUG;

            # &::logit($LOGFILE, "TI103 invalid house code [$House]");
            return;
        }
        my $Type = $str[ $ii++ ];
        if ( $Type =~ /[1-9A-GJKOP]/ ) {

            #print "Type=$Type Unit=$X10Unit{$Type}\n";
            $X10Cmd .= x10dup( $House . $X10Unit{$Type} );
        }
        elsif ( $Type =~ /[LM\-\+\&]/ ) {
            if ( $Type =~ /[\+\-]/ ) {    # Bright/Dim with Value
                if ( $str[$ii] =~ /[\{\[\(]/ ) { $ii++; }
                my $val = 0;
                while ( $str[$ii] =~ /[0-9]/ ) { $val .= $str[ $ii++ ]; }
                if ( $str[$ii] =~ /[\}\]\)]/ ) { $ii++; }
                return unless $val < 100;
                return unless $val > 0;
                $Type =~ s/\+/B/;
                $Type =~ s/\-/D/;

                #print "Type=$Type Val=$val\n";
                $X10Cmd .= x10dup( sprintf( "%s%s%02d", $House, $Type, $val ) );
            }
            elsif ( $Type eq "&" ) {    # Preset (1-63)
                return unless ( $str[ $ii++ ] eq "P" );
                if ( $str[$ii] =~ /[\{\[\(]/ ) { $ii++; }
                my $val = 0;
                while ( $str[$ii] =~ /[0-9]/ ) { $val .= $str[ $ii++ ]; }
                if ( $str[$ii] =~ /[\}\]\)]/ ) { $ii++; }
                $val = ( $val < 10 ) ? "0" . $val : $val;
                $X10Cmd .= x10dup( $House . "X" . $val );
            }
            elsif ( $Type eq "L" )
            {    # fixme  Brighten as per Misterhouse way (+40)
                $X10Cmd .= x10dup( $House . "B40" );
            }
            elsif ( $Type eq "M" ) { # fixme Dimmer as per Misterhouse way (-40)
                $X10Cmd .= x10dup( $House . "D40" );
            }

            #Extended Code
            # $>28001 A[1]01 3F 31 A[1]013F31 2D#
        }
        elsif ( $Type =~ /[#]/ ) {
            my $val = 0;
            while ( $str[$ii] =~ /[0-9]/ ) { $val .= $str[ $ii++ ]; }
            if ( $val == 1 ) {
                $X10Cmd .= x10dup( $House . "AUF" );
            }
            elsif ( $val == 2 ) {

                # $X10String =~ s/EXTENDED_CODE/#02/;
            }
            elsif ( $val == 3 ) {

                # $X10String =~ s/EXTENDED_DATA/#03/;
            }
            elsif ( $val == 4 ) {
                $X10Cmd .= x10dup( $House . "HRQ" );
            }
            elsif ( $val == 5 ) {
                $X10Cmd .= x10dup( $House . "HAK" );
            }
            elsif ( $val == 6 ) {

                # $X10String =~ s/PRESET_DIM1/#06/;
                #$X10Cmd .= x10dup(sprintf("DIM%02d", $X10Preset2{$House})) ;
                $X10Cmd .= x10dup( $House . "PR0" );
            }
            elsif ( $val == 7 ) {

                # $X10String =~ s/PRESET_DIM2/#07/;
                #$X10Cmd .= x10dup(sprintf("DIM%02d", ($X10Preset2{$House}+16))) ;
                $X10Cmd .= x10dup( $House . "PR1" );
            }
            elsif ( $val == 8 ) {
                $X10Cmd .= x10dup( $House . "SON" );
            }
            elsif ( $val == 9 ) {
                $X10Cmd .= x10dup( $House . "SOF" );
            }
            elsif ( $val == 10 ) {
                $X10Cmd .= x10dup( $House . "SRQ" );
            }
            elsif ( $val == 11 ) {
                $X10Cmd .= x10dup( $House . "ALN" );
            }
            else {
                &main::print_log("TI103.pm: invalid Macro code [$val]")
                  if $DEBUG;

                # &::logit($LOGFILE, "TI103 invalid Macro code [$House]");
                return;
            }

        }
        else {
            &main::print_log("TI103.pm: invalid Type code [$Type]") if $DEBUG;

            # &::logit($LOGFILE, "TI103 invalid Type code [$Type]");
            return;
        }
    }

    if ( buffer_blk( $serial_port, $X10Cmd ) ) {
        &main::print_log(
            "TI103.pm: SendX10 Complete X10 command received [$Cmd]")
          if $DEBUG;
        return 1;
    }

    #&main::print_log("TI103.pm: Invalid TI103 command [@_]") if $DEBUG;
    # &::logit($LOGFILE, "TI103 invalid command [@_]");
    return;
}

sub read {
    my ( $serial_port, $no_block, $no_power_fail_check ) = @_;
    my $data;

    # Note ... for dim commands > 30, this will time out after 30*50=1.5 seconds
    # No harm done, but we would rather not wait :)
    my $tries = ($no_block) ? 1 : 30;

    $LOGFILE =
      "$main::config_parms{data_dir}/logs/TI103.$main::Year_Month_Now.log";
    if ( exists $main::Debug{x10} ) {
        $DEBUG = ( $main::Debug{x10} >= 1 ) ? 1 : 0;
    }

    while ( $tries-- ) {
        print "." if $DEBUG and !$no_block;
        if ( $data = $serial_port->input ) {
            my $data_d = unpack( 'C', $data );
            printf( "\nTI103 data=%s\n", $data_d ) if $DEBUG;
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

    print "No data received from ti103\n" if ( $DEBUG and !$no_block );
    return undef;
}

sub dim_level_decode {
    my ($code) = @_;

    my %table_hcodes =
      qw(A 0110  B 1110  C 0010  D 1010  E 0001  F 1001  G 0101  H 1101
      I 0111  J 1111  K 0011  L 1011  M 0000  N 1000  O 0100  P 1100);
    my %table_dcodes =
      qw(1 0110  2 1110  3 0010  4 1010  5 0001  6 1001  7 0101  8 1101
      9 0111 10 1111 11 0011 12 1011 13 0000 14 1000 15 0100 16 1100
      A 1111  B 0011  C 1011  D 0000  E 1000  F 0100  G 1100);

    # Convert bit string to decimal
    my $level_b = $table_hcodes{ substr( $code, 0, 1 ) }
      . $table_dcodes{ substr( $code, 1, 1 ) };
    my $level_d = unpack( 'C', pack( 'B8', $level_b ) );

    # Varies from 36 to 201, by 11, then to 210 as a max.
    # 16 different values.  Round to nearest 5%, max of 95.
    my $level_p =
      int( 100 * $level_d / 211 );    # Do not allow 100% ... not a valid state?
    $level_p = $level_p - ( $level_p % 5 );
    print "TI103 debug: dim_code=$code leveld=$level_d level_p=$level_p\n"
      if $DEBUG;
    return $level_p;
}

sub reset_ti103 {
    return unless ( 1 == @_ );        # requires port number to reset
}

sub ping {
    my ($serial_port) = @_;
    my $ri_on         = 0xeb;
    my $ack           = 0x00;
    my $done          = 0x55;
    my $checksum;
    my $counter;
    my $maxcounter = 10000;

    $serial_port->write("$>28001HRQ00#");

    $counter = 0;
    do {
        $checksum = $serial_port->input;
        $counter++;
    } until ( ($checksum) || ( $counter == $maxcounter ) );

    return 0 if ( $counter == $maxcounter );

    print "ti103::ping - checksum: got: 0x", unpack( 'H2', $checksum ), "\n"
      if $DEBUG;
    print "ti103::ping - counter=$counter\n" if $DEBUG;
    return 1;
}

return 1;    # for require
__END__

=pod

=head1 NAME

ControlX10::TI103 - Perl extension for X10 'ActiveHome' Controller

=head1 SYNOPSIS

  use ControlX10::TI103;

    # $serial_port is an object created using Win32::SerialPort
    #     or Device::SerialPort depending on OS
    # my $serial_port = setup_serial_port('COM10', 4800);

  $data = &ControlX10::TI103::receive_buffer($serial_port);
  $data = &ControlX10::TI103::read($serial_port, $no_block);
  $percent = &ControlX10::TI103::dim_level_decode('GE'); # 40%

  &ControlX10::TI103::send($serial_port, 'A1'); # Address device A1
  &ControlX10::TI103::send($serial_port, 'AJ'); # Turn device ON
    # House Code 'A' present in both send() calls

  &ControlX10::TI103::send($serial_port, 'B'.'ALL_OFF');
    # Turns All lights on house code B off

=head1 DESCRIPTION

The TI103 is a bi-directional X10 controller that connects to a serial
port and transmits commands via AC power line to X10 devices. This
module translates human-readable commands (eg. 'A2', 'AJ') into the
Interface Communication Protocol accepted by the TI103.

This code is based heavily on CM11.pm.


=item read

This checks for an incoming transmission. It will return "" for no input.
It is largely untested.

=head1 EXPORTS

The B<send_ti103>, B<receive_ti103>, B<read_ti103>, and B<dim_decode_ti103>
functions are exported by default starting with Version 2.09.
They are identical to the "fully-qualified" names and accept the same
parameters. The I<export on request> tag C<:FUNC> is maintained for
compatibility (but deprecated).

  use ControlX10::TI103;
  send_ti103($serial_port, 'A1');            # send() - address
  send_ti103($serial_port, 'AJ');            # send() - function
  $data = receive_ti103($serial_port);           # receive_buffer()
  $data = read_ti103($serial_port, $no_block);       # read()
  $percent = dim_decode_ti103('GE');         # dim_level_decode()

=head1 AUTHORS

David H. Lynch Jr.  dhlii@dlasys.net  http://dlasys.net:8888

=head1 COPYRIGHT

Copyright (C) 2006 David H. Lynch Jr. All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. 1 January 2006.

=cut
