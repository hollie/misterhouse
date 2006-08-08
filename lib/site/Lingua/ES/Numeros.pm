=head1 NAME

Lingua::ES::Numeros - Convierte números a texto en Español (Castellano)

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

Lingua::ES::Numeros convierte números de precisión arbitraria en su
representación textual en castellano.  Tiene soporte para la
representación de cardinales, ordinales y reales.  Como los números
manejados tienen mayor rango que el manejo númeríco nativo de Perl,
estos se manejan como cadenas de caracteres, permitiendo así el
crecimiento ilimitado del sistema de conversión.

=cut

#######################################################################
# Jose Luis Rey Barreira (C) 2001
# Código bajo licencia GPL ver http://www.gnu.org
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
# Soporte para números CARDINALES
#
####################################################################

my @hasta30 = qw{
	cero un dos tres cuatro 
	cinco seis siete ocho nueve
	diez once doce trece catorce
	quince dieciséis diecisiete dieciocho diecinueve
	veinte veintiun veintidós veintitrés veinticuatro
	veinticinco veintiséis veintisiete veintiocho veintinueve
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
	croak 'Número fuera de rango' if @grupo > @Llones;
	for (my $i=$#grupo; $i>0; $i--) {
		my $g = $grupo[$i];
		next if $g == 0;
		$buf .= ($buf ? ' ' : '') . hasta1M($g, $un_mil) . ' ' . 
			$Llones[$i] . ($g==1 ? 'illón' : 'illones');
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
	my $ll = -$exp + length $n;  # total de dígitos en $n
	my $mm = $ll - 6*@Llones;    # digitos fuera de precisión
	croak 'Número fuera de precisión' if length($n) <= $mm; 
	$n = substr($n, 0, length($n)-$mm); # eliminar dígitos sobrantes 
	return '' unless $n =~ /[1-9]/;  
	
	$ll -= $mm if $mm > 0;   # tomar en cuenta los dígitos sobrantes
	$mm = $ll % 6;           # 1->décimas, 2->centésimas, etc.
	$ll = int( $ll / 6 );    # 1->millonésimas, 3->trillonésimas, etc.
	if ($ll) {
		$ll = enteroAtexto('1', $mm, 0) . ' ' . $Llones[$ll] . 'illonés';
		$ll =~ s/^un\s*//;  # evitar el 'un ' en 'un millonésimas'
	} else {
		for ($mm) {
			/1/ && do { $ll = "déc"; last };
			/2/ && do { $ll = "centés"; last };
			$ll = enteroAtexto('1', $mm, 0) . "és";
		}
	}
	# Traducir el número, ajustar su sexo
	$mm = enteroAtexto($n, 0, $un_mil);
	if ($sex eq 'a') {
		$mm =~ s/un$/una/;
	} else {
		$sex = 'o';
	}
	# Ajustar el sexo de la magnitud (milésimas, etc)
	$mm .= ' ' . $ll . "im$sex";
	$mm .= 's' if $n !~ /^0*1$/; # plural si es > 1
	return $mm;
}


#####################################################################
#
# Soporte para números ORDINALES
#
####################################################################

my @hasta20vo = qw{
	x primer_ segund_ tercer_ cuart_ quint_ sext_ 
	séptim_ octav_ noven_ décim_ undécim_ duodécim_
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
	return $decimos[$1 - 2] . 'gésim_' . ($2 ? ' ' . $hasta20vo[$2] : ""); 
}

sub hasta1Kvo($)
{
	my $n = shift;
	
	return "" if $n == 0;
	my $c = int($n / 100);
	$c = $c==0 
		? '' 
		: $centesimos[$c - 1] . 'entésim_';
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
			: 'milésim_'
		: hasta1k($h) . 'milésim_';
	my $l = hasta1Kvo($n % 1000);
	return $h . ($h and $l ? ' ' : '') . $l;
}


#####################################################################
#
# Métodos de Clase
#
####################################################################

=head1 MÉTODOS DE CLASE

=over 4

=item parse_num($num, $dec, $sep)

Descompone el número en sus diferentes partes y retorna una lista con
las mismas, por ejemplo:

   use Linugua::ES::Numeros qw( :All );
   ($sgn, $ent, $frc, $exp) = parse_num('123.45e10', '.', '",');

=head2 Parámetros

=over 4

=item $num

El número a traducir

=item $dec

El separador de decimales.

=item $sep

Los caracteres separadores de miles, millones, etc.

=back

=head2 Valores de retorno

=over 4

=item $sgn

Signo, puede ser -1 si está presente el signo negativo, 1 si está
presente el signo negativo y 0 si no hay signo presente.

=item $ent

Parte entera del número, solo los dígitos más significativos (ver $exp)

=item $frc

Parte fraccional del número, solo los dígitos menos significativos (ver
$exp)

=item $exp

Exponente del número, si es > 0, dicta el número de ceros que sigue a la parte entera, si es < 0, dicta el número de ceros que están entre el punto decimal y la parte fraccional.

=back

Este método no se exporta implicitamente, asi que debe ser importado
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
		croak "Número ilegal";
	}
	return ($sgn, $int, $frc, $exp) if $exp == 0;
	
	# Correr el punto décimal tantas posciones como sea posible
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

