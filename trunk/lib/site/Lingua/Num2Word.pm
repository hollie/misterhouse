# For Emacs: -*- mode:cperl; mode:folding -*-
#
# (c) 2002-2004 PetaMem, s.r.o.
#
# PPCG: 0.7

package Lingua::Num2Word;

# {{{ BEGIN
#
BEGIN {
  use Exporter ();
  use vars qw($VERSION $REVISION @ISA @EXPORT_OK %known);
  $VERSION    = '0.07';
  ($REVISION) = '$Revision: 1.25 $' =~ /([\d.]+)/;
  @ISA        = qw(Exporter);
  @EXPORT_OK  = qw(&cardinal &get_interval &known_langs &langs);
}
# }}}
# {{{ use block
use strict;
use Encode;
# }}}

# {{{ templates for functional and object interface
#
my $template_func = q§ use __PACKAGE_WITH_VERSION__ ();
                       $result = __PACKAGE__::__FUNCTION__($number);
                     §;

my $template_obj  = q§ use __PACKAGE_WITH_VERSION__ ();
                       my $tmp_obj = new __PACKAGE__;
                       $result = $tmp_obj->__FUNCTION__($number);
                     §;

# }}}
# {{{ %known                    language codes from iso639 mapped to respective interface
#
%known = (aa => undef, ab => undef,
	  af => { 'package'  => 'Numbers',
		  'version'  => '1.1',
                  'charset'  => 'ascii',
		  'limit_lo' => 0,
                  'limit_hi' => 99_999_999_999,
		  'function' => 'parse',
	          'code'     => $template_obj,
		},
	  am => undef, ar => undef, as => undef, ay => undef,
	  az => undef, ba => undef, be => undef, bg => undef,
	  bh => undef, bi => undef, bn => undef, bo => undef,
	  br => undef, ca => undef, co => undef,
	  cs => { 'package'  => 'Num2Word',
		  'version'  => '0.01',
                  'charset'  => 'iso-8859-2',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999,
		  'function' => 'num2cs_cardinal',
	          'code'     => $template_func,
		},
	  cy => undef, da => undef,
	  de => { 'package'  => 'Num2Word',
		  'version'  => '0.01',
                  'charset'  => 'iso-8859-1',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999,
		  'function' => 'num2de_cardinal',
	          'code'     => $template_func,
		},
	  dz => undef, el => undef,
	  en => { 'package'  => 'Numbers',
		  'version'  => '0.01',
                  'charset'  => 'ascii',
		  'limit_lo' => 1,
                  'limit_hi' => 999_999_999_999_999, # 1e63
		  'function' => '',
	          'code'     => q§ use __PACKAGE_WITH_VERSION__ qw(American);
				   my $tmp_obj = new __PACKAGE__;
				   $tmp_obj->parse($number);
				   $result = $tmp_obj->get_string;
				 §,
		},
	  eo => undef,
	  es => { 'package'  => 'Numeros',
		  'version'  => '0.01',
                  'charset'  => 'iso-8859-1',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999_999_999,
		  'function' => 'cardinal',
	          'code'     => $template_obj,
		},
	  et => undef,
	  eu => { 'package'  => 'Numbers',
		  'version'  => '0.01',
                  'charset'  => 'iso-8859-1',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999_999,
		  'function' => 'cardinal2alpha',
	          'code'     => $template_func,
		},
	  fa => undef, fi => undef, fj => undef, fo => undef,
	  fr => { 'package'  => 'Numbers',
		  'version'  => '0.04',
                  'charset'  => 'iso-8859-1',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999_999_999, # < 1e52
		  'function' => 'number_to_fr',
	          'code'     => $template_func,
		},
	  fy => undef, ga => undef, gd => undef, gl => undef,
	  gn => undef, gu => undef, ha => undef, he => undef,
	  hi => undef, hr => undef, hu => undef, hy => undef,
	  ia => undef,
	  id => { 'package'  => 'Nums2Words',
		  'version'  => '0.01',
                  'charset'  => 'ascii',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999_999_999,
		  'function' => 'nums2words',
	          'code'     => $template_func,
		},
	  ie => undef, ik => undef, is => undef,
	  it => { 'package'  => 'Numbers',
		  'version'  => '0.06',
                  'charset'  => 'iso-8859-1',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999_999,
		  'function' => 'number_to_it',
	          'code'     => $template_func,
		},
	  ja => { 'package'  => 'Number',
		  'version'  => '0.01',
		  'charset'  => 'ascii',
		  'limit_lo' => 1,
                  'limit_hi' => 999_999_999_999_999,
		  'function' => 'to_string',
		  'code'     => q§ use __PACKAGE_WITH_VERSION__ ();
				   my @words = __PACKAGE__::__FUNCTION__($number);
				   $result = join ' ', @words;
				 §,
		},
	  jw => undef, ka => undef, kk => undef, kl => undef,
          km => undef, kn => undef, ko => undef, ks => undef,
	  ku => undef, ky => undef, la => undef, ln => undef,
	  lo => undef, lt => undef, lv => undef, mg => undef,
	  mi => undef, mk => undef, ml => undef, mn => undef,
	  mo => undef, mr => undef, ms => undef, mt => undef,
	  my => undef, na => undef, ne => undef,
	  nl => { 'package'  => 'Numbers',
		  'version'  => '1.2',
                  'charset'  => 'ascii',
		  'limit_lo' => 0,
                  'limit_hi' => 99_999_999_999,
	  	  'function' => 'parse',
 	          'code'     => $template_obj,
		},
	  no => { 'package'  => 'Num2Word',
		  'version'  => '0.011',
		  'charset'  => 'iso-8859-1',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999,
		  'function' => 'num2no_cardinal',
		  'code'     => $template_obj,
		},
	  oc => undef, om => undef, or => undef,
	  pa => undef,
	  pl => { 'package'  => 'Numbers',
		  'version'  => '1.0',
                  'charset'  => 'cp1250',
		  'limit_lo' => 0,
                  'limit_hi' => 9_999_999_999_999,
		  'function' => 'parse',
	          'code'     => $template_obj,
		},
	  ps => undef,
	  pt => { 'package'  => 'Nums2Words',
		  'version'  => '1.03',
                  'charset'  => 'iso-8859-1',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999_999_999,
		  'function' => 'num2word',
	          'code'     => $template_func,
		},
	  qu => undef, rm => undef, rn => undef, ro => undef,
	  ru => { 'package'  => 'Number',
		  'version'  => '0.03',
                  'charset'  => 'windows-1251',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999_999_999,
		  'function' => 'rur_in_words',
	          'code'     => q§ use __PACKAGE_WITH_VERSION__ ();
				   $result = __PACKAGE__::__FUNCTION__($number);
				   if ($result) {
				     if ($number) {
				       $result =~ s/\s+\S+\s+\S+\s+\S+$//;
				     } else {
				       $result =~ s/\s+\S+$//;
				     }
				     $result =~ s/^\s+//;
				   }
				 §,
		},
	  rw => undef, sa => undef, sd => undef, sg => undef,
	  sh => undef, si => undef, sk => undef, sl => undef,
	  sm => undef, sn => undef, so => undef, sq => undef,
	  sr => undef, ss => undef, st => undef, su => undef,
          sv => { 'package'  => 'Num2Word',
		  'version'  => '0.04',
                  'charset'  => 'iso-8859-1',
		  'limit_lo' => 0,
                  'limit_hi' => 999_999_999,
		  'function' => 'num2sv_cardinal',
		  'code'     => $template_func,
		},
	  sw => undef, ta => undef, te => undef, tg => undef,
	  th => undef, ti => undef, tk => undef, tl => undef,
	  tn => undef, to => undef, tr => undef, ts => undef,
          tt => undef, tw => undef, uk => undef, ur => undef,
	  uz => undef, vi => undef, vo => undef, wo => undef,
	  xh => undef, yi => undef, yo => undef,
          zh => { 'package'  => 'Numbers',
                  'version'  => '0.03',
                  'charset'  => 'utf8',
		  'limit_lo' => 1,
                  'limit_hi' => 999_999_999_999_999,
                  'function' => '',
                  'code'     => q§ use __PACKAGE_WITH_VERSION__ qw(traditional);
				   my $tmp_obj = new __PACKAGE__;
				   $tmp_obj->parse($number);
				   $result = $tmp_obj->get_string;
				 §,
		},
	  zu => undef );
