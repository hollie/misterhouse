# Category=Test

#@ Every 30 seconds, prints how long ago MisterHouse was started and the last
#@ time the computer was booted to the log file.

# print hi and give uptime every 30 seconds
if ( new_second 30 ) {
    my $uptime_pgm      = &time_diff( $Time_Startup_time, time );
    my $uptime_computer = &time_diff( $Time_Boot_time,    $Time );
    print_log
      "Hi, I was started $uptime_pgm ago. The computer was booted $uptime_computer ago.";
}

