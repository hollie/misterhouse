
=begin comment

X10_RF_tv_remote.pm

This module contains routines called by X10_RF.pm to determine if a
group of RF data bytes represents a valid TV remote type command and
to decompose that data and set the state of the TV remote item to the
state specified by the command.

Bill Young

=cut

use strict;

package X10_RF;

use X10_RF;

#------------------------------------------------------------------------------

# Map of remote codes to discriptive state codes.
#
# Notes:
#   UR51A Function codes:
#    - OK and Ent are same, PC and Subtitle are same,
#    - Chan buttons and Skip buttons are same
my %vcodes = qw(0f Power 2b PC 6b Title 5c Display 4a Enter 1b Return
  ab Up cb Down 4b Left 8b Right 6d Menu 93 Exit 1c Rew
  0d Play 1d FF ff Record 0e Stop 4e Pause 4f Recall
  41 1 42 2 43 3 44 4 45 5 46 6 47 7 48 8 49 9
  5d AB 40 0 02 Ch+ 03 Ch- 07 Vol- 06 Vol+ 05 Mute);

#------------------------------------------------------------------------------

# Subroutine: rf_is_tv_remote
#	Determine if <nbytes> represents a valid TV remote style command.

sub rf_is_tv_remote {
    my ( $initial_checksum_good, @nbytes ) = @_;

    # The first two bytes must be complements of each other and contain
    # the command sent by the remote.  Byte 3 is always 0x77 and byte 4
    # is always 0x88.
    return ( $initial_checksum_good
          && $nbytes[2] == 0x77
          && $nbytes[3] == 0x88 );
}

#------------------------------------------------------------------------------

# Subroutine: rf_process_tv_remote
#	Given a valid TV remote style command in <nbytes>, set the state of
#	the TV remote item to the state specfied by the command.
#	<module> indicates the source of the request (mr26/w800)
#	<bbytes> is an array of binary strings for <nbytes> items.

sub rf_process_tv_remote {
    my ( $module, @nbytes, @bbytes ) = @_;

    my $uc_module = uc $module;
    my $lc_module = lc $module;

    my ( $cmd, $state );

    # Layout of bytes for TV remote commands:
    #
    # 1st byte: Command
    # 2nd byte: Complement of 1st byte
    # 3rd byte: 0x77
    # 4th byte: Complement of 3rd byte (0x88)

    # TV/VCR style remote control (UR51A, etc.)
    $cmd = $nbytes[0];
    $state = $vcodes{ unpack( "H2", chr($cmd) ) };
    unless ( defined $state ) {
        &::print_log(
            sprintf "%s: unimplemented tv remote command: "
              . "0x%02x (%s %s %s %s)",
            $uc_module, $cmd,       $bbytes[0],
            $bbytes[1], $bbytes[2], $bbytes[3]
        );
        return undef;
    }

    if ( $main::Debug{$lc_module} ) {
        &::print_log( sprintf "%s: tv remote: state = %s (0x%02x)",
            $uc_module, $state, $cmd );
    }

    # Set state of all MR26/W800 and X10_RF_Receiver objects.
    &rf_set_receiver( $module, $state );

    # Set the state of any items or classes associated with this device.
    &rf_set_RF_Item( $module, "tv remote", "no remote defined",
        "remote", undef, $state );

    return $state;
}

#------------------------------------------------------------------------------

#
# $Log: X10_RF_tv_remote.pm,v $
# Revision 1.1  2004/03/23 02:27:09  winter
# *** empty log message ***
#
#

# vim: sw=4

1;

