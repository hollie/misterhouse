# Category=Test

#@ Speaks and adds to the log file the current time when requested as
#@ well as once per minute. Good for testing speech functionality.

# speak time if asked for, and every minute
$v_tell_time = new Voice_Cmd('What is the time');
if ( said $v_tell_time or $New_Minute ) {
    print_log "It is $Time_Now on $Date_Now_Speakable.";

    #   speak("It is $Time_Now on $Date_Now.");
    speak("It is $Time_Now.");
}
