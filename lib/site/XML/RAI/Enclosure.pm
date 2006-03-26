#
# XML::RAI::Enclosure - An interface to the enclosure elements of a RSS feed.
# 

package XML::RAI::Enclosure;

use strict;

use XML::RAI::Object;

our (@ISA, $XMap, $VERSION);

$VERSION = 1.02;

@ISA = qw( XML::RAI::Object );

$XMap = {
    url    => ['@url'],
    length => ['@length'],
    type   => ['@type'],
};

sub load {
	my $class = shift;
	my $item = shift;

	my @enclosures;

	for my $enc ($item->src->query('enclosure')) {
		push @enclosures, XML::RAI::Enclosure->new($enc, $item);
	}

	return @enclosures;
}

1;

__END__

=pod

=head1 NAME

XML::RAI::Enclosure - An extension to XML::RAI adding enclosure support

=head1 DESCRIPTION

A subclass of L<XML::RAI::Object>, XML::RAI::Enclosure handles the mapping function and retrieval of RSS channel elements.

=head1 USAGE

	use XML::RAI;
	use XML::RAI::Enclosure;
	
	my $rai = XML::RAI->parse($feed_xml);
	
	for my $i (@{$rai->items}) {
	         print $i->title,"\n" ;
	         for my $e (XML::RAI::Enclosure->load($i)) {
	             print $e->url, "\n";
	             print $e->length, "\n";
	             print $e->type, "\n";
	         }
	}

=head1 METHODS

=over 4

=item XML::RAI::Enclosure->load

A class method that accepts an XML::RAI::Item and returns a list of XML::RAI::Enclosures.

=item $enclosure->src

An object method that returns the L<XML::RSS::Parser::Element> that the object is using as its source.

=item $enclosure->parent

An object method that returns the parent of the RAI object.

=item $enclosure->url

An object method that returns the enclosure URL attribute.

=item $enclosure->length

An object method that returns the enclosure length attribute.

=item $enclosure->type

An object method that returns the enclosure type attribute.  For example: 'audio/mpeg'

=back

=head1 AUTHOR & COPYRIGHT

Josh McAdams <joshua dot mcadams at gmail dot com> created this extension and released it under the GPL.

=cut

