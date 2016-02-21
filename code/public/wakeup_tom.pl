# Category=Informational

# If in normal mode, auto-go to mute mode
if ( time_cron '30 22,0-5 * * * '
    and $Save{mode} eq 'normal' )
{
    print "db set to mute\n";
    $Save{mode_set}         = 'auto';
    $Save{mode}             = 'mute';
    $Save{sleeping_parents} = 1;
    $Save{sleeping_kids}    = 1;

    #   &pa_sleep_mode('all', 1);

    # $Save{heat_temp} = 64;

}

&tk_entry( 'Wakeup Time', \$Save{wakeup_time} );
&tk_radiobutton( 'Wakeup Time', \$Save{wakeup_time},
    [ '5:50 am', '6 am', '6:20 am', '6:40 am', ' ' ] );

$Save{wakeup_time} = '5:50 am' unless $Save{wakeup_time};

#$v_wakeup_parents = new  Voice_Cmd('Wakeup the parents');
#$v_wakeup_parents-> set_info("Do not do this!  Parents like to sleep.");

# If in auto-went to mute mode, go to normal mode (don't mess with manually overides)
if (
        $Save{mode} eq 'mute'
    and $Save{mode_set} eq 'auto'
    and (  time_cron '0,15,30,45 6-21 * * 1-5'
        or time_cron '45 5 * * 1-5'
        or time_cron '0 9-21 * * 0,6' )
  )
{
    $Save{mode}             = 'normal';
    $Save{mode_set}         = '';
    $Save{sleeping_parents} = 0;
    $Save{sleeping_kids}    = 0;

    #    &pa_sleep_mode('all', 0);
}

$v_wakeup     = new Voice_Cmd('');
$timer_wakeup = new Timer;

#my @benchmark_members;
#my $benchmark_member;
#my @original_item_code;

if (
    (
            time_now( $Save{wakeup_time} )
        and $Weekday
        and $Save{mode} ne 'offline'
    )
    or time_cron('0 10 * * 0,6')
    or said $v_wakeup)
{
    # said $v_wakeup_parents) {
    $Save{mode}             = 'normal';
    $Save{mode_set}         = '';
    $Save{sleeping_parents} = 0;
    $Save{sleeping_kids}    = 0;
    my $f_weather     = "$config_parms{data_dir}/web/weather_conditions.txt";
    my $f_weather2    = "$config_parms{data_dir}/web/weather_forecast.txt";
    my $f_physics_web = new File_Item("$Pgm_Root/data/web/physics_web.txt");
    my $f_scripture2  = new File_Item("$Pgm_Root/data/remarks/praise2.txt");
    set $bedroom_light ON;
    set $bedroom_air_cleaner OFF;

    if ( time_cron('* * * * 1') ) {
        play( 'file' => "roosterc.wav" );
        speak(
            "Good morning cottage bears.  It's marvelous Monday. Time to get up."
        );
    }
    elsif ( time_cron('* * * * 2') ) {
        play( 'file' => "goodmo.wav" );
        speak(
            "Good morning cottage bears.  It's titalating Tuesday.  Time to get up."
        );
    }
    elsif ( time_cron('* * * * 3') ) {
        play( 'file' => "truman~1.wav" );
        speak("Good morning cottage bears.  It's Hump Day!.  Time to get up.");
    }
    elsif ( time_cron('* * * * 4') ) {
        play( 'file' => "reveille.wav" );
        speak(
            "Good morning cottage bears.  It's Garbage Day!.  Time to get up.");

    }
    elsif ( time_cron('* * * * 5') ) {
        play( 'file' => "btls3.wav" );
        speak(
            "Good morning cottage bears.  It's dress down day!.  Time to get up."
        );
    }
    else {
        play( 'file' => "moonstep.wav" );
        speak("Good morning cottage bears.  It's weekend.");
    }
    speak("It is $Time_Now on $Date_Now.");
    speak("Sunrise is at $Time_Sunrise and sunset is at $Time_Sunset");
    speak
      qq[The moon is $Moon{phase}, $Moon{brightness}% bright, and $Moon{age} days old];
    my $days = &time_diff( $Moon{"time_$state"}, $Time );

    #	speak qq[The next $state moon is in $days, on $Moon{$state}];
    if ( time_cron('* * * * 1-5') ) {
        speak $f_wrtv6_weather;
        speak "From the National Weather Service: ";
        speak $f_weather;
        speak $f_weather2;
        speak $f_star_citystate;
        speak $f_ap_breaking_news;
        speak $f_thisday;
        speak $f_mquote_otd;
    }
    speak "rooms=all $state, " . read_next $f_scripture2;
    speak "Have a good day.  I'll be here watching the house.";
}

if ( time_cron '* 6 * * 1-5' ) {
    set $bedroom_air_cleaner OFF;
}

if ( time_cron('45 6 * * 1-5') or time_cron('30 1 * * 0,6') ) {
    speak $f_physics_web;
}

if ( net_connect_check and time_cron '15 6 * * 1-5' ) {
    run qq[rasdial /disconnect];
    speak "Logging off the net";
}

