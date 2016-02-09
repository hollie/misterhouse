
# Category = Misc

#@ Commands to monitor computer game time

$check_game_time =
  new Voice_Cmd "Display Nick's [all,total,daily] game time log";

if ( $state = said $check_game_time) {
    display
      text =>
      scalar file_tail( '//warp/c/mh/data/logs/eqtime_totals.log', 100 ),
      time   => 200,
      title  => 'Total eq time log',
      font   => 'fixed',
      height => 50
      unless $state eq 'daily';
    display
      text   => scalar file_tail( '//warp/c/mh/data/logs/eqtime.log', 50 ),
      time   => 50,
      title  => 'Daily eq time log',
      font   => 'fixed',
      height => 50
      unless $state eq 'total';
}
$check_game_time2 = new Voice_Cmd "Check Nick's game time";
if ( said $check_game_time2 or time_now '6:30 am' ) {

    # Find how long and when last on
    my ( $time_start, $day, $date, $time, $time2, $time_prev );
    for ( file_tail( '//warp/c/mh/data/logs/eqtime.log', 500 ) ) {
        next unless /eqgame/;

        #         Sat 06/21/03 16:24:05 Time: 50.2, Pgm:eqgame.exe      Threads: 11 Mem:281.37,283.64
        ( $day, $date, $time ) = split;
        $time2 = &my_str2time("$date $time");
        if ( $time2 > $time_prev + 3600 ) {
            $time_start = $time2;
        }
        $time_prev = $time2;
    }
    my $time3 = sprintf "%3.1f", ( $time2 - $time_start ) / 3600;
    print_log "On for $time3 hours, last on $time, $day $date";
    print_msg "On for $time3 hours, last on $time, $day $date";
}

