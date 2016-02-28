# Category=Weather

=begin comment

 This monitors wx200 weatherstation weather
 To enable, add these mh.ini parms
  serial_wmr968_port      = COM7
  serial_wmr968_baudrate  = 9600
  serial_wmr968_handshake = dtr
  serial_wmr968_datatype  = raw
  serial_wmr968_module    = weather_wmr968
  serial_wmr968_skip      =  # Use to ignore bad sensor data.  e.g. TempOutdoor,HumidOutdoor,WindChill
  altitude = 1000 # In feet, used to find sea level barometric pressure

 For Rochester, compare against data from: 
   http://www.crh.noaa.gov/arx/prods/MSPCLIRST.html
   http://www.thedrumms.org/Wx.html


At the end of the following list, you will find the definitions for the 
spare sensors. You may have 0 to 3 of them added to this weather station.
If you have none, then remark (put a # in front of each line with Spare in
it). If you have extra sensors, then you can use these either with numbers
(as in BatSpare1) or use a more descriptive name (BatSpareGarage). To 
accomplish this, edit this file as needed, remarking out the ones you are
not going to be using. The first group will correspond to channel 1 on the 
remotes and the last will be channel 3 on the remotes. There is also a table
in the Weather_wmr968.pm module that will need to be changed in exactly the
same was as this was. 

=cut

$TempOutdoor      = new Weather_Item 'TempOutdoor';
$TempIndoor       = new Weather_Item 'TempIndoor';
$HumidOutdoor     = new Weather_Item 'HumidOutdoor';
$HumidIndoor      = new Weather_Item 'HumidIndoor';
$WindChill        = new Weather_Item 'WindChill';
$WindGust         = new Weather_Item 'WindGustSpeed';
$Windy            = new Weather_Item 'WindGustSpeed > 12';
$WindGustDir      = new Weather_Item 'WindGustDir';
$WindAvg          = new Weather_Item 'WindAvgSpeed';
$WindAvgDir       = new Weather_Item 'WindAvgDir';
$RainTotal        = new Weather_Item 'RainTotal';
$RainRate         = new Weather_Item 'RainRate';
$Barom            = new Weather_Item 'Barom';
$BaromSea         = new Weather_Item 'BaromSea';
$DewOutdoor       = new Weather_Item 'DewOutdoor';
$WxTendency       = new Weather_Item 'WxTendency';
$BatWind          = new Weather_Item 'BatWind';
$BatOutdoor       = new Weather_Item 'BatOutdoor';
$BatIndoor        = new Weather_Item 'BatIndoor';
$BatRain          = new Weather_Item 'BatRain';
$BatMain          = new Weather_Item 'BatMain';
$BatSpareGarage   = new Weather_Item 'BatSpareGarage';
$TempSpareGarage  = new Weather_Item 'TempSpareGarage';
$HumidSpareGarage = new Weather_Item 'HumidSpareGarage';
$DewSpareGarage   = new Weather_Item 'DewSpareGarage';
$BatSpare2        = new Weather_Item 'BatSpare2';
$TempSpare2       = new Weather_Item 'TempSpare2';
$HumidSpare2      = new Weather_Item 'HumidSpare2';
$DewSpare2        = new Weather_Item 'DewSpare2';

#$BatSpare3    = new Weather_Item 'BatSpare3';
#$TempSpare3   = new Weather_Item 'TempSpare3';
#$HumidSpare3  = new Weather_Item 'HumidSpare3';
#$DewSpare3    = new Weather_Item 'DewSpare3';

#$WindGust -> tie_event('print_log "Wind gust at $state"');

# Try to guess sunny or cloudy, based on an analog sun sensor

