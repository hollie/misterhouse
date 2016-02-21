# Category=Weather

# The script creates the weather text that MisterHouse will	speak from the
# web page you've chosen.  If this script is called	"weather.txt", please
# rename it	to "weather.pl"	adn	place into your	MisterHouse	code directory.
#
# Go to	www.wunderground.com, find out what	the	equivalent URL is for
# your local weather, and change the URL environment variable to it.
# Unmodified, you can hear what	the	weather	will be	like where I live.
# Take it as you see it.  Improve it, and let me know what you've done with
# it.
#

# ernie_oporto@mentorg.com
# October 7, 1999

#my	$Country = $config_parms{country};
#my	$StateProvince = $config_parms{state};
#my	$CityPage =	$config_parms{city};
#
my (
    $text,     @data,           $data,       $data_temp,
    $data_dew, $wind_direction, $wind_speed, $gust_speed,
    $temp,     $dew,            $presure,    $dag
);
my (
    @airport,        $aprs_ws,        $aprs_winddir,
    $aprs_windspeed, $aprs_gustspeed, $aprs_temp,
    $aprs_dev,       $aprs_presure,   $aprs_time
);
my (
    $aprs_humidity, $AirportCode, $AirportPos,
    $AirportName,   $AirportLine, $Metar
);
my ( $E_pressure, $Es_pressure );
my $HtmlFindFlag = 0;
######my $WeatherURL="http://www.egats.org/cgibin/wxread2.cgi?stations=ESKN";	###	Does not work yet, ESKN	in 2 places
my $WeatherURL = "http://blinder.lfv.se/cgi/met/metar.sweden";
my $WeatherURLForecast =
  "http://www.tv4.se/nyheterna/vadret/vadret_sverige2.asp?lan=13&location=156";

######my $WeatherFile=(split(/\./, (split(/\//,$WeatherURL))[5]	))[0];
my $WeatherFile         = "weather_conditions";
my $WeatherFileForecast = "weather_forecast";

my $f_weather_page = "$config_parms{data_dir}/web/$WeatherFile.txt";
my $f_weather_html = "$config_parms{data_dir}/web/$WeatherFile.html";
$p_weather_page = new Process_Item("get_url	$WeatherURL	$f_weather_html");
$v_weather_page = new Voice_Cmd('[Get,Read,Show] weather conditions');
$v_weather_page->set_info('Get	the	weather	conditions at Skavsta airport');
my $f_weather_forecast_page =
  "$config_parms{data_dir}/web/$WeatherFileForecast.txt";
my $f_weather_forecast_html =
  "$config_parms{data_dir}/web/$WeatherFileForecast.html";
$p_weather_forecast_page =
  new Process_Item("get_url $WeatherURLForecast $f_weather_forecast_html");
$v_weather_forecast_page = new Voice_Cmd('[Get,Read,Show] weather forecast');
$v_weather_forecast_page->set_info('Get the weather forecast from TV4');
####$v_weather_page-> set_info("Weather	conditions and forecast	for	$config_parms{city}, $config_parms{state}  $config_parms{country}");

#$udp_output = new Socket_Item(undef, undef, '213.180.75.122:1315',	undef, 'udp');	 # aprsd udpport

#if	($Startup) {
#	unless (active $udp_output)	{
#	   print_log "Starting a connection	to aprsd udp_output";
#	   start $udp_output;
#	}
#}

if ($Reload) {
    open( AIRPOS, "$config_parms{code_dir}/weather.pos" );    #	Open for input
    @airport = <AIRPOS>;    #	Open array and read	in data
    close AIRPOS;           #	Close the file
}

#speak($f_weather_page)
if ( said $v_weather_page eq 'Read' ) {
    $text = file_read $f_weather_page;
    speak $text;
}
display($f_weather_page) if said $v_weather_page eq 'Show';

if ( said $v_weather_forecast_page eq 'Read' ) {
    $text = file_read $f_weather_forecast_page;
    speak $text;
}
display($f_weather_forecast_page) if said $v_weather_forecast_page eq 'Show';

