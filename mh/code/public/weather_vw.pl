
# Category=Weather

# Add these 2 mh.ini parms
#   weather_vwlog_file=c:\vweather\log_file
#   weather_vwlog_module=Weather_vw.pm

$WindSpeed = new Weather_Item 'WindAvgSpeed';
$WindSpeed-> tie_event('print_log "VW Weather wind speed is now at $state"');
