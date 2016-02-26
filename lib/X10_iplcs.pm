use strict;

package X10_iplcs;

my ($state);

# ============================================================================

@X10_iplcs::ISA = ('Generic_Item');

sub startup {

    &::print_log("In IPLCS (Startup)\n") if $main::Debug{iplcs};

    &main::serial_port_create( 'iplcs', $main::config_parms{iplcs_port},
        4800, 'none', 'raw' );

    # Add hook only if serial port was created ok
    &::MainLoop_pre_add_hook( \&X10_iplcs::check_for_data, 1 )
      if $main::Serial_Ports{iplcs}{object};
    &main::print_log(
        "iplcs adding X10_iplcs-check_for_data into pre_add_hook\n")
      if $main::Serial_Ports{iplcs}{object};
}

#                                [       ][       ][       ]
# serial name=iplcs type= data2= ^B^BJ^@^V^B^BJ^A^S^B^BJ^@^V
#                                02 02 4A 00 16 = E1
#                                02 02 4A 01 13 = E Off
#                                02 02 4A 00 16 = E1
#                                [       ][       ][       ][       ]
# serial name=iplcs type= data2= ^B^BJ^@^V^B^BJ^A^S^B^BJ^@^V^B^BJ^A^S
#                                02 02 4A 00 16 = E1
#                                02 02 4A 01 13 = E Off
#                                02 02 4A 00 16 = E1
#                                02 02 4A 01 13 = E Off
#
# serial data2 doesn't seem to print out everything but we do get all the data
# serial name=iplcs type= data2=^B^BJ^@^V
# iplcs Chk: (024508024a0016)
# serial name=iplcs type= data2=^B^BJ^A^S
# iplcs Chk: (024508024a0113)
#
# 12/06/05 07:28:12 PM XE1EK: xE1 off
#
# This translates into

use constant X10ADDR => 0x00;
use constant X10CMD  => 0x01;

use constant STX => 0x02;

# Here we go ...
#
# start off with 02 <cmd> .....
# <cmd> will determine the number of bytes being sent (<cmd> != byte count)
# <cmd> = 0x40 - 0x4A & 0x4F
# 0x40 = Download
# 0x41 = Salad Text message <len> <message ...>
# 0x42 =
# 0x43 = Salad Text message <message ...> 0x03
# 0x44 =
use constant EVENT => 0x45;    # 0x45 = Event Report <Event> See Event Pg 49

# 0x46 =
# 0x47 =
# 0x48 =
use constant DREPORT =>
  0x49; # 0x49 = Debug report <Next Salad Addr hi> <addr lo> <Salad Instruction>
use constant RcvX10 => 0x4A;  # 0x4A = X10 receive <Addr(00)/Cmd(01)> <X10 Byte>
use constant RcvInsteon => 0x4F
  ; # 0x4F = Insteon Received <Event ID> <Insteon msg ...(9 or 23 bytes> See Pg 43

#        for Event IDs
#
# Insteon Event Handling
#
# 0x00
# 0x01
# 0x02
# 0x03 Insteon Message received
use constant ACK => 0x04;    # 0x04 Insteon ACK
use constant NAK => 0x05;    # 0x05 Insteon NAK

# 0x06 Insteon UnEnroll
# 0x07 Insteon Enroll
# 0x08 X10 Msg received
# 0x09 X10 Extended Message Received
# 0x0A
# 0x0B Midnight
# 0x0C 2AM
# 0x0D
# 0x0E
# 0x0F
# 0x10
# 0x11
# 0x12
# 0x13

# These tables are used in receiving data
my %table_hcodes2 = qw( 6 A  e B  2 C  a D 10 D 14 B
  1 E  9 F  5 G  d H 11 L 15 J
  7 I  f J  3 K  b L 12 P
  0 M  8 N  4 O  c P 13 H );

my %table_dcodes2 = qw( 6 1  e 2  2 3  a 4 10 4 14 2
  1 5  9 6  5 7  d 8 13 8
  7 9  f A  3 B  b C 11 C 15 A
  0 D  8 E  4 F  c G 12 G );

# I'm not sure what this is (next line) but I will leave it as is. NJC
# Yikes!  L and M are swapped!   If we fix it here, we also
# have to fix it elsewhere (maybe only in bin/mh, $f_code test)

