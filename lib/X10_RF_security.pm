
=begin comment

X10_RF_security.pm

This module contains routines called by X10_RF.pm to determine if a
group of RF data bytes represents a valid security type command and
to decompose that data and set the state of the security device
specified by the command to the state specified by the command.

Bill Young

=cut

use strict;

package X10_RF;

use X10_RF;

#------------------------------------------------------------------------------

# Map of security codes to class:function identifiers.
my %scodes = qw(00 Sensor:AlertMax        01 Sensor:NormalMax
  02 Sensor:AlertTamperMax    03 Sensor:NormalTamperMax
  20 Sensor:AlertMin          21 Sensor:NormalMin
  22 Sensor:AlertTamperMin    23 Sensor:NormalTamperMin
  30 Sensor:Alert             31 Sensor:Normal
  32 Sensor:AlertTamper       33 Sensor:NormalTamper
  40 System:ArmAwayMax        41 System:Disarm
  42 Control:SecurityLightsOn 43 Control:SecurityLightsOff
  44 System:Panic
  50 System:ArmHomeMax        60 System:ArmAwayMin
  61 System:Disarm
  62 Control:LightsOn         63 Control:LightsOff
  64 System:Panic
  70 System:ArmHomeMin
  80 Sensor:AlertBattLowMax   81 Sensor:NormalBattLowMax
  a0 Sensor:AlertBattLowMin   a1 Sensor:NormalBattLowMin
  c0 System:Panic
);

#------------------------------------------------------------------------------

# Subroutine: rf_is_security
#	Determine if <nbytes> represents a valid security style command.

sub rf_is_security {
    my ( $initial_checksum_good, @nbytes ) = @_;

    # Layout of bytes for security commands:
    #
    # 1st byte: Command
    # 2nd byte: Complement of 1st byte
    # 3rd byte: Device ID
    # 4th byte: Top nibble is complement of top nibble of 3rd byte,
    #           bottom nibble is copy of bottom nibble of 3rd byte
    return ( $initial_checksum_good
          && ( $nbytes[2] & 0xf0 ) == ( ( $nbytes[3] & 0xf0 ) ^ 0xf0 )
          && ( $nbytes[2] & 0x0f ) == ( $nbytes[3] & 0x0f ) );
}

#------------------------------------------------------------------------------

# Subroutine: rf_process_security
#	Given a valid security style command in <nbytes>, set the state of
#	the device specified by the command to the state specfied by the
#	command.
#	<module> indicates the source of the request (w800)
#	<bbytes> is an array of binary strings for <nbytes> items.

sub rf_process_security {
    my ( $module, @nbytes, @bbytes ) = @_;

    my $uc_module = uc $module;
    my $lc_module = lc $module;

    my ( $cmd, $device_id, $state );

    # Determine the ID of the device and the command being requested.
    $cmd       = $nbytes[0];
    $device_id = $nbytes[2];

    # See if this is a command that we recognize.
    #   my $scode = $scodes{   unpack("H2", chr($cmd))};
    my $scode = $scodes{ lc( unpack( "H2", chr($cmd) ) ) };
    unless ( defined $scode ) {
        &::print_log(
            sprintf "%s: unimplemented security cmd device_id "
              . "= 0x%02x, cmd = 0x%02x (%s %s %s %s)",
            $uc_module, $device_id, $cmd, $bbytes[0],
            $bbytes[1], $bbytes[2], $bbytes[3]
        );
        return undef;
    }

    # Break out the class and the function.
    my ( $class, $function ) = split( /:/, $scode );

    # Build the state to send off for processing.
    $state = $function;

    my $class_id = lc $class;
    my $item_id = lc sprintf "%02x", $device_id;

    if ( $main::Debug{$lc_module} ) {
        &::print_log( sprintf "%s: security: device_id = 0x%02x, cmd = 0x%02x",
            $uc_module, $device_id, $cmd );
        &::print_log(
            sprintf "%s: security: class_id = %s, "
              . "item_id = %s, state = %s",
            $uc_module, $class_id, $item_id, $state );
    }

    # Set state of all MR26/W800 and X10_RF_Receiver objects.
    &rf_set_receiver( $module, $state );

    # Set the state of any items or classes associated with this device.
    &rf_set_RF_Item( $module, "security", "unmatched device 0x$item_id",
        $item_id, $class_id, $state );

    return $state;
}

#------------------------------------------------------------------------------

#
# $Log: X10_RF_security.pm,v $
# Revision 1.2  2006/01/29 20:30:17  winter
# *** empty log message ***
#
# Revision 1.1  2004/03/23 02:27:09  winter
# *** empty log message ***
#
#

# vim: sw=4

1;
