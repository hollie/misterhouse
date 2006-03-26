#
# Copyright (C) 1999 Ken MacLeod
# XML::Handler::XMLWriter is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: Subs.pm,v 1.2 1999/12/22 21:15:00 kmacleod Exp $
#

use strict;

package XML::Handler::Subs;

use UNIVERSAL;

use vars qw{ $VERSION };

# will be substituted by make-rel script
$VERSION = "0.08";

sub new {
    my $type = shift;
    my $self = ($#_ == 0) ? { %{ (shift) } } : { @_ };

    return bless $self, $type;
}

sub start_document {
    my ($self, $document) = @_;

    $self->{Names} = [];
    $self->{Nodes} = [];
}

sub end_document {
    my ($self, $document) = @_;

    delete $self->{Names};
    delete $self->{Nodes};

    return();
}

sub start_element {
    my ($self, $element) = @_;

    push @{$self->{Names}}, $element->{Name};
    push @{$self->{Nodes}}, $element;

    my $el_name = "s_" . $element->{Name};
    $el_name =~ s/[^a-zA-Z0-9_]/_/g;
    if ($self->can($el_name)) {
	$self->$el_name($element);
	return 1;
    }

    return 0;
}

sub end_element {
    my ($self, $element) = @_;

    my $called_sub = 0;
    my $el_name = "e_" . $element->{Name};
    $el_name =~ s/[^a-zA-Z0-9_]/_/g;
    if ($self->can(${el_name})) {
	$self->$el_name($element);
	$called_sub = 1;
    }

    pop @{$self->{Names}};
    pop @{$self->{Nodes}};

    return $called_sub;
}

sub in_element {
    my ($self, $name) = @_;

    return ($self->{Names}[-1] eq $name);
}

sub within_element {
    my ($self, $name) = @_;

    my $count = 0;
    foreach my $el_name (@{$self->{Names}}) {
	$count ++ if ($el_name eq $name);
    }

    return $count;
}

1;

__END__

=head1 NAME

XML::Handler::Subs - a PerlSAX handler base class for calling user-defined subs

=head1 SYNOPSIS

 use XML::Handler::Subs;

 package MyHandlers;
 use vars qw{ @ISA };

 sub s_NAME { my ($self, $element) = @_ };
 sub e_NAME { my ($self, $element) = @_ };

 $self->{Names};    # an array of names
 $self->{Nodes};    # an array of $element nodes

 $handler = MyHandlers->new();
 $self->in_element($name);
 $self->within_element($name);

=head1 DESCRIPTION

C<XML::Handler::Subs> is a base class for PerlSAX handlers.
C<XML::Handler::Subs> is subclassed to implement complete behavior and
to add element-specific handling.

Each time an element starts, a method by that name prefixed with `s_'
is called with the element to be processed.  Each time an element
ends, a method with that name prefixed with `e_' is called.  Any
special characters in the element name are replaced by underscores.

Subclassing XML::Handler::Subs in this way is similar to
XML::Parser's Subs style.

XML::Handler::Subs maintains a stack of element names,
`C<$self->{Names}', and a stack of element nodes, `C<$self->{Nodes}>'
that can be used by subclasses.  The current element is pushed on the
stacks before calling an element-name start method and popped off the
stacks after calling the element-name end method.  The
`C<in_element()>' and `C<within_element()>' calls use these stacks.

If the subclass implements `C<start_document()>', `C<end_document()>',
`C<start_element()>', and `C<end_element()>', be sure to use
`C<SUPER::>' to call the the superclass methods also.  See perlobj(1)
for details on SUPER::.  `C<SUPER::start_element()>' and
`C<SUPER::end_element()>' return 1 if an element-name method is
called, they return 0 if no method was called.

XML::Handler::Subs does not implement any other PerlSAX handlers.

XML::Handler::Subs supports the following methods:

=over 4

=item new( I<OPTIONS> )

A basic `C<new()>' method.  `C<new()>' takes a list of key, value
pairs or a hash and creates and returns a hash with those options; the
hash is blessed into the subclass.

=item in_element($name)

Returns true if `C<$name>' is equal to the name of the innermost
currently opened element.

=item within_element($name)

Returns the number of times the `C<$name>' appears in Names.

=back

=head1 AUTHOR

Ken MacLeod, ken@bitsko.slc.ut.us

=head1 SEE ALSO

perl(1), PerlSAX.pod(3)

=cut
