# Category=Internet

                                # This deals with logging onto the net periodically/automatically


                                # Get net data periodically
if (time_cron('58 9,16 * * 0,6') or
    time_cron('15 6,17 * * 1-5')) {
    run_voice_cmd 'Get internet data';
}


                                # This really needs to be forked, as it can take a while, and mh will hang!
$timer_net_connect = new Timer;
$v_get_internet_data = new  Voice_Cmd('Get internet data');
$v_get_internet_data-> set_info('Download various internet data (e.g weather, time, tv).');
if (said  $v_get_internet_data) {
    print     "Getting internet data\n";
    print_log "Getting internet data";
    speak     "Getting internet data" unless $Save{sleeping_parents};

    unless (net_connect_check) {
        run_voice_cmd 'Log onto the net';
                                # Give the dialer time to connect, then try again
#       set $timer_net_connect 30, "speak 'Connected'; set $v_top10_list 'Get'";
        set $timer_net_connect 40, "run_voice_cmd 'Get internet data'";
    }
    else {
#       run_voice_cmd 'Send ip address to the web page';     # From internet_ip_update
#       run_voice_cmd 'Send ip address to the web servers';  # From internet_ip_update

        run_voice_cmd 'Set the clock via the internet';      # From time_info.pl
        run_voice_cmd 'Get internet weather data';           # From internet_data
        run_voice_cmd 'Get the top 10 list';                 # From internet_data
#       run_voice_cmd 'Get tv grid data for today';          # From tv_grid.pl
        run_voice_cmd 'Get tv grid data for the next 2 weeks';  # From tv_grid.pl
        run_voice_cmd 'Update stock quotes';                 # From stock.pl
#       run_voice_cmd 'Check for new Ceiva photos';          # From ceiva.pl
        run_voice_cmd 'Update the daily comic strips';       # From comics_dailystrip.pl
        run_voice_cmd 'Get on this day';                     # new_onthisday.pl

        print_log "Done with getting internet data";
    }
}

$v_logon_to_net = new  Voice_Cmd('[Log onto,dial] the net');
$v_logon_to_net-> set_info("Connect to the net using rasdial entry $config_parms{net_connect_entry} (windows only)");
set_icon $v_logon_to_net 'logon';
if (said  $v_logon_to_net) {
    if (net_connect_check) {
        speak "You are already logged on" unless $Save{sleeping_parents};
    }
    else {
        print     "Dialing the internet with $config_parms{net_connect_entry}";
        print_log "Dialing the internet with $config_parms{net_connect_entry}";
        speak "Dialing the internet" unless $Save{sleeping_parents};

                                # Hmmm, both of these hang :(  Well, we need to fork this process with run anyway
#       my $rc = &Win32::DUN::DialSelectedEntry($config_parms{net_connect_entry}, $config_parms{net_connect_name}, $config_parms{net_connect_password});
#       my $rc = `rasdial "$config_parms{net_connect_entry}" $config_parms{net_connect_name} $config_parms{net_connect_password}`;
#       print_log $rc;

        run qq[rasdial "$config_parms{net_connect_entry}" $config_parms{net_connect_name} $config_parms{net_connect_password}];
    }
} 

$v_logoff_net = new  Voice_Cmd('Log off the net');
set_icon $v_logoff_net 'logon';

if (said  $v_logoff_net) {
    if (net_connect_check) {
        run qq[rasdial /disconnect];
    }
    else {
        speak "You are not logged on";
    }
} 

