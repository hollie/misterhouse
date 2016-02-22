
=begin comment

This module contains common code used by the X10_MR26.pm and X10_W800.pm
(which is actually for the W800RF32 as opposed to the W800).  This module 
calls routines to identity and decode RF data and set the appropriate 
states.  To debug this code, add either "mr26" or "w800" to your debug 
ini parameter.   

It can read powerline control data via RF, TV/VCR control data via RF,
and security data via RF.  Note that W800RF32 can reads X10 security,
digimax, and rfxsensor data, but the MR26A cannot.

To monitor keys from an X10 TV/VCR RF remote (UR47A, UR51A, J20A, etc.),
(e.g. Play,Pause, etc), you can use something like this:

 $Remote  = new X10_MR26;
 $Remote -> tie_event('print_log "MR26 key: $state"');
 set $TV $state if $state = state_now $Remote;

For a more general way to handle TV/VCR RF remotes and X10 security
devices, see RF_Item.pm.

If you want to relay all the of the incoming powerline style RF data
back out to the powerline, use mh/code/common/x10_rf_relay.pl.

Bill Young

=cut

package X10_RF;

#------------------------------------------------------------------------------

use strict;

#------------------------------------------------------------------------------

# Bit masks for individual bits.
use constant BIT0 => 0x01;
use constant BIT1 => 0x02;
use constant BIT2 => 0x04;
use constant BIT3 => 0x08;
use constant BIT4 => 0x10;
use constant BIT5 => 0x20;
use constant BIT6 => 0x40;
use constant BIT7 => 0x80;

#------------------------------------------------------------------------------

use X10_RF_powerline;
use X10_RF_security;
use X10_RF_tv_remote;
use X10_RF_digimax;
use X10_RF_rfxsensor;

#------------------------------------------------------------------------------

# decode_rf_bytes
#
# Decode the four bytes of RF data and set the appropriate states.
#
# The first parameter should be the name of the calling module (mr26 or w800).
# The second parameter is an array of the four RF data bytes (see
# http://www.wgldesigns.com/dataformat.txt).  These bytes should be in
# the form of the original stream sent by a W800RF32 unit.  This routine will
# handle changing the order of the bytes and bits as specified by the
# above document.
#
# The routine returns the state it set to indicate that it successfully
# handled the data.  If the checksum on the bytes was bad, it will return
# "BADCHECKSUM".  If it just didn't know what to do with the data it
# parsed (i.e. a new command, it will return undef).

sub decode_rf_bytes {
    my ( $module, @bytes ) = @_;

    my $uc_module = uc $module;
    my $lc_module = lc $module;

    # Take the input data and convert it as specified X-10 wireless units
    # protocol document (note that the bits in the bytes are reversed and
    # that the bytes themselves are swapped - byte 1 is the 3rd physical
    # byte and byte 3 is the 1st physical byte).  Store the converted bytes
    # as integers instead of characters.
    my @nbytes;
    for ( my $i = 0; $i < 4; $i++ ) {
        my $j = ( $i < 2 ) ? 2 + $i : $i - 2;
        $nbytes[$j] = ord( pack( "B8", unpack( "b*", $bytes[$i] ) ) );
    }

    # Since the MR26 doesn't have the checksum bytes, we'll just manufacture
    # them here.  We can't just strip them out of the decode_rf_bytes routine
    # because decode_rf_bytes can also handle security data sent by a W800RF32,
    # which requires a unique forth byte.  Since the mr26 can't handle security
    # data, we don't need to worry about it.
    if ( $lc_module eq 'mr26' ) {
        $nbytes[1] = $nbytes[0] ^ 0xff;
        $nbytes[3] = $nbytes[2] ^ 0xff;
    }

    # Come up with binary representations of the bytes for use in messages.
    my @bbytes;
    for ( my $i = 0; $i < 4; $i++ ) {
        $bbytes[$i] = unpack( "B*", chr( $nbytes[$i] ) );
    }

    if ( $main::Debug{$lc_module} ) {
        &::print_log( sprintf "%s: reordered data: %02x %02x %02x %02x",
            $uc_module, $nbytes[0], $nbytes[1], $nbytes[2], $nbytes[3] );
    }

    # The first two bytes are always complements (Except for Digimax and rfxsensor).
    my $initial_checksum_good = ( ( $nbytes[0] ^ $nbytes[1] ) == 0xff );

    # Determine what type of device this command appears to have come from.
    if ( &rf_is_powerline( $initial_checksum_good, @nbytes ) ) {
        &::print_log("$lc_module: this is x10 powerline data")
          if ( $main::Debug{$lc_module} );
        return &rf_process_powerline( $module, @nbytes, @bbytes );

    }
    elsif ( &rf_is_tv_remote( $initial_checksum_good, @nbytes ) ) {
        &::print_log("$lc_module: this is tv remote data")
          if ( $main::Debug{$lc_module} );
        return &rf_process_tv_remote( $module, @nbytes, @bbytes );

    }
    elsif ( $lc_module ne 'mr26' ) {  # Can't receive the following with an MR26

        if ( &rf_is_security( $initial_checksum_good, @nbytes ) ) {
            &::print_log("$lc_module: this is x10 security data")
              if ( $main::Debug{$lc_module} );
            return &rf_process_security( $module, @nbytes, @bbytes );

        }
        elsif ( &rf_is_rfxsensor(@bytes) ) {
            &::print_log("$lc_module: this is rfxsensor data")
              if ( $main::Debug{$lc_module} );
            return &rf_process_rfxsensor( $module, @bytes );

        }
        elsif ( &rf_is_digimax210(@bytes) ) {
            &::print_log("$lc_module: this is digimax data")
              if ( $main::Debug{$lc_module} );
            return &rf_process_digimax210( $module, @bytes );
        }
    }

    # If we made it to here, then we don't know what to do with the command.
    if ( !$initial_checksum_good ) {
        &::print_log( "${uc_module}: bad initial checksum: "
              . "$bbytes[0] $bbytes[1] $bbytes[2] $bbytes[3]" )
          if $main::Debug{$lc_module};
    }
    else {
        &::print_log( "${uc_module}: bad checksum: "
              . "$bbytes[0] $bbytes[1] $bbytes[2] $bbytes[3]" )
          if $main::Debug{$lc_module};
    }

    return "BADCHECKSUM";
}

