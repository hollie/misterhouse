package HTML::Element;

# $Id$

=head1 NAME

HTML::Element - Class for objects that represent HTML elements

=head1 SYNOPSIS

 require HTML::Element;
 $a = new HTML::Element 'a', href => 'http://www.oslonett.no/';
 $a->push_content("Oslonett AS");

 $tag = $a->tag;
 $tag = $a->starttag;
 $tag = $a->endtag;
 $ref = $a->attr('href');

 $links = $a->extract_links();

 print $a->as_HTML;

=head1 DESCRIPTION

Objects of the HTML::Element class can be used to represent elements
of HTML.  These objects have attributes and content.  The content is an
array of text segments and other HTML::Element objects.  Thus a
tree of HTML::Element objects as nodes can represent the syntax tree
for a HTML document.

The following methods are available:

=over 4

=cut


use strict;
use Carp ();
use HTML::Entities ();

use vars qw($VERSION
	    %emptyElement %optionalEndTag %linkElements %boolean_attr
           );

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);
sub Version { $VERSION; }

# Elements that does not have corresponding end tags (i.e. are empty)
%emptyElement   = map { $_ => 1 } qw(base link meta isindex
			             img br hr wbr
			             input area param
			            );
%optionalEndTag = map { $_ => 1 } qw(p li dt dd option); # th tr td);

# Elements that might contain links and the name of the link attribute
%linkElements =
(
 body   => 'background',
 base   => 'href',
 a      => 'href',
 img    => [qw(src lowsrc usemap)],   # lowsrc is a Netscape invention
 form   => 'action',
 input  => 'src',
'link'  => 'href',          # need quoting since link is a perl builtin
 frame  => 'src',
 applet => 'codebase',
 area   => 'href',
);

# These attributes are normally printed without showing the "='value'".
# This representation works as long as no element has more than one
# attribute like this.
%boolean_attr = (
 area   => 'nohref',
 dir    => 'compact',
 dl     => 'compact',
 hr     => 'noshade',
 img    => 'ismap',
 input  => { checked => 1, readonly => 1, disabled => 1 },
 menu   => 'compact',
 ol     => 'compact',
 option => 'selected',
'select'=> 'multiple',
 td     => 'nowrap',
 th     => 'nowrap',
 ul     => 'compact',
);

=item $h = HTML::Element->new('tag', 'attrname' => 'value',...)

The object constructor.  Takes a tag name as argument. Optionally,
allows you to specify initial attributes at object creation time.

=cut

#
# An HTML::Element is represented by blessed hash reference.  Key-names
# not starting with '_' are reserved for the SGML attributes of the element.
# The following special keys are used:
#
#    '_tag':    The tag name
#    '_parent': A reference to the HTML::Element above (when forming a tree)
#    '_pos':    The current position (a reference to a HTML::Element) is
#               where inserts will be placed (look at the insert_element method)
#
# Example: <img src="gisle.jpg" alt="Gisle's photo"> is represented like this:
#
#  bless {
#     _tag => 'img',
#     src  => 'gisle.jpg',
#     alt  => "Gisle's photo",
#  }, HTML::Element;
#

sub new
{
    my $class = shift;
    my $tag   = shift;
    Carp::croak("No tag") unless defined $tag or length $tag;
    my $self  = bless { _tag => lc $tag }, $class;
    my($attr, $val);
    while (($attr, $val) = splice(@_, 0, 2)) {
	$val = $attr unless defined $val;
	$self->{lc $attr} = $val;
    }
    if ($tag eq 'html') {
	$self->{'_pos'} = undef;
    }
    $self;
}



=item $h->tag()

Returns (optionally sets) the tag name for the element.  The tag is
always converted to lower case.

=cut

sub tag
{
    my $self = shift;
    if (@_) {
	$self->{'_tag'} = lc $_[0];
    } else {
	$self->{'_tag'};
    }
}



=item $h->starttag()

Returns the complete start tag for the element.  Including leading
"<", trailing ">" and attributes.

=cut

