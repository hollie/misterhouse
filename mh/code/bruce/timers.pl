# Category=Timers

$v_laundry_timer = new  Voice_Cmd('Laundry timer [on,off]');
$v_laundry_timer-> set_info('Set a 35 minute timer to remind when the cloths are washed/dried');

$timer_laundry = new  Timer;
if ($state =  said $v_laundry_timer or
    $state = state_now $laundry_timer) {
    if ($state eq ON) {
        play('rooms' => 'shop', 'file' => 'cloths_started.wav');
        set $timer_laundry 35*60, 'speak "rooms=all The laundry clothes are speaky to move on"', 4;
    }
    else {
        speak 'rooms=shop The laundry timer has been turned off.';
        set $timer_laundry 0;
    }
}

$v_tramp_timer = new  Voice_Cmd('[Start,Stop] the tramp timer');
$v_tramp_timer-> set_info('Set a timer for fair usage on the trampoline.  Peace will rule :)');

$timer_tramp = new  Timer;
if ('Start'   eq said $v_tramp_timer) {
#    ON eq state_now $tramp_timer) {
    speak "room=family The tramp timer has been started";
#    set $timer_tramp 5*60, "speak 'rooms=family The tramp timer has just expired.  Time to trade turns'", 10;
    set $timer_tramp 30, "speak 'rooms=family The tramp timer has just expired.  Time to trade turns'", 10;
}
#print "db ", minutes_remaining $timer_tramp, "\n";
if ($temp = minutes_remaining_now $timer_tramp) {
    speak "room=family There are $temp minutes left on the tramp timer" if $temp % 2;
}
if ('Stop'     eq said $v_tramp_timer) {
#    OFF eq state_now $tramp_timer) {
    speak "room=family The tramp timer has been stopped";
    set $timer_tramp 0;
}

#      !($temp % 5);

#if (expired $timer_second) {
#    speak "timer died";
#}
#if (expired $timer_second) {
#    speak "timer died again";
#}
