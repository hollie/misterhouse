package Lingua::FR::Numbers;
use strict;

use Carp qw(carp);
use Exporter;
use vars qw( $VERSION @ISA @EXPORT_OK );
use vars qw(
  $MODE
  %NUMBER_NAMES
  %ORDINALS
  $OUTPUT_DECIMAL_DELIMITER
  $SIGN_NAMES
);

$VERSION                  = 0.04;
@ISA                      = qw(Exporter);
@EXPORT_OK                = qw( &number_to_fr &ordinate_to_fr );
$SIGN_NAMES               = ('moins');
$OUTPUT_DECIMAL_DELIMITER = ('virgule');
%NUMBER_NAMES             = (
    0    => 'zéro',
    1    => 'un',
    2    => 'deux',
    3    => 'trois',
    4    => 'quatre',
    5    => 'cinq',
    6    => 'six',
    7    => 'sept',
    8    => 'huit',
    9    => 'neuf',
    10   => 'dix',
    11   => 'onze',
    12   => 'douze',
    13   => 'treize',
    14   => 'quatorze',
    15   => 'quinze',
    16   => 'seize',
    17   => 'dix-sept',
    18   => 'dix-huit',
    19   => 'dix-neuf',
    20   => 'vingt',
    30   => 'trente',
    40   => 'quarante',
    50   => 'cinquante',
    60   => 'soixante',
    70   => 'soixante',
    80   => 'quatre-vingt',
    90   => 'quatre-vingt',
    100  => 'cent',
    1e3  => 'mille',
    1e6  => 'million',
    1e9  => 'milliard',
    1e12 => 'billion',        # un million de millions
    1e18 => 'trillion',       # un million de billions
    1e24 => 'quatrillion',    # un million de trillions
    1e30 => 'quintillion',    # un million de quatrillions
    1e36 => 'sextillion',     # un million de quintillions,
                              # the sextillion is the biggest legal unit
);
%ORDINALS = (
    1 => 'premier',
    5 => 'cinqu',
    9 => 'neuv',
);

