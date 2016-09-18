
# Includes Clay Jackson's example of logging weather data to
#   APRSWXNET:  http://www.findu.com/aprswxnet.html
# For example:  http://www.findu.com/cgi-bin/wxpage.cgi?n7qnm

=begin comment

Attached is a new copy of 'weather_vw.pl'; which uses misterhouse to
send weather data from Ambient Software's Virtual Weather station to the
Citizen's Weather Observation program (hosted by the Amateur Radio
Packet Community).

In order to use this code, you'll need a CWOP observer number, or an
Amateur Radio callsign.   Please do NOT attempt to use this code without
this.  If you need further assistance, please see:

 www.findu.com/citizenweather/signup.html

Or, contact me at n7qnm@n7qnm.net

Replace your_call and your_password before using.

=cut

# Category=Weather

$WindGust        = new Weather_Item 'WindGustSpeed';
$WindDir         = new Weather_Item 'WindAvgDir';
$WindSpeed       = new Weather_Item 'WindAvgSpeed';
$Windy           = new Weather_Item 'WindAvgSpeed > 12';
$Gusty           = new Weather_Item 'WindGustSpeed > 12';
$Stormy          = new Weather_Item 'WindGustSpeed > 25';
$HumidityOutside = new Weather_Item 'HumidOutdoor';
$TempIndoor      = new Weather_Item 'TempIndoor';
$TempOutdoor     = new Weather_Item 'TempOutdoor';
$Barom           = new Weather_Item 'Barom';
$RainTotal       = new Weather_Item 'RainTotal';
$RainRate        = new Weather_Item 'RainRate';
$Rainy           = new Weather_Item 'RainRate > .02';
$RainDay         = new Weather_Item 'RainDay';
$RainHour        = new Weather_Item 'RainHour';
$Pressure        = new Generic_Item;
$Pressure->restore_data( 'PressureLastHour', 'Trend' );
$CumRain = new Generic_Item;
$CumRain->restore_data( 'WeeklyRain', 'MonthlyRain', 'DailyRain',
    'HourlyRain' );
$DailyTemp = new Generic_Item;
$DailyTemp->restore_data( 'High', 'Low' );
$v_WeatherReport = new Voice_Cmd "What is the current weather?";
$v_RainTotals    = new Voice_Cmd "What are the rainfall totals?";

$aprs_net = new Socket_Item( undef, undef, 'ahubwest.net:23' );

my $temp           = 0;
my $temp_in        = 0;
my $humidity       = 0;
my $humidity_in    = 0;
my $hourly_rain    = 0;
my $daily_rain     = 0;
my $weekly_rain    = 0;
my $monthly_rain   = 0;
my $yearly_rain    = 0;
my $adj_humidity   = 0;
my $pressure_mb    = 0;
my $mb_conv_factor = .02953;
my $timestamp      = '';
my $aprs_data      = '';
my $aprs_in        = '';
my $hh             = 0;
my $mm             = 0;
my $ss             = 0;

