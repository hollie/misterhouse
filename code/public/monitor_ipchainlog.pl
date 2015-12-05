
# Category=Internet

# Monitor a linux ipchain log for web traffic

#  - If you want to monitor a Apache server, use mh/bin/monitor_weblog
#  - If you want to monitor mh server web traffic, use monitor_server.pl
#  - If you want to monitor router traffic, use mh/code/bruce/monitor_router.pl
#

my $ipchain_file = '//misterhouse/projects/logs/ipchains.log';

$check_ip_log = new Voice_Cmd "{Check the ip log,Check Nicks computer time}",
  "Ok, checking";
$check_ip_log->set_info(
    'Check to see if Nick has spent too much time gaming for today');

#Sun Dec  5 14:00:01 CST 1999 :: 200.200.200.2    TCP:110 24.2.1.70
#Sun Dec  5 14:00:01 CST 1999 :: 200.200.200.4   UDP:1034 192.215.33.68

$Save{nick_computer_time} = 0 if $New_Day;

if ( said $check_ip_log or ( $New_Minute and !( $Minute % 15 ) ) ) {
    print_log "Checking $ipchain_file";
    my $time_nick = 0;
    my $time_prev;
    for my $data ( file_read $ipchain_file) {
        my ( $time, $source, $port, $dest ) =
          ( split ' ', $data )[ 3, 7, 8, 9 ];

        #       print "db s=$source p=$port d=$dest\n";
        if ( $source eq '192.168.0.7' and $time ne $time_prev ) {

            #           next unless $port =~ /UDP/;  # let him surf, but not play ... games tend to use use UDP
            next if $port eq 'UDP:4000';    # icq stuff
            next if $port eq 'TCP:80';      # http
            next if $port eq 'TCP:21';      # ??
            $time_prev = $time;
            $time_nick += 5;

            #           print "db time=$time port=$port dest=$dest\n";
        }
    }

    #   $time_nick = time_diff 0, $time_nick * 60; # Convert to a text string
    if ( ( ( $Save{nick_computer_time} < $time_nick ) and $time_nick > 120 )
        or said $check_ip_log)
    {
        $Save{nick_computer_time} = $time_nick;
        my $msg = sprintf(
            "Notice, Nick has been on the computer for %2.1f hours today",
            $time_nick / 60 );

        #       run "mhsend -host house -speak rooms=all $msg";
        run "mhsend -host dm -speak $msg" unless $Save{sleeping_kids};
        speak "rooms=all $msg";
    }
}

