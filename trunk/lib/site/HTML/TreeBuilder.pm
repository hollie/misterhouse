package HTML::TreeBuilder;

=head1 NAME

HTML::TreeBuilder - Parser that builds a HTML syntax tree

=head1 SYNOPSIS

 $h = new HTML::TreeBuilder;
 $h->parse($document);
 #...

 print $h->as_HTML;  # or any other HTML::Element method

=head1 DESCRIPTION

This is a parser that builds (and actually itself is) a HTML syntax tree.

Objects of this class inherit the methods of both C<HTML::Parser> and
C<HTML::Element>.  After parsing has taken place it can be regarded as
the syntax tree itself.

The following method all control how parsing takes place.  You can set
the attributes by passing a TRUE or FALSE value as argument.

=over 4

=item $p->implicit_tags

Setting this attribute to true will instruct the parser to try to
deduce implicit elements and implicit end tags.  If it is false you
get a parse tree that just reflects the text as it stands.  Might be
useful for quick & dirty parsing.  Default is true.

Implicit elements have the implicit() attribute set.

=item $p->ignore_unknown

This attribute controls whether unknown tags should be represented as
elements in the parse tree.  Default is true.

=item $p->ignore_text

Do not represent the text content of elements.  This saves space if
all you want is to examine the structure of the document.  Default is
false.

=item $p->warn

Call warn() with an appropriate message for syntax errors.  Default is
false.

=back


=head1 SEE ALSO

L<HTML::Parser>, L<HTML::Element>

=head1 COPYRIGHT

Copyright 1995-1998 Gisle Aas. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

Gisle Aas <aas@sn.no>

=cut

use HTML::Entities ();

use strict;
use vars qw(@ISA $VERSION
            %isHeadElement %isBodyElement %isPhraseMarkup
            %isList %isTableElement %isFormElement
           );

require HTML::Element;
require HTML::Parser;
@ISA = qw(HTML::Element HTML::Parser);
($VERSION) = q$Revision$ =~ /: (\d+)/;

# Elements that should only be present in the header
%isHeadElement = map { $_ => 1 } qw(title base link meta isindex script);

# Elements that should only be present in the body
%isBodyElement = map { $_ => 1 } qw(h1 h2 h3 h4 h5 h6
				    p div pre address blockquote
				    xmp listing
				    a img br hr
				    ol ul dir menu li
				    dl dt dd
				    cite code em kbd samp strong var dfn strike
				    b i u tt small big
				    table tr td th caption
				    form input select option textarea
				    map area
				    applet param
				    isindex script
				   ),
                          # Also known are some Netscape extentions elements
                                 qw(wbr nobr center blink font basefont);

# The following elements must be directly contained in some other
# element than body.

%isPhraseMarkup = map { $_ => 1 } qw(cite code em kbd samp strong var b i u tt
				     a img br hr
				     wbr nobr center blink
				     small big font basefont
				     table
				    );

%isList         = map { $_ => 1 } qw(ul ol dir menu);
%isTableElement = map { $_ => 1 } qw(tr td th caption);
%isFormElement  = map { $_ => 1 } qw(input select option textarea);


sub new
{
    my $class = shift;
    my $self = HTML::Element->new('html');  # Initialize HTML::Element part
    $self->{'_buf'} = '';  # The HTML::Parser part of us needs this

    # Initialize parser settings
    $self->{'_implicit_tags'}  = 1;
    $self->{'_ignore_unknown'} = 1;
    $self->{'_ignore_text'}    = 0;
    $self->{'_warn'}           = 0;

    # Parse attributes passed in as arguments
    my %attr = @_;
    for (keys %attr) {
	$self->{"_$_"} = $attr{$_};
    }

    # rebless to our class
    bless $self, $class; 
}

sub _elem
{
    my($self, $elem, $val) = @_;
    my $old = $self->{$elem};
    $self->{$elem} = $val if defined $val;
    return $old;
}

sub implicit_tags  { shift->_elem('_implicit_tags',  @_); }
sub ignore_unknown { shift->_elem('_ignore_unknown', @_); }
sub ignore_text    { shift->_elem('_ignore_text',    @_); }
sub warn           { shift->_elem('_warn',           @_); }

sub warning
{
    my $self = shift;
    CORE::warn("HTML::Parse: $_[0]\n") if $self->{'_warn'};
}

