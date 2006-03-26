package XML::RSS::Parser::Element;

use strict;
use base qw(XML::Elemental::Element);

use XML::Elemental::Util qw(process_name);
use XML::RSS::Parser::Util;

use Class::XPath 1.4
  get_name       => 'qname',
  get_parent     => 'parent',
  get_root       => 'root',
  get_children   => sub { $_[0]->contents ? @{$_[0]->contents} : () },
  get_attr_names => 'attribute_qnames',
  get_attr_value => 'attribute_by_qname',
  get_content    => 'text_content';

sub new {
    my $self = shift->SUPER::new(@_);
    my $a = shift || {};
    map { $self->{$_} = $a->{$_} }
      grep { defined $a->{$_} } qw( name attributes root parent );
    $self;
}

sub as_xml { XML::RSS::Parser::Util::as_xml($_[0]); }

#--- xpath methods

sub query {
    my @nodes = $_[0]->match($_[1]);
    wantarray ? @nodes : $nodes[0];
}

sub qname {
    my $in = $_[1] || $_[0]->name;
    my ($local, $ns) = process_name($in);
    return $local if ($_[0]->root->rss_namespace_uri eq $ns);
    my $prefix = XML::RSS::Parser->prefix($ns);
    unless ($prefix) {    # make a generic prefix for unknown namespace URI.
        my $i = 1;
        while (XML::RSS::Parser->namespace("NS$i")) { $i++ }
        XML::RSS::Parser->register_ns_prefix("NS$i", $ns);
        $prefix                                 = "NS$i";
    }
    "$prefix:$local";
}

sub attribute_qnames {
    return () unless my $attr = $_[0]->attributes;
    my ($foo, $ns) = process_name($_[0]->name);
    my @names;
    foreach (keys %$attr) {
        my ($local, $nsa) = process_name($_);
        $nsa ||= $ns;
        push @names, $_[0]->qname("{$nsa}$local");
    }
    @names;
}

my $NAME = qr/[[:alpha:]_][\w\-\.]*/;

sub attribute_by_qname {
    my $self = shift;
    my $name = shift;
    my $ns   = '';
    if ($name =~ /($NAME):($NAME)/) {
        $name = $2;
        $ns = XML::RSS::Parser->namespace($1) || '#UNKNOWN';
    } else {
        $ns = XML::RSS::Parser->namespace('#DEFAULT') || '';
    }
    my ($local, $ns_parent) = process_name($self->name);
    $ns = '' if $ns_parent eq $ns;
    $self->attributes->{"{$ns}$name"};
}

#--- XML::RSS::Parser::Element 2x API methods. Now deprecated.

sub child {
    my ($self, $tag) = @_;
    my $class = ref($self);
    my $e = $class->new({parent => $self, name => $tag});
    push(@{$self->contents}, $e);
    $e;
}

sub children {
    my ($self, $name) = @_;
    return $self->contents unless defined($name);
    my @c = grep { $_->can('name') && $_->name eq $name } @{$self->contents};
    wantarray ? @c : $c[0];
}

sub attribute {
    $_[0]->attributes->{$_[1]} = $_[2] if $_[2];
    $_[0]->attributes->{$_[1]};
}

sub children_names {
    my $class = ref($_[0]);
    map { $_->name } grep { ref($_) eq $class } @{$_[0]->contents};
}

# previously deprecated methods value and append_value have been removed.

1;

__END__

=begin

=head1 NAME

XML::RSS::Parser::Element -- a node in the XML::RSS::Parser
parse tree.

=head1 METHODS

=over

=item XML::RSS::Parser::Element->new( [\%init] )

Constructor for XML::RSS::Parser::Element. Optionally the
name, value, attributes, root, and parent can be set with a
HASH reference using keys of the same name. See their
associated functions below for more.

=item $element->root

Returns a reference to the root element of class
L<XML::RSS::Parser::Feed> from the parse tree.

=item $element->parent( [$element] )

