# Category = MisterHouse

# $Date$
# $Revision$

#@ Core MisterHouse commands e.g. reload code, list x10 items, rotate logs,
#@ update docs.  This script also defines and lets you set the various modes.

# Reload MisterHouse
$v_reload_code = new Voice_Cmd("{Reload,re load} code");
$v_reload_code->set_info('Load mh.ini, icon, and/or code changes');
$v_reload_code->tie_event('push(@Nextpass_Actions, \&read_code)');    # noloop

# Force reload MisterHouse
$v_reload_code2 = new Voice_Cmd("Force {Reload,re load} code");
$v_reload_code2->set_info('Force a code reload of all modules');

# noloop=start
$v_reload_code2->tie_event('push(@Nextpass_Actions,\&read_code_forced)');

# noloop=stop

# Start/stop voice recognition
$v_listen = new Voice_Cmd( "[Start,Stop] listening", 0 );
$v_listen->tie_event('&handle_listen_state()');    # noloop

sub handle_listen_state() {
    my $state = state $v_listen;
    if ( $state eq 'Start' ) {
        if ( $v_listen->{set_by} =~ '^vr' ) {
            &Voice_Cmd::wait_for_command(0);
        }
        $v_listen->respond('app=control I am listening.');
    }
    else {
        &Voice_Cmd::wait_for_command('Start listening');
        $v_listen->respond('app=control I am not listening.');
    }
}

# Read and process mht files
$v_read_tables = new Voice_Cmd 'Read table files';
$v_read_tables->tie_event('&read_table_files()');    # noloop

# Set one of the passwords
$v_set_password = new Voice_Cmd("Set the [guest,family,admin] password");
$v_set_password->tie_event('&handle_set_password_state()');    # noloop

sub handle_set_password_state() {
    my $state = state $v_set_password;
    @ARGV = ( -user => $state );
    print_log "Setting $state password with: @ARGV";
    do "set_password";
    &password_read;    # Re-read new password data
}

# Display program and system uptime
$v_uptime = new Voice_Cmd( "What is your up time", 0 );
$v_uptime->set_info(
    'Check how long the comuter and MisterHouse have been running');
$v_uptime->set_authority('anyone');
$v_uptime->tie_event('&handle_uptime_state()');    # noloop

sub handle_uptime_state() {
    my $uptime_pgm      = &time_diff( $Time_Startup_time, time );
    my $uptime_computer = &time_diff( $Time_Boot_time,    $Time );
    respond("I was started $uptime_pgm ago. "
          . "The computer was booted $uptime_computer ago." );
}

# Control and monitor the http server
$v_http_control = new Voice_Cmd '[Open,Close,Restart,Check] the http server';
$v_http_control->tie_event('&handle_http_control_state()');    # noloop
$http_monitor = new Socket_Item( undef, undef,
    "$config_parms{http_server}:$config_parms{http_port}" );

sub handle_http_control_state() {
    my $state = state $v_http_control;

    #   print_log "${state}ing the http server";
    socket_open 'http'    if $state eq 'Open';
    socket_close 'http'   if $state eq 'Close';
    socket_restart 'http' if $state eq 'Restart';

    # Check the http port, so we can restart it if down.
    if ( $state eq 'Check' ) {
        unless ( start $http_monitor) {
            my $msg = "The http server $config_parms{http_server}:"
              . "$config_parms{http_port} is down.  Restarting";
            print_log $msg;
            display
              text        => "$Time_Date: $msg\n",
              time        => 0,
              window_name => 'http down log',
              append      => 'bottom';
            socket_close 'http';    # Somehow this gets it going again?
            stop $http_monitor if active $http_monitor;    # Need this?
        }
        else {
            print_log "The http server is up"
              unless get_set_by $v_http_control eq 'time';
            stop $http_monitor;
        }
    }
}
run_voice_cmd 'Check the http server', undef, 'time', 1 if new_minute 1;

# Restart MisterHouse
$v_restart_mh = new Voice_Cmd '[Restart,Exit] Mister House';
$v_restart_mh->set_info( 'Restarts/Exits Misterhouse.  This will only work if '
      . 'you start with mh/bin/mhl' )
  if !$OS_win;
$v_restart_mh->set_info('Restarts/Exits Misterhouse.') if $OS_win;
$v_restart_mh->tie_event('&restart_mh($state)');    # noloop

