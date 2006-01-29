# Category = Weather

#@ Retrieves current weather conditions and forecasts using bin/get_weather (US only).
#@ You will need to set the city, zone, and state parms in your ini file.
#@ To verify your city, click <a href="http://iwin.nws.noaa.gov/iwin/iwdspg1.html">here</a>,
#@ then click on your state, then click on "Hourly Reports".  If your city
#@ is not listed in the report, pick the closest one.  The zone is usually
#@ the same as your city, but not always.  To verify your zone,
#@ hit the Back button and click on "Zone Forecast".  Zone names preceed each
#@ forecast and each is followed by a hyphen.
#@ To modify when this script is run (or to disable it), go to the
#@ <a href=/bin/triggers.pl> triggers page </a>
#@ and modify the 'get internet weather' trigger.

                                # Get the forecast and current weather data from the internet
$v_get_internet_weather_data = new  Voice_Cmd('Get internet weather data');
$v_get_internet_weather_data-> set_info("Retrieves weather conditions and forecasts for $config_parms{city}, $config_parms{state}");


$v_show_internet_weather_forecast = new  Voice_Cmd('[Read,Show] internet weather forecast');
$v_show_internet_weather_forecast-> set_info('Display previously downloaded weather forecast');
$v_show_internet_weather_forecast-> set_authority('anyone');

$v_show_internet_weather_conditions = new  Voice_Cmd('[Read,Show] internet weather conditions');
$v_show_internet_weather_conditions-> set_info('Display previously downloaded weather conditions');
$v_show_internet_weather_forecast-> set_authority('anyone');


                                # These files get set by the get_weather program
my $weather_forecast_path = "$config_parms{data_dir}/web/weather_forecast.txt";
my $weather_conditions_path = "$config_parms{data_dir}/web/weather_conditions.txt";

$p_weather_forecast = new Process_Item;
if (said $v_get_internet_weather_data) {
    if (&net_connect_check) {
        my $city = $config_parms{city};
        $city = $config_parms{nws_city} if defined $config_parms{nws_city};
        set $p_weather_forecast qq|get_weather -state $config_parms{state} -city "$city" -zone "$config_parms{zone}"|;
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

        $Weather{TempInternet}  = $1 if $conditions =~ /(\d+) degrees/i;
        $Weather{HumidInternet} = $1 if $conditions =~ /(\d+)\%/;
        $Weather{BaromInternet} = $1 if $conditions =~ /([\d\.]+) in./;
        $Weather{BaromInternetDelta} = $1 if $conditions =~ /(rising|falling|steady)/;
        $Weather{WindGustSpeedI} = undef;
        $Weather{WindGustSpeedI} = $1 if $conditions =~ /gusts\s+up\s+to\s+(\d+)\s+mph/;

        if ($conditions =~ /calm/) {
            $Weather{WindI}  = "calm";
            $Weather{WindSpeedI}  = 0;
            $Weather{WindDirectionI} = undef;
        }
        else {
            $Weather{WindI}  = $1 if $conditions =~ /wind\s+was\s+(.+?)\./;
            ($Weather{WindDirectionI}, $Weather{WindSpeedI}) = $conditions =~ /wind\s+was\s+(\S+)\s+at\s+(.+?)\s+mph\./;
            #For RRD
            #$Weather{WindAvgDir}=$Weather{WindDirection};
            #$Weather{WindAvgSpeed}=$Weather{WindSpeed};
        }

        $Weather{WindChillI} = int(($Weather{WindSpeedI} > 3 and $Weather{TempInternet} <= 50)? 35.74 + .6215 * $Weather{TempInternet}- 35.75 * $Weather{WindSpeedI}**.16 + .4275 * $Weather{TempInternet} * $Weather{WindSpeedI}**.16:$Weather{TempInternet});

        if ($Weather{WindChillI} = int($Weather{TempInternet})) {
            $Weather{WindChillI} = undef;
        }

        if (int($Weather{WindSpeedI}) > 20 or int($Weather{WindGustSpeed}) > 30) {
            print_log "Weather:Warning: High winds";
        }

                                # Allow for writing to standard weather vars if you don't have a local weather station
        if ($config_parms{weather_use_internet}) {
            $Weather{TempOutdoor}   = $Weather{TempInternet};
            $Weather{HumidOutdoor}  = $Weather{HumidInternet};
            $Weather{Barom}         = $Weather{BaromInternet};
            $Weather{WindGustSpeed} = $Weather{WindGustSpeedI};
            $Weather{Wind}          = $Weather{WindI};
            $Weather{WindSpeed}     = $Weather{WindSpeedI};
            $Weather{WindDirection} = $Weather{WindDirectionI};
            $Weather{WindChill}     = $Weather{WindChillI};
        }

        print_log "Weather:Outdoor Temperature is $Weather{TempInternet} f";
        print_log "Weather:Wind is $Weather{WindI}";
        print_log "Weather:Wind Chill is $Weather{WindChillI}" if $Weather{WindChillI};
        print_log "Weather:Humidity is $Weather{HumidInternet}%";
        print_log "Weather:Pressure is $Weather{BaromInternet} and $Weather{BaromInternetDelta}";


	}
}


# lets allow the user to control via triggers

if ($Reload and $Run_Members{'trigger_code'}) {
    eval qq(
        &trigger_set("(time_cron('58 9,16 * * 0,6') or time_cron('15 6,17 * * 1-5')) and net_connect_check",
          "run_voice_cmd 'Get internet weather data'", 'NoExpire', 'get internet weather')
          unless &trigger_get('get internet weather');
    );
}
