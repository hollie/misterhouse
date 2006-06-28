# Category = MisterHouse

#@ Adds mh widgets to the tk interface

# Position=2                    Load after tk_frames

# This file adds to the tk widget grid frame

                                # Re-create tk widgets on reload
if ($Reload) {
                                # Note: We DO want to call Tk widgets, even without $MW, to allow
                                #       web widgets with -tk 0
				#  *** Strangest thing, F3 doesn't take.  Passes through to mh_control keyboard handler.  Others don't. (?)
				# *** Menu accelerators don't work in Windows as defined (Alt+R, etc.)
    if ($MW) {
        $MW->bind('<F1>' => \&read_code);
        $MW->bind('<F2>' => \&toggle_pause);
        $MW->bind('<F3>' => \&sig_handler); 
 #       $MW->bind('<F4>' => \&toggle_debug); 
        $MW->bind('<F5>' => \&toggle_log); 
    }

#    &tk_mbutton('Help', \&help);  #On toolbar now

#$Tk_objects{grid_caption} = $Tk_objects{grid}->Label(-justify => 'center', -anchor => 'w',  -font => $config_parms{tk_font_fixed});

#$Tk_objects{grid_caption}->grid($Tk_objects{grid_caption}, -sticky => 'n');

#$Tk_objects{grid_caption}->configure(-text => 'Widgets');


#    &tk_button('Reload (F1)', \&read_code, 'Pause (F2)', \&toggle_pause, ' Exit (F3) ', \&sig_handler, 'Log (F5)', \&toggle_log);
 

use vars '$mh_volume';  # In case we don't have mh_sound (see below)


if ($Reload and $MW) {

    &tk_label_new(2, \$Tk_objects{label_time}) if defined $config_parms{tk_clock} and $config_parms{tk_clock};
    &tk_label_new(2, \$Tk_objects{label_uptime_cpu});
    &tk_label_new(2, \$Tk_objects{label_uptime_mh});
    &tk_label_new(2, \$Tk_objects{label_cpu_used});
    &tk_label_new(2, \$Tk_objects{label_memory_used}) unless $Info{OS_name} =~ /Win/; # Works for NT/2k

    #$Tk_objects{sliders}{frame}->destroy if $Tk_objects{sliders}{frame};
    #$Tk_objects{sliders}{frame} = $MW -> Frame -> pack(qw/-side bottom -fill both -expand 1/);
    $Tk_objects{sliders}{sleep}  = &tk_scalebar(\$Loop_Sleep_Time, 0, 'Sleep', 0, 200);
    $Tk_objects{sliders}{passes}  = &tk_scalebar(\$Loop_Tk_Passes, 1, 'Passes', 0, 200);

	# *** This belongs in mh_sound like the other module-specific widgets!
	# This is the wrong way to hide/show tk widgets (by disabling this common module.)
	# Need a view | widgets menu.

	$Tk_objects{sliders}{volume} = &tk_scalebar_object(\$mh_volume, 0, 'Volume') if $Run_Members{mh_sound};

	&tk_scalebar(\$config_parms{x10_errata}, 1, 'X10 Logging', 1, 4, 1);


#        &tk_entry("Volume", $mh_volume) if $Run_Members{mh_sound};    

}


sub tk_scalebar {
    my ($var, $col, $label, $from, $to, $row) = @_;

	$from = 0 unless defined $from;
	$to = 100 unless defined $to;
	$row = 0 unless defined $row;

    my $tk = $Tk_objects{grid} ->
      Scale(-from         => $from,
            -to           => $to,
            -label        => $label,
            -width        => '10',
            -length       => '80',
            -showvalue    => '1',
            -orient       => 'horizontal',
            -variable     => \$$var );
    $tk -> grid(-row => $row, -column => $col);
    return $tk;
}

sub tk_scalebar_object {
    my ($object, $col, $label) = @_;
    my $tk = $Tk_objects{grid} ->
      Scale(-from         => 0,
            -to           => 100,
            -label        => $label,
            -width        => '10',
            -length       => '80',
            -showvalue    => '1',
            -orient       => 'horizontal',
            -variable     => \$$object->{state});
    $tk -> grid(-row => 1, -column => $col);

    return $tk;
}





#    &tk_entry("Sleep Time", \$Loop_Sleep_Time);
#    &tk_entry("Passes", \$Loop_Tk_Passes);
#   &tk_entry("Sleep time", \$Loop_Sleep_Time, "Sleep count", \$config_parms{sleep_count});  ... only works on reload


                                # $search_code_string is defined in mh/code/common/mh_control.pl

    &tk_entry('MP3 Search', \$Save{mp3_search}, 'MP3 Genre', \$Save{mp3_Genre}) if $Run_Members{mp3_playlist};

#   &tk_entry('Phone Search', \$Save{phone_search}) if $Run_Members{phone};

    #&tk_entry('TV search', \$Save{tv_search}, 'TV dates', \$Save{tv_days}) if $Run_Members{tv_info};
#   &tk_entry('TV key', \$Save{ir_key}, 'VCR key', \$Save{vcr_key}) if $Run_Members{tv};

#   &tk_checkbutton('Sleeping Parents', \$Save{sleeping_parents}, 'Sleeping Kids', \$Save{sleeping_kids});

 #   &tk_radiobutton('Mode',  \$Save{mode}, ['normal', 'mute', 'offline'], ['Normal', 'Mute', 'Offline']);

#   &tk_entry('Code Search', $search_code_string,    'Debug flag', \$config_parms{debug});
    &tk_entry('Code Search', $search_code_string);

	# There is a menu for this, so most won't want this (File | Debug)
    &tk_entry('Debug flag', \$config_parms{debug}) if defined $config_parms{debug_widget} and $config_parms{debug_widget};


#   &tk_radiobutton('VR Mode',  \$tk_vr_mode, ['awake', 'asleep', 'off'], ['Awake', 'Asleep', 'Off']) if $Run_Members{viavoice_control};

#   &tk_entry      ('Heat Temp', \$Save{heat_temp})                       if $Run_Members{weather_monitor};
#   &tk_radiobutton('Heat Temp', \$Save{heat_temp}, [60, 64, 66, 68, 70]) if $Run_Members{weather_monitor};

#   &tk_radiobutton('Ping Test', \$Save{ping_test_flag}, [1,0], ['On', 'Off']) if $Run_Members{internet_connect_check};

#   &tk_radiobutton('Check email', \$Save{email_check}, ['no', 'yes']) if $Run_Members{internet_mail};

#   &tk_radiobutton('Internet Speak', \$config_parms{internet_speak_flag}, ['none', 'local', 'all']) if $Run_Members{monitor_server};

    

#   &tk_radiobutton('Wakeup Time',  \$Save{wakeup_time}, ['6 am', '6:20 am', '6:40 am', '7 am', ' ']) if $Run_Members{wakeup};
#   &tk_entry('Wakeup Time', \$Save{wakeup_time}) if $Run_Members{wakeup};






}



