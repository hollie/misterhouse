# Category=Weather

#@ Monitors data collected by various weather stations.

=begin comment

 This monitors weatherstation or Internet weather data.

 If you have a wx200 or wm918 weather station, add these mh.ini parms

  serial_wx200_port      = COM7
  serial_wx200_baudrate  = 9600
  serial_wx200_handshake = dtr
  serial_wx200_datatype  = raw
  serial_wx200_module    = Weather_wx200
  serial_wx200_skip      =  # Use to ignore bad sensor data.  e.g. TempOutdoor,HumidOutdoor,WindChill
  altitude = 1000 # In feet, used to find sea level barometric pressure

 If you have a wmr918 or wmr968 (wireless) station, change wx200 in
 the above parms to wmr968

 For more info on these weather stations, see the comments in
 mh/lib/Weather_wx200.pm and Weather_wx968.pm

 For Rochester, compare against data from:
   http://www.crh.noaa.gov/arx/prods/MSPCLIRST.html
   http://www.thedrumms.org/Wx.html

Example usage:

$WindGust -> tie_event('print_log "Wind gust at $state"');

=cut

use Weather_Item;
use Weather_Common;

my $weather_wind_gust_threshold=$config_parms{weather_wind_gust_threshold}; # noloop
$weather_wind_gust_threshold=12 unless $weather_wind_gust_threshold;  # noloop
my $weather_pollen_threshold=$config_parms{weather_pollen_threshold}; # noloop
$weather_pollen_threshold=12 unless $weather_pollen_threshold;  # noloop
my $weather_temp_indoor_maximum=$config_parms{weather_temp_indoor_max}; # noloop
my $weather_temp_indoor_minimum=$config_parms{weather_temp_indoor_min}; # noloop
$weather_temp_indoor_maximum = 80 unless $weather_temp_indoor_maximum; #noloop
$weather_temp_indoor_minimum = 60 unless $weather_temp_indoor_minimum; #noloop
my $weather_humid_indoor_maximum = $config_parms{weather_humid_indoor_max}; # noloop
my $weather_humid_indoor_minimum = $config_parms{weather_humid_indoor_min}; # noloop
$weather_humid_indoor_maximum = 50 unless $weather_humid_indoor_maximum; #noloop
$weather_humid_indoor_minimum = 30 unless $weather_humid_indoor_minimum; #noloop

$TempOutdoor  = new Weather_Item 'TempOutdoor';
$TempOutdoorA = new Weather_Item 'TempOutdoorApparent';
$TempIndoor   = new Weather_Item 'TempIndoor';
$DewIndoor    = new Weather_Item 'DewIndoor';
$DewOutoor    = new Weather_Item 'DewOutdoor';
$HumidOutdoor = new Weather_Item 'HumidOutdoor';
$HumidIndoor  = new Weather_Item 'HumidIndoor';
$WindChill    = new Weather_Item 'WindChill';
$WindGust     = new Weather_Item 'WindGustSpeed';
$Windy        = new Weather_Item "WindGustSpeed > $weather_wind_gust_threshold";
$WindGustDir  = new Weather_Item 'WindGustDir';
$WindAvg      = new Weather_Item 'WindAvgSpeed';
$WindAvgDir   = new Weather_Item 'WindAvgDir';
$RainTotal    = new Weather_Item 'RainTotal';
$RainRate     = new Weather_Item 'RainRate';
$Barom        = new Weather_Item 'Barom';
$Pollen       = new Weather_Item 'PollenCount';
$Irritating   = new Weather_Item "Pollen > $weather_pollen_threshold";
$Conditions   = new Weather_Item 'Conditions';
$Warning      = new Weather_Item 'Warning'; # Set in chance of rain and by other weather items
$SunSensor    = new Weather_Item 'sun_sensor';
$PressureChange = new Weather_Item 'BaromDelta';
$ChanceOfRain = new Weather_Item 'ChanceOfRainPercent';
$ChanceOfSnow = new Weather_Item 'ChanceOfSnowPercent';
$Raining = new Weather_Item 'IsRaining';
$Snowing = new Weather_Item 'IsSnowing';
$FreezingRain = new Weather_Item 'IsRaining and TempOutdoor < FreezePoint';
$IceStorm = new Weather_Item 'IsRaining and TempOutdoor < FreezePoint and WindGustSpeed > 15';

