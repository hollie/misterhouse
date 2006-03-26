#
# Copyright (C) 1999 Ken MacLeod
# XML::PatAct::MatchName is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: MatchName.pm,v 1.3 1999/12/22 21:15:00 kmacleod Exp $
#

use strict;

package XML::PatAct::MatchName;

use vars qw{ $VERSION };

# will be substituted by make-rel script
$VERSION = "0.08";

sub new {
    my $type = shift;
    my $self = ($#_ == 0) ? { %{ (shift) } } : { @_ };

    return bless $self, $type;
}

# This is functionally equivalent to PerlSAX `start_document()'
sub initialize {
    my ($self, $driver) = @_;
    $self->{Driver} = $driver;
}

# This is functionally equivalent to PerlSAX `end_document()'
sub finalize {
    my $self = shift;

    $self->{Driver} = undef;
}

# This is functionally equivalent to a PerlSAX `start_element()'
sub match {
    my ($self, $element, $names, $nodes) = @_;

    my $names_path = '/' . join('/', @$names);
    my $patterns = $self->{Patterns};
    my $ii = 0;
    while ($ii <= $#$patterns) {
        my $pattern = $patterns->[$ii];
	if ($names_path =~ m|/$pattern$|) {
	    return $ii / 2;
	}
	$ii += 2;
    }

    return undef;
}

1;

__END__

=head1 NAME

XML::PatAct::MatchName - A pattern module for matching element names

=head1 SYNOPSIS

 use XML::PatAct::MatchName;

 my $matcher = XML::PatAct::MatchName->new();

 my $patterns = [ 'foo' => ACTION,
		  'bar/foo' => ACTION,
		  ... ];

=head1 DESCRIPTION

XML::PatAct::MatchName is a pattern module for use with PatAct drivers
for applying pattern-action lists to XML parses or trees.
XML::PatAct::MatchName is a simple pattern module that uses just
element names to match on.  If multiple names are supplied seperated
by `C</>' characters, then all of the parent element names must match
as well.

The order of patterns in the list is not significant.
XML::PatAct::MatchName will use the most specific match.  Using the
synopsis above as an example, if you have an element `C<foo>',
`C<bar/foo>' will match if `C<foo>' is in an element `C<bar>',
otherwise just the pattern with `C<foo>' will match.

=head1 AUTHOR

Ken MacLeod, ken@bitsko.slc.ut.us

=head1 SEE ALSO

perl(1)

``Using PatAct Modules'' and ``Creating PatAct Modules'' in libxml-perl.

=cut
