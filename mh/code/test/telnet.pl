# Category=Other

# This telnet example shows how to use mh as a socket_server.  Specify port number in mh.ini
# If you set server_telnet_port to 23 (the standard telnet port), you can run:
#   telnet localhost
# If you have a real telnet server run (like on linux), you will want to use a different port (e.g. 1234)
#   telnet localhost 1234
#

				# Examples on how to read and write data to a tcp socket port
$telnet_server = new  Socket_Item("Welcome to Mister House Socket Port 1\n", 'Welcome1', 'server_telnet');
$telnet_server ->add             ("Hi, thanks for dropping by!\n", 'hi');
$telnet_server ->add             ("Bye for now.  Y'all come back now, ya hear!  Type exit to exit.\n", 'bye');

                                # Authorize user with password
use vars '%telnet_auth_flags';
if (active_now $telnet_server) { 
    set $telnet_server 'Welcome1';
    my $client = $Socket_Ports{'server_telnet'}{client_ip_address};
                                # If a password has been created (with set_password command), this will return true
    if (password_check undef, 'server_telnet') {
        $telnet_auth_flags{$client} = -1;
        print_log "Telnet active on server_telnet, waiting for password";
        set_echo $telnet_server '*';
        set $telnet_server 'Enter your password:';
    }
    else {
        set $telnet_server 'Run set_password to create a password.  Global authorization enabled until then';
        $telnet_auth_flags{$client} = 1;
    }

}

if (inactive_now $telnet_server) {
    my $client = $Socket_Ports{'server_telnet'}{client_ip_address};
    $telnet_auth_flags{$client} = 0;
    print_log "Telnet session closed";
}
    

				# You can also write text directly out, not using a pre-defined item state
set $telnet_server "The time is $Time_Now" if $New_Minute and active $telnet_server;


$telnet_client_set = new Voice_Cmd 'Run telnet set test [1,2,3,4,5]';

if ($state = said $telnet_client_set) {
    set $telnet_server "Test telnet set $state"              if $state == 1;
    set $telnet_server "Test telnet set $state", 'all'       if $state == 2;
    set $telnet_server "Test telnet set $state", 0           if $state == 3;
    set $telnet_server "Test telnet set $state", 1           if $state == 4;
    set $telnet_server "Test telnet set $state", '127.0.0.1' if $state == 5;
}

				# Read from the port, then write to it based on what was sent, if authorized
my $reponse_loop_telnet = 0;
#if (my $data = $Socket_Ports{server_telnet}{data_record}) {
if (my $data = said $telnet_server) {
    my $client = $Socket_Ports{'server_telnet'}{client_ip_address};
    if ($telnet_auth_flags{$client} == -1) {
        print_log "password data: $data";
        if (my $results = password_check $data, 'server_telnet') {
            print_log "Telnet password bad: password=$data results=$results";
            set $telnet_server $results;
        }
        else {
            print_log "Telnet session authorized";
            set $telnet_server "Password accepted\n";
            $telnet_auth_flags{$client} = 1;
            set_echo $telnet_server 1;
        }
    }
    else {
        set $telnet_server "\r\n";

        print_log "server port 1 data: $data";
    
        if (lc($data) eq 'hi') {
            set $telnet_server 'hi';
        }
        elsif (lc($data) eq 'bye') {
            set $telnet_server 'bye';
        }
        elsif (lc($data) eq 'exit') {
            set $telnet_server 'bye';
            sleep 1;
            stop $telnet_server;
        }
        else {
                                # This will allow us to type in any command
#           set $telnet_server "You said: $data";
            if ($telnet_auth_flags{$client}) {
                if (process_external_command($data, 0 , 'telnet')) {
                    set $telnet_server "Command executed: $data";
                    $reponse_loop_telnet = $Loop_Count + 2; # Give us 2 passes to wait for any resulting speech
                    $Last_Response = '';
                }
                else {
                    set $telnet_server "Command not recognized:$data\n";
                }
            }
            else {
                set $telnet_server "Not authorized to run command: $data";
            }
        }
        
        logit("$config_parms{data_dir}/logs/server_telnet.$Year_Month_Now.log",  "$client: $data");
    }

}

                                # Show the reponse the the previous command
if (active $telnet_server and $reponse_loop_telnet == $Loop_Count) {
#   my ($last_spoken) = &speak_log_last(1);
    my $last_response = &last_response;
    $last_response = 'No response' unless $last_response;
    set $telnet_server "$Last_Response: $last_response\n";
}



                                # Example of how enable inputing random data from a telnet session
                                # In your telnet, type:  set $wakeup_time_test '10 am'
$wakeup_time_test = new Generic_Item;
$wakeup_time_test ->set_states (qw(6:00am 6:20am 6:40am 7:00am 7:20am 7:40am 8:00am none));

speak "Your wake up time is set for $state" if $state = state_now $wakeup_time_test;
speak "Time to wake up" if time_now state $wakeup_time_test;


