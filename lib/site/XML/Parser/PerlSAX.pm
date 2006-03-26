#
# Copyright (C) 1999 Ken MacLeod
# XML::Parser::PerlSAX is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: PerlSAX.pm,v 1.7 1999/12/22 21:15:00 kmacleod Exp $
#

use strict;

package XML::Parser::PerlSAX;

use XML::Parser;
use UNIVERSAL;
use vars qw{ $VERSION $name_re };

# will be substituted by make-rel script
$VERSION = "0.08";

# FIXME I doubt this is a correct Perl RE for productions [4] and
# [5] in the XML 1.0 specification, especially considering Unicode chars
$name_re = '[A-Za-z_:][A-Za-z0-9._:-]*';

sub new {
    my $type = shift;
    my $self = (@_ == 1) ? shift : { @_ };

    return bless $self, $type;
}

sub parse {
    my $self = shift;

    die "XML::Parser::PerlSAX: parser instance ($self) already parsing\n"
	if (defined $self->{ParseOptions});

    # If there's one arg and it has no ref, it's a string
    my $args;
    if (scalar (@_) == 1 && !ref($_[0])) {
	$args = { Source => { String => shift } };
    } else {
	$args = (scalar (@_) == 1) ? shift : { @_ };
    }

    my $parse_options = { %$self, %$args };
    $self->{ParseOptions} = $parse_options;

    # ensure that we have at least one source
    if (!defined $parse_options->{Source}
	|| !(defined $parse_options->{Source}{String}
	     || defined $parse_options->{Source}{ByteStream}
	     || defined $parse_options->{Source}{SystemId})) {
	die "XML::Parser::PerlSAX: no source defined for parse\n";
    }

    # assign default Handler to any undefined handlers
    if (defined $parse_options->{Handler}) {
	$parse_options->{DocumentHandler} = $parse_options->{Handler}
	    if (!defined $parse_options->{DocumentHandler});
	$parse_options->{DTDHandler} = $parse_options->{Handler}
	    if (!defined $parse_options->{DTDHandler});
	$parse_options->{EntityResolver} = $parse_options->{Handler}
	    if (!defined $parse_options->{EntityResolver});
    }

    my @handlers;
    if (defined $parse_options->{DocumentHandler}) {
	# cache DocumentHandler in self for callbacks
	$self->{DocumentHandler} = $parse_options->{DocumentHandler};

	my $doc_h = $parse_options->{DocumentHandler};

	push (@handlers, Init => sub { $self->_handle_init(@_) } )
	    if (UNIVERSAL::can($doc_h, 'start_document'));
	push (@handlers, Final => sub { $self->_handle_final(@_) } )
	    if (UNIVERSAL::can($doc_h, 'end_document'));
	push (@handlers, Start => sub { $self->_handle_start(@_) } )
	    if (UNIVERSAL::can($doc_h, 'start_element'));
	push (@handlers, End => sub { $self->_handle_end(@_) } )
	    if (UNIVERSAL::can($doc_h, 'end_element'));
	push (@handlers, Char => sub { $self->_handle_char(@_) } )
	    if (UNIVERSAL::can($doc_h, 'characters'));
	push (@handlers, Proc => sub { $self->_handle_proc(@_) } )
	    if (UNIVERSAL::can($doc_h, 'processing_instruction'));
	push (@handlers, Comment => sub { $self->_handle_comment(@_) } )
	    if (UNIVERSAL::can($doc_h, 'comment'));
	push (@handlers, CdataStart => sub { $self->_handle_cdatastart(@_) } )
	    if (UNIVERSAL::can($doc_h, 'start_cdata'));
	push (@handlers, CdataEnd => sub { $self->_handle_cdataend(@_) } )
	    if (UNIVERSAL::can($doc_h, 'end_cdata'));
	if (UNIVERSAL::can($doc_h, 'entity_reference')) {
	    push (@handlers, Default => sub { $self->_handle_default(@_) } );
	    $self->{UseEntRefs} = 1;
	}
    }

    if (defined $parse_options->{DTDHandler}) {
	# cache DTDHandler in self for callbacks
	$self->{DTDHandler} = $parse_options->{DTDHandler};

	my $dtd_h = $parse_options->{DTDHandler};

	push (@handlers, Notation => sub { $self->_handle_notation(@_) } )
	    if (UNIVERSAL::can($dtd_h, 'notation_decl'));
	push (@handlers, Unparsed => sub { $self->_handle_unparsed(@_) } )
	    if (UNIVERSAL::can($dtd_h, 'unparsed_entity_decl'));
	push (@handlers, Entity => sub { $self->_handle_entity(@_) } )
	    if ($self->{UseEntRefs}
		|| UNIVERSAL::can($dtd_h, 'entity_decl'));
	push (@handlers, Element => sub { $self->_handle_element(@_) } )
	    if (UNIVERSAL::can($dtd_h, 'element_decl'));
	push (@handlers, Attlist => sub { $self->_handle_attlist(@_) } )
	    if (UNIVERSAL::can($dtd_h, 'attlist_decl'));
	push (@handlers, Doctype => sub { $self->_handle_doctype(@_) } )
	    if (UNIVERSAL::can($dtd_h, 'doctype_decl'));
	push (@handlers, XMLDecl => sub { $self->_handle_xmldecl(@_) } )
	    if (UNIVERSAL::can($dtd_h, 'xml_decl'));
    }

    
    if (defined $parse_options->{EntityResolver}) {
	# cache EntityResolver in self for callbacks
	$self->{EntityResolver} = $parse_options->{EntityResolver};

	my $er = $parse_options->{EntityResolver};

	push (@handlers, ExternEnt => sub { $self->_handle_extern_ent(@_) } )
	    if (UNIVERSAL::can($er, 'resolve_entity'));
    }

    my @xml_parser_options;
    if ($self->{UseEntRefs}) {
	@xml_parser_options = ( NoExpand => 1,
				Handlers => { @handlers } );
    } else {
	@xml_parser_options = ( Handlers => { @handlers } );
    }

    push (@xml_parser_options,
	  ProtocolEncoding => $self->{ParseOptions}{Source}{Encoding})
	if (defined $self->{ParseOptions}{Source}{Encoding});

    my $parser = new XML::Parser(@xml_parser_options);
    my $result;

    if (defined $self->{ParseOptions}{Source}{ByteStream}) {
	$result = $parser->parse($self->{ParseOptions}{Source}{ByteStream});
    } elsif (defined $self->{ParseOptions}{Source}{String}) {
	$result = $parser->parse($self->{ParseOptions}{Source}{String});
    } elsif (defined $self->{ParseOptions}{Source}{SystemId}) {
	$result = $parser->parsefile($self->{ParseOptions}{Source}{SystemId});
    }

    # clean up parser instance
    delete $self->{ParseOptions};
    delete $self->{DocumentHandler};
    delete $self->{DTDHandler};
    delete $self->{EntityResolver};
    delete $self->{Expat};

    return $result;
}

