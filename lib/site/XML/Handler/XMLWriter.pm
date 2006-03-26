#
# Copyright (C) 1999 Ken MacLeod
# Portions derived from code in XML::Writer by David Megginson
# XML::Handler::XMLWriter is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: XMLWriter.pm,v 1.2 1999/12/22 21:15:00 kmacleod Exp $
#

use strict;

package XML::Handler::XMLWriter;
use XML::Handler::Subs;

use vars qw{ $VERSION @ISA $escapes };

# will be substituted by make-rel script
$VERSION = "0.08";

@ISA = qw{ XML::Handler::Subs };

$escapes = { '&' => '&amp;',
	     '<' => '&lt;',
	     '>' => '&gt;',
	     '"' => '&quot;'
	 };

sub start_document {
    my ($self, $document) = @_;

    $self->SUPER::start_document($document);

    # create a temporary Output_ in case we're creating a standard
    # output file that we'll delete later.
    if (!$self->{AsString} && !defined($self->{Output})) {
	require IO::File;
	import IO::File;
	$self->{Output_} = new IO::File(">-");
    } elsif (defined($self->{Output})) {
	$self->{Output_} = $self->{Output};
    }

    if ($self->{AsString}) {
	$self->{Strings} = [];
    }

    $self->print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");

    # FIXME support Doctype declarations
}

sub end_document {
    my ($self, $document) = @_;

    if (defined($self->{Output_})) {
	$self->{Output_}->print("\n");
	delete $self->{Output_};
    }

    my $string = undef;
    if (defined($self->{AsString})) {
	push @{$self->{Strings}}, "\n";
	$string = join('', @{$self->{Strings}});
	delete $self->{Strings};
    }

    $self->SUPER::end_document($document);

    return($string);
}

sub start_element {
    my ($self, $element) = @_;

    if ($self->SUPER::start_element($element) == 0) {
	$self->print_start_element($element);
    }
}

