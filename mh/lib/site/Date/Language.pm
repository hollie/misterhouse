
package Date::Language;

use     strict;
use     Time::Local;
use     Carp;
use     vars qw($VERSION @ISA);
require Date::Format;

$VERSION = "1.06"; #$Id$
@ISA     = qw(Date::Format::Generic);

sub new
{
 my $self = shift;
 my $type = shift || $self;

 $type = "Date::Language::" . $type
	unless $type =~ /::/o;

 bless [], $type;
}

# Stop AUTOLOAD being called ;-)
sub DESTROY {}

sub AUTOLOAD
{
 use vars qw($AUTOLOAD);

 if($AUTOLOAD =~ /::strptime\Z/o)
  {
   my $self = $_[0];
   my $type = ref($self) || $self;
   require Date::Parse;

   no strict 'refs';
   *{"${type}::strptime"} = Date::Parse::gen_parser(
	\%{"${type}::DoW"},
	\%{"${type}::MoY"},
	\@{"${type}::Dsuf"},
	1);

   goto &{"${type}::strptime"};
  }

 croak "Undefined method &$AUTOLOAD called";
}

sub str2time
{
 my $me = shift;
 my @t = $me->strptime(@_);

 return undef
	unless @t;

 my($ss,$mm,$hh,$day,$month,$year,$zone) = @t;
 my @lt  = localtime(time);

 $hh    ||= 0;
 $mm    ||= 0;
 $ss    ||= 0;

 $month = $lt[4]
	unless(defined $month);

 $day  = $lt[3]
	unless(defined $day);

 $year = ($month > $lt[4]) ? ($lt[5] - 1) : $lt[5]
	unless(defined $year);

 return defined $zone ? timegm($ss,$mm,$hh,$day,$month,$year) - $zone
    	    	      : timelocal($ss,$mm,$hh,$day,$month,$year);
}


##
## English tables
##

package Date::Language::English;

use vars qw(@ISA @DoW @DoWs @MoY @MoYs @AMPM @Dsuf %MoY %DoW);
@ISA = qw(Date::Language);

@DoW = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
@MoY = qw(January February March April May June
	  July August September October November December);
@DoWs = map { substr($_,0,3) } @DoW;
@MoYs = map { substr($_,0,3) } @MoY;
@AMPM = qw(AM PM);

@Dsuf = (qw(th st nd rd th th th th th th)) x 3;
@Dsuf[11,12,13] = qw(th th th);
@Dsuf[30,31] = qw(th st);

@MoY{@MoY}  = (0 .. scalar(@MoY));
@MoY{@MoYs} = (0 .. scalar(@MoYs));
@DoW{@DoW}  = (0 .. scalar(@DoW));
@DoW{@DoWs} = (0 .. scalar(@DoWs));

# Formatting routines

sub format_a { $DoWs[$_[0]->[6]] }
sub format_A { $DoW[$_[0]->[6]] }
sub format_b { $MoYs[$_[0]->[4]] }
sub format_B { $MoY[$_[0]->[4]] }
sub format_h { $MoYs[$_[0]->[4]] }
sub format_p { $_[0]->[2] >= 12 ?  $AMPM[1] : $AMPM[0] }

##
## German tables
##

package Date::Language::German;

use vars qw(@ISA @DoW @DoWs @MoY @MoYs @AMPM @Dsuf %MoY %DoW);
@ISA = qw(Date::Language);

@MoY  = qw(Januar Februar März April Mai Juni
	   Juli August September Oktober November Dezember);
@MoYs = qw(Jan Feb Mär Apr Mai Jun Jul Aug Sep Oct Nov Dez);
@DoW  = qw(Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag);
@DoWs = qw(Son Mon Die Mit Don Fre Sam);

@AMPM =   @{Date::Language::English::AMPM};
@Dsuf =   @{Date::Language::English::Dsuf};

@MoY{@MoY}  = (0 .. scalar(@MoY));
@MoY{@MoYs} = (0 .. scalar(@MoYs));
@DoW{@DoW}  = (0 .. scalar(@DoW));
@DoW{@DoWs} = (0 .. scalar(@DoWs));

# Formatting routines

sub format_a { $DoWs[$_[0]->[6]] }
sub format_A { $DoW[$_[0]->[6]] }
sub format_b { $MoYs[$_[0]->[4]] }
sub format_B { $MoY[$_[0]->[4]] }
sub format_h { $MoYs[$_[0]->[4]] }
sub format_p { $_[0]->[2] >= 12 ?  $AMPM[1] : $AMPM[0] }
sub format_o { sprintf("%2d.",$_[0]->[3]) }

