package SVG::DOM;
use strict;

use vars qw($VERSION);
$VERSION = "1.01";
#29.01.03 RO added setAttributes and setAttribute

# this module extends SVG::Element
package SVG::Element;

#-----------------
# sub getFirstChild

sub getFirstChild ($) {
    my $self=shift;

    if (my @children=$self->getChildren) {
        return $children[0];
    }
    return undef;
}

#-----------------
# sub getChildIndex
# return the array index of this element in the parent
# or the passed list (if there is one).

sub getChildIndex ($;@) {
    my ($self,@children)=@_;

    unless (@children) {
        my $parent=$self->getParent();
        @children=$parent->getChildren();
        return undef unless @children;
    }

    for my $index (0..$#children) {
        return $index if $children[$index]==$self;
    }

    return undef;
}

#-----------------
# sub getChildAtIndex
# return the element at the specified index
# (the index can be negative)

sub getChildAtIndex ($$;@) {
    my ($self,$index,@children)=@_;

    unless (@children) {
        my $parent=$self->getParent();
        @children=$parent->getChildren();
        return undef unless @children;
    }

    return $children[$index];
}

#-----------------
# sub getNextSibling

sub getNextSibling ($) {
    my $self=shift;

    if (my $parent=$self->getParent) {
        my @children=$parent->getChildren();
        my $index=$self->getChildIndex(@children);
        if (defined $index and scalar(@children)>$index) {
            return $children[$index+1];
        }
    }

    return undef;
}


#-----------------
# sub getPreviousSibling

sub getPreviousSibling ($) {
    my $self=shift;

    if (my $parent=$self->getParent) {
        my @children=$parent->getChildren();
        my $index=$self->getChildIndex(@children);
        if ($index) {
            return $children[$index-1];
        }
    }

    return undef;
}

#-----------------
# sub getLastChild

sub getLastChild ($) {
    my $self=shift;

    if (my @children=$self->getChildren) {
        return $children[-1];
    }

    return undef;
}

#-----------------
# sub getChildren

sub getChildren ($) {
    my $self=shift;

    if ($self->{-childs}) {
        if (wantarray) {
            return @{$self->{-childs}};
        }
        return $self->{-childs};
    }

    return wantarray?():undef;
}
*getChildElements=\&getChildren;
*getChildNodes=\&getChildren;

#-----------------

sub hasChildren ($) {
    my $self=shift;

    if (exists $self->{-childs}) {
        if (scalar @{$self->{-childs}}) {
            return 1;
        }
    }

    return 0;
}
*hasChildElements=\&hasChildren;
*hasChildNodes=\&hasChildren;

#-----------------
# sub getParent / getParentElement
# return the ref of the parent of the current node

sub getParent ($) {
    my $self=shift;

    if ($self->{-parent}) {
        return $self->{-parent};
    }

    return undef;
}
*getParentElement=\&getParent;
*getParentNode=\&getParent;

#-----------------
# sub getParents / getParentElements

sub getParents {
    my $self=shift;

    my $parent=$self->{-parent};
    return undef unless $parent;

    my @parents;
    while ($parent) {
        push @parents,$parent;
        $parent=$parent->{-parent};
    }

    return @parents;
}
*getParentElements=\&getParents;
*getParentNodes=\&getParents;
*getAncestors=\&getParents;

#-----------------
# sub isAncestor 

sub isAncestor ($$) {
    my ($self,$descendant)=@_;

    my @parents=$descendant->getParents();
    foreach my $parent (@parents) {
        return 1 if $parent==$self;
    }

    return 0;
}

#-----------------
# sub isDescendant

sub isDescendant ($$) {
    my ($self,$ancestor)=@_;

    my @parents=$self->getParents();
    foreach my $parent (@parents) {
        return 1 if $parent==$ancestor;
    }

    return 0;
}

#-----------------
# sub getSiblings

sub getSiblings ($) {
    my $self=shift;

    if (my $parent=$self->getParent) {
        return $parent->getChildren();
    }

    return wantarray?():undef;
}

#-----------------
# sub hasSiblings