if ($New_Minute) {

    #    $Weather{sun_sensor} = $analog{sun_sensor}; # From sensors.pl weeder input
    if (    time_greater_than("$Time_Sunrise + 2:00")
        and time_less_than("$Time_Sunset  - 5:00") )
    {
        $Weather{Conditions} =
          ( $Weather{sun_sensor} > 40 ) ? 'Clear' : 'Cloudy';
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
$remark_on_humidity =
  new File_Item("$config_parms{data_dir}/remarks/list_humid.txt");
$remark_on_temp_below_0 =
  new File_Item("$config_parms{data_dir}/remarks/list_temp_below_0.txt");
$remark_on_temp_below_20 =
  new File_Item("$config_parms{data_dir}/remarks/list_temp_below_20.txt");

$v_what_temp = new Voice_Cmd('What is the [,inside,outside] temperature');
$v_what_temp->set_info(
    'Returns the humidity, temperature, and windchill, as measured by wx200 weather station'
);
$v_what_temp->set_authority('anyone');

if ( $state = said $v_what_temp) {

    #   my $temp     = round($analog{temp_outside});
    #   my $humidity = round($analog{humidity_outside});

    if ( defined $Weather{TempOutdoor} and $Weather{TempOutdoor} ne 'unknown' )
    {
        my $temp        = round( $Weather{TempOutdoor} );
        my $temp_in     = round( $Weather{TempIndoor} );
        my $windchill   = round( $Weather{WindChill} );
        my $humidity    = round( $Weather{HumidOutdoor} );
        my $humidity_in = round( $Weather{HumidIndoor} );
        my ( $remark, $text );

        # Need a 'is raining' test here
        if ( $humidity > 80 and $temp > 70 ) {
            $remark = read_next $remark_on_humidity;
        }
        if ( $windchill < 0 ) {
            $remark = read_next $remark_on_temp_below_0;
        }
        if ( $windchill < 20 ) {
            $remark = read_next $remark_on_temp_below_20;
        }

        my $temp_out = " $temp degrees ";
        if ( $temp < 50 and $windchill < $temp ) {
            $temp_out .= " $windchill degree windchill outside";
        }
        else {
            $temp_out .= " $humidity percent outside";
        }

        if ( $state eq 'inside' ) {
            $text = "It is $temp_in degrees $humidity_in percent inside.";
        }
        elsif ( $state eq 'outside' ) {
            $text = "It is $temp_out.";
        }
        else {
            $text =
              "It is $temp_in degrees $humidity_in percent inside, $temp_out. $remark ";

        }
        speak $text;
    }
    else {
        speak "Sorry, no weather info";
    }
}

$v_what_wind = new Voice_Cmd('What is the wind speed');
$v_what_wind->set_info(
    'The wind speed is measured with a WX200 weather station');
$v_what_wind->set_authority('anyone');
if ( said $v_what_wind) {
    undef $temp;
    if ( $Weather{WindGustSpeed} == 0 and $Weather{WindGustSpeed} == 0 ) {
        $temp .= "There is currently no wind.";
    }
    else {
        $temp .=
            "The wind is gusting at "
          . round( $Weather{WindGustSpeed} )
          . " MPH from the "
          . convert_direction( $Weather{WindGustDir} );
        $temp .=
            ".  Average speed is "
          . round( $Weather{WindAvgSpeed} )
          . " from the "
          . convert_direction( $Weather{WindAvgDir} );
    }
    speak $temp;
}

$v_what_rain =
  new Voice_Cmd( 'How much rain have we had in the last '
      . '[hour,2 hours,6 hours,12 hours,day,2 days,3 days,4 days,5 days,6 days,week,2 weeks,3 weeks,month,'
      . '2 months,3 months,4 months,6 months]' );
$v_what_rain->set_info(
    'Rainfall, measured by the WX200 weather station and logged by mh');
if ( my $period = said $v_what_rain) {
    undef $temp;
    my $days;

    # Get last record from the day in question
    my ( $number, $unit ) = $period =~ /(\d*) ?(\S+)/;
    $number = 1 unless $number;

    if ( $unit =~ /hour/ ) {
        $days = $number / 24;
    }
    elsif ( $unit =~ /day/ ) {
        $days = $number;
    }
    elsif ( $unit =~ /week/ ) {
        $days = $number * 7;
    }
    elsif ( $unit =~ /month/ ) {
        $days = $number * 30;
    }
    else {
        print "\n\nError in weather_monitor.pl code. period=$period\n";
    }

    #   print "db period=$period unit=$unit number=$number days=$days\n";

    my @temp = get_weather_record( time - $days * 3600 * 24 );

    if ( $Weather{RainTotal} eq 'unknown' or !defined $Weather{RainTotal} ) {
        $temp = "Sorry, I don't have current weather info on rainfall";
    }
    elsif ( !@temp ) {
        $temp =
          "Sorry, I don't have a log of the weather from $days days ago.\n";
    }
    else {
        my $rain_total_yesterday = $temp[21];
        my $rain_diff            = $Weather{RainTotal} - $rain_total_yesterday;

        #   print "db rt_previous=$rain_total_yesterday rt_today=$Weather{RainTotal} diff=$rain_diff\n";
        if ($rain_diff) {
            $temp .=
              "We have had " . round( $rain_diff, 2 ) . " inches of rain ";
        }
        else {
            $temp .= "No rain has fallen ";
        }
        if ( $period eq 'day' ) {
            $temp .= 'in the last 24 hours';
        }
        else {
            $temp .= "in the last $period";
        }
    }
    speak $temp;
}

# This code gets archived weather data
sub get_weather_record {
    speak 'Sorry, not implemented yet';
}

# Note interesting weather events
$timer_wind_gust = new Timer();

#f (state_now $WindGust > 12 and
if ( state $Windy
    and not $Save{sleeping_parents} )
{
    if ( $Weather{WindGustSpeed} > ( $Save{WindGustMax} + 5 ) ) {
        $Save{WindGustMax} = $Weather{WindGustSpeed};
        speak "rooms=all Weather alert.  The wind is now gusting at "
          . round( $Weather{WindGustSpeed} ) . " MPH.";
        set $timer_wind_gust 120 * 60;
    }
    elsif ( inactive $timer_wind_gust) {
        set $timer_wind_gust 120 * 60;
        speak "rooms=all Weather alert.  A wind gust of "
          . round( $Weather{WindGustSpeed} )
          . " MPH was just recorded.";
    }
}
$Save{WindGustMax} = 0 if $New_Day;

my $raintotal_prev;
if ( my $rain = state_now $RainTotal) {
    $Weather{RainRecent} = round( ( $rain - $raintotal_prev ), 2 )
      if $raintotal_prev > 0;
    if ( $Weather{RainRecent} > 0 ) {
        speak "Notice, it just rained $Weather{RainRecent} inches";
        $Weather{IsRaining}++;
    }
    else {
        $Weather{IsRaining} = 0;
    }
    $raintotal_prev = $rain;

    #   print "Notice, 1 it just rained $Weather{RainRecent} inches (total=$Weather{RainTotal}).\n" if $Weather{RainRecent} > 0;
    #   print "Notice, 2 it just rained $Weather{RainRate} inches\n" if $Weather{RainRate};

}

