# Category=Test

				# print hi and give uptime every 30 seconds
if (new_second 30) {
    my $uptime_pgm = &time_diff($Time_Startup_time, time);
    my $uptime_computer = &time_diff($Time_Boot_time, (get_tickcount)/1000);
    print_log "Hi, I was started $uptime_pgm ago. The computer was booted $uptime_computer ago.";
}













