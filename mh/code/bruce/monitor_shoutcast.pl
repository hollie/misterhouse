# Category=Music
#
# Monitor a ShoutCast streaming audio server for winamp clients
#
# There are 2 ways to doing this:
#  - tail the log file with the said File_Item method
#  - connect a socket to the server
#
# If using the server method, you need to specify if you are
# using the older 1.0 version, as the format of the data change
# (newer versions us http data streams so you can monitor server
# status with a web browser).
# 
# I had problems with the server on 1.1 on linux.
# Version 1.5 works fine with the server method.
#
# If using the server method, add these parms to your mh.ini:
#    shoutcast_version=1.1
#    shoutcast_server=ip_address:8000
#    shoutcast_password=your_password
#
# If using the log method, you only need this parm:
#    shoutcast_log=d:\shoutcast\sc_serv.log
#
# Info on how to set up a shoutcast server is at:
#   http://mp3spy.com/server
#

                                # Check to see if the winamp shoutcast player is playing or connected
                                #  - this requires the httpq winamp plugin
$v_shoutcast_check  = new  Voice_Cmd 'Check the shoutcast player';
$v_shoutcast_check -> set_info('Will check the status the shoutcast winamp player and server');

$v_shoutcast_connect  = new  Voice_Cmd '[Connect,Disconnect] the shoutcast player';
$v_shoutcast_connect -> set_info('Use this to connect or disconnect the shoutcast winamp player from the shoutcast server');

my $sc_player_url;
if ($Reload) {
    $temp = 'localhost' unless $temp = $config_parms{shoutcast_player};
    $sc_player_url = "http://$temp:$config_parms{mp3_program_port}";
}    


                                # Monitor shoutcast player to make sure it stays connected to the server
                                #  - hmmm, maybe not.  If the sc computer is down, this get will hang mh :(
if (0 and $New_Minute) {
    $temp = filter_cr get "$sc_player_url/isplaying?p=$config_parms{mp3_program_password}";
    unless ($temp == 1) {
        print_log "Setting shoutcast player to play (flag was $temp)";
        print_log filter_cr get "$sc_player_url/play?p=$config_parms{mp3_program_password}";
        logit("$config_parms{data_dir}/logs/shoutcast_server.$Year_Month_Now.log", "restarted (was $temp)"); 
    }
    $temp = filter_cr get "$sc_player_url/shoutcast_status?p=$config_parms{mp3_program_password}";
    unless ($temp =~ /sent/) {
        print_log "Reconnecting shoutcast player (status was $temp)";
        print_log filter_cr get "$sc_player_url/shoutcast_connect?p=$config_parms{mp3_program_password}";
        logit("$config_parms{data_dir}/logs/shoutcast_server.$Year_Month_Now.log", "reconneced (was $temp)"); 
    }
}
    
if (said $v_shoutcast_check) {
                                # 0 => stopped, 1 => playing, 3 => paused
    $temp  = '  playing=' .  filter_cr get "$sc_player_url/isplaying?p=$config_parms{mp3_program_password}";
    $temp .= ',  time='    . int ((filter_cr get "$sc_player_url/getoutputtime?p=$config_parms{mp3_program_password}&a=0")/60000);
    $temp .= ' minutes,  status='  .  filter_cr get "$sc_player_url/shoutcast_status?p=$config_parms{mp3_program_password}";
    print_log "Shoutcast data: $temp";
}
if ($state = said $v_shoutcast_connect) {
    my $status = filter_cr get "$sc_player_url/shoutcast_status?p=$config_parms{mp3_program_password}";
    if ($state eq 'Connect') {
        if ($status =~ /sent/) {
            print_log "Shoutcast player already connected: $status";
        }
        else {
            $status = filter_cr get "$sc_player_url/shoutcast_connect?p=$config_parms{mp3_program_password}";
            print_log "Shoutcast connect status: $status";
        }
    }
    else {
        if ($status eq 'Disconnected.') {
            print_log "Shoutcast player already disconnected";
        }
        else {
            $status = filter_cr get "$sc_player_url/shoutcast_connect?p=$config_parms{mp3_program_password}";
            print_log "Shoutcast disconnect status: $status";
        }
    }        
}


return;                         # skip this  ... causing sc to abend ??






                                # Open the port ... check periodically, in case server was restarted.

