# Category = Weather

# $Date$
# $Revision$

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

use Weather_Common;

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
    } else {
		$v_get_internet_weather_data->respond("app=weather You must be connected to the Internet get weather data");
    }
}

if (my $state = said $v_show_internet_weather_forecast) {
	my $forecast;
    	$forecast = read_all $f_weather_forecast;

	if (length($forecast) < 50) {
		respond "app=weather Last weather forecast received was incomplete."
	} else {
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
    } else {
    	# hash used to locally store weather conditions before selectively
    	# transferring them to %Weather
    	my %w=();

		$conditions = normalize_conditions($conditions);

	    $w{TempOutdoor}  = $1 if $conditions =~ /(\d+) degrees/i;
	    if ($conditions =~ /(\d+)\%/) {
		    $w{HumidOutdoor} = $1;
		    $w{HumidOutdoorMeasured}=1; # tell Weather_Common that we directly measured humidity
		}
	    $w{BaromSea} = $1 if $conditions =~ /([\d\.]+) in./;
	    $w{BaromDelta} = $1 if $conditions =~ /(rising|falling|steady)/;

		if ($conditions =~ /calm/i) {
			$w{WindAvgSpeed} = 0;
			$w{WindAvgDir} = undef;
		} else {
			if ($conditions =~ /wind\s+was\s+(.+?)\./) {
				my $windText=$1;
				($w{WindAvgDir}, $w{WindAvgSpeed}) = $windText =~ /(.+?)\s+at\s+(.+?)\s+mph/i;
		    	($w{WindAvgSpeed}) = $windText =~ /at\s+(.+?)\s+mph/ if !defined $w{WindAvgDir};
			}
		}
		$w{WindGustSpeed}=$w{WindAvgSpeed};
	    $w{WindGustSpeed} = $1 if $conditions =~ /gusts\s+up\s+to\s+(\d+)\s+mph/;
		$w{DewOutdoor}=convert_humidity_to_dewpoint($w{HumidOutdoor},convert_f2c($w{TempOutdoor})); # DewOutdoor is in Celsius at this point

		# Who needs a sun sensor?

		if ($conditions =~ /conditions were (clear|cloudy|partly cloudy|mostly cloudy|sunny|mostly sunny|partly sunny|foggy|light rain|heavy rain|light snow|heavy snow)/i) {
			$w{Conditions} = ucfirst(lc($1));
			$w{IsRaining} = ($Weather{Conditions} =~ /rain/i);
			$w{IsSnowing} = ($Weather{Conditions} =~ /snow/i);
		}

		$w{WindAvgDir}=convert_wind_dir_text_to_num($w{WindAvgDir});

		if ($config_parms{weather_uom_wind} eq 'kph') {
			grep {$w{$_}=convert_mile2km($w{$_});} qw(
				WindAvgSpeed
				WindGustSpeed
			);
		}
		if ($config_parms{weather_uom_wind} eq 'm/s') {
			grep {$w{$_}=convert_mph2mps($w{$_});} qw(
				WindAvgSpeed
				WindGustSpeed
			);
		}
		if ($config_parms{weather_uom_temp} eq 'C') {
			grep {$w{$_}=convert_f2c($w{$_});} qw(
				TempOutdoor
			);
		}
		if ($config_parms{weather_uom_temp} eq 'F') {
			grep {$w{$_}=convert_c2f($w{$_});} qw(
				DewOutdoor
			);
		}
		if ($config_parms{weather_uom_baro} eq 'mb') {
			grep {$w{$_}=convert_in2mb($w{$_});} qw(
				BaromSea
			);
		}

		&populate_internet_weather(\%w);
		&weather_updated;

	}

	if ($v_get_internet_weather_data->{state} eq 'Check') {
	my $msg;
	if (int($Weather{WindSpeedI}) > 20 or int($Weather{WindGustSpeedI}) > 30) {
		$msg = "Warning: High winds! ";
	        }
	        $msg .= "Outdoor temperature is $Weather{TempOutdoor} degrees. ";
        	$msg .= "Wind is $Weather{Wind}. ";
	        $msg .= "Wind chill is $Weather{WindChill}. " if $Weather{WindChill};
	        $msg .= "Dew point is $Weather{DewOutdoor}. " if $Weather{DewOutdoor};
        	$msg .= "Humidity is $Weather{HumidOutdoor}%. ";
	        $msg .= "Pressure is $Weather{BaromSea} and $Weather{BaromSea}.";
		$v_get_internet_weather_data->respond("connected=0 $msg");
	}
	elsif ($v_get_internet_weather_data->{state} eq 'Mail') {
	    my $to = $config_parms{weather_sendto} || '';
	    $v_get_internet_weather_data->respond("connected=0 app=weather image=mail Sending Internet weather data to " . (($to)?$to:$config_parms{net_mail_send_account}) . '.');
	    &net_mail_send(subject => "Internet weather conditions", to => $to, file => $weather_conditions_path);
	    &net_mail_send(subject => "Internet weather forecast", to => $to, file => $weather_forecast_path);

	} elsif ($v_get_internet_weather_data->{state} eq 'SMS') {
	    my $to = $config_parms{cell_phone};
	    if ($to) {
		    $v_get_internet_weather_data->respond("connected=0 app=weather image=mail Sending Internet weather data to mobile phone.");
		    &net_mail_send(subject => "Internet weather conditions", to => $to, file => $weather_conditions_path);
		    &net_mail_send(subject => "Internet weather forecast", to => $to, file => $weather_forecast_path);
	    } else {
		    $v_get_internet_weather_data->respond("connected=0 app=error Mobile phone email address not found!");
	    }
	} else {
		$v_get_internet_weather_data->respond('app=weather connected=0 Weather data retrieved.');
	}

}


# triggers

if ($Reload) {

    if ($Run_Members{'internet_dialup'}) {
        &trigger_set("state_now \$net_connect eq 'connected'", "run_voice_cmd 'Get internet weather data'", 'NoExpire', 'get internet weather')
          unless &trigger_get('get internet weather');
    }
    else {
        &trigger_set("time_cron('5 * * * *') and &net_connect_check",
                     "run_voice_cmd 'Get internet weather data'", 'NoExpire', 'get internet weather')
          unless &trigger_get('get internet weather');
    }
}
