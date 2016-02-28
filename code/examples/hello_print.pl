# Category=Test

# print hi and give uptime every 5 seconds
if ( $New_Second and !( $Second % 5 ) ) {
    my $uptime_pgm = &time_diff( $Time_Startup_time, time );
    my $uptime_computer = &time_diff( 0, (get_tickcount) / 1000 );
    print_log
      "Hi, I was started $uptime_pgm ago. The computer was booted $uptime_computer ago.\n";
}
