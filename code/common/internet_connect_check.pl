# Category = Internet

#@ Uses ping to monitor if your internet connection is up or down
#@ Useful for those with cable or dsl modems that often go down for hours at a time

# Enable this code (with 'Ping test on') to notify you
# when your internet connection goes up or down.
# Useful for those with cable or dsl modems that often go
# down for hours at a time.
# Note: we use a process item to 'fork' the ping, as it
#       might hang if the net connection is down.

my $ping_test_results = "$config_parms{data_dir}/ping_results.txt";
my $ping_test_cmd     = ($OS_win) ? 'ping -n 1 ' : 'ping -c 1 ';
my $ping_test_host    = 'google.com';
$ping_test = new Process_Item $ping_test_cmd . $ping_test_host;
$ping_test->set_output($ping_test_results);
$v_ping_test = new Voice_Cmd 'Ping test [on,off,run]';
$v_ping_test->set_info(
    "Run a ping test to see if there is an internet connection. Set to 'On' to run it periodically.  'Run' runs it once."
);

#&tk_radiobutton('Ping Test', \$Save{ping_test_flag}, [1,0], ['On', 'Off']);

if ( said $v_ping_test) {
    my $state = $v_ping_test->{state};
    $Save{ping_test_flag} = ( $state eq 'on' ) ? 1 : 0 if $state ne 'run';
    $v_ping_test->respond("app=network Setting ping test to $state.");
    &ping_test($state);
}

sub ping_test {
    my $state = shift;
    unlink $ping_test_results;
    start $ping_test unless $state eq 'off';
    print "Starting ping test" if $Debug{ping};

}

# Check more often if it is down, to cut down on traffic
if ( $Save{ping_test_flag}
    and ( new_minute( $Save{ping_test_results} eq 'up' ? 10 : 2 ) ) )
{
    &ping_test();
}

# Win2k: Pinging 24.213.60.73 with 32 bytes of data:
#    Reply from 192.168.0.2: bytes=32 time<10ms TTL=128
#    Packets: Sent = 1, Received = 1, Lost = 0 (0% loss),
#  Failed ping
#    Request timed out.
#    Packets: Sent = 1, Received = 0, Lost = 1 (100% loss)
# Linux:
#   64 bytes from 127.0.0.1: icmp_seq=0 ttl=255 time=0.3 ms
#    1 packets transmitted, 1 packets received, 0% packet loss
#  Failed ping
#    1 packets transmitted, 0 packets received, 100% packet loss

$internet_connection = new Generic_Item;
$internet_connection->set_states( 'up', 'down' );

if ( done_now $ping_test) {
    my $ping_results = file_read $ping_test_results;
    $Save{ping_test_results} = 'up' unless $Save{ping_test_results};
    if ( $ping_results =~ /ttl=/i ) {
        if (    $Save{ping_test_results} eq 'down'
            and $Save{ping_test_count} >= 3 )
        {
            my $time_diff = time_diff $Save{ping_test_time}, $Time, 'minute',
              'numeric';
            logit "$config_parms{data_dir}/logs/internet_down.log",
              "Net up.  Was $Save{ping_test_results}.  Downtime: $time_diff";
            $time_diff = time_diff $Save{ping_test_time}, $Time, 'minute';

            #           play file => 'timer', mode => 'unmute'; # Set in event_sounds.pl
            $v_ping_test->respond(
                "app=network The internet connection is back up after $time_diff"
            );
            display
              text =>
              "The internet connection is back up  (was $Save{ping_test_results}).  Time=$time_diff",
              time        => 0,
              window_name => 'Internet Connect Check',
              append      => 'bottom';
        }
        set $internet_connection 'up', $v_ping_test;
        $Save{ping_test_results} = 'up';
    }
    else {
        # Has to be down 3 times in a row before we get worried
        if ( $Save{ping_test_results} eq 'up' ) {
            $Save{ping_test_results} = 'down';
            $Save{ping_test_count}   = 1;
            $Save{ping_test_time}    = $Time;
        }
        elsif ( ++$Save{ping_test_count} == 3 ) {
            $v_ping_test->respond(
                "app=network Internet connection just went down.");
            display
              text        => 'The internet connection is down',
              time        => 0,
              window_name => 'Internet Connect Check',
              append      => 'bottom';
            logit "$config_parms{data_dir}/logs/internet_down.log", "Net down";
        }
        set $internet_connection 'down', $v_ping_test;
        print_log "Internet is $Save{ping_test_results}";
    }
    print "Ping results: $Save{ping_test_results} results=$ping_results"
      if $Debug{ping};
}
