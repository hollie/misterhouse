

# Category=Internet

# Monitor syslog data sent by a NetGear RT311 or RT314 router
#  - http://www.netgear.com/products/routers.shtml#rt311
#  - track incoming web hits
#  - track online game time

#  - If you want to monitor a Apache server, use mh/bin/monitor_weblog
#  - If you want to monitor a linux ipchain log data, monitor_ipchainlog.pl
#  - If you want to monitor mh server web traffic, use monitor_server.pl

# Use these mh.ini parms
#   server_router_port=514
#   server_router_protocol=udp
#   server_router_datatype=raw


my %router_time_prev;
my $router_count = 0;
my $router_loops = 0;
my $router_server_hits = 0;
my %router_ip_times; 

$router = new Socket_Item(undef, undef, 'server_router');

$router_loops++;
if (my $packet = said $router) {

    $router_count++;
#   print "Router data: $packet\n";

    my ($ip_src, $ip_dst, $proto, $port_in, $port_out) = $packet =~
        /Src=(\S+) +Dst=(\S+) +(\S+) +spo=(\d+) +dpo=(\d+)/;

                                # Count incoming web hits
    if (($port_out eq '00080' or $port_out eq '08080') and !is_local_address($ip_src)) {

                                # Check time by ip name
        my $time_since_last_visit = $Time - $router_ip_times{$ip_src};
        $router_ip_times{$ip_src} = $Time;

                                # Count one any request as a hit, but no more than one per 3 seconds
        if ($time_since_last_visit > 2) {
            $router_server_hits++;
            $Save{server_hits_day}++;
            $Save{server_hits_hour}++;
        }

        if ($time_since_last_visit > 600) {

                                # Resolve from ip address to domain name
            my ($name, $name_short) = net_domain_name($ip_src);

                                # Check time by domain name
                                #   - We can get hits from a.proxy.aol.com, b.proxy.aol.com, etc
                                #     so lets only count aol hits
            $time_since_last_visit = $Time - $router_ip_times{$name_short};
            $router_ip_times{$name_short} = $Time;
            if ($time_since_last_visit > 600) {
                $name_short =~ s/[\d\.]/ /g; # Get rid of digits and dots
                $name_short = 'unknown' if $name_short =~ /^ *$/;

                if ($config_parms{internet_speak_flag} eq 'some' or
                    $config_parms{internet_speak_flag} eq 'all') {
                    speak "Web hit from $name_short";
                }
                else {
                    print_log "Web hit from $name_short";
                }
                $Save{server_clients_hour}++;
                $Save{server_clients_day}++;
            }
        }
    }

                                # Check for internet usage times
    &check_router_times('everquest')   if $proto eq 'UDP' and $ip_dst eq '192.168.0.7';
    &check_router_times('half life')   if $proto eq 'UDP' and $ip_dst eq '192.168.0.3';
    if ($proto eq 'TCP' and $port_in == 80) {
        &check_router_times('nick web')    if $ip_dst eq '192.168.0.7';
        &check_router_times('zack web')    if $ip_dst eq '192.168.0.9';
        &check_router_times('house web')   if $ip_dst eq '192.168.0.2';
    }

}

                                # Keep an eye on computer game time
$check_web_time  = new Voice_Cmd 'Check [everquest,web_nick,web_house, web_zack] time';
$check_web_time -> set_info('Check to see who spent how much time was spent on the internet for the day');
tie_event $check_web_time 'speak sprintf "Todays $state time is %2.1f hours",  $Save{"router_time_$state"} / 60';

                                # Reset times once a day
if ($New_Day) {
    for my $key (keys %Save) {
        $Save{$key} = 0 if $key =~ /^router_time/;
    }
}

sub check_router_times {
    my ($name) = @_;

    if ($Time - $router_time_prev{$name} > 60) {
        $Save{"router_time_$name"}++;
        my $hour = round $Save{"router_time_$name"}/60, 1;
        $router_time_prev{$name} = $Time;
        print_log "$name time: $hour hours";
#        print_log "Web $name time: $hour hours" unless $Save{"router_time_$name"} % 10;
        if ($hour > 2 and
            ($Save{"router_time_$name"} - $Save{"router_time_prev_$name"}) > 15) {
            $Save{"router_time_prev_$name"} = $Save{"router_time_$name"};
            my $msg = "Notice, $name time is $hour hours";
            run "mhsend -host dm -speak $msg" unless $Save{sleeping_kids};
            speak "rooms=all $msg";
            logit "$config_parms{data_dir}/logs/$name.$Year_Month_Now.log",  $msg;
        }
    }
}

                                # Beep when there is server activity
if ($New_Second and !($Second % 5) and $router_server_hits and $config_parms{internet_speak_flag} eq 'all') {
    speak 'sound_glurp1.wav';
#   speak 'sound_gleep1.wav';
#   speak 'sound_glurp1.wav';
#    print "db hits=$router_server_hits\n";
    $router_server_hits = 0;
}
                                # Montior how busy the router is for all traffic
