
=head1 B<Clipsal CBus Unit>
 
=head2 SYNOPSIS
 
Unit.pm - support for the Clipsal CBus input units, such as wall switches.
 
=head2 DESCRIPTION
 
This module is a child of Clispal_CBus, and simply allows for creation of 
CBus input unit objects, such as wall switches. Unit names and addresses are
added to the $Clipsal_CBus::Units hash, so that when CGate receives a message
from CBus that an output group has been set, the name of the unit that set it 
can be looked up and added to the log entry.
 
=cut

package Clipsal_CBus::Unit;

use strict;
use Clipsal_CBus;

@Clipsal_CBus::Unit::ISA = ( 'Generic_Item', 'Clipsal_CBus' );

=item C<new()>
 
 Instantiates a new object.
 
=cut

sub new {
    my ( $class, $address, $name, $label ) = @_;
    my $self = new Generic_Item();

    &::print_log("[Clipsal CBus] New unit object $name at $address");

    $self->set_label($label);

    #Add this object to the CBus object hash.
    $Clipsal_CBus::Units{$address}{name}  = $name;
    $Clipsal_CBus::Units{$address}{label} = $label;
    $Clipsal_CBus::Units{$address}{note}  = "Added by object creation";

    bless $self, $class;

    return $self;
}

=head1 AUTHOR
 
 Jon Whitear, jonATwhitearDOTorg

=head1 LICENSE
 
 This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
 of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License along with this program; if not, write to the
 Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 
=cut

1;

