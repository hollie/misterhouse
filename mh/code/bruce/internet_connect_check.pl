# Category = Internet
                                # Enable this code (with the tk radiobutton) to notify you 
                                # when your internet connection has come back up.
                                # Useful for those with cable modems that often go down for
                                # hours at a time.
                                # Note: we use a process item to 'fork' the ping, as it will
                                #       hang if the net connection is down.  

#y $ping_test_host = '24.2.1.71';
my $ping_test_host = '24.213.60.73'; # bresnanlink.net

my $ping_test_results = "$config_parms{data_dir}/ping_results.txt";
#$ping_test   = new Process_Item("perl saveout $ping_test_results ping $ping_test_host");
$ping_test   = new Process_Item("ping_to_file.bat $ping_test_host $ping_test_results");
$v_ping_test = new Voice_Cmd 'Run the ping test';
$v_ping_test -> set_info('Run a ping test to see if there is an internet connection');

#&tk_radiobutton('Ping Test', \$Save{ping_test_flag}, [1,0], ['On', 'Off']);

if (($Save{ping_test_flag} and $New_Minute and !($Minute % 10)) or
    said $v_ping_test) {
#   print_log "Starting connect check ping";
    unlink $ping_test_results;
    start  $ping_test;
}

if (done_now $ping_test) {
    my $ping_results = file_read $ping_test_results;
    if ($ping_results =~ /Reply from/) {
        if ($Save{ping_test_results} ne 'up') {
            $Save{ping_test_results} = 'up';
            speak "rooms=all The cable modem is back up";
        }
    }
    else {
        $Save{ping_test_results} = 'down';
        speak "rooms=all The cable modem just went down";
    }
    print_log "Internet is $Save{ping_test_results}";
}


