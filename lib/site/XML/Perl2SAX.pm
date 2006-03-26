#
# Copyright (C) 1998 Ken MacLeod
# XML::Perl2SAX is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: Perl2SAX.pm,v 1.3 1999/12/22 21:15:00 kmacleod Exp $
#

use strict;

package XML::Perl2SAX;

use vars qw{ $VERSION };

# will be substituted by make-rel script
$VERSION = "0.08";

sub new {
    my $type = shift;
    my $self = ($#_ == 0) ? shift : { @_ };

    return bless $self, $type;
}

sub start_document {
    my $self = shift;
    my $properties = ($#_ == 0) ? shift : { @_ };

    if ($properties->{Locator}) {
	$self->{DocumentHandler}->setDocumentLocator($properties->{Locator});
    }

    $self->{DocumentHandler}->startDocument;
}

sub end_document {
    my $self = shift;

    $self->{DocumentHandler}->endDocument;
}

sub start_element {
    my $self = shift;
    my $properties = shift;

    # FIXME depends on how Perl SAX treats attributes
    $self->{DocumentHandler}->startElement($properties->{Name},
					   $properties->{Attributes});
}

sub end_element {
    my $self = shift;
    my $properties = shift;

    $self->{DocumentHandler}->endElement($properties->{Name});
}

sub characters {
    my $self = shift;
    my $properties = shift;

    $self->{DocumentHandler}->characters($properties->{Data},
					 0,
					 length($properties->{Data}));
}

sub ignorable_whitespace {
    my $self = shift;
    my $properties = shift;

    $self->{DocumentHandler}->ignorableWhitespace($properties->{Data},
						  0,
						  length($properties->{Data}));
}

sub processing_instruction {
    my $self = shift;
    my $properties = shift;

    $self->{DocumentHandler}->processingInstruction($properties->{Target},
						    $properties->{Data});
}

1;

__END__

=head1 NAME

XML::SAX2Perl -- translate Perl SAX methods to Java/CORBA style methods

=head1 SYNOPSIS

 use XML::Perl2SAX;

 $perl2sax = XML::Perl2SAX(handler => $java_style_handler);

=head1 DESCRIPTION

C<XML::Perl2SAX> is a SAX filter that translates Perl style SAX
methods to Java/CORBA style method calls.  This module performs the
inverse operation from C<XML::SAX2Perl>.

C<Perl2SAX> is a Perl SAX document handler.  The `C<new>' method takes
a `C<handler>' argument that is a Java/CORBA style handler that the
new Perl2SAX instance will call.  The SAX interfaces are defined at
<http://www.megginson.com/SAX/>.

=head1 AUTHOR

Ken MacLeod <ken@bitsko.slc.ut.us>

=head1 SEE ALSO

perl(1), XML::Perl2SAX(3).

 Extensible Markup Language (XML) <http://www.w3c.org/XML/>
 Simple API for XML (SAX) <http://www.megginson.com/SAX/>

=cut
