# Category=Weather

#@ Monitors data collected by various weather stations.

=begin comment

 This monitors weatherstation weather.

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

=cut

my $weather_wind_gust_threshold=$config_parms{weather_wind_gust_threshold}; # noloop
$weather_wind_gust_threshold=12 unless $weather_wind_gust_threshold;  # noloop


$TempOutdoor  = new Weather_Item 'TempOutdoor';
$TempIndoor   = new Weather_Item 'TempIndoor';
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
$DewOutdoor   = new Weather_Item 'DewOutdoor';
#$WindGust -> tie_event('print_log "Wind gust at $state"');

                                # Try to guess sunny or cloudy, based on an analog sun sensor
if ($New_Minute) {
#    $Weather{sun_sensor} = $analog{sun_sensor}; # From sensors.pl weeder input
    if (time_greater_than("$Time_Sunrise + 2:00") and
        time_less_than   ("$Time_Sunset  - 5:00")) {
        $Weather{Conditions} = ($Weather{sun_sensor} > 40) ? 'Clear' : 'Cloudy';
    }
    else {
        $Weather{Conditions} = 'Unknown';
    }
}


                                # Add tk weather widgets ... put these in tk_widgets.pl
#&tk_label(\$Weather{TempIndoor}, \$Weather{TempOutdoor}, \$Weather{WindChill},
#          \$Weather{WindAvgSpeed}, \$Weather{HumidOutdoor});
#&tk_label(\$Weather{Summary});
#&tk_label(\$Weather{SummaryWind});
#&tk_label(\$Weather{SummaryRain});

                                # Set up pointers to random weather comments
$remark_on_humidity      = new File_Item("$config_parms{data_dir}/remarks/list_humid.txt");
$remark_on_temp_below_0  = new File_Item("$config_parms{data_dir}/remarks/list_temp_below_0.txt");
$remark_on_temp_below_20 = new File_Item("$config_parms{data_dir}/remarks/list_temp_below_20.txt");

$v_what_temp = new  Voice_Cmd('What is the [,inside,outside] temperature');
$v_what_temp-> set_info('Returns the humidity, temperature, and windchill, as measured by our weather station');
$v_what_temp-> set_authority('anyone');

if ($state = said $v_what_temp) {

#   my $temp     = round($analog{temp_outside});
#   my $humidity = round($analog{humidity_outside});
    
    if (defined $Weather{TempOutdoor} and $Weather{TempOutdoor} ne 'unknown') {
        my $temp     = round($Weather{TempOutdoor});
        my $temp_in  = round($Weather{TempIndoor});
        my $windchill= round($Weather{WindChill});
        my $humidity = round($Weather{HumidOutdoor});
        my $humidity_in = round($Weather{HumidIndoor});
        my ($remark, $text);

                                # Need a 'is raining' test here
        if ($humidity > 80 and $temp > 70) {
            $remark =  read_next $remark_on_humidity;
        }
        if ($windchill < 0) {
            $remark =  read_next $remark_on_temp_below_0;
        }
        if ($windchill < 20) {
            $remark =  read_next $remark_on_temp_below_20;
        }

        my $temp_out = " $temp degrees ";
        if ($temp < 50 and $windchill < $temp) {
            $temp_out .= " $windchill degree windchill outside";
        }
        else {
            $temp_out .= " $humidity percent outside";
        }

        if ($state eq 'inside') {
            $text = "It is $temp_in degrees $humidity_in percent inside.";
        }
        elsif ($state eq 'outside') {
            $text = "It is $temp_out.";
        }
        else {
            $text = "It is $temp_in degrees $humidity_in percent inside, $temp_out. $remark ";

        }
        respond $text;
    }
    else {
        respond "Sorry, no weather info";
    }   
}

$v_what_wind = new  Voice_Cmd('What is the wind speed');
$v_what_wind-> set_info('The wind speed is measured with our weather station');
$v_what_wind-> set_authority('anyone');
if (said $v_what_wind) {
    undef $temp;
    if ($Weather{WindGustSpeed} == 0  and $Weather{WindGustSpeed} == 0) {
        $temp .= "There is currently no wind.";  
    }
    else {
        $temp  .= "The wind is gusting at " . 
            round($Weather{WindGustSpeed}) . " MPH from the " . convert_direction($Weather{WindGustDir});
        $temp .= ".  Average speed is " . 
            round($Weather{WindAvgSpeed}) . " from the " . convert_direction($Weather{WindAvgDir});
    }
    respond $temp;
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
            $temp  .= "We have had $rain inches of rain ";
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
    respond $temp;
}

                                # This code gets archived weather data
sub get_weather_record {
    respond 'Sorry, not implemented yet';
}


                                # Note interesting weather events
$timer_wind_gust  = new Timer();
$timer_wind_gust2 = new Timer();
#f (state_now $WindGust > 12 and 
if (state $Windy and 
    not $Save{sleeping_parents}) {
				# Wait for the gust to peak before announcing
    if ($timer_wind_gust2->{speed} < $Weather{WindGustSpeed}) {
	$timer_wind_gust2->{speed} = $Weather{WindGustSpeed};
        $timer_wind_gust2->set(10);
    }
}
if (expired $timer_wind_gust2) {
    my $speed = $timer_wind_gust2->{speed};
    $timer_wind_gust2->{speed} = 0;
    if (inactive $timer_wind_gust or
	10 + $timer_wind_gust->{speed} < $speed) {
        $timer_wind_gust->{speed} = $speed;
        set $timer_wind_gust 20*60;
        respond "app=notice Weather alert, the wind is gusting at " . round($speed) . " miles per hour";
    }
    $Save{WindGustMax} = $speed if $Save{WindGustMax} < $speed; # Save a daily max
}
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
    speak "It rained $rain inches in the past $minutes minutes" if $rain; 
    set $rain_report_timer 0;
}

$rain_report_timer = new Timer;  
if (expired $rain_report_timer and $Weather{IsRaining}) {
    my $rain = rain_since($Time - 60 * 60);
    speak "It has rained $rain inches in the past hour" if $rain; 
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