sub hasSiblings ($) {
    my $self=shift;

    if (my $parent=$self->getParent) {
        my $siblings=scalar($parent->getChildren);
        return 1 if $siblings>=2;
    }

    return undef;
}

#-----------------
# sub getElementName / getType

sub getElementName ($) {
    my $self=shift;

    if (exists $self->{-name}) {
        return $self->{-name};
    }

    return undef;
}
*getType=\&getElementName;
*getElementType=\&getElementName;
*getTagName=\&getElementName;
*getTagType=\&getElementName;
*getNodeName=\&getElementName;
*getNodeType=\&getElementName;

#-----------------
# sub getElements
# get all elements of the specified type
# if none is specified, get all elements in document.

sub getElements ($;$) {
    my ($self,$element)=@_;

    return undef unless exists $self->{-docref};
    return undef unless exists $self->{-docref}->{-elist};

    my $elist=$self->{-docref}->{-elist};
    if (defined $element) {
        if (exists $elist->{$element}) {
            return wantarray?@{$elist->{$element}}:
		$elist->{$element};
        }
        return wantarray?():undef;
    } else {
       my @elements;
       foreach my $element_type (keys %$elist) {
            push @elements,@{$elist->{$element_type}};
       }
       return wantarray?@elements:\@elements;
    }
}

# forces the use of the second argument for element name
sub getElementsByName ($$) {
    return shift->getElements(shift);
}
*getElementsByType=\&getElementsByName;

#-----------------
sub getElementNames ($) {
    my $self=shift;

    my @types=keys %{$self->{-docref}->{-elist}};

    return wantarray?@types:\@types;
}
*getElementTypes=\&getElementNames;

#-----------------
# sub getElementID

sub getElementID ($) {
    my $self=shift;

    if (exists $self->{id}) {
        return $self->{id};
    }

    return undef;
}

#-----------------
# sub getElementByID / getElementbyID

sub getElementByID ($$) {
    my ($self,$id)=@_;

    return undef unless defined($id);
    my $idlist=$self->{-docref}->{-idlist};
    if (exists $idlist->{$id}) {
        return $idlist->{$id};
    }

    return undef;
}
*getElementbyID=\&getElementByID;

#-----------------
# sub getAttribute
# see also SVG::attrib()

sub getAttribute ($$) {
    my ($self,$attr)=@_;

    if (exists $self->{$attr}) {
        return $self->{$attr};
    }

    return undef;
}

#-----------------
# sub getAttributes

sub getAttributes ($) {
    my $self=shift;

    my $out = {};
    foreach my $i (keys %$self) {
        $out->{$i} = $self->{$i} unless $i =~ /^-/;
    }

    return wantarray?%{$out}:$out;
}


#-----------------
# sub setAttribute

sub setAttributes ($$) {
    my ($self,$attr) = @_;
    foreach my $i (keys %$attr) {
        $self->attrib($i,$attr->{$i});
    }
}

#-----------------
# sub setAttribute

sub setAttribute ($$;$) {
    my ($self,$att,$val) = @_;
    $self->attrib($att,$val);
}
#-----------------
# sub getCDATA / getCdata / getData

sub getCDATA ($) {
    my $self=shift;

    if (exists $self->{-cdata}) {
        return $self->{-cdata};
    }

    return undef;
}
*getCdata=\&getCDATA;
*getData=\&getCDATA;

#-------------------------------------------------------------------------------

=pod 

=head1 NAME

SVG::DOM - A library of DOM (Document Object Model) methods for SVG objects.

=head1 SUMMARY

SVG::DOM provides a selection of methods for accessing and manipulating SVG
elements through DOM-like methods such as getElements, getChildren, getNextSibling
and so on. 

Currently only methods that provide read operations are supported. Methods to
manipulate SVG elements will be added in a future release.

