
# Position=2                    Load after tk_frames

# This file adds to the tk widget grid frame

# Re-create tk widgets on reload
if ($Reload) {

    # Note: We DO want to call Tk widgets, even without $MW, to allow
    #       web widgets with -tk 0
    if ($MW) {
        $MW->bind( '<F1>' => \&read_code );
        $MW->bind( '<F2>' => \&pause );
        $MW->bind( '<F3>' => \&sig_handler );
        $MW->bind( '<F4>' => \&toggle_debug );
        $MW->bind( '<F5>' => \&toggle_log );
    }

    &tk_mbutton( 'Help', \&help );

    &tk_button(
        'Reload (F1)', \&read_code,   'Pause (F2)', \&pause,
        ' Exit (F3) ', \&sig_handler, 'Debug (F4)', \&toggle_debug,
        'Log (F5)',    \&toggle_log
    );

    &tk_label( \$Tk_objects{label_time} );
    &tk_label( \$Tk_objects{label_uptime_cpu} );
    &tk_label( \$Tk_objects{label_uptime_mh} );
    &tk_label( \$Tk_objects{label_cpu_used} );
    &tk_label( \$Tk_objects{label_cpu_loops} );

    &tk_entry( "Sleep time", \$Loop_Sleep_Time, "Tk passes", \$Loop_Tk_Passes );

    &tk_radiobutton(
        'Mode', \$Save{mode},
        [ 'normal', 'mute', 'offline' ],
        [ 'Normal', 'Mute', 'Offline' ]
    );

    #   &tk_radiobutton('Debug', \$config_parms{debug}, [1, 0], ['On', 'Off']);
    #   &tk_checkbutton('Debug on', \$config_parms{debug});
    &tk_entry( 'Debug flag', \$config_parms{debug} );

    &tk_checkbutton(
        'Sleeping Parents', \$Save{sleeping_parents},
        'Sleeping Kids',    \$Save{sleeping_kids}
    );

}
