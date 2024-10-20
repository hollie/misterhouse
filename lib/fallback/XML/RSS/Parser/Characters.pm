package XML::RSS::Parser::Characters;

use strict;
use base qw(XML::Elemental::Characters);

use XML::RSS::Parser::Util qw(encode_xml);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my $a     = shift;
    $self->data($a->{data}) if ($a);
    $self;
}

sub as_xml { encode_xml($_[0]->data) } 

###--- hack to keep Class::XPath happy.
sub qname            { '' }
sub attributes       { {} }
sub contents         { () }
sub text_content     { $_[0]->data; }
sub attribute_qnames { }

1;

__END__

=begin

=head1 NAME

XML::RSS::Parser::Characters - an object representing a
character data in an RSS parse tree.

=head1 METHODS

=item XML::RSS::Parser::Character->new( [\%init] )

Constructor. Optionally the data and parent can be set with
a HASH reference using keys of the same name. See their
associated functions below for more.

=item $chars->parent([$object])

Returns a reference to the parent object. If a parameter is
passed the parent is set.

=item $chars->data([$string])

A method that returns the character data as a string. If a
parameter is passed the value is set.

=item $chars->root

Returns a reference to the root element of class
L<XML::RSS::Parser::Feed> from the parse tree.

=item $chars->as_xml

Pass-thru to the C<encode_xml> in L<XML::RSS::Parser::Util>
using the C<data> method return as input.

=head1 AUTHOR & COPYRIGHT

Please see the XML::RSS::Parser manpage for author,
copyright, and license information.

=cut

=end
