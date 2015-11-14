
# Position=1                    Load before any tk_widget code

#@ This file determines the layout of the mh Tk window

# Re-create tk widgets on startup or if this file has changed on code reload
if ( $MW and $Reload ) {

    # If this file has not changed, only re-create the tk widget grid
    if ( !$Startup and !file_change("$config_parms{code_dir}/tk_frames.pl") ) {
        print "Deleting old grid frame\n";
        $Tk_objects{grid}->destroy;
        $Tk_objects{grid} =
          $Tk_objects{fl}->Frame->pack(qw/-side left -anchor n/);
    }

    # This file changed, so re-create all frames
    else {
        file_change("$config_parms{code_dir}/tk_frames.pl")
          if $Startup;    # Set file change time stamp

        unless ($Startup) {
            print "Deleteing old tk frames\n";
            $Tk_objects{fl}->destroy;
            $Tk_objects{fr}->destroy;
        }
        print "Creating new tk frames\n";

        # Create top and bottom frames
        $Tk_objects{fl} =
          $MW->Frame->pack(qw/-side left  -fill both -expand 1/);
        $Tk_objects{fr} =
          $MW->Frame->pack(qw/-side right -fill both -expand 1/);

        # Create top left and tk grid frames
        $Tk_objects{fll} =
          $Tk_objects{fl}->Frame->pack(qw/-side left -fill both -expand 1/);
        $Tk_objects{grid} =
          $Tk_objects{fl}->Frame->pack(qw/-side left -anchor n/);

        # Add command list and msg windows to top left frame
        $Tk_objects{cmd_list} = &tk_command_list( $Tk_objects{fll} );
        $Tk_objects{cmd_list}->pack(qw/-side top -expand 1 -fill both/);

        $Tk_objects{msg_window} = $Tk_objects{fll}->Scrolled(
            'Text',
            -height     => 5,
            -width      => 30,
            -bg         => 'white',
            -wrap       => 'none',
            -scrollbars => 'se'
        )->pack(qw/-side top -expand 0 -fill both/);
        &print_msg("Started");

        # Add speak and log windows to bottom frame
        $Tk_objects{speak_window} = $Tk_objects{fr}->Scrolled(
            'Text',
            -height     => 25,
            -width      => 60,
            -bg         => 'cyan',
            -wrap       => 'none',
            -scrollbars => 'se',
            -setgrid    => 'true',
            -font       => $config_parms{tk_font}
        )->pack(qw/-side top -expand 1 -fill both/);
        $Tk_objects{speak_window}->insert( '0.0', ( join "\n", @Speak_Log ) )
          ;    # Seed with previous entries

        $Tk_objects{log_window} = $Tk_objects{fr}->Scrolled(
            'Text',
            -height     => 25,
            -width      => 60,
            -bg         => 'cyan',
            -wrap       => 'none',
            -scrollbars => 'se',
            -setgrid    => 'true',
            -font       => $config_parms{tk_font}
        )->pack(qw/-side top -expand 1 -fill both/);
        $Tk_objects{log_window}->insert( '0.0', ( join "\n", @Print_Log ) )
          ;    # Seed with previous entries

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
