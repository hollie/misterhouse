package XML::RSS::Parser;
use strict;

use XML::Elemental;
use base qw( Class::ErrorHandler );

use vars qw( $VERSION );
$VERSION = 4.0;

my %xpath_prefix = (
    admin      => "http://webns.net/mvcb/",
    ag         => "http://purl.org/rss/1.0/modules/aggregation/",
    annotate   => "http://purl.org/rss/1.0/modules/annotate/",
    atom       => "http://www.w3.org/2005/Atom",
    audio      => "http://media.tangent.org/rss/1.0/",
    cc         => "http://web.resource.org/cc/",
    company    => "http://purl.org/rss/1.0/modules/company",
    content    => "http://purl.org/rss/1.0/modules/content/",
    cp         => "http://my.theinfo.org/changed/1.0/rss/",
    dc         => "http://purl.org/dc/elements/1.1/",
    dcterms    => "http://purl.org/dc/terms/",
    email      => "http://purl.org/rss/1.0/modules/email/",
    ev         => "http://purl.org/rss/1.0/modules/event/",
    feedburner => "http://rssnamespace.org/feedburner/ext/1.0",
    foaf       => "http://xmlns.com/foaf/0.1/",
    image      => "http://purl.org/rss/1.0/modules/image/",
    itunes     => "http://www.itunes.com/DTDs/Podcast-1.0.dtd",
    l          => "http://purl.org/rss/1.0/modules/link/",
    openSearch => "http://a9.com/-/spec/opensearchrss/1.0/",
    rdf        => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    rdfs       => "http://www.w3.org/2000/01/rdf-schema#",
    'ref'      => "http://purl.org/rss/1.0/modules/reference/",
    reqv       => "http://purl.org/rss/1.0/modules/richequiv/",
    rss091     => "http://purl.org/rss/1.0/modules/rss091#",
    search     => "http://purl.org/rss/1.0/modules/search/",
    slash      => "http://purl.org/rss/1.0/modules/slash/",
    ss         => "http://purl.org/rss/1.0/modules/servicestatus/",
    str        => "http://hacks.benhammersley.com/rss/streaming/",
    'sub'      => "http://purl.org/rss/1.0/modules/subscription/",
    sy         => "http://purl.org/rss/1.0/modules/syndication/",
    tapi       => "http://api.technorati.com/dtd/tapi-001.xml#",
    taxo       => "http://purl.org/rss/1.0/modules/taxonomy/",
    thr        => "http://purl.org/rss/1.0/modules/threading/",
    trackback  => "http://madskills.com/public/xml/rss/module/trackback/",
    wiki       => "http://purl.org/rss/1.0/modules/wiki/",
    xhtml      => "http://www.w3.org/1999/xhtml",
    xml        => "http://www.w3.org/XML/1998/namespace/",

    creativeCommons => "http://backend.userland.com/creativeCommonsRssModule"
);
my %xpath_ns = reverse %xpath_prefix;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    my $params = {
                  Document   => 'XML::RSS::Parser::Feed',
                  Element    => 'XML::RSS::Parser::Element',
                  Characters => 'XML::RSS::Parser::Characters'
    };
    $self->{__parser} = XML::Elemental->parser($params);
    $self;
}

sub register_ns_prefix {
    my ($this, $prefix, $ns) = @_;
    $xpath_prefix{$prefix} = $ns;
    $xpath_ns{$ns}         = $prefix;
}

sub parse        { _parse('parse',        @_); }
sub parse_file   { _parse('parse_file',   @_); }
sub parse_string { _parse('parse_string', @_); }
sub parse_uri    { _parse('parse_uri',    @_); }

sub _parse {
    my $meth = shift;
    my $e    = shift;
    my $doc;
    eval { $doc = $e->{__parser}->$meth(@_) };
    return $e->error($@) if ($@);
    $e->rss_normalize($doc);
}

#--- utils

sub prefix { $xpath_ns{$_[1]} }
sub namespace { $xpath_prefix{$_[1]} }

sub ns_qualify {
    my ($this, $name, $ns) = @_;
    $ns ||= '';
    "{$ns}$name";
}

# Since different RSS formats have slightly different tag hierarchies
# we make some alternations after processing so bring them all into
# line.
sub rss_normalize {
    my $self         = shift;
    my $doc          = shift;
    my $ns           = $doc->find_rss_namespace;
    my $channel_name = "{$ns}channel";
    my $root         = $doc->contents->[0];
    my @new_contents;
    my $channel;
    foreach (@{$root->contents}) {
        if ($_->can('name') && ($_->name eq $channel_name)) {
            $_->parent($doc);
            $channel = $_;
            $doc->contents([$_]);
        } else {
            push(@new_contents, $_);
        }
    }
    map { $_->parent($channel) } @new_contents;
    $channel->contents([@{$channel->contents}, @new_contents]);
    $root->parent(undef);
    $root->contents(undef);
    $doc;
}

