# Category=Internet

#@ This deals with dialing the net periodically/automatically

$timer_net_connect = new Timer;
$net_connect = new Generic_Item;

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
        set $net_connect 'connected';
    }
} 

$v_logoff_net = new  Voice_Cmd('Log off the net');
set_icon $v_logoff_net 'logon';

if (said  $v_logoff_net) {
    if (net_connect_check) {
        run qq[rasdial /disconnect];
        set $net_connect 'disconnected';
    }
    else {
        speak "You are not logged on";
    }
} 

if ($Reload and $Run_Members{'trigger_code'}) { 
    eval qq(
        &trigger_set("time_cron('58 9,16 * * 0,6') or time_cron('15 6,17 * * 1-5')", "run_voice_cmd 'dial the net'", 'NoExpire', 'dial the net') 
          unless &trigger_get('dial the net');
    );
}
