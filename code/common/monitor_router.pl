
# Category = Internet

#@ Monitors Linksys, NetGear or Draytek Vigor router traffic.   Set these mh.ini parms:
#@ server_router_type=netgear (or linksys for Linksys, draytek for Draytek Vigor 2300)
#@ server_router_port=162 (use 514 for NetGear and Draytek), server_router_protocol=udp, and server_router_datatype=raw.

=begin comment

 Monitor data sent by a NetGear (RT311 or RT314), Draytek Vigor 2300 or Linksys routers
  - track incoming web hits
  - track online game time

 Related monitors:
   Apache server traffic:   mh/bin/monitor_weblog
   Linux ipchain log data:  mh/code/public/monitor_ipchainlog.pl
   mh server web traffic:   mh/code/public/monitor_server.pl

 Use these mh.ini parms
   server_router_type=netgear   # If NetGear
   server_router_type=linksys   # If Linksys
   server_router_type=draytek   # If Draytek
   server_router_port=514   # If NetGear/Draytek
   server_router_port=162   # If Linksys
   server_router_protocol=udp
   server_router_datatype=raw

 Optionally set this parm to ignore frequent visitors:
   router_ignore_list = inktomi netmind netwhistle northernlight singingfish googlebot avantgo inktomisearch

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

 To enable logging on a Draytek Vigor router, from the admin webpage,
  select System Management -> Syslog Setup, click Enable
  and enter the IP address of your misterhouse server, port 514

=cut

my %router_time_prev;
my $router_count       = 0;
my $router_loops       = 0;
my $router_server_hits = 0;

use vars '%router_ip_times';    # This will save data between reloads

$router = new Socket_Item( undef, undef, 'server_router' );

$router_loops++;
if ( my $packet = said $router) {

    $router_count++;

    my ( $dir, $ip_src, $ip_dst, $proto, $port_in, $port_out );

    # Grandfather old usage
    unless ( $config_parms{server_router_type} ) {
        $config_parms{server_router_type} =
          ( $config_parms{server_router_port} == 514 ) ? 'netgear' : 'linksys';
    }

    # Netgear
    if ( $config_parms{server_router_type} eq "netgear" ) {

        #Router data: <181>winter_router: IP[Src=168.191.93.23   Dst=192.168.0.5 TCP spo=02248  dpo=00080]}S05>R01nN>R02nF
        ( $ip_src, $ip_dst, $proto, $port_in, $port_out ) =
          $packet =~ /Src=(\S+) +Dst=(\S+) +(\S+) +spo=(\d+) +dpo=(\d+)/;
    }

    # Draytek
    elsif ( $config_parms{server_router_type} eq "draytek" ) {

        # Draytek Vigor 2300 ADSL Router
        # Incoming:
        #local2:info Apr 29 04:46:10 zappa-router: Open port: 63.139.99.163:43465 -> 192.168.100.3:80 (TCP) Web
        # Outgoing:
        #local2:info Apr 29 22:12:42 zappa-router: Local User: 192.168.100.4:2428 -> 66.230.141.102:80 (TCP)Web

        ( $dir, $ip_src, $port_in, $ip_dst, $port_out, $proto ) = $packet =~
          /(Open port|Local User): (\S+):(\S+) -> (\S+):(\S+) \((\S+)\)/;
    }

    # Linksys
    elsif ( $config_parms{server_router_type} eq "linksys" ) {

        #Router data: 0é p?? .... +????Ps?? ?é +@out 192.168.0.2 8080 24.159.204.248 10325
        $proto = 'TCP';    # Linksys only does TCP :(
        ( $dir, $ip_src, $port_in, $ip_dst, $port_out ) =
          $packet =~ /\@(in|out) (\S+) (\S+) (\S+) (\S+)/;
    }

    print "Router: $proto $port_in \t-> $port_out\t$ip_src \t-> $ip_dst \n"
      if $Debug{router};

    # Count incoming traffic from non-local addresses
    #  if (($port_out == 80 or $port_out == 8080)) {
    if ( !is_local_address($ip_src) ) {

        # Cache visits by first 3 fields (e.g. aol proxy will have the same first 3 fields)
        my $ip_src2 = $ip_src;
        $ip_src2 =~ s/\.\d+?$//;

        # Check time by ip name
        my $time_since_last_visit = $Time - $router_ip_times{$ip_src2};
        $router_ip_times{$ip_src2} = $Time;

        # Count one any request as a hit, but no more than one per 3 seconds
        if ( $time_since_last_visit > 2 ) {
            $router_server_hits++;
            $Save{server_hits_day}++;
            $Save{server_hits_hour}++;
        }

        #       if ($time_since_last_visit > 6) {
        if ( $time_since_last_visit > 600 ) {

            #           my ($name, $name_short) = net_domain_name $ip_src;
            print_log "Web hit port=$port_out ip=$ip_src -> $ip_dst";
            play 'router_new';    # Defined in event_sounds.pl
            net_domain_name_start 'router', $ip_src
              ;   # Resolve from ip address to domain name ... in the background
        }
    }

    # Check for internet usage times on kid computers
    &check_router_times( $proto, $ip_dst );

}