if ( said $v_weather_page eq 'Get' or time_cron '1,31 * * * *' ) {

    # Do this only if we the file has not already been updated today and it	is not empty
    if (    0
        and -s $f_weather_html > 10
        and time_date_stamp( 6, $f_weather_html ) eq time_date_stamp(6) )
    {
        print_log "Weather page	is current";
        display $f_weather_page;
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving $WeatherFile ...";

            #			 speak "Retrieving $WeatherFile	...";

            # Use start	instead	of run so we can detect	when it	is done
            start $p_weather_page;
        }
        else {
            speak "Sorry, you must be logged onto the net";
        }
    }
}

if ( said $v_weather_forecast_page eq 'Get' ) {

    # Do this only if we the file has not already been updated today and it	is not empty
    if (    0
        and -s $f_weather_forecast_html > 10
        and time_date_stamp( 6, $f_weather_forecast_html ) eq
        time_date_stamp(6) )
    {
        print_log "Weather forecast	page is	current";
        display $f_weather_forecast_page;
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving $WeatherFileForecast ...";

            #			 speak "Retrieving $WeatherFileForecast	...";

            # Use start	instead	of run so we can detect	when it	is done
            start $p_weather_forecast_page;
        }
        else {
            speak "Sorry, you must be logged onto the net";
        }
    }
}

