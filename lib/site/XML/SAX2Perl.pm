#
# Copyright (C) 1998 Ken MacLeod
# XML::SAX2Perl is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: SAX2Perl.pm,v 1.4 2001/07/23 15:47:15 kmacleod Exp $
#

use strict;

package XML::SAX2Perl;

use vars qw{ $VERSION };

# will be substituted by make-rel script
$VERSION = "0.08";

sub new {
    my $type = shift;
    my $self = ($#_ == 0) ? shift : { @_ };

    return bless $self, $type;
}

sub setDocumentLocator {
    my $self = shift;
    my $self->{Locator} = shift;
}

sub startDocument {
    my $self = shift;

    my @properties;
    if (defined $self->{Locator}) {
	push @properties, locator => $self->{Locator};
    }

    $self->{DocumentHandler}->start_document(@properties);
}

sub endDocument {
    my $self = shift;

    $self->{DocumentHandler}->end_document;
}

sub startElement {
    my $self = shift;
    my $name = shift;
    my $attributes = shift;

    # FIXME depends on how Perl SAX treats attributes
    $self->{DocumentHandler}->start_element(Name => $name, Attributes => $attributes);
}

sub endElement {
    my $self = shift;
    my $name = shift;

    $self->{DocumentHandler}->end_element(Name => $name);
}

sub characters {
    my $self = shift;
    my $ch = shift;
    my $start = shift;
    my $length = shift;

    $self->{DocumentHandler}->characters(Data => substr($ch, $start, $length));
}

sub ignorableWhitespace {
    my $self = shift;
    my $ch = shift;
    my $start = shift;
    my $length = shift;

    $self->{DocumentHandler}->ignorable_whitespace(Data => substr($ch, $start, $length));
}

sub processingInstruction {
    my $self = shift;
    my $target = shift;
    my $data = shift;

    $self->{DocumentHandler}->processing_instruction(Target => $target, Data => $data);
}

1;

__END__

=head1 NAME

XML::SAX2Perl -- translate Java/CORBA style SAX methods to Perl methods

=head1 SYNOPSIS

 use XML::SAX2Perl;

 $sax2perl = XML::SAX2Perl(Handler => $my_handler);
 $sax->setDocumentHandler($sax2perl);

=head1 DESCRIPTION

C<XML::SAX2Perl> is a SAX filter that translates Java/CORBA style SAX
methods to Perl style method calls.  This man page summarizes the
specific options, handlers, and properties supported by
C<XML::SAX2Perl>; please refer to the Perl SAX standard C<XML::SAX>
for general usage information.

=head1 METHODS

=over 4

=item new

Creates a new parser object.  Default options for parsing, described
below, are passed as key-value pairs or as a single hash.  Options may
be changed directly in the parser object unless stated otherwise.
Options passed to `C<parse()>' override the default options in the
parser object for the duration of the parse.

=item parse

Parses a document.  Options, described below, are passed as key-value
pairs or as a single hash.  Options passed to `C<parse()>' override
default options in the parser object.

=item location

Returns the location as a hash:

  ColumnNumber    The column number of the parse.
  LineNumber      The line number of the parse.
  PublicId        A string containing the public identifier, or undef
                  if none is available.
  SystemId        A string containing the system identifier, or undef
                  if none is available.

=item SAX DocumentHandler Methods

The following methods are DocumentHandler methods that the SAX 1.0
parser will call and C<XML::SAX2Perl> will translate to Perl SAX
methods calls.  See SAX 1.0 for details.

 setDocumentLocator(locator)
 startDocument()
 endDocument()
 startElement(name, atts)
 endElement(name)
 characters(ch, start, length)
 ignorableWhitespace(ch, start, length)
 processingInstruction(target, data)

=back

=head1 OPTIONS

The following options are supported by C<XML::SAX2Perl>:

 Handler          default handler to receive events
 DocumentHandler  handler to receive document events
 DTDHandler       handler to receive DTD events
 ErrorHandler     handler to receive error events
 EntityResolver   handler to resolve entities
 Locale           locale to provide localisation for errors
 Source           hash containing the input source for parsing

If no handlers are provided then all events will be silently ignored,
except for `C<fatal_error()>' which will cause a `C<die()>' to be
called after calling `C<end_document()>'.

If a single string argument is passed to the `C<parse()>' method, it
is treated as if a `C<Source>' option was given with a `C<String>'
parameter.

The `C<Source>' hash may contain the following parameters:

 ByteStream       The raw byte stream (file handle) containing the
                  document.
 String           A string containing the document.
 SystemId         The system identifier (URI) of the document.
 PublicId         The public identifier.
 Encoding         A string describing the character encoding.

If more than one of `C<ByteStream>', `C<String>', or `C<SystemId>',
then preference is given first to `C<ByteStream>', then `C<String>',
then `C<SystemId>'.

=head1 HANDLERS

The following handlers and properties are supported by
C<XML::SAX2Perl>:

=head2 DocumentHandler methods

=over 4

=item start_document

Receive notification of the beginning of a document. 

 Locator          An object that can return the location of any SAX
                  document event.

=item end_document

Receive notification of the end of a document. 

No properties defined.

=item start_element

Receive notification of the beginning of an element. 

 Name             The element type name.
 Attributes       Attributes attached to the element, if any.

ALPHA WARNING: The `C<Attributes>' value is not translated from the
SAX 1.0 value, so it will contain an AttributeList object.

=item end_element

Receive notification of the end of an element. 

 Name             The element type name.

=item characters

Receive notification of character data. 

 Data             The characters from the XML document.

=item ignorable_whitespace

Receive notification of ignorable whitespace in element content. 

 Data             The characters from the XML document.

=item processing_instruction

Receive notification of a processing instruction. 

 Target           The processing instruction target. 
 Data             The processing instruction data, if any.

=back

=head1 AUTHOR

Ken MacLeod <ken@bitsko.slc.ut.us>

=head1 SEE ALSO

perl(1), XML::Perl2SAX(3).

 Extensible Markup Language (XML) <http://www.w3c.org/XML/>
 Simple API for XML (SAX) <http://www.megginson.com/SAX/>

=cut
