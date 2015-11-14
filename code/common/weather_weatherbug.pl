        # Program:      To get and parse the Forecast using the API from  wxbug
        # Author:       J. Serack
        # Contributor:  David Norwood
        # Orginal date: Nov 28, 2007
        # Last change date: Jan 3, 2009
        # This next line categorizes the program for program code control
        # Category=Weather
        # These next lines provide a description of the code in the common code activation web interface
        #@ Gets the current weather conditions and weather forecast from <a href="http://www.weatherbug.com">Weatherbug</a>
        #@ using the XML API key registered to Misterhouse and is intended to be useable
        #@ globally.
        #@ This code uses XML::Twig perl module, which is included with Misterhouse.
        #@ <bk/>
        #@ The location that the forecast is for is determined by;
        #@ A citycode - for international cities if supplied in the configuration
        #@ The zipcode - for US cities if defined in the .ini file or by the user
        #@ The latitude and longitude (for NA) if defined in the .ini file
        #@ or by the configuration parameters (in that order of precident)
        #@ The forecast received is compared to the city defined in the .ini file or by
        #@ the user in the user code activation screen of the web interface. If the city
        #@ does not match the forecast is INVALID and will not process! Pay special attention if you use the lattitude and longitude to specify location because the city name may be different that you might expect (e.g. Kanata, Nepean, ... are all sub cities of Ottawa, Canada - moving the longitude a few minutes gives a different city name.
        #@#@ <bk/>
        #@ Also note that changes to the location only take effect on a reboot!
        #@ The forecast information is populated into a weather hash for other
        #@ functions to access to deliver capabilites to user scripts.
        #@ <bk/>
        #@ The source of the data comes from rss.wxbug.com
        #@ This API was originally written by Jim Serack in November 2007
        #@ Updates were coded by Jim Serack and David Norwood in Dec 2008
        # Revision History
        # Jan 3, 2009	David updated the documentation and made cosmetic
        #		changes in preparation for first svn commit
        # Dec 6, 2008 	David converted the forecast processing to XML::Twig
        #		and cleaned up some logic
        # Dec 4, 2008 	fixed the not conditions for raining and snowing
        #               and added the config for what elements are
        # 		populated into weather_common
        # Dec 1, 2008 	fixed the maximum conditions value, ammount (sp)
        # Nov 27, 2008 	major update completing the code
        #
        # To do: change the name of the xml files to weatherbug roots, add default elements to populate in the setup, improve the debug toggle to state the result, simplify the observation section to use twig, and simplify the variable names to match the populate_internet_weather, consider a module to populate_forecast_weather, create weather{going_to_be_hot} like logic, add support for US weather alerts
        #
        # A properly formed call looks like this
        # http://api.wxbug.net/getForecastRSS.aspx?ACode=APIKEY&citycode=54256&unittype=1
        # -----------------------------------------------------------------------
        # noloop=start
        use Weather_Common;

        # Define config parameters
        # add variables for the weatherbug feed
        my $weatherbug_city  = $config_parms{weather_weatherbug_city};
        my $weatherbug_state = lc( $config_parms{weather_weatherbug_state} );
        my $weatherbug_country =
          lc( $config_parms{weather_weatherbug_country} );
        my $weatherbug_units     = $config_parms{weather_weatherbug_units};
        my $weatherbug_citycode  = $config_parms{weather_weatherbug_citycode};
        my $weatherbug_zipcode   = $config_parms{weather_weatherbug_zipcode};
        my $weatherbug_latitude  = $config_parms{weather_weatherbug_latitude};
        my $weatherbug_longitude = $config_parms{weather_weatherbug_longitude};

        # build the url from existing init variables if the values have been left blank
        $weatherbug_state = uc( $config_parms{state} ) unless $weatherbug_state;
        $weatherbug_country = uc( $config_parms{country} )
          unless $weatherbug_country;
        $weatherbug_city    = $config_parms{city}    unless $weatherbug_city;
        $weatherbug_zipcode = $config_parms{zipcode} unless $weatherbug_zipcode;
        $weatherbug_latitude = $config_parms{latitude}
          unless $weatherbug_latitude;
        $weatherbug_longitude = $config_parms{longitude}
          unless $weatherbug_longitude;
        unless ( $weatherbug_units eq "1" or $weatherbug_units eq "0" ) {
            $weatherbug_units = "1";
            $weatherbug_units = "0"
              if ( $config_parms{weather_uom_temp} ne "C" );
        }

        # complete the url for the rss feed
        my $weatherbug_url;
        my $key =
          "A" . ( ( ( 149 * 37 * 2 * 5 * 37 + 23 ) * 9 * 17 ) + 10 ) * 3 * 5;
        my $weatherbug_file =
          $config_parms{data_dir} . '/web/weather_weatherbug_frcst.xml';
        my $weatherbug_obs_file =
          $config_parms{data_dir} . '/web/weather_weatherbug_obs.xml';

        # Define the url that is used to fetch the forecast
        # use the lattitude and longitude form if they are available
        $weatherbug_url =
            "http://api.wxbug.net/getForecastRSS.aspx?ACode="
          . $key . "&lat="
          . $weatherbug_latitude
          . "&long="
          . $weatherbug_longitude
          . "&unittype="
          . $weatherbug_units
          if ( $weatherbug_latitude ne "" and $weatherbug_longitude ne "" );

        # 2nd Priority use the zipcode form if the zipcode is available
        $weatherbug_url =
            "http://api.wxbug.net/getForecastRSS.aspx?ACode="
          . $key
          . "&zipcode="
          . $weatherbug_zipcode
          . "&unittype="
          . $weatherbug_units
          if ( $weatherbug_zipcode ne "" );

        # First Priority so test last - and use the city code if assigned
        $weatherbug_url =
            "http://api.wxbug.net/getForecastRSS.aspx?ACode="
          . $key
          . "&citycode="
          . $weatherbug_citycode
          . "&unittype="
          . $weatherbug_units
          if ( $weatherbug_citycode ne "" );
        logit( "$config_parms{data_dir}/web/weatherbug_debug",
            $weatherbug_url, 13, 0 )
          if ( $Debug{weatherbug} );

        # Define the new process item that fetchs the RSS feed for the location
        $p_weather_weatherbug_forecast = new Process_Item(
            qq{get_url -quiet "$weatherbug_url" "$weatherbug_file"});

        # Need to add a process to search for the citycode
        $weatherbug_url =
            "http://api.wxbug.net/getLocationsXML.aspx?ACode="
          . $key
          . "&searchString="
          . lc($weatherbug_city);
        logit( "$config_parms{data_dir}/web/weatherbug_debug",
            $weatherbug_url, 13, 0 )
          if ( $Debug{weatherbug} );

        # Define the new process item that fetchs the RSS feed for the location
        $p_weather_weatherbug_citycode = new Process_Item(
            qq{get_url -quiet "$weatherbug_url" "$weatherbug_file"});

        # Need to add a process to get the live observations
        # use the lattitude and longitude form if they are available
        $weatherbug_url =
            "http://api.wxbug.net/getLiveWeatherRSS.aspx?ACode="
          . $key . "&lat="
          . $weatherbug_latitude
          . "&long="
          . $weatherbug_longitude
          . "&unittype="
          . $weatherbug_units
          if ( $weatherbug_latitude ne "" and $weatherbug_longitude ne "" );

        # 2nd Priority use the zipcode form if the zipcode is available
        $weatherbug_url =
            "http://api.wxbug.net/getLiveWeatherRSS.aspx?ACode="
          . $key
          . "&zipcode="
          . $weatherbug_zipcode
          . "&unittype="
          . $weatherbug_units
          if ( $weatherbug_zipcode ne "" );

        # First Priority so test last - and use the city code if assigned
        $weatherbug_url =
            "http://api.wxbug.net/getLiveWeatherRSS.aspx?ACode="
          . $key
          . "&citycode="
          . $weatherbug_citycode
          . "&unittype="
          . $weatherbug_units
          if ( $weatherbug_citycode ne "" );
        logit( "$config_parms{data_dir}/web/weatherbug_debug",
            $weatherbug_url, 13, 0 )
          if ( $Debug{weatherbug} );

        # Define the new process item that fetchs the RSS feed for the location
        $p_weather_weatherbug_liveweather = new Process_Item(
            qq{get_url -quiet "$weatherbug_url" "$weatherbug_obs_file"});

        # Define the voice commands that are used to get and process the RSS feed
        my $weatherbug_states = 'getforecast,LiveWeather,getcitycode,debug';
        $v_weatherbug = new Voice_Cmd("Weatherbug [$weatherbug_states]");

        # Define the lists of returned conditions by image code
        # Conditions from wxbug api definition
        # Here is a list of all the possible forecast conditions.
        # Corresponds to the image code in the RSS forecast
        # From Nov 2007 to Nov 2008 some of the descriptions were changed and a few
        # were added - the API version number did not change - so the only way to
        # provide some protection is to use a count of the maximum number of conditions
        # excluding 999 which is unknown.
        my $wxbug_maximum_code = 176;
        my @wxbug_conditions   = (
            "Clear",
            "Cloudy",
            "Partly Cloudy",
            "Partly Cloudy",
            "Partly Sunny",
            "Rain",
            "Thunderstorms",
            "Sunny",
            "Snow",
            "Flurries",
            "Unknown",
            "Chance of Snow",
            "Snow",
            "Cloudy",
            "Rain",
            "Chance of Rain",
            "Partly Cloudy",
            "Fair",
            "Thunderstorms",
            "Chance of Flurry",
            "Chance of Rain",
            "Chance of Sleet",
            "Chance of Storms",
            "Hazy",
            "Mostly Cloudy",
            "Sleet",
            "Mostly Sunny",
            "Chance of Flurry",
            "Chance of Sleet ",
            "Chance of Snow",
            "Chance of Storms",
            "Clear",
            "Flurries",
            "Hazy",
            "Mostly Cloudy ",
            "Fair",
            "Sleet",
            "Unknown",
            "Chance of Rain Showers",
            "Chance of Snow Showers",
            "Snow Showers",
            "Rain Showers",
            "Chance of Rain Showers",
            "Chance of Snow Showers",
            "Snow Showers",
            "Rain Showers",
            "Freezing Rain",
            "Freezing Rain",
            "Chance Freezing Rain",
            "Chance Freezing Rain",
            "Windy",
            "Fog",
            "Scattered Showers",
            "Scattered Thunderstorms",
            "Light Snow",
            "Chance of Light Snow",
            "Frozen Mix",
            "Chance of Frozen Mix",
            "Drizzle",
            "Chance of Drizzle",
            "Freezing Drizzle",
            "Chance of Freezing Drizzle",
            "Heavy Snow",
            "Heavy Rain",
            "Hot and Humid",
            "Very Hot",
            "Increasing Clouds",
            "Clearing",
            "Mostly Cloudy",
            "Very Cold",
            "Mostly Clear",
            "Increasing Clouds",
            "Clearing",
            "Mostly Cloudy",
            "Very Cold",
            "Warm and Humid",
            "Nowcast",
            "Headline",
            "30% Chance of Snow",
            "40% Chance of Snow",
            "50% Chance of Snow",
            "30% Chance of Rain",
            "40% Chance of Rain",
            "50% Chance of Rain",
            "30% Chance of Flurry",
            "40% Chance of Flurry",
            "50% Chance of Flurry",
            "30% Chance of Rain",
            "40% Chance of Rain",
            "50% Chance of Rain",
            "30% Chance of Sleet",
            "40% Chance of Sleet",
            "50% Chance of Sleet",
            "30% Chance of Storms",
            "40% Chance of Storms",
            "50% Chance of Storms",
            "30% Chance of Flurry",
            "40% Chance of Flurry",
            "50% Chance of Flurry",
            "30% Chance of Sleet",
            "40% Chance of Sleet",
            "50% Chance of Sleet",
            "30% Chance of Snow",
            "40% Chance of Snow",
            "50% Chance of Snow",
            "30% Chance of Storms",
            "40% Chance of Storms",
            "50% Chance of Storms",
            "30% Chance Rain Shower",
            "40% Chance Rain Shower",
            "50% Chance Rain Shower",
            "30% Chance Snow Shower",
            "40% Chance Snow Shower",
            "50% Chance Snow Shower",
            "30% Chance Rain Shower",
            "40% Chance Rain Shower",
            "50% Chance Rain Shower",
            "30% Chance Snow Shower",
            "40% Chance Snow Shower",
            "50% Chance Snow Shower",
            "30% Chance Freezing Rain",
            "40% Chance Freezing Rain",
            "50% Chance Freezing Rain",
            "30% Chance Freezing Rain",
            "40% Chance Freezing Rain",
            "50% Chance Freezing Rain",
            "30% Chance of Light Snow",
            "40% Chance of Light Snow",
            "50% Chance of Light Snow",
            "30% Chance of Frozen Mix",
            "40% Chance of Frozen Mix",
            "50% Chance of Frozen Mix",
            "30% Chance of Drizzle",
            "40% Chance of Drizzle",
            "50% Chance of Drizzle",
            "30% Chance Freezing Drizzle",
            "40% Chance Freezing Drizzle",
            "50% Chance Freezing Drizzle",
            "Chance of Snow",
            "Chance of Rain",
            "Chance of Flurry",
            "Chance of Rain",
            "Chance of Sleet",
            "Chance of Storms",
            "Chance of Flurry",
            "Chance of Sleet",
            "Chance of Snow",
            "Chance of Storms",
            "Chance Rain Shower",
            "Chance Snow Shower",
            "Chance Rain Shower",
            "Chance Snow Shower",
            "Chance Freezing Rain",
            "Chance Freezing Rain",
            "Chance of Light Snow",
            "Chance of Frozen Mix",
            "Chance of Drizzle",
            "Chance Freezing Drizzle",
            "windy",
            "Foggy",
            "Light Snow",
            "Frozen Mix",
            "Drizzle",
            "Heavy Rain",
            "Chance of Frozen Mix",
            "Chance of Drizzle",
            "Chance of Frozen Drizzle",
            "30% Chance Drizzle",
            "30% Chance Frozen Drizzle",
            "30% Chance Frozen Mix",
            "40% Chance Drizzle",
            "40% Chance Fozen Drizzle",
            "40% Chance Frozen Mix",
            "40% Chance Drizzle",
            "40% Chance Frozen Drizzle",
            "40% Chance Frozen Mix",
            "Chance of Light Snow"
        );

        # conditions simplified for rain and snow
        my @wxbug_precip_type = (
            "Clear",    "Overcast", "Overcast", "Overcast",
            "Clear",    "Rain",     "Rain",     "Clear",
            "Snow",     "Snow",     "Clear",    "Snow",
            "Snow",     "Overcast", "Rain",     "Rain",
            "Clear",    "Clear",    "Rain",     "Snow",
            "Rain",     "Ice",      "Rain",     "Overcast",
            "Overcast", "Ice",      "Clear",    "Snow",
            "Ice",      "Snow",     "Rain",     "Clear",
            "Snow",     "Overcast", "Overcast", "Clear",
            "Ice",      "Clear",    "Rain",     "Snow",
            "Snow",     "Rain",     "Rain",     "Snow",
            "Snow",     "Rain",     "Ice",      "Ice",
            "Ice",      "Ice",      "Clear",    "Overcast",
            "Rain",     "Rain",     "Snow",     "Snow",
            "Ice",      "Ice",      "Rain",     "Rain",
            "Ice",      "Rain",     "Snow",     "Rain",
            "Clear",    "Clear",    "Overcast", "Clear",
            "Overcast", "Clear",    "Clear",    "Overcast",
            "Clear",    "Overcast", "Clear",    "Clear",
            "Clear",    "Clear",    "Snow",     "Snow",
            "Snow",     "Rain",     "Rain",     "Rain",
            "Snow",     "Snow",     "Snow",     "Rain",
            "Rain",     "Rain",     "Ice",      "Ice",
            "Ice",      "Rain",     "Rain",     "Rain",
            "Snow",     "Snow",     "Snow",     "Ice",
            "Ice",      "Ice",      "Snow",     "Snow",
            "Snow",     "Rain",     "Rain",     "Rain",
            "Rain",     "Rain",     "Rain",     "Snow",
            "Snow",     "Snow",     "Rain",     "Rain",
            "Rain",     "Snow",     "Snow",     "Snow",
            "Ice",      "Ice",      "Ice",      "Ice",
            "Ice",      "Ice",      "Snow",     "Snow",
            "Snow",     "Ice",      "Ice",      "Ice",
            "Rain",     "Rain",     "Rain",     "Ice",
            "Ice",      "Ice",      "Snow",     "Rain",
            "Snow",     "Rain",     "Ice",      "Rain",
            "Snow",     "Ice",      "Snow",     "Rain",
            "Rain",     "Snow",     "Rain",     "Snow",
            "Ice",      "Ice",      "Snow",     "Ice",
            "Rain",     "Ice",      "Clear",    "Overcast",
            "Snow",     "Mixed",    "Rain",     "Rain",
            "Mixed",    "Rain",     "Mixed",    "Rain",
            "Rain",     "",         "Rain",     "Mixed",
            "Mixed",    "Rain",     "Mixed",    "Mixed",
            "Snow"
        );

        # inferred amount of precipatation
        my @wxbug_precip_ammount = (
            "None",     "None",     "None",     "None",
            "None",     "Moderate", "Moderate", "None",
            "Moderate", "Light",    "None",     "Light",
            "Moderate", "None",     "Moderate", "Light",
            "None",     "None",     "Moderate", "Light",
            "Light",    "Light",    "Light",    "None",
            "None",     "Light",    "None",     "Light",
            "Light",    "Light",    "Light",    "None",
            "Light",    "None",     "None",     "None",
            "Light",    "None",     "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Moderate", "Moderate",
            "Light",    "Light",    "None",     "None",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Trace",    "Trace",
            "Trace",    "Trace",    "Heavy",    "Heavy",
            "None",     "None",     "None",     "None",
            "None",     "None",     "None",     "None",
            "None",     "None",     "None",     "None",
            "None",     "None",     "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Trace",    "Trace",    "Trace",    "Trace",
            "Trace",    "Trace",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Light",    "Light",    "Light",    "Light",
            "Trace",    "Trace",    "None",     "None",
            "Light",    "Light",    "Trace",    "Heavy",
            "Trace",    "Trace",    "Trace",    "Trace",
            "Trace",    "Trace",    "Trace",    "Trace",
            "Trace",    "Trace",    "Trace",    "Trace",
            "Trace"
        );

        # noloop=stop
        # -----------------------------------------------------------------------
        # set the triggers for calling the updated forecast
        if ($Reload) {
            &trigger_set(
                '($New_Minute and $Minute == 55) or $Reload',
                "run_voice_cmd 'Weatherbug getforecast'",
                'NoExpire',
                'Update weather forecast via WeatherBug'
            ) unless &trigger_get('Update weather forecast via WeatherBug');
            &trigger_set(
                '($New_Minute and $Minute == 5) or $Reload',
                "run_voice_cmd 'Weatherbug LiveWeather'",
                'NoExpire',
                'Update current weather via WeatherBug'
            ) unless &trigger_get('Update current weather via WeatherBug');
        }

        # -----------------------------------------------------------------------
        my $weatherbug_state = 'blank';
        if ( $weatherbug_state = $v_weatherbug->{said} ) {
            if ( $weatherbug_state eq 'getforecast' ) {
                start $p_weather_weatherbug_forecast;
            } # ----------------------------------------------------------------------
            if ( $weatherbug_state eq 'getcitycode' ) {
                start $p_weather_weatherbug_citycode;
            } # ----------------------------------------------------------------------
            if ( $weatherbug_state eq 'LiveWeather' ) {
                start $p_weather_weatherbug_liveweather;
            } # ----------------------------------------------------------------------
            if ( $weatherbug_state eq 'debug' ) {

                # toggle the debug state
                my $debug = 0;
                $debug = 0 if ( $Debug{weatherbug} == 1 );
                $debug = 1 if ( $Debug{weatherbug} == 0 );
                $Debug{weatherbug} = $debug;
            } # ----------------------------------------------------------------------
        }

        #------------- End of voice commands said if block ---------------------
        # this next code run when the processes are completed and the file is ready
        # ------------ Get LiveWeather -----------------
        if ( done_now $p_weather_weatherbug_liveweather) {
            $Weather{weatherbug_obsv_valid} = 0; #Set to not valid unless proven
            my $weatherbug_xml = file_read $weatherbug_obs_file;
            print_log "Weatherbug location liveweather.";

            # should do a check on the api version <aws:api version="2.0" />
            my $pattern = '<aws:ob>(.*?)</aws:ob>';
            my ($f_observation) = $weatherbug_xml =~ /$pattern/;
            $Weather{weatherbug_obsv_valid} = 1;
            my $pattern = '<aws:ob-date>(.*?)</aws:ob-date>';
            my ($f_obdate) = $f_observation =~ /$pattern/;

            #<aws:year number="2008" />
            my $pattern = '<aws:year number="20(\d+)"';
            my ($f_obyear) = $f_obdate =~ /$pattern/;

            #<aws:month number="11" text="November" abbrv="Nov" />
            my $pattern = '<aws:month number="(\d+)';
            my ($f_obmonth) = $f_obdate =~ /$pattern/;

            #<aws:day number="26" text="Wednesday" abbrv="Wed" />
            my $pattern = '<aws:day number="(\d+)';
            my ($f_obday) = $f_obdate =~ /$pattern/;

            #<aws:hour number="3" hour-24="15" />
            my $pattern = '<aws:hour number="(\d+)';
            my ($f_obhour) = $f_obdate =~ /$pattern/;

            #<aws:minute number="00" />
            my $pattern = '<aws:minute number="(\d+)';
            my ($f_obmin) = $f_obdate =~ /$pattern/;

            #<aws:second number="00" />
            my $pattern = '<aws:second number="(\d+)';
            my ($f_obsec) = $f_obdate =~ /$pattern/;

            #<aws:am-pm abbrv="PM" />
            my $pattern = '<aws:am-pm abbrv="([APM]*)"';
            my ($f_obampm) = $f_obdate =~ /$pattern/;
            my $f_obsdate =
                $f_obmonth . "/"
              . $f_obday . "/"
              . $f_obyear . " "
              . $f_obhour . ":"
              . $f_obmin . " "
              . $f_obampm;
            my $pattern = '<aws:station>(.*?)</aws:station>';
            my ($f_station) = $f_observation =~ /$pattern/;

            #<aws:requested-station-id />
            #<aws:station-id>CYOW</aws:station-id>
            #<aws:station>Ottawa International Airport</aws:station>
            #<aws:city-state citycode="54256">Ottawa,  ON</aws:city-state>
            #<aws:country>Canada</aws:country>
            #<aws:latitude>45.3166666666667</aws:latitude>
            #<aws:longitude>-75.6666666666667</aws:longitude>
            #<aws:site-url />
            #<aws:aux-temp units="&amp;deg;C">-47</aws:aux-temp>
            #<aws:aux-temp-rate units="&amp;deg;C">+0.0</aws:aux-temp-rate>
            my $pattern                 = '.gif">(.*?)</aws:current-condition>';
            my ($f_currentcondition)    = $f_observation =~ /$pattern/;
            my $pattern                 = 'cond(\d+).gif';
            my ($f_currentconditionnum) = $f_observation =~ /$pattern/;

            #<aws:current-condition icon="http://deskwx.weatherbug.com/images/Forecast/icons/cond054.gif">Light Snow</aws:current-condition>
            my $pattern = '>(-?\d+)</aws:dew-point>';
            my ($f_dewpoint) = $f_observation =~ /$pattern/;

            #<aws:dew-point units="&amp;deg;C">-0</aws:dew-point>
            #<aws:elevation units="m">100</aws:elevation>
            my $pattern = '>(-?\d+)</aws:feels-like>';
            my ($f_feelslike) = $f_observation =~ /$pattern/;

            #<aws:feels-like units="&amp;deg;C">-5</aws:feels-like>
            my $pattern     = '<aws:gust-time>(.*?)</aws:gust-time>';
            my ($f_obdate)  = $f_observation =~ /$pattern/;
            my $pattern     = '<aws:year number="20(\d+)"';
            my ($f_obyear)  = $f_obdate =~ /$pattern/;
            my $pattern     = '<aws:month number="(\d+)';
            my ($f_obmonth) = $f_obdate =~ /$pattern/;
            my $pattern     = '<aws:day number="(\d+)';
            my ($f_obday)   = $f_obdate =~ /$pattern/;
            my $pattern     = '<aws:hour number="(\d+)';
            my ($f_obhour)  = $f_obdate =~ /$pattern/;
            my $pattern     = '<aws:minute number="(\d+)';
            my ($f_obmin)   = $f_obdate =~ /$pattern/;
            my $pattern     = '<aws:second number="(\d+)';
            my ($f_obsec)   = $f_obdate =~ /$pattern/;
            my $pattern     = '<aws:am-pm abbrv="([APM]*)"';
            my ($f_obampm)  = $f_obdate =~ /$pattern/;
            my $f_gustdate =
                $f_obmonth . "/"
              . $f_obday . "/"
              . $f_obyear . " "
              . $f_obhour . ":"
              . $f_obmin . " "
              . $f_obampm;

            #<aws:gust-time>
            #<aws:year number="2008" />
            #<aws:month number="11" text="November" abbrv="Nov" />
            #<aws:day number="26" text="Wednesday" abbrv="Wed" />
            #<aws:hour number="12" hour-24="12" />
            #<aws:minute number="00" />
            #<aws:second number="00" />
            #<aws:am-pm abbrv="PM" />
            #</aws:gust-time>
            my $pattern = '>([NSWE]*)</aws:gust-direction>';
            my ($f_gustdirection) = $f_observation =~ /$pattern/;

            #<aws:gust-direction>SSW</aws:gust-direction>
            my $pattern = '>(\d+)</aws:gust-speed>';
            my ($f_gustspeed) = $f_observation =~ /$pattern/;

            #<aws:gust-speed units="km">17</aws:gust-speed>
            my $pattern = '>(\d+)</aws:humidity>';
            my ($f_humidity) = $f_observation =~ /$pattern/;

            #<aws:humidity units="%">100</aws:humidity>
            #<aws:humidity-high units="%">100.0</aws:humidity-high>
            #<aws:humidity-low units="%">93.0</aws:humidity-low>
            #<aws:humidity-rate>+0.0</aws:humidity-rate>
            #<aws:indoor-temp units="&amp;deg;C">-18</aws:indoor-temp>
            #<aws:indoor-temp-rate units="&amp;deg;C">+0.0</aws:indoor-temp-rate>
            #<aws:light>0</aws:light>
            #<aws:light-rate>+0.0</aws:light-rate>
            #<aws:moon-phase moon-phase-img="http://api.wxbug.net/images/moonphase/mphase01.gif">3</aws:moon-phase>
            my $pattern = '>(\d+.?\d+)</aws:pressure>';
            my ($f_pressure) = $f_observation =~ /$pattern/;

            #<aws:pressure units="mbar">1004.74</aws:pressure>
            #<aws:pressure-high units="mbar">1004.74</aws:pressure-high>
            #<aws:pressure-low units="mbar">1001.36</aws:pressure-low>
            #<aws:pressure-rate units="mbar/h">+0.00</aws:pressure-rate>
            #<aws:rain-month units="mm">0.0</aws:rain-month>
            #<aws:rain-rate units="mm/h">0.0</aws:rain-rate>
            #<aws:rain-rate-max units="mm/h">0.0</aws:rain-rate-max>
            #<aws:rain-today units="mm">0.0</aws:rain-today>
            #<aws:rain-year units="mm">0.0</aws:rain-year>
            my $pattern = '>(-?\d+.?\d+)</aws:temp>';
            my ($f_temp) = $f_observation =~ /$pattern/;

            #<aws:temp units="&amp;deg;C">-0.0</aws:temp>
            #<aws:temp-high units="&amp;deg;C">1</aws:temp-high>
            #<aws:temp-low units="&amp;deg;C">-0</aws:temp-low>
            #<aws:temp-rate units="&amp;deg;C/h">+0.0</aws:temp-rate>
            #<aws:sunrise>
            #<aws:year number="2008" />
            #<aws:month number="11" text="November" abbrv="Nov" />
            #<aws:day number="26" text="Wednesday" abbrv="Wed" />
            #<aws:hour number="7" hour-24="07" />
            #<aws:minute number="16" />
            #<aws:second number="39" />
            #<aws:am-pm abbrv="AM" />
            #</aws:sunrise>
            #<aws:sunset>
            #<aws:year number="2008" />
            #<aws:month number="11" text="November" abbrv="Nov" />
            #<aws:day number="26" text="Wednesday" abbrv="Wed" />
            #<aws:hour number="4" hour-24="16" />
            #<aws:minute number="23" />
            #<aws:second number="31" />
            #<aws:am-pm abbrv="PM" />
            #</aws:sunset>
            #<aws:wet-bulb units="&amp;deg;C">0</aws:wet-bulb>
            my $pattern = '>(\d+)</aws:wind-speed>';
            my ($f_windspeed) = $f_observation =~ /$pattern/;

            #<aws:wind-speed units="km">17</aws:wind-speed>
            my $pattern = '>(\d+)</aws:wind-speed-avg>';
            my ($f_windspeedavg) = $f_observation =~ /$pattern/;

            #<aws:wind-speed-avg units="km">17</aws:wind-speed-avg>
            my $pattern = '>([NSWE]*)</aws:wind-direction>';
            my ($f_winddirection) = $f_observation =~ /$pattern/;

            #<aws:wind-direction>SSW</aws:wind-direction>
            my $pattern = '>([NSWE]*)</aws:wind-direction-avg>';
            my ($f_winddirectionavg) = $f_observation =~ /$pattern/;

            #<aws:wind-direction-avg>SSW</aws:wind-direction-avg>
            $Weather{weatherbug_obsv_date}              = $f_obsdate;
            $Weather{weatherbug_obsv_station}           = $f_station;
            $Weather{weatherbug_obsv_currentconditions} = $f_currentcondition;
            $Weather{weatherbug_obsv_currentconditionnumber} =
              $f_currentconditionnum;

            # then the extensions developed for mh tests
            if ( $f_currentconditionnum <= $wxbug_maximum_code ) {
                $Weather{weatherbug_obsv_precip_type} =
                  $wxbug_precip_type[$f_currentconditionnum];
                $Weather{weatherbug_obsv_precip_ammount} =
                  $wxbug_precip_ammount[$f_currentconditionnum];
            }
            else {    # We are here because the code is > known table
                $Weather{weatherbug_obsv_precip_type}    = "Unknown";
                $Weather{weatherbug_obsv_precip_ammount} = "Unknown";
                if ( $f_currentconditionnum != 999 ) {

                    # if it is not the unknown code then the
                    # table needs to be updated
                    print_log "weatherbug: Error check for API update.";
                }
            }    #end else
            $Weather{weatherbug_obsv_dewpoint}         = $f_dewpoint;
            $Weather{weatherbug_obsv_feelslike}        = $f_feelslike;
            $Weather{weatherbug_obsv_gustdirection}    = $f_gustdirection;
            $Weather{weatherbug_obsv_gustspeed}        = $f_gustspeed;
            $Weather{weatherbug_obsv_gustdate}         = $f_gustdate;
            $Weather{weatherbug_obsv_humidity}         = $f_humidity;
            $Weather{weatherbug_obsv_pressure}         = $f_pressure;
            $Weather{weatherbug_obsv_temp}             = $f_temp;
            $Weather{weatherbug_obsv_windspeed}        = $f_windspeed;
            $Weather{weatherbug_obsv_windspeedavg}     = $f_windspeedavg;
            $Weather{weatherbug_obsv_winddirection}    = $f_winddirection;
            $Weather{weatherbug_obsv_winddirectionavg} = $f_winddirectionavg;

            #prepare a vector to pass data to internet weather
            my %wxbug_pass;
            $wxbug_pass{TempOutdoor} = $f_temp;
            $wxbug_pass{DewOutdoor}  = $f_dewpoint;
            $wxbug_pass{WindAvgDir} =
              &Weather_Common::convert_wind_dir_abbr_to_num(
                $f_winddirectionavg);
            $wxbug_pass{WindAvgSpeed} = $f_windspeedavg;
            $wxbug_pass{WindGustDir} =
              &Weather_Common::convert_wind_dir_abbr_to_num($f_gustdirection);
            $wxbug_pass{WindGustSpeed} = $f_gustspeed;
            $wxbug_pass{WindGustTime}  = $f_gustdate;

            if ( $Weather{weatherbug_obsv_precip_type} eq "Clear" ) {
                $wxbug_pass{Clouds}    = "";
                $wxbug_pass{IsRaining} = 0;
                $wxbug_pass{IsSnowing} = 0;
            }
            elsif ( $Weather{weatherbug_obsv_precip_type} eq "Overcast" ) {
                $wxbug_pass{Clouds}    = 1;
                $wxbug_pass{IsRaining} = 0;
                $wxbug_pass{IsSnowing} = 0;
            }
            elsif ( $Weather{weatherbug_obsv_precip_type} eq "Rain" ) {
                $wxbug_pass{Clouds}    = 1;
                $wxbug_pass{IsRaining} = 1;
                $wxbug_pass{IsSnowing} = 0;
            }
            elsif ( $Weather{weatherbug_obsv_precip_type} eq "Snow" ) {
                $wxbug_pass{Clouds}    = 1;
                $wxbug_pass{IsRaining} = 0;
                $wxbug_pass{IsSnowing} = 1;
            }
            elsif ( $Weather{weatherbug_obsv_precip_type} eq "Mixed" ) {
                $wxbug_pass{Clouds}    = 1;
                $wxbug_pass{IsRaining} = 1;
                $wxbug_pass{IsSnowing} = 1;
            }
            else {
                $wxbug_pass{Clouds}    = "";
                $wxbug_pass{IsRaining} = 0;
                $wxbug_pass{IsSnowing} = 0;
            }
            $wxbug_pass{Conditions}           = $f_currentcondition;
            $wxbug_pass{Barom}                = $f_pressure;
            $wxbug_pass{HumidOutdoorMeasured} = 1;
            $wxbug_pass{HumidOutdoor}         = $f_humidity;
            $wxbug_pass{RainRate} =
              $wxbug_precip_ammount[$f_currentconditionnum];
            &Weather_Common::populate_internet_weather( \%wxbug_pass,
                $config_parms{weather_weatherbug_elements} );

            &Weather_Common::weather_updated;
        }

        # ------------ Get Location -----------------
        if ( done_now $p_weather_weatherbug_citycode) {

            # This section is only likely to be used once to get the city code
            # during configuration. It is necessary to provide this code because
            # the api key is necessary to do the search
            # the output is simply put into the print log and then the user
            # selects the correct city code to put into the parameter
            my $weatherbug_xml = file_read $weatherbug_file;

            # Check that the file is valid by looking for locations tag
            if ( $weatherbug_xml =~ /<aws:locations>/ ) {

                # this next step splits the file up into its locations
                # This split depends on there being elements before and after the
                # items like the rss, channel, and the corresponding closing elements
                my @weatherbug_locations;
                my $weatherbug_location;

                # This splits the detailed forecasts into the forecast items
                @weatherbug_locations =
                  split( /<aws:location|\/>/, $weatherbug_xml );

                # The first item, the last item, and every second items are not forecasts - need to test and discard
                # Process each forecast element
                my $rss_locations_counter = 0;
                floop: foreach $weatherbug_location (@weatherbug_locations) {

                    #just use the presence of a valid citycode or zipcode to print a location
                    my $pattern         = 'cityname="(\w+)"';
                    my ($f_cityname)    = $weatherbug_location =~ /$pattern/;
                    my $pattern         = 'statename="(\w+)"';
                    my ($f_statename)   = $weatherbug_location =~ /$pattern/;
                    my $pattern         = 'countryname="(\w+)"';
                    my ($f_countryname) = $weatherbug_location =~ /$pattern/;
                    my $pattern         = 'zipcode="(\w+)"';
                    my ($f_zipcode)     = $weatherbug_location =~ /$pattern/;
                    my $pattern         = 'citycode="(\d+)"';
                    my ($f_citycode)    = $weatherbug_location =~ /$pattern/;
                    print_log
                      "Citycode=$f_citycode for $f_cityname,$f_statename,$f_countryname."
                      if ( $f_citycode != 0 );
                    print_log
                      "Zipcode=$f_zipcode for $f_cityname,$f_statename,$f_countryname."
                      if ( $f_zipcode != 0 );
                }
                print_log "Weatherbug location search result.";
            }
            else {    # the test for locations failed
                print_log "weatherbug: Error Did not find locations.";
            }

        }    # end of the process locations file section

        # ------------ Get Forecast -----------------
        use XML::Twig;
        if ( done_now $p_weather_weatherbug_forecast) {
            my $twig = new XML::Twig;
            $twig->parsefile($weatherbug_file);
            my $root    = $twig->root;
            my $channel = $root->first_child("channel");

            # Do a test to see if the data returned is likely valid.
            # There should be a title for forecast in the text for the
            # city if the fetch was successful
            $Weather{weatherbug_fcst_valid} = 0; #Set to not valid unless proven
            my $search_for = "Forecast for $weatherbug_city";
            my $title      = $channel->first_child_text("title");
            logit(
                "$config_parms{data_dir}/web/weatherbug_debug",
                "Search for: " . $search_for,
                13, 0
            ) if ( $Debug{weatherbug} );
            logit(
                "$config_parms{data_dir}/web/weatherbug_debug",
                "WeatherBug returned: $title",
                13, 0
            ) if ( $Debug{weatherbug} );
            if ( $title =~ /$search_for/i ) {
                $Weather{weatherbug_fcst_valid} = 1;
            }
            else {
                # the test for forecast failed
                # Since there is not an forecast title assume failure
                $Weather{weatherbug_valid} = 0;
                print_log
                  "weatherbug: Error Did not find forecast for $weatherbug_city.";
                print_log
                  "weatherbug: Check the $weatherbug_file file for which city was found and modify the config parameters.";
                goto fail;
            }

            # Valid forecast so record the forecast date and time to live
            my $f_date       = $channel->first_child_text("lastBuildDate");
            my $f_timetolive = $channel->first_child_text("ttl");
            logit(
                "$config_parms{data_dir}/web/weatherbug_debug",
                $f_date . ' for ' . $f_timetolive . ' minutes',
                13, 0
            ) if ( $Debug{weatherbug} );

            my $fcast_counter = 0;

            # This splits the detailed forecasts into the forecast elements
            foreach my $forecast ( $root->descendants("aws:forecast") ) {

                # a valid forecast has a title element to start with
                next unless my $title = $forecast->first_child("aws:title");
                next unless my $f_day = $title->att("alttitle");

                # If we got here we have a valid forecast to process
                logit( "$config_parms{data_dir}/web/weatherbug_debug",
                    $forecast->print, 13, 0 )
                  if ( $Debug{weatherbug} );
                $f_day = ucfirst( lc($f_day) );

                # Use the day to determine if the first forecast is for today or
                # tomorrow - until evening the first is for today
                if ( $fcast_counter == 0 ) {

                    # only does it on the first forecast
                    # increment the counter to 1 if the day is not today
                    $fcast_counter++ if ( $Day ne $f_day );
                }

                # Determine the condition summary number
                my $image   = $forecast->first_child("aws:image");
                my $f_cond  = $image->att("icon");
                my $pattern = 'cond(\d+).gif';
                ($f_cond) = $f_cond =~ /$pattern/;

                # use the condition number to look up the conditions
                my $f_conditions;
                my $f_precip_type;
                my $f_precip_ammount;
                if ( $f_cond <= $wxbug_maximum_code ) {

                    # first the official wxbug condition
                    ($f_conditions) = $wxbug_conditions[$f_cond];

                    # then the extensions developed for mh tests
                    ($f_precip_type)    = $wxbug_precip_type[$f_cond];
                    ($f_precip_ammount) = $wxbug_precip_ammount[$f_cond];
                }
                else {
                    # We are here because the code is > known table
                    ($f_conditions) = "Unknown";

                    # then the extensions developed for mh tests
                    ($f_precip_type)    = "Unknown";
                    ($f_precip_ammount) = "Unknown";
                    if ( $f_cond != 999 ) {

                        # if it is not the unknown code then the
                        # table needs to be updated
                        print_log "weatherbug: Error check for API update.";
                    }
                }

                my $f_prediction =
                  $forecast->first_child_text("aws:prediction");

                # Get the chance of rain or snow
                my $pattern = 'There is a (\d+)% chance of precipitation';
                my ($f_chance) = $f_prediction =~ /$pattern/;

                # Get the humidity
                my $pattern = 'Humidity will be (\d+)% with a dewpoint of ';
                my ($f_humidity) = $f_prediction =~ /$pattern/;

                # Get the dew point
                my $pattern = 'with a dewpoint of\s+(-?\d+)';
                my ($f_dewpoint) = $f_prediction =~ /$pattern/;

                # Get the comfort level
                my $pattern = 'and feels-like temperature of\s+(-?\d+)';
                my ($f_comfort) = $f_prediction =~ /$pattern/;

                # looking for Winds WSW 26km.
                my $f_windspeed;
                my $f_winddir;

                # but the pattern last year was Winds 26km WSW!
                # So need to test for the pattern
                my $search_for = 'Winds [SENW]+';
                if ( $f_prediction =~ /$search_for/ ) {
                    my $pattern = 'Winds [SENW]+ (\d+)[kmph]+';
                    ($f_windspeed) = $f_prediction =~ /$pattern/;
                    my $pattern = 'Winds ([SENW]+) \d+[kmph]+';
                    ($f_winddir) = $f_prediction =~ /$pattern/;
                }
                else {
                    my $pattern = 'Winds (\d+)[kmph]+';
                    ($f_windspeed) = $f_prediction =~ /$pattern/;
                    my $pattern = 'Winds \d+[kmph]+ ([NSEW]+)\.';
                    ($f_winddir) = $f_prediction =~ /$pattern/;
                }

                # looking for high
                my $f_high = $forecast->first_child_text("aws:high");

                # looking for low
                my $f_low = $forecast->first_child_text("aws:low");

                # prepare a debug statement
                if ( $Debug{weatherbug} ) {
                    my $temp =
                        'Forecast#='
                      . $fcast_counter . ' day='
                      . $f_day
                      . ' cond='
                      . $f_cond
                      . ' chance='
                      . $f_chance
                      . ' humidity='
                      . $f_humidity
                      . ' dewpoint='
                      . $f_dewpoint
                      . ' comfort='
                      . $f_comfort
                      . ' windspeed='
                      . $f_windspeed
                      . ' winddir='
                      . $f_winddir
                      . ' high='
                      . $f_high . ' low='
                      . $f_low
                      . ' conditions='
                      . $f_conditions
                      . ' precip_type='
                      . $f_precip_type
                      . ' precip_ammount='
                      . $f_precip_ammount
                      . ' Published='
                      . $f_date
                      . ' valid for '
                      . $f_timetolive
                      . ' minutes.';
                    logit( "$config_parms{data_dir}/web/weatherbug_debug",
                        $temp, 13, 0 );
                }

                # load the forecast into the hash
                my $findex    = $fcast_counter;
                my $hashindex = "weatherbug_frcst_" . $findex . "_pubdate";
                $Weather{$hashindex} = $f_date;
                my $hashindex = "weatherbug_frcst_" . $findex . "_ttl";
                $Weather{$hashindex} = $f_timetolive;
                my $hashindex = "weatherbug_frcst_" . $findex . "_Forecast#";
                $Weather{$hashindex} = $fcast_counter;
                my $hashindex = "weatherbug_frcst_" . $findex . "_day";
                $Weather{$hashindex} = $f_day;
                my $hashindex = "weatherbug_frcst_" . $findex . "_cond";
                $Weather{$hashindex} = $f_cond;
                my $hashindex = "weatherbug_frcst_" . $findex . "_chance";
                $Weather{$hashindex} = $f_chance;
                my $hashindex = "weatherbug_frcst_" . $findex . "_humidity";
                $Weather{$hashindex} = $f_humidity;
                my $hashindex = "weatherbug_frcst_" . $findex . "_dewpoint";
                $Weather{$hashindex} = $f_dewpoint;
                my $hashindex = "weatherbug_frcst_" . $findex . "_comfort";
                $Weather{$hashindex} = $f_comfort;
                my $hashindex = "weatherbug_frcst_" . $findex . "_windspeed";
                $Weather{$hashindex} = $f_windspeed;
                my $hashindex = "weatherbug_frcst_" . $findex . "_winddir";
                $Weather{$hashindex} = $f_winddir;
                my $hashindex = "weatherbug_frcst_" . $findex . "_high";
                $Weather{$hashindex} = $f_high;
                my $hashindex = "weatherbug_frcst_" . $findex . "_low";
                $Weather{$hashindex} = $f_low;
                my $hashindex = "weatherbug_frcst_" . $findex . "_conditions";
                $Weather{$hashindex} = $f_conditions;
                my $hashindex = "weatherbug_frcst_" . $findex . "_precip_type";
                $Weather{$hashindex} = $f_precip_type;
                my $hashindex =
                  "weatherbug_frcst_" . $findex . "_precip_ammount";
                $Weather{$hashindex} = $f_precip_ammount;

                # increment the forecast counter for the next forecast day
                $fcast_counter++;
            }

            # --- end of foreach forecast item
            fail:
        }

        # --------------- end of the file processing section ----------------
