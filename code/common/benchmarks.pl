# Category = MisterHouse

#@ Various benchmarking functions.

# you can set parameters with at startup.  For example:
#    mh -voice_cmd 0 -voice_text 0 -weeder_port none

$v_what_speed = new Voice_Cmd 'What is your [max,normal] speed';
$v_what_speed->set_info(
    'Runs mh at max speed for a few seconds, then reports Passes Per Second');

$timer_speed_check = new Timer;
if ( said $v_what_speed) {
    my $msg;
    if ( $v_what_speed->{state} eq 'max' ) {
        $Loop_Sleep_Time = 0;
        $Loop_Tk_Passes  = .1;    # 0 gets reset to 1, so use .1
        set $timer_speed_check 3;
        print "Speeds1 = @Loop_Speeds\n";
        print "Note: tk window is temporily disabled\n" if $MW;

        $msg = 'Calculating maximum speed. One moment...';
    }
    else {
        set $timer_speed_check .01;
        $msg = 'Calculating normal speed...';
    }
    $v_what_speed->respond("app=pc $msg");

}
if ( expired $timer_speed_check) {
    $Loop_Sleep_Time = $config_parms{sleep_time};
    $Loop_Tk_Passes  = $config_parms{tk_passes};
    print "Speeds2 = @Loop_Speeds\n";
    $v_what_speed->respond(
            "app=pc $Info{cpu_used}% of cpu, $Info{loop_speed} loops/sec, and "
          . ( int $Info{memory_real} )
          . " megabytes" );
}

my $speed_benchmark_count = 0;

$v_speed_benchmark =
  new Voice_Cmd '[Start a by name,Start a by speed,Stop the] speed benchmark';
$v_speed_benchmark->set_info(
    'This will suspend normal mh while it benchmarks each code member individually. It can take few minutes.'
);
if ( said $v_speed_benchmark) {
    my $msg;
    if ( $v_speed_benchmark->{state} eq 'Stop the' ) {
        $Benchmark_Members{on_off_flag} = $speed_benchmark_count = 0;
        undef %Benchmark_Members;
        $msg = 'Speed benchmark stopped.';
    }
    else {
        $Benchmark_Members{on_off_flag} = $speed_benchmark_count = 1
          unless $speed_benchmark_count;
        $msg =
            'Speed benchmark started by '
          . ( ( $v_speed_benchmark->{state} =~ /name/i ) ? 'name' : 'speed' )
          . '.';
    }
    $v_speed_benchmark->respond("app=pc $msg");

}
$speed_benchmark_count++ if $speed_benchmark_count;

if ( $speed_benchmark_count and ( new_second 5 or said $v_speed_benchmark) ) {
    my $log =
      "Benchmark report.  Loop count=$speed_benchmark_count.  The following is in milliseconds\n";
    my $by_speed = ( state $v_speed_benchmark =~ /speed/ ) ? 1 : 0;
    my @log;
    for my $member (
        sort {
            $by_speed and ( $Benchmark_Members{$b} <=> $Benchmark_Members{$a} )
              or $a cmp $b
        } ' OTHER',
        ' USER',
        keys %Run_Members
      )
    {    # Use Run_Members so we get all members on the 1st pass
        push @log, sprintf "  %-22s avg=%5.2f total=%5d", $member,
          $Benchmark_Members{$member} / $speed_benchmark_count,
          $Benchmark_Members{$member};
    }

    # Double or triple up columns so it fits on without scrolling when there are lots of members
    if ( $#log > 100 ) {
        my $i = 1 + int $#log / 3;
        for my $j ( 0 .. $i ) {
            $log .=
                $log[$j] . " | "
              . $log[ $j + $i ] . " | "
              . $log[ $j + 2 * $i ] . "\n";
        }
    }
    elsif ( $#log > 20 ) {
        my $i = 1 + int $#log / 2;

        #        print "db2 i=$i l=$#log\n";
        for my $j ( 0 .. $i ) {
            $log .= $log[$j] . " | " . $log[ $j + $i ] . "\n";
        }
    }
    else {
        for my $j ( 0 .. $#log ) {
            $log .= $log[$j] . "\n";
        }
    }

    file_write "$config_parms{data_dir}/logs/benchmark.log", $log;
    display
      text        => $log,
      time        => 0,
      font        => 'fixed',
      window_name => 'benchmarks';
}