1;

__END__

=begin

=head1 NAME

XML::RSS::Parser - A liberal object-oriented parser for RSS
feeds.

=head1 SYNOPSIS

 #!/usr/bin/perl -w
 use strict;
 
 use XML::RSS::Parser;
 use FileHandle;
 
 my $p = XML::RSS::Parser->new;
 my $fh = FileHandle->new('/path/to/some/rss/file');
 my $feed = $p->parse_file($fh);
 
 # output some values 
 my $feed_title = $feed->query('/channel/title');
 print $feed_title->text_content;
 my $count = $feed->item_count;
 print " ($count)\n";
 foreach my $i ( $feed->query('//item') ) { 
     my $node = $i->query('title');
     print '  '.$node->text_content;
     print "\n"; 
 }

=head1 DESCRIPTION

XML::RSS::Parser is a lightweight liberal parser of RSS
feeds. This parser is "liberal" in that it does not demand
compliance of a specific RSS version and will attempt to
gracefully handle tags it does not expect or understand. 
The parser's only requirements is that the file is
well-formed XML and remotely resembles RSS. Roughly
speaking, well formed XML with a C<channel> element as a
direct sibling or the root tag and C<item> elements etc.

There are a number of advantages to using this module then
just using a standard parser-tree combination. There are a
number of different RSS formats in use today. In very subtle
ways these formats are not entirely compatible from one to
another. XML::RSS::Parser makes a couple assumptions to
"normalize" the parse tree into a more consistent form. For
instance, it forces C<channel> and C<item> into a
parent-child relationship. For more detail see L<SPECIAL
PROCESSING NOTES>.

This module is leaner then L<XML::RSS> -- the majority of
code was for generating RSS files. It also provides a
XPath-esque interface to the feed's tree.

While XML::RSS::Parser creates a normalized parse tree, it
still leaves the mapping of overlapping and alternate tags
common in the RSS format space to the developer. For this
look at the L<XML::RAI> (RSS Abstraction Interface) package
which provides an object-oriented layer to XML::RSS::Parser
trees that transparently maps these various tags to one
common interface.

XML::RSS::Parser is based on L<XML::Elemental>, a a
SAX-based package for easily parsing XML documents into a
more native and mostly object-oriented perl form.

=head2 SPECIAL PROCESSING NOTES

There are a number of different RSS formats in use today. In
very subtle ways these formats are not entirely compatible
from one to another. What's worse is that there are
unlabeled versions within the standard in addition to tags
with overlapping purposes and vague definitions. (See Mark
Pilgrim's "The myth of RSS compatibility"
L<http://diveintomark.org/archives/2004/02/04/incompatible-
rss> for just a sampling of what I mean.) To ease working
with RSS data in different formats, the parser does not
create the feed's parse tree verbatim. Instead it makes a
few assumptions to "normalize" the parse tree into a more
consistent form.

With the refactoring of this module and the switch to a true
tree structure, the normalization process has been
simplified. Some of the version 2x proved to be problematic
with more advanced and complex feeds.

=over

=item * The RSS namespace (if any) is extracted from the
first sibling of the root tag. We don't use the root tag
because in RSS 1.0 the root tag is in the RDF namespace and
not RSS. That namespace is treated as the '#default' (no
prefix) namespace for the parse tree.

=item * The parser will not include the root tags of C<rss>
or C<RDF> in the tree. Namespace declaration information is
still extracted.

=item * The parser forces C<channel> and C<item> into a
parent-child relationship. In versions 0.9 and 1.0,
C<channel> and C<item> tags are siblings.

=back

=head2

Two significant changes were made with the release of
version 4.0.

=over

=item XML::RSS::Parser is B<not> a subclass of
L<XML::Elemental>.

This change should be transparent in most cases, but deemed
necessary for the error handling and special handling of RSS
data.

=item XML::RSS::Parser uses Clarkian Notation for element
and attribute names.

This change is inherited from recent changes in
XML::Elemental. The previous system was flawed and not
widely adopted. Clarkian notation is the form used by
XML::SAX and XML::Simple to name a few. Use the
C<process_name> in L<XML::Elemental::Util> to parse element
and attribute names intoo their namespace URI and local name
parts.

=back

=head1 NAMESPACE PREFIXES

