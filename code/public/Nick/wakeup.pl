# Category=Wakeup

&tk_entry( 'Wakeup Time', \$Save{wakeup_time} );
&tk_radiobutton( 'Wakeup Time', \$Save{wakeup_time},
    [ '6 am', '6:15 am', '6:30 am', '6:45 am', '8 am', ' ' ] );

$v_wakeup_nick = new Voice_Cmd('Wakeup Nick');

# Disable this ... parents wake up at weird times
if ( $Save{wakeup_time} ) {
    speak "No, I don't want to wake up at $Save{wakeup_time}";
    $Save{wakeup_time} = '';
}

if ( ( time_now( $Save{wakeup_time} ) and $Weekday )
    or said $v_wakeup_nick)
{
    # Can not do more than one run_voice_cmd at a time :(
    #   run_voice_cmd 'set mp3 player to playlist thelist';
    #   sleep 1;
    #   run_voice_cmd 'set mp3 player to next song';
    run_voice_cmd 'set mp3 player to play';

    #   set $reading_light ON;
    speak "Good morning Nick. It is now $Time_Now";
}

set $reading_light OFF if time_now '7 am' and $Weekday;

run_voice_cmd 'set mp3 player to stop' if time_now '7:00 am' and $Weekday;

#un_voice_cmd 'set mp3 player to play' if time_now '3:30 pm' and $Weekday;

$wakeup_time = new Serial_Item( 'XNDNJ', 'Early' );
$wakeup_time->add( 'XNDNK', 'Late' );
if ( $state = state_now $wakeup_time) {
    $Save{wakeup_time} = '6 am'    if ( $state eq 'Early' );
    $Save{wakeup_time} = '6:45 am' if ( $state eq 'Late' );
    speak "Me wake up at $Save{wakeup_time}";
}

