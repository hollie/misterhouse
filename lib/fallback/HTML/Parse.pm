package HTML::Parse;

# $Id$

=head1 NAME

HTML::Parse - Depreciated

=head1 SYNOPSIS

 use HTML::Parse;
 $h = parse_htmlfile("test.html");
 print $h->dump;
 $h = parse_html("<p>Some more <i>italic</i> text", $h);
 $h->delete;

 print parse_htmlfile("index.html")->as_HTML;  # tidy up markup in a file

=head1 DESCRIPTION

I<Disclaimer: This module is only provided for backwards compatibility
with earlier versions of this library.  New code shold use the
HTML::Parser and HTML::TreeBuilder modules directly.>

The C<HTML::Parse> module provides functions to parse HTML documents.
There are two functions exported by this module:

=over 4

=item parse_html($html, [$obj])

This function is really just a synonym for $obj->parse($html) and $obj
is assumed to be a subclass of C<HTML::Parser>.  Refer to
L<HTML::Parser> for more documentation.

The $obj will default to an internally created C<HTML::TreeBuilder>
object configured with strict_comment() turned on.  This class
implements a parser that builds (and is) a HTML syntax tree with
HTML::Element objects as nodes.

The return value from parse_html() is $obj.

=item parse_htmlfile($file, [$obj])

Same as parse_html(), but obtains HTML text from the named file.

Returns C<undef> if the file could not be opened, or $obj otherwise.

=back

When a C<HTML::TreeBuilder> object is created, the following variables
control how parsing takes place:

=over 4

=item $HTML::Parse::IMPLICIT_TAGS

Setting this variable to true will instruct the parser to try to
deduce implicit elements and implicit end tags.  If this variable is
false you get a parse tree that just reflects the text as it stands.
Might be useful for quick & dirty parsing.  Default is true.

Implicit elements have the implicit() attribute set.

=item $HTML::Parse::IGNORE_UNKNOWN

This variable contols whether unknow tags should be represented as
elements in the parse tree.  Default is true.

=item $HTML::Parse::IGNORE_TEXT

Do not represent the text content of elements.  This saves space if
all you want is to examine the structure of the document.  Default is
false.

=item $HTML::Parse::WARN

Call warn() with an apropriate message for syntax errors.  Default is
false.

=back

=head1 SEE ALSO

L<HTML::Parser>, L<HTML::TreeBuilder>, L<HTML::Element>

=head1 COPYRIGHT

Copyright 1995-1998 Gisle Aas. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

Gisle Aas <aas@sn.no>

=cut


require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(parse_html parse_htmlfile);

use strict;
use vars qw($VERSION
            $IMPLICIT_TAGS $IGNORE_UNKNOWN $IGNORE_TEXT $WARN);

# Backwards compatability
$IMPLICIT_TAGS  = 1;
$IGNORE_UNKNOWN = 1;
$IGNORE_TEXT    = 0;
$WARN           = 0;

require HTML::TreeBuilder;

($VERSION) = q$Revision$ =~ /: (\d+)/;


sub parse_html ($;$)
{
    my $p = $_[1];
    $p = _new_tree_maker() unless $p;
    $p->parse($_[0]);
}


sub parse_htmlfile ($;$)
{
    my($file, $p) = @_;
    local(*HTML);
    open(HTML, $file) or return undef;
    $p = _new_tree_maker() unless $p;
    $p->parse_file(\*HTML);
}

sub _new_tree_maker
{
    my $p = HTML::TreeBuilder->new(implicit_tags  => $IMPLICIT_TAGS,
		 	           ignore_unknown => $IGNORE_UNKNOWN,
			           ignore_text    => $IGNORE_TEXT,
				   'warn'         => $WARN,
				  );
    $p->strict_comment(1);
    $p;
}

1;
