# Category=Timed Events

&pa_sleep_mode('kids', 1) if time_cron '* 21 * * * ';

				# If in normal mode, auto-go to mute mode
if (time_cron '0 22,23,0-4 * * * ' and
    $Save{mode} eq 'normal') {
    print "db set to mute\n";
    $Save{mode_set} = 'auto';
    $Save{mode} = 'mute';
    $Save{sleeping_parents} = 1;
    $Save{sleeping_kids} = 1;
    &pa_sleep_mode('all', 1);

    $Save{heat_temp} = 64;

}
				# If in auto-went to mute mode, go to normal mode (don't mess with manually overides)
if ($Save{mode} eq 'mute' and    
    $Save{mode_set} eq 'auto' and
    (time_cron '0 8-21 * * 1-5' or
     time_cron '0 9-21 * * 0,6')) {
    $Save{mode} = 'normal';
    $Save{mode_set} = '';
    $Save{sleeping_parents} = 0;
    $Save{sleeping_kids} = 1;
    &pa_sleep_mode('all', 0);
}

#return;                         # Summertime!

&tk_entry('Wakeup Time', \$Save{wakeup_time});
&tk_radiobutton('Wakeup Time',  \$Save{wakeup_time}, ['6 am', '6:20 am', '6:40 am', '7 am', ' ']);


$Save{wakeup_time} = '6 am' unless $Save{wakeup_time};
$v_wakeup_parents = new  Voice_Cmd('Wakeup the parents');
$v_wakeup_parents-> set_info("Do not do this!  Parents like to sleep.");

#if (($Weekday and time_now("$wakeup_time - 0:01")) or
#if ((!$Holiday and time_cron('00 6 * * 1-5') and $Save{mode} ne 'offline') or 
#if ((time_cron('45 6 * * 1-5') and $Save{mode} ne 'offline') or 
#if ((time_cron('00 6 * * 1-5') and $Save{mode} ne 'offline') or 
if ((time_now($Save{wakeup_time}) and $Weekday and $Save{mode} ne 'offline') or
    said $v_wakeup_parents) {
    $Save{mode} = 'normal';
    $Save{mode_set} = '';
    $Save{sleeping_parents} = 0;
    $Save{sleeping_kids} = 0;
    &pa_sleep_mode('all', 0);
    speak "rooms=all Good morning everybody.  It is now $Time_Now on $Date_Now_Speakable.";
    speak "rooms=all The outside temperature is " . round($weather{TempOutdoor}) . " degrees";
#   speak "rooms=all The outside temperature is " . convert_k2f((state $temp_outside)/10) . "degrees";
#   speak "rooms=all Sunrise today is at $Time_Sunrise, sunset is at $Time_Sunset";
#   speak "\\house\c\data\weather_conditions.txt";
#   speak "-rooms bedroom //house/c/homepage/mail/mail.txt";

    set $left_bedroom_light ON;
    sleep 4;			# Need a way to send 2 x10 items simultaneously or get weeder to work OK.
    set $right_bedroom_light ON;

    set $TV 'power,51';
#   run "ir_cmd TV,POWER,5,1";

    &curtain_on('bedroom', OPEN) if time_greater_than("$Time_Sunrise + 0:15");

    $Save{heat_temp} = 68;

}

unless ($Save{sleeping_parents}) {
    speak $Time_Now          if time_cron '0,15,30,45 6,7,8 * * 1-5';
    run_voice_cmd  'Read the top 10 list'                      if time_cron '20 6 * * 1-5';
    run_voice_cmd  'Read the next deep thought'                if time_cron '22 6 * * 1-5';
    run_voice_cmd  'What is the next Mixed trivia question?'   if time_cron '23 6 * * 1-5';
    run_voice_cmd  'What is the trivia answer?'                if time_cron '24 6 * * 1-5';
#   set $living_curtain ON   if time_cron '0  7 * * 1-5';
#   speak "My Thought for the day: " . read_next $house_tagline if time_cron '12 7 * * 1-5';
}



