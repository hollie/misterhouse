package Text::PhraseDistance;

use strict;
#use warnings;  # Not in perl 5.0
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = '0.02';
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(&pdistance);
%EXPORT_TAGS = ();

sub _create_sets {

	my ($phrase,$set)=@_;

	$set=quotemeta($set);

	my $RE1 = qr/[$set]/;
	my $RE2 = qr/[^$set]/;

	my @set1 = ();
	my @set2 = ();
	my $flip_flop = 1;

	while ($phrase) {
      	
		if ( $flip_flop ) {
            
			$phrase =~ s/$RE1*//x;
                  	push @set1, $&;
            	}
            	else {

                	$phrase =~ s/$RE2*//x;
                	push @set2, $&;
		}
            
		$flip_flop = !$flip_flop;
	}

	return \@set1,\@set2;
}

sub _set_distance {

	my ($refc,$set1,$set2,$distance)=@_;
	my $string_difference_cost=$$refc[0];
	my $positional_cost=$$refc[1];
	my $correction=$$refc[2];

	if ((!scalar @$set1) && (!scalar @$set2)) {

		return 0
	}

	my @matrix_distance;
	my @matrix_preference_set1;
	my @matrix_preference_set2;
	my $real_dim_set=@$set1;

	if ($#$set1 > $#$set2) {

		$real_dim_set=@$set2;
		foreach my $index (1 .. $#$set1-$#$set2) {

			push @$set2,"";
		}

	} elsif ($#$set1 < $#$set2) {

		$real_dim_set=@$set1;
		foreach my $index (1 .. $#$set2-$#$set1) {

			push @$set1,"";
		}
	}

	my $count_distance_0=0;
	foreach my $index_set1 (0 .. $#$set1) {

		my $distance_0=0;
		foreach my $index_set2 (0 .. $#$set2) {

			my $elem_set1=$$set1[$index_set1];
			my $elem_set2=$$set2[$index_set2];
			my $abs_index_distance=abs($index_set1 - $index_set2);
			my $local_distance=&$distance($elem_set1,$elem_set2);

			$matrix_distance[$index_set1]
					[$index_set2]=$local_distance
							 *$string_difference_cost
				     		      + $abs_index_distance
							 *$positional_cost;

			$distance_0++ if (!$local_distance);
		}

		$count_distance_0++ if ($distance_0);
	}

	foreach my $index_set1 (0 .. $#$set1) {

		$matrix_preference_set1[$index_set1]=[

	        				sort { 
                             				$matrix_distance[ $index_set1 ][ $b ]
                                 				<=>
			        	                $matrix_distance[ $index_set1 ][ $a ]

		        		             } 0 .. $#$set2 
                		  	];

		$matrix_preference_set2[$index_set1]=[

	        				sort { 
                             				$matrix_distance[ $b ][ $index_set1 ]
                                	 			<=>
				                        $matrix_distance[ $a ][ $index_set1 ]

			        	             } 0 .. $#$set1
        	        	  	];
	}

	my @unpaired_set1=(0..$#$set1);
	my %married_set2=();

	while (@unpaired_set1) {

		my $set1_element=pop @unpaired_set1;
		my $set2_element=pop @{$matrix_preference_set1[$set1_element]};

		my $current_married=$married_set2{$set2_element};
		if (defined $current_married) {

			if ($matrix_preference_set2[$set2_element][$set1_element] <
			    $matrix_preference_set2[$set2_element][$current_married]) {

				push @unpaired_set1,$current_married;

				$married_set2{$set2_element}=$set1_element;

			} else {

				push @unpaired_set1,$set1_element;
			}

		} else {

			$married_set2{$set2_element}=$set1_element;
		}
	}

	my $dist;
	foreach my $set2_element (keys %married_set2) {

		$dist+=$matrix_distance[$married_set2{$set2_element}][$set2_element];
	}

	$dist+=abs($real_dim_set-$count_distance_0)*$correction;
	return $dist;
}

sub pdistance {

	my ($phrase1,$phrase2,$set,$distance,$optional_ref)=@_;
	my $mode;
	my $cost;

	if (!defined &$distance) {

		require Carp;
		Carp::croak("Text::PhraseDistance: a string distance subroutine is needed");
	}

	if ($optional_ref) {

		if (ref($optional_ref) ne "HASH") {

			warn "Text::PhraseDistance: options not well formed, using default";

		} else {

			foreach my $key (keys %$optional_ref) {

				if ($key eq "-cost") {

					$cost=$$optional_ref{'-cost'};
					if (ref($cost) ne "ARRAY") {

           					require Carp;
				      		Carp::croak("Text::PhraseDistance: -cost option requires an array");

					} else {

						if (@$cost < 3) {

							warn "Text::PhraseDistance: array cost not well formed, using default";
							$cost=undef;
						}
					}

				} elsif ($key eq "-mode") {

					$mode=$$optional_ref{'-mode'};

				} else {

					require Carp;
					Carp::croak("Text::PhraseDistance: $key is not a valid option");
				}
			}
		}
	}

	$cost ||= [1,1,0];
	$mode='both' if (!defined $mode);

	my $pdistance;

	my ($set1_p1,$set2_p1)=_create_sets($phrase1,$set);
	my ($set1_p2,$set2_p2)=_create_sets($phrase2,$set);

	if ($mode eq 'complementary') {

		#only things that ARE NOT in $set are used to calculate the phrase distance

		$pdistance=_set_distance($cost,$set2_p1,$set2_p2,$distance);

	} elsif ($mode eq 'both') {

		#both things that ARE and ARE NOT in $set are used to calculate the phrase distance

		$pdistance=_set_distance($cost,$set1_p1,$set1_p2,$distance);
		$pdistance+=_set_distance($cost,$set2_p1,$set2_p2,$distance);

	} elsif ($mode eq 'set') {

		#only things that ARE in $set are used to calculate the phrase distance

		$pdistance=_set_distance($cost,$set1_p1,$set1_p2,$distance);

	} else {

		require Carp;
		Carp::croak("Text::PhraseDistance: -mode option must be 'complementary' or 'both' or 'set', not $mode");
	}

	return $pdistance;
}
	
1;

__END__

=head1 NAME

Text::PhraseDistance - A measure of the degree of proximity of 2 given phrases


=head1 SYNOPSIS

 use Text::PhraseDistance qw(pdistance);

 sub distance {

	#your own implementation of a distance between strings
	#
	#that needs 2 strings (2 arguments) and returns a number
 }

 # otherwise you can use Text::Levensthein or others, e.g.
 # use Text::Levenshtein qw(distance);

 my $phrase1="a yellow dog";
 my $phrase2="a dog yellow";

 my $set="abcdefghijklmnopqrstuvwxyz";

 print pdistance($phrase1,$phrase2,$set,\&distance);


=head1 DESCRIPTION


This module provides a way to compare two phrases and to give a measure of
their proximity. In this context, a phrase is a groups of words formed by
a set of characters, separated by elements from the complemetary of that set.
E.g. if the set is composed by [abcdefghijklmnopqrstuvwxyz], a phrase is
"hello, world!" where the words are "hello" and "world", with ", " and "!" parts 
of the complementary set.

This module does not provide a "classic" string distance (e.g. Levenshtein), i.e. a 
way to compare two strings as unique entities. 
Instead it uses a string distance to compare the words, one by one and it tries to
"match" the ones that have a smaller distance. It also calculates a positional distance
for every words belonging to the set and for the elements of the complementary set.
So for example, for the two phrases:

 "a yellow dog"
 "a dog yellow"

Levenshtein says that are distance 8.
Also for the phrases:

 "a yellow dog"
 "a good cat"

the Levenshtein distance is 8, but the first 2 phrases are much closer than the second.

With the phrase distance implemented in this module, using the
Text::Levenshtein as the string distance, the phrases:

 "a yellow dog"
 "a good cat"

have distance 8, but the phrases:

 "a yellow dog"
 "a dog yellow"

have distance 2.
This is because this module evaluates the string distance for the words that it
is 0 (because there are 3 pairs of words with minimal string distance equal to 0) 
and the positional distance, that is 0 for the two "a"s plus 1 for "yellow" in the 
first phrase compared with "yellow" in the second (i.e. they are distant 1 
position from each other), plus 1 for "dog" in the first phrase compared with "dog" 
in the second.

This 2 components of the phrase distance (i.e. the string distance and the
positional distance) can have a different cost from the default (that is 1 for both)
to give your own type of phrase distance (see below for the syntax).

There is a third component: a cost that eigh heavily on the phrases that have 
less exact matches.

For example 

"dinning lamp on" compared with "living lamp on"

has 2 exact matches ("lamp","on") on 3 words of the 2nd phrase.

But

"living room lamp on" compared with "living lamp on"

has 3 exact matches ("living","lamp","on") on 3 words of the 2nd phrase.

In this case the phrase "dinning lamp on" has 1 "degree" of disavantage 
as to "living lamp on" when compared with "living room lamp on".

This 3rd component is disabled by default (i.e. it has a 0 cost), but
it can be enabled with custom cost (see below for the syntax).
In this case, the string distance used MUST define the exact match with cost 0.

By default, this module sums the phrase distance from the words from the set 
(i.e. formed by the defined set of characters) and the phrase distance calculated
from the "words" belonging the complementary set. In order to change this behaviour, 
see below.

The algorithm used to find the distance is the "Stable marriage problem" one.
This is a matching algorithm, used to harmonize the elements of two sets
on the ground of the preference relationships (in this case
the string distance of single "words" plus the positional distance plus
eventually the exact match weight).


=head2 USAGE

You have to import the pdistance function to the current namespace:

 use Text::PhraseDistance qw(pdistance);


then you have to declare your distance function:

 sub distance {

	#your own implementation of a distance between strings
	#
	#that needs 2 strings (2 arguments) and returns a number
 }

otherwise you can use Text::Levensthein or others, e.g.

 use Text::Levenshtein qw(distance);


You need also the set of characters for the words, e.g.

 my $set="abcdefghijklmnopqrstuvwxyz";


and then the two phrases, e.g.:


 my $phrase1="a yellow dog";
 my $phrase2="a dog yellow";


so you can call the phrase distance:

 print pdistance($phrase1,$phrase2,$set,\&distance);


In order to define a custom distance subroutine, wrapping an existent one
(e.g. WagnerFischer with a custom array cost) you can use a closure
like this:

 my $mydistance;
 {
     my $array_ref = [0, 1, 2];
     $mydistance = sub { 
         distance( $array_ref, shift, shift );
     };
 }


=head2 OPTIONAL PARAMETERS

 pdistance($phrase1,$phrase2,$set,\&distance,{-cost=>[1,0,3],-mode=>'set'});

 -mode	
 accepted values are: 	
	complementary	means that the distance is calculated only
			from the "words" from the complementary set
					
	both	the distance is calculated from both sets

	set	means that the distance is calculated only
		from the "words" from the given set

 Default mode is 'both'.

 -cost
 accepted value is an array with 3 elements: first is the cost for
 the string distance, the second is the cost for positional distance
 and the third is the cost to penalize the phrases that have less exact 
 matches.

 Default array is [1,1,0].


=head1 THANKS

Many thanks to Stefano L. Rodighiero <F<larsen at perlmonk.org>> for 
the support and part of the code, and to D. Frankowski and B. Winter 
for the suggestions.


=head1 AUTHOR

Copyright 2002,2003 Dree Mistrut <F<dree@friuli.to>>

This package is free software and is provided "as is" without express
or implied warranty. You can redistribute it and/or modify it under 
the same terms as Perl itself.


=head1 SEE ALSO

C<Text::Levenshtein>, C<Text::WagnerFischer>


=cut


