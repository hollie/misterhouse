# Category= Timers

# Cancel all timers
$v_call_timer = new  Voice_Cmd('Cancel all timers');
$v_call_timer-> set_info('All timers will be unset');
if ($state = said $v_call_timer) {
#	unset $timer_second;
	unset $timer_minute;
	unset $timer_hour;
 	speak "ALL timers have been canceled";
}

# list all timers
$v_lall_timer = new  Voice_Cmd('list all timers');
$v_lall_timer-> set_info('Summarize all Minute and Hour timers');

if ($state = said $v_lall_timer) {

                                # Second timers are local, not global, so not accessable here
#	$temp = seconds_remaining $timer_second;
#	speak &plural($temp, "second") . " left on seconds timer" if ($temp !=0);

	$temp = minutes_remaining $timer_minute;
	speak &plural($temp, "minute") . " left on minutes timer" if ($temp !=0);

	$temp = hours_remaining $timer_hour;
	speak &plural($temp, "hour") . " left on hour timer" if ($temp !=0);
}		