my %table_fcodes2 = qw( 2 J  3 K
  4 L  5 M
  1 O  0 P
  6 *  7 Z
  8 *  9 *
  10 PRESET_DIM1
  11 PRESET_DIM2
  c *
  13 STATUS_ON
  14 STATUS_OFF
  15 STATUS );

# These tables are used in receiving data
my %table_hcodes = qw( 0110 A  1110 B  0010 C  1010 D
  0001 E  1001 F  0101 G  1101 H
  0111 I  1111 J  0011 K  1011 L
  0000 M  1000 N  0100 O  1100 P );
my %table_dcodes = qw( 0110 1  1110 2  0010 3  1010 4
  0001 5  1001 6  0101 7  1101 8
  0111 9  1111 A  0011 B  1011 C
  0000 D  1000 E  0100 F  1100 G );

# I'm not sure what this is but I will leave it as is.
# Yikes!  L and M are swapped!   If we fix it here, we also
# have to fix it elsewhere (maybe only in bin/mh, $f_code test)
my %table_fcodes = qw( 0010 J  0011 K
  0100 L  0101 M
  0001 O  0000 P
  0111 Z
  1010 PRESET_DIM1
  1011 PRESET_DIM2
  1101 STATUS_ON
  1110 STATUS_OFF
  1111 STATUS );

