# Category=none

$timer_garage_door = new  Timer();
if($state = state_now $garage_door) {
    unless ($state eq 'init') {
        set $timer_garage_door 300;
        play('rooms' => 'all', 'file' => "garage_door_" . $state . "*.wav");
    }
}

# Note:  testing on state $item seems to reset it!! use $item->{state} instead :(
if ((time_cron('0,5,10,15,30,45 22,23 * * *') and 
    (OPENED eq ($garage_door->{state})) and
    inactive $timer_garage_door)) {
    &speak(mode => 'unmuted', text => "The garage door has been left opened.  I am now closing it.");
    set $garage_door_button ON;
    set $garage_door_button OFF;
}

$timer_front_door = new  Timer();
if ($state = state_now $front_door  and $state ne 'init' and inactive $timer_front_door) {
    set $timer_front_door 30;
    play(mode => 'unmuted', 'rooms' => 'all', 'file' => "front_door_" . $state . "_Zach1.wav");
}
if (expired $timer_front_door and state $front_door eq OPENED) {
    speak(mode => 'unmuted', text => 'The front door has been left open');
    set $timer_front_door 120;
}

$timer_back_door = new  Timer();
if ($state = state_now $back_door and $state ne 'init' and inactive $timer_back_door) {
    set $timer_back_door 60;
                # Need to make rooms=all more efficient, or we don't detect closure.
    play(mode => 'unmuted', 'rooms' => 'all', 'file' => "back_door_" . $state . ".wav");
#   speak("rooms=all Back door $state");
#   speak("Back door $state");
}
if (expired $timer_back_door and state $back_door eq OPENED) {
    speak("The back door has been left open");
    set $timer_back_door 240;
}

#layit("rooms=all garage_entry_door_$state.wav") if $state = state_now $garage_entry_door;
#layit("rooms=all entry_door_$state.wav") if $state = state_now $entry_door;

$timer_garage_movement = new  Timer();
if (state_now $garage_movement) {
    set $garage_light ON;
    if (inactive $timer_garage_movement) {
    play('rooms' => 'all', 'file' => "garage_movement*.wav");
#       speak("Something is in the garage.");
    }
    set $timer_garage_movement 300;
    set $timer_garage_door 300;
}
if (expired $timer_garage_movement) {
    set $garage_light OFF;
}

if (state_now $garage_door or
    state_now $garage_entry_door or
    state_now $entry_door or
    state_now $front_door) {
    set $timer_garage_movement 300;
    set $timer_garage_door 300;
    set $timer_stair_movement 150;
}

$timer_stair_movement = new  Timer();
$bathroom_timer  = new Timer();
#speak("stair creek")      if state_now $movement_sensor eq ON;

#print_log "movement sensor: " . (state $movement_sensor_unit) if state_now $movement_sensor;

if (state_now $movement_sensor eq ON and 
    inactive $timer_stair_movement and
    !$Save{sleeping_parents}) {
    set $timer_stair_movement 60;
#    set $timer_stair_movement 150;
    if ((state $movement_sensor_unit) eq 'stair') {
        play('file' => "stairs_creek*.wav");
    }
    elsif ((state $movement_sensor_unit) eq 'hall') {
        play(rooms => 'all', file => 'sound_hall*.wav');
#       speak "rooms=all boys in the hall";
    }
    elsif ((state $movement_sensor_unit) eq 'bathroom') {
        print_log 'bathroom movement';
        set $bathroom_timer 5;
    }
} 
