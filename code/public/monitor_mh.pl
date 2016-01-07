# Category=MisterHouse

# Restart periodically, to work around memory leaks
#un_voice_cmd 'Restart Mister House' if $New_Day;
#run_voice_cmd 'Reboot the computer' if $New_Day;

# Update a file once a minute so another box
# can do the watchdog thing
my $watchdog_file1 = "$config_parms{data_dir}/monitor_mh.time";
file_write $watchdog_file1 , $Time if $New_Minute;

# Keep an eye on another box on the network
#$watchdog_light = new X10_Item('O7');
#$watchdog_light_timer = new  Timer;

my $watchdog_file2 = '//house/c/misterhouse/data/monitor_mh.time';

# Periodically check
my $reboot_flag          = 0;
my $guest_in_living_room = 1;    # Don't wake up sleeping guest

if ($New_Minute) {

    # Check to see if Dad's MisterHouse is running
    #  - unless we are with 60 seconds of Startup
    if ( file_change $watchdog_file2 or $Time_Uptime_Seconds < 60 ) {
        if ($reboot_flag) {
            run "SHUTDOWN -a -m \\\\house" if $reboot_flag;
            get "http://192.168.0.81/cgi-bin/SetLEDState?0";
            $reboot_flag = 0;

            #           run_voice_cmd 'Kitchen Led off';
        }
    }
    else {
        my $msg = 'Bruce, MisterHouse is not running on the House box';
        print_log $msg;

        #       display $msg, 5 if $New_Hour;
        #        speak(rooms => 'all', text => $msg);

        get "http://192.168.0.81/cgi-bin/SetLEDState?1"
          unless $guest_in_living_room;

        #       get "http://kitchen/cgi-bin/SetLEDState?1";
        #       run_voice_cmd 'Kitchen Led blink';

        if ( $reboot_flag++ > 2 ) {

            # This does not work ... access denied
            run
              qq|SHUTDOWN -f -m \\\\house -t 600 -r -c "C1 detected MisterHouse on house stopped, so requested a reboot"|;
        }

        #        set $watchdog_light ON;
        #        set $watchdog_light_timer 3, 'set $watchdog_light OFF';
    }
}