sub number_to_fr {
    my $number    = shift;
    my @fr_string = ();

    # Test if $number is really a number, or return undef, from perldoc
    # -q numbers
    if ( $number !~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ ) {
        carp("Invalid number format: '$number'");
        return undef;
    }

    if ( $number > ( 1e75 - 1 ) ) {
        carp("Number '$number' too big to be represented as string");
        return undef;
    }

    return $NUMBER_NAMES{0} if $number == 0;

    # Add the 'minus' string if the number is negative.
    push @fr_string, $SIGN_NAMES if abs $number != $number;
    $number = abs $number;

    # We deal with decimal numbers by calling number2fr twice, once for
    # the integer part, and once for the decimal part.
    if ( $number != int $number ) {

        # XXX Ugly Hack.
        ( my $decimal ) = $number =~ /\.(\d+)/;

        push @fr_string, number_to_fr( int $number ), $OUTPUT_DECIMAL_DELIMITER;

        # XXX
        if ( $decimal =~ s/^(0+)// ) {
            my $decimal_power = 10**length $1;
            last unless $decimal_power;
            my $fr_decimal;
            $fr_decimal = number_to_fr($decimal) . ' ';
            $fr_decimal .= ordinate_to_fr($decimal_power);
            $fr_decimal .= 's' if $decimal > 1;
            push @fr_string, $fr_decimal;
        }
        else {
            push @fr_string, number_to_fr($decimal);
        }

        return join ( ' ', @fr_string );
    }

    # First, we split the number by 1000 blocks
    # i.e:
    #   $block[0] => 0    .. 999      => centaines
    #   $block[1] => 1000 .. 999_999  => milliers
    #   $block[2] => 1e6  .. 999_999_999 => millions
    #   $block[3] => 1e9  .. 1e12-1      => milliards
    my @blocks;
    while ($number) {
        push @blocks, $number % 1000;
        $number = int $number / 1000;
    }
    @blocks = reverse @blocks;

    # We then go through each block, starting from the greatest
    # (..., billions, millions, thousands)
    foreach ( 0 .. $#blocks ) {

        # No need to spell numbers like 'zero million'
        next if $blocks[$_] == 0;

        my $number = $blocks[$_];

        # Determine the 'size' of the block
        my $power = 10**( ( $#blocks - $_ ) * 3 );
        my $hundred = int( $blocks[$_] / 100 );
        my $teens   = int( $blocks[$_] % 100 / 10 );
        my $units   = $blocks[$_] % 10;

        # Process hundred numbers 'inside' the block
        # (ie. 235 in 235000 when dealing with thousands.)

        # Hundreds
        if ($hundred) {
            my $fr_hundred;

            # We don't say 'un cent'
            $fr_hundred = $NUMBER_NAMES{$hundred} . ' '
              unless $hundred == 1;

            $fr_hundred .= $NUMBER_NAMES{100};

            # Cent prend un 's' quand il est multiplié par un autre
            # nombre et qu'il termine l'adjectif numéral.
            $fr_hundred .= 's'
              if ( $hundred > 1 && !$teens && !$units && $_ == $#blocks );

            push @fr_string, $fr_hundred;
        }

        # Process number below 100
        my $fr_decimal;

        # No tens
        $fr_decimal = $NUMBER_NAMES{$units}
          if ( $units && !$teens )
          &&    # On ne dit pas 'un mille' (A bit awkward to put here)
          !( $number == 1 && ( $power == 1000 ) );

        # Cas spécial pour les 80
        # On dit 'quatre-vingts' mais 'quatre-vingt-deux'
        if ( $teens == 8 ) {
            $fr_decimal = $units
              ? $NUMBER_NAMES{ $teens * 10 } . '-' . $NUMBER_NAMES{$units}
              : $NUMBER_NAMES{ $teens * 10 } . 's';
        }

        # Cas spécial pour les nombres en 70 et 90
        elsif ( $teens == 7 || $teens == 9 ) {
            $units += 10;
            if ( $teens == 7 && $units == 11 ) {
                $fr_decimal =
                  $NUMBER_NAMES{ $teens * 10 } . ' et ' . $NUMBER_NAMES{$units};
            }
            else {
                $fr_decimal =
                  $NUMBER_NAMES{ $teens * 10 } . '-' . $NUMBER_NAMES{$units};
            }

        }

        # Un nombre s'écrit avec un trait d'union sauf s'il est associé
        # à 'cent' ou à 'mille'; ou s'il est relié par 'et'.
        # Nombres écrits avec des 'et': 21, 31, 51, 61, 71
        elsif ($teens) {
            if ( $teens == 1 ) {
                $fr_decimal = $NUMBER_NAMES{ $teens * 10 + $units };
            }
            elsif ( $units == 1 || $units == 11 ) {
                $fr_decimal =
                  $NUMBER_NAMES{ $teens * 10 } . ' et ' . $NUMBER_NAMES{$units};
            }
            elsif ( $units == 0 ) {
                $fr_decimal = $NUMBER_NAMES{ $teens * 10 };
            }
            else {
                $fr_decimal =
                  $NUMBER_NAMES{ $teens * 10 } . '-' . $NUMBER_NAMES{$units};
            }
        }

        push @fr_string, $fr_decimal if $fr_decimal;

        # Processing thousands, millions, billions, ...
        if ( $power >= 1e3 ) {
            my $fr_power;

            if ( exists $NUMBER_NAMES{$power} ) {
                $fr_power = $NUMBER_NAMES{$power};

                # Billion, milliard, etc. prennent un 's' au pluriel
                $fr_power .= 's' if $number > 1 && $power >= 1e6;

                push @fr_string, $fr_power;
            }

            # If the power we're looking dealing with doesn't exists
            # (ie. 1e15, 1e21) we multiply by the lowest power we have,
            # starting at 1e6.
            else {
                my $sub_power;
                my $pow_diff = 1;
                do {
                    $pow_diff *= 1_000_000;
                    $sub_power = $power / $pow_diff;
                } until exists $NUMBER_NAMES{$sub_power};

                # If the power_diff doesn't exists (for really big
                # numbers), we do the same dance.
                unless ( exists $NUMBER_NAMES{$pow_diff} ) {

                }
                $fr_power = $NUMBER_NAMES{$pow_diff};
                $fr_power .= 's' if $number > 1;
                $fr_power .= " de $NUMBER_NAMES{$sub_power}s";

                push @fr_string, $fr_power;
            }
        }

        next;
    }

    return join ( ' ', @fr_string );
}

sub ordinate_to_fr {
    my $number = shift;

    unless ( $number > 0 ) {
        carp('Ordinates must be strictly positive');
        return undef;
    }
    return $ORDINALS{1} if $number == 1;

    my $ordinal    = number_to_fr($number);
    my $last_digit = $number % 10;

    if ( $last_digit != 1 && exists $ORDINALS{$last_digit} ) {
        my $replace = number_to_fr($last_digit);
        $ordinal =~ s/$replace$/$ORDINALS{$last_digit}/;
    }

    $ordinal =~ s/e?$/ième/;
    $ordinal =~ s/vingtsième/vingtième/;    # Bug #1772
    $ordinal;
}

#
# OO Methods
#
sub new {
    my $class  = shift;
    my $number = shift;
    bless \$number, $class;
}

sub parse {
    my $self = shift;
    if ( $_[0] ) { $$self = shift }
    $self;
}

sub get_string {
    my $self = shift;
    number_to_fr($$self);
}

sub get_ordinate {
    my $self = shift;
    ordinate_to_fr($$self);
}

1;

__END__

=pod

=head1 NAME

Lingua::FR::Numbers - Converts numeric values into their French string
equivalents

=head1 SYNOPSIS

 # Procedural Style
 use Lingua::FR::Numbers qw(number_to_fr ordinate_to_fr);
 print number_to_fr( 345 );

 my $vingt  = ordinate_to_fr( 20 );
 print "Tintin est reporter au petit $vingt";

 # OO Style
 use Lingua::FR::Numbers;
 my $number = Lingua::FR::Numbers->new( 123 );
 print $number->get_string;
 print $number->get_ordinate;

 my $other_number = Lingua::FR::Numbers->new;
 $other_number->parse( 7340 );
 $french_string = $other_number->get_string;

=head1 DESCRIPTION

This module converts a number into a French cardinal or ordinal. 
It supports decimal numbers, but this feature is
experimental.

The interface tries to conform to the one defined in Lingua::EN::Number,
though this module does not provide any parse() method. Also, 
unlike Lingua::En::Numbers, you can use this module in a procedural
manner by importing the number_to_fr() function.

If you plan to use this module with greater numbers (>10e20), you can use
the Math::BigInt module:

 use Math::BigInt;
 use Lingua::FR::Numbers qw( number_to_fr );

 my $big_num = new Math::BigInt '1.23e68';
 print number_to_fr($big_num);
 # cent vingt-trois quintillions de sextillions

This module should output strings for numbers up to, but not including,
1e75, but due to a lack of documentation in French grammar, it can only
reliably output strings for numbers lower than 1e51. For example, 1e72
is 'un sextillion de sextillion', but I am unable to say 1e51 or 1e69,
at least for now.

=head2 VARIABLES

=head1 FUNCTION-ORIENTED INTERFACE

=head2 number_to_fr( $number )

 use Lingua::FR::Numbers qw(number_to_fr);
 my $depth = number_to_fr( 20_000 );
 my $year  = number_to_fr( 1870 );
 print "Jules Vernes écrivit _$depth lieues sous les mers_ en $year.";

This function can be exported by the module.

=head2 ordinate_to_fr( $number )
 
 use Lingua::FR::Numbers qw(ordinate_to_fr);
 my $twenty  = ordinate_to_fr( 20 );
 print "Tintin est reporter au petit $twenty";

This function can be exported by the module.

=head1 OBJECT-ORIENTED INTERFACE

=head2 new( [ $number ] )

 my $start = Lingua::FR::Numbers->new( 500 );
 my $end   = Lingua::FR::Numbers->new( 3000 );
 print "Nous partîmes ", $start->get_string, 
       "; mais par un prompt renfort\n",
       "Nous nous vîmes ", $end->get_string," en arrivant au port"

Creates and initializes a new instance of an object.

=head2 parse( $number )

Initializes (or reinitializes) the instance. 

=head2 get_string()

 my $string = $number->get_string;
 
Returns the number as a formatted string in French, lowercased.

=head2 get_ordinate()

 my $string = $number->get_ordinate;
 
Returns the ordinal representation of the number as a formatted string
in French, lowercased.

 
=head1 DIAGNOSTICS

=over

=item Invalid number format: '$number'

(W) The number specified is not in a valid numeric format.

=item Number '$number' too big to be represented as string

(W) The number is too big to be converted into a string. Numbers must be
lower than 1e75-1.

=back

=head1 SOURCE

I<Le français correct - Maurice GREVISSE>

I<Décret n° 61-501 du 3 mai 1961. relatif aux unités de mesure
et au contrôle des instruments de mesure.>
- http://www.adminet.com/jo/dec61-501.html

=head1 BUGS

Though the module should be able to convert big numbers (up to 10**36),
I do not know how Perl handles them.

Please report any bugs or comments using the Request Tracker interface:
https://rt.cpan.org/NoAuth/Bugs.html?Dist=Lingua-FR-Numbers

=head1 COPYRIGHT

Copyright 2002, Briac Pilpré. All Rights Reserved. This module can be
redistributed under the same terms as Perl itself.

=head1 AUTHOR

Briac Pilpré <briac@cpan.org>

=head1 SEE ALSO

Lingua::EN::Numbers, Lingua::Word2Num