if ( defined $Weather{TempOutdoor} and $Weather{TempOutdoor} ne 'unknown' ) {
    $temp                  = round( $Weather{TempOutdoor} );
    $temp_in               = round( $Weather{TempIndoor} );
    $humidity              = round( $Weather{HumidOutdoor} );
    $humidity_in           = round( $Weather{HumidIndoor} );
    $daily_rain            = $Weather{RainDay};
    $hourly_rain           = $Weather{RainHour};
    $CumRain->{HourlyRain} = $hourly_rain;
    $CumRain->{DailyRain}  = $daily_rain;
    $weekly_rain           = $daily_rain + $CumRain->{WeeklyRain};
    $monthly_rain          = $daily_rain + $CumRain->{MonthlyRain};
    $yearly_rain           = $Weather{RainTotal};
    $DailyTemp->{High} = $temp if $temp > $DailyTemp->{High};
    $DailyTemp->{Low}  = $temp if $temp < $DailyTemp->{Low};

    if (    ( state $Windy)
        and ( new_minute 15 ) )
    {
        print_msg "The wind is "
          . round( $Weather{WindAvgSpeed} )
          . " mph from the "
          . convert_direction( $Weather{WindAvgDir} ) . " \n";
    }
    print_msg "Wind gust of "
      . round( $Weather{WindGustSpeed} )
      . " mph from the "
      . convert_direction( $Weather{WindAvgDir} ) . " \n"
      if state_now $Gusty;
    speak "Wind gust of "
      . round( $Weather{WindGustSpeed} )
      . " mph from the "
      . convert_direction( $Weather{WindAvgDir} ) . " \n"
      if state_now $Stormy;
    print_msg "It is raining $Weather{RainRate} \n" if state_now $Rainy;
}
if ($New_Month) {
    $CumRain->{MonthlyRain} = 0;
}
if ( time_cron '0 0 * * 0' ) {
    $CumRain->{WeeklyRain} = 0;
}
if ($New_Day) {
    $CumRain->{WeeklyRain}  = $CumRain->{WeeklyRain} + $Weather{RainDay};
    $CumRain->{MonthlyRain} = $CumRain->{MonthlyRain} + $Weather{RainDay};
    $DailyTemp->{Low}       = $temp;
    $DailyTemp->{High}      = $temp;
}

if ($New_Hour) {
    $Pressure->{Trend} = "rising"
      if $Pressure->{PressureLastHour} < $Weather{Barom};
    $Pressure->{Trend} = "falling"
      if $Pressure->{PressureLastHour} > $Weather{Barom};
    $Pressure->{Trend} = "steady"
      if $Pressure->{PressureLastHour} = $Weather{Barom};
    $Pressure->{PressureLastHour} = $Weather{Barom};
}
if ( time_cron '5,20,35,50 * * * *' ) {
    $timestamp = time_date_stamp(13);
    $hh = substr( $timestamp, 0, 2 ) + $config_parms{time_zone};
    if ( $hh > 23 ) { $hh -= 24 }
    $mm = substr( $timestamp, 3, 2 );
    $ss = substr( $timestamp, 6, 2 );
    if ( $humidity eq 100 ) {
        $adj_humidity = 0;
    }
    else {
        $adj_humidity = $humidity;
    }
    $pressure_mb = ( $Weather{Barom} / $mb_conv_factor ) * 10;
    $aprs_data =
      sprintf
      "your_call>APRS,TCPIP*:@%02d%02d%02dzDDMM.ddN/DDDMM.ddW_%03d/%03dg%03dt%03dr%03dP%03dh%02db%05d/station type\n",
      $hh, $mm, $ss, $Weather{WindAvgDir}, $Weather{WindAvgSpeed},
      $Weather{WindGustSpeed}, $temp, $hourly_rain * 100, $daily_rain * 100,
      $adj_humidity, $pressure_mb;
    logit( "$config_parms{data_dir}/aprs.log", $aprs_data );
    unless ( active $aprs_net) {
        start $aprs_net;
        set $aprs_net
          "user your_call pass your_password vers misterhouse linux .01";
    }
    if ( $aprs_in = said $aprs_net) { }
    set $aprs_net $aprs_data;
    stop $aprs_net;

}
if ( said $v_WeatherReport) {
    speak
      "Weather at $Time_Now It is $temp degrees Outside and the humidity is $humidity percent It is $temp_in degrees Inside and the humidity is $humidity_in percent The high since midnight is $DailyTemp->{High}, the low since midnight is $DailyTemp->{Low} The pressure is $Weather{Barom} and $Pressure->{Trend} The average wind speed is "
      . round( $Weather{WindAvgSpeed} )
      . " from the "
      . convert_direction( $Weather{WindAvgDir} )
      . "It has rained $hourly_rain inches in the last hour It has rained $daily_rain inches today";
}
if ( said $v_RainTotals) {
    speak
      "It has rained $hourly_rain inches in the last hour It has rained $daily_rain inches today It has rained $weekly_rain inches since Sunday It has rained $monthly_rain inches this month It has rained $yearly_rain inches this year";
}
