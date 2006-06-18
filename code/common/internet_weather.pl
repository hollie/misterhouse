# Category = Weather

#@ Retrieves current weather conditions and forecasts using bin/get_weather (US only).
#@ You will need to set the city, zone, and state parms in your ini file.
#@ To verify your city, click <a href="http://iwin.nws.noaa.gov/iwin/iwdspg1.html">here</a>,
#@ then click on your state, then click on "Hourly Reports".  If your city
#@ is not listed in the report, pick the closest one.  The zone is usually
#@ the same as your city, but not always.  To verify your zone,
#@ hit the Back button and click on "Zone Forecast".  Zone names precede each
#@ forecast and each is followed by a hyphen.
#@ To modify when this script is run (or to disable it), go to the
#@ <a href="/bin/triggers.pl"> triggers page </a>
#@ and modify the 'get internet weather' trigger.

                                # Get the forecast and current weather data from the Internet
$v_get_internet_weather_data = new  Voice_Cmd('[Get,Check,Mail,SMS] Internet weather data');
$v_get_internet_weather_data-> set_info("Retrieves weather conditions and forecasts for $config_parms{city}, $config_parms{state}");


$v_show_internet_weather_forecast = new  Voice_Cmd('[Read Internet,What is the] weather forecast', 0);
$v_show_internet_weather_forecast-> set_info('Read previously downloaded weather forecast');
$v_show_internet_weather_forecast-> set_authority('anyone');

$v_show_internet_weather_conditions = new  Voice_Cmd('[Read Internet,What are the] weather conditions', 0);
$v_show_internet_weather_conditions-> set_info('Read previously downloaded weather conditions');
$v_show_internet_weather_forecast-> set_authority('anyone');


                                # These files get set by the get_weather program

#noloop=start
my $weather_forecast_path = "$config_parms{data_dir}/web/weather_forecast.txt";
my $weather_conditions_path = "$config_parms{data_dir}/web/weather_conditions.txt";
$f_weather_conditions = new File_Item($weather_conditions_path);
$f_weather_forecast = new File_Item($weather_forecast_path);
#noloop=stop
$p_weather_forecast = new Process_Item;

sub normalize_conditions {
	my $conditions = shift;
        $conditions =~ s/\n/\x20/g;
        $conditions =~ s/\r/\x20/g;
        $conditions =~ s/\l/\x20/g;
        $conditions =~ s/\t/\x20/g;
        $conditions =~ s/\x20+/\x20/g;
        $conditions =~ s/\x20,\x20/,\x20/g;
	return $conditions;
}


if (said $v_get_internet_weather_data) {
    if (&net_connect_check) {
        my $city = $config_parms{city};
        $city = $config_parms{nws_city} if defined $config_parms{nws_city};
        set $p_weather_forecast qq|get_weather -state $config_parms{state} -city "$city" -zone "$config_parms{zone}"|;
        start $p_weather_forecast;
        $v_get_internet_weather_data->respond("app=weather Weather data requested for $city, $config_parms{state}" . (($config_parms{zone})?" Zone $config_parms{zone}":''));
    }
    else {
	$v_get_internet_weather_data->respond("app=weather You must be connected to the Internet get weather data");
    }
}

if (my $state = said $v_show_internet_weather_forecast) {
	my $forecast;
    	$forecast = read_all $f_weather_forecast;

	if (length($forecast) < 50) {
		respond "app=weather Last weather forecast received was incomplete."
	}
	else {
		respond "app=weather $forecast";
	}
}

if (my $state = said $v_show_internet_weather_conditions) {
	my $conditions;

    	$conditions = read_all $f_weather_conditions;
	$conditions = normalize_conditions($conditions);

	respond "app=weather $conditions";
}