$Freezing = new Weather_Item 'TempOutdoor <= FreezePoint';
$FreezingIndoor = new Weather_Item 'TempIndoor <= FreezePoint';

# *** Need to track temperature rate of change

$WindChill = new Weather_Item 'WindChill';
$DewOutdoor = new Weather_Item 'DewOutdoor';
$Dew = new Weather_Item 'HumidOutdoor > 70';
$Frost = new Weather_Item 'HumidOutoor > 70 and TempOutdoor < FreezePoint';
$Frostbite = new Weather_Item 'WindChill < FrostbitePoint';

#noloop=start

my $default_outdoor_comfort_min=70;
my $default_outdoor_comfort_max=75;
my $default_heat_warning_point=90;
my $default_cold_warning_point=20;

# Set for quick reference in expressions
$Weather{FreezePoint} = 32;
$Weather{FrostbitePoint} = 20; # in fahrenheit

if ($config_parms{weather_uom_temp} eq 'C') {
	grep {$_=convert_f2c($_)} (
		$default_outdoor_comfort_min,
		$default_outdoor_comfort_max,
		$default_heat_warning_point,
		$default_cold_warning_point,
		$Weather{FreezePoint},
		$Weather{FrostbitePoint},
	);
}


$Weather{HeatWarningPoint} = $config_parms{heat_warning_point}; # danger point for outdoor temp
$Weather{HeatWarningPoint} = $default_heat_warning_point unless defined $Weather{HeatWarningPoint};
$Weather{ColdWarningPoint} = $config_parms{cold_warning_point}; # danger point for outdoor temp
$Weather{ColdWarningPoint} = $default_cold_warning_point unless defined $Weather{ColdWarningPoint};

my $outdoor_comfort_min = $config_parms{outdoor_comfort_min};
$outdoor_comfort_min = $default_outdoor_comfort_min unless $config_parms{outdoor_comfort_min};
my $outdoor_comfort_max = $config_parms{outdoor_comfort_max};
$outdoor_comfort_max = $default_outdoor_comfort_max unless $config_parms{outdoor_comfort_max};

my $rain_units='inches';
$rain_units='millimeters' if $config_parms{weather_uom_rain} eq 'mm';
my $rainrate_units='inches per hour';
$rainrate_units='millimeters per hour' if $config_parms{weather_uom_rain} eq 'mm/hr';

my $wind_units='miles per hour';
$wind_units='kilometers per hour' if $config_parms{weather_uom_wind} eq 'kph';
$wind_units='meters per second' if $config_parms{weather_uom_wind} eq 'm/s';

#noloop=stop


# Examples.  Someone weather-oriented should come up with some real forecasting expressions...
# Possibility: snowstorm (chance_of_snow, high humidity, high winds, under freezing, low pressure and falling)  Something like that.


$Extreme = new Weather_Item 'TempOutdoorApparent > HeatWarningPoint or TempOutdoorApparent < ColdWarningPoint';
$Comfortable = new Weather_Item "TempOutdoorApparent >= $outdoor_comfort_min and TempOutdoorApparent <= $outdoor_comfort_max";
$Uncomfortable = new Weather_Item "TempOutdoorApparent < $outdoor_comfort_min or TempOutdoorApparent > $outdoor_comfort_max";
$Intolerable = new Weather_Item "TempOutdoorApparent > HeatWarningPoint and HumidOutdoor > 70 and Pollen > $weather_pollen_threshold";
$Scorching = new Weather_Item 'TempOutdoor > HeatWarningPoint and HumidOutdoor < 50';

