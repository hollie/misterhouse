
# Simple example of sending email on motion:

$motion_sensor1 = new Serial_Item 'XA1AJ', 'garage';
$motion_sensor1->add( 'XA2AJ', 'deck' );
$motion_sensor1->tie_event(
    '&net_mail_send(subject => "$state motion at $Time_Date")');

# Detects motion from an 2 X10 motion sensors, one on the stairs
# and one in the hallway.
# A timer is used so it doesn't report more often than once a minute.
# Random 'creaky stair' wave files are played.

# Note:  This will not work if you have X10_Item's defined on these
#        codes, as a XA2AJ will match the X10 item before it
#        matches the movemen_sensor items

$movement_sensor = new Serial_Item( 'XAJ', ON );
$movement_sensor->add( 'XAK', OFF );
$movement_sensor_unit = new Serial_Item( 'XA1', 'stair' );
$movement_sensor_unit->add( 'XA2', 'hall' );

$timer_stair_movement = new Timer();

if (    state_now $movement_sensor eq ON
    and inactive $timer_stair_movement
    and !$Save{sleeping_parents} )
{
    set $timer_stair_movement 60;
    if ( ( state $movement_sensor_unit) eq 'stair' ) {
        play( 'file' => 'stairs_creak*.wav' );
    }
    elsif ( ( state $movement_sensor_unit) eq 'hall' ) {
        speak 'boys in the hall';
    }
}

# The above code has a problem if you have other X10 devices on the
# same house code.  $movement_sensor_unit state only
# gets set when one of the matching units is detected.  If an unrelated
# unit is fires, $movement_sensor IS set for ON or OFF, but
# $movement_sensor_unit keeps its old value.

# Here is another approach that does not have this problem

$movement_sensor_unit2 = new Serial_Item( 'XA3AJ', 'outside on' );
$movement_sensor_unit2->add( 'XA3AK', 'outside off' );
speak "Outside movement on" if 'outside on' eq state_now $movement_sensor_unit2;
speak "Outside movement off"
  if 'outside off' eq state_now $movement_sensor_unit2;
