
=begin comment

This code demonstrates using a sensor based Group_Item to detect
when we are away and when we are asleep, using the get_idle time
and member_changed methods.
You can use this web page to set and monitor item states for debug: 
   http://localhost:8080/bin/list_items.pl

=cut

# These are the 2 items we want to set
$status_occupied_house = new Generic_Item;
$status_sleeping       = new Generic_Item;

# These are X10 hawkeye sensors
$sensor_garage  = new X10_Sensor('A1');
$sensor_living  = new X10_Sensor('A3');
$sensor_bedroom = new X10_Sensor( 'A5', 'MS13' );

#$sensor_bedroom_brightness = new X10_Sensor('A5', 'MS13');
$sensor_bedroom_brightness = new Serial_Item( 'XA6AJ', 'dark' );
$sensor_bedroom_brightness->add( 'XA6AK', 'light' );

# Ignore non-motion states
$sensor_garage->tie_filter( 1, 'still' );

$sensor_living->tie_filter( 1, 'still' );

$sensor_bedroom->tie_filter( 1, 'still' );
$sensor_bedroom->tie_filter( 1, 'light' );
$sensor_bedroom->tie_filter( 1, 'dark' );

# Used only for light/dark detection
#$sensor_bedroom_brightness -> tie_filter( 1, 'on');
#$sensor_bedroom_brightness -> tie_filter( 1, 'off');

# Group the motion sensors
$sensors = new Group( $sensor_garage, $sensor_living, $sensor_bedroom );

# Debug to monitor sensors
$sensor_garage->tie_event('print_log "Garage sensor  set to $state"');
$sensor_living->tie_event('print_log "Living sensor  set to $state"');
$sensor_bedroom->tie_event('print_log "Bedroom sensor set to $state"');
$sensors->tie_event('print_log "Sensors set to $state"');

# Example of showing when and what member name changed
if ( my $member = member_changed $sensors) {
    print_log "Group sensor $member->{object_name} changed";
}

# Example of querying seconds time since last state change
print_log "Group idle time: " . $sensors->get_idle_time if $New_Minute;

# Detect when we are away from the house.
# Last motion event is the garage and no other
# events received in 20 minutes.
my ( $member, @members );
@members = member_changed_log $sensors;

if (    ( state $status_occupied_house eq ON )
    and ( $sensors->get_idle_time > ( 20 * 60 / 60 ) )
    and ( $members[0] and $members[0]->get_object_name eq '$sensor_garage' ) )
{
    print_log "MODE: House is now un-occupied";
    speak "Goodbye";
    set $status_occupied_house OFF;
}
elsif ( ( state $status_occupied_house ne ON )
    and ( state_now $sensors) )
{
    print_log
      "MODE: House is now occupied state=$status_occupied_house->{state}";
    speak "Hello";
    set $status_occupied_house ON;
}

# Detect when we are asleep.
# Last motion received was in the bedroom,
# but allow for bedroom motion while we sleep.
# Sleep if idle_time on the 2nd to last changed sensor
# (non-bedroom) is > 10 minutes, and it is dark.

if (    ( state $status_sleeping eq OFF )
    and ( $members[0] and $members[0]->get_object_name eq '$sensor_bedroom' )
    and ( $members[1] and $members[1]->get_idle_time > ( 10 * 60 / 60 ) )
    and ( state $sensor_bedroom_brightness eq 'dark' )
    and ( time_greater_than '9:00 PM' ) )
{
    print_log "MODE: Parents are now sleeping";
    speak "Goodnight";
    set $status_sleeping ON;
}
elsif ( ( state $status_sleeping ne OFF )
    and ( $member = member_changed $sensors)
    and ( $member ne $sensor_bedroom ) )
{
    print_log "MODE: Parents are now awake";
    speak "Goodmorning";
    set $status_sleeping OFF;
}
