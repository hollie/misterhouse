package Clipsal_CBus::Unit;

use strict;
use Clipsal_CBus;

@Clipsal_CBus::Unit::ISA = ('Generic_Item', 'Clipsal_CBus');

=item C<new()>
 
 Instantiates a new object.
 
=cut

sub new {
    my ( $class, $address, $name, $label ) = @_;
    my $self = new Generic_Item();
    
    &::print_log ("[Clipsal CBus] New unit object $name at $address");
    
    $self->set_label($label);
    
    #Add this object to the CBus object hash.
    $Clipsal_CBus::Units{$address}{name} = $name;
    $Clipsal_CBus::Units{$address}{label} = $label;
    $Clipsal_CBus::Units{$address}{note} = "Added by object creation";
    
    bless $self, $class;
    
    return $self;
}

1;


