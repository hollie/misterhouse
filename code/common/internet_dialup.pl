# Category=Internet

#@ This deals with dialing the net periodically/automatically

$timer_net_connect = new Timer;
$net_connect       = new Generic_Item;

$v_logon_to_net = new Voice_Cmd('[Log onto,dial] the net');
$v_logon_to_net->set_info(
    "Connect to the net using rasdial entry $config_parms{net_connect_entry} (windows only)"
);

#set_icon $v_logon_to_net 'logon';
if ( said $v_logon_to_net) {
    if (net_connect_check) {
        $v_logon_to_net->respond("app=network I am already logged on");
    }
    else {

        # Both of these hang :(  Well, we need to fork this process with run anyway
        #       my $rc = &Win32::DUN::DialSelectedEntry($config_parms{net_connect_entry}, $config_parms{net_connect_name}, $config_parms{net_connect_password});
        #       my $rc = `rasdial "$config_parms{net_connect_entry}" $config_parms{net_connect_name} $config_parms{net_connect_password}`;
        #       print_log $rc;

        if ( !defined $config_parms{net_connect_entry}
            and $config_parms{net_connect_entry} )
        {    #name and password optional
            $v_logon_to_net->respond(
                "app=error Dial-up networking is not configured.");
        }
        else {
            $v_logon_to_net->respond("app=network Dialing the internet");
            set $net_connect 'connected', $v_logon_to_net
              if &ras_connect();    # *** BIG assumption!
        }
    }
}

$v_logoff_net = new Voice_Cmd('Log off the net');

#set_icon $v_logoff_net 'logon'; # *** Fix the graphics folder collision problem! This is a crutch.

if ( said $v_logoff_net) {
    if (net_connect_check) {
        if ( &ras_disconnect() ) {
            set $net_connect 'disconnected', $v_logoff_net;  # *** same as above
            $v_logoff_net->respond("app=network Logged off the Internet.");
        }
        else {
            $v_logoff_net->respond("app=network Logoff failed.");
        }
    }
    else {
        $v_logoff_net->respond("app=network I am not logged on.");
    }
}

if ($Reload) {
    &trigger_set(
        "time_cron('58 9,16 * * 0,6') or time_cron('15 6,17 * * 1-5')",
        "run_voice_cmd 'dial the net'",
        'NoExpire', 'dial the net'
    ) unless &trigger_get('dial the net');
}
