 
# Position=2                    Load after tk_frames

# This file adds to the tk widget grid frame

                                # Re-create tk widgets on reload
if ($MW and $Reload) {

    &tk_mbutton('Help', \&help);

    &tk_button('Reload(F1)', \&read_code, 'Pause (F2)', \&pause, ' Exit (F3) ', \&sig_handler,
               'Debug(F4)', \&toggle_debug, 'Log(F5)', \&toggle_log);
    $MW->bind('<F1>' => \&read_code);
    $MW->bind('<F2>' => \&pause);
    $MW->bind('<F3>' => \&sig_handler); 
    $MW->bind('<F4>' => \&toggle_debug); 
    $MW->bind('<F5>' => \&toggle_log); 

    &tk_label(\$Tk_objects{label_time});
    &tk_label(\$Tk_objects{label_uptime_cpu});
    &tk_label(\$Tk_objects{label_uptime_mh});
    &tk_label(\$Tk_objects{label_cpu_used});
    &tk_label(\$Tk_objects{label_cpu_loops});

#    &tk_entry("Sleep time:", \$Loop_Sleep_Time);
#    &tk_entry("Tk passes:", \$Loop_Tk_Passes);

#    &tk_entry("Test data:", \$Save{test_data});

    &tk_radiobutton('Mode',  \$Save{mode}, ['normal', 'mute', 'offline'], ['Normal', 'Mute', 'Offline']);

#   &tk_radiobutton('Debug', \$config_parms{debug}, [1, 0], ['On', 'Off']);
#   &tk_checkbutton('Debug on', \$config_parms{debug});

    &tk_radiobutton('Tracking', \$config_parms{tracking_speakflag}, [0,1,2,3], ['None', 'GPS', 'WX', 'All']);

    &tk_radiobutton('Weekday Callout', \$Save{Autocall}, ['on', 'off'], ['On', 'Off']);
}
