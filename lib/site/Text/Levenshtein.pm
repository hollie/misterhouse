package Text::Levenshtein;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = '0.03';
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(&distance);
%EXPORT_TAGS = ();


sub _min {

	my ($first,$second,$third)=@_;
	my $result=$first;

	$result=$second if ($second < $result);
	$result=$third if ($third < $result);

	return $result
}


sub distance {

	my ($s,@t)=@_;

	my $n=length($s);
	my @result;

	foreach my $t (@t) {

		my @d;
		my $cost=0;

		my $m=length($t);
		if(!$n) {push @result,$m;last}
		if(!$m) {push @result,$n;last}

		$d[0][0]=0;
		foreach my $i (1 .. $n) {$d[$i][0]=$i}
		foreach my $j (1 .. $m) {$d[0][$j]=$j}

		foreach my $i (1 .. $n) {
			my $s_i=substr($s,$i-1,1);
			foreach my $j (1 .. $m) {

				my $t_i=substr($t,$j-1,1);

				if ($s_i eq $t_i) {

					$cost=0

				} else {

					$cost=1
				}
			
				$d[$i][$j]=&_min($d[$i-1][$j]+1,
						 $d[$i][$j-1]+1,
						 $d[$i-1][$j-1]+$cost)
			}
		}

		push @result,$d[$n][$m];
	}

	if (wantarray) {return @result} else {return $result[0]}
}
	
1;

__END__

=head1 NAME

Text::Levenshtein - An implementation of the Levenshtein edit distance

=head1 SYNOPSIS

 use Text::Levenshtein qw(distance);

 print distance("foo","four");
 # prints "2"

 my @words=("four","foo","bar");
 my @distances=distance("foo",@words);

 print "@distances";
 # prints "2 0 3"
 

=head1 DESCRIPTION

This module implements the Levenshtein edit distance.
The Levenshtein edit distance is a measure of the degree of proximity between two strings.
This distance is the number of substitutions, deletions or insertions ("edits") 
needed to transform one string into the other one (and vice versa).
When two strings have distance 0, they are the same.
A good point to start is: <http://www.merriampark.com/ld.htm>

See also Text::WagnerFischer on CPAN for a configurable edit distance, i.e. for
configurable costs (weights) for the edits.


=head1 AUTHOR

Copyright 2002 Dree Mistrut <F<dree@friul.it>>

This package is free software and is provided "as is" without express
or implied warranty.  You can redistribute it and/or modify it under 
the same terms as Perl itself.

=cut

