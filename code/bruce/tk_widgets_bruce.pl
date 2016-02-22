
# Category=MisterHouse

#@ Specifies Tk widgets

# Position=2                    Load after tk_frames

# This file adds to the tk widget grid frame

# Re-create tk widgets on reload
if ($Reload) {

    # Note: We DO want to call Tk widgets, even without $MW, to allow
    #       web widgets with -tk 0
    if ($MW) {
        $MW->bind( '<F1>' => \&read_code );
        $MW->bind( '<F2>' => \&toggle_pause );
        $MW->bind( '<F3>' => \&sig_handler );
        $MW->bind( '<F4>' => \&toggle_debug );
        $MW->bind( '<F5>' => \&toggle_log );
    }

    &tk_mbutton( 'Help', \&help );

    &tk_button(
        'Reload (F1)', \&read_code,   'Pause (F2)', \&toggle_pause,
        ' Exit (F3) ', \&sig_handler, 'Debug (F4)', \&toggle_debug,
        'Log (F5)',    \&toggle_log
    );

    &tk_label( \$Tk_objects{label_time} );
    &tk_label( \$Tk_objects{label_uptime_cpu} );
    &tk_label( \$Tk_objects{label_uptime_mh} );
    &tk_label( \$Tk_objects{label_cpu_used} );
    &tk_label( \$Tk_objects{label_memory_used} );

    # Category=Internet
    &tk_label( \$Save{stock_data1} ) if $Run_Members{stocks};
    &tk_label( \$Save{stock_data2} ) if $Run_Members{stocks};

    # Category=Weather
    &tk_label( \$Weather{Summary} )     if $Run_Members{weather_monitor};
    &tk_label( \$Weather{SummaryWind} ) if $Run_Members{weather_monitor};
    &tk_label( \$Weather{SummaryRain} ) if $Run_Members{weather_monitor};

    # Category=Timed Events
    &tk_entry( "Sleep time", \$Loop_Sleep_Time, "Tk passes", \$Loop_Tk_Passes );

    #   &tk_entry("Sleep time", \$Loop_Sleep_Time, "Sleep count", \$config_parms{sleep_count}); ... only works on reload

    # Category=MisterHouse
    # $search_code_string is defined in mh/code/common/mh_control.pl
    &tk_entry(
        'Code Search',    $search_code_string,
        'Command Search', $search_command_string
    ) if $Run_Members{mh_control};
    &tk_entry( "Volume", $mh_volume, 'Debug flag', \$config_parms{debug} )
      if $Run_Members{mh_sound};

    # Category=Music
    &tk_entry( 'MP3 Search', \$Save{mp3_search}, 'MP3 Genre',
        \$Save{mp3_Genre} )
      if $Run_Members{mp3_playlist};

    # Category=Phone
    &tk_entry(
        'Phone Search', \$Save{phone_search},
        'Photo Search', \$Save{photo_search}
    );

    # Category=TV
    &tk_entry( 'TV search', \$Save{tv_search}, 'TV dates', \$Save{tv_days} )
      if $Run_Members{tv_info};
    &tk_entry( 'TV key', \$Save{ir_key}, 'VCR key', \$Save{vcr_key} )
      if $Run_Members{tv};

    # Category=Timed Events
    &tk_entry( 'Wakeup Time', \$Save{wakeup_time} ) if $Run_Members{wakeup};

    &tk_checkbutton(
        'Sleeping Parents', \$Save{sleeping_parents},
        'Sleeping Nick',    \$Save{sleeping_nick},
        'Sleeping Zack',    \$Save{sleeping_zack}
    );
    &tk_radiobutton( 'Wakeup Time', \$Save{wakeup_time},
        [ '6:20 am', '6:30 am', '6:40 am', '7:00 am', 'none' ] )
      if $Run_Members{wakeup};

    # Category=MisterHouse
    &tk_radiobutton(
        'Mode', \$Save{mode},
        [ 'normal', 'mute', 'offline' ],
        [ 'Normal', 'Mute', 'Offline' ]
    );

    #    &tk_radiobutton('VR Mode',  \$tk_vr_mode, ['awake', 'asleep', 'off'], ['Awake', 'Asleep', 'Off']) if $Run_Members{viavoice_control};

    # Category=HVAC
    &tk_entry( 'Heat Temp', \$Save{heat_temp} )
      if $Run_Members{weather_monitor};

    #   &tk_radiobutton('Heat Temp', \$Save{heat_temp}, [66, 68, 69, 70, 71]) if $Run_Members{weather_monitor};
    my $tk_heat_cool = $Tk_objects{grid}->

      #     Scale(-label        => 'Heat',
      Scale(
        -width        => '10',
        -length       => '500',
        -from         => '60',
        -to           => '75',
        -showvalue    => '1',
        -tickinterval => '1',
        -orient       => 'horizontal',
        -variable     => \$Save{heat_temp}
      );
    $tk_heat_cool->grid(qw/-columnspan 5 -sticky w/);

    # Category=Internet
    &tk_radiobutton(
        'Ping Test',
        \$Save{ping_test_flag},
        [ 1,    0 ],
        [ 'On', 'Off' ]
    ) if $Run_Members{internet_connect_check};

    &tk_radiobutton( 'Check email', \$Save{email_check}, [ 'no', 'yes' ] )
      if $Run_Members{internet_mail};
    &tk_radiobutton(
        'Internet Speak',
        \$config_parms{internet_speak_flag},
        [ 'none', 'local', 'some', 'all' ]
    ) if $Run_Members{speak_server};

    # Category=GPS tracking
    if ( $Run_Members{tracking_aprs} ) {
        &tk_radiobutton(
            'APRS Speak',
            \$config_parms{tracking_speakflag},
            [ 'none', 'family', 'GPS', 'WX', 'all' ]
        );
        &tk_radiobutton(
            'APRS Print',
            \$config_parms{tracking_printflag},
            [ 'none', 'family', 'GPS', 'WX', 'all' ]
        );
    }

    # Category=MisterHouse
    &tk_radiobutton( 'X10 errata', \$config_parms{x10_errata}, [ 1, 2, 3, 4 ] );
    &tk_radiobutton(
        'Web format',
        \$config_parms{web_format},
        [ 'default', 1, 2 ]
    );

}

# Debug
&tk_entry( 'Disable (1->14)', \$Disable, 'Run Command', $run_command );
