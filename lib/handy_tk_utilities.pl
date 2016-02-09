
=head1 B<handy_tk_utilities>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<>

=head2 METHODS

=over

=cut

sub tk_toolbar_add_button {
    my ( $tb, $p_button ) = @_;

    my $text    = $p_button->{text};
    my $tip     = $p_button->{tip};
    my $image   = $p_button->{image};
    my $command = $p_button->{command};

    $tip = $text unless $tip;

    my $button = $tb->ToolButton(
        -text    => $text,
        -tip     => $tip,
        -image   => $image,
        -command => $command
    );

    &configure_element( 'button', \$button );
    return $button;
}

sub tk_setup_geometry {

    # Allow geometry resizing on reload, but only if it has changed,
    # so we don't mess up manual changes.
    if (
        $config_parms{tk_geometry}
        and (  $Startup
            or $config_parms{tk_geometry} ne
            $config_parms{tk_geometry_startup} )
      )
    {
        print "Setting geometry to $config_parms{tk_geometry}\n";
        $MW->geometry( $config_parms{tk_geometry} );
        $config_parms{tk_geometry_startup} = $config_parms{tk_geometry};
    }
}

sub tk_setup_cascade_menus {

    if ( $config_parms{tk_commands} ) {

        print "Creating Command menu\n";
        $Tk_objects{menu_commands}->menu->delete( 0, 'end' ); # Delete old menus

        for my $category ( &list_code_webnames('Voice_Cmd') ) {

            next if $category =~ /^none$/;

            # We must delete old ones first, otherwise we get a memory leak!
            $Tk_objects{menu_command_by_cat}{$category}->delete( 0, 'end' )
              if $Tk_objects{menu_command_by_cat}{$category};
            delete $Tk_objects{menu_command_by_cat}{$category};

            for my $cmd ( &list_objects_by_webname($category) ) {
                my $object = &get_object_by_name($cmd);
                my $text   = $object->{text};

                next unless $text;    # Only do voice items
                next if $$object{hidden};

                # Create category menu ... now that we know it will have entries!
                unless ( $Tk_objects{menu_command_by_cat}{$category} ) {
                    $Tk_objects{menu_command_by_cat}{$category} =
                      $Tk_objects{menu_commands}->menu->Menu;
                    &tk_cascade_entry(
                        $category,
                        $Tk_objects{menu_commands},
                        $Tk_objects{menu_command_by_cat}{$category}
                    );
                }

                #                $Tk_objects{menu_command_by_cat}{$category}->
                #                    add('command', -label => 'state_log', command => sub{display join("\n", state_log $object)});

                my $filename = $object->{filename};

                # Drop the {a,b,c} enumeration (pick the first one)
                $text = $1 . $2 . $3 if $text =~ /^(.*)\{(.*),.*\}(.*)/;

                $filename =~ s/_/\x20/g;
                $filename =~ ucfirst($filename);

                if ( my ( $prefix, $states, $suffix ) =
                    $text =~ /^(.*)\[(.+?)\](.*)$/ )
                {
                    for my $state ( split( ',', $states ) ) {
                        my $text2 = "$prefix$state$suffix";
                        my $text3 = "$filename: $text2";
                        $Tk_objects{menu_command_by_cat}{$category}->add(
                            'command',
                            -label => $text3,
                            -command =>
                              sub { &run_voice_cmd( $text2, undef, 'tk' ) }
                        );
                    }
                }
                else {
                    my $text3 = "$filename: $text";
                    $Tk_objects{menu_command_by_cat}{$category}->add(
                        'command',
                        -label   => $text3,
                        -command => sub { &run_voice_cmd( $text, undef, 'tk' ) }
                    );
                }
            }
        }
    }

    if ( $config_parms{tk_items} ) {
        print "Creating Items menu\n";

        # Create/Reset Item cascade menu
        $Tk_objects{menu_items}->menu->delete( 0, 'end' );    # Delete old menus
        $Tk_objects{menu_items}->command(
            -label   => 'Add or Remove Items...',
            -command => \&add_remove_items
        );

        # Timers do not have @states (only state), so can not be included
        #       for my $object_type ('Serial_Item', 'X10_Item', 'X10_Appliance', 'iButton', 'Compool_Item', 'Group') {
        for my $object_type (@Object_Types) {

            my @object_list = &list_objects_by_type($object_type);
            my @objects = map { &get_object_by_name($_) } @object_list;

            # See if any of these objects have states ... if not skip menu entry
            my $flag = 0;
            for my $object (@objects) {
                if ( &tk_object_states( $object, 'menu_items' ) ) {
                    $flag = 1;
                    last;
                }
            }
            next unless $flag;

            # We must delete old ones first, otherwise we get a memory leak!
            $Tk_objects{menu_items_by_type}{$object_type}->delete( 0, 'end' )
              if $Tk_objects{menu_items_by_type}{$object_type};

            $Tk_objects{menu_items_by_type}{$object_type} =
              $Tk_objects{menu_items}->menu->Menu;

            &configure_element( 'window',
                \$Tk_objects{menu_items_by_type}{$object_type} );
            &tk_cascade_entry( $object_type, $Tk_objects{menu_items},
                $Tk_objects{menu_items_by_type}{$object_type} );

            # Sort by filename first, then object name
            for my $object (
                sort {
                         $a->{filename} cmp $b->{filename}
                      or $a->{object_name} cmp $b->{object_name}
                } @objects
              )
            {

                next if $$object{hidden};

                # We must delete old ones first, otherwise we get a memory leak!
                #  - this one does not help!  Still leaks about .3 mb per reload with 40 or so items :(
                # *** How is this one special?

                $Tk_objects{menu_items_by_object}{$object}->delete( 0, 'end' )
                  if $Tk_objects{menu_items_by_object}{$object};

                # Only list items with NON-BLANK states
                if ( my $menu = &tk_object_states( $object, 'menu_items' ) ) {
                    $Tk_objects{menu_items_by_object}{$object} = $menu;
                    my $filename = $object->{filename};
                    $filename =~ s/_/ /g;
                    $filename = ucfirst($filename);

                    # *** This should be another cascade!
                    my $object_name = "$filename: "
                      . &pretty_object_name( $object->{object_name} );
                    &tk_cascade_entry(
                        $object_name,
                        $Tk_objects{menu_items_by_type}{$object_type},
                        $Tk_objects{menu_items_by_object}{$object}
                    );
                }
            }
        }
    }

    # Create/Reset Group cascade menu
    if ( $config_parms{tk_groups} ) {
        print "Creating Groups menu\n";

        # Don't create if no groups!

        my @list = &list_objects_by_type('Group');

        if ( $#list != -1 ) {

            $Tk_objects{menu_groups} = $Tk_objects{menu_bar}->Menubutton(
                -text        => 'Groups',
                -borderwidth => 2,
                -underline   => 0
              )->pack( -side => 'left', -padx => 0 )
              unless $Tk_objects{menu_groups};

            $Tk_objects{menu_groups}->menu->delete( 0, 'end' )
              ;    # Delete old menus

            for my $group_name ( &list_objects_by_type('Group') ) {
                my $group = &get_object_by_name($group_name);
                next unless $group;
                next if $$group{hidden};
                $group_name = &pretty_object_name($group_name);

                $Tk_objects{menu_groups_by_group}{$group} =
                  $Tk_objects{menu_groups}->menu->Menu;

                &configure_element( 'window',
                    \$Tk_objects{menu_groups_by_group}{$group} );

                &tk_cascade_entry(
                    $group_name,
                    $Tk_objects{menu_groups},
                    $Tk_objects{menu_groups_by_group}{$group}
                );

                # Add an entry for the group
                &tk_object_states( $group, 'menu_groups',
                    $Tk_objects{menu_groups_by_group}{$group} );

                # Sort by filename first, then object name
                for my $object (
                    sort {
                             $a->{filename} cmp $b->{filename}
                          or $a->{object_name} cmp $b->{object_name}
                    } list $group)
                {
                    next if $$object{hidden};
                    if ( my $menu =
                        &tk_object_states( $object, 'menu_groups' ) )
                    {
                        $Tk_objects{menu_items_by_object}{$object} = $menu;
                        my $filename    = $object->{filename};
                        my $object_name = "$filename: "
                          . &pretty_object_name( $object->{object_name} );
                        &tk_cascade_entry( $object_name,
                            $Tk_objects{menu_groups_by_group}{$group}, $menu );
                    }
                }
            }
        }

    }

    # Check for leaking memory on $Reload, where we re-build menus
    #   my $mem = `ps -F \"%z\" -p $$ | tail -1`;
    #   chomp $mem;
    #   print "Memory used: $mem,  Memory delta:", $mem - $memory_prev, "\n";
    #   $memory_prev = $mem;

}