sub print_start_element {
    my ($self, $element)  = @_;

    my $output = "<$element->{Name}";
    if (defined($element->{Attributes})) {
	foreach my $name (sort keys %{$element->{Attributes}}) {
	    my $esc_value = $element->{Attributes}{$name};
	    $esc_value =~ s/([\&\<\>\"])/$escapes->{$1}/ge;
	    $output .= " $name=\"$esc_value\"";
	}
    }

    if ($self->{Newlines}) {
	$output .= "\n";
    }

    $output .= ">";

    $self->print($output);
}

sub end_element {
    my ($self, $element) = @_;

    if ($self->SUPER::end_element($element) == 0) {
	$self->print_end_element($element);
    }
}

sub print_end_element {
    my ($self, $element) = @_;

    my $output = "</$element->{Name}"
	. ($self->{Newlines} ? "\n" : "") . ">";

    $self->print($output);
}
sub characters {
    my ($self, $characters) = @_;

    my $output = $characters->{Data};

    $output =~ s/([\&\<\>])/$escapes->{$1}/ge;

    $self->print($output);
}

sub processing_instruction {
    my ($self, $pi) = @_;

    my $nl = ($#{$self->{Names}} == -1) ? "\n" : "";

    my $output;
    if ($self->{IsSGML}) {
	$output = "<?$pi->{Data}>\n";
    } else {
	if ($pi->{Data}) {
	    $output = "<?$pi->{Target} $pi->{Data}?>$nl";
	} else {
	    $output = "<?$pi->{Target}?>$nl";
	}
    }

    $self->print($output);
}

sub ignorable_whitespace {
    my ($self, $whitespace) = @_;

    $self->print($whitespace->{Data});
}

sub comment {
    my ($self, $comment) = @_;

    my $nl = ($#{$self->{Names}} == -1) ? "\n" : "";

    my $output = "<!-- $comment->{Data} -->$nl";

    $self->print($output);
}

sub print {
    my ($self, $output) = @_;

    $self->{Output_}->print($output)
	if (defined($self->{Output_}));

    push(@{$self->{Strings}}, $output)
	if (defined($self->{AsString}));
}

1;

__END__

=head1 NAME

XML::Handler::XMLWriter - a PerlSAX handler for writing readable XML

=head1 SYNOPSIS

 use XML::Parser::PerlSAX;
 use XML::Handler::XMLWriter;

 $my_handler = XML::Handler::XMLWriter->new( I<OPTIONS> );

 XML::Parser::PerlSAX->new->parse(Source => { SystemId => 'REC-xml-19980210.xml' },
                                  Handler => $my_handler);

=head1 DESCRIPTION

C<XML::Handler::XMLWriter> is a PerlSAX handler for writing readable
XML (in contrast to Canonical XML, for example).
XML::Handler::XMLWriter can be used with a parser to reformat XML,
with XML::DOM or XML::Grove to write out XML, or with other PerlSAX
modules that generate events.

C<XML::Handler::XMLWriter> is intended to be used with PerlSAX event
generators and does not perform any checking itself (for example,
matching start and end element events).  If you want to generate XML
directly from your Perl code, use the XML::Writer module.  XML::Writer
has an easy to use interface and performs many checks to make sure
that the XML you generate is well-formed.

C<XML::Handler::XMLWriter> is a subclass of C<XML::Handler::Subs>.
C<XML::Handler::XMLWriter> can be further subclassed to alter it's
behavior or to add element-specific handling.  In the subclass, each
time an element starts, a method by that name prefixed with `s_' is
called with the element to be processed.  Each time an element ends, a
method with that name prefixed with `e_' is called.  Any special
characters in the element name are replaced by underscores.  If there
isn't a start or end method for an element, the default action is to
write the start or end tag.  Start and end methods can use the
`C<print_start_element()>' and `C<print_end_element()>' methods to
print start or end tags.  Subclasses can call the `C<print()>' method
to write additional output.

Subclassing XML::Handler::XMLWriter in this way is similar to
XML::Parser's Stream style.

XML::Handler::Subs maintains a stack of element names,
`C<$self->{Names}', and a stack of element nodes, `C<$self->{Nodes}>'
that can be used by subclasses.  The current element is pushed on the
stacks before calling an element-name start method and popped off the
stacks after calling the element-name end method.

See XML::Handler::Subs for additional methods.

In addition to the standard PerlSAX handler methods (see PerlSAX for
descriptions), XML::Handler::XMLWriter supports the following methods:

=over 4

=item new( I<OPTIONS> )

Creates and returns a new instance of XML::Handler::XMLWriter with the
given I<OPTIONS>.  Options may be changed at any time by modifying
them directly in the hash returned.  I<OPTIONS> can be a list of key,
value pairs or a hash.  The following I<OPTIONS> are supported:

=over 4

=item Output

An IO::Handle or one of it's subclasses (such as IO::File), if this
parameter is not present and the AsString option is not used, the
module will write to standard output.

=item AsString

Return the generated XML as a string from the `C<parse()>' method of
the PerlSAX event generator.

=item Newlines

A true or false value; if this parameter is present and its value is
true, then the module will insert an extra newline before the closing
delimiter of start, end, and empty tags to guarantee that the document
does not end up as a single, long line.  If the paramter is not
present, the module will not insert the newlines.

=item IsSGML

A true or false value; if this parameter is present and its value is
true, then the module will generate SGML rather than XML.

=back

=item print_start_element($element)

Print a start tag for `C<$element>'.  This is the default action for
the PerlSAX `C<start_element()>' handler, but subclasses may use this
if they define a start method for an element.

=item print_end_element($element)

Prints an end tag for `C<$element>'.  This is the default action for
the PerlSAX `C<end_element()>' handler, but subclasses may use this
if they define a start method for an element.

=item print($output)

Write `C<$output>' to Output and/or append it to the string to be
returned.  Subclasses may use this to write additional output.

=back

=head1 TODO

=over 4

=item *

An Elements option that provides finer control over newlines than the
Newlines option, where you can choose before and after newline for
element start and end tags.  Inspired by the Python XMLWriter.

=item *

Support Doctype and XML declarations.

=back

=head1 AUTHOR

Ken MacLeod, ken@bitsko.slc.ut.us
This module is partially derived from XML::Writer by David Megginson.

=head1 SEE ALSO

perl(1), PerlSAX.pod(3)

=cut
