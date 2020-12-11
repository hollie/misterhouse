# Category=MisterHouse

# Update a file once a minute so another box
# can do the watchdog thing
my $watchdog_file1 = "$Pgm_Root/data/mh.time";
file_write $watchdog_file1 , $Time if $New_Minute;

# C2 will keep an eye on House
return;

# Keep an eye on another box on the network
$watchdog_light       = new X10_Item('O7');
$watchdog_light_timer = new Timer;
my $watchdog_file2 = '//house/e/mh/data/mh.time';

# Periodically check
if ( $New_Minute and !( $Minute % 2 ) ) {

    # Check to see if Dad's MisterHouse is running
    #  - unless we are with 60 seconds of Startup
    unless ( file_change $watchdog_file2 or $Time_Uptime_Seconds < 60 ) {
        my $msg = 'Bruce, MisterHouse is not running on the House box';
        print_log $msg;

        #       display $msg, 5 if $New_Hour;
        #       speak(rooms => 'all', text => $msg);
        set $watchdog_light ON;
        set $watchdog_light_timer 3, 'set $watchdog_light OFF';
    }
}

