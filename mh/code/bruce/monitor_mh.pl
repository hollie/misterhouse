
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

my $watchdog_socket_address = 'misterhouse.net';
$watchdog_socket = new  Socket_Item(undef, undef, $watchdog_socket_address);

$watchdog_light = new X10_Item('O7');

                                # Periodically check stuff
#if ($New_Minute and !($Minute % 15)) {
if ($New_Hour) {

                                # Check to see if Nick's MisterHouse is running
                                #  - note: file_change undef means we don't know (startup)
    if (file_unchanged $watchdog_file2) {
        my $msg = 'Nick, MisterHouse is not running on D M';
        display $msg, 5;
        speak "rooms=all $msg";
        print_log $msg;
        set_with_timer $watchdog_light '10%', 3;
    }

    if (file_unchanged $watchdog_file3) {
        my $msg = 'MisterHouse has stopped running on the C2 box';
        display $msg, 5;
        speak "rooms=all $msg";
        print_log $msg;
        set_with_timer $watchdog_light '20%', 5;
    }

                                # Check to make sure misterhouse.net port redirection is working
#    for my $port ('8080', '8082', '9000') {
    for my $port ('8080', '8082') {
        set_port $watchdog_socket "$watchdog_socket_address:$port";
        unless (is_available $watchdog_socket) {
            my $msg = "Notice, MisterHouse port $port is down";
            speak "rooms=all $msg";
            display $msg, 5;
        }
    }

}



