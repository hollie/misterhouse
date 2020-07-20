=head1 NAME

Lingua::ES::Numeros - Convierte n�meros a texto en Espa�ol (Castellano)

=head1 SYNOPSIS

   use Lingua::ES::Numeros

   $obj = new Lingua::ES::Numeros ('MAYUSCULAS' => 1)
   print $obj->Cardinal(124856), "\n";
   print $obj->Real(124856.531), "\n";
   $obj->{SEXO} = 'a';
   print $obj->Ordinal(124856), "\n";

=head1 REQUIERE

Perl 5.004, Exporter, Carp

=head1 DESCRIPTION

Lingua::ES::Numeros convierte n�meros de precisi�n arbitraria en su
representaci�n textual en castellano.  Tiene soporte para la
representaci�n de cardinales, ordinales y reales.  Como los n�meros
manejados tienen mayor rango que el manejo n�mer�co nativo de Perl,
estos se manejan como cadenas de caracteres, permitiendo as� el
crecimiento ilimitado del sistema de conversi�n.

=cut

#######################################################################
# Jose Luis Rey Barreira (C) 2001
# C�digo bajo licencia GPL ver http://www.gnu.org
#######################################################################

package Lingua::ES::Numeros;

require 5.004;
require Exporter;
@ISA = qw(Exporter);

use strict;
use Carp;

use vars qw {
	$VERSION
	@EXPORT
	@EXPORT_OK
	%EXPORT_TAGS
};

BEGIN {
	$VERSION = '0.01';

	@EXPORT = qw{ cardinal real ordinal };
	@EXPORT_OK = qw{ parse_num };
	%EXPORT_TAGS = ( 
		'all' => [ @EXPORT, @EXPORT_OK ],
		'default' => [ @EXPORT ],
		);
};


#####################################################################
#
# Soporte para n�meros CARDINALES
#
####################################################################

my @hasta30 = qw{
	cero un dos tres cuatro 
	cinco seis siete ocho nueve
	diez once doce trece catorce
	quince diecis�is diecisiete dieciocho diecinueve
	veinte veintiun veintid�s veintitr�s veinticuatro
	veinticinco veintis�is veintisiete veintiocho veintinueve
	};

my @decenas = qw {
	treinta cuarenta cincuenta 
	sesenta setenta ochenta noventa
	};

my @centenas = (
	"", "ciento", "doscientos", "trescientos", 
	"cuatrocientos", "quinientos", "seiscientos", 
	"setecientos", "ochocientos", "novecientos"
	);
	
my @Llones = (
	"", "m", "b", "tr", "cuatr", "quint", 
	"sext", "sept", "oct", "non", "dec", 
	"undec", "dudec", "tredec", "cuatordec", 
	"quindec", "sexdec", "sepdec", "octodec",
	"novendec", "vigint"
	);

sub hasta100($) {
	my $n = shift;

	return "" if $n == 0;
	return $hasta30[$n] if $n < 30;
	$n =~ /(.)(.)$/;
	return $decenas[$1-3] unless $2;
	return $decenas[$1-3] . " y " .$hasta30[$2];
}

sub hasta1k($) {
	my $n = shift;
	
	return "" if $n == 0;
	return "cien" if $n == 100;
	my $c = $centenas[int($n / 100)];
	my $d = hasta100($n % 100);
	return $c . ($c and $d ? ' ' : '') . $d;
}

sub hasta1M($$) {
	my ($n, $un_mil) = @_;

	return "" if $n == 0;
	my $h = int($n / 1000);
	$h = $h==1 
		? $un_mil
			? 'un mil' 
			: 'mil'
		: $h 
			? hasta1k($h) . ' mil' 
			: '';
	my $l = hasta1k($n % 1000);
	return $h . ($h and $l ? ' ' : '') . $l;
}

