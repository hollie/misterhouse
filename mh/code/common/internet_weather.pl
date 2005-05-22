# Category = Weather

#@ Retrieves current weather conditions and forecasts using bin/get_weather (US only).
#@ You will need to set the city, zone, and state parms in your ini file.
#@ To verify your city, click <a href="http://iwin.nws.noaa.gov/iwin/iwdspg1.html">here</a>,
#@ then click on your state, then click on "Hourly Reports".  If your city
#@ is not listed in the report, pick the closest one.  The zone is usually
#@ the same as your city, but not always.  To verify your zone,
#@ hit the Back button and click on "Zone Forecast".  Zone names preceed each
#@ forecast and each is followed by a hyphen.

                                # Get the forecast and current weather data from the internet
$v_get_internet_weather_data = new  Voice_Cmd('Get internet weather data');
$v_get_internet_weather_data-> set_info("Retreive weather conditions and forecasts for $config_parms{city}, $config_parms{state}");


$v_show_internet_weather_forecast = new  Voice_Cmd('[Read,Show] internet weather forecast');
$v_show_internet_weather_forecast-> set_info('Display previously downloaded weather forecast');
$v_show_internet_weather_forecast-> set_authority('anyone');

$v_show_internet_weather_conditions = new  Voice_Cmd('[Read,Show] internet weather conditions');
$v_show_internet_weather_conditions-> set_info('Display previously downloaded weather conditions');
$v_show_internet_weather_forecast-> set_authority('anyone');


                                # These files get set by the get_weather program
my $weather_forecast_path = "$config_parms{data_dir}/web/weather_forecast.txt";
my $weather_conditions_path = "$config_parms{data_dir}/web/weather_conditions.txt";


if (said $v_get_internet_weather_data) {
    if (&net_connect_check) {
    my $city = $config_parms{city};
    $city = $config_parms{nws_city} if defined $config_parms{nws_city};
    $p_weather_forecast = new Process_Item(qq|get_weather -state $config_parms{state} -city "$config_parms{city}" -zone "$config_parms{zone}"|);
    start $p_weather_forecast;
        print_log "Weather data requested for $city, $config_parms{state}" . (($config_parms{zone})?"zone=$config_parms{zone}":"");
    }
    else {
        print_log "Sorry, you must be logged onto the net to get the weather";
    }
}

if ($state = said $v_show_internet_weather_forecast) {
    if ($state eq "Read") {
        respond "target=speak " . $weather_forecast_path;
    }
    else {
        respond $weather_forecast_path;
    }
}

if ($state = said $v_show_internet_weather_conditions) {
    if ($state eq "Read") {
        respond "target=speak " . $weather_conditions_path;
    }
    else {
        respond $weather_conditions_path;
    }
}


my $f_weather_conditions = new File_Item($weather_conditions_path);
my $f_weather_forecast = new File_Item($weather_forecast_path);
my $conditions;

if (done_now $p_weather_forecast) {

        # Parse data.  Here is an example:
        # At 6:00 AM, Rochester, MN conditions were  at  55 degrees , wind was south at
        #    5 mph.  The relative humidity was 100%, and barometric pressure was
        #    rising from 30.06 in.


        $conditions = read_all $f_weather_conditions;
    if ($conditions =~ /No data available/) {
        print_log "Weather conditions unavailable at this time";
    }
    else {
        $conditions =~ s/\n/ /g;

#***Check trigger

        $Weather{TempOutdoor}  = $1 if $conditions =~ /(\d+) degrees/i;
        $Weather{Humid} = $1 if $conditions =~ /(\d+)\%/;
        $Weather{Barom} = $1 if $conditions =~ /([\d\.]+) in./;
        $Weather{BaromDelta} = $1 if $conditions =~ /(rising|falling|steady)/;
        $Weather{WindGustSpeed} = "N/A";
        $Weather{WindGustSpeed} = $1 if $conditions =~ /gusting\s+to\s+(\d+)\s+mph/;

        if ($conditions =~ /calm/) {

            $Weather{Wind}  = "calm";
            $Weather{WindSpeed}  = 0;
            $Weather{WindDirection} = "N/A"

        }
        else {
            $Weather{Wind}  = $1 if $conditions =~ /wind\s+was\s+(.+?)\./;
            ($Weather{WindDirection}, $Weather{WindSpeed}) = $conditions =~ /wind\s+was\s+(\S+)\s+at\s+(.+?)\s+mph\./;
            $Weather{Wind}  =~ s/^\s+//;
        }

        $Weather{WindChill} = ($Weather{WindSpeed} > 3 and $Weather{TempOutdoor} <= 50)? 35.74 + .6215 * $Weather{TempOutdoor}- 35.75 * $Weather{WindSpeed}**.16 + .4275 * $Weather{TempOutdoor} * $Weather{WindSpeed}**.16:$Weather{TempOutdoor};

        if ($Weather{WindSpeed} > 20 or $Weather{WindGust} > 30) {
            print_log "Weather:Warning: High winds";
            speak "Warning: Winds at $Weather{WindSpeed} miles per hour";
        }


        print_log "Weather:Outdoor Temperature is $Weather{TempOutdoor} f";
        print_log "Weather:Wind is $Weather{Wind}";
        print_log "Weather:Wind is gusting to $Weather{WindGustSpeed}" if $Weather{WindGustSpeed} ne "N/A" ;
        #print_log "Weather:Wind Speed is $Weather{WindSpeed} mph";
        #print_log "Weather:Wind Direction is $Weather{WindDirection}" if $Weather{WindDirection} ne "N/A" ;
        print_log "Weather:Wind Chill is $Weather{WindChill}" if $Weather{WindChill} ne $Weather{TempOutdoor} ;
        print_log "Weather:Humidity is $Weather{Humid}%";
        print_log "Weather:Pressure is $Weather{Barom} and $Weather{BaromDelta}";
    }
}
