# Category=MisterHouse

#@ Monitors other mh boxes

return;

# Update a file once a minute so another box
# can do the watchdog thing
my $watchdog_file1 = "$config_parms{data_dir}/monitor_mh.time";
file_write $watchdog_file1 , $Time if new_second 30;

# Keep an eye on another box on the network
#y $watchdog_file2 = '//c2/c/misterhouse/data/monitor_mh.time';
my $watchdog_file2 = '//c1/c/misterhouse/data/monitor_mh.time';

#my $watchdog_file3 = '//warp/c/mh/data/monitor_mh.time';

# Set file_change flag at startup
file_change $watchdog_file2 if $Reload;

#file_change $watchdog_file3 if $Reload;

# Periodically check other mh boxes
if ( new_minute 90 ) {
    my $msg;
    if ( !file_change $watchdog_file2) {
        $msg = 'Bruce, MisterHouse is not running C1';
    }

    #    if (!file_change $watchdog_file3) {
    #        $msg = 'Bruce, MisterHouse is not running on Warp';
    #    }
    if ($msg) {
        speak $msg;
        get "http://kitchen/cgi-bin/SetLEDState?2";
        logit( "$config_parms{data_dir}/logs/monitor_mh.log", $msg );
    }
    else {
        get "http://kitchen/cgi-bin/SetLEDState?0";
    }
}

# We now do this every 10 minutes in mh_control.pl
#run_voice_cmd 'Check the http server' if new_minute 1;
