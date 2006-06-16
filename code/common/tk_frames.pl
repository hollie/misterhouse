# Category = MisterHouse

#@ Specifies tk layout

# Position=1                    Load before any tk_widget code

# This file determines the layout of the mh Tk window

                                # Re-create tk widgets on startup or if this file has changed on code reload
if ($MW and $Reload) {

                                # If this file has not changed, only re-create the tk widget grid
    if (!$Startup and !file_change("$config_parms{code_dir_common}/tk_frames.pl")) {
        print "Deleting old grid framework\n";
        $Tk_objects{grid}->destroy;
        $Tk_objects{grid} = $Tk_objects{ft}->Frame->pack(qw/-side right -anchor n/); 
    }

                                # This file changed, so re-create all frames
    else {
        file_change("$config_parms{code_dir_common}/tk_frames.pl") if $Startup; # Set file change time stamp

        unless ($Startup) {
            print "Deleting old tk frames\n";
            $Tk_objects{ft}->destroy;
            $Tk_objects{fb}->destroy;
        }
        print "Creating Frames\n";

                                # Create top and bottom frames
        $Tk_objects{ft}   = $MW->Frame->pack(qw/-side top -fill both -expand 1/); 
        $Tk_objects{fb}   = $MW->Frame->pack(qw/-side top -fill both -expand 1/); 
        $Tk_objects{fb2}   = $MW->Frame->pack(qw/-side top -fill both -expand 1/); 







	

                                # Create top left and tk grid frames
        $Tk_objects{ftl}  = $Tk_objects{ft}->Frame->pack(qw/-side left -fill both -expand 1/); 
        $Tk_objects{grid} = $Tk_objects{ft}->Frame->pack(qw/-side right -padx 5 -anchor n/); 

#$Tk_objects{grid_caption}->pack(qw/-side top/);

#    &tk_label(\$Tk_objects{label_time}); # *** Yecch!  Needs a config parm or forget it
    &tk_label(\$Tk_objects{label_uptime_cpu});
    &tk_label(\$Tk_objects{label_uptime_mh});
    &tk_label(\$Tk_objects{label_cpu_used});
    &tk_label(\$Tk_objects{label_memory_used}) unless $Info{OS_name} =~ /Win/; # Works for NT/2k






                                # Add command list and msg windows to top left frame
        $Tk_objects{cmd_list} = &tk_command_list($Tk_objects{ftl});
        $Tk_objects{cmd_list}->pack(qw/-side top -expand 1 -fill both/);

#        $Tk_objects{msg_window} = $Tk_objects{ftl}->Scrolled('Text', -height=> 2, -width => 30, -bg => 'white', -wrap => 'none', -scrollbars => 'se')->pack(qw/-side top -expand 0 -fill both/);
#        &print_msg("Started");

                                # Add speak and log windows to bottom frame
        $Tk_objects{speak_window} = $Tk_objects{fb}->
            Scrolled('Text', -height => 5, -width => 40, -wrap => 'none', -scrollbars => 'se',
                     -setgrid => 'true')->
                         pack(qw/-side top -expand 1 -fill both/);
        $Tk_objects{speak_window}->insert('0.0', (join "\n", @Speak_Log)); # Seed with previous entries

        $Tk_objects{log_window} = $Tk_objects{fb}->
            Scrolled('Text', -height => 5, -width => 40, -wrap => 'none', -scrollbars => 'se',
                     -setgrid => 'true')->
                         pack(qw/-side top -expand 1 -fill both/);
        $Tk_objects{log_window}->insert('0.0', (join "\n", @Print_Log)); # Seed with previous entries




    



    }

                                # Show the window (it is hidden during statup)
    if ($Startup) {
        $MW->deiconify;
        $MW->raise;
        $MW->focusForce;
#       $MW->focus("-force"); 
#       $MW->grabGlobal;
#       $MW->grab("-global"); 
    }

}
