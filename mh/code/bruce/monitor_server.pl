#
# Category=Internet
#
# Monitor the mh Web server
#  - If you want to monitor an Apache server, use mh/bin/monitor_weblog
#

&tk_radiobutton('Internet Speak', \$config_parms{internet_speak_flag}, ['none', 'all']);

$http_server = new  Socket_Item(undef, undef, 'http');

my (%server_clients);

if (my $data = said $http_server) {

                                # Ignore the auto-refresh requests
    my ($request) = $data =~ /\/(\S+)/;
    next if $request =~ /^list/ or $request =~ /^speech/ or $request =~ /^print/ or $request =~ /^tk/ or $request =~ /^widgets/;

    my $client_ip = $main::Socket_Ports{http}{client_ip_address};

                                # Keep only the last 3 qualifiers (e.g. xyz.proxy.aol.com)
    my $client = $client_ip;
    $client = $1 if $client =~ /((\.?[^\.]*){1,3})$/;

#   print_log "web request from $client: $data";

    my $time_since_last_visit = time - $server_clients{$client}{time};
    $server_clients{$client}{time} = time;
    $server_clients{$client}{hits}++;

   play 'sound_click1.wav' if $time_since_last_visit > 5;

                                # Speak client name, if it is new and non-local
    if (!$Local_Addresses{$client_ip}) {
        $Save{web_hits_day}++ if $time_since_last_visit > 5;
        $Save{web_hits_hour}++ if $time_since_last_visit > 5;
        if ($time_since_last_visit > 3600) {
            my ($name, $name_short) = net_domain_name($client_ip);
            $client = $name_short if $name_short;
            $client =~ s/[\d\.]/ /g; # Get rid of digits and dots
            $client = 'unknown' if $client =~ /^ *$/;
            speak "Web hit from $client" unless $config_parms{internet_speak_flag} eq 'none' or $Save{sleeping_parents};
            $Save{web_clients_day}++;
            $Save{web_clients_hour}++;
        }
    }
}

if ($New_Day) {
    $Save{web_hits_day} = 0;
    $Save{web_clients_day} = 0;
}

if ($New_Hour) {
    $Save{web_hits_hour} = 0;
    $Save{web_clients_hour} = 0;
}

$v_client_hits = new  Voice_Cmd('Read the web server stats');
$v_client_hits-> set_info('Summarize how many people have visted the mh server in the last hour and day');
if (said $v_client_hits or
    (time_cron '58 19 * * * ' and $Save{web_hits_day} > 0 and $config_parms{internet_speak_flag} eq 'all')) {
    speak "rooms=all The MisterHouse server had $Save{web_hits_day} web hits from $Save{web_clients_day} clients since midnight";
}
if (said $v_client_hits or
    (!$Save{sleeping_parents} and time_cron '59 * * * * ' and $Save{web_hits_hour} > 0 and $config_parms{internet_speak_flag} eq 'all')) {
    speak "rooms=all $Save{web_hits_hour} web hits from $Save{web_clients_hour} clients in the last hour";
}

