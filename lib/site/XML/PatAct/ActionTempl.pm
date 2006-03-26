# This template file is in the Public Domain.
# You may do anything you want with this file.
#
# $Id: ActionTempl.pm,v 1.2 1999/08/16 16:04:03 kmacleod Exp $
#

# replace all occurrences of ACTION with the name of your module!

use strict;

use UNIVERSAL;

package XML::PatAct::ACTION;

sub new {
    my $type = shift;
    my $self = ($#_ == 0) ? { %{ (shift) } } : { @_ };

    bless $self, $type;

    my $usage = <<'EOF';
usage: XML::PatAct::ACTION->new( Matcher => $matcher,
				 Patterns => $patterns );
EOF

    die "No Matcher specified\n$usage\n"
	if !defined $self->{Matcher};
    die "No Patterns specified\n$usage\n"
	if !defined $self->{Patterns};

    # perform additional initialization here

    return $self;
}

sub start_document {
    my ($self, $document) = @_;

    # initialize the pattern module at the start of a document
    $self->{Matcher}->initialize($self);

    # create empty name and node lists for passing to `match()'
    $self->{Names} = [ ];
    $self->{Nodes} = [ ];

    # Knowing that a source is a tree can be useful information
    $self->{SourceIsGrove} = UNIVERSAL::isa($document, 'Data::Grove');
}

sub end_document {
    my ($self, $document) = @_;

    # notify the pattern module that we're done
    $self->{Matcher}->finalize();

    my $value;
    # perform any finalization actions, use $value to return a result
    # from calling `parse()'

    # release all the info that is just used during event handling
    $self->{Matcher} = $self->{Names} = $self->{Nodes} = undef;
    $self->{SourceIsGrove} = undef;

    return $value;
}

sub start_element {
    my ($self, $element) = @_;

    push @{$self->{Names}}, $element->{Name};
    push @{$self->{Nodes}}, $element;

    my $index = $self->{Matcher}->match($element,
					$self->{Names},
					$self->{Nodes});

    # use $index to retrieve an action for this element
}

sub end_element {
    my ($self, $end_element) = @_;

    my $name = pop @{$self->{Names}};
    my $element = pop @{$self->{Nodes}};

    # perform any finishing steps at the end of an element
}

sub characters {
    my ($self, $characters) = @_;

}

sub processing_instruction {
    my ($self, $pi) = @_;

}

sub ignorable_whitespace {
    my ($self, $characters) = @_;

}

1;

__END__

=head1 NAME

XML::PatAct::ACTION - An action module for

=head1 SYNOPSIS

 use XML::PatAct::ACTION;

 my $patterns = [ PATTERN => ACTION,
		  ... ];

 my $matcher = XML::PatAct::ACTION->new(Patterns => $patterns,
					Matcher => $matcher );


=head1 DESCRIPTION

XML::PatAct::ACTION is a PerlSAX handler for applying pattern-action
lists to XML parses or trees.  XML::PatAct::ACTION ...

New XML::PatAct::ACTION instances are creating by calling `new()'.  A
Parameters can be passed as a list of key, value pairs or a hash.
Patterns and Matcher options are required.  Patterns is the
pattern-action list to apply.  Matcher is an instance of the pattern
or query matching module.

DESCRIBE THE FORMAT OF YOUR ACTIONS HERE

=head1 AUTHOR

This template file was written by Ken MacLeod, ken@bitsko.slc.ut.us

=head1 SEE ALSO

perl(1)

``Using PatAct Modules'' and ``Creating PatAct Modules'' in libxml-perl.

=cut