El objeto contiene los siguientes campos que alteran la conversión.

=over 4

=item DECIMAL

Especifíca la cadena de caracteres que se utilizará para separar la
parte entera de la parte fraccional del número a convertir.  El valor
por defecto de DECIMAL es '.'

=item SEPARADORES

Cadena de caracteres que contiene todos los caracteres de formato del
número.  Todos los caracteres de esta cadena serán ignorados por el
parser que descompone el número.  El valor por defecto de SEPARADORES es
',"_'

=item ACENTOS

Afecta la ortografía de los números traducidos, si es falso la
representación textual de los números no tendrá acentos, el valor
predeterminado de este campo es 1 (con acentos).  Esté campo puede ser
de mucha utilidad si el conjunto de caracteres utilizado no es el
Latin1, ya que los acentos dependen de él en esta versión (ver
PROBLEMAS).

=item MAYUSCULAS

Si es cierto, la representación textual del número será una cadena de
caracteres en mayúsculas, el valor predeterminado de este campo es 0 (en
minúsculas)

=item HTML

Si es cierto, la representación textual del número será una cadena de
caracteres en HTML (los acentos estarán representados por las
respectivas entidades HTML).  El valor predeterminado es 0 (texto).

=item SEXO

El sexo de los números, puede ser: 'a', 'o' o '', para números en
femenino, masculino o neutro respectivamente.  El valor por defecto
de este campo es 'o'.

 +---+--------------------+-----------------------------+
 |Nú |     CARDINALES     |          ORDINALES          |
 |me +------+------+------+---------+---------+---------+
 |ro | 'o'  | 'a'  |  ''  |   'o'   |   'a'   |   ''    |
 +---+------+------+------+---------+---------+---------+
 | 1 | uno  | una  | un   | primero | primera | primer  |
 | 2 | dos  | dos  | dos  | segundo | segunda | segundo |
 | 3 | tres | tres | tres | tercero | tercera | tercer  |
 +---+------+------+------+---------+---------+---------+

=item UNMIL

Este campo solo afecta la traduccion de cardinales y cuando es cierto,
el número 1000 se traduce como 'un mil', de otro modo se traduce
simplemente 'mil'.  El valor por defecto de UNMIL es 1.

=item NEGATIVO

La cadena de caracteres que contiene el nombre con el que se traducirá
el signo negativo (-), por defecto vale 'menos'.

=item POSITIVO

La cadena de caracteres que contiene el nombre con el que se traducirá
el signo positivo (+), por defecto vale ''.  Esta cadena sólo es añadida
al número en presencia del signo '+', de otro modo no se agrega aunque
el número se asume positivo.

=item FORMATO

Una cadena de caracteres que especifíca como se deben traducir los
decimales de un número real.  Su valor por defecto es 'con %02d ctms.'
(ver el método B<real>).

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

Para construir un objeto Lingua::ES::Numeros, se utiliza el método de
clase B<new>, este método puede recibir como parámetro cualesquiera de
los campos mencionados en la sección anterior.

Ejemplos:

      use Lingua::ES::Numeros;
      
      # usa los valores predeterminados de los campos
      $obj = new Lingua::ES::Numeros; 
      
      # especifíca los valores de algunos campos
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
# Métodos del Objeto
#
####################################################################

sub retval($$)
{
# Rutina de utilidad que retorna el valor textual adecuado, según los
# valores de los campos ACENTOS, MAYUSCULAS y HTML.
#
# Esta rutina por ahora no hace uso de locale ni utf8 y por lo tanto el
# módulo solo funciona en máquinas que utilicen el set de caracteres
# Latin1 (ISO-8859-1).  Esto puede cambiar proximamente.
#
	my $self = shift;
	$_ = shift;
	if ($self->{ACENTOS}) {
		tr/a-záéíóú/A-ZÁÉÍÓÚ/ if $self->{MAYUSCULAS};
		if ( $self->{HTML} ) {
			s/([ÁÉÍÓÚáéíóú])/&$1acute;/g;
			tr/ÁÉÍÓÚáéíóú/AEIOUaeiou/;
		}
	} 
	else {
		tr/áéíóú/aeiou/;
		return uc $_ if $self->{MAYUSCULAS};
	}
	return $_;
}

