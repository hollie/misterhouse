# Category=Test


				# speak time if asked for, and every minute
$v_tell_time = new  Voice_Cmd('What is the time');
if (said $v_tell_time or $New_Minute) {
    print_log "It is $Time_Now on $Date_Now.";
    speak("It is $Time_Now on $Date_Now.");
}
