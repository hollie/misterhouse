# Category = MisterHouse

# $Date$
# $Revision$

#@ Specifies tk layout

# Position=1                    Load before any tk_widget code

# This file determines the layout of the mh Tk window

# Re-create tk widgets on startup or if this file has changed on code reload
if ( $MW and $Reload ) {

    # *** Need to loop through child windows and configure too (if !$Startup)

    # If this file has not changed, only re-create the tk widget grids
    if (    !$Startup
        and !file_change("$config_parms{code_dir_common}/tk_frames.pl")
        and !$Invalidate_Window )
    {
        print "Deleting old grid framework\n";
        $Tk_objects{grid}->destroy;
        $Tk_objects{fb2}->destroy;
        $Tk_objects{fb3}->destroy;
        $Tk_objects{fb4}->destroy;

        $Tk_objects{grid} =
          $Tk_objects{ft}->Frame->pack(qw/-side right -anchor n/);
        $Tk_objects{fb2} =
          $MW->Frame->pack(qw/-side bottom -fill both -expand 1/);
        $Tk_objects{fb3} =
          $MW->Frame->pack(qw/-side bottom -fill both -expand 1/);
        $Tk_objects{fb4} =
          $MW->Frame->pack(qw/-side bottom -fill both -expand 1/);

        # *** Put in to make window menu fonts sync with scheme change (doesn't seem to work)

        &configure_element( 'window', \$MW );

        &configure_element( 'frame', \$Tk_objects{grid} );
        &configure_element( 'frame', \$Tk_objects{fb2} );
        &configure_element( 'frame', \$Tk_objects{fb3} );
        &configure_element( 'frame', \$Tk_objects{fb4} );

    }

    # This file changed, so re-create all frames
    else {
        file_change("$config_parms{code_dir_common}/tk_frames.pl")
          if $Startup
          ; # Set file change time stamp *** Why? display_alpha doesn't do this for bitmaps

        $Invalidate_Window = 0;

        unless ($Startup) {
            print "Deleting Frames\n";
            $Tk_objects{ft}->destroy;
            $Tk_objects{fb}->destroy;
            $Tk_objects{fb2}->destroy;
            $Tk_objects{fb3}->destroy;
            $Tk_objects{fb4}->destroy;
        }
        print "Creating Frames\n";

        # Create top and bottom frames
        $Tk_objects{ft} = $MW->Frame->pack(qw/-side top -fill both -expand 1/);
        $Tk_objects{fb} = $MW->Frame->pack(qw/-side top -fill both -expand 1/);
        $Tk_objects{fb2} =
          $MW->Frame->pack(qw/-side bottom -fill both -expand 1/);
        $Tk_objects{fb3} =
          $MW->Frame->pack(qw/-side bottom -fill both -expand 1/);
        $Tk_objects{fb4} =
          $MW->Frame->pack(qw/-side bottom -fill both -expand 1/);

        &configure_element( 'frame', \$Tk_objects{ft} );
        &configure_element( 'frame', \$Tk_objects{fb} );
        &configure_element( 'frame', \$Tk_objects{fb2} );
        &configure_element( 'frame', \$Tk_objects{fb4} );

        # Create top left and tk grid frames
        $Tk_objects{ftl} =
          $Tk_objects{ft}->Frame->pack(qw/-side left -fill both -expand 1/);
        $Tk_objects{grid} =
          $Tk_objects{ft}->Frame->pack(qw/-side right -padx 5 -anchor n/);

        &configure_element( 'frame', \$Tk_objects{ftl} );
        &configure_element( 'frame', \$Tk_objects{grid} );

        # *** Why is this here???  Should be in widgets (where it is duplicated currently!)

        if ( $config_parms{tk_system_widgets} ) {

            &tk_label_new( 2, \$Tk_objects{label_time} )
              if defined $config_parms{tk_clock} and $config_parms{tk_clock};
            &tk_label_new( 2, \$Tk_objects{label_uptime_cpu} );
            &tk_label_new( 2, \$Tk_objects{label_uptime_mh} );
            &tk_label_new( 2, \$Tk_objects{label_cpu_used} );
            &tk_label_new( 2, \$Tk_objects{label_memory_used} )
              unless $Info{OS_name} =~ /Win/;    # Works for NT/2k

        }

        # Add command list to top left frame
        $Tk_objects{cmd_list} = &tk_command_list( $Tk_objects{ftl} );
        $Tk_objects{cmd_list}->pack(qw/-side top -expand 1 -fill both/);

        # *** Config parms for heights of these!

        # Add speak and log windows to bottom frame
        $Tk_objects{speak_window} = $Tk_objects{fb}->Scrolled(
            'Text',
            -height     => 3,
            -width      => 100,
            -wrap       => 'none',
            -scrollbars => 'se',
            -setgrid    => 'true'
        )->pack(qw/-side top -expand 1 -fill both/);
        $Tk_objects{speak_window}->insert( '0.0', ( join "\n", @Speak_Log ) )
          ;    # Seed with previous entries

        &configure_element( 'log', \$Tk_objects{speak_window} );

        $Tk_objects{log_window} = $Tk_objects{fb}->Scrolled(
            'Text',
            -height     => 3,
            -width      => 100,
            -wrap       => 'none',
            -scrollbars => 'osoe',
            -setgrid    => 'true'
        )->pack(qw/-side top -expand 1 -fill both/);
        $Tk_objects{log_window}->insert( '0.0', ( join "\n", @Print_Log ) )
          ;    # Seed with previous entries

        &configure_element( 'log', \$Tk_objects{log_window} );

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
