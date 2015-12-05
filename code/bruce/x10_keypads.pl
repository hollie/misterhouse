# Category=Informational

#@ Responds to x10 keypad commands

# Set up so we can use keys on a remote transmiter to taunt the kids
$personal_remark_good = new Serial_Item('XACAJ');
$personal_remark_bad  = new Serial_Item('XACAK');

# Let button 4 of various X10 consoles be the Time button
$request_time = new Serial_Item('XH4');    # Laundry
$request_time->add('XK4');
$request_time->add('XM4');                 # Zack
$request_time->add('XN4');                 # Nick
$request_time->add('XO4');                 # Living room
$request_time->add('XP4');                 # Bedroom

# equest_time       -> add             ('XJ4');  # Garage

if ( state_now $request_time) {
    ( $temp = $Time_Now ) =~ s/\:00//;     # MS TTS V5 turns :00 into O'clock

    #   ($temp = $Time_Now) =~ s/ [AP]M//; # Drop the AM/PM
    speak "mode=unmuted rooms=$request_time->{room} volume=100 It is now $temp";
}

$request_deep_thought  = new Serial_Item('XD1');
$request_tagline       = new Serial_Item('XD1D1');
$request_rain_forecast = new Serial_Item('XD2');
run_voice_cmd 'Read the next deep thought' if state_now $request_deep_thought;
run_voice_cmd 'Read the house tagline'     if state_now $request_tagline;
run_voice_cmd 'What is the forecasted chance of rain'
  if state_now $request_rain_forecast;

if ( state_now $display_calls) {
    run_voice_cmd 'Show the phone log';
}

if ( state_now $request_temp) {

    #   run_voice_cmd 'What is the  temperature', undef, 'human', 1, 'unmuted';
    run_voice_cmd 'What is the  temperature', undef, 'default', 1, 'unmuted';
    $mh_speakers->{rooms} = $request_temp->{room};
}

# Test double/triple keys

my $kitchen_2 = new X10_Item 'O2';

print_log "Kitchen key: $state" if $state = state_now $kitchen_2;

if ($ControlX10::CM11::POWER_RESET) {
    display time => 0, text => "Detected a CM11 power reset";
    $ControlX10::CM11::POWER_RESET = 0;
}