sub location {
    my $self = shift;

    my $expat = $self->{Expat};

    my @properties = ( ColumnNumber => $expat->current_column,
		       LineNumber => $expat->current_line,
		       BytePosition => $expat->current_byte,
		       Base => $expat->base );

    # FIXME these locations change while parsing external entities
    push (@properties, PublicId => $self->{Source}{PublicId})
	if (defined $self->{Source}{PublicId});
    push (@properties, SystemId => $self->{Source}{SystemId})
	if (defined $self->{Source}{SystemId});

    return { @properties };
}

###
### DocumentHandler methods
###

sub _handle_init {
    my $self = shift;
    my $expat = shift;

    $self->{Expat} = $expat;

    if ($self->{DocumentHandler}->can('set_document_locator')) {
	$self->{DocumentHandler}->set_document_locator( { Locator => $self } );
    }
    $self->{DocumentHandler}->start_document( { } );
}

sub _handle_final {
    my $self = shift;

    delete $self->{UseEntRefs};
    delete $self->{EntRefs};
    return $self->{DocumentHandler}->end_document( { } );
}

sub _handle_start {
    my $self = shift;
    my $expat = shift;
    my $element = shift;

    my @properties;
    if ($self->{ParseOptions}{UseAttributeOrder}) {
	# Capture order and defined() status for attributes
	my $ii;

	my $order = [];
	for ($ii = 0; $ii < $#_; $ii += 2) {
	    push @$order, $_[$ii];
	}

	push @properties, 'AttributeOrder', $order;

	# Divide by two because XML::Parser counts both attribute name
	# and value within it's index
	push @properties, 'Defaulted', ($expat->specified_attr() / 2);
    }

    $self->{DocumentHandler}->start_element( { Name => $element,
					       Attributes => { @_ },
					       @properties } );
}