$Dry = new Weather_Item 'HumidOutdoor < 60';
$Arid = new Weather_Item 'HumidOutdoor < 40';

$Mold = new Weather_Item 'HumidIndoor > 60';

$Blustery =  new Weather_Item 'WindGustSpeed > 30';
$Tornado = new Weather_Item 'WindGustSpeed > 55';

$SwimmingWeather = new Weather_Item 'WindGustSpeed < 10 and TempOutdoor > 80';
$RunningWeather = new Weather_Item 'TempOutdoor > 45 and TempOutdoor < 60 and WindGustSpeed < 10';


#   rainstorm, snowstorm (chance_of_snow, high humidity, high winds, under freezing, low pressure and falling), portending

$ColdInside =  new Weather_Item "TempIndoor < $weather_temp_indoor_minimum";
$HotInside =  new Weather_Item "TempIndoor > $weather_temp_indoor_maximum";
$WetInside = new Weather_Item "HumidIndoor > $weather_humid_indoor_maximum";
$DryInside = new Weather_Item "HumidIndoor < $weather_humid_indoor_minimum";

$SunSensor->tie_event('&monitor_sun()');


# trigger

                                # Try to guess sunny or cloudy, based on an analog sun sensor
sub monitor_sun {
#   $Weather{sun_sensor} = $analog{sun_sensor}; # From sensors.pl weeder input
    if (time_greater_than("$Time_Sunrise + 2:00") and
        time_less_than   ("$Time_Sunset  - 5:00") and defined $Weather{sun_sensor}) {
        $Weather{Conditions} = ($Weather{sun_sensor} > 40) ? 'Clear' : 'Cloudy';
    }
}

                                # Add tk weather widgets ... put these in tk_widgets.pl
&tk_label(\$Weather{TempIndoor});
&tk_label(\$Weather{HumidIndoor});
&tk_label(\$Weather{TempOutdoor});
&tk_label(\$Weather{TempOutdoorApparent});
&tk_label(\$Weather{HumidOutdoor});
&tk_label(\$Weather{WindAvgSpeed});
&tk_label(\$Weather{Conditions});

#&tk_label(\$Weather{Summary});
#&tk_label(\$Weather{SummaryWind});
#&tk_label(\$Weather{SummaryRain});

                                # Set up pointers to random weather comments
$f_remark_on_humidity      = new File_Item("$config_parms{data_dir}/remarks/list_humid.txt");
$f_remark_on_temp_below_0  = new File_Item("$config_parms{data_dir}/remarks/list_temp_below_0.txt");
$f_remark_on_temp_below_20 = new File_Item("$config_parms{data_dir}/remarks/list_temp_below_20.txt");

$v_what_temp = new  Voice_Cmd('What is the [,inside,outside] temperature');
$v_what_temp-> set_info('Returns the humidity, temperature, and windchill, as measured by our weather station');
$v_what_temp-> set_authority('anyone');