sub tk_object_states {
    my ( $object, $menu_parent, $menu ) = @_;

    return
      unless $object
      ;    # *** Looks like a warning needed here (for calling code's developer)

    # Already have this object's menu created
    return $Tk_objects{menu_items_by_object}{$object}
      if !$menu
      and $Tk_objects{menu_items_by_object}{$object}
      ;    # Already have this object's menu created

    return unless $object->{states}; # Only create menus for objects with states
    my @states      = @{ $object->{states} };
    my $object_type = ref $object;

    # *** NO! Groups have dynamically aggregated states assigned on reload. &aggregate_states needs to be in this script! Where is it in the SVN version?

    @states = split ',', $config_parms{x10_menu_states}
      if $object_type eq 'X10_Item'
      or $object_type eq 'Group';
    return unless $states[0];

    $menu = $Tk_objects{$menu_parent}->menu->Menu
      unless $menu;                  # Create a new menu unless given
    $menu->add(
        'command',
        -label   => 'Log',
        -command => sub { display join( "\n", state_log $object) }
    );
    for my $state (@states) {
        next if $state =~ /^[+-]\d+$/ and $state % 20;
        $menu->add(
            'command',
            -label   => $state,
            -command => sub { set $object $state, 'tk' }
        );
    }
    return $menu;
}

sub tk_cascade_entry {
    my ( $label, $menu1, $menu2 ) = @_;

    $label =~ s/_/ /g;

    $menu1->cascade( -label => $label );
    $menu1->entryconfigure( $label, -menu => $menu2 );
}

=item C<tk_button>

=item C<tk_mbutton>

Use these functions to add a Tk button widget to the mh tk grid (tk_button) or the tk menu_bar (tk_mbutton).
&tk_button will accept multiple variables, displaying them in a row in the grid.

Usage:

  &tk_mbutton('Button Name', \&subroutine);
  &tk_button('Button1', \&sub1);
  &tk_button('Button1', \&sub1, 'Button2', \&sub2,'Button3', \&sub3);

Examples:

  &tk_mbutton('Help', \&help);
  &tk_button('Reload(F1)', \&read_code, 'Pause (F2)', \&pause,
             ' Exit (F3) ', \&sig_handler, 'Debug(F4)',  \&toggle_debug,
             'Log(F5)', \&toggle_log);

=cut

