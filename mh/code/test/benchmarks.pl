# Category=MisterHouse

#
# To turn stuff off, use startup arms.  For example:
#    mh -voice_cmd 0 -voice_text 0 -weeder_port none
#

$v_what_speed = new Voice_Cmd 'What is your speed', 'Calculating';
$v_what_speed-> set_info('Runs mh at max speed for a few seconds, then reports Passes Per Second');

$timer_speed_check = new  Timer;
#$request_speed       = new  Serial_Item('XO2');
if (said $v_what_speed) {
#   speak("$Loop_Speed and .");
    $Loop_Sleep_Time = 0;
    $Loop_Tk_Passes = .1;	# 0 gets reset to 1, so use .1
    set $timer_speed_check 3;
    print "Speeds1 = @Loop_Speeds\n";
    print "Note:  tk window is temporily disabled\n";
}
if (expired $timer_speed_check) {
    speak("$Loop_Speed mips.");
    $Loop_Sleep_Time = $config_parms{sleep_time};
    $Loop_Tk_Passes  = $config_parms{tk_passes};
    print "Speeds2 = @Loop_Speeds\n";
}


$v_speed_benchmark = new Voice_Cmd 'Run speed benchmark';
$v_speed_benchmark-> set_info('This will suspend normal mh while it benchmarks each code member individually.  It can take few minutes.');

$timer_speed_benchmark = new  Timer;
my @benchmark_members;
my $benchmark_member;
my @original_item_code;
if (said $v_speed_benchmark) {
#   or state_now $test_16) {
    speak("Starting benchmark.");
    print "Note:  tk window is temporily disabled\n";
#   logit("$config_parms{data_dir}/logs/benchmarks.$Year_Month_Now.log", "\n");
    logit("$config_parms{data_dir}/logs/benchmarks.log", "\n");
    sleep 2;

    @benchmark_members = sort keys %Run_Members;
    push(@benchmark_members, ' none', '  all');
    &set_run_flags;

    $Loop_Sleep_Time = 0;
    $Loop_Tk_Passes = .1;	# 0 gets reset to 1, so use .1
}

if (expired $timer_speed_benchmark) {
    my $data = sprintf("Benchmark member=%20s Speeds=%s", $benchmark_member, join(", ", @Loop_Speeds[0..2]));
    print "$data\n";
    logit("$config_parms{data_dir}/logs/benchmarks.log", $data);

    if (@benchmark_members) {
        &set_run_flags;
    }
    else {
        $Loop_Sleep_Time = $config_parms{sleep_time};
        $Loop_Tk_Passes  = $config_parms{tk_passes};
        speak("Benchmark is done and loged in the data directory.");
        foreach (keys %Run_Members) {
            $Run_Members{$_} = 1;  # use map here
        }
    }
}

$v_view_benchmark_log = new Voice_Cmd 'Display the benchmark log';
$v_view_benchmark_log-> set_info('Display the results of previous benchmarking runs');

display "$config_parms{data_dir}/logs/benchmarks.log" if said $v_view_benchmark_log;


sub set_run_flags {

    $benchmark_member = shift @benchmark_members;
    foreach (keys %Run_Members) {
        $Run_Members{$_} = ($_ eq $benchmark_member or $benchmark_member eq '  all') ? 1 : 0;
    }
    $Run_Members{benchmarks} = 1;

    set $timer_speed_benchmark 3;

}    



