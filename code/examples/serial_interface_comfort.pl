# Category=Comfort

# An example of reading/writing to the Comfort HA interface

#
# Set these mh.ini parms (in mh.private.ini)
# serial_comfort_port=/dev/ttyS1
# serial_comfort_baudrate=9600
# serial_comfort_handshake=dtr
#
# Comfort login pin number is required in the Comfort_Login subroutine
# The @comfort_names are specific to each installation, and only required for logging
# - MH uses the definitions in items.mht
#
use strict;
use POSIX;    # for strftime

my $C3 = chr 3;

$comfort = new Serial_Item( $C3 . "LI1234\n", 'init', 'serial_comfort' );

if ($Reload) {
    Comfort_Login();
}

if ( $state = said $comfort) {
    $state =~ tr/\x03\x0D\x0A//d;    #delete control-C, CR & LF

    print "Comfort Says : $state\n"; # debugging

    # split input string into parameters
    my $c_command = substr( $state, 0, 2 );
    my $c_p1 = hex( substr( $state, 2, 2 ) );
    my $c_p2 = hex( substr( $state, 4, 2 ) );

    #print "Command = $c_command, Port = $c_p1, State = $c_p2\n";

    #
    # define the names of the input ports. From 1..64.
    my @comfort_names = (
        "Front Door",
        "Hall PIR",
        "Basement PIR",
        "Utility PIR",
        "Shower PIR",
        "Garage PIR",
        "Basement Door",
        "Balcony Door",
        "Computer Room Door",
        "Garage Steps Door",
        "Garage Front Door",
        "Spare",
        "Dark Sensor",
        "Garden PIR",
        "Spare",
        "Spare"
    );

    my @comfort_states = ( "OFF", "ON", "Short Circuit", "Open Circuit" );

    my @comfort_alarm_states = ( "Idle", "Trouble", "Alert", "Alarm" );

    my @comfort_modes = ( "Security OFF", "Away Mode", "Night Mode", "Day Mode",
        "Vacation Mode" );

    my @comfort_users = ( "Keypad", "Response" );

    my @comfort_alarm_params = (
        "Intruder, zone",
        "Zone Trouble, zone",
        "Low Battery, NA",
        "Power Fail, id",
        "Phone Trouble, NA",
        "Duress, user",
        "Arm Failure, user",
        "Not Used",
        "Security Off, user",
        "System Armed, user",
        "Tamper, id",
        "Not Used",
        "Entry Warning, zone",
        "Alarm Abort (disarmed in < 90 seconds), NA",
        "Siren Tamper, NA",
        "Bypass, zone",
        "Not Used",
        "Dial Test, user",
        "Not Used",
        "Entry Alert, zone",
        "Fire (Response-activated), NA",
        "Panic (Response-activated), NA",
        "Not Used",
        "New Message, user",
        "Doorbell pressed, id",
        "Communications Failure (RS485), id",
        "Signin Tamper, id"
    );

    if ( $c_command eq "IP" ) {
        print_log "$comfort_names[$c_p1-1] : $comfort_states[$c_p2]";

        # By default, generic serial data is not checked for matches on items.
        # this tests for items defined in items.mht
        &main::process_serial_data($state);

    }
    elsif ( $c_command eq "LU" ) {
        print_log "Login User : $c_p1 \n";

    }
    elsif ( $c_command eq "AL" ) {
        print_log "Alarm Type Report : $c_p1 $comfort_alarm_states[$c_p2]\n";

    }
    elsif ( $c_command eq "AM" ) {
        $c_p2 &= 127;    # mask off bit 8
        print_log "System Alarm Report : $comfort_alarm_params[$c_p1] $c_p2\n";

    }
    elsif ( $c_command eq "MD" ) {

        if ( $c_p2 < 16 ) {
            print_log
              "Security Mode Changed to : $comfort_modes[$c_p1] by user $c_p2\n";
        }
        else {
            print_log
              "Security Mode Changed to : $comfort_modes[$c_p1] by $comfort_users[$c_p2 - 90]\n";
        }
    }
    else {
        print_log "Comfort said $state\n";

    }

}

# ----------------------------------------------------------------------------------
#
# At midnight (comfort time) the user is kicked off
# Just before midnight, set the clock, then, just after midnight, log back in again !
# (The problem is that you can't set the time if you are not logged in!
# and if you login just before comfort kicks you off then you'll miss a days logging)
if ($New_Minute) {
    if ( time_now("23:55:00") ) {
        Set_Comfort_Time();
    }
    if ( time_now("00:01:00") ) {
        Comfort_Login();
    }
}

# ----------------------------------------------------------------------------------
#
# Login and set the current time.
# Setup a user pin number with only logging permissions, and define it here.
# Notes:
# "From Comfort version 4.114, a login on the UCM enables status reporting"
# "Status reporting is disabled automatically at midnight every day"
sub Comfort_Login() {
    $comfort = new Serial_Item( $C3 . "LI1234\r", 'init', 'serial_comfort' );
    print_log "Comfort login ...";
    set $comfort 'init';    # Login
}

# ----------------------------------------------------------------------------------
#
# Set the current time on the comfort unit.
sub Set_Comfort_Time() {
    my ($comfort_time_set_string);

    # comfort time testing
    $comfort_time_set_string = strftime( "%Y%m%d%H%M%S", localtime );
    print_log "Setting Comfort Clock : $comfort_time_set_string\n";

    $comfort->add( $C3 . "DT" . $comfort_time_set_string . "\r",
        'Set_Time', 'serial_comfort' );
    set $comfort 'Set_Time';
}

# ----------------------------------------------------------------------------------

