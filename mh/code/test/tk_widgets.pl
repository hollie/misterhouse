# Category=MisterHouse

# Position=2                    Load after tk_frames

# This file adds to the tk widget grid frame

                                # Re-create tk widgets on reload
if ($Reload) {
                                # Note: We DO want to call Tk widgets, even without $MW, to allow
                                #       web widgets with -tk 0
    if ($MW) {
        $MW->bind('<F1>' => \&read_code);
        $MW->bind('<F2>' => \&pause);
        $MW->bind('<F3>' => \&sig_handler); 
        $MW->bind('<F4>' => \&toggle_debug); 
        $MW->bind('<F5>' => \&toggle_log); 
    }

    &tk_mbutton('Help', \&help);

    &tk_button('Reload (F1)', \&read_code, 'Pause (F2)', \&pause, ' Exit (F3) ', \&sig_handler,
               'Debug (F4)', \&toggle_debug, 'Log (F5)', \&toggle_log);
 

    &tk_label(\$Tk_objects{label_time});
    &tk_label(\$Tk_objects{label_uptime_cpu});
    &tk_label(\$Tk_objects{label_uptime_mh});
    &tk_label(\$Tk_objects{label_cpu_used});
    &tk_label(\$Tk_objects{label_memory_used}) unless $OS_win;

#   &tk_label(\$Save{stock_data1}) if $Run_Members{stocks};
#   &tk_label(\$Save{stock_data2}) if $Run_Members{stocks};

#   &tk_label(\$weather{Summary})     if $Run_Members{weather_monitor};
#   &tk_label(\$weather{SummaryWind}) if $Run_Members{weather_monitor};
#   &tk_label(\$weather{SummaryRain}) if $Run_Members{weather_monitor};

    &tk_entry("Sleep time", \$Loop_Sleep_Time, "Tk passes", \$Loop_Tk_Passes);

    &tk_entry('Code Search', \$Save{mh_code_search}, 'Debug flag', \$config_parms{debug}) if $Run_Members{mh_control};

    &tk_entry('MP3 Search', \$Save{mp3_search}, 'MP3 Genre', \$Save{mp3_Genre}) if $Run_Members{mp3_playlist};

#   &tk_entry('Phone Search', \$Save{phone_search}) if $Run_Members{phone};

    &tk_entry('TV search', \$Save{tv_search}, 'TV dates', \$Save{tv_days}) if $Run_Members{tv_info};
#   &tk_entry('TV key', \$Save{ir_key}, 'VCR key', \$Save{vcr_key}) if $Run_Members{tv};

#   &tk_checkbutton('Sleeping Parents', \$Save{sleeping_parents}, 'Sleeping Kids', \$Save{sleeping_kids});

    &tk_radiobutton('Mode',  \$Save{mode}, ['normal', 'mute', 'offline'], ['Normal', 'Mute', 'Offline']);

#   &tk_radiobutton('VR Mode',  \$tk_vr_mode, ['awake', 'asleep', 'off'], ['Awake', 'Asleep', 'Off']) if $Run_Members{viavoice_control};

#   &tk_entry      ('Heat Temp', \$Save{heat_temp})                       if $Run_Members{weather_monitor};
#   &tk_radiobutton('Heat Temp', \$Save{heat_temp}, [60, 64, 66, 68, 70]) if $Run_Members{weather_monitor};

#   &tk_radiobutton('Ping Test', \$Save{ping_test_flag}, [1,0], ['On', 'Off']) if $Run_Members{internet_connect_check};

#   &tk_radiobutton('Check email', \$Save{email_check}, ['no', 'yes']) if $Run_Members{internet_mail};

#   &tk_radiobutton('Internet Speak', \$config_parms{internet_speak_flag}, ['none', 'local', 'all']) if $Run_Members{monitor_server};

    &tk_radiobutton('X10 errata',  \$config_parms{x10_errata}, [1, 2, 3, 4]);

#   &tk_radiobutton('Wakeup Time',  \$Save{wakeup_time}, ['6 am', '6:20 am', '6:40 am', '7 am', ' ']) if $Run_Members{wakeup};
#   &tk_entry('Wakeup Time', \$Save{wakeup_time}) if $Run_Members{wakeup};

}