The following prefix and namespace combinations are
recognized by default. Use C<register_ns_prefix> to add
more as needed.

    admin       http://webns.net/mvcb/
    ag          http://purl.org/rss/1.0/modules/aggregation/
    annotate    http://purl.org/rss/1.0/modules/annotate/
    atom        http://www.w3.org/2005/Atom
    audio       http://media.tangent.org/rss/1.0/
    cc          http://web.resource.org/cc/
    company     http://purl.org/rss/1.0/modules/company
    content     http://purl.org/rss/1.0/modules/content/
    cp          http://my.theinfo.org/changed/1.0/rss/
    dc          http://purl.org/dc/elements/1.1/
    dcterms     http://purl.org/dc/terms/
    email       http://purl.org/rss/1.0/modules/email/
    ev          http://purl.org/rss/1.0/modules/event/
    feedburner  http://rssnamespace.org/feedburner/ext/1.0
    foaf        http://xmlns.com/foaf/0.1/
    image       http://purl.org/rss/1.0/modules/image/
    itunes      http://www.itunes.com/DTDs/Podcast-1.0.dtd
    l           http://purl.org/rss/1.0/modules/link/
    openSearch  http://a9.com/-/spec/opensearchrss/1.0/
    rdf         http://www.w3.org/1999/02/22-rdf-syntax-ns#
    rdfs        http://www.w3.org/2000/01/rdf-schema#
    ref         http://purl.org/rss/1.0/modules/reference/
    reqv        http://purl.org/rss/1.0/modules/richequiv/
    rss091      http://purl.org/rss/1.0/modules/rss091#
    search      http://purl.org/rss/1.0/modules/search/
    slash       http://purl.org/rss/1.0/modules/slash/
    ss          http://purl.org/rss/1.0/modules/servicestatus/
    str         http://hacks.benhammersley.com/rss/streaming/
    sub         http://purl.org/rss/1.0/modules/subscription/
    sy          http://purl.org/rss/1.0/modules/syndication/
    tapi        http://api.technorati.com/dtd/tapi-001.xml#
    taxo        http://purl.org/rss/1.0/modules/taxonomy/
    thr         http://purl.org/rss/1.0/modules/threading/
    trackback   http://madskills.com/public/xml/rss/module/trackback/
    wiki        http://purl.org/rss/1.0/modules/wiki/
    xhtml       http://www.w3.org/1999/xhtml
    xml         http://www.w3.org/XML/1998/namespace/

    creativeCommons  http://backend.userland.com/creativeCommonsRssModule

=head1 METHODS

The following objects and methods are provided in this
package.

=item XML::RSS::Parser->new

Constructor. Returns a reference to a new XML::RSS::Parser
object.

=item $parser->parse 
=item $parser->parse_file 
=item $parser->parse_string
=item $parser->parse_uri

These methods are mostly pass-thru to the underlying SAX parser
provided by L<XML::Elemental>. (See L<XML::SAX::Base> for
more.)

XML::RSS::Parser wraps these calls in eval statements and rather then 
dying returns undefined. Any parsing errors can be retreived by using the 
C<errstr> method inherited from L<Class::ErrorHandler>.

Once the markup has been parsed it is automatically passed
through the C<rss_normalize> method before the parse tree is
returned to the caller.

=item XML::RSS::Parser->register_ns_prefix(prefix,curi)

Registers the given path with namespace URI for XPath
lookups. Both parameters are required.

=item XML::RSS::Parser->ns_qualify(element, namespace_uri)

An simple utility implemented as an abstract method that
will return a fully namespace qualified string for the
supplied element. Return values are now in Clarkian
notation.

=item XML::RSS::Parser->prefix(namespace_uri)

Returns the prefix to the given namespace URI. Returns
C<undef> if the prefix is not known.

=item XML::RSS::Parser->namespace(prefix)

Returns the namespace URI to the given prefix. Returns
C<undef> if the namespace is not registered.

=item error

Sets an error message for later retreival and returns
C<undef>. Inherited from Class::ErrorHandler.

=item errstr

Returns the last error message set by C<error>. Inherited
from Class:ErrorHandler.

=head1 DEPENDENCIES

L<XML::SAX>, L<XML::Elemental>, L<Class::ErrorHandler>,
L<Class::XPath> 1.4*

Versions up to 1.4 have a design flaw that would cause it to
choke on feeds with the / character in an attribute value.
For example the Yahoo! feeds.

=head1 SEE ALSO

L<XML::RAI>

The Feed Validator L<http://www.feedvalidator.org/>

What is RSS?
L<http://www.xml.com/pub/a/2002/12/18/dive-into-xml.html>

Raising the Bar on RSS Feed Quality
L<http://www.oreillynet.com/pub/a/webservices/2002/11/19/
rssfeedquality.html>

The myth of RSS compatibility
L<http://diveintomark.org/archives/2004/02/04/incompatible-
rss>

=back

=head1 AUTHOR & COPYRIGHT

Except where otherwise noted, XML::RSS::Parser is Copyright
2003-2005, Timothy Appnel, cpan@timaoutloud.org. All rights
reserved.

=cut

=end