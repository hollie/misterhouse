# Category = Time

#@ Wakeup events

#$Save{heat_temp} = 66 if time_now '11:00 pm';
#$Save{heat_temp} = 64 if time_now '12:30 am';
#$Save{heat_temp} = 65 if time_now '8:00 am';
#$Save{heat_temp} = 67 if time_now '10 am' and $Weekend;
#$Save{heat_temp} = 68 if time_now '6 pm';

# Wake up Zack for Saturday job

#if (time_cron '0 8 * * 6' or
#    time_now '8:01 am' and $Day eq 'Sat') {
#  speak "room=zack Zack, time to wake up.  Really.   Time to wake up now.  Ok?  Ok!";
#  run_voice_cmd 'open Zacks curtains';
#}

$wakeup_bypass = new Voice_Cmd 'Skip next wakeup time';
if ( state_now $wakeup_bypass) {
    speak 'Ok, no alarm today';
}

#$config_parms{sound_volume} =  40 if time_now '11 pm';
#$config_parms{sound_volume} = 100 if time_now '7 am';

# Sleep mode
speak 'I am going to mute mode now.  Nite nite' if time_now eq '10 pm';
if ( time_cron '00 23,0-4 * * * ' ) {
    $Save{mode}             = 'mute';
    $Save{sleeping_parents} = 1;
    $Save{sleeping_nick}    = 1;
    $Save{sleeping_zack}    = 1;

    #    $Save{heat_temp} = 66;
}

# Awake mode
if ( ( time_cron '30  8-22 * * 1-5' or time_cron '0 10-22 * * 0,6' ) ) {
    $Save{mode}             = 'normal';
    $Save{sleeping_parents} = 0;
    $Save{sleeping_nick}    = 0;
    $Save{sleeping_zack}    = 0;

    #    $Save{heat_temp} = 68;
}

$Save{sleeping_parents} = 0 if time_now '11:00 am';
$Save{sleeping_nick}    = 0 if time_now '11:00 am';
$Save{sleeping_zack}    = 0 if time_now '11:00 am';

#return;                         # Summertime!

#&tk_entry('Wakeup Time', \$Save{wakeup_time});
#&tk_radiobutton('Wakeup Time',  \$Save{wakeup_time}, ['6 am', '6:20 am', '6:40 am', '7 am', ' ']);

# Allow for keypad control of wakeup time
$mh_toggle_wakeup_time = new Serial_Item( 'XPF', 'cycle' );
if ( 'cycle' eq state_now $mh_toggle_wakeup_time) {
    my $time = $Save{wakeup_time};
    $time = '6 am' unless $time;
    my ( $second, $minute, $hour ) = localtime( &my_str2time($time) + 20 * 60 );
    ( $hour = 6, $minute = 0 ) if ( $hour + $minute / 60 ) > 8;
    $Save{wakeup_time} = sprintf( "%d:%02d am", $hour, $minute );
    &speak(
        mode  => 'unmuted',
        rooms => 'bedroom',
        text  => "$Save{wakeup_time}"
    );
}

$Save{wakeup_time} = '6:00 am' unless $Save{wakeup_time};
$v_wakeup_parents = new Voice_Cmd('Wakeup the parents');
$v_wakeup_parents->set_info("Do not do this!  Parents like to sleep.");

#if (($Weekday and time_now("$wakeup_time - 0:01")) or
#if ((!$Holiday and time_cron('00 6 * * 1-5') and $Save{mode} ne 'offline') or
#if ((time_cron('45 6 * * 1-5') and $Save{mode} ne 'offline') or
#if ((time_cron('00 6 * * 1-5') and $Save{mode} ne 'offline') or
if (
    (
            time_now( $Save{wakeup_time} )
        and $Weekday
        and $Save{mode} ne 'offline'
        and $Save{wakeup_time}
        and time_greater_than('6 am')
    )
    or said $v_wakeup_parents)
{
    if ( state $wakeup_bypass) {
        print_log 'Wakeup alarm was bypassed, so no alarm today!';
        set $wakeup_bypass 0;
    }
    else {
        $Save{mode} = 'normal';

        #       $Save{sleeping_parents} = 0;
        $Save{sleeping_nick} = 0;

        #       $Save{sleeping_zack} = 0;
        speak
          "rooms=bedroom mode=unmute Good morning Parents.  It is now $Time_Now on $Date_Now_Speakable.";
        speak "rooms=bedroom mode=unmute The outside temperature is "
          . round( $Weather{TempOutdoor} )
          . " degrees";

        run_voice_cmd 'Check for school closing';

        set $left_bedroom_light ON;
        set $right_bedroom_light ON;

        #        set $TV 'power,12';
        #       set $TV 'power,51';
        #       run "ir_cmd TV,POWER,5,1";

        #       &curtain_on('bedroom', OPEN) if time_greater_than("$Time_Sunrise + 0:15");

        #        $Save{heat_temp} = 68;
    }

}

if ( $Save{wakeup_time} and $Weekday ) {

    speak $Time_Now if time_cron '0,15,30,45 6,7,8 * * 1-5';
    speak
      voice => 'next',
      text  => read_next $house_tagline
      if time_now "$Save{wakeup_time} + 11";
    run_voice_cmd 'What is the forecasted chance of rain'
      if time_now "$Save{wakeup_time} + 14";
    run_voice_cmd 'Read the top 10 list' if time_now "$Save{wakeup_time} + 17";
    run_voice_cmd 'Read the next deep thought'
      if time_now "$Save{wakeup_time} + 20";

    #    run_voice_cmd  'What is the next Random trivia question'   if time_cron '38 6 * * 1-5';
    #    run_voice_cmd  'What is the trivia answer'                 if time_cron '40 6 * * 1-5';
    #   set $living_curtain ON   if time_cron '0  7 * * 1-5';
    #   speak "My Thought for the day: " . read_next $house_tagline if time_cron '12 7 * * 1-5';

}