sub _handle_end {
    my $self = shift;
    my $expat = shift;
    my $element = shift;

    $self->{DocumentHandler}->end_element( { Name => $element } );
}

sub _handle_char {
    my $self = shift;
    my $expat = shift;
    my $string = shift;

    $self->{DocumentHandler}->characters( { Data => $string } );
}

sub _handle_proc {
    my $self = shift;
    my $expat = shift;
    my $target = shift;
    my $data = shift;

    $self->{DocumentHandler}->processing_instruction( { Target => $target,
							Data => $data } );
}

sub _handle_comment {
    my $self = shift;
    my $expat = shift;
    my $data = shift;

    $self->{DocumentHandler}->comment( { Data => $data } );
}

sub _handle_cdatastart {
    my $self = shift;
    my $expat = shift;

    $self->{DocumentHandler}->start_cdata( { } );
}

sub _handle_cdataend {
    my $self = shift;
    my $expat = shift;

    $self->{DocumentHandler}->end_cdata( { } );
}

# Default receives all characters that aren't handled by some other
# handler, this means a lot of stuff goes through here.  All we're
# looking for are `&NAME;' entity reference sequences
sub _handle_default {
    my $self = shift;
    my $expat = shift;
    my $string = shift;

    if ($string =~ /^&($name_re);$/) {
	my $ent_ref = $self->{EntRefs}{$1};
	if (!defined $ent_ref) {
	    $ent_ref = { Name => $1 };
	}
	$self->{DocumentHandler}->entity_reference($ent_ref);
    }
}

###
### DTDHandler methods
###

sub _handle_notation {
    my $self = shift;
    my $expat = shift;
    my $notation = shift;
    my $base = shift;
    my $sysid = shift;
    my $pubid = shift;
    my @properties = (Name => $notation);

    push (@properties, Base => $base)
	if (defined $base);
    push (@properties, SystemId => $sysid)
	if (defined $sysid);
    push (@properties, PublicId => $pubid)
	if (defined $pubid);


    $self->{DTDHandler}->notation_decl( { @properties } );
}

sub _handle_unparsed {
    my $self = shift;
    my $expat = shift;
    my $entity = shift;
    my $base = shift;
    my $sysid = shift;
    my $pubid = shift;
    my @properties = (Name => $entity, SystemId => $sysid);

    push (@properties, Base => $base)
	if (defined $base);
    push (@properties, PublicId => $pubid)
	if (defined $pubid);

    $self->{DTDHandler}->unparsed_entity_decl( { @properties } );
}

sub _handle_entity {
    my $self = shift;
    my $expat = shift;
    my $name = shift;
    my $val = shift;
    my $sysid = shift;
    my $pubid = shift;
    my $ndata = shift;
    my @properties = (Name => $name);

    push (@properties, Value => $val)
	if (defined $val);
    push (@properties, PublicId => $pubid)
	if (defined $pubid);
    push (@properties, SystemId => $sysid)
	if (defined $sysid);
    push (@properties, Notation => $ndata)
	if (defined $ndata);

    my $properties = { @properties };
    if ($self->{UseEntRefs}) {
	$self->{EntRefs}{$name} = $properties;
    }
    if ($self->{DTDHandler}->can('entity_decl')) {
	$self->{DTDHandler}->entity_decl( $properties );
    }
}

sub _handle_element {
    my $self = shift;
    my $expat = shift;
    my $name = shift;
    my $model = shift;

    $self->{DTDHandler}->element_decl( { Name => $name,
					 Model => $model } );
}

sub _handle_attlist {
    my $self = shift;
    my $expat = shift;
    my $elname = shift;
    my $attname = shift;
    my $type = shift;
    my $default = shift;
    my $fixed = shift;

    $self->{DTDHandler}->attlist_decl( { ElementName => $elname,
					 AttributeName => $attname,
					 Type => $type,
					 Default => $default,
					 Fixed => $fixed } );
}

sub _handle_doctype {
    my $self = shift;
    my $expat = shift;
    my $name = shift;
    my $sysid = shift;
    my $pubid = shift;
    my $internal = shift;
    my @properties = (Name => $name);

    push (@properties, SystemId => $sysid)
	if (defined $sysid);
    push (@properties, PublicId => $pubid)
	if (defined $pubid);
    push (@properties, Internal => $internal)
	if (defined $internal);

    $self->{DTDHandler}->doctype_decl( { @properties } );
}