if ($New_Hour) {
    my $router_overload = int 100 * $router_count / $router_loops;
    $router_count = sprintf '%4.1f', $router_count / 1000;
    my $msg = "Router had $router_count k-packets (${router_overload}% packets-per-pass) of traffic in the last hour";
    logit "$config_parms{data_dir}/logs/router.$Year_Month_Now.log", $msg;
    print_log $msg;
    $router_count = 0;
    $router_loops = 0;
}

                                # Summarize hourly and daily hits
if (time_cron '1 * * * *') {
    if ($Save{server_clients_hour} > 2) {
        my $msg = "Notice , there were $Save{server_hits_hour} web hits from $Save{server_clients_hour} clients in the last hour";
        ($config_parms{internet_speak_flag} ne 'none') ?  speak "rooms=all $msg" : print_log $msg;
    }
    $Save{server_hits_hour}    = 0;
    $Save{server_clients_hour} = 0;
}
elsif (time_cron '1 20 * * *') {
    speak "rooms=all Notice , there were $Save{server_hits_day} web hits from $Save{server_hits_day} clients in the last day"
        if $Save{server_hits_day} > 5;
    $Save{server_hits_day}    = 0;
    $Save{server_clients_day} = 0;
}

                                # Allow for router reboot
$router_reboot = new Voice_Cmd 'Reboot the router';
$router_reboot-> set_info('Sends commands to the router telnet port to walk the menus to reboot the router');
$router_client = new Socket_Item(undef, undef, $config_parms{router_address} . ":23", 'router', 'tcp', 'raw');

if (said $router_reboot) {
    print_log 'Rebooting the router';
    set_expect $router_client (Password => $config_parms{router_password}, Number => 24, Number => 4, Number => 11); 
}


# Outgoing web requests
#Router data: <181>winter_router: IP[Src=64.57.169.177   Dst=192.168.0.2 TCP spo=00080  dpo=03632]}S05>R01nN>R02nF
#Router data: <181>winter_router: IP[Src=63.211.153.95   Dst=192.168.0.7 TCP spo=00080  dpo=01168]}S05>R01nN>R02nF

# Incomming web hits
#Router data: <181>winter_router: IP[Src=168.191.93.23   Dst=192.168.0.5 TCP spo=02248  dpo=00080]}S05>R01nN>R02nF
#Router data: <181>winter_router: IP[Src=208.160.84.55   Dst=192.168.0.2 TCP spo=20307  dpo=08080]}S05>R01nN>R02nF

# Everquest logon
#Router data: <181>winter_router: IP[Src=64.37.130.25    Dst=192.168.0.7 TCP spo=07000  dpo=01237]}S05>R01nN>R02nF

# Everquest on
#Router data: <181>winter_router: IP[Src=208.236.12.62   Dst=192.168.0.7 UDP spo=05999  dpo=01239]}S05>R01nN>R02nF
#Router data: <181>winter_router: IP[Src=192.215.33.89   Dst=192.168.0.7 UDP spo=01065  dpo=04296]}S05>R01nN>R02nF

# Halflife on
#Router data: <181>winter_router: IP[Src=203.96.152.2    Dst=192.168.0.3 UDP spo=27300  dpo=27005]}S05>R01nN>R02nF
#Router data: <181>winter_router: IP[Src=203.96.152.2    Dst=192.168.0.9 UDP spo=27300  dpo=27005]}S05>R01nN>R02nF

# Everquest logoff
#Router data: <181>winter_router: IP[Src=208.236.12.62   Dst=192.168.0.7 UDP spo=05999  dpo=01245]}S05>R01nN>R02nF
#Router data: <181>winter_router: IP[Src=192.168.100.1   Dst=224.0.0.1 Proto=2]}S05>R01nN>R02nF

# Other
#Router data: <181>winter_router: IP[Src=198.186.203.35  Dst=192.168.0.5 TCP spo=56827  dpo=00025]}S05>R01nN>R02nF
#Router data: <181>winter_router: IP[Src=12.24.250.39    Dst=192.168.0.5 UDP spo=00053  dpo=03908]}S05>R01nN>R02nF
#Router data: <181>winter_router: IP[Src=205.188.4.7     Dst=192.168.0.2 TCP spo=05190  dpo=03650]}S05>R01nN>R02nF
#Router data: <181>winter_router: IP[Src=152.163.241.191 Dst=192.168.0.2 TCP spo=05190  dpo=03651]}S05>R01nN>R02nF

# Ping
#Router data: <181>winter_router: IP[Src=24.213.60.73    Dst=192.168.0.2 ICMP]}S05>R01nN>R02nF

# Mail check
#             <181>winter_router: IP[Src=204.212.170.6   Dst=192.168.0.2 TCP spo=00110  dpo=02017]}S05>R01nN>R02nF