# }}}
# {{{ %known duplicity          codes from iso639 have the same interface of another code
#
  $known{in} = defined $known{id} ? {%{$known{id}}, lang=>'id'} : $known{id};
  $known{iw} = defined $known{he} ? {%{$known{he}}, lang=>'he'} : $known{he};
  $known{ji} = defined $known{yi} ? {%{$known{yi}}, lang=>'yi'} : $known{yi};
# }}}
# {{{ new                       constructor
#
sub new {
  return bless {}, shift;
}
# }}}
# {{{ known_langs               list of currently supported languages
#
sub known_langs {
  my @result;

  for (keys %known) {
    push @result,$_ if (defined $known{$_});
  }

  return @result if (wantarray);
  return \@result;
}
# }}}
# {{{ langs                     list of all languages from iso639
#
sub langs {
  my @tmp = keys %known;
  return @tmp if (wantarray);
  return \@tmp;
}
# }}}
# {{{ get_interval              get minimal and maximal supported number

#
# Return:
#  undef for unsupported language
#  list or list reference (depending to calling context) with
#  minimal and maximal supported number
#
sub get_interval {
  my $self = ref($_[0]) ? shift : Lingua::Num2Word->new();
  my $lang = shift || return undef;
  my @limits;

  return undef if (!defined $known{$lang});

  @limits = ($known{$lang}{limit_lo}, $known{$lang}{limit_hi});

  return @limits if (wantarray);
  return \@limits;
}

