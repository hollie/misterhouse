
=begin comment

Kasa_Item.pm

Basic Kasa Smart item set-only support
Copyright (C) 2020 Jeff Siddall (jeff@siddall.name)
Last modified: 2020-12-09

This module only supports setting state on or off

Requirements:

  This module calls the kasa script from the python-kasa package so ensure
  that package is installed and in the MH path (typically /usr/local/bin)
  See: https://github.com/python-kasa/python-kasa

Setup:

In your code define Kasa_Items in an MHT:

  KASA,   192.168.x.y,   Living_Room_KP_0,       strip,  0,      Living_Room
  KASA,   192.168.x.y,   Living_Room_KP_1,       strip,  1,      Living_Room
  KASA,   192.168.x.y,   Basement_KS,            plug,    ,      Basement

Or in a code file:

 $kasa = new Kasa_Item(<address/hostname>, <type>, [<index>]);
 Where:
   <address/hostname> - IPv4 address or hostname of the Kasa module
   <type>  - Type of device (bulb, plug or strip)
   <index>  - Optional, child ID to set (or all children if not set)

 $kasa->set(ON);

=cut

#=======================================================================================
#
# Generic Kasa_Item
#
#=======================================================================================

# To add table support, add these lines to the read_table_A.pl file:
# elsif ( $type eq "KASA" ) {
#     require Kasa_Item;
#     my ( $type, $index );
#     ( $address, $name, $type, $index, $grouplist ) = @item_info;
#     # Check if device has an index
#     if ($index eq '') {
#         $object = "Kasa_Item('$address', '$type')";
#     } else {
#         $object = "Kasa_Item('$address', '$type', $index)";
#     }
# }

package Kasa_Item;
use strict;
use parent 'Generic_Item';

# Base class constructor
sub new {
    my ( $class, $address, $type, $index ) = @_;

    # Call the parent class constructor to make sure all the important things are done
    my $self = new Generic_Item();
    bless $self, $class;

    # Additional Kasa variables
    $self->{address} = $address;
    $self->{type}    = $type;
    $self->{index}   = $index;

    # Initialize states
    $self->set_states( 'on', 'off' );

    # Log the setup of the item
    &main::print_log("[Kasa_Item] Created item with address $address type $type index $index");

    return $self;
}

# Call the python-kasa script to set items
sub set {
    my ( $self, $state, $set_by, $respond ) = @_;

    # Call the parent class set to make sure all the important things are done
    $self->SUPER::set( $state, $set_by, $respond );

    # Debug logging
    my $debug = $self->{debug} || $main::Debug{kasa};
    &main::print_log("Kasa_Item::set $self->{object_name} to: $state") if $debug;

    # Only add the index if one was specified with the item was created
    if ( defined( $self->{index} ) ) {
        `/usr/local/bin/kasa --$self->{type} --host $self->{address} $state --index $self->{index}`
    }
    else {
        `/usr/local/bin/kasa --$self->{type} --host $self->{address} $state`
    }
}

# Perl modules need to return true
1;
