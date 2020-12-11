
# An example of how to turn a light on slowly, like a sunrise.
# For real use, you probably want to increase the
# timer delay from 5 seconds to something like 5*60 seconds.

$sunrise_light = new X10_Item 'O7';
$sunrise_timer = new Timer;

#f ($New_time_now  '6 am') {
if ($New_Minute) {
    set $sunrise_light '1%';    # In case it was on?
    print_log "Slowly turning on the sunrise light";
    set $sunrise_timer 5, 'set $sunrise_light "+5"', 20;
}

