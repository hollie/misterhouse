# Category=HVAC

use Owfs_Item;
use Owfs_Thermostat;

# Reading and Writing OWFS variables is simply a manner of using the set and get methods.
# The first argument to both set/get is the "item" variable used by OWFS to identify items.
# The second argument to the set function is the value to be written to the "item" variable
# defined by the first argument.  The return value for the get method is the current state
# of the "item".

# Examples:

# Control a relay in code loop.  Toggle the relay on/off each minute
my $relay1 = new Owfs_Item("05.14312A000000");    # heater

if (new_minute) {
    if ( $relay1->get("PIO") ) {
        $relay1->set( "PIO", 0 );
    }
    else {
        $relay1->set( "PIO", 1 );
    }
}

# Fetch a new temperature value once a minute
my $therm1 = new Owfs_Item( "10.4936E4000800", "Sewing Room" );
my $temp;
if (new_minute) {
    $temp = $therm1->get("temperature");
    $temp = ( ( $temp * 9 ) / 5 ) + 32;
    speak "The temperature in the Sewing Room is now $temp degree Fahrenheit";
}

# Using the OWFS thermostat to control the HVAC equipment in your house.  You
# attach various thermometers, relays, sensors to the thermostat then configure
# the thermostat using the mh/code/pulic/Owfs_Thermostat.pl CGI perl script
# copied to the mh/web/ia5/outside area.

$thermostat = new Owfs_Thermostat();

if ( $Startup or $Reload ) {
    $thermostat->add_thermometer( "10.A930E4000800", "Sewing Room",    3 );
    $thermostat->add_thermometer( "10.6D9EB1000800", "Kitchen",        1 );
    $thermostat->add_thermometer( "10.4936E4000800", "Living Room",    1 );
    $thermostat->add_thermometer( "10.6474E4000800", "Master Bedroom", 2 );
    $thermostat->add_thermometer( "10.842CE4000800", "Guest Room",     3 );
    $thermostat->set_heat_relay( "05.14312A000000", "Furnace" );
    $thermostat->set_heat_sensor( "20.DB2506000000", "Furnace", "B" );
    $thermostat->set_cool_relay( "05.F2302A000000", "Air Conditioner" );
    $thermostat->set_cool_sensor( "20.DB2506000000", "Air Conditioner", "A" );
    $thermostat->set_fan_relay( "05.14312A000000", "Air Fan" );
    $thermostat->set_fan_sensor( "20.DB2506000000", "Air Fan", "C" );
}

# Make sure the A/C compressor states on/off a minimum cycle time
# to avoid damaging the compressor with fast start/stop events.
$t_compressor = new Timer;
if ( $t_compressor->expired() ) {
    $thermostat->set_system_mode('cool');
}

# I use a switch light sense near the backdoor to shut the
# compressor off while eating in the backyard patio hear the
# outside compressor.
if ( my $state = said $palmPad) {
    print_log "garage_remote: $state" if $Debug{w800};

    # a/c off
    if ( $state eq 'xfgfk' ) {
        if ( $thermostat->get_system_mode() eq 'cool' ) {
            $thermostat->set_system_mode('off');
            $t_compressor->set( 60 * 60 );
        }
    }

    # a/c on
    if ( $state eq 'xfgfj' ) {
        if ( $t_compressor->active() ) {
            $thermostat->set_system_mode('cool');
        }
    }
}

# I use some latching sensors to detect doorbell activity.
my $frontDoorBell =
  new Owfs_Item( "12.487344000000", "Front DoorBell", undef, "A" );
my $backDoorBell =
  new Owfs_Item( "12.487344000000", "Back DoorBell", undef, "B" );

if ( new_second 1 ) {
    if ( $frontDoorBell->get("latch.A") ) {
        print_log("notice,,, someone is at the front door");
        speak(
            rooms => "all",
            text  => "notice,,, someone is at the front door"
        );
        $frontDoorBell->set( "latch.A", "0" );
    }
    if ( $backDoorBell->get("latch.B") ) {
        print_log("notice,,, someone is at the back door");
        speak(
            rooms => "all",
            text  => "notice,,, someone is at the back door"
        );
        $backDoorBell->set( "latch.B", "0" );
    }
}

# This sensor is attached to a motion detector

my $sensor = new Owfs_Item("05.4D212A000000");
if ( new_second 1 ) {
    my $sense   = $sensor->get("sensed");
    my $present = $sensor->get("present");
    if ($sense) {
        print_log "storage room sensor active:: $sense";
    }
}

my $relay1 = new Owfs_Item("05.14312A000000");    # heater
my $relay2 = new Owfs_Item("05.552A2A000000");    # RIGHT
my $relay3 = new Owfs_Item("05.57222A000000");    # LEFT
my $relay4 = new Owfs_Item("05.F2302A000000");    # a/c

my $ram = new Owfs_Item("09.5DCFAD030000");

my $therm1 = new Owfs_Item( "10.4936E4000800", "Sewing Room" );

my $hub1 = new Owfs_Item("1F.144E02000000");
my $hub2 = new Owfs_Item("1F.E64C02000000");
my $hub3 = new Owfs_Item("1F.F74C02000000");

# I use some relays to control a camera mount
$v_ellison_camera = new Voice_Cmd("ellison camera [LEFT,RIGHT,UP,DOWN]");
if ( my $state = said $v_ellison_camera) {
    if ( !active $t_ellison_camera) {
        if ( $state eq 'LEFT' ) {
            $relay3->set( "PIO", 1 );
        }
        if ( $state eq 'RIGHT' ) {
            $relay2->set( "PIO", 1 );
        }
        set $t_ellison_camera 1;
    }
}

$t_ellison_camera = new Timer;
if ( expired $t_ellison_camera) {
    $relay3->set( "PIO", 0 );
    $relay2->set( "PIO", 0 );
}