if ($state = said $v_what_temp) {
    if (defined $Weather{TempOutdoor} and $Weather{TempOutdoor} ne 'unknown') {
        my $temp     = round($Weather{TempOutdoor});
        my $apparent = round($Weather{TempOutdoorApparent});
        my $temp_in  = round($Weather{TempIndoor});
        my $windchill = round($Weather{WindChill});
        my $windchill= round($Weather{WindChill}) if defined $Weather{WindChill};
        my $humidity = round($Weather{HumidOutdoor});
        my $humidity_in = round($Weather{HumidIndoor});
	my $is_raining = $Weather{IsRaining};
	# *** Others

        my ($remark, $text);

	$remark = "It is raining." if $is_raining;
#	$remark = "Watch out for freezing rain." if $FreezingRain->{state};
	$remark = "Frostbite warning." if $Frostbite->{state};

        if ($humidity > 80 and $temp > $config_parms{weather_uom_temp} eq 'F' ? 70 : 20) {
            $remark =  read_next $f_remark_on_humidity;
        }
		if (defined $windchill) {
	        if ($windchill < $config_parms{weather_uom_temp} eq 'F' ? 0 : -17) {
	            $remark =  read_next $f_remark_on_temp_below_0;
	        }
	        if ($windchill < $config_parms{weather_uom_temp} eq 'F' ? 20 : -6) {
	            $remark =  read_next $f_remark_on_temp_below_20;
	        }
		}

        my $temp_out = " $temp degrees ";

        if ($apparent != $temp) {
            $temp_out .= " and feels like $apparent degrees";
        }

        if ($state eq 'inside') {
            $text = "It is $temp_in degrees $humidity_in percent inside.";
        }
        elsif ($state eq 'outside') {
            $text = "It is $temp_out. $remark";
        }
        else {
            $text = "It is $temp_in degrees $humidity_in percent inside, $temp_out. $remark";

        }
        $v_what_temp->respond("app=weather $text");
    }
    else {
        $v_what_temp->respond("app=weather Weather information is not available.");
    }
}

$v_what_wind = new  Voice_Cmd('What is the wind speed');
$v_what_wind-> set_info('The wind speed is measured with our weather station');
$v_what_wind-> set_authority('anyone');
if (said $v_what_wind) {
    undef $temp;
    if ($Weather{WindGustSpeed} == 0  and $Weather{WindAvgSpeed} == 0) {
        $temp .= "There is currently no wind.";
    }
    else {



        $temp  .= "The wind is gusting at " .
            round($Weather{WindGustSpeed}) . " from the " . convert_direction($Weather{WindGustDir});
        $temp .= ".  Average speed is " .
            round($Weather{WindAvgSpeed}) . " from the " . convert_direction($Weather{WindAvgDir});
    }
    respond "app=weather $temp";
}

$v_what_rain = new  Voice_Cmd('How much rain have we had in the last ' .
                              '[hour,2 hours,6 hours,12 hours,day,2 days,3 days,4 days,5 days,6 days,week,2 weeks,3 weeks,month,' .
                              '2 months,3 months,4 months,6 months]');
$v_what_rain-> set_info('Rainfall, measured by our weather station and logged by mh');
if (my $period = said $v_what_rain) {
    undef $temp;
    my $days;
    # Get last record from the day in question
    my ($number, $unit) = $period =~ /(\d*) ?(\S+)/;
    $number = 1 unless $number;

    if ($unit =~ /hour/) {
        $days = $number / 24;
    }
    elsif ($unit =~ /day/) {
        $days = $number;
    }
    elsif ($unit =~ /week/) {
        $days = $number * 7;
    }
    elsif ($unit =~ /month/) {
        $days = $number * 30;
    }
    else {
        print "\n\nError in weather_monitor.pl code. period=$period\n";
    }
#   print "db period=$period unit=$unit number=$number days=$days\n";

    my $rain = rain_since($Time - $days * 3600 * 24);
    if ($rain == -1) {
        $temp .= "Sorry, no rainfall data has been collected";
    }
    else {
        if ($rain) {
            $temp  .= "We have had $rain $rain_units of rain ";
        }
        else {
            $temp .= "No rain has fallen ";
        }
        if ($period eq 'day') {
            $temp .= 'in the last 24 hours';
        }
        else {
            $temp .= "in the last $period";
        }
    }
    respond "app=weather $temp";
}

                                # This code does not get archived weather data
sub get_weather_record {
    respond 'app=weather Sorry, this feature is not implemented yet.';
}


                                # Note interesting weather events
if (state_now $Irritating) {
	$Weather{warning} = 'High pollen count.';
}

if (state_now $HotInside) {
	$Weather{warning} = 'Indoor temperature is too high.';
}

