
=begin comment

X10_RF_powerline.pm

This module contains routines called by X10_RF.pm to determine if a
group of RF data bytes represents a valid powerline type command and
to decompose that data and set the state of the X10 device specified
by the command to the state specified by the command.

Bill Young

=cut

use strict;

package X10_RF;

use X10_RF;

#------------------------------------------------------------------------------

# Map of house codes sent in RF data to normal house codes.
my @hcodes = (
    'M', 'E', 'C', 'K', 'O', 'G', 'A', 'I',
    'N', 'F', 'D', 'L', 'P', 'H', 'B', 'J'
);

#------------------------------------------------------------------------------

# Subroutine: rf_is_powerline
#	Determine if <nbytes> represents a valid powerline style command.

sub rf_is_powerline {
    my ( $initial_checksum_good, @nbytes ) = @_;

    # Each pair of bytes must be a complement of each other.  The top three
    # bits in the first byte are always zero and the top two bits of the
    # third byte are always zero.
    return ( $initial_checksum_good
          && ( $nbytes[0] & ( BIT5 | BIT6 | BIT7 ) ) == 0
          && ( $nbytes[2] & ( BIT6 | BIT7 ) ) == 0
          && ( $nbytes[2] ^ $nbytes[3] ) == 0xff );
}

#------------------------------------------------------------------------------

# Subroutine: rf_process_powerline
#	Given a valid powerline style command in <nbytes>, set the state of
#	the device specified by the command to the state specfied by the
#	command.
#	<module> indicates the source of the request (mr26/w800)
#	<bbytes> is an array of binary strings for <nbytes> items.