sub starttag
{
    my $self = shift;
    my $name = $self->{'_tag'};
    my $tag = "<\U$name";
    for (sort keys %$self) {
	next if /^_/;
	my $val = $self->{$_};
	if ($_ eq $val &&
	    exists($boolean_attr{$name}) &&
	    (ref($boolean_attr{$name}) ? $boolean_attr{$name}{$_} : 
 					 $boolean_attr{$name} eq $_)) {
	    $tag .= " \U$_";
	} else {
	    if ($val !~ /^\d+$/) {
		# count number of " compared to number of '
		if (($val =~ tr/\"/\"/) > ($val =~ tr/\'/\'/)) {
		    # use single quotes around the attribute value
		    HTML::Entities::encode_entities($val, "&'>");
		    $val = qq('$val');
		} else {
		    HTML::Entities::encode_entities($val, '&">');
		    $val = qq{"$val"};
		}
	    }
	    $tag .= qq{ \U$_\E=$val};
	}
    }
    "$tag>";
}



=item $h->endtag()

Returns the complete end tag.  Includes leading "</" and the trailing
">".

=cut

sub endtag
{
    "</\U$_[0]->{'_tag'}>";
}



=item $h->parent([$newparent])

Returns (optionally sets) the parent for this element.

=cut

sub parent
{
    my $self = shift;
    if (@_) {
	$self->{'_parent'} = $_[0];
    } else {
	$self->{'_parent'};
    }
}



=item $h->implicit([$bool])

Returns (optionally sets) the implicit attribute.  This attribute is
used to indicate that the element was not originally present in the
source, but was inserted in order to conform to HTML strucure.

=cut

sub implicit
{
    shift->attr('_implicit', @_);
}



=item $h->is_inside('tag',...)

Returns true if this tag is contained inside one of the specified tags.

=cut

sub is_inside
{
    my $self = shift;
    my $p = $self;
    while (defined $p) {
	my $ptag = $p->{'_tag'};
	for (@_) {
	    return 1 if $ptag eq $_;
	}
	$p = $p->{'_parent'};
    }
    0;
}



=item $h->pos()

Returns (and optionally sets) the current position.  The position is a
reference to a HTML::Element object that is part of the tree that has
the current object as root.  This restriction is not enforced when
setting pos(), but unpredictable things will happen if this is not
true.


=cut

sub pos
{
    my $self = shift;
    my $pos = $self->{'_pos'};
    if (@_) {
	$self->{'_pos'} = $_[0];
    }
    return $pos if defined($pos);
    $self;
}



=item $h->attr('attr', [$value])

Returns (and optionally sets) the value of some attribute.

=cut

sub attr
{
    my $self = shift;
    my $attr = lc shift;
    my $old = $self->{$attr};
    if (@_) {
	$self->{$attr} = $_[0];
    }
    $old;
}



=item $h->content()

Returns the content of this element.  The content is represented as a
reference to an array of text segments and references to other
HTML::Element objects.

=cut

sub content
{
    shift->{'_content'};
}



=item $h->is_empty()

Returns true if there is no content.

=cut

sub is_empty
{
    my $self = shift;
    !exists($self->{'_content'}) || !@{$self->{'_content'}};
}



=item $h->insert_element($element, $implicit)

Inserts a new element at current position and updates pos() to point
to the inserted element.  Returns $element.

=cut

sub insert_element
{
    my($self, $tag, $implicit) = @_;
    my $e;
    if (ref $tag) {
	$e = $tag;
	$tag = $e->tag;
    } else {
	$e = new HTML::Element $tag;
    }
    $e->{'_implicit'} = 1 if $implicit;
    my $pos = $self->{'_pos'};
    $pos = $self unless defined $pos;
    $pos->push_content($e);
    unless ($emptyElement{$tag}) {
	$self->{'_pos'} = $e;
	$pos = $e;
    }
    $pos;
}


=item $h->push_content($element_or_text,...)

Adds to the content of the element.  The content should be a text
segment (scalar) or a reference to a HTML::Element object.

=cut

sub push_content
{
    my $self = shift;
    $self->{'_content'} = [] unless exists $self->{'_content'};
    my $content = $self->{'_content'};
    for (@_) {
	if (ref $_) {
	    $_->{'_parent'} = $self;
	    push(@$content, $_);
	} else {
	    # The current element is a text segment
	    if (@$content && !ref $content->[-1]) {
		# last content element is also text segment
		$content->[-1] .= $_;
	    } else {
		push(@$content, $_);
	    }
	}
    }
    $self;
}



=item $h->delete_content()

Clears the content.

=cut

sub delete_content
{
    my $self = shift;
    for (@{$self->{'_content'}}) {
	$_->delete if ref $_;
    }
    delete $self->{'_content'};
    $self;
}



=item $h->delete()

Frees memory associated with the element and all children.  This is
needed because perl's reference counting does not work since we use
circular references.

=cut
#'

sub delete
{
    $_[0]->delete_content;
    delete $_[0]->{'_parent'};
    delete $_[0]->{'_pos'};
    $_[0] = undef;
}



=item $h->traverse(\&callback, [$ignoretext])

Traverse the element and all of its children.  For each node visited, the
callback routine is called with the node, a startflag and the depth as
arguments.  If the $ignoretext parameter is true, then the callback
will not be called for text content.  The flag is 1 when we enter a
node and 0 when we leave the node.

If the returned value from the callback is false then we will not
traverse the children.

=cut

sub traverse
{
    my($self, $callback, $ignoretext, $depth) = @_;
    $depth ||= 0;

    if (&$callback($self, 1, $depth)) {
	for (@{$self->{'_content'}}) {
	    if (ref $_) {
		$_->traverse($callback, $ignoretext, $depth+1);
	    } else {
		&$callback($_, 1, $depth+1) unless $ignoretext;
	    }
	}
	&$callback($self, 0, $depth) unless $emptyElement{$self->{'_tag'}};
    }
    $self;
}



=item $h->extract_links([@wantedTypes])

Returns links found by traversing the element and all of its children.
The return value is a reference to an array.  Each element of the
array is an array with 2 values; the link value and a reference to the
corresponding element.

You might specify that you just want to extract some types of links.
For instance if you only want to extract <a href="..."> and <img
src="..."> links you might code it like this:

  for (@{ $e->extract_links(qw(a img)) }) {
      ($link, $linkelem) = @$_;
      ...
  }

=cut

sub extract_links
{
    my $self = shift;
    my %wantType; @wantType{map { lc $_ } @_} = (1) x @_;
    my $wantType = scalar(@_);
    my @links;
    $self->traverse(
	sub {
	    my($self, $start, $depth) = @_;
	    return 1 unless $start;
	    my $tag = $self->{'_tag'};
	    return 1 if $wantType && !$wantType{$tag};
	    my $attr = $linkElements{$tag};
	    return 1 unless defined $attr;
	    $attr = [$attr] unless ref $attr;
            for (@$attr) {
	       my $val = $self->attr($_);
	       push(@links, [$val, $self]) if defined $val;
            }
	    1;
	}, 'ignoretext');
    \@links;
}



=item $h->dump()

Prints the element and all its children to STDOUT.  Mainly useful for
debugging.  The structure of the document is shown by indentation (no
end tags).

=cut

sub dump
{
    my $self = shift;
    my $depth = shift || 0;
    print STDERR "  " x $depth;
    print STDERR $self->starttag, "\n";
    for (@{$self->{'_content'}}) {
	if (ref $_) {
	    $_->dump($depth+1);
	} else {
	    print STDERR "  " x ($depth + 1);
	    print STDERR qq{"$_"\n};
	}
    }
}



=item $h->as_HTML()

Returns a string (the HTML document) that represents the element and
its children.

=cut

sub as_HTML
{
    my $self = shift;
    my @html = ();
    $self->traverse(
        sub {
	    my($node, $start, $depth) = @_;
	    if (ref $node) {
		my $tag = $node->tag;
		if ($start) {
		    push(@html, $node->starttag);
		} elsif (not ($emptyElement{$tag} or $optionalEndTag{$tag})) {
		    push(@html, $node->endtag);
		}
	    } else {
		# simple text content
		HTML::Entities::encode_entities($node, "<>&");
		push(@html, $node);
	    }
        }
    );
    join('', @html, "\n");
}

sub format
{
    my($self, $formatter) = @_;
    unless (defined $formatter) {
	require HTML::FormatText;
	$formatter = new HTML::FormatText;
    }
    $formatter->format($self);
}


1;

__END__

=back

=head1 BUGS

If you want to free the memory assosiated with a tree built of
HTML::Element nodes then you will have to delete it explicitly.  The
reason for this is that perl currently has no proper garbage
collector, but depends on reference counts in the objects.  This
scheme fails because the parse tree contains circular references
(parents have references to their children and children have a
reference to their parent).

=head1 SEE ALSO

L<HTML::AsSubs>

=head1 COPYRIGHT

Copyright 1995-1998 Gisle Aas.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