if (state_now $ColdInside) {
	$Weather{warning} = 'Indoor temperature is too low.';
}



$timer_wind_gust  = new Timer();
$timer_wind_gust2 = new Timer();
#f (state_now $WindGust > 12 and
if (state $Windy) {
				# Wait for the gust to peak before announcing
    print "Wind gust: s1=$timer_wind_gust2->{speed}, s2=$Weather{WindGustSpeed}, t=$weather_wind_gust_threshold" if $Debug{weather};
    if ($timer_wind_gust2->{speed} < $Weather{WindGustSpeed}) {
        $timer_wind_gust2->{speed} = $Weather{WindGustSpeed};
        $timer_wind_gust2->set(10);
    }
}
if (expired $timer_wind_gust2) {
    my $speed = $timer_wind_gust2->{speed};
    $timer_wind_gust2->{speed} = 0;
    if (inactive $timer_wind_gust or
	5 + $timer_wind_gust->{speed} < $speed) {
        $timer_wind_gust->{speed} = $speed;
        set $timer_wind_gust 20*60;
        respond "app=weather image=warning color=red Weather alert, the wind is gusting to " . round($speed) . " $wind_units";
        $Weather{Warning} = 'High winds gusting to ' . round($speed) . " $wind_units"
    }
    $Save{WindGustMax} = $speed if $Save{WindGustMax} < $speed; # Save a daily max
}
$timer_wind_gust->{speed} = 0 if expired $timer_wind_gust;

$Save{WindGustMax} = 0 if $New_Day;

# report the start of the first rain each day
# while raining, report hourly totals and remainder when rain stops

my $firstrain = 0;
$firstrain = 0 if $New_Day;

$israining_timer = new Timer;
if (expired $israining_timer) {
    $Weather{IsRaining} = 0 ;
    my $minutes = int(60 - minutes_remaining $rain_report_timer);
    my $rain = rain_since($Time - 60 * $minutes) if $minutes;
    speak "It rained $rain $rain_units in the past $minutes minutes" if $rain;
    set $rain_report_timer 0;
}

$rain_report_timer = new Timer;
if (expired $rain_report_timer and $Weather{IsRaining}) {
    my $rain = rain_since($Time - 60 * 60);
    speak "It has rained $rain $rain_units in the past hour" if $rain;
    set $rain_report_timer 60 * 60 if $Weather{IsRaining};
}

my $raintotal_prev = 0;
my $rain_file = "$config_parms{data_dir}/rain.dbm";
if (my $rain = state_now $RainTotal) {
    $Weather{RainRecent} = 0;
    $Weather{RainRecent} = $rain - $raintotal_prev if $rain > $raintotal_prev;
#   print "db r=$rain p=$raintotal_prev w=$Weather{RainRecent} f=$firstrain\n";
    if ($Weather{RainRecent} > 0) {
        respond "Notice, it just started raining" unless $firstrain;
        dbm_write $rain_file, $Time, $Weather{RainRecent};
#       logit "$config_parms{data_dir}/rain.dbm", "$Time_Now $Weather{RainRecent}"
        set $israining_timer 20 * 60;
        set $rain_report_timer 60 * 60 unless active $rain_report_timer;
        $firstrain++;
        $Weather{IsRaining}++;
    }
    $raintotal_prev = $rain;
}

sub rain_since {
    my $time = shift;
    my %rain_dbm = read_dbm $rain_file;

    return -1 unless keys %rain_dbm;
    my $amount = 0;
    foreach my $event (reverse sort keys %rain_dbm) {
        #print "db e=$event a=$amount r=$rain_dbm{$event}\n";
        if ($event > $time) {
            $amount += $rain_dbm{$event};
        }
        else {
            last;
        }
    }
    eval "untie %rain_dbm";
    $amount = round $amount, 2;  # Round to nearest 1/100
    return $amount;
}
