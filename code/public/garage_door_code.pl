
=begin comment

From Jeff D. on 4/2003

Attached is the relevant code for my door setup.  Note I use the pulse
feature of the weeder boards, so it is about .65 seconds to the relays.
Don't forget to 'init' them in your startup.pl.

I don't automatically close the doors, so I don't worry about the safety
reverse.

These are the sensors I used, $4 a peice:
http://www.norcoalarms.com/ezStore123/DTProductZoom.asp?productID=531

=cut

# Category=Doors
#>From doors.pl
######################################################
# Miscellaneous Door stuff
#####################################################

####################
#
# Voice Commands
#
####################

$v_ToggleGarageDoorN = new Voice_Cmd("Toggle North Garage door");
$v_ToggleGarageDoorS = new Voice_Cmd("Toggle South Garage door");

if ( said $v_ToggleGarageDoorN) {
    set $WB_OD_NorthOHTog 'pulse';
    speak("Toggling North Garage Door");
}

if ( said $v_ToggleGarageDoorS) {
    set $WB_OE_SouthOHTog 'pulse';
    speak("Toggling South Garage Door");
}
####################
#
# Automatic states
#
####################

#########################
# Overhead Garage Doors
#
if ( state_now $WB_IB_NorthOHDoor eq OPEN ) {
    if ( time_greater_than("$Time_Sunset") or time_less_than("$Time_Sunrise") )
    {
        set_with_timer $Garage_North_Lights ON, 60;
        set_with_timer $Coach_Lights ON,        90;

        #        set $Garage_North_Lights ON;
        #        set $TimerGarageNLights 60, '&GarageNLightsExpired';
    }
    logit( "$config_parms{data_dir}/door/nortover.log", "1", "12" );
    speak("North Overhead Garage door open");
}

if ( state_now $WB_IB_NorthOHDoor eq CLOSED ) {
    logit( "$config_parms{data_dir}/door/nortover.log", "0", "12" );
    speak("North Overhead Garage door closed");
}

if ( state_now $WB_IC_SouthOHDoor eq OPEN ) {
    if ( time_greater_than("$Time_Sunset") or time_less_than("$Time_Sunrise") )
    {
        set $Garage_South_Lights ON;
        set_with_timer $Coach_Lights ON, 90;
        set $TimerGarageSLights 60, '&GarageSLightsExpired';
    }
    logit( "$config_parms{data_dir}/door/soutover.log", "1", "12" );
    speak("South Overhead Garage door open");
}

if ( state_now $WB_IC_SouthOHDoor eq CLOSED ) {
    logit( "$config_parms{data_dir}/door/soutover.log", "0", "12" );
    speak("South Overhead Garage door closed");
}

# Category=Other
> From items . pl
#####################################################

  # North Overhead door, NO = pulled up High
  $WB_IB_NorthOHDoor= new Serial_Item( 'BBH', OPEN, 'weeder' );
$WB_IB_NorthOHDoor->add( 'BBL', CLOSED );
$WB_IB_NorthOHDoor->add( 'BSB', 'init' );
$WB_IB_NorthOHDoor->add( 'BRB', 'read' );

# South Overhead door, NO = pulled up High
$WB_IC_SouthOHDoor = new Serial_Item( 'BCH', OPEN, 'weeder' );
$WB_IC_SouthOHDoor->add( 'BCL', CLOSED );
$WB_IC_SouthOHDoor->add( 'BSC', 'init' );
$WB_IC_SouthOHDoor->add( 'BRC', 'read' );

$WB_OD_NorthOHTog = new Serial_Item( 'BHD', ON, 'weeder' );
$WB_OD_NorthOHTog->add( 'BHD65000', 'pulse' );
$WB_OD_NorthOHTog->add( 'BLD',      OFF );
$WB_OD_NorthOHTog->add( 'BLD',      'init' );

$WB_OE_SouthOHTog = new Serial_Item( 'BHE', ON, 'weeder' );
$WB_OE_SouthOHTog->add( 'BHE65000', 'pulse' );
$WB_OE_SouthOHTog->add( 'BLE',      OFF );
$WB_OE_SouthOHTog->add( 'BLE',      'init' );

