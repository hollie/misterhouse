# Category=Informational

#@ School related events

unless ( $Save{sleeping_kids} ) {

    #   speak "The time is $Time_Now" if time_cron '40,44,46,48 6 * * 1-5';
    speak "room=nick,zack $Time_Now. Kids leave in "
      . plural( 48 - $Minute, 'minute' )
      if time_cron '30,35,40,44,46,48,50 6 * * 1-5';

    if ( time_cron '43,49,52 6 * * 1-5' ) {

        #       or 9 == said $v_test1) {
        #       speak 'School bus weather report';
        run_voice_cmd 'What is the outside temperature';
    }

    #   speak("room=all The school bus does NOT arrives in " . &plural(05 - $Minute, 'minute')) if time_cron('00,01,02,03 7 * * 1-5');
}

if ( time_cron '01,15,30 6 * * 1-5' ) {
    run_voice_cmd 'Check for school closing';
}

#peak "rooms=all Remember to turn the boys alarm clocks off" if time_cron '15,30 22 * * 5';

# speak('rooms=all Remember to sign the assignment notebooks') if time_cron('30 19,21 * * 4');