sub enteroAtexto($$$) {
	my ($n, $exp, $un_mil) = @_;
	
	my @grupo;
	my $buf = '';
	
	$n =~ s/^0*//;		# eliminar ceros a la izquierda
	while ($exp > 6) {
		push @grupo, 0;
		$exp -= 6;
	}
	$n .= '0' x $exp;
	while ($n =~ s/(......)$//) {
		push @grupo, $1;
	}
	push @grupo, $n;
	croak 'N�mero fuera de rango' if @grupo > @Llones;
	for (my $i=$#grupo; $i>0; $i--) {
		my $g = $grupo[$i];
		next if $g == 0;
		$buf .= ($buf ? ' ' : '') . hasta1M($g, $un_mil) . ' ' . 
			$Llones[$i] . ($g==1 ? 'ill�n' : 'illones');
	}
	if ($grupo[0] > 0) {
		$buf .= ' ' if $buf;
		$buf .= hasta1M($grupo[0], $un_mil); 
	}
	return $buf;
}

sub fracAtexto($$$$) {
	my ($n, $exp, $un_mil, $sex) = @_;
	
	$n =~ s/0*$//;               # eliminar 0 a la derecha
	my $ll = -$exp + length $n;  # total de d�gitos en $n
	my $mm = $ll - 6*@Llones;    # digitos fuera de precisi�n
	croak 'N�mero fuera de precisi�n' if length($n) <= $mm; 
	$n = substr($n, 0, length($n)-$mm); # eliminar d�gitos sobrantes 
	return '' unless $n =~ /[1-9]/;  
	
	$ll -= $mm if $mm > 0;   # tomar en cuenta los d�gitos sobrantes
	$mm = $ll % 6;           # 1->d�cimas, 2->cent�simas, etc.
	$ll = int( $ll / 6 );    # 1->millon�simas, 3->trillon�simas, etc.
	if ($ll) {
		$ll = enteroAtexto('1', $mm, 0) . ' ' . $Llones[$ll] . 'illon�s';
		$ll =~ s/^un\s*//;  # evitar el 'un ' en 'un millon�simas'
	} else {
		for ($mm) {
			/1/ && do { $ll = "d�c"; last };
			/2/ && do { $ll = "cent�s"; last };
			$ll = enteroAtexto('1', $mm, 0) . "�s";
		}
	}
	# Traducir el n�mero, ajustar su sexo
	$mm = enteroAtexto($n, 0, $un_mil);
	if ($sex eq 'a') {
		$mm =~ s/un$/una/;
	} else {
		$sex = 'o';
	}
	# Ajustar el sexo de la magnitud (mil�simas, etc)
	$mm .= ' ' . $ll . "im$sex";
	$mm .= 's' if $n !~ /^0*1$/; # plural si es > 1
	return $mm;
}


#####################################################################
#
# Soporte para n�meros ORDINALES
#
####################################################################

my @hasta20vo = qw{
	x primer_ segund_ tercer_ cuart_ quint_ sext_ 
	s�ptim_ octav_ noven_ d�cim_ und�cim_ duod�cim_
	};

my @decimos = qw {
	vi tri cuadra quicua sexa septua octo nona
	};

my @centesimos = qw {
	c duoc tric cuadring quing sexc septig octing noning 
	};

sub hasta100vo($)
{
	$_ = shift;
	return $hasta20vo[$_] if $_ < 13;
	/(.)(.)/;
	return 'decim_' . $hasta20vo[$2] if $1 == 1;
	return $decimos[$1 - 2] . 'g�sim_' . ($2 ? ' ' . $hasta20vo[$2] : ""); 
}

sub hasta1Kvo($)
{
	my $n = shift;
	
	return "" if $n == 0;
	my $c = int($n / 100);
	$c = $c==0 
		? '' 
		: $centesimos[$c - 1] . 'ent�sim_';
	my $d = hasta100vo($n % 100);
	return $c . ($c and $d ? ' ' : '') . $d;
}

sub hasta1Mvo($)
{
	my $n = shift;

	return "" if $n == 0;
	my $h = int($n / 1000);
	$h = $h<=1
		? $h==0 
			? ''
			: 'mil�sim_'
		: hasta1k($h) . 'mil�sim_';
	my $l = hasta1Kvo($n % 1000);
	return $h . ($h and $l ? ' ' : '') . $l;
}


#####################################################################
#
# M�todos de Clase
#
####################################################################

=head1 M�TODOS DE CLASE

=over 4

