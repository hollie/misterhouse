# Category=Other

# This shows an example on how to act as a client to a socket server
# to the mh/code/common/mhsend_server.pl, so for example
# you could have 2 mh boxes, both running this code (and mhsend_server)
# sending and receiving commands to each other.

# Change $clint1_adress to IP address or name of server, and port
# 8084 is the default port in mh.ini

my $client1_address = '192.168.0.2:8084';
$client1 = new Socket_Item( undef, undef, $client1_address );

$v_test_client1 = new Voice_Cmd(
    "Run socket test: [display,speak,run,log,file,use mhsend command]");

if ( $state = said $v_test_client1) {
    print_log "Running client test $state";
    if ( $state eq 'display' ) {
        start $client1;

        # This message will be diplayed on the host for 10 seconds
        set $client1
          "display 10\nAuthorization: Basic none\n\nHello from mh at $Time_Now";
        stop $client1;
    }

    elsif ( $state eq 'speak' ) {
        start $client1;
        set $client1
          "speak\nAuthorization: Basic none\n\nThis is a test of one misterhouse computer sending a command to another. The time now is $Time_Now";
        stop $client1;
    }

    elsif ( $state eq 'run' ) {
        start $client1;
        set $client1
          "run\nAuthorization: Basic none\n\n'When will the sun set'";
        stop $client1;
    }

    elsif ( $state eq 'log' ) {
        start $client1;
        set $client1
          "log test\nAuthorization: Basic none\n\nLogged this data in test.log";
        stop $client1;
    }

    elsif ( $state eq 'file' ) {
        start $client1;
        set $client1
          "file test.txt\nAuthorization: Basic none\n\nSaved this data in test.txt";
        stop $client1;
    }

    elsif ( $state eq 'use mhsend command' ) {
        start $client1;
        run qq[mhsend -run -port 8084 -host 192.168.0.2 When will the sun set];
        stop $client1;
    }
}

