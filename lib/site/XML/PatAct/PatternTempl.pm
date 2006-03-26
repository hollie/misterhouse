# This template file is in the Public Domain.
# You may do anything you want with this file.
#
# $Id: PatternTempl.pm,v 1.2 1999/08/16 16:04:03 kmacleod Exp $
#

# replace all occurrences of PATTERN with the name of your module!

use strict;

package XML::PatAct::PATTERN;

sub new {
    my $type = shift;
    my $self = ($#_ == 0) ? { %{ (shift) } } : { @_ };

    # perform any one-time initializations

    return bless $self, $type;
}

sub initialize {
    my ($self, $driver) = @_;
    $self->{Driver} = $driver;

    # perform initializations for each XML instance
}

sub finalize {
    my $self = shift;

    # clean up any state information

    $self->{Driver} = undef;
}

sub match {
    my ($self, $element, $names, $nodes) = @_;

    # Use the Patterns list to match a pattern

    return undef;
}

1;

__END__

=head1 NAME

XML::PatAct::PATTERN - A pattern module for 

=head1 SYNOPSIS

 use XML::PatAct::PATTERN;

 my $patterns = [ PATTERN => ACTION,
                  ... ]

 my $matcher = XML::PatAct::PATTERN->new( Patterns => $patterns );

=head1 DESCRIPTION

XML::PatAct::PATTERN is a pattern module for use with PatAct action
modules for applying pattern-action lists to XML parses or trees.
XML::PatAct::PATTERN ...

Parameters can be passed as a list of key, value pairs or a hash.

DESCRIBE THE FORMAT OR LANGUAGE OF YOUR PATTERNS HERE

=head1 AUTHOR

This template file was written by Ken MacLeod, ken@bitsko.slc.ut.us

=head1 SEE ALSO

perl(1)

``Using PatAct Modules'' and ``Creating PatAct Modules'' in libxml-perl.

=cut
