# Category=MisterHouse

$v_reload_code = new Voice_Cmd("{Reload,re load} code");
if ( said $v_reload_code) {
    read_code();

    #   set $digital_read_port_c;	# No need to reset anymore ... data is saved in -saved_states
}

$v_set_password = new Voice_Cmd("Set the password");
if ( said $v_set_password) {
    @ARGV = ();
    do "$Pgm_PathU/set_password";
}

$v_uptime = new Voice_Cmd( "What is your up time?", 0 );
if ( said $v_uptime) {
    my $uptime_pgm = &time_diff( $Time_Startup_time, time );
    my $uptime_computer = &time_diff( $Time_Boot_time, (get_tickcount) / 1000 );

    #   speak("I was started on $Time_Startup\n");
    speak(
        "I was started $uptime_pgm ago. The computer was booted $uptime_computer ago."
    );
}

$v_reboot = new Voice_Cmd("Reboot the computer");
if ( said $v_reboot and $OS_win ) {
    speak("The house computer will reboot in 5 minutes.");
    Win32::InitiateSystemShutdown( 'HOUSE', 'Rebooting in 5 minutes',
        300, 1, 1 );
}

# Another way might be to run the following:
#http://support.microsoft.com/support/kb/articles/q234/2/16.asp
#rundll32.exe shell32.dll,SHExitWindowsEx 6
#0 - LOGOGG
#1 - SHUTDOWN
#2 - REBOOT
#4 - FORCE
#8 - POWEROFF

$v_reboot_abort = new Voice_Cmd("Abort the reboot");
if ( said $v_reboot_abort and $OS_win ) {
    Win32::AbortSystemShutdown('HOUSE');
    speak("OK, the reboot has been aborted.");
}

$v_debug = new Voice_Cmd("Turn debug [on,off]");
if ( $state = said $v_debug) {
    $config_parms{debug} = ( $state eq ON ) ? 1 : 0;
    speak "Debug has been turned $state";
}

$v_mode = new Voice_Cmd("Put house in [normal,mute,offline] mode");
if ( $state = said $v_mode) {
    $Save{mode} = $state;
    speak "The house is now in $state mode.";
    print_log "The house is now in $state mode.";
}

$mh_mode = new Serial_Item( 'XPG', 'toggle' );
if ( 'toggle' eq state_now $mh_mode) {
    if ( $Save{mode} eq 'mute' ) {
        $Save{mode} = 'offline';
    }
    elsif ( $Save{mode} eq 'offline' ) {
        $Save{mode} = 'normal';
    }
    else {
        $Save{mode} = 'mute';
    }

    # mode => force cause speech even in mute or offline mode
    &speak(
        mode => 'unmuted',
        text => "MisterHouse is set to $Save{mode} mode"
    );
}

# Search for strings in user code
&tk_entry( 'Code Search', \$Save{mh_code_search} );
if ( my $string = quotemeta $Tk_results{'Code Search'} ) {
    undef $Tk_results{'Code Search'};
    print "Searching for code $string";
    my ( $results, $count, %files );
    $count = 0;
    for my $file ( sort keys %User_Code ) {
        my $n = 0;
        for ( @{ $User_Code{$file} } ) {
            $n++;
            if (/$string/i) {
                $count++;
                $results .= "\nFile: $file:\n------------------------------\n"
                  unless $files{$file}++;
                $results .= sprintf( "%4d: %s", $n, $_ );
            }
        }
    }
    print_log "Found $count matches";
    $results = "Found $count matches\n" . $results;
    display $results, 60, 'Code Search Results', 'fixed' if $count;
}

# Create a list by X10 Addresses
$v_list_x10_Items = new Voice_Cmd 'List {X 10,X10} items';
if ( said $v_list_x10_Items) {
    print_log "Listing X10 items";
    my @object_list = &list_objects_by_type('X10_Item');
    my @objects = map { &get_object_by_name($_) } @object_list;
    my $results;
    for my $object ( sort { $a->{x10_id} cmp $b->{x10_id} } @objects ) {
        $results .= sprintf(
            "Address:%-2s  File:%-15s  Object:%s\n",
            substr( $object->{x10_id}, 1 ),
            $object->{filename}, $object->{object_name}
        );
    }
    display $results, 60, 'X10 Items', 'fixed';
}

# Create a list by Serial States
$v_list_serial_Items = new Voice_Cmd 'List serial items';
if ( said $v_list_serial_Items) {
    print_log "Listing serial items";
    my @object_list = &list_objects_by_type('Serial_Item');
    my @objects = map { &get_object_by_name($_) } @object_list;
    my $results;

    # Sort object by the first id
    for my $object (
        sort {
            my $a_state = $$a{states}->[0];
            my $b_state = $$b{states}->[0];
            $$a{id_by_state}{$a_state} cmp $$b{id_by_state}{$b_state};
        } @objects
      )
    {

        my ( $first_state, $states );
        for my $state ( @{ $$object{states} } ) {
            $first_state = $$object{id_by_state}{$state} unless $first_state;
            $states .= "$$object{id_by_state}{$state}=$state, ";
        }
        $results .= sprintf( "ID:%-5s File:%-15s Object:%-15s states: %s\n",
            $first_state, $object->{filename}, $object->{object_name},
            $states );
    }
    display $results, 60, 'Serial Items', 'fixed';
}
