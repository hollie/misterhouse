package HTML::Entities;

# $Id$

=head1 NAME

HTML::Entities - Encode or decode strings with HTML entities

=head1 SYNOPSIS

 use HTML::Entities;

 $a = "V&aring;re norske tegn b&oslash;r &#230res";
 decode_entities($a);
 encode_entities($a, "\200-\377");

=head1 DESCRIPTION

This module deals with encoding and decoding of strings with HTML
character entites.  The module provide the following functions:

=over 4

=item decode_entities($string)

This routine replaces HTML entities found in the $string with the
corresponding ISO-8859/1 character.  Unrecognized entities are left
alone.

=item endode_entities($string, [$unsafe_chars])

This routine replaces unsafe characters in $string with their entity
representation.  A second argument can be given to specify which
characters to concider as unsafe.  The default set of characters to
expand are control chars, high-bit chars and the '<', '&', '>' and '"'
character.

=back

Both routines modify the string passed in as the first argument if
called in void context.  In scalar and array context the encoded or
decoded string is returned (and the argument string is left
unchanged).

If you prefer not to import these routines into your namespace you can
call them as:

  use HTML::Entities ();
  $encoded = HTML::Entities::encode($a);
  $decoded = HTML::Entities::decode($a);

The module can also export the %char2entity and the %entity2char
hashes which contains the mapping from all characters to the
corresponding entities.

=head1 COPYRIGHT

Copyright 1995-1998 Gisle Aas. All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);
use vars qw(%entity2char %char2entity);

require 5.004;
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(encode_entities decode_entities);
@EXPORT_OK = qw(%entity2char %char2entity);

($VERSION) = q$Revision$ =~ /: (\d+)/;
sub Version { $VERSION; }


%entity2char = (
 # Some normal chars that have special meaning in SGML context
 amp    => '&',  # ampersand 
'gt'    => '>',  # greater than
'lt'    => '<',  # less than
 quot   => '"',  # double quote

 # PUBLIC ISO 8879-1986//ENTITIES Added Latin 1//EN//HTML
 AElig	=> '�',  # capital AE diphthong (ligature)
 Aacute	=> '�',  # capital A, acute accent
 Acirc	=> '�',  # capital A, circumflex accent
 Agrave	=> '�',  # capital A, grave accent
 Aring	=> '�',  # capital A, ring
 Atilde	=> '�',  # capital A, tilde
 Auml	=> '�',  # capital A, dieresis or umlaut mark
 Ccedil	=> '�',  # capital C, cedilla
 ETH	=> '�',  # capital Eth, Icelandic
 Eacute	=> '�',  # capital E, acute accent
 Ecirc	=> '�',  # capital E, circumflex accent
 Egrave	=> '�',  # capital E, grave accent
 Euml	=> '�',  # capital E, dieresis or umlaut mark
 Iacute	=> '�',  # capital I, acute accent
 Icirc	=> '�',  # capital I, circumflex accent
 Igrave	=> '�',  # capital I, grave accent
 Iuml	=> '�',  # capital I, dieresis or umlaut mark
 Ntilde	=> '�',  # capital N, tilde
 Oacute	=> '�',  # capital O, acute accent
 Ocirc	=> '�',  # capital O, circumflex accent
 Ograve	=> '�',  # capital O, grave accent
 Oslash	=> '�',  # capital O, slash
 Otilde	=> '�',  # capital O, tilde
 Ouml	=> '�',  # capital O, dieresis or umlaut mark
 THORN	=> '�',  # capital THORN, Icelandic
 Uacute	=> '�',  # capital U, acute accent
 Ucirc	=> '�',  # capital U, circumflex accent
 Ugrave	=> '�',  # capital U, grave accent
 Uuml	=> '�',  # capital U, dieresis or umlaut mark
 Yacute	=> '�',  # capital Y, acute accent
 aacute	=> '�',  # small a, acute accent
 acirc	=> '�',  # small a, circumflex accent
 aelig	=> '�',  # small ae diphthong (ligature)
 agrave	=> '�',  # small a, grave accent
 aring	=> '�',  # small a, ring
 atilde	=> '�',  # small a, tilde
 auml	=> '�',  # small a, dieresis or umlaut mark
 ccedil	=> '�',  # small c, cedilla
 eacute	=> '�',  # small e, acute accent
 ecirc	=> '�',  # small e, circumflex accent
 egrave	=> '�',  # small e, grave accent
 eth	=> '�',  # small eth, Icelandic
 euml	=> '�',  # small e, dieresis or umlaut mark
 iacute	=> '�',  # small i, acute accent
 icirc	=> '�',  # small i, circumflex accent
 igrave	=> '�',  # small i, grave accent
 iuml	=> '�',  # small i, dieresis or umlaut mark
 ntilde	=> '�',  # small n, tilde
 oacute	=> '�',  # small o, acute accent
 ocirc	=> '�',  # small o, circumflex accent
 ograve	=> '�',  # small o, grave accent
 oslash	=> '�',  # small o, slash
 otilde	=> '�',  # small o, tilde
 ouml	=> '�',  # small o, dieresis or umlaut mark
 szlig	=> '�',  # small sharp s, German (sz ligature)
 thorn	=> '�',  # small thorn, Icelandic
 uacute	=> '�',  # small u, acute accent
 ucirc	=> '�',  # small u, circumflex accent
 ugrave	=> '�',  # small u, grave accent
 uuml	=> '�',  # small u, dieresis or umlaut mark
 yacute	=> '�',  # small y, acute accent
 yuml	=> '�',  # small y, dieresis or umlaut mark

 # Some extra Latin 1 chars that are listed in the HTML3.2 draft (21-May-96)
 copy   => '�',  # copyright sign
 reg    => '�',  # registered sign
 nbsp   => "\240", # non breaking space

 # Additional ISO-8859/1 entities listed in rfc1866 (section 14)
 iexcl  => '�',
 cent   => '�',
 pound  => '�',
 curren => '�',
 yen    => '�',
 brvbar => '�',
 sect   => '�',
 uml    => '�',
 ordf   => '�',
 laquo  => '�',
'not'   => '�',    # not is a keyword in perl
 shy    => '�',
 macr   => '�',
 deg    => '�',
 plusmn => '�',
 sup1   => '�',
 sup2   => '�',
 sup3   => '�',
 acute  => '�',
 micro  => '�',
 para   => '�',
 middot => '�',
 cedil  => '�',
 ordm   => '�',
 raquo  => '�',
 frac14 => '�',
 frac12 => '�',
 frac34 => '�',
 iquest => '�',
'times' => '�',    # times is a keyword in perl
 divide => '�',
);