#------------------------------------------------------------------------------

# Subroutine: rf_set_receiver
#	Set state of all MR26/W800 and X10_RF_Receiver objects.

sub rf_set_receiver {
    my ( $module, $state ) = @_;

    my $uc_module = uc $module;

    for my $name (
        &main::list_objects_by_type( 'X10_' . $uc_module ),
        &main::list_objects_by_type('X10_RF_Receiver')
      )
    {

        my $object = &main::get_object_by_name($name);
        $object->set($state);
    }
}

#------------------------------------------------------------------------------

# Subroutine: rf_set_RF_Item
#	Set the state of any items or classes associated with this device.

sub rf_set_RF_Item {
    my ( $module, $desc, $no_match_text, $item_id, $class_id, $state ) = @_;

    my $uc_module = uc $module;
    my $lc_module = lc $module;

    my $matched;
    for my $name ( &main::list_objects_by_type('RF_Item') ) {
        my $object = &main::get_object_by_name($name);
        my $id     = $object->{rf_id};
        if ( $id eq $item_id or ( defined $class_id and $id eq $class_id ) ) {
            $object->set( $state, 'rf' );
            $matched = 1;
            if ( $main::Debug{$lc_module} ) {
                &::print_log(
                    "$item_id: " . substr( $name, 1 ) . " set $state" );
            }
        }
    }
    unless ($matched) {
        &::print_log("${uc_module}: ${desc}: $no_match_text (state = $state)");
    }
}

#------------------------------------------------------------------------------

# Subroutine: rf_get_RF_Item
#	Get the state of the item with the given id.

sub rf_get_RF_Item {
    my ( $module, $desc, $no_match_text, $item_id ) = @_;

    my $uc_module = uc $module;
    my $lc_module = lc $module;

    my $matched;
    for my $name ( &main::list_objects_by_type('RF_Item') ) {
        my $object = &main::get_object_by_name($name);
        my $id     = $object->{rf_id};
        if ( $id eq $item_id ) {
            my $state = $object->state;
            $matched = 1;
            if ( $main::Debug{$lc_module} ) {
                &::print_log(
                    "$item_id: " . substr( $name, 1 ) . " get $state" );
            }
            return $state;
        }
    }
    unless ($matched) {
        &::print_log("${uc_module}: ${desc}: $no_match_text");
    }
    return undef;
}

#------------------------------------------------------------------------------

# Data format info on here:  http://www.wgldesigns.com/dataformat.txt

#
# $Log: X10_RF.pm,v $
# Revision 1.4  2004/03/23 01:58:08  winter
# *** empty log message ***
#
# Revision 1.3  2004/02/01 19:24:35  winter
#  - 2.87 release
#
#

# vim: sw=4

1;