=item parse_num($num, $dec, $sep)

Descompone el n�mero en sus diferentes partes y retorna una lista con
las mismas, por ejemplo:

   use Linugua::ES::Numeros qw( :All );
   ($sgn, $ent, $frc, $exp) = parse_num('123.45e10', '.', '",');

=head2 Par�metros

=over 4

=item $num

El n�mero a traducir

=item $dec

El separador de decimales.

=item $sep

Los caracteres separadores de miles, millones, etc.

=back

=head2 Valores de retorno

=over 4

=item $sgn

Signo, puede ser -1 si est� presente el signo negativo, 1 si est�
presente el signo negativo y 0 si no hay signo presente.

=item $ent

Parte entera del n�mero, solo los d�gitos m�s significativos (ver $exp)

=item $frc

Parte fraccional del n�mero, solo los d�gitos menos significativos (ver
$exp)

=item $exp

Exponente del n�mero, si es > 0, dicta el n�mero de ceros que sigue a la parte entera, si es < 0, dicta el n�mero de ceros que est�n entre el punto decimal y la parte fraccional.

=back

Este m�todo no se exporta implicitamente, asi que debe ser importado
con cualquiera de las siguientes sintaxis:

  use Lingua::ES::Numeros qw(parse_num);
  use Lingua::ES::Numeros qw(:All);

=back

=cut

sub parse_num($$$)
{
	$_ = shift;
	my ($dec, $sep) = @_;
	
	my ($sgn, $int, $frc, $exp);

	# Eliminar blancos y separadores
	s/[\s\Q$sep\E]//g;
	$dec = '\\' . $dec;
	if (/^([+-]?)(?=\d|$dec\d)(\d*)($dec(\d*))?([Ee]([+-]?\d+))?$/) {
		($sgn, $int, $frc, $exp) = ( $1, $2, $4, $6 );
		$sgn = defined $sgn 
			? $sgn = $sgn eq '-' ? -1 : 1
			: 0;
		$exp = 0 unless defined $exp;
	}
	else {
		croak "N�mero ilegal";
	}
	return ($sgn, $int, $frc, $exp) if $exp == 0;
	
	# Correr el punto d�cimal tantas posciones como sea posible
	if ($exp > 0) {
		if ($exp > length $frc) {
			$exp -= length $frc;
			$int .= $frc;
			$frc = '';
		}
		else {
			$int .= substr($frc, 0, $exp);
			$frc = substr($frc, $exp);
			$exp = 0;
		}
	}
	else {
		if (-$exp > length $int) {
			$exp += length $int;
			$frc = $int . $frc;
			$int = '';
		}
		else {
			$frc = substr($int, $exp + length $int) . $frc;
			$int = substr($int, 0, $exp + length $int);
			$exp = 0;
		}
	}
	return ($sgn, $int, $frc, $exp);
}

=head1 CAMPOS

El objeto contiene los siguientes campos que alteran la conversi�n.

=over 4

=item DECIMAL

Especif�ca la cadena de caracteres que se utilizar� para separar la
parte entera de la parte fraccional del n�mero a convertir.  El valor
por defecto de DECIMAL es '.'

=item SEPARADORES

Cadena de caracteres que contiene todos los caracteres de formato del
n�mero.  Todos los caracteres de esta cadena ser�n ignorados por el
parser que descompone el n�mero.  El valor por defecto de SEPARADORES es
',"_'

=item ACENTOS

Afecta la ortograf�a de los n�meros traducidos, si es falso la
representaci�n textual de los n�meros no tendr� acentos, el valor
predeterminado de este campo es 1 (con acentos).  Est� campo puede ser
de mucha utilidad si el conjunto de caracteres utilizado no es el
Latin1, ya que los acentos dependen de �l en esta versi�n (ver
PROBLEMAS).

=item MAYUSCULAS

Si es cierto, la representaci�n textual del n�mero ser� una cadena de
caracteres en may�sculas, el valor predeterminado de este campo es 0 (en
min�sculas)

=item HTML

Si es cierto, la representaci�n textual del n�mero ser� una cadena de
caracteres en HTML (los acentos estar�n representados por las
respectivas entidades HTML).  El valor predeterminado es 0 (texto).

