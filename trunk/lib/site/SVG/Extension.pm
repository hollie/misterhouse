package SVG::Extension;
use strict;

use vars qw(@ISA $VERSION @TYPES %TYPES);
$VERSION = "0.1";

# although DTD declarations are not elements, we use the same API so we can
# manipulate the internal DTD subset using the same methods available for
# elements. At this state, all extensions are the same object class, but
# may be subclassed in the future to e.g. SVG::Extension::ELEMENT. Use
# e.g. isElementDecl() to determine types; this API will be retained
# irrespective.

@ISA=qw(SVG::Element);

# DTD declarations handled in this module
use constant ELEMENT => "ELEMENT";
use constant ATTLIST => "ATTLIST";
use constant NOTATION => "NOTATION";
use constant ENTITY => "ENTITY";

@TYPES=(ELEMENT,ATTLIST,NOTATION,ENTITY);
%TYPES=map { $_ => 1 } @TYPES;

#-----------------

sub new {
    return shift->SUPER::new(@_);
}

sub internal_subset {
    my $self=shift;

    my $document=$self->{-docref};
    unless (exists $document->{-internal}) {
        $document->{-internal}=new SVG::Extension("internal");
        $document->{-internal}{-docref}=$document;
    }

    return $document->{-internal};
}

sub extension {
    my $self=shift;
    my $class=ref($self) || $self;

    return bless $self->SUPER::element(@_),$class;
}

#-----------------

sub element_decl {
    my ($self,%attrs)=@_;
    my $subset=$self->internal_subset();

    return $subset->extension('ELEMENT',%attrs);
}

sub attribute_decl {
    my ($element_decl,%attrs)=@_;

    unless ($element_decl->getElementType eq 'ELEMENT') {
        $element_decl->error($element_decl => 'is not an ELEMENT declaration');
        return undef;
    }

    return $element_decl->extension('ATTLIST',%attrs);
}

sub attlist_decl {
    my ($self,%attrs)=@_;
    my $subset=$self->internal_subset();

    my $element_decl=$subset->getElementDeclByName($attrs{name});
    unless ($element_decl) {
        $subset->error("ATTLIST declaration '$attrs{attr}'" => "ELEMENT declaration '$attrs{name}' does not exist");
        return undef;
    }

    return $element_decl->attribute_decl(%attrs);
}

sub notation_decl {
    my ($self,%attrs)=@_;
    my $subset=$self->internal_subset();

    return $subset->extension('NOTATION',%attrs);
}

sub entity_decl {
    my ($self,%attrs)=@_;
    my $subset=$self->internal_subset();

    return $subset->extension('ENTITY',%attrs);
}

#-----------------

# this interim version of xmlify handles the vanilla extension
# format of one parent 'internal' element containing a list of
# extension elements. A hierarchical model will follow in time
# with the same render API.
sub xmlify {
    my $self=shift;
    my $decl="";

    if ($self->{-name} ne 'internal') {
        $decl="<!";
        SWITCH: foreach ($self->{-name}) {
            /^ELEMENT$/ and do {
                $decl.="ELEMENT $self->{name}";

                $decl.=" ".$self->{model} if exists $self->{model};

                last SWITCH;
            };
            /^ATTLIST$/ and do {
                $decl.="ATTLIST $self->{name} $self->{attr}";

                $decl.=" $self->{type} ".
                  ($self->{fixed}?"#FIXED ":"").
                  $self->{default};

                last SWITCH;
            };
            /^NOTATION$/ and do {
                $decl.="NOTATION $self->{name}";

                $decl.=" ".$self->{base} if exists $self->{base};
                if (exists $self->{pubid}) {
                    $decl.="PUBLIC $self->{pubid} ";
                    $decl.=" ".$self->{sysid} if exists $self->{sysid};
                } elsif (exists $self->{sysid}) {
                    $decl.=" SYSTEM ".$self->{sysid} if exists $self->{sysid};
                }

                last SWITCH;
            };
            /^ENTITY$/ and do {
                $decl.="ENTITY ".($self->{isp}?"% ":"").$self->{name};

                if (exists $self->{value}) {
                    $decl.=' "'.$self->{value}.'"';
                } elsif (exists $self->{pubid}) {
                    $decl.="PUBLIC $self->{pubid} ";
                    $decl.=" ".$self->{sysid} if exists $self->{sysid};
                    $decl.=" ".$self->{ndata} if $self->{ndata};
                } else {
                    $decl.=" SYSTEM ".$self->{sysid} if exists $self->{sysid};
                    $decl.=" ".$self->{ndata} if $self->{ndata};
                }

                last SWITCH;
              DEFAULT:
                # we don't know what this is, but the underlying parser allowed it
                $decl.="$self->{-name} $self->{name}";
            };
        }
        $decl.=">".$self->{-docref}{-elsep};
    }

    my $result="";
    if ($self->hasChildren) {
        $self->{-docref}->{-level}++;
        foreach my $child ($self->getChildren) {
            $result .= ($self->{-docref}{-indent} x $self->{-docref}->{-level}).
                       $child->render();
        }
        $self->{-docref}->{-level}--;
    }

    return $decl.$result;
}
*render=\&xmlify;
*to_xml=\&xmlify;

