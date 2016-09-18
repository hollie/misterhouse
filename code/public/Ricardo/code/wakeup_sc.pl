# Category = Time

#@ Wakeup events (Sacedón)

my $Workday;
$Workday = $Weekday and !$Holiday and ( state $mode_occupied eq 'home' );

if (    time_now( $config_parms{wakeup_time} )
    and ( state $mode_mh ne 'offline' )
    and ( state $mode_occupied eq 'home' ) )
{
    set $mode_mh 'normal';
    $Save{mode_set} = '';
    set $mode_sleeping 'nobody';
    speak "rooms=all mode=unmute Buenos días.  Son las "
      . say_time($Time_Now)
      . " del $Date_Now_Speakable.";
}

if ( time_now "$config_parms{wakeup_time}" ) {
    run_voice_cmd 'Que tiempo hace';
}

if ( time_now "$config_parms{wakeup_time}" ) {
    run_voice_cmd 'Comprueba las últimas noticias';
}

