# Category = Weather

# Gets weather data from weather.com, using the CPAN Geo::Weather.pm
# module. Unlike the web site used in mh/bin/get_weather,
# weather.com also has data on non-US cities.
# Set mh.ini city and state parms.  For non-US cities, set state to the
# country (e.g. city=London, state=United Kingdon
# Unlike get_weather, this data is not retreived with a background
# process, so mh will pause while retrieving data.

use Geo::Weather;

# noloop=start
$weather_com   = new Geo::Weather;
$v_weather_com = new Voice_Cmd '[Get,Display,Speak] internet weather.com data';
$v_weather_com->set_info(
    "Gets data from weather.com, for mh.ini city parm $config_parms{city}, $config_parms{state}"
);

my %weatherComMap = (
    cond => 'Conditions',
    temp => 'TempOutdoor',
    wind => 'WindAvgSpeed',
    dewp => 'DewOutdoor',
    humi => 'HumidOutdoor',
    baro => 'BaromSea'
);

# noloop=stop
# Periodically get data, if online
run_voice_cmd 'Get internet weather.com data'
  if time_cron '1 7,13,19 * * * ' and &net_connect_check;

if ( $state = said $v_weather_com) {
    $v_weather_com->respond('Retrieving weather from weather.com');
    if ( $state eq 'Get' ) {
        print_log
          "Getting weather data for $config_parms{city}, $config_parms{state}";
        my $data =
          $weather_com->get_weather( $config_parms{city},
            $config_parms{state} );
        if ( ref($data) eq 'HASH' ) {
            my %w = ();
            for my $key ( sort keys %{$data} ) {
                &print_log("weather_com: found $key = ---$$data{$key}---")
                  if $Debug{Weather};
                if ( defined( $weatherComMap{$key} ) and $$data{$key} ne '' ) {
                    $w{ $weatherComMap{$key} } = $$data{$key};
                }
            }
            if ( defined( $w{TempOutdoor} ) ) {
                if ( $config_parms{weather_uom_temp} eq 'C' ) {
                    $w{TempOutdoor} = convert_f2c( $w{TempOutdoor} );
                }
            }
            if ( defined( $w{DewOutdoor} ) ) {
                if ( $config_parms{weather_uom_temp} eq 'C' ) {
                    $w{DewOutdoor} = convert_f2c( $w{DewOutdoor} );
                }
            }
            if ( defined( $w{BaromSea} ) ) {
                if ( $config_parms{weather_uom_baro} eq 'mb' ) {
                    $w{BaromSea} = convert_in2mb( $w{BaromSea} );
                }
                $w{Barom} = convert_sea_barom_to_local( $w{BaromSea} );
            }
            if ( defined( $w{WindAvgSpeed} ) ) {
                if ( $config_parms{weather_uom_wind} eq 'kph' ) {
                    $w{WindAvgSpeed} = convert_mile2km( $w{WindAvgSpeed} );
                }
                if ( $config_parms{weather_uom_wind} eq 'mps' ) {
                    $w{WindAvgSpeed} = convert_mph2mps( $w{WindAvgSpeed} );
                }
                $w{WindGustSpeed} = $w{WindAvgSpeed};
            }
            if ( defined( $w{HumidOutdoor} ) ) {
                $w{HumidOutdoorMeasured} = 1;
            }
            else {
                $w{HumidOutdoorMeasured} = 0;
            }
            if ( $Debug{weather} ) {
                foreach my $key ( sort( keys(%w) ) ) {
                    &print_log( "weather_com: $key is " . $w{$key} );
                }
            }
            &populate_internet_weather( \%w );
            &weather_updated;

            if ( defined( $$data{url} ) and $$data{url} ne '' ) {
                print_log("weather_com: Getting weather page");
                run "get_url $$data{url} $config_parms{data_dir}/weather.html";
            }
            else {
                print_log(
                    "weather_com: couldn't retrieve weather page as url is missing or invaid"
                );
            }
        }
        else {
            my $errorReason = 'unknown reason';
            if ( $data == $Geo::Weather::ERROR_QUERY ) {
                $errorReason = 'Invalid data supplied';
            }
            if ( $data == $Geo::Weather::ERROR_PAGE_INVALID ) {
                $errorReason =
                  'No URL, or incorrectly formatted UTL for retrieving the information';
            }
            if ( $data == $Geo::Weather::ERROR_CONNECT ) {
                $errorReason = 'Error connecting to weather.com';
            }
            if ( $data == $Geo::Weather::ERROR_NOT_FOUND ) {
                $errorReason =
                    'Weather for '
                  . $config_parms{city} . ', '
                  . $config_parms{state}
                  . ' could not be found';
            }
            if ( $data == $Geo::Weather::ERROR_TIMEOUT ) {
                $errorReason =
                  'Timed out while trying to connect to or get date from weather.com';
            }
            &print_log(
                "weather_com: problem retrieving forecast: $errorReason");
        }
    }
    elsif ( $state eq 'Display' ) {
        browser "$config_parms{data_dir}/weather.html";
        my $msg =
          "Weather for $config_parms{city}\n  Conditions: $Weather{Conditions}\n";
        $msg .=
          "  Dewpoint: $Weather{DewOutdoor}\n  Humidity: $Weather{HumidOutdoor}\n";
        $msg .=
          "  Temperature: $Weather{TempOutdoor}\n  Wind: $Weather{WindAvgSpeed}\n";
        display $msg;
    }
    else {
        speak
          "It is $Weather{TempOutdoor} degrees, $Weather{HumidOutdoor} outside. Wind is $Weather{WindAvgSpeed}";
    }
}
