
# Category = Internet

=begin comment

 Monitor data sent by a NetGear (RT311 or RT314) or Linksys routers
  - track incoming web hits
  - track online game time

 Related monitors:
   Apache server traffic:   mh/bin/monitor_weblog
   Linux ipchain log data:  mh/code/public/monitor_ipchainlog.pl
   mh server web traffic:   mh/code/public/monitor_server.pl

 Use these mh.ini parms
   server_router_port=514   # If NetGear
   server_router_port=162   # If Linksys
   server_router_protocol=udp
   server_router_datatype=raw

 To enable loging on a Linksys, set Enable Access log on the log tab.
 Leaving 'Send log to: ...255' will let any local computer monitor the log

 To enable logging on a Netgear rounter, telnet router, 
  select option 24 -> 3 -> 2, then fill it in something like this:
 Menu 24.3.2 - System Maintenance - UNIX Syslog

    Syslog:
    Active= Yes
    Syslog IP Address= 192.168.0.2
    Log Facility= Local 6

    Types:
    CDR= Yes
    Packet triggered= Yes
    Filter log= Yes
    PPP log= Yes

=cut

my %router_time_prev;
my $router_count = 0;
my $router_loops = 0;
my $router_server_hits = 0;
my %router_ip_times; 

$router = new Socket_Item(undef, undef, 'server_router');

$router_loops++;
if (my $packet = said $router) {

#   print "db router packet: $packet\n";

    $router_count++;

    my ($dir, $ip_src, $ip_dst, $proto, $port_in, $port_out);

                                # Netgear
    if ($config_parms{server_router_port} == 514) {
#Router data: <181>winter_router: IP[Src=168.191.93.23   Dst=192.168.0.5 TCP spo=02248  dpo=00080]}S05>R01nN>R02nF
        ($ip_src, $ip_dst, $proto, $port_in, $port_out) = $packet =~
            /Src=(\S+) +Dst=(\S+) +(\S+) +spo=(\d+) +dpo=(\d+)/;
    }
                                # Linksys
    else {
#Router data: 0é p?? .... +????Ps?? ?é +@out 192.168.0.2 8080 24.159.204.248 10325
        $proto = 'TCP'; # Linksys only does TCP :( 
        ($dir, $ip_src, $port_in, $ip_dst, $port_out) = $packet =~
            /\@(in|out) (\S+) (\S+) (\S+) (\S+)/;
    }

    print "Router: $proto $port_in \t-> $port_out\t$ip_src \t-> $ip_dst \n"
        if $config_parms{debug} eq 'router';

                                # Count incoming web hits
#  if (($port_out == 80 or $port_out == 8080)) {
   if (!is_local_address($ip_src)) {

                                # Check time by ip name
        my $time_since_last_visit = $Time - $router_ip_times{$ip_src};
        $router_ip_times{$ip_src} = $Time;

                                # Count one any request as a hit, but no more than one per 3 seconds
        if ($time_since_last_visit > 2) {
            $router_server_hits++;
            $Save{server_hits_day}++;
            $Save{server_hits_hour}++;
        }

        if ($time_since_last_visit > 6) {
#       if ($time_since_last_visit > 600) {
#           my ($name, $name_short) = net_domain_name $ip_src;
            net_domain_name_start 'router', $ip_src; # Resolve from ip address to domain name ... in the background
        }
    }

                                # Check for internet usage times on kid computers
    &check_router_times('nick_web')    if $proto eq 'TCP' and $ip_dst eq '192.168.0.9';
#   &check_router_times('nick_game')   if $proto eq 'UDP' and $ip_dst eq '192.168.0.9' and $port_in != 53;
#   play "sound_beep1.wav"             if $proto eq 'UDP' and $ip_dst eq '192.168.0.9' and $port_in != 53;

}
                                # Do not announce visits from these robots
my %router_ignore_list =  map {$_, 1} qw(inktomi netmind netwhistle northernlight singingfish googlebot avantgo inktomisearch);

                                # This is true when the background dns request finishes
if (my ($name, $name_short) = net_domain_name_done 'router') {

                                # Check time by domain name
                                #   - We can get hits from a.proxy.aol.com, b.proxy.aol.com, etc
                                #     so lets only count aol hits
    my $time_since_last_visit = $Time - $router_ip_times{$name_short};
    $router_ip_times{$name_short} = $Time;
    if ($time_since_last_visit > 600) {
        $name_short =~ s/[\d\.]/ /g; # Get rid of digits and dots
        $name_short = 'unknown' if $name_short =~ /^ *$/;
        
        print_log "Web hit from $name_short: $name";
        if ($config_parms{internet_speak_flag} eq 'some' or
            $config_parms{internet_speak_flag} eq 'all') {
            unless ($router_ignore_list{$name_short}) {
                play 'router_new'; # Defined in event_sounds.pl
                speak voice => 'sam', text => $name_short unless $name_short =~ /unknown/;
            }
        }
        $Save{server_clients_hour}++;
        $Save{server_clients_day}++;
    }
}

                                # Beep when there is server activity
