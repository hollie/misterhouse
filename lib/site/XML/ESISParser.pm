#
# Copyright (C) 1999 Ken MacLeod
# See the file COPYING for distribution terms.
#
# $Id: ESISParser.pm,v 1.9 2000/03/02 20:18:09 kmacleod Exp $
#

use strict;

use IO::File;
use UNIVERSAL;

package XML::ESISParser;

use vars qw{ $VERSION $NSGMLS_sgml $NSGMLS_FLAGS_sgml $NSGMLS_ENV_sgml
	     $NSGMLS_xml $NSGMLS_FLAGS_xml $NSGMLS_ENV_xml
	     $XML_DECL };

# will be substituted by make-rel script
$VERSION = "0.08";

$NSGMLS_sgml = 'nsgmls';
$NSGMLS_FLAGS_sgml = '-oentity -oempty -onotation-sysid -oincluded -oline -E0';
$NSGMLS_ENV_sgml = '';

$NSGMLS_xml = 'nsgmls';
$XML_DECL = '/usr/lib/sgml/declaration/xml.decl';
$NSGMLS_FLAGS_xml = '-oentity -oempty -onotation-sysid -oline -oincluded -wxml -E0 ';
$NSGMLS_ENV_xml = 'SP_CHARSET_FIXED=YES SP_ENCODING=XML';

sub new {
    my $type = shift;

    return bless { @_ }, $type;
}

sub parse {
    my $self = shift;

    die "XML::ESISParser: parser instance ($self) already parsing\n"
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
	     || defined $parse_options->{Source}{SystemId}
	     || defined $parse_options->{Source}{ESISStream})) {
	die "XML::ESISParser: no source defined for parse\n";
    }

    # assign default Handler to any undefined handlers
    if (defined $parse_options->{Handler}) {
	$parse_options->{DocumentHandler} = $parse_options->{Handler}
	    if (!defined $parse_options->{DocumentHandler});
	$parse_options->{DTDHandler} = $parse_options->{Handler}
	    if (!defined $parse_options->{DTDHandler});
	$parse_options->{ErrorHandler} = $parse_options->{Handler}
	    if (!defined $parse_options->{ErrorHandler});
    }

    # create the NSGMLS command
    my ($nsgmls_command, $nsgmls, $nsgmls_flags);
    if (defined $parse_options->{NSGMLSCommand}) {
	$nsgmls_command = $parse_options->{NSGMLSCommand};
    } elsif (defined $parse_options->{IsSGML}
	     && $parse_options->{IsSGML}) {
	my $declaration = (defined $parse_options->{Declaration})
	    ? " " . $parse_options->{Declaration} : "";
	$nsgmls = $parse_options->{NSGMLS} = $NSGMLS_sgml;
	$nsgmls_flags = $parse_options->{NSGMLS_FLAGS} = $NSGMLS_FLAGS_sgml;
	$nsgmls_command = $parse_options->{NSGMLS_COMMAND} = "$nsgmls $nsgmls_flags $declaration";
    } else {
	my $declaration = (defined $parse_options->{Declaration})
	    ? $parse_options->{Declaration} : $XML_DECL;
	$nsgmls = $parse_options->{NSGMLS} = $NSGMLS_xml;
	$nsgmls_flags = $parse_options->{NSGMLS_FLAGS} = $NSGMLS_FLAGS_xml;
	$nsgmls_command = $parse_options->{NSGMLS_COMMAND} = "$NSGMLS_ENV_xml $nsgmls $nsgmls_flags $declaration";
    }
	

    my $result;
    if (defined $self->{ParseOptions}{Source}{ESISStream}) {
	# read ESIS stream directly
	my $system_id = (defined $self->{ParseOptions}{Source}{SystemId})
	    ? "\`$self->{ParseOptions}{Source}{SystemId}'" : 'ESIS Stream';
	eval { $result = $self->parse_fh ($self->{ParseOptions}{Source}{ESISStream}) };
	my $retval = $@;

	if ($retval) {
	    die "XML::ESISParser::parse: unable to parse \`$system_id'\n$retval";
	}
    } elsif (defined $self->{ParseOptions}{Source}{ByteStream}) {
	# call nsgmls using file handle
	# FIXME special case stdin?

	# For ByteStreams (Perl file handles) we create a sub-process
	# that we feed the XML/SGML document and we get back the ESIS
	# stream
	my $retval;
	my $system_id = (defined $self->{ParseOptions}{Source}{SystemId})
	    ? "\`$self->{ParseOptions}{Source}{SystemId}'" : 'Byte Stream';
	my ($pid) = open (ESIS, "-|");
	if ($pid == 0) {
	    # 20% speed increase if grep swipes implieds (only 8% if
	    # we do it in `parse_fh').  XXX use a C routine or patch SP
	    open (SGML, "| $nsgmls_command 2>&1 | egrep -v '^A.* IMPLIED\$'")
	        or die "XML::ESISParser::parse: can't run \`$nsgmls' on \`$system_id'\n";

	    $self->{ParseOptions}{Source}{ByteStream}->print (*SGML);

	    close (SGML)
		or die "XML::ESISParser::parse: can't run \`$nsgmls' on \`$system_id'\n";

	    exit 0;
	} else {
	    eval { $result = $self->parse_fh (*ESIS) };
	    $retval = $@;
	    wait;		# clean up that process
	}
	close (ESIS);

	$self->{ParseOptions}{Source}{ByteStream}->close ();

	if ($retval) {
	    die "XML::ESISParser::parse: unable to parse \`$system_id'\n$retval";
	}
    } elsif (defined $self->{ParseOptions}{Source}{String}) {
	# call nsgmls with a literal string
    } elsif (defined $self->{ParseOptions}{Source}{SystemId}) {
	# if SystemId is a file, call nsgmls with file name
	# otherwise, open stream on SystemId and do ByteStream

	# FIXME this only handles file SystemIds right now
	# 20% speed increase if grep swipes implieds (only 8% if
	# we do it in `parse').  XXX use a C routine or patch SP
	my $system_id = $self->{ParseOptions}{Source}{SystemId};
	my ($fh) = IO::File->new
	    ("$nsgmls_command '$system_id' 2>&1 | egrep -v '^A.* IMPLIED\$' |");
	die "XML::ESISParser::parse: can't run \`$nsgmls' on \`$system_id'\n"
	    if (!defined $fh);

	eval { $result = $self->parse_fh ($fh) };
	my $retval = $@;

	close ($fh);

	if ($retval) {
	    die "XML::ESISParser::parse: unable to parse \`$system_id'\n$retval";
	}
    }
	

    # clean up parser instance
    delete $self->{ParseOptions};
    delete $self->{DocumentHandler};
    delete $self->{DTDHandler};
    delete $self->{ErrorHandler};

    return $result;
}

