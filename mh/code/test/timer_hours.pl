# Category= Timers

				# Do an hour timer
my %timer_reminder_intervals = map {$_, 1} (1,2,5,10,20,30);
$v_hour_timer = new  Voice_Cmd('Set a timer for [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,24,30] hours');
$v_hour_timer-> set_info('Set an hour timer.  Time remaining will be periodically announced');

$timer_hour = new  Timer;
if ($state =  said $v_hour_timer) {
    speak "A timer has been set for $state hours";
    set $timer_hour $state*60*60, "speak 'rooms=all Notice, the $state hour timer just expired'";
}   
my $temp;
speak &plural($temp, "hour") . " left on the hour timer"  if ($temp = hours_remaining_now $timer_hour) and $timer_reminder_intervals{$temp};
speak "$temp minutes left on the hour timer"  if ($temp = minutes_remaining_now $timer_hour) and $timer_reminder_intervals{$temp};

# Cancel all hour timers
$v_chour_timer = new  Voice_Cmd('Cancel hour timers');
if ($state = said $v_chour_timer) {
	unset $timer_hour;
 	speak "All hour timers have been canceled";
	}
