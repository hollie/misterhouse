# Category= Timers

my %timer_reminder_intervals = map {$_, 1} (1,5,10,20,30,60);

# Do an minutes timer
$v_minute_timer = new  Voice_Cmd('Set a timer for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,45,60,90,120] minutes');
$v_minute_timer-> set_info('Set a minute timer.  Time remaining will be periodically announced');

$timer_minute = new  Timer;
if ($state =  said $v_minute_timer) {
    speak "A timer has been set for $state minutes";
    set $timer_minute $state*60, "speak 'rooms=all Notice, the $state minute timer just expired'";
}
speak &plural($temp, "minute") . " left on the timer"  if ($temp = minutes_remaining_now $timer_minute) and $timer_reminder_intervals{$temp};

# Cancel all minute timers
$v_cminute_timer = new  Voice_Cmd('Cancel all minute timers');
if ($state = said $v_cminute_timer) {
	unset $timer_minute;
 	speak "All minute timers have been canceled";
	}


