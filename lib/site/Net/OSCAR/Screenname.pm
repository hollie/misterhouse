=pod

Net::OSCAR::Screenname -- OSCAR screenname class

This class overrides a few operators to transparently get
appropriate behavior for OSCAR screennames.  Screennames
are case-insensitive and whitespace-insensitive.  So, if you
do
	$a = Net::OSCAR::Screenname->new("Some Dude");
	print "Yay!\n" if $a eq "somedude";
will be true.

=cut

package Net::OSCAR::Screenname;

$VERSION = '1.925';
$REVISION = '$Revision: 1.24 $';

use strict;
use vars qw($VERSION);

use Net::OSCAR::Utility qw(normalize);

use overload
	"cmp" => "compare",
	'""' => "stringify",
	"bool" => "boolify";

sub new($$) {
	return $_[1] if ref($_[0]) or UNIVERSAL::isa($_[1], "Net::OSCAR::Screenname");
	my $class = ref($_[0]) || $_[0] || "Net::OSCAR::Screenname";
	shift;
	my $name = $_[0];
	my $self = ref($name) eq "SCALAR" ? $name : \"$name";
	bless $self, $class;
	return $self;
}

sub compare {
	my($self, $comparand) = @_;

	return normalize($$self) cmp normalize($comparand);
}

sub stringify { my $self = shift; return $$self; }

sub boolify {
	my $self = shift;
	return 0 if !defined($$self) or $$self eq "" or $$self eq "0";
	return 1;
}

1;