=head1 SYNOPSIS

    my $svg=new SVG(id=>"svg_dom_synopsis", width=>"100", height=>"100");
    my %attributes=$svg->getAttributes;

    my $group=$svg->group(id=>"group_1");
    my $name=$group->getElementName;
    my $id=$group->getElementID;

    $group->circle(id=>"circle_1", cx=>20, cy=>20, r=>5, fill=>"red");
    my $rect=$group->rect(id=>"rect_1", x=>10, y=>10, width=>20, height=>30);
    my $width=$rect->getAttribute("width");

    my $has_children=$group->hasChildren();
    my @children=$group->getChildren();

    my $kid=$group->getFirstChild();
    do {
        print $kid->xmlify();
    } while ($kid=$kid->getNextSibling);

    my @ancestors=$rect->getParents();
    my $is_ancestor=$group->isAncestor($rect);
    my $is_descendant=$rect->isDescendant($svg);

    my @rectangles=$svg->getElements("rect");
    my $allelements_arrayref=$svg->getElements();

    ...and so on...

=head1 METHODS

=head2 @elements = $obj->getElements($element_name)

Return a list of all elements with the specified name (i.e. type) in the document. If
no element name is provided, returns a list of all elements in the document.
In scalar context returns an array reference.

=head2 @children = $obj->getChildren()

Return a list of all children defined on the current node, or undef if there are no children.
In scalar context returns an array reference.

Alias: getChildElements(), getChildNodes()
  
=head2 @children = $obj->hasChildren()

Return 1 if the current node has children, or 0 if there are no children.

Alias: hasChildElements, hasChildNodes()
  
=head2 $ref = $obj->getFirstChild() 

Return the first child element of the current node, or undef if there are no children.

=head2 $ref = $obj->getLastChild() 

Return the last child element of the current node, or undef if there are no children.

=head2 $ref = $obj->getSiblings()

Return a list of all children defined on the parent node, containing the current node.

=head2 $ref = $obj->getNextSibling()

Return the next child element of the parent node, or undef if this is the last child.

=head2 $ref = $obj->getPreviousSibling()

Return the previous child element of the parent node, or undef if this is the first child.

=head2 $index = $obj->getChildIndex()

Return the place of this element in the parent node's list of children, starting from 0.

=head2 $element = $obj->getChildAtIndex($index)

Returns the child element at the specified index in the parent node's list of children.

=head2 $ref = $obj->getParentElement()

Return the parent of the current node.

Alias: getParent()

=head2 @refs = $obj->getParentElements()

Return a list of the parents of the current node, starting from the immediate parent. The
last member of the list should be the document element.

Alias: getParents()

=head2 $name = $obj->getElementName()

Return a string containing the name (i.e. the type, not the ID) of an element.

Alias: getType(), getTagName(), getNodeName()

=head2 $ref = $svg->getElementByID($id) 

Alias: getElementbyID()

Return a reference to the element which has ID $id, or undef if no element with this ID exists.

=head2 $id = $obj->getElementID()

Return a string containing the ID of the current node, or undef if it has no ID.

=head2 $ref = $obj->getAttributes()

Return a hash reference of attribute names and values for the current node.

=head2 $value = $obj->getAttribute($name);

Return the string value attribute value for an attribute of name $name.

=head2 $ref = $obj->setAttributes({name1=>$value1,name2=>undef,name3=>$value3})

Set a set of attributes. If $value is undef, deletes the attribute.

=head2 $value = $obj->setAttribute($name,$value);

Set attribute $name to $value. If $value is undef, deletes the attribute.

=head2 $cdata = $obj->getCDATA()

Return the cannonical data (i.e. textual content) of the current node.

Alias: getCdata(), getData()

=head2 $boolean = $obj->isAncestor($element)

Returns 1 if the current node is an ancestor of the specified element, otherwise 0.

=head2 $boolean = $obj->isDescendant($element)

Returns 1 if the current node is a descendant of the specified element, otherwise 0.

=head1 AUTHOR

Ronan Oger, ronan@roasp.com

=head1 SEE ALSO

perl(1), L<SVG>, L<SVG::XML>, L<SVG::Element>, L<SVG::Parser>, L<SVG::Manual>

<http://www.roasp.com/>

<http://www.perlsvg.com/>

<http://www.roitsystems.com/>

<http://www.w3c.org/Graphics/SVG/>

=cut

1;