sub check_for_data {
    my ($self) = @_;

    my @bytes;
    my ( $bits, $byte, $hc, $house, $xkey, $kc, $b2, $last, $DEBUG );
    my ( $i, $j, $k );

    if ( exists $main::Debug{iplcs} ) {
        $DEBUG = ( $main::Debug{iplcs} >= 1 ) ? 1 : 0;
    }
    $DEBUG = 1;

    # used to hold 'progress text', useful for debugging
    my ($outputtext) = "Iplcs";

    &main::check_for_generic_serial_data('iplcs');    # ???
    return unless $main::Serial_Ports{iplcs}{data};

    #
    # $data (and $remainder) are in binary format, so we don't really want to
    # be displaying it if we can help it.
    #

    # First 4 bytes into $data the rest into $remainder
    #my ($data) = $main::Serial_Ports{iplcs}{data} =~ /(....)(.*)/;
    # This gets us a copy but doesn't drain the buffer
    my ($data) = $main::Serial_Ports{iplcs}{data};
    return unless $data;
    $main::Serial_Ports{iplcs}{data} = "";

    #return if($data eq "");

    #$main::Serial_Ports{W800RF}{iplcs} = $remainder; # ???
    my $hex = unpack "H*", $data;

    #printf("iplcs Chk: (%s)\n", $hex) if($DEBUG);

    # Recall that you can join the whole array together with a statement like $text = "@lines";
    #
    @bytes = unpack( '(C2)*', $data );

    $k    = @bytes;
    $byte = shift(@bytes);

    $last  = $state;
    $state = "";
    if ( $byte == STX ) {

        # 02 Next byte is one of the commands.
        $byte = shift(@bytes);
        if ( $byte == EVENT ) {

            # Events always preceed things like X10 Receive or Insteon Receive
            printf( "Event %s\n", substr( $hex, 4 ) ) if ($DEBUG);

            # 024508 024a0113
            $main::Serial_Ports{iplcs}{data} = substr( $data, 3 );
        }
        elsif ( $byte == RcvX10 ) {

            # -----------------------------------------------------------------------------------------------
            #  1 2 3 4
            # 024a0113
            $byte = shift(@bytes);    # X10 code Address(0)/Command(1)

            $b2    = shift(@bytes);         #
            $hc    = $b2 >> 4;
            $kc    = $b2 & 0x0f;
            $house = $table_hcodes2{$hc};

            if ( $byte == X10ADDR ) {

                # X10 Address i.e. A1
                $xkey = $table_dcodes2{$kc};
                $main::Serial_Ports{iplcs}{data} = substr( $data, 4 );    #
                $state = "X${house}${xkey}";

                print("X10 Address $house $xkey $state ($kc)\n") if ($DEBUG);

            }
            elsif ( $byte == X10CMD ) {

                # X10 Command i.e. AOn (or AJ)
                $xkey = $table_fcodes2{$kc};
                $main::Serial_Ports{iplcs}{data} = substr( $data, 4 );    #
                $state = "X${house}${xkey}";

                print("X10 Command $house $xkey $state ($kc)\n") if ($DEBUG);
            }
            else {
                # we received something else? I hope not
                printf( "X10 ??? %s\n", substr( $hex, 6 ) ) if ($DEBUG);
                $main::Serial_Ports{iplcs}{data} = substr( $data, 1 );
            }

            # -----------------------------------------------------------------------------------------------
        }
        elsif ( $byte == RcvInsteon ) {
            $byte = shift(@bytes);
            printf( "Insteon: %s\n", substr( $hex, 4 ) ) if ($DEBUG);
            $main::Serial_Ports{iplcs}{data} = ""
              ; # (FIX ME) For now I'll drain the buffer but I should rethink this
        }
        else {
            printf(
                "Unknown 0x%02x %s [0x%02x]\n",
                $byte, substr( $hex, 2 ),
                $bytes[1]
            );
            $main::Serial_Ports{iplcs}{data} = substr( $data, 1 ) if ($DEBUG);
        }
    }
    else {
        # --------------------------------------------------------------------
        printf( "GRRR X10_iplcs Chk: [%d] 0x%02x (%s)\n", @bytes, $byte, $hex )
          if ($DEBUG);

        # This is causing me a major problem. It fills the buffer with 0xFF
        # preceding the important data. It doesn't help drain the data at
        # all!
        #$main::Serial_Ports{iplcs}{data} = substr($data, 1);
        $i = 0;
        $j = length($data);    # Remember that you've shifted a byte above.
        if ( $j > 0 ) {
            $j = $j - 1;

            # if the string is FF ... 02... then figure out where 02 is
            # and return that to the buffer. Hmm, it might be possible that
            # we stomp any new data. But I doubt there is a good solution for
            # that.
            #	    while(($i < $j) & (shift(@bytes) != STX)) {
            #		$i++;
            #	    } # Find the fsrt STX (02) in the buffer
            # OK, this seems to work better
            do {
                $i++;
                print "$i.";
              } while ( ( $i <= $j ) && ( shift(@bytes) != STX ) )
              ;    # Find the first STX (02) in the buffer
            print "\n";
            my $ldata = substr( $data, $i );
            if ($DEBUG) {
                my $l2 = length($ldata);
                $hex = unpack "H*", $ldata;
                $data = $main::Serial_Ports{iplcs}{data};
                my $l3 = length($data);
                printf( "GRRR X10_iplcs Chk:[ %d vs. %d ]<%d> (%s)\n",
                    $j, $l2, $l3, $hex );
                $main::Serial_Ports{iplcs}{data} = $ldata . $data;
            }
            else {
                # We need to rewrite this debug statement, the next statement is now junk
                $main::Serial_Ports{iplcs}{data} = substr( $ldata, $i );

            }
        }
        else {
            $main::Serial_Ports{iplcs}{data} = "";
        }

        # --------------------------------------------------------------------
    }

    # Drain the buffer so we don't read more of that data!
    # sub process_serial_data ($event_data, $prev_pass, $source)

    if ($state) {
        print "State = $state\n" if ($DEBUG);

        # Send out that Xxx information
        &main::process_serial_data( $state, $last, "iplcs" );
    }

}

# ----------------------------------------------------------------------------
# 12/08/2005 - Only the ON and OFF seem to work properly. I've tried DIM and
#              PRESET DIMS but I'm not really decoding them. I'll have to work
#              on that.
# 12/26/2005 - Ran into a nasty little bug! The Grr error message pops up and
#              the buffer is filled with a ton of garbage (usually FF but I
#              sometimes see the real string way down in the buffer.
# GRRR iplcs Chk: 0xff (ff ... 024508024a001e024508024a011302450e02450f024510)[255]
# ----------------------------------------------------------------------------

=begin comment
iplcs Chk: (150246016688ff06)
GRRR iplcs Chk: 0x15 (150246016688ff06)[2]
GRRR iplcs Chk:     (150246016688ff06)[ 8 vs. 8 ]
iplcs Chk: (150246016688ff06)
GRRR iplcs Chk: 0x15 (150246016688ff06)[2]
GRRR iplcs Chk:     (150246016688ff06)[ 8 vs. 8 ]
=cut
