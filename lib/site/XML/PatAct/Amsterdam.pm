#
# Copyright (C) 1999 Ken MacLeod
# XML::PatAct::Amsterdam is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: Amsterdam.pm,v 1.4 1999/12/22 21:15:00 kmacleod Exp $
#

use strict;

use UNIVERSAL;

package XML::PatAct::Amsterdam;

use vars qw{ $VERSION };

# will be substituted by make-rel script
$VERSION = "0.08";

sub new {
    my $type = shift;
    my $self = ($#_ == 0) ? { %{ (shift) } } : { @_ };

    bless $self, $type;

    my $usage = <<'EOF';
usage: XML::PatAct::Amsterdam->new( Matcher => $matcher,
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

    $self->{ActionStack} = [ ];

    # create a temporary Output_ in case we're creating a standard
    # output file that we'll delete later.
    if (!$self->{AsString} && !defined($self->{Output})) {
	require IO::File;
	import IO::File;
	$self->{Output_} = new IO::File(">-");
    } elsif (defined($self->{Output})) {
	$self->{Output_} = $self->{Output};
    }

    if ($self->{AsString}) {
	$self->{Strings} = [];
    }
}

sub end_document {
    my ($self, $document) = @_;

    # notify the pattern module that we're done
    $self->{Matcher}->finalize();

    if (defined($self->{Output_})) {
	delete $self->{Output_};
    }

    my $string = undef;
    if (defined($self->{AsString})) {
	$string = join('', @{$self->{Strings}});
	delete $self->{Strings};
    }

    # release all the info that is just used during event handling
    $self->{Matcher} = $self->{Names} = $self->{Nodes} = undef;
    $self->{ActionStack} = undef;

    return($string);
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
	$action = $self->{Patterns}[$index * 2 + 1];
    }

    push @{$self->{ActionStack}}, $action;

    if (defined($action)) {
	my $before = $action->{Before};
	if (defined $before) {
	    my $atts = $element->{Attributes};
	    $before =~ s/\[([\w.:]+)\]/
		($1 eq '_element') ? $element->{Name} : $atts->{$1}
	    /eg;
	    $self->print($before);
	}
    }
}

sub end_element {
    my ($self, $end_element) = @_;

    my $name = pop @{$self->{Names}};
    my $element = pop @{$self->{Nodes}};

    my $action = pop @{$self->{ActionStack}};

    if (defined($action)) {
	my $after = $action->{After};
	if (defined $after) {
	    my $atts = $element->{Attributes};
	    $after =~ s/\[([\w.:]+)\]/
		($1 eq '_element') ? $element->{Name} : $atts->{$1}
	    /eg;
	    $self->print($after);
	}
    }
}

sub characters {
    my ($self, $characters) = @_;

    $self->print($characters->{Data});
}

sub print {
    my ($self, $output) = @_;

    $self->{Output_}->print($output)
	if (defined($self->{Output_}));

    push(@{$self->{Strings}}, $output)
	if (defined($self->{AsString}));
}

1;

__END__

=head1 NAME

XML::PatAct::Amsterdam - An action module for simplistic style-sheets

=head1 SYNOPSIS

 use XML::PatAct::Amsterdam;

 my $patterns = [ PATTERN => { Before => 'before',
			       After => 'after' },
		  ... ];

 my $matcher = XML::PatAct::Amsterdam->new( I<OPTIONS> );


=head1 DESCRIPTION

XML::PatAct::Amsterdam is a PerlSAX handler for applying
pattern-action lists to XML parses or trees.  XML::PatAct::Amsterdam
applies a very simple style sheet to an instance and outputs the
result.  Amsterdam gets it's name from the Amsterdam SGML Parser (ASP)
which inspired this module.

CAUTION: Amsterdam is a very simple style module, you will run into
it's limitations quickly with even moderately complex XML instances,
be aware of and prepared to switch to more complete style modules.

New XML::PatAct::Amsterdam instances are creating by calling `new()'.
Parameters can be passed as a list of key, value pairs or a hash.  A
Patterns and Matcher options are required.  The following I<OPTIONS>
are supported:

=over 4

=item Patterns

The pattern-action list to apply.  The list is an anonymous array of
pattern, action pairs.  Each action in the list contains either or
both a Before and an After string to copy to the output before and
after processing an XML element.  The Before and After strings may
contain attribute names enclosed in square brackets (`C<[>' I<NAME>
`C<]>'), these are replaced with the value of the attribute with that
name.  The special I<NAME> `C<_element>' will be replaced with the
element's name.

=item Matcher

An instance of the pattern or query matching module.

=item Output

An IO::Handle or one of it's subclasses (such as IO::File), if this
parameter is not present and the AsString option is not used, the
module will write to standard output.

=item AsString

Return the generated output as a string from the `C<parse()>' method
of the PerlSAX event generator.

=back

=head1 AUTHOR

Ken MacLeod, ken@bitsko.slc.ut.us

=head1 SEE ALSO

perl(1)

``Using PatAct Modules'' and ``Creating PatAct Modules'' in libxml-perl.

=cut
