package XML::RSS::Parser::Feed;

use strict;
use base qw(XML::Elemental::Document);

use XML::Elemental::Util qw(process_name);
use XML::RSS::Parser::Util;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{rss_namespace_uri} = '';
    $self;
}

# Very loose determination of the RSS namespace (if any). Goes to the
# first child of the root element (most likely the channel) and extracts
# its namespace URI. We don't use the root element because in RSS 1.0
# the root element is not in the RSS (default) namespace.
sub find_rss_namespace {
    my $doc  = shift;
    my $root = $doc->contents->[0];
    foreach my $node (@{$root->contents}) {
        if (ref($node) eq 'XML::RSS::Parser::Element') {
            my ($n, $ns) = process_name($node->name);
            $doc->{rss_namespace_uri} = $ns || '';
            return $doc->{rss_namespace_uri};
        }
    }
    return '';
}

sub rss_namespace_uri {
    $_[0]->{rss_namespace_uri} = $_[1] if defined $_[1];
    $_[0]->{rss_namespace_uri};
}

# sub name { 'rss' }
sub query      { $_[0]->contents->[0]->query($_[1]) }
sub channel    { my @c = $_[0]->query('/channel'); $c[0]; }
sub image      { $_[0]->query('image'); }
sub items      { $_[0]->query('item'); }
sub item_count { my @i = $_[0]->items; scalar @i; }
sub as_xml { XML::RSS::Parser::Util::as_xml($_[0]->contents->[0],1,$_[1]) }

###--- hack to keep Class::XPath happy.
sub qname            { '' }
sub attribute_qnames { }

1;

__END__

=begin

=head1 NAME

XML::RSS::Parser::Feed -- the root element of a parsed RSS
feed.

=head1 METHODS

=over

=item XML::RSS::Parser::Feed->new

Constructor. Returns a XML::RSS::Parser::Feed object.

=item $feed->rss_namespace_uri

Returns the namespace URI the RSS elements are in, if at
all. This is important since different RSS namespaces are in
use. Return a null string if a namespace cannot be
determined or was not defined at all in the feed.

=item $feed->item_count

Returns an integer representing the number of C<item>
elements in the feed.

=back

=head2 ALIAS METHODS

=over

=item $feed->channel

Returns a reference to the channel element object.

=item $feed->items

Returns an array of reference to item elements object.

=item $feed->image

Returns a reference to the image object if one exists.

=item $feed->as_xml([$encoding])

Alias to the C<channel> element's C<as_xml> method which
outputs the XML of the entire feed including a standard 
XML 1.0 declaration. An optional encoding can be defined.
The default encoding is 'utf-8'.

=item $feed->query

A pass-thru to the root element's C<query> method.

=back

=head1 AUTHOR & COPYRIGHT

Please see the XML::RSS::Parser manpage for author,
copyright, and license information.

=cut

=end

