

$v_reload_code = new  Voice_Cmd("Reload code");
if (said $v_reload_code) {
    read_code();
#   set $digital_read_port_c;	# No need to reset anymore ... data is saved in -saved_states
}


$v_uptime = new  Voice_Cmd("What is your up time?");
if (said $v_uptime) {
    my $uptime_pgm = &time_diff($Time_Startup_time, time);
    my $uptime_computer = &time_diff(0, (get_tickcount)/1000);
#   speak("I was started on $Time_Startup\n");
    speak("I was started $uptime_pgm ago. The computer was booted $uptime_computer ago.");
}

$v_debug = new  Voice_Cmd("Turn debug [on,off,X10,serial,http]");
if ($state = said $v_debug) {
    $state = 0 if $state eq OFF;
    $config_parms{debug} = $state;
    speak "Debug has been turned $state";
}

$v_mode = new  Voice_Cmd("Put house in [normal,mute,offline] mode");
if ($state = said $v_mode) {
    $Save{mode} = $state;
    speak "The house is now in $state mode.";
    print_log "The house is now in $state mode.";
}

$v_disk_space2 = new Voice_Cmd("Show disk space");
if (said $v_disk_space2) {
				# Include remote drives on other computers
    my $report = "Disk drive space (free / total megabytes) sorted by drive:\n";
    my (%total_by_drive, %free_by_drive);
    if ($OS_win) {
        for my $drive (Win32::DriveInfo::DrivesInUse(),
                       '\\\dm\c', '\\\dm\d', '\\\dm\e', '\\\dm\f') {
            next if $drive eq 'A';
            my ($total, $free) = (Win32::DriveInfo::DriveSpace($drive))[5,6];
            $total /= 10**6;
            $free  /= 10**6;
            $total_by_drive{$drive} = $total;
            $free_by_drive{$drive} = $free;
            $report .= sprintf("%14s: %6.1f / %6.1f\n", $drive, $free, $total);
        }
        $report .=  "\n\nDisk drive space (free / total megabytes) sorted by free space:\n";
        for my $drive (sort {$free_by_drive{$a} <=> $free_by_drive{$b} or $a cmp $b} keys %free_by_drive) {
            $report .= sprintf("%14s: %6.1f / %6.1f\n", $drive, $free_by_drive{$drive}, $total_by_drive{$drive});
        }
        display $report, 30, 'Disk use report', 'fixed';
        speak "Here is the report on disk space";
    }
    else {
        speak "Sorry, function not available on unix yet";
    }
}


$v_uptime = new  Voice_Cmd("What is your up time?");
if (said $v_uptime) {
    my $uptime_pgm = &time_diff($Time_Startup_time, time);
    my $uptime_computer = &time_diff(0, (get_tickcount)/1000);
#   speak("I was started on $Time_Startup\n");
    speak("I was started $uptime_pgm ago. The computer was booted $uptime_computer ago.");
}

$v_reboot = new  Voice_Cmd("Reboot the computer");
if (said $v_reboot and $OS_win) {
    speak("The D M computer will reboot in 5 minutes.");
    Win32::InitiateSystemShutdown('DM', 'Rebooting in 5 minutes', 300, 1, 1);
}

$v_reboot_abort = new  Voice_Cmd("Abort the reboot");
if (said $v_reboot_abort and $OS_win) {
  Win32::AbortSystemShutdown('HOUSE');
  speak("OK, the reboot has been aborted.");
}
