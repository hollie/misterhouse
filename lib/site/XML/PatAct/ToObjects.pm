#
# Copyright (C) 1999 Ken MacLeod
# XML::PatAct::ToObjects is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: ToObjects.pm,v 1.5 1999/12/22 21:15:00 kmacleod Exp $
#

# The original XML::Grove::ToObjects actually generated and compiled a
# sub for matching actions, possibly a performance improvement of three
# or four times over all the comparisons made in start_element() and
# end_element().

use strict;

use UNIVERSAL;

package XML::PatAct::ToObjects;
use vars qw{ $VERSION $name_re };

# will be substituted by make-rel script
$VERSION = "0.08";

# FIXME I doubt this is a correct Perl RE for productions [4] and
# [5] in the XML 1.0 specification, especially considering Unicode chars
$name_re = '[A-Za-z_:][A-Za-z0-9._:-]*';

sub new {
    my $type = shift;
    my $self = ($#_ == 0) ? { %{ (shift) } } : { @_ };

    bless $self, $type;

    my $usage = <<'EOF';
usage: XML::PatAct::ToObjects->new( Matcher => $matcher,
				    Patterns => $patterns );
EOF

    die "No Matcher specified\n$usage\n"
	if !defined $self->{Matcher};
    die "No Patterns specified\n$usage\n"
	if !defined $self->{Patterns};

    # Parse action items
    $self->{Actions} = [ ];
    my $patterns = $self->{Patterns};
    my $ii = 1;
    while ($ii <= $#$patterns) {
        if (ref $patterns->[$ii]) {
	    push @{$self->{Actions}},
	      $self->_parse_action($patterns->[$ii]);
	} else {
	    # is a code fragment
	}
	$ii += 2;
    }

    if (defined $self->{GroveBuilder}) {
	require XML::Grove::Builder;
	import XML::Grove::Builder;
	$self->{GroveBuilder} = XML::Grove::Builder->new();
    }

    return $self;
}

sub start_document {
    my ($self, $document) = @_;

    $self->{Matcher}->initialize($self);
    $self->{Parents} = [ { Contents => [  ] } ];
    $self->{ActionStack} = [ ];
    $self->{States} = [ 'normal' ];
    $self->{Document} = $document;
    $self->{Names} = [ ];
    $self->{Nodes} = [ ];
    $self->{Data} = undef;
    $self->{SourceIsGrove} = UNIVERSAL::isa($document, 'Data::Grove');
    if (!defined $self->{CharacterDataType}) {
	require Data::Grove;
	import Data::Grove;
	$self->{CharacterDataType} = 'Data::Grove::Characters';
    }
}

sub end_document {
    my ($self, $document) = @_;

    $self->{Matcher}->finalize();
    # FIXME check to make sure no other fields were assigned to
    my $value = $self->{Parents}[0]{Contents};

    # release all the info that is just used during event handling
    $self->{Matcher} = $self->{Parents} = $self->{ActionStack} = undef;
    $self->{States} = $self->{Document} = $self->{Names} = undef;
    $self->{Nodes} = $self->{Data} = $self->{SourceIsGrove} = undef;

    return $value;
}

sub start_element {
    my ($self, $element) = @_;

    push @{$self->{Names}}, $element->{Name};
    push @{$self->{Nodes}}, $element;

    my $index = $self->{Matcher}->match($element,
					$self->{Names},
					$self->{Nodes});

    my $action;
    if (!defined $index) {
	$action = undef;
    } else {
	$action = $self->{Actions}[$index];
    }

    push @{$self->{ActionStack}}, $action;

    my $state = $self->{States}[-1];
    push @{$self->{States}}, $state;

    if (($state eq 'as-grove') and !$self->{SourceIsGrove}) {
	$self->{GroveBuilder}->start_element($element);
    }

    return if (($state ne 'normal') && ($state ne 'pcdata'));

    if (defined($action) and defined($action->{PCData})) {
	$self->{States}[-1] = 'pcdata';
    }

    if (!defined($action) or $action->{Holder}) {
	# ignore this element but continue processing below
	return;
    }

    if ($action->{Ignore} or $action->{FieldValue}) {
	# ignore (discard) this element and it's children
	$self->{States}[-1] = 'discarding';
	return;
    }

    if ($action->{AsString}) {
	$self->{Data} = [ ];
	$self->{States}[-1] = 'as-string';
	return;
    }

    if ($action->{AsGrove}) {
	$self->{States}[-1] = 'as-grove';
	if (!$self->{SourceIsGrove}) {
	    $self->{GroveBuilder}->start_document( { } );
	    $self->{GroveBuilder}->start_element($element);
	}
	return;
    }

    if (defined $action->{Make}) {
	my @args;
	if (defined $element->{Attributes}) {
	    if (defined $self->{CopyAttributes}) {
		push @args, %{$element->{Attributes}};
	    } elsif ($self->{CopyId} && defined($element->{Attributes}{ID})) {
		# FIXME use code from XML::Grove::IDs
		push (@args, ID => $element->{Attributes}{ID});
	    }
	}

	if (defined $action->{Args}) {
	    eval 'push (@args, (' . $action->{Args} . '))';
	    if ($@) {
		warn "$@\nwhile processing pattern/action #$index\n";
	    }
	}

	if ($action->{Make} eq 'HASH') {
	    push @{$self->{Parents}}, { @args };
	} else {
	    my $is_defined = 0;
	    #eval "\$is_defined = defined %{$action->{Make}" . "::}";
	    if ($is_defined) {
		push @{$self->{Parents}}, $action->{Make}->new( @args );
	    } else {
		push (@{$self->{Parents}},
		      bless ({ @args }, $action->{Make}));
	    }
	}

	if ($action->{ContentsAsGrove}) {
	    $self->{States}[-1] = 'as-grove';
	    if (!$self->{SourceIsGrove}) {
		$self->{GroveBuilder}->start_document( { } );
	    }
	}

	return;
    }

    # Place to store all the rest of gathered contents
    push (@{$self->{Parents}}, { } );
}

sub end_element {
    my ($self, $end_element) = @_;

    my $name = pop @{$self->{Names}};
    my $element = pop @{$self->{Nodes}};

    my $action = pop @{$self->{ActionStack}};
    my $state = pop @{$self->{States}};

    if ($state eq 'as-grove' and !$self->{SourceIsGrove}) {
	$self->{GroveBuilder}->end_element($end_element);
    }

    if (!defined($action) or $action->{Holder}) {
	return;
    }

    if ($action->{Ignore}) {
	return;
    }

    my $value;

    if ($action->{AsString}) {
	$value = join("", @{$self->{Data}});
    } elsif ($action->{AsGrove}) {
	if ($self->{SourceIsGrove}) {
	    $value = $element;
	} else {
	    # get just the root element of the document fragment
	    $value = $self->{GroveBuilder}->end_document({ })->{Contents}[0];
	}
    } elsif (defined $action->{FieldValue}) {
	$value = $action->{FieldValue};
	$value =~ s/%\{($name_re)\}/$element->{Attributes}{$1}/ge;
    } elsif (defined $action->{Make}) {
	$value = pop @{$self->{Parents}};
	if ($action->{ContentsAsGrove}) {
	    if ($self->{SourceIsGrove}) {
		$value->{Contents} = $element->{Contents};
	    } else {
		$value->{Contents} =
		    $self->{GroveBuilder}->end_document({ })->{Contents};
	    }
	}
    } else {
	$value = pop(@{$self->{Parents}})->{Contents};
    }

    if ($action->{FieldIsArray}) {
	push @{$self->{Parents}[-1]{$action->{Field}}}, $value;
    } elsif (defined $action->{Field}) {
	$self->{Parents}[-1]{$action->{Field}} = $value;
    } else {
	push @{$self->{Parents}[-1]{Contents}}, $value;
    }
}

sub characters {
    my ($self, $characters) = @_;

    my $state = $self->{States}[-1];
    if ($state eq 'as-string') {
	push @{$self->{Data}}, $characters->{Data};
    } elsif ($state eq 'as-grove' and !$self->{SourceIsGrove}) {
	$self->{GroveBuilder}->characters($characters);
    } elsif ($state eq 'pcdata') {
	push (@{$self->{Parents}[-1]{Contents}},
	      $self->{CharacterDataType}->new(%$characters));
    }
}

# we ignore processing instructions and ignorable whitespace by not
# defining those functions

###
### private functions
###

sub _parse_action {
    my $self = shift; my $source = shift;

    my $action = {};

    while ($#$source > -1) {
	my $option = shift @$source;
	if ($option eq '-holder') {
	    $action->{Holder} = 1;
	} elsif ($option eq '-make') {
	    $action->{Make} = shift @$source;
	} elsif ($option eq '-args') {
	    my $args = shift @$source;
	    $args =~ s/%\{($name_re)\}/(\$element->{Attributes}{'$1'})/g;
	    $action->{Args} = $args;
	} elsif ($option eq '-field') {
	    $action->{Field} = shift @$source;
	} elsif ($option eq '-push-field') {
	    $action->{Field} = shift @$source;
	    $action->{FieldIsArray} = 1;
	} elsif ($option eq '-as-string') {
	    $action->{AsString} = 1;
	} elsif ($option eq '-value') {
	    $action->{FieldValue} = shift @$source;
	} elsif ($option eq '-grove') {
	    $self->{GroveBuilder} = 1;
	    $action->{AsGrove} = 1;
	} elsif ($option eq '-grove-contents') {
	    $self->{GroveBuilder} = 1;
	    $action->{ContentsAsGrove} = 1;
	} elsif ($option eq '-ignore') {
	    $action->{Ignore} = 1;
	} elsif ($option eq '-pcdata') {
	    $action->{PCData} = 1;
	} else {
	    die "$option: undefined option\n";
	}
    }

    return $action;
}

1;

__END__

=head1 NAME

XML::PatAct::ToObjects - An action module for creating Perl objects

=head1 SYNOPSIS

 use XML::PatAct::ToObjects;

 my $patterns = [ PATTERN => [ OPTIONS ],
		  PATTERN => "PERL-CODE",
		  ... ];

 my $matcher = XML::PatAct::ToObjects->new( Patterns => $patterns,
					    Matcher => $matcher,
					    CopyId => 1,
					    CopyAttributes => 1 );


=head1 DESCRIPTION

XML::PatAct::ToObjects is a PerlSAX handler for applying
pattern-action lists to XML parses or trees.  XML::PatAct::ToObjects
creates Perl objects of the types and contents of the action items you
define.

New XML::PatAct::ToObject instances are creating by calling `new()'.
Parameters can be passed as a list of key, value pairs or a hash.
`new()' requires the Patterns and Matcher parameters, the rest are
optional:

=over 4

=item Patterns

The pattern-action list to apply.

=item Matcher

An instance of the pattern or query matching module.

=item CopyId

Causes the `ID' attribute, if any, in a source XML element to be
copied to an `ID' attribute in newly created objects.  Note that IDs
may be lost of no pattern matches that element or an object is not
created (C<-make>) for that element.

=item CopyAttributes

Causes all attributes of the element to be copied to the newly created
objects.

=back

Each action can either be a list of options defined below or a string
containing a fragment of Perl code.  If the action is a string of Perl
code then simple then some simple substitutions are made as described
further below.

Options that can be used in an action item containing an option-list:

=over 4

=item B<-holder>

Ignore this element, but continue processing it's children (compare to
B<-ignore>).  C<-pcdata> may be used with this option.