=head1 MÉTODOS DEL OBJETO

=over 4

=item $n = cardinal($n)

Convierte el número $n, como un número cardinal a castellano.

La conversión esta afectada por los campos: DECIMAL, SEPARADORES,
SEXO, ACENTOS, MAYUSCULAS, POSITIVO y NEGATIVO.

Esta conversión ignora la parte fraccional del número, si la tiene.

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
		$ent =~ tr/áéíóú/aeiou/ unless $self->{ACENTOS};
	} 
	else {
		$ent = 'cero';
	}
	return retval( $self, $ent);
}

=item $n = real($n [, $fsexo])

Convierte el número $n, como un número real a castellano.  

El parámetro opcional $fsexo se utiliza para especificas un sexo diferente para
la parte decimal, recibe los mismos valores que se le pueden asignar al campo
SESO, pero el sexo neutro equivale a masculino en la parte fraccional, si es
omitido se usará el valor del campo SEXO.

La conversión esta afectada por los campos: DECIMAL, SEPARADORES,
SEXO, ACENTOS, MAYUSCULAS, POSITIVO y NEGATIVO.

=head2 Formato de la parte fraccional (FORMATO)

Además esta conversión utiliza el campo FORMATO para dirigir la
conversión de la parte fraccional del número real.  Este campo es un
formato estilo sprintf que solo tiene una especificación de
formato precedida por '%'.  Además las dos únicas especificaciones
válidas por ahora son:

=over 4

=item %s

Incluye la representación textual de la parte fraccional dentro del
formato.  Por ejemplo, convertir '123.345' con formato 'más %s.' resultará
en el número: CIENTO VEINTITRÉS Y TRECIENTOS CUARENTA MÁS CINCO MILÉSIMAS.

=item %Nd

Incluye la representación numérica de la parte fraccional, donde N es
una especificación del formato '%d' de sprintf.  Por ejemplo, convertir
'123.345' con formato ' con %02d ctms.' producirá: CIENTO VEINTITRÉS Y
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
			# Textual, se traduce según el sexo
			$fsex = $sex unless defined $fsex;
			$frc = fracAtexto($frc, $exp, $self->{UNMIL}, $fsex);
			$frc = $frc ? sprintf($self->{FORMATO}, $frc) : '';
			last;
			};
		/%([0-9]*)/ && do {
			# Numérico, se da formato a los dígitos
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

Convierte el número $n, como un número ordinal a castellano.  

La conversión esta afectada por los campos: DECIMAL, SEPARADORES,
SEXO, ACENTOS y MAYUSCULAS.

Presenta advertencias si el número es negativo y/o si no es un natural >
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
			$Llones[$i] . 'illonésim_';
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

=head1 DIAGNÓSTICOS

=over 4

=item Número ilegal.

El número tiene un error sintáctico.

=item Número fuera de rango.

La parte entera del número es demasiado grande.  Por el momento solo se
aceptan números de hasta 10**126 - 1, pues no se cual es la
representación textual de números >= 10**126.  Cualquier ayuda o
corrección será bien recibida.

=item Número fuera de precisión.

La parte fraccional del número es menor que 10**-126 y no se puede
traducir por los motivos antes mencionados.

=item Ordinal negativo

El número a convertir en ordinal es negativo.

=item Ordinal con decimales

El número a convertir en ordinal tiene decimales.

=back

=head1 AUTOR

José Luis Rey Barreira <jrey@mercared.com>

=head1 PROBLEMAS

La conversión a mayúsculas se está haciendo actualmente mediante una
transliteración para poder convertir los caracteres acentuados.  El
problema es que esto no funcionará si el conjunto de caracteres en uso
es distinto al ISO 8859-1 (Latin1) o al ISO 8859-15.

Las alternativas a este problema serían: la utilización de Perl 5.6 o
superior con 'utf8', pero restringo el uso del módulo a una gran
cantidad de usuarios que todavía usan Perl 5.00x, por otra parte podría
utilizar locales, pero no se si estos funcionan exactamente igual en
Unix, Windows, BeOS, etc. así que creo que la transliteración es
adecuada por ahora.

=head1 LICENCIA

Este código es propiedad intelectual de José Rey y se distribuye según
los términos de la Licencia Pública General del proyecto GNU, cuya letra
y explicación se pueden encontrar en inglés en la página
http://www.gnu.org/licenses/licenses.html y de la que cual hay una
traducción al castellano en
http://lucas.hispalinux.es/Otros/gples/gples.html

=cut

