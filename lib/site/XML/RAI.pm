# Copyright (c) 2004-2005 Timothy Appnel
# http://www.timaoutloud.org/
# This code is released under the Artistic License.
#
# XML::RAI - RSS Abstraction Interface.
#

package XML::RAI;

use strict;

use vars qw($VERSION);
$VERSION = 1.301;

use XML::RSS::Parser 4.0;
use XML::RAI::Channel;
use XML::RAI::Item;
use XML::RAI::Image;

use constant W3CDTF    => '%Y-%m-%dT%H:%M:%S%z';    # AKA...
use constant RFC8601   => W3CDTF;
use constant RFC822    => '%a, %d %b %G %T %Z';
use constant PASS_THRU => '';
use constant EPOCH     => 'EPOCH';

my $parser;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->init(@_);
    $self;
}

sub init {
    my $self = shift;
    my $doc;
    unless (ref($_[0]) eq 'XML::RSS::Parser::Feed') {
        my ($method, @r) = @_;
        $parser ||= XML::RSS::Parser->new;
        $doc = $parser->$method(@r) or die $parser->errstr;
    } else {
        $doc = shift;
    }
    $self->{__doc} = $doc;
    my $channel = $self->{__channel} =
      XML::RAI::Channel->new($doc->channel, $self);
    my @items = map { XML::RAI::Item->new($_, $channel) } $doc->items;
    $self->{__items} = \@items;
    my @imgs = $doc->image;    # fix multiple image bug ala slashdot.
    $self->{__image} = XML::RAI::Image->new($imgs[0], $channel) if $doc->image;
    $self->{__timef} = W3CDTF;
}

sub time_format {
    $_[0]->{__timef} = $_[1] if defined $_[1];
    $_[0]->{__timef};
}

sub parse {
    my $class = shift;
    if (ref($_[0]) eq 'GLOB') {    # is filehandle
        $class->parse_file(@_);
    } else {                       # is string
        $class->parse_string(@_);
    }
}

sub parsefile {
    my $class = shift;
    $class->new('parse_file', @_) or die $class->errstr;
}
*parse_file = \&parsefile;

sub parse_string {
    my $class = shift;
    $class->new('parse_string', @_) or die $class->errstr;
}

sub parse_uri {
    my $class = shift;
    $class->new('parse_uri', @_) or die $class->errstr;
}

sub document   { $_[0]->{__doc}; }
sub channel    { $_[0]->{__channel}; }
sub items      { $_[0]->{__items}; }
sub item_count { scalar @{$_[0]->{__items}}; }
sub image      { $_[0]->{__image}; }

1;

__END__

=begin

=head1 NAME

XML::RAI - RSS Abstraction Interface.

=head1 SYNOPSIS

 #!/usr/bin/perl -w
 use strict;
 use XML::RAI;
 my $doc = <<DOC;
 <?xml version="1.0" encoding="iso-8859-1"?>
 <rss xmlns:dc="http://purl.org/dc/elements/1.1/"
     xmlns="http://purl.org/rss/1.0/">
     <channel>
         <title>tima thinking outloud</title>
         <link>http://www.timaoutloud.org/</link>
         <description></description>
         <dc:language>en-us</dc:language>
         <item>
             <title>His and Hers Weblogs.</title>
             <description>First it was his and hers Powerbooks. Now 
             its weblogs. There goes the neighborhood.</description>
             <link>http://www.timaoutloud.org/archives/000338.html</link>
             <dc:subject>Musings</dc:subject>
             <dc:creator>tima</dc:creator>
             <dc:date>2004-01-23T12:33:22-05:00</dc:date>
         </item>
         <item>
             <title>Commercial Music Again.</title>
             <description>Last year I made a post about music used 
             in TV commercials that I recognized and have been listening to. 
             For all the posts I made about technology and other bits of sagely
             wisdom the one on commercial music got the most traffic of any 
             each month. I need a new top post. Here are some more tunes that 
             have appeared in commercials.</description>
             <guid isPermaLink="true">
               http://www.timaoutloud.org/archives/000337.html
             </guid>
             <category>Musings</category>
             <author>tima</author>
             <pubDate>Sun, 18 Jan 2004 14:09:03 GMT</pubDate>
         </item>
     </channel>
 </rss>
 DOC

 # The above is to demonstrate the value of RAI. It is not any 
 # specific RSS format, nor does it exercise best practices.

 my $rai = XML::RAI->parse_string($doc);
 print $rai->channel->title."\n\n";
 foreach my $item ( @{$rai->items} ) {
    print $item->title."\n";
    print $item->link."\n";
    print $item->content."\n";
    print $item->issued."\n\n";
 }