=item SEXO

El sexo de los n�meros, puede ser: 'a', 'o' o '', para n�meros en
femenino, masculino o neutro respectivamente.  El valor por defecto
de este campo es 'o'.

 +---+--------------------+-----------------------------+
 |N� |     CARDINALES     |          ORDINALES          |
 |me +------+------+------+---------+---------+---------+
 |ro | 'o'  | 'a'  |  ''  |   'o'   |   'a'   |   ''    |
 +---+------+------+------+---------+---------+---------+
 | 1 | uno  | una  | un   | primero | primera | primer  |
 | 2 | dos  | dos  | dos  | segundo | segunda | segundo |
 | 3 | tres | tres | tres | tercero | tercera | tercer  |
 +---+------+------+------+---------+---------+---------+

=item UNMIL

Este campo solo afecta la traduccion de cardinales y cuando es cierto,
el n�mero 1000 se traduce como 'un mil', de otro modo se traduce
simplemente 'mil'.  El valor por defecto de UNMIL es 1.

=item NEGATIVO

La cadena de caracteres que contiene el nombre con el que se traducir�
el signo negativo (-), por defecto vale 'menos'.

=item POSITIVO

La cadena de caracteres que contiene el nombre con el que se traducir�
el signo positivo (+), por defecto vale ''.  Esta cadena s�lo es a�adida
al n�mero en presencia del signo '+', de otro modo no se agrega aunque
el n�mero se asume positivo.

=item FORMATO

Una cadena de caracteres que especif�ca como se deben traducir los
decimales de un n�mero real.  Su valor por defecto es 'con %02d ctms.'
(ver el m�todo B<real>).

=back

=cut

my $objvars = {
	'ACENTOS' =>     1, 
	'MAYUSCULAS' =>  2, 
	'UNMIL' =>       3, 
	'HTML' =>        4, 
	'DECIMAL' =>     5,
	'SEPARADORES' => 6, 
	'SEXO' =>        7,
	'NEGATIVO' =>    8,
	'POSITIVO' =>    9,
	'FORMATO' =>     10 
	};

=head1 CONSTRUCTOR

Para construir un objeto Lingua::ES::Numeros, se utiliza el m�todo de
clase B<new>, este m�todo puede recibir como par�metro cualesquiera de
los campos mencionados en la secci�n anterior.

Ejemplos:

      use Lingua::ES::Numeros;
      
      # usa los valores predeterminados de los campos
      $obj = new Lingua::ES::Numeros; 
      
      # especif�ca los valores de algunos campos
      $obj = Lingua::ES::Numeros::->new( 'ACENTOS'    => 0, 
                                         'MAYUSCULAS' => 1,
                                         'SEXO'       => 'a',
					 'DECIMAL'    => ',',
					 'SEPARADORES'=> '"_' );

=cut

sub new {
	my $self = [ $objvars, 1, 0, 1, 0, '.', ',', 'o', 
			'menos', '', 'con %02d ctms.' ];
	bless $self, shift;
	while (@_) {
		my $i = shift;
		$self->{$i} = shift;
	}
	return $self;
}


#####################################################################
#
# M�todos del Objeto
#
####################################################################

sub retval($$)
{
# Rutina de utilidad que retorna el valor textual adecuado, seg�n los
# valores de los campos ACENTOS, MAYUSCULAS y HTML.
#
# Esta rutina por ahora no hace uso de locale ni utf8 y por lo tanto el
# m�dulo solo funciona en m�quinas que utilicen el set de caracteres
# Latin1 (ISO-8859-1).  Esto puede cambiar proximamente.
#
	my $self = shift;
	$_ = shift;
	if ($self->{ACENTOS}) {
		tr/a-z�����/A-Z�����/ if $self->{MAYUSCULAS};
		if ( $self->{HTML} ) {
			s/([����������])/&$1acute;/g;
			tr/����������/AEIOUaeiou/;
		}
	} 
	else {
		tr/�����/aeiou/;
		return uc $_ if $self->{MAYUSCULAS};
	}
	return $_;
}