#-----------------

# simply an alias for the general method for SVG::Extension objects
sub getDeclName {
    return shift->SUPER::getElementName();
}
*getExtensionName=\&getDeclName;

# return list of existing decl types by extracting it from the overall list
# of existing element types
sub getDeclNames {
    my $self=shift;

    return grep {
        exists $TYPES{$_}
    } $self->SUPER::getElementNames();
}
*getExtensionNames=\&getDeclNames;

#-----------------

# we can have only one element decl of a given name...
sub getElementDeclByName {
    my ($self,$name)=@_;
    my $subset=$self->internal_subset();

    my @element_decls=$subset->getElementsByName('ELEMENT');
    foreach my $element_decl (@element_decls) {
        return $element_decl if $element_decl->{name} eq $name;
    }

    return undef;
}

# ...but we can have multiple attributes. Note that this searches the master list
# which is not what you are likely to want in most cases. See getAttributeDeclByName
# (no 's') below, to search for an attribute decl on a particular element decl.
# You can use the result of this method along with getParent to find the list of
# all element decls that define a given attribute.
sub getAttributeDeclsByName {
    my ($self,$name)=@_;
    my $subset=$self->internal_subset();

    my @element_decls=$subset->getElementsByName('ELEMENT');
    foreach my $element_decl (@element_decls) {
        return $element_decl if $element_decl->{name} eq $name;
    }

    return undef;
}

#-----------------

sub getElementDecls {
    return shift->SUPER::getElements('ELEMENT');
}

sub getNotations {
    return shift->SUPER::getElements('NOTATION');
}
*getNotationDecls=\&getNotations;

sub getEntities {
    return shift->SUPER::getElements('ENTITY');
}
*getEntityDecls=\&getEntities;

sub getAttributeDecls {
    return shift->SUPER::getElements('ATTLIST');
}

#-----------------
# until/unless we subclass these, use the name. After (if) we
# subclass, will use the object class.

sub isElementDecl {
    return (shift->getElementName eq ELEMENT)?1:0;
}

sub isNotation {
    return (shift->getElementName eq NOTATION)?1:0;
}

sub isEntity {
    return (shift->getElementName eq ENTITY)?1:0;
}

sub isAttributeDecl {
    return (shift->getElementName eq ATTLIST)?1:0;
}

#-----------------

# the Decl 'name' is an attribute, the name is e.g. 'ELEMENT'
# use getElementName if you want the actual decl type
sub getElementDeclName ($) {
    my $self=shift;

    if (exists $self->{name}) {
        return $self->{name};
    }

    return undef;
}

# identical to the above; will be smarter as and when we subclass
# as above, the name is ATTLIST, the 'name' is a property of the decl
sub getAttributeDeclName ($) {
    my $self=shift;

    if (exists $self->{name}) {
        return $self->{name};
    }

    return undef;
}

# unlike other 'By' methods, attribute searches work from their parent element
# del only. Multiple element decls with the same attribute name is more than
# likely, so searching the master ATTLIST is not very useful. If you really want
# to do that, use getAttributeDeclsByName (with an 's') above.
sub getAttributeDeclByName {
    my ($self,$name)=@_;

    my @attribute_decls=$self->getElementAttributeDecls();
    foreach my $attribute_decl (@attribute_decls) {
        return $attribute_decl if $attribute_decl->{name} eq $name;
    }

    return undef;
}
# as this is element specific, we allow a 'ElementAttribute' name too,
# for those that like consistency at the price of brevity. Not that
# the shorter name is all that brief to start with...
*getElementAttributeDeclByName=\&getAttributeDeclByName;
# ...and for those who live their brevity:
*getAttributeDecl=\&getAttributeDeclByName;

sub hasAttributeDecl {
    return (shift->getElementDeclByName(shift))?1:0;
}

#-----------------
# directly map to Child/Siblings: we presume this is being called from an
# element decl. You can use 'getChildIndex', 'getChildAtIndex' etc. as well

sub getElementAttributeAtIndex ($$;@) {
    my ($self,$index,@children)=@_;

    return $self->SUPER::getChildAtIndex($index,@children);
}

sub getElementAttributeIndex ($;@) {
    return shift->SUPER::getChildIndex(@_);
}

sub getFirstAttributeDecl ($) {
    return shift->SUPER::getFirstChild();
}

sub getNextAttributeDecl ($) {
    return shift->SUPER::getNextSibling();
}

sub getLastAttributeDecl ($) {
    return shift->SUPER::getLastChild();
}

sub getPreviousAttributeDecl ($) {
    return shift->SUPER::getPreviousSibling();
}

sub getElementAttributeDecls ($) {
    return shift->SUPER::getChildren();
}

#-------------------------------------------------------------------------------

# These methods are slated for inclusion in a future release of SVG.pm. They
# will allow programmatic advance determination of the validity of various DOM
# manipulations. If you are in a hurry for this feature, get in touch!
#
# example:
#    if ($svg_object->allowsElement("symbol")) { ... }
#
#package SVG::Element;
#
#sub allowedElements {}
#sub allowedAttributes {}
#
#sub allowsElement {}
#sub allowsAttribute {}
#

#-------------------------------------------------------------------------------

1;