Returns a reference to the parent element. A
L<XML::RSS::Parser::Element> object or one of its subclasses
can be passed to optionally set the parent.

=item $element->name( [$extended_name] )

Returns the name of the element as a SCALAR. This should by
the fully namespace qualified (extended)  name of the
element and not the QName or local part.

=item $element->attributes( [\%attributes] )

Returns a HASH reference contain attributes and their values
as key value pairs. An optional parameter of a HASH
reference can be passed in to set multiple attributes.
Returns C<undef> if no attributes exist. B<NOTE:> When
setting attributes with this method, all existing attributes
are overwritten irregardless of whether they are present in
the hash being passed in.

=item $element->contents([\@children])

Returns an ordered ARRAY reference of direct sibling
objects. Returns a reference to an empty array if the
element does not have any siblings. If a parameter is passed
all the direct siblings are (re)set.

=item $element->text_content

A method that returns the character data of all siblings.

=item $element->as_xml

Pass-thru to the C<as_xml> in L<XML::RSS::Parser::Util>
using the object as the node parameter.

=back

=head2 XPath-esque Methods

=over

=item $element->query($xpath)

Finds matching nodes using an XPath-esque query from
anywhere in the tree. Like the C<param> method found in
L<CGI>, calling C<query> in a SCALAR context will return
only the first matching node. In an ARRAY context all
matching elements are returned.

=item $element->match($xpath)

C<match> is inherited from L<Class::XPath> and always
returns an array regardless of context. While C<query> is
generally preferred, using match in a scalar context is a
good quick way of getting a count of matching nodes. See the
L<Class::XPath> documentation for more information.

=item $element->xpath

Returns a unique XPath string to the current node which can
be used as an identifier.

=back

These methods were implemented for internal use with
L<Class::XPath> and have now been exposed for general use.

=over

=item $elemenet->qname

Returns the QName of the element based on the internal
namespace prefix mapping.

=item $element->attribute_qnames

Returns an array of attribute names in namespace qualified
(QName) form based on the internal prefix mapping.

=item $element->attribute_by_qname($qname)

Returns an array of attribute names in namespace qualified
(QName) form.

=back

=head2 2x API Methods

These were easily re-implemented though implementing them
with only the methods provided by L<XML::Elemental> are
trivial. They are still available for backwards
compatability reasons.

B<These methods are now considered deprecated.>

=over

=item $element->attribute($name [, $value] )

Returns the value of an attribute specified by C<$name> as a
SCALAR. If an optional second text parameter C<$value> is
passed in the attribute is set. Returns C<undef> if the
attribute does not exist.

Using the C<attributes> method you could replicate this
method like so:

 $element->attributes->{$name};          #get
 $element->attributes->{$name} = $value; #set
 
=item $element->child( [$extended_name] )

Constructs and returns a new element object making the
current object as its parent. An optional parameter
representing the name of the new element object can be
passed. This should be the fully namespace qualified
(extended) name and not the QName or local part.

=item $element->children( [$extended_name] )

Returns any array of child elements to the object. An
optional parameter can be passed in to return element(s)
with a specific name. If called in a SCALAR context it will
return only the first element with this name. If called in
an ARRAY context the function returns all elements with this
name. If no elements exist as a child of the object, and
undefined value is returned.

B<NOTE:> In keeping with the original behaviour of the 2x
API, this method only returns L<XML::RSS::Parser::Element>s.
L<XML::RSS::Parser::Characters> are stripped out. Use the
C<contents> method for the full list of child objects.

=item $element->children_names

Returns an array containing the names of the objects
children. Empty if no children are present.

B<NOTE:> In keeping with the original behaviour of the 2x
API, this method only returns the names of
L<XML::RSS::Parser::Element>s.
L<XML::RSS::Parser::Characters> are not present.

=back

=head1 AUTHOR & COPYRIGHT

Please see the XML::RSS::Parser manpage for author,
copyright, and license information.

=cut

=end



