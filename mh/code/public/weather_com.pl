# Category = Weather

# Gets weather data from weather.com, using the CPAN Geo::Weather.pm
# module. Unlike the web site used in mh/bin/get_weather,
# weather.com also has data on non-US cities.
# Set mh.ini city and state parms.  For non-US cities, set state to the
# country (e.g. city=London, state=United Kingdon
# Unlike get_weather, this data is not retreived with a background
# process, so mh will pause while retrieving data.

use Geo::Weather;

$weather_com  = new Geo::Weather;
$weather_comv = new Voice_Cmd '[Get,Display,Speak] internet weather.com data';
$weather_comv-> set_info("Gets data from weather.com, for mh.ini city parm $config_parms{city}, $config_parms{state}");

                                # Periodically get data, if online
run_voice_cmd 'Get internet weather.com data' if time_cron '1 7,13,19 * * * ' and &net_connect_check;

if ($state = said $weather_comv) {
    if ($state eq 'Get') {
        print_log "Getting weather data for $config_parms{city}, $config_parms{state}";
        my $data = $weather_com->get_weather($config_parms{city}, $config_parms{state});
        for my $key (sort keys %{$data}) {
            print "  Weather{$key}=$$data{$key}\n";
            $Weather{$key} = $$data{$key};
        }
        print_log "Getting weather map";
        run "get_url $Weather{page} $config_parms{data_dir}/weather.html";
    }
    elsif ($state eq 'Display') {
        browser "$config_parms{data_dir}/weather.html";
        my $msg = "Weather for $Weather{city}\n  Conditions: $Weather{cond}\n";
        $msg .= "  Dewpoint: $Weather{dewp}\n  Humidity: $Weather{humi}\n";
        $msg .= "  Temperature: $Weather{temp}\n  Wind: $Weather{wind}\n";
        display $msg;
    }
    else {
        speak "It is $Weather{temp} degrees, $Weather{humi} outside. Wind is $Weather{wind}";
    }
}

#$WindSpeed = new Weather_Item 'wind';
#$WindSpeed-> tie_event('print_log "Weather.com wind speed is now at $state"');