# }}}
# {{{ cardinal                  convert number to text
#
sub cardinal {
  my $self   = ref($_[0]) ? shift : Lingua::Num2Word->new();
  my $result = '';
  my $lang   = defined $_[0] ? shift : return $result;
  my $number = defined $_[0] ? shift : return $result;

  $lang = lc $lang;

  return $result if (!defined $known{$lang} || !$known{$lang}{charset});

  if (defined $known{$lang}{lang}) {
    eval $self->preprocess_code($known{$lang}{lang});
  } else {
    eval $self->preprocess_code($lang);
  }

  if ($result && $known{$lang}{charset} ne "utf8") {
    $result = Encode::decode($known{$lang}{charset},$result);
  }

  return $result;
}
# }}}
# {{{ preprocess_code           prepare code for evaluation
#
sub preprocess_code {
  my $self                  = shift;
  my $lang                  = shift;
  my $result                = $known{$lang}{code};
  my $pkg_name              = 'Lingua::'.uc($lang).'::'.$known{$lang}{package};
  my $pkg_name_with_version = $known{$lang}{version} ne ''
                            ? "$pkg_name $known{$lang}{version}" : $pkg_name;
  my $function              = $known{$lang}{function};

  $result =~ s/__PACKAGE_WITH_VERSION__/$pkg_name_with_version/g;
  $result =~ s/__PACKAGE__/$pkg_name/g;
  $result =~ s/__FUNCTION__/$function/g;

  return $result;
}
# }}}

1;
__END__

# {{{ module documentation

=head1 NAME

Lingua::Num2Word - wrapper for number to text conversion modules of
various languages in the Lingua:: hierarchy.

=head1 SYNOPSIS

 use Lingua::Num2Word;

 my $numbers = Lingua::Num2Word->new;

 # try to use czech module (Lingua::CS::Num2Word) for conversion to text
 my $text = $numbers->cardinal( 'cs', 123 );

 # or procedural usage if you dislike OO
 my $text = Lingua::Num2Word::cardinal( 'cs', 123 );

 print $text || "sorry, can't convert this number into czech language.";

 # check if number is in supported interval before conversion
 my $number = 999_999_999_999;
 my $limit  = $numbers->get_interval('cs');
 if ($limit) {
   if ($number > $$limit[1] || $number < $$limit[0]) {
     print "Number is outside of supported range - <$$limit[0], $$limit[1]>.";
   } else {
     print Lingua::Num2Word::cardinal( 'cs', $number );
   }
 } else {
   print "Unsupported language.";
 }

=head1 DESCRIPTION

Lingua::Num2Word is a module for converting numbers into their
equivalent in written representation. This is a wrapper for various
Lingua::XX::Num2Word modules that do the conversions for specific
languages.  Output encoding is utf-8.

For further information about various limitations of the specific
modules see their documentation.

=head2 Functions

=over

=item * cardinal(lang,number)

Conversion from number to text representation in specified language.

=item * get_interval(lang)

Returns the minimal and maximal number (inclusive) supported by the
conversion in a specified language. The returned value is a list of
two elements (low,high) or reference to this list depending on calling
context. In case a unsupported language is passed undef is returned.

=item * known_langs

List of all currently supported languages. Return value is list or reference
to list depending to calling context.

=item * langs

List of all known language codes from iso639. Return value is list or
reference to list depending to calling context.

=back

=head2 Language codes and names

Language codes and names from iso639 can be found at L<http://www.triacom.com/archive/iso639.en.html>

=head1 EXPORT_OK

=over

=item * cardinal

=item * get_interval

=item * known_langs

=item * langs

=back

=head2 Required modules / supported languages

This module is only wrapper and require other cpan modules for requested
conversions eg. Lingua::AF::Numbers for Afrikaans.

Currently supported languages/modules are:

=over

=item * af - L<Lingua::AF::Numbers>

=item * cs - L<Lingua::CS::Num2Word>

=item * de - L<Lingua::DE::Num2Word>

=item * en - L<Lingua::EN::Numbers>

=item * es - L<Lingua::ES::Numeros>

=item * eu - L<Lingua::EU::Numbers>

=item * fr - L<Lingua::FR::Numbers>

=item * id - L<Lingua::ID::Nums2Words>

=item * in - see 'id'

=item * it - L<Lingua::IT::Numbers>

=item * ja - L<Lingua::JA::Number>

=item * nl - L<Lingua::NL::Numbers>

=item * no - L<Lingua::NO::Num2Word>

=item * pl - L<Lingua::PL::Numbers>

=item * pt - L<Lingua::PT::Nums2Words>

=item * ru - L<Lingua::RU::Number>

=item * sv - L<Lingua::SV::Num2Word>

=item * zh - L<Lingua::ZH::Numbers>

=back

=head1 KNOWN BUGS

None.

=head1 AUTHOR

Roman Vasicek E<lt>rv@petamem.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-2004 PetaMem s.r.o. - L<http://www.petamem.com/>

This package is free software. You can redistribute and/or modify it under
the same terms as Perl itself.

=cut

# }}}