#
# Parse the `ESIS' information coming from `file'
#

sub parse_fh {
    my ($self, $file) = @_;
    my (@attributes, @properties, $files);

    my $doc_h = $self->{ParseOptions}{DocumentHandler};
    my $dtd_h = $self->{ParseOptions}{DTDHandler};
    my $err_h = $self->{ParseOptions}{ErrorHandler};

    # we cache these most commonly used `can()' calls
    my $can_start_element = $doc_h->can('start_element');
    my $can_end_element = $doc_h->can('end_element');
    my $can_characters = $doc_h->can('characters');
    my $can_record_end = $doc_h->can('record_end');

    my $line = 0;
    $doc_h->start_document( { } )
	if ($doc_h->can('start_document'));

    # 30% speed improvement by breaking the encapsulation
    my ($is_filehandle) = (ref ($file) eq "FileHandle"
			   || ref ($file) eq "IO::File");
    while ($_ = ($is_filehandle ? <$file> : $file->getline())) {
	chop;

	if (/^A/) {		# attribute
	    # Note: the output of `nsgmls' is `grep -v'ed to get rid of
	    # IMPLIED attributes, if we do it here we only get an 8%
	    # speed boost

	    my ($name, $type, $value) = split (/\s/, $', 3);

	    push (@attributes, $name => $value);

	    next;
	}

	if (/^\(/) {		# start element
	    # break the encapsulation for an 8% boost
	    if ($#attributes >= 0) {
		push (@properties, Attributes => { @attributes });
	    }
	    $doc_h->start_element ({ Name => $', @properties })
		if ($can_start_element);

	    @properties = (); @attributes = ();
	    next;
	}

	if (/^\)/) {		# end element
	    $doc_h->end_element ({ Name => $' })
		if ($can_end_element);

	    next;
	}

	if (/^L/) {		# line number
	    $line = $';

	    next;
	}

	if (/^-/) {		# data (including sdata entities)
	    # This section is derived from David Megginson's SGMLSpm
	    my $sdata_flag = 0;
	    my $out = '';
	    my $data = $';

	    while ($data =~ /\\(\\|n|\||[0-7]{1,3})/) {
		$out .= $`;
		$data = $';

		if ($1 eq '|') {
		    # beginning or end of SDATA
		    if ("$out" ne '') {
			if ($sdata_flag) {
			    $doc_h->internal_entity_ref({ Name => $self->{'internal_entities_by_value'}{$out} })
				if ($doc_h->can('internal_entity_ref'));
			} else {
			    $doc_h->characters({ Data => $out })
				if ($can_characters);
			}
			$out = '';
		    }
		    $sdata_flag = !$sdata_flag;

		} elsif ($1 eq 'n') {
		    # record end
		    if ("$out" ne '') {
			if ($sdata_flag) {
			    $doc_h->internal_entity_ref({ Name => $self->{'internal_entities_by_value'}{$out} })
				if ($doc_h->can('internal_entity_ref'));
			} else {
			    $doc_h->characters({ Data => $out })
				if ($can_characters);
			}
			$out = '';
		    }
		    if ($can_record_end) {
			$doc_h->record_end( { } );
		    } else {
			$doc_h->characters({ Data => "\n" })
			    if ($can_characters);
		    }
		} elsif ($1 eq '\\') {
		    $out .= '\\';
		} else {
		    $out .= chr(oct($1));
		}
	    }
	    $out .= $data;
	    if ("$out" ne '') {
		if ($sdata_flag) {
		    $doc_h->internal_entity_ref({ Name => $self->{'internal_entities_by_value'}{$out} })
			if ($doc_h->can('internal_entity_ref'));
		} else {
		    $doc_h->characters({ Data => $out })
			if ($can_characters);
		}
	    }

	    next;
	}

	if (/^s/) {		# sysid
	    push (@properties, SystemId => $');

	    next;
	}

	if (/^p/) {		# pubid
	    push (@properties, PublicId => $');

	    next;
	}

	if (/^f/) {		# file
	    if (!defined $files) {
		$files = $';
	    } elsif (!ref $files) {
		$files = [ $files, $' ];
	    } else {
		push (@$files, $');
	    }

	    next;
	}

	if (/^E/) {		# external entity definition
	    my ($entity_data) = $';
	    $entity_data =~ /^(\S+) (\S+) (\S+)$/
		or die "XML::ESISParser::parse_fh: bad external entity event data: $entity_data\n";
	    my ($name,$type,$notation) = ($1,$2,$3);
	    if (defined $files) {
		push (@properties, GeneratedId => $files);
	    }
	    $dtd_h->external_entity_decl ({ Name => $name, Type => $type,
					    Notation => $notation, @properties })
		if ($dtd_h->can('external_entity_decl'));

	    @properties = (); undef $files;
	    next;
	}

	if (/^I/) {             # internal entity definition
	    my ($name, $type, $value) = split (/\s/, $', 3);
	    $self->{'internal_entities_by_value'}{$value} = $name;
	    $dtd_h->internal_entity_decl ({ Name => $name, Type => $type,
					    Value => $value })
		if ($dtd_h->can('internal_entity_decl'));

	    next;
	}

	if (/^&/) {		# external entity reference
	    my ($name) = $';
	    $doc_h->external_entity_ref({ Name => $name })
		if ($doc_h->can('external_entity_ref'));

	    next;
	}

	if (/^\?/) {		# processing instruction (PI)
	    my ($data) = $';
	    if ($self->{ParseOptions}{IsSGML}) {
		$doc_h->processing_instruction({ Data => $data })
		    if ($doc_h->can('processing_instruction'));
	    } else {
		my ($target, $pi_data) = split (/\s+/, $data, 2);
		$doc_h->processing_instruction({ Target => $target, Data => $pi_data })
		    if ($doc_h->can('processing_instruction'));
	    }

	    next;
	}

	if (/^N/) {		# notation definition
	    my ($name) = $';
	    if (defined $files) {
		push (@properties, GeneratedId => $files);
	    }
	    $dtd_h->notation_decl ({ Name => $name, @properties })
		if ($dtd_h->can('notation_decl'));

	    @properties = (); undef $files;
	    next;
	}

	if (/^S/) {		# subdoc definition
	    my ($name) = $';
	    if (defined $files) {
		push (@properties, GeneratedId => $files);
	    }
	    $dtd_h->subdoc_entity_decl ({ Name => $name, @properties })
		if ($dtd_h->can('subdoc_entity_decl'));

	    @properties = (); undef $files;
	    next;
	}

	if (/^T/) {		# external SGML text entity definition
	    my ($name) = $';
	    if (defined $files) {
		push (@properties, GeneratedId => $files);
	    }
	    $dtd_h->external_sgml_entity_decl ({ Name => $name, @properties })
		if ($dtd_h->can('external_sgml_entity_decl'));

	    @properties = (); undef $files;
	    next;
	}

	if (/^D/) {             # data attribute
	    # FIXME
	    my $message = "XML::ESISParser: can't handle data attributes yet\n";
	    if ($err_h->can('error')) {
		$err_h->error ({ Message => $message });
	    } else {
		die "$message";
	    }

	    next;
	}

	if (/^D/) {             # link attribute
	    # FIXME
	    my $message = "XML::ESISParser: can't handle link attributes yet\n";
	    if ($err_h->can('error')) {
		$err_h->error ({ Message => $message });
	    } else {
		die "$message";
	    }

	    next;
	}

	if (/^{/) {		# subdoc start
	    my ($name) = $';
	    $doc_h->start_subdoc ({ Name => $name })
		if ($doc_h->can('start_subdoc'));

	    next;
	}

	if (/^}/) {		# subdoc end
	    my ($name) = $';
	    $doc_h->end_subdoc ({ Name => $name })
		if ($doc_h->can('end_subdoc'));

	    next;
	}

	if (/^#/) {		# appinfo
	    my ($text) = $';
	    $doc_h->appinfo ({ Text => $text })
	        if ($doc_h->can('appinfo'));

	    next;
	}

	if (/^i/) {             # next element is an included subelement
	    push (@properties, IncludedSubelement => 1);

	    next;
	}

	if (/^e/) {             # next element is declared empty
	    push (@properties, Empty => 1);

	    next;
	}

	if (/^C/) {		# conforming
	    $doc_h->conforming({})
		if ($doc_h->can('conforming'));

	    next;
	}

	if (/^$self->{ParseOptions}{NSGMLS}:/) {	# `nsgmls' error
	    my $message = $_;
	    if ($err_h->can('error')) {
		$err_h->error ({ Message => $message });
	    } else {
		die "$message\n";
	    }

	    next;
	}

	my ($op) = substr ($_, 0, 1);
	my $message = "XML::ESISParser::parse_fh: ESIS command character \`$op' not recognized when reading line \`$_' around line $line ($.)";
	if ($err_h->can('error')) {
	    $err_h->error ({ Message => $message });
	} else {
	    die "$message";
	}
    }

    if ($doc_h->can('end_document')) {
	return $doc_h->end_document({});
    } else {
	return ();
    }
}

1;

__END__

=head1 NAME

XML::ESISParser - Perl SAX parser using nsgmls

=head1 SYNOPSIS

 use XML::ESISParser;

 $parser = XML::ESISParser->new( [OPTIONS] );
 $result = $parser->parse( [OPTIONS] );

 $result = $parser->parse($string);

=head1 DESCRIPTION

C<XML::ESISParser> is a Perl SAX parser using the `nsgmls' command of
James Clark's SGML Parser (SP), a validating XML and SGML parser.
This man page summarizes the specific options, handlers, and
properties supported by C<XML::ESISParser>; please refer to the Perl
SAX standard in `C<SAX.pod>' for general usage information.

C<XML::ESISParser> defaults to parsing XML and has an option for
parsing SGML.

`C<nsgmls>' source, and binaries for some platforms, is available from
<http://www.jclark.com/>.  `C<nsgmls>' is included in both the SP and
Jade packages.

=head1 METHODS

=over 4

=item new

Creates a new parser object.  Default options for parsing, described
below, are passed as key-value pairs or as a single hash.  Options may
be changed directly in the parser object unless stated otherwise.
Options passed to `C<parse()>' override the default options in the
parser object for the duration of the parse.

=back

=head1 OPTIONS

The following options are supported by C<XML::ESISParser>:

 Handler          default handler to receive events
 DocumentHandler  handler to receive document events
 DTDHandler       handler to receive DTD events
 ErrorHandler     handler to receive error events
 Source           hash containing the input source for parsing
 IsSGML           the document to be parsed is in SGML

If no handlers are provided then all events will be silently ignored.

If a single string argument is passed to the `C<parse()>' method, it
is treated as if a `C<Source>' option was given with a `C<String>'
parameter.

The `C<Source>' hash may contain the following parameters:

 ByteStream       The raw byte stream (file handle) containing the
                  document.
 String           A string containing the document.
 SystemId         The system identifier (URI) of the document.

If more than one of `C<ByteStream>', `C<String>', or `C<SystemId>',
then preference is given first to `C<ByteStream>', then `C<String>',
then `C<SystemId>'.

=head1 HANDLERS

The following handlers and properties are supported by
C<XML::ESISParser>:

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
 IncludedSubelement This element is an included subelement.
 Empty            This element is declared empty.

The `C<Attributes>' hash contains only string values.  The `C<Empty>'
flag is not set for an element that merely has no content, it is set
only if the DTD declares it empty.

BETA: Attribute values currently do not expand SData entities into
entity objects, they are still in the system data notation used by
nsgmls (inside `|').  A future version of XML::ESISParser will also
convert other types of attributes into their respective objects,
currently just their notation or entity names are given.

=item end_element

Receive notification of the end of an element.

 Name             The element type name.

=item characters

Receive notification of character data.

 Data             The characters from the document.

=item record_end

Receive notification of a record end sequence.  XML applications
should convert this to a new-line.

=item processing_instruction

Receive notification of a processing instruction. 

 Target           The processing instruction target in XML.
 Data             The processing instruction data, if any.

=item internal_entity_ref

Receive notification of a system data (SData) internal entity
reference.

 Name             The name of the internal entity reference.

=item external_entity_ref

Receive notification of a external entity reference.

 Name             The name of the external entity reference.

=item start_subdoc

Receive notification of the start of a sub document.

 Name             The name of the external entity reference.

=item end_subdoc

Receive notification of the end of a sub document.

 Name             The name of the external entity reference.

=item conforming

Receive notification that the document just parsed conforms to it's
document type declaration (DTD).

No properties defined.

=back

=head2 DTDHandler methods

=over 4

=item external_entity_decl

Receive notification of an external entity declaration.

 Name             The entity's entity name.
 Type             The entity's type (CDATA, NDATA, etc.)
 SystemId         The entity's system identifier.
 PublicId         The entity's public identifier, if any.
 GeneratedId      Generated system identifiers, if any.

=item internal_entity_decl

Receive notification of an internal entity declaration.

 Name             The entity's entity name.
 Type             The entity's type (CDATA, NDATA, etc.)
 Value            The entity's character value.

=item notation_decl

Receive notification of a notation declaration.

 Name             The notation's name.
 SystemId         The notation's system identifier.
 PublicId         The notation's public identifier, if any.
 GeneratedId      Generated system identifiers, if any.

=item subdoc_entity_decl

Receive notification of a subdocument entity declaration.

 Name             The entity's entity name.
 SystemId         The entity's system identifier.
 PublicId         The entity's public identifier, if any.
 GeneratedId      Generated system identifiers, if any.

=item external_sgml_entity_decl

Receive notification of an external SGML-entity declaration.

 Name             The entity's entity name.
 SystemId         The entity's system identifier.
 PublicId         The entity's public identifier, if any.
 GeneratedId      Generated system identifiers, if any.

=back

=head1 AUTHOR

Ken MacLeod, ken@bitsko.slc.ut.us

=head1 SEE ALSO

perl(1), PerlSAX.pod(3)

 Extensible Markup Language (XML) <http://www.w3c.org/XML/>
 SAX 1.0: The Simple API for XML <http://www.megginson.com/SAX/>
 SGML Parser (SP) <http://www.jclark.com/sp/>

=cut
