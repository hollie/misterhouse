# This template file is in the Public Domain.
# You may do anything you want with this file.
#
# $Id: Sample.pm,v 1.4 1999/08/16 16:04:03 kmacleod Exp $
#

package XML::Handler::Sample;

use vars qw{ $AUTOLOAD };

sub new {
    my $type = shift;
    my $self = ( $#_ == 0 ) ? shift : { @_ };

    return bless $self, $type;
}

# Basic PerlSAX
sub start_document            { print "start_document\n"; }
sub end_document              { print "end_document\n"; }
sub start_element             { print "start_element\n"; }
sub end_element               { print "end_element\n"; }
sub characters                { print "characters\n"; }
sub processing_instruction    { print "processing_instruction\n"; }
sub ignorable_whitespace      { print "ignorable_whitespace\n"; }

# Additional expat callbacks in XML::Parser::PerlSAX
sub comment                   { print "comment\n"; }
sub notation_decl             { print "notation_decl\n"; }
sub unparsed_entity_decl      { print "unparsed_entity_decl\n"; }
sub entity_decl               { print "entity_decl\n"; }
sub element_decl              { print "element_decl\n"; }
sub doctype_decl              { print "doctype_decl\n"; }
sub xml_decl                  { print "xml_decl\n"; }

# Additional SP/nsgmls callbacks in XML::ESISParser
sub start_subdoc              { print "start_subdoc\n"; }
sub end_subdoc                { print "start_subdoc\n"; }
sub appinfo                   { print "appinfo\n"; }
sub internal_entity_ref       { print "sdata\n"; }
sub external_entity_ref       { print "sdata\n"; }
sub record_end                { print "record_end\n"; }
sub internal_entity_decl      { print "internal_entity_decl\n"; }
sub external_entity_decl      { print "external_entity_decl\n"; }
sub external_sgml_entity_decl { print "external_sgml_entity_decl\n"; }
sub subdoc_entity_decl        { print "subdoc_entity_decl\n"; }
sub notation                  { print "notation\n"; }
sub error                     { print "error\n"; }
sub conforming                { print "conforming\n"; }

# Others
sub AUTOLOAD {
    my $self = shift;

    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';

    print "UNRECOGNIZED $method\n";
}

1;

__END__

=head1 NAME

XML::Handler::Sample - a trivial PerlSAX handler

=head1 SYNOPSIS

 use XML::Parser::PerlSAX;
 use XML::Handler::Sample;

 $my_handler = XML::Handler::Sample->new;

 XML::Parser::PerlSAX->new->parse(Source => { SystemId => 'REC-xml-19980210.xml' },
                                  Handler => $my_handler);

=head1 DESCRIPTION

C<XML::Handler::Sample> is a trivial PerlSAX handler that prints out
the name of each event it receives.  The source for
C<XML::Handler::Sample> lists all the currently known PerlSAX
handler methods.

C<XML::Handler::Sample> is intended for Perl module authors who wish
to look at example PerlSAX handler modules.  C<XML::Handler::Sample>
can be used as a template for writing your own PerlSAX handler
modules.  C<XML::Handler::Sample> is in the Public Domain and can be
used for any purpose without restriction.

=head1 AUTHOR

Ken MacLeod, ken@bitsko.slc.ut.us

=head1 SEE ALSO

perl(1), PerlSAX.pod(3)

=cut