##
## Norwegian tables
##

package Date::Language::Norwegian;

use vars qw(@ISA @DoW @DoWs @MoY @MoYs @AMPM @Dsuf %MoY %DoW);
@ISA = qw(Date::Language);

@MoY  = qw(Januar Februar Mars April Mai Juni
	   Juli August September Oktober November Desember);
@MoYs = qw(Jan Feb Mar Apr Mai Jun Jul Aug Sep Okt Nov Des);
@DoW  = qw(Søndag Mandag Tirsdag Onsdag Torsdag Fredag Lørdag Søndag);
@DoWs = qw(Søn Man Tir Ons Tor Fre Lør Søn);

@AMPM =   @{Date::Language::English::AMPM};
@Dsuf =   @{Date::Language::English::Dsuf};

@MoY{@MoY}  = (0 .. scalar(@MoY));
@MoY{@MoYs} = (0 .. scalar(@MoYs));
@DoW{@DoW}  = (0 .. scalar(@DoW));
@DoW{@DoWs} = (0 .. scalar(@DoWs));

# Formatting routines

sub format_a { $DoWs[$_[0]->[6]] }
sub format_A { $DoW[$_[0]->[6]] }
sub format_b { $MoYs[$_[0]->[4]] }
sub format_B { $MoY[$_[0]->[4]] }
sub format_h { $MoYs[$_[0]->[4]] }
sub format_p { $_[0]->[2] >= 12 ?  $AMPM[1] : $AMPM[0] }

##
## Italian tables
##

package Date::Language::Italian;

use vars qw(@ISA @DoW @DoWs @MoY @MoYs @AMPM @Dsuf %MoY %DoW);
@ISA = qw(Date::Language);

@MoY  = qw(Gennaio Febbraio Marzo Aprile Maggio Giugno
	   Luglio Agosto Settembre Ottobre Novembre Dicembre);
@MoYs = qw(Gen Feb Mar Apr Mag Giu Lug Ago Set Ott Nov Dic);
@DoW  = qw(Domenica Lunedi Martedi Mercoledi Giovedi Venerdi Sabato);
@DoWs = qw(Dom Lun Mar Mer Gio Ven Sab);

@AMPM =   @{Date::Language::English::AMPM};
@Dsuf =   @{Date::Language::English::Dsuf};

@MoY{@MoY}  = (0 .. scalar(@MoY));
@MoY{@MoYs} = (0 .. scalar(@MoYs));
@DoW{@DoW}  = (0 .. scalar(@DoW));
@DoW{@DoWs} = (0 .. scalar(@DoWs));

# Formatting routines

sub format_a { $DoWs[$_[0]->[6]] }
sub format_A { $DoW[$_[0]->[6]] }
sub format_b { $MoYs[$_[0]->[4]] }
sub format_B { $MoY[$_[0]->[4]] }
sub format_h { $MoYs[$_[0]->[4]] }
sub format_p { $_[0]->[2] >= 12 ?  $AMPM[1] : $AMPM[0] }

##
## Austrian tables
##

package Date::Language::Austrian;

use vars qw(@ISA @DoW @DoWs @MoY @MoYs @AMPM @Dsuf %MoY %DoW);
@ISA = qw(Date::Language);

@MoY  = qw(Jänner Feber März April Mai Juni
	   Juli August September Oktober November Dezember);
@MoYs = qw(Jän Feb Mär Apr Mai Jun Jul Aug Sep Oct Nov Dez);
@DoW  = qw(Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag);
@DoWs = qw(Son Mon Die Mit Don Fre Sam);

@AMPM = @{Date::Language::English::AMPM};
@Dsuf = @{Date::Language::English::Dsuf};

@MoY{@MoY}  = (0 .. scalar(@MoY));
@MoY{@MoYs} = (0 .. scalar(@MoYs));
@DoW{@DoW}  = (0 .. scalar(@DoW));
@DoW{@DoWs} = (0 .. scalar(@DoWs));

# Formatting routines

sub format_a { $DoWs[$_[0]->[6]] }
sub format_A { $DoW[$_[0]->[6]] }
sub format_b { $MoYs[$_[0]->[4]] }
sub format_B { $MoY[$_[0]->[4]] }
sub format_h { $MoYs[$_[0]->[4]] }
sub format_p { $_[0]->[2] >= 12 ?  $AMPM[1] : $AMPM[0] }

1;

