# Category=Informational


				# Set up so we can use keys on a remote transmiter to taunt the kids
$personal_remark_good   = new Serial_Item('XACAJ');
$personal_remark_bad    = new Serial_Item('XACAK');

				# Let button 4 of various X10 consoles be the Time button
$request_time        = new  Serial_Item('XH4');
$request_time       -> add             ('XJ4');
$request_time       -> add             ('XK4');
$request_time       -> add             ('XM4');
$request_time       -> add             ('XN4');
$request_time       -> add             ('XO4');
$request_time       -> add             ('XP4');

if (state_now $request_time) {
    ($temp = $Time_Now) =~ s/\:00//;   # MS TTS V5 turns :00 into O'clock
#   ($temp = $Time_Now) =~ s/ [AP]M//; # Drop the AM/PM
    speak "rooms=$request_time->{room} volume=100 It is now $temp";
}
 
if (state_now $display_calls) {
    run_voice_cmd 'Show the phone log';
}


if (state_now $request_temp) {
    run_voice_cmd 'What is the  temperature';
    $mh_speakers->{rooms} = $request_temp->{room};
}

# Test double/triple keys

my $kitchen_2 = new X10_Item 'O2';

print_log "Kitchen key: $state" if $state = state_now $kitchen_2;


if ($ControlX10::CM11::POWER_RESET) {
    display time => 0, text => "Detected a CM11 power reset";
    $ControlX10::CM11::POWER_RESET = 0;
}

