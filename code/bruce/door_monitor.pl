# Category=Other

#@ Monitors door and movement sensors

$timer_garage_door = new Timer();
my $garage_door_time;
if ( $state = state_now $garage_door) {

    #   print "db garage door state=$state, t=$Time l=$Loop_Count\n";
    # Ignore mh startup noise and add a bit of hysteresis
    unless ( $state eq 'init' or ( $Time - $garage_door_time ) < 7 ) {
        set $timer_garage_door 300;

        #       play('rooms' => 'all', 'file' => "garage_door_" . $state . "*.wav");
        #        speak "rooms=all mode=unmute Garage door just $state";
        speak "mode=unmute Garage door just $state";
        print_msg "Garage door $state";
    }
    $garage_door_time = $Time;
}

# Note:  testing on state $item seems to reset it!! use $item->{state} instead :(
if (
    (
            time_cron('0,5,10,15,30,45 22,23 * * *')
        and ( OPENED eq ( $garage_door->{state} ) )
        and inactive $timer_garage_door)
  )
{
    &speak(
        mode => 'unmuted',
        text => "The garage door has been left opened."
    );

    #    set $garage_door_button ON;
    #    set $garage_door_button OFF;
}

$garage_door_v = new Voice_Cmd '[open,close,change] garage door';
if ( $temp = state_now $garage_door_v) {
    $state = state $garage_door;
    print_log "Garage door is $state.  Request=$temp\n";
    if ( $state eq 'open' and $temp eq 'open' ) {
        speak 'The garage door is already opened';
    }
    elsif ( $state eq 'close' and $temp eq 'close' ) {
        speak 'The garage door is already closed';
    }
    else {
        speak $temp . 'ing the garage door';
        set $garage_door_button ON;
        select undef, undef, undef, .100;
        set $garage_door_button OFF;
    }
}

$timer_front_door = new Timer();

if ( $state = state_now $front_door and $state ne 'init' ) {
    set $timer_front_door ( $state eq 'opened' ) ? 30 : 0;

    #    play(mode => 'unmuted', 'rooms' => 'all', volume => 10, 'file' => "front_door_" . $state . ".wav");
    print_log "front_door_" . $state . ".wav";
    print_msg "Front door $state"
      if $state eq 'opened' and inactive $timer_front_door;

    #   play(mode => 'unmuted', 'rooms' => 'all', 'file' => "front_door_" . $state . "_Zach1.wav");
}

if ( expired $timer_front_door and state $front_door eq OPENED ) {

    # Don't speak if it is warm out, unless we are asleep, so we can air out house with door open
    speak( mode => 'unmuted', text => 'The front door has been left open' )
      if $Weather{TempOutdoor} < 50 or $Save{sleeping_parents};
    set $timer_front_door 120;
}

$timer_back_door = new Timer();
if ( $state =
        state_now $back_door
    and $state ne 'init'
    and inactive $timer_back_door)
{
    set $timer_back_door 60;

    # Need to make rooms=all more efficient, or we don't detect closure.
    play(
        mode    => 'unmuted',
        'rooms' => 'all',
        'file'  => "back_door_" . $state . ".wav"
    );

    #   speak("rooms=all Back door $state");
    #   speak("Back door $state");
}
if ( expired $timer_back_door and state $back_door eq OPENED ) {
    speak( mode => 'unmuted', text => 'The back door has been left open' );
    set $timer_back_door 240;
}

#layit("rooms=all garage_entry_door_$state.wav") if $state = state_now $garage_entry_door;
#layit("rooms=all entry_door_$state.wav") if $state = state_now $entry_door;

$timer_garage_movement  = new Timer();
$timer_garage_movement2 = new Timer();
if (
       state_now $garage_door
    or state_now $garage_entry_door
    or state_now $garage_movement
    or

    #   state_now $webcam_garage or   ... this causes and endless cycle
    state_now $entry_door or state_now $front_door)
{
    set $garage_light ON if $Dark;
    if ( inactive $timer_garage_movement) {
        play( 'rooms' => 'all', 'file' => "garage_movement*.wav" );

        #       speak("Something is in the garage.");
    }
    set $timer_garage_movement 60 * 10;
    set $timer_garage_movement2 60 * 30;
    set $timer_garage_door 60 * 10;
}

set $timer_garage_movement2 60 * 30 if state_now $webcam_garage;

if ( new_hour 2 and inactive $timer_garage_movement2) {
    set $garage_lights OFF;
}

if ( expired $timer_garage_movement) {
    set $garage_light OFF;
    print_log
      "Garage timer expired: light=$$garage_light{state} lights=$$garage_lights{state}";

    #    set $garage_light  OFF if $garage_light  ne 'OFF';
    #    set $garage_lights OFF if $garage_lights ne 'OFF';
}

# Check the movement sensors

$timer_hall_movement     = new Timer;
$timer_bathroom_movement = new Timer;

unless ( $Save{sleeping_parents} ) {
    if ( state_now $hall_light eq ON and inactive $timer_hall_movement) {

        #       play file => 'timer', rooms => 'all', mode => 'unmuted'; # Girl detector
        play 'movement1';    # Defined in event_sounds.pl

        #       play 'file' => 'stairs_creek*.wav';
        set $timer_hall_movement 3;
    }
    elsif ( state_now $bathroom_light eq ON
        and inactive $timer_bathroom_movement)
    {
        #       play 'movement1';       # Defined in event_sounds.pl
        set $timer_bathroom_movement 5;
    }
}

#if (state_now $sensor_bathroom eq 'motion') {
#    set $bathroom_light ON;
#}
#if (state_now $sensor_bathroom eq 'still') {
#    set $bathroom_light OFF;
#}

# If we tried to turn the light off, and it went back on because of the motion
# sensor detected a light change as motion, lets auto-dim it gradually.
# ... not done yet ...
#if (state_now $sensor_bathroom eq 'motion') {
#}

# These items do 24 hour battery tests
#$sensor_hall     = new X10_Sensor 'XA2AJ', 'Hall';
#$sensor_bathroom = new X10_Sensor 'XA4AJ', 'Bathroom';