# Create tk widget subroutines
sub tk_button {
    return unless $MW and $Reload and $Tk_objects{grid};
    my (@data) = @_;
    my @widgets;
    while (@data) {
        my $label = shift @data;
        my $pvar  = shift @data;
        $Tk_objects{button}{$pvar}->destroy
          if $Tk_objects{button}{$pvar}
          and Exists( $Tk_objects{button}{$pvar} );
        $Tk_objects{button}{$pvar} =
          $Tk_objects{grid}->Button( -text => $label, -command => $pvar );
        push( @widgets, $Tk_objects{button}{$pvar} );
    }
    if ( @widgets > 3 ) {
        $widgets[0]->grid( @widgets[ 1 .. $#widgets ], -sticky => 'w' );
    }
    elsif ( @widgets > 1 ) {
        $widgets[0]->grid(
            @widgets[ 1 .. $#widgets ],
            -columnspan => 2,
            -sticky     => 'w'
        );
    }
    else {
        $widgets[0]->grid(qw/-columnspan 5 -sticky w/);
    }
}

# Button for the menubar
sub tk_mbutton {
    return unless $MW and $Reload and $Tk_objects{grid};
    my ( $label, $pvar ) = @_;
    $Tk_objects{mbutton}{$pvar}->destroy
      if $Tk_objects{mbutton}{$pvar} and Exists( $Tk_objects{mbutton}{$pvar} );
    $Tk_objects{mbutton}{$pvar} =
      $Tk_objects{menu_bar}->Button( -text => $label, -command => $pvar )
      ->pack(qw/-side right/);
}

=item C<tk_checkbutton>

tk_checkbutton adds a Tk checkbutton widget to the mh tk grid.
It will accept multiple variables, displaying them in a row in the grid.

Usage:

  &tk_checkbutton('text',  \&var1);
  &tk_checkbutton('test1', \&var1, 'text22', \&var22, 'text3', \&var33);

Examples:

  &tk_checkbutton('Debug on', \$config_parms{debug});
  &tk_checkbutton('Sleeping Parents', \$Save{sleeping_parents},
                  'Sleeping Kids', \$Save{sleeping_kids});

=cut

sub tk_checkbutton {
    return unless $Reload;

    # Allow web widgets, even with -no_tk
    push( @Tk_widgets, [ $Category, 'checkbutton', @_ ] );

    return unless $MW and $Tk_objects{grid};
    my @data = @_;
    my @widgets;
    while (@data) {
        my $label = shift @data;
        my $pvar  = shift @data;
        $Tk_objects{checkbutton}{$pvar}->destroy
          if $Tk_objects{checkbutton}{$pvar}
          and Exists( $Tk_objects{checkbutton}{$pvar} );
        $Tk_objects{checkbutton}{$pvar} =
          $Tk_objects{grid}->Checkbutton( -text => $label, -variable => $pvar );

        &configure_element( 'label', \$Tk_objects{checkbutton}{$pvar} );
        push( @widgets, $Tk_objects{checkbutton}{$pvar} );
    }
    if ( @widgets > 3 ) {
        $widgets[0]->grid( @widgets[ 1 .. $#widgets ], -sticky => 's' );
    }
    elsif ( @widgets > 1 ) {
        $widgets[0]->grid(
            @widgets[ 1 .. $#widgets ],
            -columnspan => 2,
            -sticky     => 's'
        );
    }
    else {
        $widgets[0]->grid(qw/-columnspan 2 -sticky w/);
    }
}

sub tk_command_list {
    my ($parent) = @_;

    my $list = $parent->Scrolled(
        qw/Tree -separator : -exportselection 1 -scrollbars osoe /);
    &configure_element( 'edit', \$list );

    # These 2 commands give a 'can not find delegate.pl' msg on tk 8.020 (ok on 8.015).
    #   $list->Label(text => "Command or Search String")->pack(-side => 'top', -fill => 'x');
    #   $Tk_objects{command} = $list->Entry(-width => 20, -borderwidth => 4)->pack(-side => 'top', -fill => 'both');

    my $f = $parent->Frame->pack( -side => 'top', -fill => 'x' );

    #    $f->Label(-text => "Command or Search:")->pack(-side => 'left', -fill => 'x');
    $Tk_objects{command} =
      $f->BrowseEntry( -width => 20 )
      ->pack( -side => 'left', -fill => 'x', -expand => 1 );

    #    $Tk_objects{command}->Subwidget('entry')->configure(-bg => 'white');

    # *** Need execute_tk_command sub (looks at textbox)

    $Tk_objects{command}
      ->configure( -command => sub { print "testing browseentry @_"; } );

    my $entry = $Tk_objects{command}->Subwidget('entry');
    &configure_element( 'edit', \$entry );

    # *** Errored (?!);

    #	my $list = $Tk_objects{command}->Subwidget("slistbox")->Subwidget("listbox");
    #	&configure_element('edit', \$list);

    #$list->insert(0, &list_voice_cmds_match($config_parms{tk_startup_cmd})); # Init with all commands *** Need to persist the last command search!

    my @cmds = &list_voice_cmds_match( $config_parms{tk_startup_cmd} );

    my $last_cat = '';

    for (@cmds) {
        my $cat = ( split( /:/, $_ ) )[0];
        if ( $last_cat ne $cat ) {
            $list->add(
                $cat,
                -text  => $cat,
                -image => $list->Getimage("folder")
            );
            $last_cat = $cat;
        }
        my $text = ( split( /:/, $_ ) )[-1];
        $list->add( $_, -text => $text, -image => $list->Getimage("file") );
    }

    # *** Check if leaf node!

    $list->configure(
        -command => sub {
            my $cmd = "@_";
            if ( $cmd =~ /^(.*?): / ) {
                $cmd =~ s/^(.*?): //;
                $Tk_objects{command}->Subwidget('entry')
                  ->configure( -text => $cmd );
                &process_external_command( $cmd, 0, 'tk' );
            }
        }
    );

    $list->autosetmode();

    #$list->bind('<Double-1>' => sub{
    #   $list->selectionClear(0, 'end');
    #    my ($file, $cmd) = $_[0]->get('active') =~ /(.+)\: *(.+)/;
    #    &run_voice_cmd($cmd, undef, 'tk');
    #});

    $Tk_objects{command}->bind(
        '<Return>',
        sub {
            my $cmd = $Tk_objects{command}->Subwidget('entry')->get();

            #my $cmd = $Tk_objects{command}->cget('-text');
            unless ( &process_external_command( $cmd, 0, 'tk' ) ) {

                # No exact match ... create a list of commands that kind of match
                $last_cat = undef;
                $list->delete('all');
                my @cmds = &list_voice_cmds_match($cmd);
                print_log "No matching commands found for $cmd" unless @cmds;

                for (@cmds) {
                    my $cat = ( split( /:/, $_ ) )[0];
                    if ( $last_cat ne $cat ) {
                        $list->add(
                            $cat,
                            -text  => $cat,
                            -image => $list->Getimage("folder")
                        );
                        $last_cat = $cat;
                    }
                    my $text = ( split( /:/, $_ ) )[-1];
                    $list->add(
                        $_,
                        -text  => $text,
                        -image => $list->Getimage("file")
                    );
                }

                $list->autosetmode();
            }
            $Tk_objects{command}->insert( 'end', $cmd )
              ;    # add to MRU (*** check if there already, move to top)
        }
    );
    return $list;
}

sub tk_scalebar {
    return
      unless $Reload
      and $Tk_objects{grid}
      ; # a crutch for ailing code that creates widgets at the wrong time (better to let them break!)
    my $tk;
    my ( $pvar, $col, $label, $from, $to, $row, $show_label ) = @_;

    $from       = 0   unless defined $from;
    $to         = 100 unless defined $to;
    $row        = 0   unless defined $row;
    $show_label = 1   unless defined $show_label;

    if ( ref $pvar ne 'SCALAR' ) {

        $tk = $Tk_objects{grid}->Scale(
            -from        => $from,
            -to          => $to,
            -label       => $label,
            -width       => '10',
            -length      => '80',
            -showvalue   => '1',
            -borderwidth => '0',
            -relief      => 'sunken',
            -orient      => 'horizontal',
            -variable    => \$$pvar->{state},
            -command     => sub {
                $Tk_results{$label} = $$pvar->{state};
                $$pvar->set( $$pvar->{state}, 'tk' );
            }
        );

    }
    else {

        $tk = $Tk_objects{grid}->Scale(
            -from        => $from,
            -to          => $to,
            -label       => $label,
            -width       => '10',
            -length      => '80',
            -showvalue   => '1',
            -borderwidth => '0',
            -relief      => 'sunken',
            -orient      => 'horizontal',
            -variable    => \$$pvar
        );

    }

    &configure_element( 'scale', \$tk );

    $tk->grid( -row => $row, -column => $col );
    return $tk;
}

=item C<tk_entry>

Use this function to allow for arbitrary data to be entered via the mh tk grid.

Usage:

  &tk_entry('Entry label:', $state_based_object);
  &tk_entry('Entry label:', \$variable);
  &tk_entry('Entry label:', \$variable, 'Entry label2:, \$variable2);

Example:

  &tk_entry('Sleep time:', \$Loop_Sleep_Time);
  &tk_entry('Test in 1', \$Save{test_input1}, 'Test in 2', \$Save{test_input2});


Note:  The $variable reflects the data, as it is being entered.  If you want to test on the data
only after the RETURN key has been hit, use %Tk_results array.
The $variable is copied to $Tk_results{'Entry label:'} only after the RETURN key has been entered.

Now you can now also use a state based object (like Generic_Item) to store/monitor/change the tk_entry text.

Examples:

  &tk_entry('TV search', \$Save{tv_search});
  if ($state = $Tk_results{'TV search'}) {
     run qq[get_tv_info -times all -keys "$state"];
     set_watch $f_tv_file;
     undef $Tk_results{'TV search'};
  }

  $mp3_search_text =  new Generic_Item;
  $mp3_search_text -> tie_event('print_log "mp3 search text is now $state"');
  &tk_entry('mp3 Search', $mp3_search_text);

=cut

sub tk_entry {
    return unless $Reload;

    # Allow web widgets, even with -no_tk
    push( @Tk_widgets, [ $Category, 'entry', @_ ] );

    return unless $MW and $Tk_objects{grid};
    my @data = @_;
    my @widgets;
    for (@data) {
        my $label = shift @data;
        my $pvar  = shift @data;
        $Tk_objects{entry}{$label}->destroy
          if $Tk_objects{entry}{$label}
          and Exists( $Tk_objects{entry}{$label} );
        $Tk_objects{entry}{$pvar}->destroy
          if $Tk_objects{entry}{$pvar} and Exists( $Tk_objects{entry}{$pvar} );

        $Tk_objects{entry}{$label} =
          $Tk_objects{grid}->Label( -text => $label, -anchor => 'w' );

        #           Label(-relief => 'groove', -text => $label, -anchor => 'w',  -bg => 'white', -font => $config_parms{tk_font});

        &configure_element( 'label', \$Tk_objects{entry}{$label} );

        if ( ref $pvar ne 'SCALAR' and $pvar->can('set') ) {
            $Tk_objects{entry}{$pvar} =
              $Tk_objects{grid}
              ->Entry( -textvariable => \$$pvar{state}, -width => 12 );

            $Tk_objects{entry}{$pvar}->bind(
                '<Return>',
                sub {
                    $Tk_results{$label} = $$pvar{state};
                    $pvar->set( $$pvar{state}, 'tk' );
                }
            );
        }
        else {
            $Tk_objects{entry}{$pvar} =
              $Tk_objects{grid}->Entry( -textvariable => $pvar, -width => 12 );
            $Tk_objects{entry}{$pvar}
              ->bind( '<Return>', sub { $Tk_results{$label} = $$pvar } );
        }

        &configure_element( 'edit', \$Tk_objects{entry}{$pvar} );

        push( @widgets, $Tk_objects{entry}{$label} );
        push( @widgets, $Tk_objects{entry}{$pvar} );
    }

    #   if (@widgets > 2) {
    $widgets[0]->grid( @widgets[ 1 .. $#widgets ], -sticky => 'w' );

    #   }
    #   else {
    #       $widgets[0]->grid(@widgets[1..$#widgets], -columnspan => 2, -sticky => 'w');
    #   }

}

# One at a time now, first param is status bar frame number (1 = original, 2=sb, 3=sb row 2)

sub tk_label_new {
    return unless $Reload;
    my $frame_number = shift;
    my @data         = @_;
    my @widgets;

    # Allow web widgets, even with -no_tk
    push( @Tk_widgets, [ $Category, 'label', @_ ] );

    return unless $MW and $Tk_objects{"fb$frame_number"};
    for my $pvar (@data) {
        $Tk_objects{label}{$pvar}->destroy
          if $Tk_objects{label}{$pvar} and Exists( $Tk_objects{label}{$pvar} );

        $Tk_objects{label}{$pvar} = $Tk_objects{"fb$frame_number"}->Label(
            -relief       => 'sunken',
            -textvariable => $pvar,
            -justify      => 'center'
        );

        $Tk_objects{label}{$pvar}->pack( -fill => 'x', -expand => 1 );

        #           Label(-relief => 'sunken', -textvariable => $pvar, -anchor => 'w', -font => $font1);

        push( @widgets, $Tk_objects{label}{$pvar} );
        &configure_element( 'label', \$Tk_objects{label}{$pvar} );
    }

    #    if (@widgets > 1) {
    #       $widgets[0]->pack(qw/-side bottom -padx 5 -anchor n/);
    #    }
    #    else {
    #        $widgets[0]->grid(qw/-sticky w/);
    $widgets[0]->pack(qw/-side left -padx 2 -anchor n/);

    #    }
}

=item C<tk_label tk_mlabel>

Use these functions to add a Tk label widget to the mh tk grid (tk_label) or the tk menu_bar (tk_mlabel).
To avoid duplicate labels after a reload, pass a label name as a 2nd parm.

Usage:

  &tk_mlabel(\$variable, $label);

Example:

  &tk_mlabel(\$Save{email_flag}, 'email flag');

=cut

# *** Deprecated (labels populate status bar, not widget control pane.)

sub tk_label {
    return unless $Reload;

    # Allow web widgets, even with -no_tk
    push( @Tk_widgets, [ $Category, 'label', @_ ] );

    return unless $MW and $Tk_objects{grid};
    my @data = @_;
    my @widgets;
    for my $pvar (@data) {
        $Tk_objects{label}{$pvar}->destroy
          if $Tk_objects{label}{$pvar} and Exists( $Tk_objects{label}{$pvar} );

        # Note: Use a fixed font, so label size does not change with changing letters.
        $Tk_objects{label}{$pvar} = $Tk_objects{grid}->Label(
            -relief       => 'sunken',
            -textvariable => $pvar,
            -justify      => 'left',
            -anchor       => 'w'
        );

        #           Label(-relief => 'sunken', -textvariable => $pvar, -anchor => 'w', -font => $font1);

        &configure_element( 'log', \$Tk_objects{label}{$pvar} )
          ;    # these are log-like (need fixed-width font)

        push( @widgets, $Tk_objects{label}{$pvar} );
    }
    if ( @widgets > 1 ) {
        $widgets[0]->grid( @widgets[ 1 .. $#widgets ], -sticky => 'w' );
    }
    else {
        $widgets[0]->grid(qw/-columnspan 5 -sticky w/);
    }
}

sub configure_element {
    my $type      = shift;    # *** Check ref $$element for type of widget
    my $p_element = shift;
    my $flags     = shift;
    my $font;
    my $bgcolor;
    my $color;
    my $colors;
    my $relief;
    my $border_width;

    unless ($$p_element) {
        print "configure_element error: type=$type\n";
        return;
    }

    if ( defined $$p_element ) {

        $font   = &get_scheme_parameter( $type, 'font' );
        $color  = &get_scheme_parameter( $type, 'color' );
        $colors = &get_scheme_parameter( $type, 'colors' )
          ;    #for multi-color progress bars
        $bgcolor      = &get_scheme_parameter( $type, 'bgcolor' );
        $relief       = &get_scheme_parameter( $type, 'relief' );
        $border_width = &get_scheme_parameter( $type, 'borderwidth' );

        if ( $type eq 'window' ) {
            $$p_element->optionAdd( '*font' => $font ) if $font;
        }
        elsif ( $type ne 'toolbar' and $type ne 'progress' ) {

            # Get this error:  Can't set -font to `Times 10 bold' for Tk::Frame=HASH(0x73b0928): unknown option "-font" at C:/Perl/site/lib/Tk/Configure.pm line 46.
            #			$$p_element->configure(-font => $font) if $font;
        }
        if ( $type eq 'progress' ) {
            $$p_element->configure( -colors => [ 0, $color ] ) if $color;

            my @colors = split ',', $colors;

            $$p_element->configure(
                -colors => [
                    0,  $colors[0], 12, $colors[0], 25, $colors[1],
                    37, $colors[1], 50, $colors[2], 63, $colors[2],
                    75, $colors[3], 87, $colors[3]
                ]
              )
              if defined $colors
              and defined $flags
              and $flags;
        }
        else {
            $$p_element->configure( -bg => $bgcolor ) if $bgcolor;
        }
        if ( $type ne 'frame' and $type ne 'window' ) {
            $$p_element->configure( -relief => $relief ) if $relief;
            $$p_element->configure( -borderwidth => $border_width )
              if $border_width;
        }
    }
    else {
        warn
          "Undefined element passed to configure_element type=$type $p_element";
    }
}

sub get_scheme_parameter {
    my $type = shift; #window *** or menu, frame, edit, log, progress or toolbar
    my $parameter = shift;    #borderwidth, relief, bgcolor or font

    # *** Validate

    my $key = "tk_$parameter";
    if ( $parameter eq 'font' )
    {    # for backwards compatibility (tk_font_fixed, tk_font_menus, etc.)
            #	$key .= '_menus' if $type eq 'window' or $type eq 'frame';
        $key .= '_window' if $type eq 'window';
        $key .= '_fixed'  if $type eq 'log';
        $key .= '_edit'   if $type eq 'edit';
        $key .= '_label'
          if $type eq 'label'
          ; # *** label widget sends this or log, depending on parameter passed to it
    }
    else {
        $key .= "_$type";
    }

    my $scheme_key = $key;
    $scheme_key .= "_$config_parms{tk_scheme}" if $config_parms{tk_scheme};

    if ( exists $config_parms{$scheme_key} ) {
        return $config_parms{$scheme_key};
    }
    else {
        return ( exists $config_parms{$key} ) ? $config_parms{$key} : '';
    }

}

# Label for the menubar (not used much.)
sub tk_mlabel {
    return unless $Reload;

    push( @Tk_widgets, [ $Category, 'label', $_[0] ] );

    return unless $MW and $Tk_objects{menu_bar};
    my ( $pvar, $name ) = @_;

    # Allow for $name so we can reliably destroy on $Reload.
    # $pvar may be %Save or an object that changes on reloads :( # *** Why the frown here?  Do these not work properly?  Other labels do.
    $name = $pvar unless $name;

    # If an object, get its state
    #  - As of 2.88 (Generic_Item Tie update), object pointers don't work.  Data is not updated.
    my $pvar2 =
      ( ref $pvar ne 'SCALAR' and $pvar->can('set') ) ? \$$pvar{state} : $pvar;

    #   print "db2 testing mlabel pv=$pvar pv2=$pvar2 pv2v=$$pvar2  $Tk_objects{mlabel}{$pvar}\n";

    $Tk_objects{mlabel}{$name}->destroy()
      if $Tk_objects{mlabel}{$name} and Exists( $Tk_objects{mlabel}{$name} );
    $Tk_objects{mlabel}{$name} =
      $Tk_objects{menu_bar}
      ->Label( -relief => 'sunken', -textvariable => $pvar2 );

    &configure_element( 'edit', $Tk_objects{mlabel}{$name} );

    $Tk_objects{mlabel}{$name}->pack(qw/-side right -anchor e/);
}

=item C<tk_radiobutton>

Use this function to create radio buttons in the mh tk grid.  If labels are not specified, the values are displayed.

Usage:

  &tk_radiobutton('Button label:', $state_based_object, ['value1', 'value2', 'value3']);
  &tk_radiobutton('Button label:', \$variable, ['value1', 'value2', 'value3']);
  &tk_radiobutton('Button label:', \$variable, ['value1', 'value2', 'value3'],
                                               ['label1', 'label2', 'label3']);

Examples:

  &tk_radiobutton('Mode',  \$Save{mode}, ['normal', 'mute', 'offline']);
  &tk_radiobutton('Debug', \$config_parms{debug}, [1, 0], ['On', 'Off']);
  &tk_radiobutton('Tracking', \$config_parms{tracking_speakflag}, [0,1,2,3],
                  ['None', 'GPS', 'WX', 'All']);
  
  my $alarm_states = "Disarmed,Disarming,Arming,Armed,Violated,Exit Delay,Entry Delay";
  my @alarm_states = split ',', $alarm_states;
  $alarm_status    = new Generic_Item;
  &tk_radiobutton('Security Status', $alarm_status, [@alarm_states]);
  
  $v_alarm_status  = new Voice_Cmd "Set the alarm to [$alarm_states]";
  $v_alarm_status -> tie_items($alarm_status);
  
  print_log "Alarm status changed to $state" if $state = state_now $alarm_status;


See mh/code/examples/tk_examples.pl for more tk_*  examples.

=cut

sub tk_radiobutton {
    return unless $Reload;

    #   print "db5 Debug doing the radiobutton thing, l=@_, r=$Reload\n";

    # Allow web widgets, even with -no_tk
    push( @Tk_widgets, [ $Category, 'radiobutton', @_ ] );

    return unless $MW and $Tk_objects{grid};
    my ( $label, $pvar, $pvalue, $ptext, $callback, $widget ) = @_;
    $Tk_objects{radiobutton}{$pvar}->destroy
      if $Tk_objects{radiobutton}{$pvar}
      and Exists( $Tk_objects{radiobutton}{$pvar} );
    my @widgets;
    my @text = @$ptext
      if $ptext
      ; # Copy, so we can do shift and still have the origial $ptext array available for html widget
    for my $value (@$pvalue) {
        my $text = shift @text;
        $text = $value unless defined $text;

        # Check to see if $pvar is an object with the set method
        #  - use set if we can, so state_now works on tk changes
        if ( ref $pvar ne 'SCALAR' and $pvar->can('set') ) {
            $widget = $Tk_objects{grid}->Radiobutton(
                -text     => $text,
                -variable => \$$pvar{state},
                -value    => $value,
                -command  => sub { $pvar->set($value) }
            );
        }
        else {
            $widget = $Tk_objects{grid}->Radiobutton(
                -text     => $text,
                -variable => $pvar,
                -value    => $value
            );
        }
        push( @widgets, $widget );

        #       &configure_element('frame', $widget);
    }
    $Tk_objects{radiobutton}{$pvar} =
      $Tk_objects{grid}->Label( -text => $label )
      ->grid( @widgets, -sticky => 'w' );

    #   $Tk_objects{radiobutton}{$pvar} = $Tk_objects{grid}->Label(-text => $label);
    #   &configure_element('frame', $Tk_objects{radiobutton}{$pvar});
    #   $Tk_objects{radiobutton}{$pvar}->grid(@widgets, -sticky => 'w');
}

sub help_about {
    my $title =
      ( ( ( $config_parms{title} ) ? $config_parms{title} : "Misterhouse" ) );
    my $win = &load_child_window(
        title       => "About $title",
        text        => "$Pgm_Path/../docs/mh_logo.gif",
        wait        => 1,
        app         => 'help',
        window_name => 'about',
        buttons     => 1,
        help =>
          'This is the about box. The System Info button displays OS and program status.'
    );
    unless ( $win->{activated} ) {
        play 'about';
        my $tk;
        $tk =
          $win->{MW}{top_frame}->Label( -text => "$title $Version PID: $$" )
          ->pack(qw/-expand yes -fill both -side top/);
        &configure_element( 'label', \$tk );
        $tk =
          $win->{MW}{bottom_frame}
          ->Button( -text => "System Info...", -command => \&system_info )
          ->pack(qw/-side right/);
        &configure_element( 'button', \$tk );

        # easter egg (plays goofy WAV file)
        $win->{photo2}->bind( '<Double-1>' => sub { play 'fun/service.wav' } );

        $win->activate();
    }
}

sub tk_setup_windows {

    # See perl/bin/widget.bat for lots of examples
    print " - setting up the main window\n";
    eval { $MW = MainWindow->new(); };
    if ($@) {
        print
          " - WARN: failed to setup main window.  This may be a x-windows permissions problem,\n";
        print
          " -        a ssh forwarding problem or some other x-windows related problem.\n";
        print
          " -        You may wish to try \"wish\" to debug.  If using ssh, look into ForwardX11Trusted option\n";
        return;
    }
    $MW->withdraw;    # Hide the window until we are all set up
                      # doesn't quite work on XP :(

    #$MW->protocol('WM_DELETE_WINDOW', sub { &display("To exit, use the File->Exit pulldown\n", 5)}
    $MW->protocol( 'WM_DELETE_WINDOW', sub { &exit_pgm() } );

    # Keep startup value so we resize only if it has changed since startup.
    # and we don't mess with manual changes.
    $config_parms{tk_geometry_startup} = $config_parms{tk_geometry};

    $MW->iconname('Misterhouse'); # Loads tk icon resource
                                  # Older build gives 'bitmap not defined' error
     # $MW->iconbitmap($Pgm_Root . '/web/favicon.ico') unless $^O eq 'MSWin32' and &Win32::BuildNumber < 810;
    my $icon_image = $MW->Photo(
        -file   => "${Pgm_Root}/web/favicon.gif",
        -format => 'gif'
    );
    $MW->Icon( -image => $icon_image );

    #   $MW->optionAdd('*font' => 'systemfixed');
    #   $MW->optionAdd('*font' => $config_parms{tk_font_menus}) if $config_parms{tk_font_menus};
    &configure_element( 'window', \$MW );

    # This doesn't work :( So let's not call it! :)
    #    $MW->bind('Alt-Key-R'   => \&read_code);
    #    $MW->bind('Alt-Key-X'   => \&sig_handler);

    $MW->title(
        ( $config_parms{title} )
        ? eval "'$config_parms{title}'"
        : "Misterhouse $Version PID: $$"
    );

    # Create menu bar and top-level menus
    $Tk_objects{menu_bar} = $MW->Frame->pack(
        -anchor => 'w',
        -side   => 'top',
        -expand => 0,
        -fill   => 'x'
    );
    &configure_element( 'window', \$Tk_objects{menu_bar} );

    $Tk_objects{menu_file} = $Tk_objects{menu_bar}->Menubutton(
        -text        => 'File',
        -borderwidth => 2,
        -underline   => 0
    )->pack( -side => 'left', -padx => 0 );

    &configure_element( 'window', \$Tk_objects{menu_file} );

    $Tk_objects{menu_view} = $Tk_objects{menu_bar}->Menubutton(
        -text        => 'View',
        -borderwidth => 2,
        -underline   => 0
    )->pack( -side => 'left', -padx => 0 );

    &configure_element( 'window', \$Tk_objects{menu_view} );

    $Tk_objects{menu_view}->command(
        -label => 'in Browser',
        -command =>
          sub { &browser("http://localhost:$config_parms{http_port}") }
    );
    $Tk_objects{menu_view}->separator();

    # *** Move this (and debug options) to after loop code read (with groups, etc.)

    if ( $config_parms{tk_schemes} ) {
        $Tk_objects{menu_view_schemes} = $Tk_objects{menu_view}->menu->Menu;
        &tk_cascade_entry( 'Schemes', $Tk_objects{menu_view},
            $Tk_objects{menu_view_schemes} );

        &configure_element( 'window', \$Tk_objects{menu_view_schemes} );

        my @scheme_options;
        @scheme_options = split ',', $config_parms{tk_schemes};
        my $sub;

        for ( sort @scheme_options ) {
            $sub =
              "sub {\$Invalidate_Window = 1; my \%opts = (tk_scheme => '$_'); print 'SCHEME = $_\n';  &write_mh_opts(\\%opts,0,1); &read_code_forced()}";
            $sub = eval $sub;
            print "Error in tk_scheme eval: error=$@\n" if $@;
            $Tk_objects{menu_view_schemes}->radiobutton(
                -label     => ucfirst($_),
                -underline => 0,
                -variable  => \$config_parms{tk_scheme},
                -value     => $_,
                -command   => $sub
            );
        }

        $Tk_objects{menu_view}->separator();

    }

    if ( $config_parms{tk_commands} ) {
        $Tk_objects{menu_commands} = $Tk_objects{menu_bar}->Menubutton(
            -text        => 'Commands',
            -borderwidth => 2,
            -underline   => 0
        )->pack( -side => 'left', -padx => 0 );

        &configure_element( 'window', \$Tk_objects{menu_commands} );
    }

    $Tk_objects{menu_items} = $Tk_objects{menu_bar}->Menubutton(
        -text        => 'Items',
        -borderwidth => 2,
        -underline   => 0
      )->pack( -side => 'left', -padx => 0 )
      if $config_parms{tk_items};

    &configure_element( 'window', \$Tk_objects{menu_items} )
      if $Tk_objects{menu_items};

    $Tk_objects{menu_tools} = $Tk_objects{menu_bar}->Menubutton(
        -text        => 'Tools',
        -borderwidth => 2,
        -underline   => 0
    )->pack( -side => 'left', -padx => 0 );

    &configure_element( 'window', \$Tk_objects{menu_tools} );

    $Tk_objects{menu_tools}
      ->command( -label => 'Undo last action', -command => \&undo_last_action );

    $Tk_objects{menu_tools}
      ->command( -label => 'Triggers...', -command => \&browse_triggers );

    $Tk_objects{menu_tools}->separator();

    $Tk_objects{menu_tools_set_password} = $Tk_objects{menu_tools}->menu->Menu;

    &configure_element( 'window', \$Tk_objects{menu_tools_set_password} );

    &tk_cascade_entry( 'Set Password', $Tk_objects{menu_tools},
        $Tk_objects{menu_tools_set_password} );

    $Tk_objects{menu_tools_set_password}->command(
        -label     => 'Guest',
        -underline => 0,
        -command   => sub { &set_password('guest') }
    );
    $Tk_objects{menu_tools_set_password}->command(
        -label     => 'Family',
        -underline => 0,
        -command   => sub { &set_password('family') }
    );
    $Tk_objects{menu_tools_set_password}->command(
        -label     => 'Administrator',
        -underline => 0,
        -command   => sub { &set_password('admin') }
    );

    $Tk_objects{menu_tools}->separator;

    $Tk_objects{menu_tools}->checkbutton(
        -label    => 'Console Speech',
        -variable => \$config_parms{console_speech}
    );

    $Tk_objects{menu_tools_echoes} =
      $Tk_objects{menu_tools}->command( -label => 'Echo' )
      ;    # This is a dynamic cascade...

    $Tk_objects{menu_tools}->separator;

    $Tk_objects{menu_file}->command(
        -label     => 'Restart',
        -underline => 0,
        -command   => sub { exit_pgm(999) }
    );

    $Tk_objects{menu_file}->command(
        -label       => 'Reload',
        -accelerator => 'F1',
        -underline   => 0,
        -command     => \&read_code
    );
    $Tk_objects{menu_file}->command(
        -label     => 'Reload All',
        -underline => 0,
        -command   => \&read_code_forced
    );
    $Tk_objects{menu_file}->command(
        -label       => 'Pause',
        -accelerator => 'F2',
        -underline   => 0,
        -command     => \&toggle_pause
    );
    $Tk_objects{menu_file}->command(
        -label       => 'Log',
        -accelerator => 'F5',
        -underline   => 0,
        -command     => \&toggle_log
    );
    $Tk_objects{menu_file}->separator();

    $Tk_objects{menu_file_debug} = $Tk_objects{menu_file}->menu->Menu;

    &configure_element( 'window', \$Tk_objects{menu_file_debug} );

    &tk_cascade_entry( 'Debug', $Tk_objects{menu_file},
        $Tk_objects{menu_file_debug} );

    #Loop through debug options (should build dynamically like "list debug options"

    if ( $config_parms{debug_options} ) {

        my @debug_options;

        @debug_options = split ',', $config_parms{debug_options};

        for ( sort @debug_options ) {

            #my $cmd = "sub {\$config_parms{debug} = $_}";
            $Tk_objects{menu_file_debug}->checkbutton(
                -label     => ucfirst($_),
                -underline => 0,
                -variable  => \$Debug{$_},
                -command   => sub { $config_parms{debug} = undef }
            ) if $_ !~ /^off$/i;
        }

    }

    $Tk_objects{menu_file}->separator();
    $Tk_objects{menu_file}->command(
        -label       => 'Exit',
        -accelerator => 'F3',
        -underline   => 1,
        -command     => \&sig_handler
    );

    # *** Is an object toggle "shortcut" on the main tb now (doesn't really belong on file menu.)

    #    $Tk_objects{menu_file}->radiobutton(-label => 'Mode: Normal',  -variable => \$Save{mode}, -value => 'normal');
    #    $Tk_objects{menu_file}->radiobutton(-label => 'Mode: Mute',    -variable => \$Save{mode}, -value => 'mute');
    #    $Tk_objects{menu_file}->radiobutton(-label => 'Mode: Offline', -variable => \$Save{mode}, -value => 'offline');

}

return 1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

