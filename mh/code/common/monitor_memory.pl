# Category = MisterHouse

#@ Monitors for memory leaks 

# Monitor memory usage (unix and NT/2K only. 
# Win95/98 have no way to monitor memory :(

my $memory_leak_log = "$config_parms{data_dir}/logs/monitor_memory_leak.log";
logit $memory_leak_log, "-- Restarted --.  Perl version:  $Info{Perl_version}" if $Startup;

                                # Ignore startup memory stats
if ($Time_Uptime_Seconds > 600) {
    if (!$Info{memory_virtual_prev}) {
        $Info{memory_virtual_startup} = $Info{memory_virtual};
        $Info{memory_virtual_prev}    = $Info{memory_virtual};
        $Info{memory_virtual_time}    = $Time;
    }

    logit $memory_leak_log, '   ReLoad'     if ($Reload);

    if (new_minute 10) {
        my $memory_diff = $Info{memory_virtual} - $Info{memory_virtual_prev};
        my $memory_time = round ($Time - $Info{memory_virtual_time})/3600 if $Info{memory_virtual_time};
        if ($memory_diff > .5) {
            my $time_startup = $Time_Uptime_Seconds / 3600;
            my $memory_diff_rate  = $memory_diff / $memory_time if $memory_time;
            my $memory_diff_total = ($Info{memory_virtual} - $Info{memory_virtual_startup}) / $time_startup;
            my $msg = sprintf "%5.1f hours:  %4.1f MB in %4.1f hours.  %5.1f -> %5.1f at %5.2f MB/hour.  Total: %5.2f MB/hour", 
              $time_startup, $memory_diff, $memory_time, $Info{memory_virtual_prev}, $Info{memory_virtual},
                $memory_diff_rate, $memory_diff_total;
            print_log "Warning, memory leak detected: $msg";
            logit $memory_leak_log, $msg;
            $Info{memory_virtual_prev} = $Info{memory_virtual};
            $Info{memory_virtual_time} = $Time;
        }
    }
}

$v_memory_leak_log = new Voice_Cmd 'Display the memory leak log';
display font => 'fixed', text => $memory_leak_log if said $v_memory_leak_log;

$v_memory_check = new Voice_Cmd '[Start,Stop] the memory leak checker';
$v_memory_check-> set_info('This will disable each code file for a while, to determine which is causing a memory leak');
$t_memory_check = new Timer;

my (@memory_leak_members, $memory_leak_index, $memory_leak_member);
if ('Start' eq said $v_memory_check) {
    respond 'Ok, starting memory check';
    @memory_leak_members = grep !/(monitor_memory)|(tk_)/, sort keys %Run_Members;
    print_log "These members will be tested: @memory_leak_members";
    $memory_leak_index = 0;
    set $t_memory_check 1;      # Set to start next pass
}

if ('Stop' eq said $v_memory_check) {
    respond 'Memory leak check has been stopped';
    unset $t_memory_check;
}

if (expired $t_memory_check) {
    print_log "Memory leak timer expired";
    if ($memory_leak_member) {
        $Run_Members{$memory_leak_member} = 1;
        print_log "Memory leak test: re-enabled $memory_leak_member";
        $memory_leak_index++;
        my $memory_diff = round $Info{memory_virtual} - $Info{memory_virtual_test}, 2;
        print_log "Memory leak amount: $memory_diff";
        logit "$config_parms{data_dir}/logs/monitor_memory.log", "Leaked $memory_diff MB with $memory_leak_member disabled";
    }
    if ($memory_leak_member = $memory_leak_members[$memory_leak_index]) {
        $Run_Members{$memory_leak_member} = 0;
        print_log "Memory leak test: disabled $memory_leak_member";
        set $t_memory_check 20*60;
        $Info{memory_virtual_test} = $Info{memory_virtual};
    }
    else {
        print_log "Memory leak test finished";
    }
}
    
    