sub restart_mh {
    my ($command) = @_;
    my $restart = ( $command eq "Restart" ) ? 1 : 0;
    my $exit_timer = new Timer;
    print_log "MisterHouse will " . lc($command) . " in 2 seconds.";
    $exit_timer->set( 2, "&exit_pgm($restart)" );
}

# This will be abend.
# Allow for no msg on first time use where this flag is not set yet.
if (    $Startup
    and $Save{mh_exit}
    and $Save{mh_exit} ne 'normal'
    and $Save{mh_exit} ne 'restart' )
{
    # May not be "auto" at all.
    # Often it is just ran manually after the last abend.
    my $exit_condition = $Save{mh_exit};
    $exit_condition = 'unexpectedly!' if $exit_condition eq 'abend';
    display "MisterHouse restarted $exit_condition", 0;
}

# Reboot/shutdown the computer (windows only)
$v_reboot = new Voice_Cmd '[Reboot,Shut Down] the computer';
$v_reboot->set_info('Do this only if you really mean it!  Windows only');
$v_reboot->tie_event('&handle_reboot_state()');    # noloop

sub handle_reboot_state() {
    my $state = state $v_reboot;
    return unless $OS_win;
    respond "$state the computer";
    if ( $Info{OS_name} eq 'Win95' ) {
        run 'RUNDLL USER.EXE,ExitWindows';
    }

    # In theory, either of these work for Win98/WinMe
    elsif ( $Info{OS_name} eq 'WinMe' ) {
        respond "The house computer will reboot in 15 seconds";
        run 'start c:\\windows\\system\\runonce.exe -q';
        sleep 5;    # Give it a chance to get started
        &exit_pgm;
    }
    elsif ( $Info{OS_name} eq 'NT' ) {
        my $machine = $ENV{COMPUTERNAME};
        respond "The computer $machine will reboot in 1 minute.";
        my $reboot = ( $state eq 'Reboot' ) ? 1 : 0;
        Win32::InitiateSystemShutdown( $machine, 'Rebooting in 1 minute',
            60, 1, $reboot );
    }
    elsif ( $Info{OS_name} eq 'XP' ) {
        my $machine = $ENV{COMPUTERNAME};
        respond "The computer $machine will reboot in 1 minute.";
        my $reboot = ( $state =~ /^reboot$/i ) ? '-r' : '-s';

        # *** Need 60 second timer to exit program!
        run "SHUTDOWN $reboot -f -t 60";
    }
    else {
        run 'rundll32.exe shell32.dll,SHExitWindowsEx 6 ';
        sleep 5;    # Give it a chance to get started
        &exit_pgm;
    }
}

# Good info for all OSes here: http://www.robvanderwoude.com/index.html
#http://support.microsoft.com/support/kb/articles/q234/2/16.asp
#  rundll32.exe shell32.dll,SHExitWindowsEx n
#where n is one, or a combination of, the following numbers:
#0 - LOGOFF
#1 - SHUTDOWN
#2 - REBOOT
#4 - FORCE
#8 - POWEROFF
#The above options can be combined into one value to achieve different results.
#For example, to restart Windows forcefully, without querying any running
#programs, use the following command line:
#rundll32.exe shell32.dll,SHExitWindowsEx 6

# Abort a reboot that has been initiated
$v_reboot_abort = new Voice_Cmd("Abort the reboot");
$v_reboot_abort->tie_event('&handle_reboot_abort_state()');    # noloop

sub handle_reboot_abort_state() {
    return unless $OS_win;
    if ( $Info{OS_name} eq 'XP' ) {
        run "SHUTDOWN -a";
        respond "app=pc The reboot has been aborted.";
    }
    else {
        my $machine = $ENV{COMPUTERNAME};
        Win32::AbortSystemShutdown($machine);
        respond "app=pc The reboot has been aborted.";
    }
}

# Turn on selected debug options, or turn off completely
my $debug_str =
    $config_parms{debug_options}
  ? $config_parms{debug_options}
  : "X10,serial,http,misc,startup,socket,password,user_code,weather";
$v_debug = new Voice_Cmd("Set debug for [$debug_str,none]");
$v_debug->set_info('Adds the given module to the current set of debug flags');
$v_debug->tie_event('&handle_debug_state()');    # noloop

