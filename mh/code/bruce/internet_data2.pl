# Category=Internet

                                # This does NOT use a background process
$v_get_net1 = new  Voice_Cmd('Get ham list');
if (said $v_get_net1) {
    if (&net_connect_check) {
        print_log "Retrieving ham list";
        my $html = get 'http://lantz.com/htbin/cbs_today_bystate?MN';
        display $html, 0;
    }
    else {
        speak "Sorry, no net";
    }
}


                                # This DOES use a background process
my $f_get_url1 = "$config_parms{data_dir}/web/get_url1.html";
$v_get_url1 = new  Voice_Cmd('Get test url');
$p_get_url1 = new Process_Item("get_url http://www.wunderground.com/US/NJ/Newark.html $f_get_url1");
if (said $v_get_url1) {
    start $p_get_url1;
    speak "Retreiving test url";
}

if (done_now $p_get_url1) {
    my $html = file_read $f_get_url1;
    display $html;
}

