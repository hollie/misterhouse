
# Category=Internet

# Monitor mh running on other boxes, speaking out when they go down
# for whatever reason.

                                # Update a file once a minute so another box
                                # can do the watchdog thing
my $watchdog_file1 = "$config_parms{data_dir}/mh.time"; 
file_write $watchdog_file1 , $Time if $New_Minute;

#return;                         # Turn off till Nick's computer is fixed

                                # Declare various things to keep an eye on
my $watchdog_file2 = '//dm/d/misterhouse/mh/data/mh.time';
my $watchdog_file3 = '//c2/g/misterhouse/mh/data/mh.time';

#my $watchdog_socket_address = 'misterhouse.net';
my $watchdog_socket_address = '192.168.0.2';
$watchdog_socket = new  Socket_Item(undef, undef, $watchdog_socket_address);

$watchdog_light = new X10_Item('O7', 'CM11',  'LM14');

                                # In case it trys to come on at night, make it dim
if (time_now '11 PM' or time_now '11:30 PM') {
    set $watchdog_light '15%';
    set $watchdog_light OFF;
}
if (time_now '8 AM') {
    set $watchdog_light '75%';
    set $watchdog_light OFF;
}

        

                                # Periodically check stuff
$v_check_servers = new Voice_Cmd 'Check servers';
if ($New_Minute and !($Minute % 15) or said $v_check_servers) {
#if ($New_Hour or said $v_check_servers) {

                                # Check to see if Nick's MisterHouse is running
                                #  - note: file_change undef means we don't know (startup)
    if (file_unchanged $watchdog_file2) {
        my $msg = 'Nick, MisterHouse is not running on D M';
        display $msg, 5;
        speak "rooms=all $msg";
        print_log $msg;
        set_with_timer $watchdog_light '10%', 3 unless $Save{sleeping_parents};
    }

    if (file_unchanged $watchdog_file3) {
        my $msg = 'MisterHouse has stopped running on the C2 box';
        display $msg, 5;
        speak "rooms=all $msg";
        print_log $msg;
        set_with_timer $watchdog_light '20%', 5 unless $Save{sleeping_parents};
    }

                                # Check to make sure the socket server ports are
                                # still working using a test client socket
    for my $server ('http', 'server_speak') {
        my $port = $config_parms{$server . '_port'};
        set_port $watchdog_socket "$watchdog_socket_address:$port";
        unless (is_available $watchdog_socket) {
            my $msg = "Notice, the $server server is down";
            speak "rooms=all $msg";
            display $msg, 0;
            run_voice_cmd "Restart the $server port";
        }
    }

}

$v_restart_server = new Voice_Cmd 'Restart the [http,server_speak] port';
if ($state = said $v_restart_server) {
    &socket_close($state);
    if($Socket_Ports{$state}{sock} = new IO::Socket::INET->
       new(LocalPort => $config_parms{$state.'_port'}, Proto => 'tcp', Reuse => 1, Listen => 10)) {
        print_log "Port $state was restarted";
    }
    else {
        print_log "Port $state was not restarted:  $@";
    }
}



