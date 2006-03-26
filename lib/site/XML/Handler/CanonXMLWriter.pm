#
# Copyright (C) 1998, 1999 Ken MacLeod
# XML::Handler::CanonXMLWriter is free software; you can redistribute
# it and/or modify it under the same terms as Perl itself.
#
# $Id: CanonXMLWriter.pm,v 1.2 1999/12/22 21:15:00 kmacleod Exp $
#

use strict;

package XML::Handler::CanonXMLWriter;
use vars qw{ $VERSION %char_entities };

# will be substituted by make-rel script
$VERSION = "0.08";

%char_entities = (
    "\x09" => '&#9;',
    "\x0a" => '&#10;',
    "\x0d" => '&#13;',
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&quot;',
);

sub new {
    my ($class, %args) = @_;

    my $self = \%args;
    return bless $self, $class;
}

sub start_document {
    my $self = shift; my $document = shift;

    $self->{'_text_array'} = [];
}

sub end_document {
    my $self = shift; my $document = shift;

    if (defined $self->{IOHandle}) {
	return ();
    } else {
	my $text = join ('', @{$self->{'_text_array'}});
	undef $self->{'_text_array'};
	return $text;
    }
}

sub start_element {
    my $self = shift; my $element = shift;

    $self->_print('<' . $element->{Name});
    my $key;
    my $attrs = $element->{Attributes};
    foreach $key (sort keys %$attrs) {
	$self->_print(" $key=\"" . $self->_escape($attrs->{$key}) . '"');
    }
    $self->_print('>');
}

sub end_element {
    my $self = shift; my $element = shift;

    $self->_print('</' . $element->{Name} . '>');
}

sub characters {
    my $self = shift; my $characters = shift;

    $self->_print($self->_escape($characters->{Data}));
}

sub ignorable_whitespace {
    my $self = shift; my $characters = shift;

    $self->_print($self->_escape($characters->{Data}));
}

sub processing_instruction {
    my $self = shift; my $pi = shift;

    $self->_print('<?' . $pi->{Target} . ' ' . $pi->{Data} . '?>');
}

sub entity {
    # entities don't occur in text
    return ();
}

sub comment {
    my $self = shift; my $comment = shift;

    if ($self->{PrintComments}) {
	$self->_print('<!--' . $comment->{Data} . '-->');
    } else {
	return ();
    }
}

sub _print {
    my $self = shift; my $string = shift;

    if (defined $self->{IOHandle}) {
	$self->{IOHandle}->print($string);
	return ();
    } else {
	push @{$self->{'_text_array'}}, $string;
    }
}

sub _escape {
    my $self = shift; my $string = shift;

    $string =~ s/([\x09\x0a\x0d&<>"])/$char_entities{$1}/ge;
    return $string;
}

1;

__END__

=head1 NAME

XML::Handler::CanonXMLWriter - output XML in canonical XML format

=head1 SYNOPSIS

 use XML::Handler::CanonXMLWriter;

 $writer = XML::Handler::CanonXMLWriter OPTIONS;
 $parser->parse(Handler => $writer);

=head1 DESCRIPTION

C<XML::Handler::CanonXMLWriter> is a PerlSAX handler that will return
a string or write a stream of canonical XML for an XML instance and it's
content.

C<XML::Handler::CanonXMLWriter> objects hold the options used for
writing the XML objects.  Options can be supplied when the the object
is created,

    $writer = new XML::Handler::CanonXMLWriter PrintComments => 1;

or modified at any time before calling the parser's `C<parse()>' method:

    $writer->{PrintComments} = 0;

=head1 OPTIONS

=over 4

=item IOHandle

IOHandle contains a handle for writing the canonical XML to.  If an
IOHandle is not provided, the canonical XML string will be returned
from `C<parse()>'.

=item PrintComments

By default comments are not written to the output.  Setting comment to
a true value will include comments in the output.

=back

=head1 AUTHOR

Ken MacLeod, ken@bitsko.slc.ut.us

=head1 SEE ALSO

perl(1), PerlSAX

James Clark's Canonical XML definition
<http://www.jclark.com/xml/canonxml.html>

=cut