if (new_second 10 and $router_server_hits and $config_parms{internet_speak_flag} eq 'all') {
    print_log "Router hits: $router_server_hits\n";
                                # Play a sound, louder for more hits
    my $volume = int 100 * $router_server_hits / 20;
    play file => 'router_hit', volume => $volume; # Defined in event_sounds.pl
    $router_server_hits = 0;
}
                                # Monitor how busy the router is for all traffic
if (new_minute 10) {
    my $router_overload = int 100 * $router_count / $router_loops;
#   $router_count = sprintf '%4.1f', $router_count / 1000;
    my $msg = "Router had $router_count packets (${router_overload}% packets-per-pass) of traffic in the last hour";
    logit "$config_parms{data_dir}/logs/router.$Year_Month_Now.log", $msg;
    print_log $msg;
    $router_count = 0;
    $router_loops = 0;
}

                                # Summarize hourly and daily hits
if (time_cron '1 * * * *') {
    if ($Save{server_clients_hour} > 2) {
        my $msg = "voice=male Notice , there were $Save{server_hits_hour} web hits from $Save{server_clients_hour} clients in the last hour";
        ($config_parms{internet_speak_flag} ne 'none') ?  speak $msg : print_log $msg;
    }
    $Save{server_hits_hour}    = 0;
    $Save{server_clients_hour} = 0;
}
elsif (time_cron '1 20 * * *') {
    speak "voice=sam Notice , there were $Save{server_hits_day} web hits from $Save{server_hits_day} clients in the last day"
        if $Save{server_hits_day} > 5;
    $Save{server_hits_day}    = 0;
    $Save{server_clients_day} = 0;
}


                                # Keep an eye on computer game time
#$check_web_time  = new Voice_Cmd 'Check [nick_game,nick_web,house_web,zack_web] time';
#$check_web_time -> set_info('Check to see who spent how much time was spent on the internet for the day');
#$check_web_time -> set_authority('anyone');
#tie_event $check_web_time 'speak sprintf "voice=male Todays $state time is %2.1f hours",  $Save{"router_time_$state"} / 60';

#$check_web_time2  = new Voice_Cmd 'Display [nick_web,nick_game,house_web,zack_web] time log';
#$check_web_time2 -> set_info('Review the internet usage logs');
#tie_event $check_web_time2 'display "$config_parms{data_dir}/logs/$state.$Year_Month_Now.log", 200, "$state log", "fixed"';
#tie_event $check_web_time2 'display "$config_parms{data_dir}/logs/$state.totals.log",       200, "$state totals", "fixed"';

#f ($New_Day) {
if (time_now "11:59 pm") {
    for my $name (('halflife', 'nick_web', 'nick_game')) {
        if ($Save{"router_time_$name"}) {
            $Save{"router_total_time_$name"} += $Save{"router_time_$name"};
            my $hour = round $Save{"router_time_$name"}       / 60, 1;
            my $hourt= round $Save{"router_total_time_$name"} / 60, 1;
            my $msg = "Notice, $name time is $hour hours (total: $hourt)";
            logit "$config_parms{data_dir}/logs/$name.totals.log", "---------------------" if $New_Week;
            logit "$config_parms{data_dir}/logs/$name.totals.log", $msg;
        }
    }
}

                                # Reset times once a day
if ($New_Day) {
    for my $key (keys %Save) {
        $Save{$key} = 0 if $key =~ /^router_time/;
    }
    display "Reset data for %Save";
}


                                # Allow for Neatgear outer reboot
$router_reboot = new Voice_Cmd 'Reboot the router';
$router_reboot-> set_info('Sends commands to the router telnet port to walk the menus to reboot the router');
$router_client = new Socket_Item(undef, undef, $config_parms{router_address} . ":23", 'router', 'tcp', 'raw');

if (said $router_reboot) {
    print_log 'Rebooting the router';
    set_expect $router_client (Password => $config_parms{router_password}, Number => 24, Number => 4, Number => 11); 
}


sub check_router_times {
    my ($name) = @_;

    if ($Time - $router_time_prev{$name} > 60) {
        $Save{"router_time_$name"}++;
        my $i = $Save{"router_time_$name"};
        my $hour = round $Save{"router_time_$name"}/60, 1;
        $router_time_prev{$name} = $Time;
#       print_log "$name time: $hour hours";
#       print_log "Web $name time: $hour hours" unless $Save{"router_time_$name"} % 10;
        if ($Save{"router_time_$name"} - $Save{"router_time_prev_$name"} > 15) {
            $Save{"router_time_prev_$name"} = $Save{"router_time_$name"};
            my $name2 = $name;
            $name2 =~ tr/_/ /;
            my $msg = "Notice, $name2 time is $hour hours";
            if ($hour > 2) {
                run "mhsend -host dm -speak $msg";
                speak voice => 'sam', rooms => 'all', text => $msg;
            }
            elsif (time_greater_than '10 PM' and ($Day ne 'Fri' and $Day ne 'Sat')) {
                speak "voice=>sam rooms=nick mode=unmuted Notice, $name2 detected after hours";
            }
            logit "$config_parms{data_dir}/logs/$name.$Year_Month_Now.log",  $msg;
        }
    }
}