sub start
{
    my($self, $tag, $attr) = @_;

    my $pos  = $self->{'_pos'};
    $pos = $self unless defined $pos;
    my $ptag = $pos->{'_tag'};
    my $e = HTML::Element->new($tag, %$attr);

    if (!$self->{'_implicit_tags'}) {
	# do nothing
    } elsif ($isBodyElement{$tag}) {

	# Ensure that we are within <body>
	if ($pos->is_inside('head')) {
	    $self->end('head');
	    $pos = $self->insert_element('body', 1);
	    $ptag = $pos->tag;
	} elsif (!$pos->is_inside('body')) {
	    $pos = $self->insert_element('body', 1);
	    $ptag = $pos->tag;
	}

	# Handle implicit endings and insert based on <tag> and position
	if ($tag eq 'p' || $tag =~ /^h[1-6]/ || $tag eq 'form') {
	    # Can't have <p>, <h#> or <form> inside these
	    $self->end([qw(p h1 h2 h3 h4 h5 h6 pre textarea)], 'li');
	} elsif ($tag =~ /^[oud]l$/) {
	    # Can't have lists inside <h#>
	    if ($ptag =~ /^h[1-6]/) {
		$self->end($ptag);
		$pos = $self->insert_element('p', 1);
		$ptag = 'p';
	    }
	} elsif ($tag eq 'li') {
	    # Fix <li> outside list
	    $self->end('li', keys %isList);
	    $ptag = $self->pos->tag;
	    $pos = $self->insert_element('ul', 1) unless $isList{$ptag};
	} elsif ($tag eq 'dt' || $tag eq 'dd') {
	    $self->end(['dt', 'dd'], 'dl');
	    $ptag = $self->pos->tag;
	    # Fix <dt> or <dd> outside <dl>
	    $pos = $self->insert_element('dl', 1) unless $ptag eq 'dl';
	} elsif ($isFormElement{$tag}) {
	    return unless $pos->is_inside('form');
	    if ($tag eq 'option') {
		# return unless $ptag eq 'select';
		$self->end('option');
		$ptag = $self->pos->tag;
		$pos = $self->insert_element('select', 1)
		  unless $ptag eq 'select';
	    }
	} elsif ($isTableElement{$tag}) {
	    $self->end($tag, 'table');
	    $pos = $self->insert_element('table', 1)
	      if !$pos->is_inside('table');
	} elsif ($isPhraseMarkup{$tag}) {
	    if ($ptag eq 'body') {
		$pos = $self->insert_element('p', 1);
	    }
	}
    } elsif ($isHeadElement{$tag}) {
	if ($pos->is_inside('body')) {
	    $self->warning("Header element <$tag> in body");
	} elsif (!$pos->is_inside('head')) {
	    $pos = $self->insert_element('head', 1);
	}
    } elsif ($tag eq 'html') {
	if ($ptag eq 'html' && $pos->is_empty()) {
	    # migrate attributes to origial HTML element
	    for (keys %$attr) {
		$self->attr($_, $attr->{$_});
	    }
	    return;
	} else {
	    $self->warning("Skipping nested <html> element");
	    return;
	}
    } elsif ($tag eq 'head') {
	if ($ptag ne 'html' && $pos->is_empty()) {
	    $self->warning("Skipping nested <head> element");
	    return;
	}
    } elsif ($tag eq 'body') {
	if ($pos->is_inside('head')) {
	    $self->end('head');
	} elsif ($ptag ne 'html') {
	    $self->warning("Skipping nested <body> element");
	    return;
	}
    } else {
	# unknown tag
	if ($self->{'_ignore_unknown'}) {
	    $self->warning("Skipping unknown tag $tag");
	    return;
	}
    }
    $self->insert_element($e);
}


sub end
{
    my($self, $tag, @stop) = @_;

    # End the specified tag, but don't move above any of the @stop tags.
    # The tag can also be a reference to an array.  Terminate the first
    # tag found.

    my $p = $self->{'_pos'};
    $p = $self unless defined($p);
    if (ref $tag) {
      PARENT:
	while (defined $p) {
	    my $ptag = $p->{'_tag'};
	    for (@$tag) {
		last PARENT if $ptag eq $_;
	    }
	    for (@stop) {
		return if $ptag eq $_;
	    }
	    $p = $p->{'_parent'};
	}
    } else {
	while (defined $p) {
	    my $ptag = $p->{'_tag'};
	    last if $ptag eq $tag;
	    for (@stop) {
		return if $ptag eq $_;
	    }
	    $p = $p->{'_parent'};
	}
    }

    # Move position if the specified tag was found
    $self->{'_pos'} = $p->{'_parent'} if defined $p;
}


sub text
{
    my $self = shift;
    my $pos = $self->{'_pos'};
    my $ignore_text = $self->{'_ignore_text'};

    $pos = $self unless defined($pos);

    my $text = shift;
    return unless length $text;

    HTML::Entities::decode($text) unless $ignore_text;

    if ($pos->is_inside(qw(pre xmp listing))) {
	return if $ignore_text;
	$pos->push_content($text);
    } else {
	# return unless $text =~ /\S/;  # This is sometimes wrong

	my $ptag = $pos->{'_tag'};
	if (!$self->{'_implicit_tags'} || $text !~ /\S/) {
	    # don't change anything
	} elsif ($ptag eq 'head') {
	    $self->end('head');
	    $self->insert_element('body', 1);
	    $pos = $self->insert_element('p', 1);
	} elsif ($ptag eq 'html') {
	    $self->insert_element('body', 1);
	    $pos = $self->insert_element('p', 1);
	} elsif ($ptag eq 'body' ||
	       # $ptag eq 'li'   ||
	       # $ptag eq 'dd'   ||
		 $ptag eq 'form') {
	    $pos = $self->insert_element('p', 1);
	}
	return if $ignore_text;
	$text =~ s/\s+/ /g;  # canoncial space
	$pos->push_content($text);
    }
}

1;