sub handle_debug_state() {
    my $state = state $v_debug;
    if ( $state eq 'none' ) {
        $config_parms{debug} = '';
        %Debug = {};
        $v_debug->respond("Debugging completely turned off");
    }
    else {
        $Debug{$state} = 1;
        &update_config_parms_debug;
        $state =~ s/_/\x20/g;
        $v_debug->respond("Debugging turned on for $state");
    }
}

# Toggle selected debug options
$v_debug_toggle = new Voice_Cmd "Toggle debug for [$debug_str]";
$v_debug_toggle->set_info(
    'Toggles what kind of debugging information is logged');
$v_debug_toggle->tie_event('&handle_debug_toggle_state()');    # noloop

sub handle_debug_toggle_state() {
    my $state = state $v_debug_toggle;
    if ( $Debug{$state} ) {
        $Debug{$state} = 0;
        &update_config_parms_debug;
        $state =~ s/_/\x20/g;
        $v_debug_toggle->respond("Debugging turned off for $state");
    }
    else {
        $Debug{$state} = 1;
        &update_config_parms_debug;
        $state =~ s/_/\x20/g;
        $v_debug_toggle->respond("Debugging turned on for $state");
    }
}

# Display currently active debug flags
$v_show_debug = new Voice_Cmd('Show debug');
$v_show_debug->set_info('Shows the currently active debug flags');
$v_show_debug->tie_event('&handle_show_debug_state()');    # noloop

sub handle_show_debug_state() {
    &update_config_parms_debug;
    if ( $config_parms{debug} eq '' ) {
        $v_show_debug->respond('There are no active debug flags');
    }
    else {
        $v_show_debug->respond(
            'The currently active debug flags are ' . $config_parms{debug} );
    }
}

sub update_config_parms_debug {
    my @currentDebugs = ();
    foreach my $key ( keys %Debug ) {
        next if $key eq 'debug_previous';
        push( @currentDebugs, $key . ':' . $Debug{$key} ) if $Debug{$key};
    }
    $config_parms{debug} = join( ';', @currentDebugs );
}

# Set the house mode
$v_mode = new Voice_Cmd("Put house in [normal,mute,offline] mode");
$v_mode->set_info( 'mute mode disables all speech and sound.  '
      . 'offline disables all serial control' );
$v_mode->tie_event('&handle_mode_state()');    # noloop

sub handle_mode_state() {
    my $state = state $v_mode;
    $Save{mode} = $state;
    set $mode_mh $state, $v_mode;
    $v_mode->respond("Setting house to $state mode.");
}

# Toggle the house mode
$v_mode_toggle = new Voice_Cmd("Toggle the house mode");
$v_mode_toggle->tie_event('&handle_mode_toggle_state()');    # noloop

sub handle_mode_toggle_state() {
    if ( $Save{mode} eq 'mute' ) {
        $Save{mode} = 'offline';
    }
    elsif ( $Save{mode} eq 'offline' ) {
        $Save{mode} = 'normal';
    }
    else {
        $Save{mode} = 'mute';
    }
    set $mode_mh $Save{mode}, $v_mode_toggle;

    # mode => unmuted cause speech even in mute or offline mode
    $v_mode_toggle->respond("mode=unmuted app=control Now in $Save{mode} mode");
}

# Allow tk and web users to search the user code for strings
# Set from web menu mh/web/ia5/house/search.shtml
$search_code_string = new Generic_Item;
$search_code_string->set_icon('mh.jpg');                                # noloop
$search_code_string->tie_event('&handle_search_code_string_state()');   # noloop

