# Category=Internet

#@ Dial-up networking (Windows only) and period refresh of TV grid data

# *** "Get internet data" should be deprecated at this point (see notes)

# Create trigger

if ($Reload) {
    &trigger_set("time_cron('57 9,16 * * 0,6') or time_cron('17 6,17 * * 1-5')", "run_voice_cmd('Get internet data')", 'NoExpire', 'get internet data') unless &trigger_get('get internet data');
}

sub uninstall_internet_logon {
	&trigger_delete('get internet data');
}

#noloop=start
	$v_get_internet_data = new  Voice_Cmd('Get internet data');
	$v_get_internet_data-> set_info('Download various internet data (e.g weather, time, tv).');
	if ($OS_win) {
		$v_logon_to_net = new Voice_Cmd('[Log on,Dial] the Internet');
		$v_logon_to_net-> set_info("Connect to the Internet using dial-up networking entry:$config_parms{net_connect_entry}");
		$v_logoff_net = new  Voice_Cmd('Log off the Internet');
	}


#       $Flags{internet_data_cmds}{'Send ip address to the web page'}++;     # From internet_ip_update
#       $Flags{internet_data_cmds}{'Send ip address to the web servers'}++;  # From internet_ip_update

#        $Flags{internet_data_cmds}{'Set the clock via the internet'}++;      # From time_info.pl
#       $Flags{internet_data_cmds}{'Get internet weather data'}++;           # From internet_data
#        $Flags{internet_data_cmds}{'Get the top 10 list'}++;                 # From internet_data
#       $Flags{internet_data_cmds}{'Get tv grid data for today'}++;          # From tv_grid.pl
        $Flags{internet_data_cmds}{'Get tv grid data for the next 2 weeks'}++;  # From tv_grid.pl
#       $Flags{internet_data_cmds}{'Update stock quotes'}++;                 # From stock.pl
#       $Flags{internet_data_cmds}{'Check for new Ceiva photos'}++;          # From ceiva.pl
#        $Flags{internet_data_cmds}{'Update the daily comic strips'}++;       # From comics_dailystrip.pl
#        $Flags{internet_data_cmds}{'Get on this day'}++;                     # From news_onthisday.pl
#noloop=stop
                                # This really needs to be forked, as it can take a while, and mh will pause!

				# *** Whole thing should be chucked at this point!
				# *** Down to TV grid update! (triggers exist for others.)

$timer_net_connect = new Timer;
if (said  $v_get_internet_data) {
    $v_get_internet_data->respond('Retrieving Internet data...');
    unless (net_connect_check) {
        run_voice_cmd 'Log onto the net'; # *** Not good (put code in a sub)
                                # Give the dialer time to connect, then try again
        set $timer_net_connect 40, "run_voice_cmd 'Get internet data'"; # *** Will loop forever on failure!
    }
    else {
	for my $cmd (sort keys %{$Flags{internet_data_cmds}}) {
		run_voice_cmd $cmd;
	}
        $v_get_internet_data->respond("Internet data retrieved.");
    }
}

if (said $v_logon_to_net) {
    if (net_connect_check) {
        $v_logon_to_net->respond("app=network I am already logged on to the Internet.");
    }
    else {
        $v_logon_to_net->respond("app=network Dialing the Internet...");

                                # Both of these hang
#       my $rc = &Win32::DUN::DialSelectedEntry($config_parms{net_connect_entry}, $config_parms{net_connect_name}, $config_parms{net_connect_password});
#       my $rc = `rasdial "$config_parms{net_connect_entry}" $config_parms{net_connect_name} $config_parms{net_connect_password}`;
#       print_log $rc;

	# *** RASAPI should work! Something wrong with DUN lib?

        run qq[rasdial "$config_parms{net_connect_entry}" $config_parms{net_connect_name} $config_parms{net_connect_password}];
    }
}

if (said $v_logoff_net) {
    if (net_connect_check) {
	# *** (see above)
        $v_logoff_net->respond("app=network Logging off the Internet...");
        run qq[rasdial /disconnect];
    }
    else {
        $v_logoff_net->respond("app=network I am not logged on.");
    }
}
