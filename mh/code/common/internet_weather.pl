# Category = Weather

#@ Retrieves current weather conditions and forecasts using bin/get_weather (US only).
#@ You will need to set the city, zone, and state parms in your ini file.
#@ To verify your city, click <a href="http://iwin.nws.noaa.gov/iwin/iwdspg1.html">here</a>,
#@ then click on your state, then click on "Hourly Reports".  If your city 
#@ is not listed in the report, pick the closest one.  The zone is usually 
#@ the same as your city, but not always.  To verify your zone, 
#@ hit the Back button and click on "Zone Forecast".  Zone names preceed each 
#@ forecast and each is followed by a hyphen. 

                                # Get the forcast and current weather data from the internet
$v_get_internet_weather_data = new  Voice_Cmd('Get internet weather data');
$v_get_internet_weather_data-> set_info("Retreive weather conditions and forecasts for $config_parms{city}, $config_parms{state}");

                                # These files get set by the get_weather program
$f_weather_forecast   = new File_Item("$config_parms{data_dir}/web/weather_forecast.txt");
$f_weather_conditions = new File_Item("$config_parms{data_dir}/web/weather_conditions.txt");

if (said  $v_get_internet_weather_data) {
    if (&net_connect_check) {
                                # Detatch this, as it may take 10-20 seconds to retreive
                                # Another, probably better way, to do this is with the
                                # Process_Item, as is with p_top10_list above
        my $city = $config_parms{city};
        $city = $config_parms{nws_city} if defined $config_parms{nws_city};
        run qq|get_weather -city "$city" -zone "$config_parms{zone}" -state $config_parms{state}|;

        set_watch $f_weather_forecast;
        print_log "Weather data requested for $city, $config_parms{state} zone=$config_parms{zone}";
    }
    else {
	    speak "Sorry, you must be logged onto the net";
    }
}

$v_show_internet_weather_data = new  Voice_Cmd('Show internet weather [forecast,conditions]');
$v_show_internet_weather_data-> set_info('Display previously downloaded weather data');
$v_show_internet_weather_data-> set_authority('anyone');
if ($state = said  $v_show_internet_weather_data or changed $f_weather_forecast) {
    print_log "Weather $state displayed";
    if ($state eq 'forecast') {
        my $name = name $f_weather_forecast;
        display name $f_weather_forecast;
    }
    else {
        display name $f_weather_conditions;
# Parse data.  Here is an example:
# At 6:00 AM, Rochester, MN conditions were  at  55 degrees , wind was south at
#    5 mph.  The relative humidity was 100%, and barometric pressure was
#    rising from 30.06 in.
        my $conditions = read_all $f_weather_conditions;
        $conditions =~ s/\n/ /g;
        $Weather{TempInternet}  = $1 if $conditions =~ /(\d+) degrees/i;
        $Weather{HumidInternet} = $1 if $conditions =~ /(\d+)\%/;
        $Weather{BaromInternet} = $1 if $conditions =~ /([\d\.]+) in\./;
        $Weather{WindInternet}  = $1 if $conditions =~ /wind (.+?)\./;
        print_log "Internet weather Temp=$Weather{TempInternet} Humid=$Weather{HumidInternet} " . 
                  "Wind=$Weather{WindInternet} Pres=$Weather{BaromInternet}";
    }
}


