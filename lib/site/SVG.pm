=pod 

=head1 NAME

SVG - Perl extension for generating Scalable Vector Graphics (SVG) documents

=cut

package SVG;

use strict;
use vars qw($VERSION @ISA $AUTOLOAD);
use Exporter;
use SVG::XML;
use SVG::Element;
use SVG::Extension;

@ISA = qw(SVG::Element SVG::Extension);

$VERSION = "2.28";

#-------------------------------------------------------------------------------

=pod 

=head2 VERSION

Version 2.26, 12.01.03

Refer to L<SVG::Manual> for the complete manual

=head1 DESCRIPTION

SVG is a 100% Perl module which generates a nested data structure containing the
DOM representation of an SVG (Scalable Vector Graphics) image. Using SVG, you
can generate SVG objects, embed other SVG instances into it, access the DOM
object, create and access javascript, and generate SMIL animation content.

Refer to L<SVG::Manual> for the complete manual.

=head1 AUTHOR

Ronan Oger, RO IT Systemms GmbH, ronan@roasp.com

=head1 CREDITS

Peter Wainwright, peter@roasp.com Excellent ideas, beta-testing, SVG::Parser


=head1 EXAMPLES

http://www.roasp.com/index.shtml?svg.pod

=head1 SEE ALSO

perl(1),L<SVG>,L<SVG::DOM>,L<SVG::XML>,L<SVG::Element>,L<SVG::Parser>, L<SVG::Manual>
http://www.roasp.com/
http://www.perlsvg.com/
http://www.roitsystems.com/
http://www.w3c.org/Graphics/SVG/

=cut


#-------------------------------------------------------------------------------

my %default_attrs = (
    # processing options
    -auto       => 0,       # permit arbitrary autoloads (only at import)
    -printerror => 1,       # print error messages to STDERR
    -raiseerror => 1,       # die on errors (implies -printerror)

    # rendering options
    -indent     => "\t",    # what to indent with
    -elsep      => "\n",    # element line (vertical) separator
    -nocredits  => 0,       # enable/disable credit note comment
    -namespace  => '',      # The root element's (and it's children's) namespace

    # XML and Doctype declarations
    -inline     => 0,       # inline or stand alone
    -docroot    => 'svg',   # The document's root element
    -version    => '1.0',
    -extension  => '',
    -encoding   => 'UTF-8',
    -standalone => 'yes',
    -pubid      => "-//W3C//DTD SVG 1.0//EN", # formerly -identifier
    -sysid      => 'http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd',
);

sub import {
    my $package=shift;

    my $attr=undef;
    foreach (@_) {
        if ($attr) {
            $default_attrs{$attr}=$_;
            undef $attr;
        } elsif (exists $default_attrs{$_}) {
            $attr=$_;
        } else {
            /^-/ and die "Unknown attribute '$_' in import list\n";
            $SVG::Element::autosubs{$_}=1; # add to list of autoloadable tags
        }
    }

    # switch on AUTOLOADer, if asked.
    if ($default_attrs{'-auto'}) {
        *SVG::Element::AUTOLOAD=\&SVG::Element::autoload;
    }

    # predeclare any additional elements asked for by the user
    foreach my $sub (keys %SVG::Element::autosubs) {
        $SVG::Element::AUTOLOAD=("SVG::Element::$sub");
        SVG::Element::autoload();
    }

    delete $default_attrs{-auto}; # -auto is only allowed here, not in new

    return ();
}

#-------------------------------------------------------------------------------

=pod

=head1 Methods

SVG provides both explicit and generic element constructor methods. Explicit
generators are generally (with a few exceptions) named for the element they
generate. If a tag method is required for a tag containing hyphens, the method 
name replaces the hyphen with an underscore. ie: to generate tag <column-heading id="new">
you would use method $svg->column_heading(id=>'new').


All element constructors take a hash of element attributes and options;
element attributes such as 'id' or 'border' are passed by name, while options for the
method (such as the type of an element that supports multiple alternate forms)
are passed preceded by a hyphen, e.g '-type'. Both types may be freely
intermixed; see the L<"fe"> method and code examples througout the documentation
for more examples.

=head2 new (constructor)

$svg = SVG->new(%attributes)

Creates a new SVG object. Attributes of the document SVG element be passed as
an optional list of key value pairs. Additionally, SVG options (prefixed with
a hyphen) may be set on a per object basis:

B<Example:>

    my $svg1=new SVG;

    my $svg2=new SVG(id => 'document_element');

    my $svg3=new SVG(
        -printerror => 1,
        -raiseerror => 0,
        -indent     => '  ',
    -elsep      =>"\n",  # element line (vertical) separator
        -docroot => 'svg', #default document root element (SVG specification assumes svg). Defaults to 'svg' if undefined
        -sysid      => 'abc', #optional system identifyer 
        -pubid      => "-//W3C//DTD SVG 1.0//EN", #public identifyer default value is "-//W3C//DTD SVG 1.0//EN" if undefined
        -namespace => 'mysvg',
        -inline   => 1
        id          => 'document_element',
        width       => 300,
        height      => 200,
    );

Default SVG options may also be set in the import list. See L<"EXPORTS"> above
for more on the available options. 

Furthermore, the following options:

    -version
    -encoding
    -standalone
    -namespace
    -inline
    -pubid (formerly -identifier)
    -sysid (standalone)

may also be set in xmlify, overriding any corresponding values set in the SVG->new declaration

=cut

#-------------------------------------------------------------------------------
#
# constructor for the SVG data model.
#
# the new constructor creates a new data object with a document tag at its base.
# this document tag then has either:
#     a child entry parent with its child svg generated (when -inline = 1)
# or
#     a child entry svg created.
#
# Because the new method returns the $self reference and not the 
# latest child to be created, a hash key -document with the reference to the hash
# entry of its already-created child. hence the document object has a -document reference
# to parent or svg if inline is 1 or 0, and parent will have a -document entry
# pointing to the svg child.
#
# This way, the next tag constructor will descend the
# tree until it finds no more tags with -document, and will add
# the next tag object there.
# refer to the SVG::tag method 

sub new ($;@) {
    my ($proto,%attrs)=@_;
    my $class=ref $proto || $proto;
    my $self;

    # establish defaults for unspecified attributes
    foreach my $attr (keys %default_attrs) {
        $attrs{$attr}=$default_attrs{$attr} unless exists $attrs{$attr}
    }
    $self = $class->SUPER::new('document');
    $self->{-docref} = $self unless ($self->{-docref});
    $self->{-level} = 0;
    $self->{$_} = $attrs{$_} foreach keys %default_attrs;

    # create SVG object according to nostub attribute
    my $svg;
    unless ($attrs{-nostub}) {
        $svg = $self->svg(%attrs);
        $self->{-document} = $svg;
    }

    # add -attributes to SVG object
    #    $self->{-elrefs}->{$self}->{name} = 'document';
    #    $self->{-elrefs}->{$self}->{id} = '';

    return $self;
}

#-------------------------------------------------------------------------------

=pod

=head2 xmlify (alias: to_xml render)

$string = $svg->xmlify(%attributes);

Returns xml representation of svg document.

B<XML Declaration>

    Name               Default Value
    -version           '1.0'               
    -encoding          'UTF-8'
    -standalone        'yes'
    -namespace         'svg' - namespace for elements. 
                               Can also be used in any element method to over-ride
                               the current namespace
    -inline            '0' - If '1', then this is an inline document.
    -pubid             '-//W3C//DTD SVG 1.0//EN';
    -sysid             'http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd'

=cut

sub xmlify ($;@) {

    my ($self,%attrs) = @_;
    my ($decl,$ns);

    my $credits = '';

    # Give the module and myself credit unless explicitly turned off
    unless ($self->{-docref}->{-nocredits}) {
        $self->comment("\n\tGenerated using the Perl SVG Module V$VERSION\n\tby Ronan Oger\n\tInfo: http://www.roasp.com/\n" );
    }

    foreach my $key (keys %attrs) {
        next unless ($key =~ /^\-/);
        $self->{$key} = $attrs{$key};
    }

    foreach my $key (keys %$self) {
        next unless ($key =~ /^\-/);
        $attrs{$key} ||= $self->{$key};
    }

    return $self->SUPER::xmlify($self->{-namespace});
}
*render=\&xmlify;
*to_xml=\&xmlify;

sub perlify ($;@) {
    return shift->SUPER::perlify();
}
*toperl=\&perlify;

#-------------------------------------------------------------------------------

1;
