# Category = Internet
                                # Enable this code (with the tk radiobutton) to notify you 
                                # when your internet connection has come back up.
                                # Useful for those with cable modems that often go down for
                                # hours at a time.
                                # Note: we use a process item to 'fork' the ping, as it will
                                #       hang if the net connection is down.  

my $ping_test_host    = "24.2.1.71";
my $ping_test_results = "$config_parms{data_dir}/ping_results.txt";
$ping_test = new Process_Item("perl saveout $ping_test_results ping $ping_test_host");

&tk_radiobutton('Ping Test', \$Save{ping_test_flag}, [1,0], ['On', 'Off']);

if (($Save{ping_test_flag} and !$Save{sleeping_parents} and $New_Minute and !($Minute % 10)) or
    ($Save{test_data} eq 'ping' and $Save{test_data} = ' ')) {
    print "Starting connect check ping\n";
    unlink $ping_test_results;
    start  $ping_test;
}

if (done_now $ping_test) {
    my $ping_results = file_read $ping_test_results;
    print "Ping result: $ping_results\n";
    speak "rooms=all The cable modem is back up" if $ping_results =~ /Reply from/;
}


