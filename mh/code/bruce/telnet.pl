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
my $telnet_auth_flag = 0;
my $telnet_password_flag = 0;
if (active_now $telnet_server) { 
    set $telnet_server 'Welcome1';

                                # If password has been set (with set_password command), this will return true
    if (password_check undef, 'server_telnet') {
        $telnet_password_flag = 1;
        print_log "Telnet active on server_telnet, waiting for password";
        set_echo $telnet_server '*';
        set $telnet_server 'Enter your password:';
    }
    else {
        set $telnet_server 'Run set_password to create a password.  Global authorization enabled until then';
        $telnet_auth_flag = 1;
    }

}
my $data;
if ($telnet_password_flag and ($data = said $telnet_server)) {
    print_log "password data: $data";
    $telnet_password_flag = 0;
    set_echo $telnet_server 1;
    if (my $results = password_check $data, 'server_telnet') {
        print_log "Telnet password bad: password=$data results=$results";
        set $telnet_server $results;
    }
    else {
        print_log "Telnet session authorized";
        set $telnet_server "Password accepted\n";
        $telnet_auth_flag = 1;
    }
}
if (inactive_now $telnet_server) {
    $telnet_password_flag = 0;
    $telnet_auth_flag = 0;
    print_log "Telnet session closed";
}
    

				# You can also write text directly out, not using a pre-defined item state
set $telnet_server "The time is $Time_Now" if $New_Minute and active $telnet_server and !$telnet_password_flag;

				# Read from the port, then write to it based on what was sent
my $socket_speak_loop;
#if (my $data = $Socket_Ports{server_telnet}{data_record}) {
if (my $data = said $telnet_server) {

    print_log "server port 1 data: $data";
    
    if (lc($data) eq 'hi') {
        set $telnet_server 'hi';
    }
    elsif (lc($data) eq 'bye') {
        set $telnet_server 'bye';
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
#       set $telnet_server "You said: $data";
        if ($telnet_auth_flag) {
            if (process_external_command($data)) {
                set $telnet_server "Command executed: $data";
                $socket_speak_loop = $Loop_Count + 2; # Give us 2 full passes to wait for any resulting speech
            }
            else {
                set $telnet_server "Command not recognized:$data\n";
            }
        }
        else {
            set $telnet_server "Not authorized to run command: $data";
        }
    }
    
    logit("$config_parms{data_dir}/logs/server_telnet.$Year_Month_Now.log",  $data);

}

				# Show text that was spoken as a result of a previous socket command
if (active $telnet_server and $socket_speak_loop == $Loop_Count) {
    my ($last_spoken) = &main::speak_log_last(1);
    set $telnet_server "Last spoken text: $last_spoken\n";
}



                                # Example of how enable inputing random data from a telnet session
                                # In your telnet, type:  set $wakeup_time '10 am'
$wakeup_time_test = new Generic_Item;
$wakeup_time_test ->set_states (qw(6:00am 6:20am 6:40am 7:00am 7:20am 7:40am 8:00am none));

speak "Your wake up time is set for $state" if $state = state_now $wakeup_time_test;
speak "Time to wake up" if time_now state $wakeup_time_test;


