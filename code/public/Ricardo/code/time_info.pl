# Category=Informational

#@ Announces time and date info (e.g. sun/moon times and holidays)

# version 1.1
#
# written by Ricardo Arroyo (ricardo.arroyo@ya.com)
#
# adapted from time_info.pl, written by
#      Bruce Winter    bruce@misterhouse.net   http://misterhouse.net
#

$v_what_time = new Voice_Cmd( '{Que hora es,Dime la hora}', 0 );
$v_what_time->set_info('Dice la fecha y hora');
$v_what_time->set_authority('anyone');

#$v_what_time = new Voice_Cmd("{Please, } tell me the time");

if ( said $v_what_time) {
    my $temp = "";
    $temp .= "Es $Holiday. "                   if $Holiday;
    $temp .= "Es el cumpleaños de $Birthday. " if $Birthday;
    $temp .= "Es el santo de $Nameday. "       if $Nameday;

    # Avoid really speaking if command was from an Instant Messanger
    my $mode = ( get_set_by $v_what_time eq 'im' ) ? 'mode=mute' : '';
    respond "$mode Son las $Time_Now del $Date_Now_Speakable. $temp";
}

#Say 'today is [Holiday name]' ramdomly every 2 hours between 11am and 10pm
#on holiday days
speak "Hoy es $Holiday" if $Holiday and time_random( '* 11-22 * * *', 120 );

#Say 'today is birthday of [Birthday name]' ramdomly every 2 hours between 11am and 10pm on birthday days (non workdays) or every 90 minutes on workdays
speak "Hoy es el cumpleaños de $Birthday"
  if $Birthday
  and ( $Weekend or $Holiday )
  and time_random( '* 11-22 * * *', 120 );
speak "Hoy es el cumpleaños de $Birthday"
  if $Birthday
  and ( $Weekday and !$Holiday )
  and time_random( '* 20-22 * * *', 90 );

#Say 'today is nameday of [nameday name]' ramdomly every 2 hours between 11am and 10pm on birthday days (non workdays) or every 90 minutes on workdays
speak "Hoy es el santo de $Nameday"
  if $Nameday
  and ( $Weekend or $Holiday )
  and time_random( '* 11-22 * * *', 120 );
speak "Hoy es el santo de $Nameday"
  if $Nameday
  and ( $Weekday and !$Holiday )
  and time_random( '* 20-22 * * *', 90 );

$v_sun_set = new Voice_Cmd( 'Cuando es la puesta de sol', 0 );
$v_sun_set->set_info(
    "Calcula la puesta de sol para la latitud=$config_parms{latitude}, y longitud=$config_parms{longitude}"
);
$v_sun_set->set_authority('anyone');
respond
  "El sol sale hoy a las $Time_Sunrise, la puesta de sol es a las $Time_Sunset."
  if said $v_sun_set;

speak "Aviso, el sol está saliendo ahora a las " . say_time($Time_Sunrise)
  if time_now $Time_Sunrise and !$Save{sleeping_parents};
speak "app=notice Aviso, el sol se está poniendo ahora a las "
  . say_time($Time_Sunset)
  if time_now $Time_Sunset;

$v_moon_info1 = new Voice_Cmd "Cuando es la siguiente luna [nueva,llena]";
$v_moon_info2 = new Voice_Cmd "Cuando fue la última luna [nueva,llena]";
$v_moon_info3 = new Voice_Cmd "Cual es la fase de la luna";
$v_moon_info3->set_info(
    'fase será: Nueva, Cuarto creciente, Llena, Cuarto menguante, ...r');
$v_moon_info1->set_authority('anyone');
$v_moon_info2->set_authority('anyone');
$v_moon_info3->set_authority('anyone');

if ( $state = said $v_moon_info1) {
    my $state_en = $state eq 'nueva' ? 'new' : 'full';
    my $days = &time_diff( $Moon{"time_${state_en}"}, $Time );
    respond qq[La siguiente luna $state será en $days, el $Moon{$state_en}];
}

if ( $state = said $v_moon_info2) {
    my $state_en = $state eq 'nueva' ? 'new' : 'full';
    my $days = &time_diff( $Moon{"time_${state_en}_prev"}, $Time );
    respond
      qq[La última luna $state fué hace $days, el $Moon{"${state_en}_prev"}];
}

if ( $state = said $v_moon_info3) {
    respond
      qq[la fase de la luna es $Moon{phase}, con un brillo del $Moon{brightness}%, y $Moon{age} dias];
}

$full_moon = new File_Item("$config_parms{data_dir}/remarks/full_moon.txt");
if ( $Moon{phase} eq 'Llena' and time_random( '* 8-22 * * *', 240 ) ) {
    respond "app=notice Aviso, está noche es luna llena.  "
      . ( read_next $full_moon);
}

