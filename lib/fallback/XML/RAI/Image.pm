# Copyright (c) 2004-2005 Timothy Appnel
# http://www.timaoutloud.org/
# This code is released under the Artistic License.
#
# XML::RAI::Image - An interface to the image elements of a RSS feed.
#

package XML::RAI::Image;

use strict;

use vars qw(@ISA $XMap);
@ISA = qw( XML::RAI::Object );

$XMap = {
    description => ['/channel/image[0]/description', '/channel/image[0]/rss091:description'],
    height => ['/channel/image[0]/height', '/channel/image[0]/rss091:height'],
    'link' => [ '/channel/image[0]/link' ],
    title => ['/channel/image[0]/title', '/channel/image[0]/dc:title'],
    url => ['/channel/image[0]/@rdf:resource', '/channel/image[0]/@rdf:about', '/channel/image[0]/url'],
    width  => ['/channel/image[0]/width',  '/channel/image[0]/rss091:width']
};

1;

__END__

=begin

=head1 NAME

XML::RAI::Image - An interface to the image elements of a RSS feed.

=head1 DESCRIPTION

A subclass of L<XML::RAI::Object>, XML::RAI::Image handles the
mapping function and retrieval of RSS channel elements.

=head1 METHODS

=item $image->src

Returns the L<XML::RSS::Parser::Element> that the object is using
as its source.

=item $image->parent

Returns the parent of the RAI object.

=item $image->add_mapping(key, @xpaths)

Creates or appends XPath mappings to the image object for
extensibility and easier access of RAI.

=head2 META DATA ACCESSORS

These accessor methods attempt to retrieve meta data from the
source L<XML::RSS::Parser> element by checking a list of potential
tag names until one returns a value.  They are generally based on
Dublin Core terminology and RSS elements that are common across the
many formats. If called in a SCALAR context, the value of the first
element of the tag being matched is returned. If called in an ARRAY
context it will return all of the values to the tag being matched
-- it does not return all of the values for all of the tags that
have been mapped to the method. (Note that some mappings only allow
one value to be returned.) Returns C<undef> if nothing could be
found.

The following are the tags (listed in XPath notation) mapped to
each method and the order in which they are checked.

=over 4

=item $image->description

=over 4

=item * /channel/image[0]/description

=item * /channel/image[0]/rss091:description

=back

=item $image->height

=over 4

=item * /channel/image[0]/height

=item * /channel/image[0]/rss091:height

=back

=item $image->link

=over 4

=item * /channel/image[0]/link

=back

=item $image->title

=over 4

=item * /channel/image[0]/title

=item * /channel/image[0]/dc:title

=back

=item $image->url

=over 4

=item * /channel/image[0]/@rdf:resource

=item * /channel/image[0]/@rdf:about

=item * /channel/image[0]/url

=back

=item $image->width

=over 4

=item * /channel/image[0]/width

=item * /channel/image[0]/rss091:width

=back

=head1 AUTHOR & COPYRIGHT

Please see the XML::RAI manpage for author, copyright, and license
information.

=cut

=end