if ( done_now $p_weather_page) {
    my $html = file_read $f_weather_html;

    $text = HTML::FormatText->new( leftmargin => 0, rightmargin => 150 )
      ->format( HTML::TreeBuilder->new()->parse($html) );

    # New section for APRS Weather objects - Roger Bille
    # V0.1	2001-06-16
    # V0.2	2001-06-17	Added better field checks, i.e.	included \d{x} in pattern matching
    # V0.3	2001-06-21	Added support for Variable winddirection and humidity 100% or more

    foreach $AirportLine (@airport) {    # Run for each airport in array
        ( $AirportCode, $AirportPos, $AirportName ) =
          ( split( ',', $AirportLine ) )[ 0, 1, 2 ];    # Split	each line
        chomp $AirportName;    # Remove any trailing linefeed

        if ( $text =~ /$AirportCode / ) {    # Check	if Airport is in text
            $Metar = $text;                     # Copy text	so it is not changed
            $Metar =~ s/.+$AirportCode /$1/s;   # Remove all before
            $Metar =~ s/=.+/$1/s;               # Remove all after

            @data = split( ' ', $Metar );       # Split	field by field
            foreach $data (@data) {             # Process each field

                if ( $data =~ /KT/ ) {    # Check	if Wind	data (03010KT,VRB02KT)
                    $aprs_winddir = substr( $data, 0, 3 );    # Wind direction
                    if ( $aprs_winddir eq "VRB" )
                    {    # Check	if variable	direction
                        $aprs_winddir = "...";    # Set aprs to variable
                    }
                    $wind_speed = substr( $data, 3, 2 );    # Windspeed	in knot
                    $wind_speed =~ s/^0+/$1/s;    # Remove beginning 0´s
                    $aprs_windspeed =
                      sprintf( "%03d", $wind_speed * 1.852 / 1.609344 )
                      ;    # Convert to mph with 3 characters	beginning with 0's
                    $gust_speed = 0;
                    if ( $data =~ /G/ ) {
                        $gust_speed = substr( $data, 6, 2 );
                        $aprs_gustspeed =
                          sprintf( "%03d", $gust_speed * 1.852 / 1.609344 )
                          ; # Convert to mph with 3 characters	beginning with 0's
                    }
                }

                if ( $data =~ /\// ) {    # Check	if Temp	and	Dew
                    ( $data_temp, $data_dew ) =
                      split( "/", $data );    # Split	temp and dew
                    if ( $data_temp =~ /M/ ) {    # Check	if negative
                        $temp = substr( $data_temp, 1, 2 );    # Temperatur in	C
                        $temp =~ s/^0+/$1/s;    # Remove beginning 0's
                        $temp = $temp * -1;     # Negative
                    }
                    else {
                        $temp = substr( $data_temp, 0, 2 );    # Temperatur in	C
                        $temp =~ s/^0+/$1/s;    # Remove beginning 0's
                    }
                    if ( $data_dew =~ /M/ ) {    # Check	if negative
                        $dew = substr( $data_dew, 1, 2 );    # Dewpoint in C
                        $dew =~ s/^0+/$1/s;    # Remove beginning 0's
                        $dew = $dew * -1;      # Negative
                    }
                    else {
                        $dew = substr( $data_dew, 0, 2 );    # Dewpoint in C
                        $dew =~ s/^0+/$1/s;    # Remove beginning 0's
                    }
                    $aprs_temp = sprintf( "%03d", $temp * 9 / 5 + 32 )
                      ;                        # Convert to F with	formating
                    $aprs_dev = sprintf( "%03d", $dew * 9 / 5 + 32 )
                      ;                        # Convert to F with	formating
                    $Es_pressure =
                      6.11 * 10.0**( 7.5 * $temp / ( 237.7 + $temp ) )
                      ;    # Caluculate Saturation	Vapor Pressure
                    $E_pressure = 6.11 * 10.0**( 7.5 * $dew / ( 237.7 + $dew ) )
                      ;    # Caluculate Actual	Vapor Pressure
                    $aprs_humidity = ( $E_pressure / $Es_pressure ) *
                      100;    # Calculate	Relative Humidity
                    if ( $aprs_humidity >= 100 )
                    {         # Check	if humidity	is 100%	or more
                        $aprs_humidity =
                          99;    # Convert to APRS format (of 100% =	00)
                    }
                    $aprs_humidity = sprintf( "%02d", $aprs_humidity )
                      ;          # Convert to APRS format
                }

                if ( $data =~ /Q\d{4}/ ) {    # Check	if Presure (Q1011)
                    $presure = substr( $data, 1, 4 );    # Presure in mbar
                    $aprs_presure = $presure . "0"
                      ;    # Format and add extra 0 for presure in	thenth:s mbar
                }

                if ( $data =~ /\d{6}Z/ ) {    # Check	for	time stamp (172130Z)
                    $aprs_time = substr( $data, 0, 6 );    # Time stamp in	zulu
                }

            }    # End foreach field
                 # Create APRS packet
            $aprs_ws =
                "SM5NRK-1>APRS,TRACE5-5:;"
              . $AirportCode
              . "     *";    # Header + Airport
            $aprs_ws =
              $aprs_ws . $aprs_time . "z" . $AirportPos . "_";    # Time + Pos
            $aprs_ws = $aprs_ws . $aprs_winddir . "/" . $aprs_windspeed;  # Wind
            if ( $gust_speed != 0 ) {
                $aprs_ws = $aprs_ws . "g" . $aprs_gustspeed;              # Gust
            }
            $aprs_ws = $aprs_ws . "t" . $aprs_temp;        # Temperatur
            $aprs_ws = $aprs_ws . "b" . $aprs_presure;     # Presure
            $aprs_ws = $aprs_ws . "h" . $aprs_humidity;    # Humidity
            $aprs_ws = $aprs_ws . " $AirportName";         # Comment

            #			print "$aprs_ws\n";
            set $tnc_output $aprs_ws;
        }    # End each matched airport
    }    # End each airport

    ###	End	section	for	APRS Weather

    # chop off stuff we	don't care to hear read
    #	 $text =~ s/.+Add this sticker to your homepage\!(.+)/$1/s;
    $text =~ s/.+ESKN /$1/s;    # ESKN = Skavsta Airport, Nyköping,	Sweden
    $text =~ s/=.+/$1/s;

    #	 print_log $text;

    # convert any weather related acronyms or abbreviations	to readable	forms
    # Note:	Does not take care of 0	(Zero)
    # Note:	Does not take care of minus	temperature
    # Note:	Error if temp is more than 2 characters	= Minus
    # Note:	Does not take care of time field

    @data = split( '	', $text );
    foreach $data (@data) {

        #		print_log $data;
        if ( $data =~ /KT/ ) {
            $wind_direction = substr( $data, 0, 3 );
            $aprs_winddir = $wind_direction;
            if ( $wind_direction >= 0 && $wind_direction <= 22 ) {
                $wind_direction = "North";
            }
            if ( $wind_direction >= 23 && $wind_direction <= 67 ) {
                $wind_direction = "NorthEast";
            }
            if ( $wind_direction >= 68 && $wind_direction <= 112 ) {
                $wind_direction = "East";
            }
            if ( $wind_direction >= 113 && $wind_direction <= 157 ) {
                $wind_direction = "SouthEast";
            }
            if ( $wind_direction >= 158 && $wind_direction <= 202 ) {
                $wind_direction = "South";
            }
            if ( $wind_direction >= 203 && $wind_direction <= 247 ) {
                $wind_direction = "SouthWest";
            }
            if ( $wind_direction >= 248 && $wind_direction <= 292 ) {
                $wind_direction = "West";
            }
            if ( $wind_direction >= 293 && $wind_direction <= 337 ) {
                $wind_direction = "NorthWest";
            }
            if ( $wind_direction >= 338 && $wind_direction <= 360 ) {
                $wind_direction = "North";
            }
            $wind_speed = substr( $data, 3, 2 );
            $wind_speed =~ s/^0+/$1/s;
            $aprs_windspeed = sprintf( "%03d", $wind_speed * 1.852 / 1.609344 );
        }
        if ( $data =~ /\// ) {
            $temp      = substr( $data, 0, 2 );
            $aprs_temp = $temp;
            $dew       = substr( $data, 3, 2 );
            $temp =~ s/^0+/$1/s;
            $dew =~ s/^0+/$1/s;
            $aprs_temp = $temp * 9 / 5 + 32;
            $aprs_temp = sprintf( "%03d", $temp * 9 / 5 + 32 );

        }
        if ( $data =~ /Q/ ) {
            $presure = substr( $data, 1, 4 );
            $aprs_presure = $presure . "0";
        }
        if ( $data =~ /Z/ ) {
            $aprs_time = substr( $data, 0, 6 );
        }
    }

    $text = "Wind speed $wind_speed knots $wind_direction";
    $text .= ",	Temperature	$temp degrees, dewpoint	$dew degrees";
    $text .= ",	Presure	$presure millibar\n";

    # HTML::FormatText converts	&#176; to the 'degrees'	string °.
    # which	is ascii decimal 176 or	hex	b0.
    #	$text =~ s/\&\#176\;/ degrees /g;
    #	 $text =~ s/\xb0/ degrees /g;

    #	 $text =~ s/\q&nbsp\;/ /g;
    #	 $text =~ s/\[IMAGE\]//g;
    #	 $text =~ s/\(Click for forecast\)//g;
    #	 $text =~ s/approx./ approximately /g;
    #	 $text =~ s/\s+F\s+/ Fahrenheit	/g;
    #	 $text =~ s/\s+%\s+/ Percent /g;
    #	 $text =~ s/Moon Phase//g;
    #	 $text =~ s/\s+N\s+/ North /g;
    #	 $text =~ s/\s+NE\s+/ NorthEast	/g;
    #	 $text =~ s/\s+NNE\s+/ North by	NorthEast /g;
    #	 $text =~ s/\s+NNW\s+/ North by	NorthWest /g;
    #	 $text =~ s/\s+E\s+/ East /g;
    #	 $text =~ s/\s+SE\s+/ SouthEast	/g;
    #	 $text =~ s/\s+W\s+/ West /g;
    #	 $text =~ s/\s+SW\s+/ South	West /g;
    #	 $text =~ s/\s+S\s+/ South /g;
    #	 $text =~ s/\s+NW\s+/ NorthWest	/g;
    #	 $text =~ s/\s+SSE\s+/ South by	SouthEast /g;
    #	 $text =~ s/\s+SSW\s+/ South by	SouthWest /g;

    file_write( $f_weather_page, $text );

    #	 display $f_weather_page;
##	   speak "$WeatherFile retrieved!";

    #	  $aprs_ws = "SM5NRK>TNC:;ESKN	   *\@000000/5847.10N/01655.32E_" .	$aprs_winddir .	"/"	. $aprs_windspeed .	"t"	. $aprs_temp . "b" . $aprs_presure;
    #	  print	$aprs_ws;
    #	  set $udp_output $aprs_ws;

    #	WU2Z>APRSM,WIDE,WIDE:_06150811c302s001g002t069r000p000P000h99b10151mDAV
    #	WU2Z*>APM348,WIDE,WIDE:_06150811c302s001g002t069r000p000P000h99b10151mDAV
    #	WU2Z>APM350,TCPIP*:_06150812c302s002g002t069r000p000P000h99b10151mDAV
    #	WU2Z>APRSM,WIDE,WIDE:_06150821c302s001g001t069r000p000P000h99b10151mDAV
    #	WU2Z>APRSM,WIDE,WIDE:_06150831c302s000g000t069r000p000P000h99b10153mDAV

}