if (done_now $p_weather_forecast) {

        # Parse data.  Here is an example:
        # At 6:00 AM, Rochester, MN conditions were  at  55 degrees , wind was south at
        #    5 mph.  The relative humidity was 100%, and barometric pressure was
        #    rising from 30.06 in.

    my $conditions;

    $conditions = read_all $f_weather_conditions;

    if ($conditions =~ /No data available/) {
        $v_get_internet_weather_data->respond("Weather conditions are unavailable at this time.");
    }
    else {

	$conditions = normalize_conditions($conditions);

        $Weather{TempInternet}  = $1 if $conditions =~ /(\d+) degrees/i;
        $Weather{HumidInternet} = $1 if $conditions =~ /(\d+)\%/;
        $Weather{BaromInternet} = $1 if $conditions =~ /([\d\.]+) in./;
        $Weather{BaromInternetDelta} = $1 if $conditions =~ /(rising|falling|steady)/;
        $Weather{WindGustSpeedI} = undef;
        $Weather{WindGustSpeedI} = $1 if $conditions =~ /gusts\s+up\s+to\s+(\d+)\s+mph/;


        if ($conditions =~ /calm/i) {
            $Weather{WindI}  = "calm";
            $Weather{WindSpeedI}  = 0;
            $Weather{WindDirectionI} = undef;
        }
        else {
            $Weather{WindI}  = $1 if $conditions =~ /wind\s+was\s+(.+?)\./;

            ($Weather{WindDirectionI}, $Weather{WindSpeedI}) = $Weather{WindI} =~ /(.+?)\s+at\s+(.+?)\s+mph/i;

	    ($Weather{WindSpeedI}) = $Weather{WindI} =~ /wind\s+was\s+at\s+(.+?)\s+mph/ if !defined $Weather{WindDirectionI};        }

        $Weather{WindChillI} = int(($Weather{WindSpeedI} > 3 and $Weather{TempInternet} <= 50)? 35.74 + .6215 * $Weather{TempInternet}- 35.75 * $Weather{WindSpeedI}**.16 + .4275 * $Weather{TempInternet} * $Weather{WindSpeedI}**.16:$Weather{TempInternet});

        if ($Weather{WindChillI} = int($Weather{TempInternet})) {
            $Weather{WindChillI} = undef;
        }


	my $temp_celsius;
	my $dew_point;

        $dew_point = 1 - $Weather{HumidInternet} / 100;
	$temp_celsius = (5/9) * ($Weather{TempInternet} - 32);
	$dew_point = (14.55 + .114 * $temp_celsius) * $dew_point + ((2.5 + .007 * $temp_celsius) * $dew_point ** 3)  + ((15.9 + .117 * $temp_celsius) * $dew_point ** 14);
	$dew_point = $temp_celsius - $dew_point;
	#Convert to fahrenheit and round to two decimal places
	$Weather{DewInternet} = (int(((9/5) * $dew_point + 32) * 100) + 5)/100;



                                # Allow for writing to standard weather vars if no local weather station
        if ($config_parms{weather_use_internet}) {
	    $Weather{Summary_Short} = $conditions;
            $Weather{TempOutdoor}   = $Weather{TempInternet};
            $Weather{HumidOutdoor}  = $Weather{HumidInternet};
	    $Weather{DewOutdoor}    = $Weather{DewInternet};
            $Weather{Barom}         = $Weather{BaromInternet};
            $Weather{WindGustSpeed} = $Weather{WindGustSpeedI};
            $Weather{Wind}          = $Weather{WindI};
            $Weather{WindSpeed}     = $Weather{WindSpeedI};
            $Weather{WindDirection} = $Weather{WindDirectionI};
            $Weather{WindChill}     = $Weather{WindChillI};
	    $Weather{DewPoint}      = $Weather{DewInternet};
	    $Weather{BaromDelta}    = $Weather{BaromInternetDelta};


	    # Who needs a sun sensor?

	    if ($conditions =~ /conditions were (clear|cloudy|partly cloudy|mostly cloudy|sunny|mostly sunny|partly sunny|foggy)/i) {
			$Weather{Conditions} = ucfirst(lc($1));
	    }


            #For RRD and weather monitor

	      if (lc($Weather{WindDirection}) eq 'north') {
                  $Weather{WindGustDir} = 0;
	      }
              elsif (lc($Weather{WindDirection}) eq 'northeast') {
		  $Weather{WindGustDir} = 45;
              } 
              elsif (lc($Weather{WindDirection}) eq 'east') {
		  $Weather{WindGustDir} = 90;
              } 
              elsif (lc($Weather{WindDirection}) eq 'southeast') {
                  $Weather{WindGustDir} = 135;
              } 
              elsif (lc($Weather{WindDirection}) eq 'south') {
                  $Weather{WindGustDir} = 180;
              } 
              elsif (lc($Weather{WindDirection}) eq 'southwest') {
                  $Weather{WindGustDir} = 225;
              } 
              elsif (lc($Weather{WindDirection}) eq 'west') {
                  $Weather{WindGustDir} = 270;
              } 
              elsif (lc($Weather{WindDirection}) eq 'northwest') {
                  $Weather{WindGustDir} = 315;
              }
	      else {
                  $Weather{WindGustDir} = undef;
              }

            $Weather{WindAvgDir}=$Weather{WindGustDir};
            $Weather{WindAvgSpeed}=$Weather{WindSpeedI};
	    # so weather items do not have to check gust AND avg speed (gust defaults to avg)
            $Weather{WindGustSpeed}=$Weather{WindSpeedI} unless $Weather{WindGustSpeed};

        }
	if ($v_get_internet_weather_data->{state} eq 'Check') {
		my $msg;
	        if (int($Weather{WindSpeedI}) > 20 or int($Weather{WindGustSpeedI}) > 30) {
        	    $msg = "Warning: High winds! ";
	        }
	        $msg .= "Outdoor temperature is $Weather{TempInternet} degrees fahrenheit. ";
        	$msg .= "Wind is $Weather{WindI}. ";
	        $msg .= "Wind chill is $Weather{WindChillI}. " if $Weather{WindChillI};
	        $msg .= "Dew point is $Weather{DewInternet}. " if $Weather{DewInternet};
        	$msg .= "Humidity is $Weather{HumidInternet}%. ";
	        $msg .= "Pressure is $Weather{BaromInternet} and $Weather{BaromInternetDelta}.";
		$v_get_internet_weather_data->respond("connected=0 $msg");
	}
	elsif ($v_get_internet_weather_data->{state} eq 'Mail') {
	    my $to = $config_parms{weather_sendto} || '';
	    $v_get_internet_weather_data->respond("connected=0 app=weather image=mail Sending Internet weather data to " . (($to)?$to:$config_parms{net_mail_send_account}) . '.');
	    &net_mail_send(subject => "Internet weather conditions", to => $to, file => $weather_conditions_path);
	    &net_mail_send(subject => "Internet weather forecast", to => $to, file => $weather_forecast_path);

	}
	elsif ($v_get_internet_weather_data->{state} eq 'SMS') {
	    my $to = $config_parms{cell_phone};
	    if ($to) {
		    $v_get_internet_weather_data->respond("connected=0 app=weather image=mail Sending Internet weather data to mobile phone.");
		    &net_mail_send(subject => "Internet weather conditions", to => $to, file => $weather_conditions_path);
		    &net_mail_send(subject => "Internet weather forecast", to => $to, file => $weather_forecast_path);
	    }
	    else {
		    $v_get_internet_weather_data->respond("connected=0 app=error Mobile phone email address not found!");
	    }
	}

	else {
		$v_get_internet_weather_data->respond('app=weather connected=0 Weather data retrieved.');
	}

	}
}


# triggers

if ($Reload and $Run_Members{'trigger_code'}) {

    if ($Run_Members{'internet_dialup'}) { 
        eval qq(
            &trigger_set("state_now \$net_connect eq 'connected'", "run_voice_cmd 'Get internet weather data'", 'NoExpire', 'get internet weather') 
              unless &trigger_get('get internet weather');
        );
    }
    else {

    eval qq(
        &trigger_set(("time_cron('5 * * * *') or $Startup) and net_connect_check",
          "run_voice_cmd 'Get internet weather data'", 'NoExpire', 'get internet weather')
          unless &trigger_get('get internet weather');
    );

    }
}
