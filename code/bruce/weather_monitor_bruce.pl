# Category=Weather

#@ Bruce specific weather monitoring.  Generic monitoring is in mh/code/common/weather_monitor.pl

# Announce when the outside temp changes to more/less the inside temp
$weather_outside_flag = new Generic_Item;

if ( $Weather{TempOutdoor} > ( $Weather{TempIndoor} + .75 )
    and state $weather_outside_flag ne 'warmer' )
{
    set $weather_outside_flag 'warmer';
}
elsif ( $Weather{TempOutdoor} < ( $Weather{TempIndoor} - .5 )
    and state $weather_outside_flag ne 'cooler' )
{
    set $weather_outside_flag 'cooler';
}
if ( $state = state_now $weather_outside_flag) {
    speak
      "app=notice Weather notice.  The temperature is now $state outside than inside at $Weather{TempOutdoor} degrees";
}