if ( done_now $p_weather_forecast_page) {
    my $html = file_read $f_weather_forecast_html;

    $text = HTML::FormatText->new( leftmargin => 0, rightmargin => 150 )
      ->format( HTML::TreeBuilder->new()->parse($html) );

    print_log $text;
    print_log $Day;
    if ( $Day eq "Sat" )  { $dag = "Lördag"; }
    if ( $Day eq "Sun" )  { $dag = "Söndag"; }
    if ( $Day eq "Mon" )  { $dag = "Måndag"; }
    if ( $Day eq "Tue" )  { $dag = "Tisdag"; }
    if ( $Day eq "Wed" )  { $dag = "Onsdag"; }
    if ( $Day eq "Thur" ) { $dag = "Torsdag"; }
    if ( $Day eq "Fri" )  { $dag = "Fredag"; }

    # chop	off	stuff we don't care	to hear	read
    #	 $text =~ s/.+Add this sticker to your homepage\!(.+)/$1/s;
    $text =~ s/.+$dag/$1/s;    # ESKN = Skavsta Airport, Nyköping,	Sweden
    $text =~ s/Prognoser.+/$1/s;

    #	 $text =~ s/ö/oe/g;
    #	 $text =~ s/ä/ai/g;
    #	 $text =~ s/å/oa/g;
    $text =~ s/\[IMAGE]//g;
    $text =~ s/\n/ /g;
    $text =~ s/\272C//g;
    $text =~ s/\240//g;
    $text =~ s/	\d+	m\/s / /g;

    #	 $text	= "Wind	speed $wind_speed knots	$wind_direction";
    #	 $text .= ", Temperature $temp degrees,	dewpoint $dew degrees";
    #	 $text .= ", Presure $presure millibar\n";

    # HTML::FormatText converts	&#176; to the 'degrees'	string °.
    # which	is ascii decimal 176 or	hex	b0.
    #	$text =~ s/\&\#176\;/ degrees /g;
    #	 $text =~ s/\xb0/ degrees /g;

    #	 $text =~ s/\q&nbsp\;/ /g;
    #	 $text =~ s/\[IMAGE\]//g;
    #	 $text =~ s/\(Click for forecast\)//g;
    #	 $text =~ s/approx./ approximately /g;
    #	 $text =~ s/\s+F\s+/ Fahrenheit	/g;
    #	 $text =~ s/\s+%\s+/ Percent /g;
    #	 $text =~ s/Moon Phase//g;
    #	 $text =~ s/\s+N\s+/ North /g;
    #	 $text =~ s/\s+NE\s+/ NorthEast	/g;
    #	 $text =~ s/\s+NNE\s+/ North by	NorthEast /g;
    #	 $text =~ s/\s+NNW\s+/ North by	NorthWest /g;
    #	 $text =~ s/\s+E\s+/ East /g;
    #	 $text =~ s/\s+SE\s+/ SouthEast	/g;
    #	 $text =~ s/\s+W\s+/ West /g;
    #	 $text =~ s/\s+SW\s+/ South	West /g;
    #	 $text =~ s/\s+S\s+/ South /g;
    #	 $text =~ s/\s+NW\s+/ NorthWest	/g;
    #	 $text =~ s/\s+SSE\s+/ South by	SouthEast /g;
    #	 $text =~ s/\s+SSW\s+/ South by	SouthWest /g;

    file_write( $f_weather_forecast_page, $text );

    #	 display $f_weather_forecast_page;
    speak "$WeatherFileForecast retrieved!";

}