sub handle_search_code_string_state() {
    my $state = state $search_code_string;
    print "Searching for code $state\n";
    my ( $results, $count, %files );
    $count = 0;
    $state =~ s/ /.+/;    # Let 'reload code' match 'reload xyz code'
                          # quotemeta function?
    $state =~ s/\//\\\//g;
    $state =~ s/\\/\\\\/g;
    $state =~ s/\(/\\\(/g;
    $state =~ s/\)/\\\)/g;
    $state =~ s/\$/\\\$/;
    $state =~ s/\*/\\\*/g;

    for my $file ( sort keys %User_Code ) {
        my $n = 0;
        for ( @{ $User_Code{$file} } ) {
            $n++;
            if (/$state/i) {
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

# Create a list of all Voice_Cmd texts
$v_list_voice_cmds = new Voice_Cmd 'List voice commands';
$v_list_voice_cmds->set_info('Display a list of valid voice commands');
display join "\n", &Voice_Cmd::voice_items if said $v_list_voice_cmds;

# Display the info text (set via the set_info() method) of all voice commands
$v_voice_cmds_help = new Voice_Cmd 'Voice commands help';
$v_voice_cmds_help->set_info('Display help text for all voice commands');
$v_voice_cmds_help->tie_event('&handle_voice_cmds_help_state()');    # noloop

sub handle_voice_cmds_help_state() {
    my @voice_commands = &Voice_Cmd::voice_items();
    my $msg;

    foreach my $voice_command (@voice_commands) {
        my ( $category, $cmd ) = split ': ', $voice_command;
        my ( $ref, $said, $vocab_cmd ) = &Voice_Cmd::voice_item_by_text($cmd);
        $msg .= "$voice_command: $ref->{info}\n" if $ref->{info};
    }

    $v_voice_cmds_help->respond($msg);
}

# Create a list by X10 Addresses
$v_list_x10_items = new Voice_Cmd 'List {X 10,X10} items', 0;
$v_list_x10_items->set_info(
    'Generates a report fo all X10 items, sorted by device code');
$v_list_x10_items->tie_event('&handle_list_x10_items_state()');    # noloop

sub handle_list_x10_items_state() {
    print_log "Listing X10 items";
    my @object_list = (
        &list_objects_by_type('X10_Item'),
        &list_objects_by_type('X10_Appliance'),
        &list_objects_by_type('X10_Garage_Door')
    );
    my @objects = map { &get_object_by_name($_) } @object_list;
    my $results;
    for my $object ( sort { $a->{x10_id} cmp $b->{x10_id} } @objects ) {
        $results .= sprintf(
            "Address:%-2s  File:%-15s  Object:%-30s State:%s\n",
            substr( $object->{x10_id}, 1 ), $object->{filename},
            $object->{object_name}, $object->{state}
        );
    }

    #   display $results, 60, 'X10 Items', 'fixed';
    respond
      text  => $results,
      time  => 60,
      title => 'X10 Items',
      font  => 'fixed'
      if $results;
    respond 'No items found' if !$results;
}

# Create a list by Serial States
$v_list_serial_items = new Voice_Cmd 'List serial items';
$v_list_serial_items->set_info(
    'Generates a report of all Serial_Items, sorted by serial state');
$v_list_serial_items->tie_event('&handle_list_serial_items_state()');   # noloop

sub handle_list_serial_items_state() {
    print_log "Listing serial items";
    my @object_list = &list_objects_by_type('Serial_Item');
    my @objects = map { &get_object_by_name($_) } @object_list;
    my @results;

    # Sort object by the first id
    for my $object (@objects) {

        #        my ($first_id, $states);
        for my $id ( sort keys %{ $$object{state_by_id} } ) {
            push @results,
              sprintf(
                "ID:%-5s File:%-15s Object:%-15s states: %s",
                $id, $object->{filename},
                $object->{object_name},
                $$object{state_by_id}{$id}
              );

            #            $first_id = $id unless $first_id;
            #            $states .= "$id=$$object{state_by_id}{$id}, ";
        }

        #       push @results, sprintf("ID:%-5s File:%-15s Object:%-15s states: %s",
        #         $first_id, $object->{filename}, $object->{object_name}, $states);
    }
    my $results = join "\n", sort @results;

    #   display $results, 60, 'Serial Items', 'fixed';
    respond
      text  => $results,
      time  => 60,
      title => 'Serial Items',
      font  => 'fixed';
}

# Find a list of debug options code for $Debug{xyz}
$v_list_debug_options = new Voice_Cmd 'List debug options';
$v_list_debug_options->set_info( 'Generates a list of the various -debug '
      . 'options you can use to get debug errata' );
$v_list_debug_options->tie_event('&handle_list_debug_options_state()'); # noloop

sub handle_list_debug_options_state() {
    my ( %debug_options, $debug_string, $prev_index );
    my %files = &file_read_dir('../lib/');
    my @files = grep( /\.(pl|pm)$/i, values %files );
    for my $file ( 'mh', @files ) {
        print "reading $file\n";
        for ( &file_read( $file, 2 ) ) {
            $debug_options{$1}++ if /Debug\{['"]?(\S+?)['"]?\}/;
        }
    }
    print "Reading user code\n";
    for (@Sub_Code) {
        $debug_options{$1}++ if /Debug\{['"]?(\S+?)['"]?\}/;
    }
    for my $key ( sort keys %debug_options ) {
        if ( $prev_index ne substr( $key, 0, 1 ) ) {
            $prev_index = substr( $key, 0, 1 );
            $debug_string .= "\n";
        }
        $debug_string .= "$key ";
    }

    #   display "List of debug options:\n$debug_string";
    respond text => "List of debug options:\n$debug_string";
}

# Echo serial matches
&Serial_match_add_hook( \&serial_match_log ) if $Reload;

sub serial_match_log {
    my ( $ref, $state, $event ) = @_;
    return unless $event =~ /^X/;    # Echo only X10 events
    my ( $prefix, $name ) = $$ref{object_name} =~ /^(.)(.+)/g;

    # don't log a message if being generated by an X10_Item contained object
    # see lib/X10_Items for more info
    return if $prefix eq '#';
    print_log "$event: $name $state"
      if $config_parms{x10_errata} > 1 and !$$ref{no_log};
}

# Allow for keyboard control
if ($Keyboard) {
    if ( $Keyboard eq 'F1' ) {
        print "Key F1 pressed.  Reloading code\n";

        # Must be done before the user code eval
        push @Nextpass_Actions, \&read_code;
    }
    elsif ( $Keyboard eq 'F2' ) {
        print "Key F2 pressed.  Toggling pause mode.\n";
        &toggle_pause;    # Leaving pause mode is still done in mh code
    }
    elsif ( $Keyboard eq 'F3' ) {
        print "Key F3 pressed.  Exiting.\n";
        &exit_pgm;
    }
    elsif ( $Keyboard eq 'F4' ) {
        print "Key F4 pressed.  Toggling debug.\n";    # defunct
        &toggle_debug;
    }
    elsif ( $Keyboard eq 'F5' ) {
        print "Key F3 pressed.  Toggling console logging.\n";
        &toggle_log;
    }
    elsif ($Keyboard) {
        print "key press: $Keyboard\n" if $Debug{misc};
    }
}

# Monitor if web password was set or unset
speak 'app=notice Web password was just set' if $Cookies{password_was_set};
speak 'app=notice Notice, an invalid Web password was just specified'
  if $Cookies{password_was_not_set};

# Those with ups devices can set this seperatly
# Those without a CM11 ... this will not hurt any
$Power_Supply = new Generic_Item;

if ($ControlX10::CM11::POWER_RESET) {
    $ControlX10::CM11::POWER_RESET = 0;
    set $Power_Supply 'Restored';
    print_log 'CM11 power reset detected';
}

# Set back to normal 1 pass after restored
if ( state_now $Power_Supply eq 'Restored' ) {
    speak 'Power has been restored';
    set $Power_Supply 'Normal';
    display time => 0, text => "Detected a power reset";
}

# Process any backlogged X10 data
$x10_backlog_timer = new Timer;
if ($ControlX10::CM11::BACKLOG) {
    print "X10:scheduling backlog\n";
    set $x10_backlog_timer 1,
      "process_serial_data('X$ControlX10::CM11::BACKLOG',1,undef)";
    $ControlX10::CM11::BACKLOG = "";
}

# Repeat last spoken
$v_repeat_last_spoken =
  new Voice_Cmd '{Repeat your last message, What did you say}', '';
$v_repeat_last_spoken->tie_event('&handle_repeat_last_spoken_state()'); # noloop

sub handle_repeat_last_spoken_state() {
    ( $temp = $Speak_Log[0] ) =~ s/^.+?: //s;
    $temp =~ s/^I said //s;    # In case we run this more than once in a row
    $temp = lcfirst($temp);
    respond "I said $temp";
}

# Clear the web cache directory
$v_clear_cache = new Voice_Cmd 'Clear the web cache directory', '';
$v_clear_cache->set_info(
    'Delete all the auto-generated .jpg files in html_alias_cache directory');
$v_clear_cache->tie_event('&handle_clear_cache_state()');    # noloop

sub handle_clear_cache_state() {
    my $cmd = ($OS_win) ? 'del' : 'rm';
    $cmd .= " $config_parms{html_alias_cache}/*.jpg";
    $cmd .= " $config_parms{html_alias_cache}/*.wav";
    $cmd =~ s|/|\\|g if $OS_win;
    system $cmd;
    print_log "Ran: $cmd";
    respond "Web cache directory has been cleared.";
}

# Archive old logs
if ($New_Month) {
    print_log
      "Archiving old print/speak logs: $config_parms{data_dir}/logs/print.log.old";
    file_backup "$config_parms{data_dir}/logs/print.log.old", 'force';
    file_backup "$config_parms{data_dir}/logs/speak.log.old", 'force';
    file_backup "$config_parms{data_dir}/logs/error.log.old", 'force';
}

# Allow for commands to be entered via tk or web
# Set from web menu mh/web/ia5/house/search.shtml
$run_command = new Generic_Item;
$run_command->tie_event('&handle_run_command_state()');    # noloop

sub handle_run_command_state() {
    my $state  = state $run_command;
    my $set_by = get_set_by $run_command;
    print_log "Running External $set_by command: $state";
    &process_external_command( $state, 1, $set_by );
}

# Allow web users to search the code
# Set from web menu mh/web/ia5/house/search.shtml
$search_command_string = new Generic_Item;

# noloop=start
$search_command_string->tie_event('&handle_search_command_string_state()');

# noloop=stop

sub handle_search_command_string_state() {

    # this next line shouldn't be neccessary, but it is
    my $state   = state $search_command_string;
    my @match   = &phrase_match($state);
    my $results = "Matches for $state:\n";
    my $i       = 1;
    for my $cmd2 (@match) {
        $results .= " $i: $cmd2\n";
        $i++;
    }

    #    respond $results;
    $search_command_string->respond($results);
}

# Undo the last action
$v_undo_last_change = new Voice_Cmd 'Undo the last action';
$v_undo_last_change->set_info(
    'Changes the most recently changed item back to its previous state');
$v_undo_last_change->tie_event('&handle_undo_last_change_state()');    # noloop

sub handle_undo_last_change_state() {
    &undo_last_action($v_undo_last_change);
}

# Set up core MisterHouse modes like mode_mh (normal/mute/offline),
# mode_vacation (on/off), mode_security (armed/unarmed),
# mode_sleep (awake/sleeping parents/sleeping kids).
# These modes can be controlled via the modes menu.

# Grandfather in the $Save{mode} versions
$mode_mh = new Generic_Item;
$mode_mh->set_states( 'normal', 'mute', 'offline' );
$mode_mh->tie_event('&handle_mode_mh_state()');    # noloop

sub handle_mode_mh_state() {
    my $state = state $mode_mh;
    $Save{mode} = $state;
    $mode_mh->respond("mode=unmuted app=control Changed to $Save{mode} mode.");
}

$mode_security = new Generic_Item;
$mode_security->set_states( 'armed', 'unarmed' );
$mode_security->tie_event('&handle_mode_security_state()');    # noloop

sub handle_mode_security_state() {
    my $state = state $mode_security;
    $Save{security} = $state;
    $mode_security->respond("mode=unmuted app=control Security $state.");
}

$mode_occupied = new Generic_Item;
$mode_occupied->set_states( 'home', 'work', 'vacation' );

$mode_sleeping = new Generic_Item;
$mode_sleeping->set_states( 'nobody', 'parents', 'kids', 'all' );
$mode_sleeping->tie_event('&handle_mode_sleeping_state()');    # noloop

sub handle_mode_sleeping_state() {
    my $state = state $mode_sleeping;
    $Save{sleeping_parents} =
      ( $state eq 'parents' or $state eq 'all' ) ? 1 : 0;
    $Save{sleeping_kids} = ( $state eq 'kids' or $state eq 'all' ) ? 1 : 0;
    $state = ucfirst($state);
    $mode_sleeping->respond("mode=unmuted app=control $state are sleeping.");
}

# Convert any updated pod documentation to html
$v_update_docs = new Voice_Cmd "Update the Documentation";
$p_update_docs = new Process_Item "update_docs";
$v_update_docs->tie_event('start $p_update_docs');    # noloop
$v_update_docs->set_icon('mh.jpg');                   # noloop

# noloop=start
&trigger_set(
    "time_cron('5 4 * * *')",
    "run_voice_cmd 'Update the Documentation'",
    'NoExpire',
    'update the documentation'
) unless &trigger_get('update the documentation');

# noloop=stop
