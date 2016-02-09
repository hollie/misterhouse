# Category = Time

#@ Wakeup events

my $Workday;
$Workday = $Weekday and !$Holiday and ( state $mode_occupied eq 'home' );

$wakeup_bypass = new Voice_Cmd 'Saltar despertador mañana';
if ( state_now $wakeup_bypass) {
    speak 'De acuerdo, sin despertador mañana';
}

$v_wakeup_parents = new Voice_Cmd('Despertar a los padres');
$v_wakeup_parents->set_info("No lo hagas!  Los padres quieren dormir.");

if (
    (
            time_now( $config_parms{wakeup_time} )
        and $Workday
        and ( state $mode_mh ne 'offline' )
    )
    or said $v_wakeup_parents)
{
    if ( state $wakeup_bypass) {
        print_log 'Despertador silenciado, hoy no suena!';
        set $wakeup_bypass 0;
    }
    else {
        set $mode_mh 'normal';
        $Save{mode_set} = '';
        set $mode_sleeping 'nobody';
        speak "rooms=all mode=unmute Buenos días.  Son las "
          . say_time($Time_Now)
          . " del $Date_Now_Speakable.";
        speak "rooms=all mode=unmute La temperatura exterior es "
          . round( $Weather{TempOutdoor} )
          . " grados";

        #       run_voice_cmd 'Check for school closing';

        #       set $left_bedroom_light  ON;
        #       set $right_bedroom_light ON;

        #       set $TV 'power,12';
        #       set $TV 'power,51';
        #       run "ir_cmd TV,POWER,5,1";

        #       &curtain_on('bedroom', OPEN) if time_greater_than("$Time_Sunrise + 0:15");

        #       $Save{heat_temp} = 68;
    }

}

if ( time_now "$config_parms{wakeup_time} + 0:40" and $Workday ) {
    run_voice_cmd 'Read internet weather';
}

if ( time_now "$config_parms{wakeup_time} + 0:40" and $Workday ) {
    run_voice_cmd 'Comprueba las últimas noticias';
}