sub rf_process_powerline {
    my ( $module, @nbytes, @bbytes ) = @_;

    my $uc_module = uc $module;
    my $lc_module = lc $module;

    # Layout of bytes/bits for powerline commands:
    #
    # 1st byte:
    #
    # NORMAL                             INTENSITY BIT SET
    # ---------------------------------- -----------------------------------
    # 7 always 0
    # 6 always 0
    # 5 always 0
    # 4 unit code bit 1                   0=bright/dim, 1=alloff/on
    # 3 unit code bit 0                   0=bright or alloff, 1=dim or allon
    # 2 off (0=off command, 1=on command) 0
    # 1 unit code bit 2 for all but RW724 0
    # 0 intensity (0=on/off cmd, 1=bri/dim/allon/alloff cmd)
    #
    # 2nd byte:
    #
    # complement of 1st byte
    #
    # 3rd byte:
    #
    # 7 always 0
    # 6 always 0
    # 5 unit  code bit 3
    # 4 unit  code bit 2 for RW724
    # 3 house code bit 3
    # 2 house code bit 2
    # 1 house code bit 1
    # 0 house code bit 0
    #
    # 4th byte:
    #
    # complement of 3rd byte

    # Check to see if this sequence is something that we can handle.  The
    # X-10 wireless units protocol document specifies that bits 5-7 of the
    # 1st byte are supposed to always be zero.  Also, it seems that nothing
    # uses bits 6-7 of the 3rd byte (tested above to indicate we're in
    # powerline mode).  Bit 1 of 1st byte is bit 2 of the unit code for the
    # HR12A, but bit 4 of 3rd byte is used for bit 2 of the unit code on
    # the RW724.  So, we'll make sure that they are not both on.
    if (   ( $nbytes[0] & ( BIT5 | BIT6 | BIT7 ) )
        || ( ( $nbytes[0] & BIT1 ) && ( $nbytes[2] & BIT4 ) ) )
    {

        &::print_log( "${uc_module}: invalid powerline data: "
              . "$bbytes[0] $bbytes[1] $bbytes[2] $bbytes[3]" );
        return undef;
    }

    my ( $off_bit, $intensity_bit, $not_all_bit, $dim_bit, $hn, $un );
    my ( $cmd, $state );

    # Get the house code number.
    $hn = $nbytes[2] & 0x0F;

    # Determine if this is an ON/OFF command or a BRIGHT/DIM command
    # and what unit it applies to.
    $intensity_bit = ( $nbytes[0] & BIT0 ) != 0;
    if ($intensity_bit) {    # Bright/Dim
        $un = 0;

        $off_bit     = 'N/A';
        $dim_bit     = ( $nbytes[0] & BIT3 ) != 0;    # Dim
        $not_all_bit = ( $nbytes[0] & BIT4 ) != 0;    # Not all on/off
        if ($not_all_bit) {
            $cmd = $dim_bit ? 'dim' : 'bright';
        }
        else {
            $cmd = $dim_bit ? 'allon' : 'alloff';
        }
    }
    else {                                            # On/Off
            # Build up the unit number.  Note that different RF
            # transmitters use different bits for bit 2.
        $un = 0;

        # From byte 1.
        $un = $un | BIT0 if $nbytes[0] & BIT3;
        $un = $un | BIT1 if $nbytes[0] & BIT4;
        $un = $un | BIT2 if $nbytes[0] & BIT1;    # HR12A (normal)

        # From byte 3.
        $un = $un | BIT2 if $nbytes[2] & BIT4;    # RW724 (abnormal)
        $un = $un | BIT3 if $nbytes[2] & BIT5;

        $un++;                                    # Increment to make 1 based

        $dim_bit     = 'N/A';
        $not_all_bit = 'N/A';
        $off_bit     = ( $nbytes[0] & BIT2 ) != 0;
        $cmd         = $off_bit ? 'off' : 'on';
    }

    if ( $main::Debug{$lc_module} ) {
        &::print_log( sprintf "%s: reordered: byte 1: %s (0x%02x)",
            $uc_module, $bbytes[0], $nbytes[0] );
        &::print_log( sprintf "%s: reordered: byte 3: %s (0x%02x)",
            $uc_module, $bbytes[2], $nbytes[2] );
        &::print_log( sprintf "%s: intensity_bit = %s",
            $uc_module, $intensity_bit ? $intensity_bit : 0 );
        &::print_log( sprintf "%s: not_all_bit   = %s",
            $uc_module, $not_all_bit ? $not_all_bit : 0 );
        &::print_log( sprintf "%s: dim_bit       = %s",
            $uc_module, $dim_bit ? $dim_bit : 0 );
        &::print_log( sprintf "%s: off_bit       = %s",
            $uc_module, $off_bit ? $off_bit : 0 );
    }

    # Build the state to send off for processing.
    my $h = $hcodes[$hn];
    my $u = ( $un <= 9 ) ? $un : chr( ord('A') + $un - 10 );

    if    ( $cmd eq 'on' )     { $state = "X${h}${u}${h}J"; }
    elsif ( $cmd eq 'off' )    { $state = "X${h}${u}${h}K"; }
    elsif ( $cmd eq 'bright' ) { $state = "X${h}L"; }
    elsif ( $cmd eq 'dim' )    { $state = "X${h}M"; }
    elsif ( $cmd eq 'allon' )  { $state = "X${h}O"; }
    elsif ( $cmd eq 'alloff' ) { $state = "X${h}P"; }
    else {
        &::print_log( "${uc_module}: unimplemented X10 command: "
              . "$bbytes[0] $bbytes[1] $bbytes[2] $bbytes[3]" );
        return undef;
    }

    if ( $main::Debug{$lc_module} ) {
        &::print_log(
            sprintf "%s: STATE %s%s %s (%s)",
            $uc_module, $h, ( $un == 0 ) ? '' : $un,
            $state, $cmd
        );
    }

    # Set states on X10_Items.
    &main::process_serial_data( $state, undef, 'rf' );

    # Set state of all MR26/W800 and X10_RF_Receiver objects.
    &rf_set_receiver( $module, $state );

    return $state;
}

#------------------------------------------------------------------------------

#
# $Log: X10_RF_powerline.pm,v $
# Revision 1.1  2004/03/23 02:27:09  winter
# *** empty log message ***
#
#

# vim: sw=4

1;