# Make the oposite mapping
while (my($entity, $char) = each(%entity2char)) {
    $char2entity{$char} = "&$entity;";
}

# Fill inn missing entities
for (0 .. 255) {
    next if exists $char2entity{chr($_)};
    $char2entity{chr($_)} = "&#$_;";
}

my %subst;  # compiled encoding regexps


sub decode_entities
{
    my $array;
    if (defined wantarray) {
	$array = [@_]; # copy
    } else {
	$array = \@_;  # modify in-place
    }
    my $c;
    for (@$array) {
	s/(&\#(\d+);?)/$2 < 256 ? chr($2) : $1/eg;
	s/(&\#[xX]([0-9a-fA-F]+);?)/$c = hex($2); $c < 256 ? chr($c) : $1/eg;
	s/(&(\w+);?)/$entity2char{$2} || $1/eg;
    }
    wantarray ? @$array : $array->[0];
}

sub encode_entities
{
    my $ref;
    if (defined wantarray) {
	my $x = $_[0];
	$ref = \$x;     # copy
    } else {
	$ref = \$_[0];  # modify in-place
    }
    if (defined $_[1]) {
	unless (exists $subst{$_[1]}) {
	    # Because we can't compile regex we fake it with a cached sub
	    $subst{$_[1]} =
	      eval "sub {\$_[0] =~ s/([$_[1]])/\$char2entity{\$1}/g; }";
	    die $@ if $@;
	}
	&{$subst{$_[1]}}($$ref);
    } else {
	# Encode control chars, high bit chars and '<', '&', '>', '"'
	$$ref =~ s/([^\n\t !\#\$%\'-;=?-~])/$char2entity{$1}/g;
    }
    $$ref;
}

# Set up aliases
*encode = \&encode_entities;
*decode = \&decode_entities;

1;