sub _handle_xmldecl {
    my $self = shift;
    my $expat = shift;
    my $version = shift;
    my $encoding = shift;
    my $standalone = shift;
    my @properties = (Version => $version);

    push (@properties, Encoding => $encoding)
	if (defined $encoding);
    push (@properties, Standalone => $standalone)
	if (defined $standalone);

    $self->{DTDHandler}->xml_decl( { @properties } );
}

###
### EntityResolver methods
###

sub _handle_extern_ent {
    my $self = shift;
    my $expat = shift;
    my $base = shift;
    my $sysid = shift;
    my $pubid = shift;
    my @properties = (SystemId => $sysid);

    push (@properties, Base => $base)
	if (defined $base);
    push (@properties, PublicId => $pubid)
	if (defined $pubid);

    my $result = $self->{EntityResolver}->resolve_entity( { @properties } );

    if (UNIVERSAL::isa($result, 'HASH')) {
	if ($result->{ByteStream}) {
	    return $result->{ByteStream};
	} elsif ($result->{String}) {
	    return $result->{String};
	} elsif ($result->{SystemId}) {
	    # FIXME must be able to resolve SystemIds, XML::Parser's
	    # default can :-(
	    die "PerlSAX: automatic opening of SystemIds from \`resolve_entity' not implemented, contact the author\n";
	} else {
	    # FIXME
	    die "PerlSAX: invalid source returned from \`resolve_entity'\n";
	}
    }

    return undef;
}

1;

__END__

=head1 NAME

XML::Parser::PerlSAX - Perl SAX parser using XML::Parser

=head1 SYNOPSIS

 use XML::Parser::PerlSAX;

 $parser = XML::Parser::PerlSAX->new( [OPTIONS] );
 $result = $parser->parse( [OPTIONS] );

 $result = $parser->parse($string);

=head1 DESCRIPTION

C<XML::Parser::PerlSAX> is a PerlSAX parser using the XML::Parser
module.  This man page summarizes the specific options, handlers, and
properties supported by C<XML::Parser::PerlSAX>; please refer to the
PerlSAX standard in `C<PerlSAX.pod>' for general usage information.

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
  BytePosition    The current byte position of the parse.
  PublicId        A string containing the public identifier, or undef
                  if none is available.
  SystemId        A string containing the system identifier, or undef
                  if none is available.
  Base            The current value of the base for resolving relative
                  URIs.

ALPHA WARNING: The `C<SystemId>' and `C<PublicId>' properties returned
are the system and public identifiers of the document passed to
`C<parse()>', not the identifiers of the currently parsing external
entity.  The column, line, and byte positions I<are> of the current
entity being parsed.

=head1 OPTIONS

The following options are supported by C<XML::Parser::PerlSAX>:

 Handler          default handler to receive events
 DocumentHandler  handler to receive document events
 DTDHandler       handler to receive DTD events
 ErrorHandler     handler to receive error events
 EntityResolver   handler to resolve entities
 Locale           locale to provide localisation for errors
 Source           hash containing the input source for parsing
 UseAttributeOrder set to true to provide AttributeOrder and Defaulted
                   properties in `start_element()'

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
C<XML::Parser::PerlSAX>:

=head2 DocumentHandler methods

=over 4

=item start_document

Receive notification of the beginning of a document.

No properties defined.

=item end_document

Receive notification of the end of a document.

No properties defined.

=item start_element

Receive notification of the beginning of an element.

 Name             The element type name.
 Attributes       A hash containing the attributes attached to the
                  element, if any.

The `C<Attributes>' hash contains only string values.

If the `C<UseAttributeOrder>' parser option is true, the following
properties are also passed to `C<start_element>':

 AttributeOrder   An array of attribute names in the order they were
                  specified, followed by the defaulted attribute
                  names.
 Defaulted        The index number of the first defaulted attribute in
                  `AttributeOrder.  If this index is equal to the
                  length of `AttributeOrder', there were no defaulted
                  values.

Note to C<XML::Parser> users:  `C<Defaulted>' will be half the value of
C<XML::Parser::Expat>'s `C<specified_attr()>' function because only
attribute names are provided, not their values.


=item end_element

Receive notification of the end of an element.

 Name             The element type name.

=item characters

Receive notification of character data.

 Data             The characters from the XML document.

=item processing_instruction

Receive notification of a processing instruction. 

 Target           The processing instruction target. 
 Data             The processing instruction data, if any.

=item comment

