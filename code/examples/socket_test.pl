# Category=Other

# This shows an example on how to act as a client to a socket server

my $client1_address = '9.5.169.79:2348';
$client1 = new Socket_Item( undef, undef, $client1_address );

# Open the port
$v_test_client1 = new Voice_Cmd("Run socket test [1,2,3,4,5]");

if ( $state = said $v_test_client1) {
    print_log "Running client test $state";
    if ( $state == 1 ) {
        unless ( active $client1) {
            print_log "Start a connection to $client1_address";
            start $client1;
        }
        set $client1 "Hi from mh at $Time_Now\n";
    }
    elsif ( $state == 2 ) {
        print_log "closing $client1";
        stop $client1;
    }
    else {
        print_log "socket test $state is not implemented";
    }
}

# Example of how to read a socket client
if ( my $data = said $client1) {
    print_log "client data: $data\n";
}

# Here is an example on how to create a mh server, instead of clients like above.
# Add this  mh.ini parm, so the server is created on startup:
#   server_myserver_port=8012
# Then monitor the server port with this:

$myserver = new Socket_Item( undef, undef, 'server_myserver' );
print_log "myserver data: $temp" if $temp = said $myserver;