=head1 M�TODOS DEL OBJETO

=over 4

=item $n = cardinal($n)

Convierte el n�mero $n, como un n�mero cardinal a castellano.

La conversi�n esta afectada por los campos: DECIMAL, SEPARADORES,
SEXO, ACENTOS, MAYUSCULAS, POSITIVO y NEGATIVO.

Esta conversi�n ignora la parte fraccional del n�mero, si la tiene.

=cut

sub cardinal($) {
	my $self = shift;
	my ($sgn, $ent, $frc, $exp)= parse_num(shift, $self->{DECIMAL}, $self->{SEPARADORES});
#	$ent = enteroAtexto($ent . '0' x $exp, $self->{UNMIL});
	$ent = enteroAtexto($ent, $exp, $self->{UNMIL});
	my $sex = $self->{SEXO};
	$ent =~ s/un$/un$sex/ if $sex;
	if ($ent) {
		my $s = '';
		$s = $self->{NEGATIVO} if $sgn < 0;
		$s = $self->{POSITIVO} if $sgn > 0;
		$s .= ' ' if $s;
		$ent = $s . $ent;
		$ent =~ tr/�����/aeiou/ unless $self->{ACENTOS};
	} 
	else {
		$ent = 'cero';
	}
	return retval( $self, $ent);
}

=item $n = real($n [, $fsexo])

Convierte el n�mero $n, como un n�mero real a castellano.  

El par�metro opcional $fsexo se utiliza para especificas un sexo diferente para
la parte decimal, recibe los mismos valores que se le pueden asignar al campo
SESO, pero el sexo neutro equivale a masculino en la parte fraccional, si es
omitido se usar� el valor del campo SEXO.

La conversi�n esta afectada por los campos: DECIMAL, SEPARADORES,
SEXO, ACENTOS, MAYUSCULAS, POSITIVO y NEGATIVO.

=head2 Formato de la parte fraccional (FORMATO)

Adem�s esta conversi�n utiliza el campo FORMATO para dirigir la
conversi�n de la parte fraccional del n�mero real.  Este campo es un
formato estilo sprintf que solo tiene una especificaci�n de
formato precedida por '%'.  Adem�s las dos �nicas especificaciones
v�lidas por ahora son:

=over 4

=item %s

Incluye la representaci�n textual de la parte fraccional dentro del
formato.  Por ejemplo, convertir '123.345' con formato 'm�s %s.' resultar�
en el n�mero: CIENTO VEINTITR�S Y TRECIENTOS CUARENTA M�S CINCO MIL�SIMAS.

=item %Nd

Incluye la representaci�n num�rica de la parte fraccional, donde N es
una especificaci�n del formato '%d' de sprintf.  Por ejemplo, convertir
'123.345' con formato ' con %02d ctms.' producir�: CIENTO VEINTITR�S Y
TRECIENTOS CUARENTA CON 34 CTMS.

=back

=cut

sub real($;$) {
	my $self = shift;
	my ($sgn, $ent, $frc, $exp)= parse_num(shift, $self->{DECIMAL}, $self->{SEPARADORES});
	my $fsex = shift; # sexo de la parte decimal (opcional)
	
	# Convertir la parte entera ajustando el sexo
	my $sex = $self->{SEXO};
#	$ent = enteroAtexto($ent . '0' x $exp, $self->{UNMIL});
	$ent = enteroAtexto($ent, $exp, $self->{UNMIL});
	$ent =~ s/un$/un$sex/ if $sex;
	
	# Traducir la parte decimal de acuerdo al formato
	for ($self->{FORMATO}) {
		/%s/ && do { 
			# Textual, se traduce seg�n el sexo
			$fsex = $sex unless defined $fsex;
			$frc = fracAtexto($frc, $exp, $self->{UNMIL}, $fsex);
			$frc = $frc ? sprintf($self->{FORMATO}, $frc) : '';
			last;
			};
		/%([0-9]*)/ && do {
			# Num�rico, se da formato a los d�gitos
			$frc = substr('0' x $exp . $frc, 0, $1);
			$frc = sprintf($self->{FORMATO}, $frc);
			last;
			};
		do {
			# Sin formato, se ignoran los decimales
			$frc = ''; 
			last;
			};
	}
	if ($ent) {
		my $s = '';
		$s = $self->{NEGATIVO} if $sgn < 0;
		$s = $self->{POSITIVO} if $sgn > 0;
		$s .= ' ' if $s;
		$ent = $s . $ent;
	} 
	else {
		$ent = 'cero';
	}
	$ent .= ' ' . $frc if $ent and $frc;
	return retval($self, $ent);
}