$shoutcast_server = new Socket_Item(undef, undef, $config_parms{shoutcast_server});
$shoutcast_log    = new File_Item($config_parms{shoutcast_log});

$v_shoutcast_server = new  Voice_Cmd '[Start,Stop] the shoutcast server monitor';
$v_shoutcast_server-> set_info('The shoutcast server monitor announces when new listeners come');

if (($Startup or $New_Minute or said $v_shoutcast_server eq 'Start') and 
    $config_parms{shoutcast_server} and 
    !active $shoutcast_server and
    (state $v_shoutcast_server ne 'Stop')) {

    print_log "Starting a connection to the shoutcast server $config_parms{shoutcast_server}";
    start $shoutcast_server;

                                # Use HTTP with shoutcast 1.1+
    my $temp = <<eof;
GET /admin.cgi?pass=$config_parms{shoutcast_password}&mode=viewlog&viewlog=tail HTTP/1.1
User-Agent: Mozilla/4.0 (compatible; MisterHouse)
Connection: Keep-Alive
eof

                                # Use TAILLOG with shoutcast 1.0
    $temp = "TAILLOG $config_parms{shoutcast_password}" if $config_parms{shoutcast_version} eq '1.0';

#   print "\n\n dbx $config_parms{shoutcast_version} temp=$temp\n";
    set $shoutcast_server $temp;

}

stop $shoutcast_server if said $v_shoutcast_server eq 'Stop';


                                # Now monitor the server log
my (%shoutcast_clients);

if ($config_parms{shoutcast_server} and $state = said $shoutcast_server or  
    $config_parms{shoutcast_log}    and $New_Second and $state = said $shoutcast_log) {
    my ($ip_address, $status) = $state =~ /: ?(\S+)\] (starting stream|connection closed)/;
    my $shoutcast_users = $1 if $state =~ /\((\d+)\/\d+/; # looking for the first number here: (1/4) 
    print "db shoutcast users=$shoutcast_users ip=$ip_address status=$status data=\n$state...\n" if $status;
#   print_log "shoutcast users=$shoutcast_users ip=$ip_address status=$status";
     
                                # Do not echo when the shoutcast player connects between songs
    if ($status and -1 == index($config_parms{local_addresses}, $ip_address)) {
        my $domain_name = &net_domain_name($ip_address);
        my $msg;
        if ($status eq 'starting stream') {
            $msg = "DJ has a new listener ";
        }
        else {
            $msg = "DJ lost the listener ";
        }
        $domain_name = 'the winter house' if $domain_name =~ /192.168.0/; # Local domain
        $domain_name =~ s/[\d\.]/ /g; # Get rid of digits and dots
        $domain_name = 'unknown' if $domain_name =~ /^ *$/;
        $msg .=  "  from $domain_name.  " . plural_check "There are now $shoutcast_users listeners";

        my $time_since_last_visit = $Time - $shoutcast_clients{$domain_name}{time};
        print "db sc time $time_since_last_visit, $shoutcast_clients{$domain_name}{time}\n";
        $shoutcast_clients{$domain_name}{time} = $Time;
        $shoutcast_clients{$domain_name}{hits}++;
        
        if ($time_since_last_visit > 20 and $config_parms{internet_speak_flag} ne 'none') {
            speak "rooms=all $msg";
        }
        else {
            print_log $msg;
        }
#       display("$Time_Now: $msg", 0);
        logit("$config_parms{data_dir}/logs/shoutcast_server.$Year_Month_Now.log", "domain=$domain_name ip=$ip_address status=$status count=$shoutcast_users"); 
    }
}

#<07/17/99@20:17:43> [dest: 200.200.200.2] starting stream
#<07/17/99@20:33:43> [dest: 200.200.200.2] connection closed (sent 0 bytes total)
#<07/18/99@16:14:34> [dest] 1/4 users

#<01/15/100@21:48:33> [http:200.200.200.5] REQ:"/" (Mozilla/4.07 [en] (X11; I; Linux 2.2.10 i686))    
#<01/15/100@21:54:10> [dest: 200.200.200.3] starting stream (1/32)
#<01/15/100@21:54:21> [dest: 200.200.200.3] connection closed (sent 40878 bytes total) (0/32)
#<01/15/100@21:54:23> [dest: 200.200.200.3] starting stream (1/32)
#<01/15/100@21:54:31> [dest: 200.200.200.3] connection closed (sent 33388 bytes total) (0/32)