Receive notification of a comment.

 Data             The comment data, if any.

=item start_cdata

Receive notification of the start of a CDATA section.

No properties defined.

=item end_cdata

Receive notification of the end of a CDATA section.

No properties defined.

=item entity_reference

Receive notification of an internal entity reference.  If this handler
is defined, internal entities will not be expanded and not passed to
the `C<characters()>' handler.  If this handler is not defined,
internal entities will be expanded if possible and passed to the
`C<characters()>' handler.

 Name             The entity reference name
 Value            The entity reference value

=back

=head2 DTDHandler methods

=over 4

=item notation_decl

Receive notification of a notation declaration event.

 Name             The notation name.
 PublicId         The notation's public identifier, if any.
 SystemId         The notation's system identifier, if any.
 Base             The base for resolving a relative URI, if any.

=item unparsed_entity_decl

Receive notification of an unparsed entity declaration event.

 Name             The unparsed entity's name.
 SystemId         The entity's system identifier.
 PublicId         The entity's public identifier, if any.
 Base             The base for resolving a relative URI, if any.

=item entity_decl

Receive notification of an entity declaration event.

 Name             The entity name.
 Value            The entity value, if any.
 PublicId         The notation's public identifier, if any.
 SystemId         The notation's system identifier, if any.
 Notation         The notation declared for this entity, if any.

For internal entities, the `C<Value>' parameter will contain the value
and the `C<PublicId>', `C<SystemId>', and `C<Notation>' will be
undefined.  For external entities, the `C<Value>' parameter will be
undefined, the `C<SystemId>' parameter will have the system id, the
`C<PublicId>' parameter will have the public id if it was provided (it
will be undefined otherwise), the `C<Notation>' parameter will contain
the notation name for unparsed entities.  If this is a parameter entity
declaration, then a '%' will be prefixed to the entity name.

Note that `C<entity_decl()>' and `C<unparsed_entity_decl()>' overlap.
If both methods are implemented by a handler, then this handler will
not be called for unparsed entities.

=item element_decl

Receive notification of an element declaration event.

 Name             The element type name.
 Model            The content model as a string.

=item attlist_decl

Receive notification of an attribute list declaration event.

This handler is called for each attribute in an ATTLIST declaration
found in the internal subset. So an ATTLIST declaration that has
multiple attributes will generate multiple calls to this handler.

 ElementName      The element type name.
 AttributeName    The attribute name.
 Type             The attribute type.
 Fixed            True if this is a fixed attribute.

The default for `C<Type>' is the default value, which will either be
"#REQUIRED", "#IMPLIED" or a quoted string (i.e. the returned string
will begin and end with a quote character).

=item doctype_decl

Receive notification of a DOCTYPE declaration event.

 Name             The document type name.
 SystemId         The document's system identifier.
 PublicId         The document's public identifier, if any.
 Internal         The internal subset as a string, if any.

Internal will contain all whitespace, comments, processing
instructions, and declarations seen in the internal subset. The
declarations will be there whether or not they have been processed by
another handler (except for unparsed entities processed by the
Unparsed handler).  However, comments and processing instructions will
not appear if they've been processed by their respective handlers.

=item xml_decl

Receive notification of an XML declaration event.

 Version          The version.
 Encoding         The encoding string, if any.
 Standalone       True, false, or undefined if not declared.

=back

=head2 EntityResolver

=over 4

=item resolve_entity

Allow the handler to resolve external entities.

 Name             The notation name.
 SystemId         The notation's system identifier.
 PublicId         The notation's public identifier, if any.
 Base             The base for resolving a relative URI, if any.

`C<resolve_entity()>' should return undef to request that the parser
open a regular URI connection to the system identifier or a hash
describing the new input source.  This hash has the same properties as
the `C<Source>' parameter to `C<parse()>':

  PublicId    The public identifier of the external entity being
              referenced, or undef if none was supplied. 
  SystemId    The system identifier of the external entity being
              referenced.
  String      String containing XML text
  ByteStream  An open file handle.
  CharacterStream
              An open file handle.
  Encoding    The character encoding, if known.

=back

=head1 AUTHOR

Ken MacLeod, ken@bitsko.slc.ut.us

=head1 SEE ALSO

perl(1), PerlSAX.pod(3)

 Extensible Markup Language (XML) <http://www.w3c.org/XML/>
 SAX 1.0: The Simple API for XML <http://www.megginson.com/SAX/>

=cut
