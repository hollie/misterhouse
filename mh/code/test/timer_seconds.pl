# Category= Timers

my %timer_reminder_intervals = map {$_, 1} (5,10,20,30,60);

# Do an seconds timer
$v_second_timer = new  Voice_Cmd('Start a timer for [5,10,15,20,30,45,60,90,120] seconds');
$v_second_timer-> set_info('Set an second timer.  Time remaining will be periodically announced.  Note you can have more than one second timer.');

                                # Note, we use a local object here by putting a 'my' in front of the object
                                # delcaration.  This allows us to create multiple objects, on the fly, so we 
                                # can have more than one active second timer. 
                                # The down side to this is that since the Object is not global, it's state
                                # is not saved if we restart or reload code :(
                                # I left the timer_hours.pl and timer_minutes.pl with global objects.
my @timers_second;

if ($state =  said $v_second_timer) {
    my $timer_second = new  Timer;
    push(@timers_second, $timer_second);
    speak "$state second timer started"; 
    set $timer_second $state, "speak 'Notice, the $state second timer just expired'";
}

for my $timer (@timers_second) {
    speak &plural($temp, "second") . " left"  if ($temp = seconds_remaining_now $timer) and $timer_reminder_intervals{$temp};
}

# Cancel all seconds timers
$v_csecond_timer = new  Voice_Cmd('Cancel all second timers');
if ($state = said $v_csecond_timer) {
    for my $timer (@timers_second) {
        unset $timer;
    }
 	speak "All second timers have been canceled";
}


