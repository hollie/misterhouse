
# Category=Test

sub web_func1 {
    return "uptime = "
      . &time_diff( $Time_Startup_time, $Time, undef, 'numeric' );
}

sub web_func2 {
    return "results from function 2";
}