# This can be customized in user code (e.g. code/bruce/monitor_router_bruce.pl)
# to log and/or monitor times (e.g. check on internet computer game traffic).
sub check_router_times {
    my ( $proto, $ip ) = @_;

    #   print "db $proto router hit to $ip\n";
    return;
}

# Do not announce visits from these robots
$config_parms{router_ignore_list} =
  'inktomi netmind netwhistle northernlight singingfish googlebot avantgo inktomisearch'
  unless $config_parms{router_ignore_list};
my %router_ignore_list = map { $_, 1 } split ' ',
  $config_parms{router_ignore_list};

# This is true when the background dns request finishes
if ( my ( $name, $name_short ) = net_domain_name_done 'router' ) {

    # Check time by domain name
    #   - We can get hits from a.proxy.aol.com, b.proxy.aol.com, etc
    #     so lets only count aol hits
    my $time_since_last_visit = $Time - $router_ip_times{$name_short};
    $router_ip_times{$name_short} = $Time;
    if ( $time_since_last_visit > 600 ) {
        $name_short =~ s/[\d\.]/ /g;    # Get rid of digits and dots
        $name_short = 'unknown' if $name_short =~ /^ *$/;

        print_log "Web hit from $name_short:  $name";
        if (   $config_parms{internet_speak_flag} eq 'some'
            or $config_parms{internet_speak_flag} eq 'all' )
        {
            unless ( $router_ignore_list{$name_short} ) {
                speak
                  app  => 'router',
                  text => $name_short
                  unless $name_short =~ /unknown/;
            }
        }
        $Save{server_clients_hour}++;
        $Save{server_clients_day}++;
    }
}

# Beep when there is server activity
if (    new_second 10
    and $router_server_hits
    and $config_parms{internet_speak_flag} eq 'all' )
{
    print_log "Router hits: $router_server_hits\n";

    # Play a sound, louder for more hits
    my $volume = int 100 * $router_server_hits / 20;
    play file => 'router_hit', volume => $volume;   # Defined in event_sounds.pl
    $router_server_hits = 0;
}

# Monitor how busy the router is for all traffic
if ( new_minute 60 ) {
    my $router_overload = int 100 * $router_count / $router_loops;

    #   $router_count = sprintf '%4.1f', $router_count / 1000;
    my $msg =
      "Router had $router_count packets (${router_overload}% packets-per-pass) of traffic in the last hour";
    logit "$config_parms{data_dir}/logs/router.$Year_Month_Now.log", $msg;
    print_log $msg;
    $router_count = 0;
    $router_loops = 0;
}

# Summarize hourly and daily hits
if ( time_cron '1 * * * *' ) {
    if ( $Save{server_clients_hour} > 2 ) {
        my $msg =
          "voice=female3 Notice, there were $Save{server_hits_hour} web hits from $Save{server_clients_hour} clients in the last hour";
        ( $config_parms{internet_speak_flag} ne 'none' )
          ? speak $msg
          : print_log $msg;
    }
    $Save{server_hits_hour}    = 0;
    $Save{server_clients_hour} = 0;
}
elsif ( time_cron '1 20 * * *' ) {
    speak
      "app=router Notice, there were $Save{server_hits_day} web hits from $Save{server_clients_day} clients in the last day"
      if $Save{server_hits_day} > 5;
    $Save{server_hits_day}    = 0;
    $Save{server_clients_day} = 0;
}

# Allow for rebooting of various routers

$v_router_reboot = new Voice_Cmd 'Reboot the router';
$v_router_reboot->set_info(
    'Sends commands to the router telnet port to walk the menus to reboot the router'
);
$router_client =
  new Socket_Item( undef, undef, $config_parms{router_address} . ":23",
    'router', 'tcp', 'raw' );

if ( said $v_router_reboot) {
    $v_router_reboot->respond('Rebooting the router...');
    if ( lc $config_parms{server_router_type} eq 'linksys' ) {

        # Press 'Apply' on the harmless Log menu.  Apply on any menu seems to restart the router
        my $cmd =
          qq[get_url "http://$config_parms{router_address}/Gozila.cgi?rLog=on&trapAddr3=255&Log=1" ];
        $cmd .= qq[-userid admin -password $config_parms{router_password}];
        run $cmd;
    }
    else {
        # This walks down the NetGear menu to the reboot option
        set_expect $router_client (
            Password => $config_parms{router_password},
            Number   => 24,
            Number   => 4,
            Number   => 11
        );
    }
}