=head1 DESCRIPTION

The RSS Abstraction Interface, or RAI (said "ray"), provides an
object-oriented interface to XML::RSS::Parser trees that abstracts
the user from handling namespaces, overlapping and alternate tag
mappings.

It's rather well known that, while popular, the RSS syntax is a bit
of a mess. Anyone who has attempted to write software that consumes
RSS feeds "in the wild" can attest to the headaches in handling the
many formats and interpretations that are in use. For instance, in
"The myth of RSS compatibility"
L<http://diveintomark.org/archives/2004/02/04/incompatible-rss>
Mark Pilgrim identifies 9 different versions of RSS (there are 10
actually[1]) and that is not without going into tags with
overlapping purposes. Even the acronym RSS has multiple though
similar meanings.

The L<XML::RSS::Parser> alone attempts to help developers cope with these
issues through a liberal interpretation of what is RSS and routines
to normalize the parse tree into a more common and manageable form.

RAI takes this one step further. Its intent is to give a developer
the means to not have to care about what tags the feed uses to
present its meta data.

RAI provides a single simplified interface that maps one method
call to various overlapping and alternate tags used in RSS feeds.
The interface also abstracts developers from needing to deal with
namespaces. Method names are based on Dublin Core terminology.

With the release of version 1.0, the L<XML::RSS::Parser> 
distribution was folded into XML::RAI. 

[1] When initially released, RSS 2.0 had a namespace. When it was
reported a few days later that some XSLT-based systems were
breaking because of the change in the RSS namespace from "" (none)
to http://backend.userland.com/rss2, the namespace was removed, but
the version number was not incremented making it incompatible with
itself. L<http://groups.yahoo.com/group/rss-dev/message/4113> This
version was not counted in Mark's post.

=head1 METHODS

=item XML::RAI->new($rss_tree)

Returns a populated RAI instance based on the 
L<XML::RSS::Parser::Feed> object passed in.

=item XML::RAI->parse($string_or_file_handle)

Passes through the string or file handle to the C<parse>
method to either C<parse_file> or C<parse_string> in
L<XML::RSS::Parser>. Returns a populated RAI instance.

To maintain backwards compatability this method is B<not> inherited 
from the underlying SAX implementation.

=item XML::RAI->parse_file

=item XML::RAI->parse_string

=item XML::RAI->parse_uri

A pass-thru to the underlying SAX implentation. See L<XML::SAX::Base> for 
more on these methods.

=item $rai->document

Returns the L<XML::RSS::Parser> parse tree being used as the source
for the RAI object

=item $rai->channel

Returns the L<XML::RAI::Channel> object.

=item $rai->items

Returns an array reference containing the L<XML::RAI::Item> objects
for the feed

=item $rai->item_count

Returns the number of items as an integer.

=item $rai->image

Returns the L<XML::RAI::Image> object, if any. (Many feeds do not
have an image block.)

=item $rai->time_format($timef)

Sets the timestamp normalization format. RAI will attempt to parse
the string into a data value and will output timestamp (date)
values in this format.

RAI implements a few constants with common RSS timestamp formatting
strings:

 W3CDTF     1999-09-01T22:10:40Z 
 RFC8601    (other name for W3CDTF)
 RFC822     Wed, 01 Sep 1999 22:10:40 GMT 
 EPOCH      (Seconds since system epoch.)
 PASS_THRU  (timestamp as it appear in the source. does not normalize.)

W3CDTF/RFC8601 is the default. For more detail on creating your own
timestamp formats see the manpage for the C<strftime> command.

=head1 PLUGINS

With the introduction of the C<add_mapping> and the
C<register_ns_prefix> method in the underlying
L<XML::RSS::Parser>, RAI now has a plugin API for easily
extending its mappings.

To create a RAI plugin module, simply create a package with
an C<import> method that makes all of the necessary
C<add_mapping> and C<register_ns_prefix> calls. For an
example plugin module see L<XML::RAI::TrackBack>

=head1 DEPENDENCIES

L<XML::RSS::Parser> 4.0, L<Date::Parse> 2.26, L<Date::Format> 2.22

=head1 TO DO

=over

=item * Add Atom elements into mappings.

=item * Serialization module(s).

=item * DATETIME (L<DateTime> object) constants and functionality 
for C<time_format>.

=back

=head1 LICENSE

The software is released under the Artistic License. The terms of
the Artistic License are described at
L<http://www.perl.com/language/misc/Artistic.html>.

=head1 AUTHOR & COPYRIGHT

Except where otherwise noted, XML::RAI is Copyright
2003-2005, Timothy Appnel, cpan@timaoutloud.org. All rights
reserved.

=cut

=end