=item $n = ordinal($n)

Convierte el n�mero $n, como un n�mero ordinal a castellano.  

La conversi�n esta afectada por los campos: DECIMAL, SEPARADORES,
SEXO, ACENTOS y MAYUSCULAS.

Presenta advertencias si el n�mero es negativo y/o si no es un natural >
0.

=cut

sub ordinal($) {
	my $self = shift;
	my ($sgn, $ent, $frc, $exp)= parse_num(shift, $self->{DECIMAL}, $self->{SEPARADORES});
	
	croak "Ordinal negativo" if $sgn < 0;
	croak "Ordinal con decimales" if $frc;
	if ($ent =~ /^0*$/) {
		carp "Ordinal cero";
		return '';
	}

	my @grupo;
	
	$ent .= '0' x $exp;
	while ($ent =~ s/(......)$//) {
		push @grupo, $1;
	}
	push @grupo, $ent;
	$ent = '';
	for (my $i=$#grupo; $i>0; $i--) {
		my $g = $grupo[$i];
		next if $g == 0;
		$ent .= ($ent ? ' ' : '') . hasta1M($g,0) . ' ' . 
			$Llones[$i] . 'illon�sim_';
	}
	if ($grupo[0] > 0) {
		$ent .= ' ' if $ent;
		$ent .= hasta1Mvo($grupo[0]); 
	}
	my $sex = $self->{SEXO};
	$ent =~ s/r_$/r/ unless $sex;  # Ajustar neutros en 1er, 3er, etc.
	$sex = 'o' unless $sex;        
	$ent =~ s/_/$sex/g;
	return retval($self, $ent);
}

1;

__END__

=back

=head1 DIAGN�STICOS

=over 4

=item N�mero ilegal.

El n�mero tiene un error sint�ctico.

=item N�mero fuera de rango.

La parte entera del n�mero es demasiado grande.  Por el momento solo se
aceptan n�meros de hasta 10**126 - 1, pues no se cual es la
representaci�n textual de n�meros >= 10**126.  Cualquier ayuda o
correcci�n ser� bien recibida.

=item N�mero fuera de precisi�n.

La parte fraccional del n�mero es menor que 10**-126 y no se puede
traducir por los motivos antes mencionados.

=item Ordinal negativo

El n�mero a convertir en ordinal es negativo.

=item Ordinal con decimales

El n�mero a convertir en ordinal tiene decimales.

=back

=head1 AUTOR

Jos� Luis Rey Barreira <jrey@mercared.com>

=head1 PROBLEMAS

La conversi�n a may�sculas se est� haciendo actualmente mediante una
transliteraci�n para poder convertir los caracteres acentuados.  El
problema es que esto no funcionar� si el conjunto de caracteres en uso
es distinto al ISO 8859-1 (Latin1) o al ISO 8859-15.

Las alternativas a este problema ser�an: la utilizaci�n de Perl 5.6 o
superior con 'utf8', pero restringo el uso del m�dulo a una gran
cantidad de usuarios que todav�a usan Perl 5.00x, por otra parte podr�a
utilizar locales, pero no se si estos funcionan exactamente igual en
Unix, Windows, BeOS, etc. as� que creo que la transliteraci�n es
adecuada por ahora.

=head1 LICENCIA

Este c�digo es propiedad intelectual de Jos� Rey y se distribuye seg�n
los t�rminos de la Licencia P�blica General del proyecto GNU, cuya letra
y explicaci�n se pueden encontrar en ingl�s en la p�gina
http://www.gnu.org/licenses/licenses.html y de la que cual hay una
traducci�n al castellano en
http://lucas.hispalinux.es/Otros/gples/gples.html

=cut