=item B<-ignore>

Ignore (discard) this element and it's children (compare to B<-holder>).

=item B<-pcdata>

Character data in this element should be copied to the C<Contents>
field.

=item B<-make> I<PACKAGE>

Create an object blessed into I<PACKAGE>, and continue processing this
element and it's children.  I<PACKAGE> may be the type `C<HASH>' to
simply create an anonyous hash.

=item B<-args> I<ARGUMENTS>

Use I<ARGUMENTS> in creating the object specified by B<-make>.  This
is commonly used to copy element attributes into fields in the newly
created object.  For example:

  -make => 'HASH', -args => 'URL => %{href}'

would copy the `C<href>' attribute in an element to the `C<URL>' field
of the newly created hash.

=item B<-field> I<FIELD>

Store this element, object, or children of this element in the parent
object's field named by I<FIELD>.

=item B<-push-field> I<FIELD>

Similar to B<-field>, except that I<FIELD> is an array and the
contents are pushed onto that array.

=item B<-value> I<VALUE>

Use I<VALUE> as a literal value to store in I<FIELD>, otherwise
ignoring this element and it's children.  Only valid with B<-field> or
B<-push-field>.  `C<%{I<ATTRIBUTE>}>' notation can be used to
substitute the value of an attribute into the literal value.

=item B<-as-string>

Convert the contents of this element to a string (as in
C<XML::Grove::AsString>) and store in I<FIELD>.  Only valid with
B<-field> or B<-push-field>.

=item B<-grove>

Copy this element to I<FIELD> without further processing.  The element
can then be processed later as the Perl objects are manipulated.  Only
valid with B<-field> or B<-push-field>.  If ToObjects is used with
PerlSAX, this will use XML::Grove::Builder to build the grove element.

=item B<-grove-contents>

Used with B<-make>, B<-grove-contents> creates an object but then
takes all of the content of that element and stores it in Contents.

=back

If an action item is a string, that string is treated as a fragment of
Perl code.  The following simple substitutions are performed on the
fragment to provide easy access to the information being converted:

=over 4

=item B<@ELEM@>

The object that caused this action to be called.  If ToObjects is used
with PerlSAX this will be a hash with the element name and attributes,
with XML::Grove this will be the element object, with Data::Grove it
will be the matching object, and with XML::DOM it will be an
XML::DOM::Element.

=back

=head1 EXAMPLE

The example pattern-action list below will convert the following XML
representing a Database schema:

    <schema>
      <table>
        <name>MyTable</name>
        <summary>A short summary</summary>
        <description>A long description that may
          contain a subset of HTML</description>
        <column>
          <name>MyColumn1</name>
          <summary>A short summary</summary>
          <description>A long description</description>
          <unique/>
          <non-null/>
          <default>42</default>
        </column>
      </table>
    </schema>

into Perl objects looking like:

    [
      { Name => "MyTable",
        Summary => "A short summary",
        Description => $grove_object,
        Columns => [
          { Name => "MyColumn1",
            Summary => "A short summary",
            Description => $grove_object,
            Unique => 1,
            NonNull => 1,
            Default => 42
          }
        ]
      }
    ]

Here is a Perl script and pattern-action list that will perform the
conversion using the simple name matching pattern module
XML::PatAct::MatchName.  The script accepts a Schema XML file as an
argument (C<$ARGV[0]>) to the script.  This script creates a grove as
one of it's objects, so it requires the XML::Grove module.

    use XML::Parser::PerlSAX;
    use XML::PatAct::MatchName;
    use XML::PatAct::ToObjects;

    my $patterns = [
      'schema'      => [ qw{ -holder                                  } ],
      'table'       => [ qw{ -make Schema::Table                      } ],
      'name'        => [ qw{ -field Name -as-string                   } ],
      'summary'     => [ qw{ -field Summary -as-string                } ],
      'description' => [ qw{ -field Description -grove                } ],
      'column'      => [ qw{ -make Schema::Column -push-field Columns } ],
      'unique'      => [ qw{ -field Unique -value 1                   } ],
      'non-null'    => [ qw{ -field NonNull -value 1                  } ],
      'default'     => [ qw{ -field Default -as-string                } ],
    ];

    my $matcher = XML::PatAct::MatchName->new( Patterns => $patterns );
    my $handler = XML::PatAct::ToObjects->new( Patterns => $patterns,
                                               Matcher => $matcher);

    my $parser = XML::Parser::PerlSAX->new( Handler => $handler );
    my $schema = $parser->parse(Source => { SystemId => $ARGV[0] } );

=head1 TODO

=over 4

=item *

It'd be nice if patterns could be applied even in B<-as-string> and
B<-grove>.

=item *

Implement Perl code actions.

=item *

B<-as-xml> to write XML into the field.

=back



=head1 AUTHOR

Ken MacLeod, ken@bitsko.slc.ut.us

=head1 SEE ALSO

perl(1), Data::Grove(3)

``Using PatAct Modules'' and ``Creating PatAct Modules'' in libxml-perl.

=cut
