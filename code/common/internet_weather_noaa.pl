# Category=Weather
#
#
#@ This code will retrieve and parse data from the XML feeds provided
#@ by the Natiional Weather service.
#@
#@ Check <a href="http://www.weather.gov/data/current_obs/">http://www.weather.gov/data/current_obs/</a>
#@ for the nearest station's ID.  Add the ID to the "weather_noaa_station"
#@ configuration option in mh.ini<br><br>
#@
#@

=begin comment
 internet_weather_noaa.pl
 Created by John Wohlers (john@wohlershome.net)

 This code retrieves and parses XML weather data from the national
 weather service website.

 Revision History


 Version 0.1      December 8, 2006
 Initial version

=cut

# use module
use XML::Simple;
use LWP::Simple;
use Weather_Common;

my $NWSdata;
my $station = $config_parms{weather_noaa_station};
$station = 'KARR' unless $station;

# create object
$xml = new XML::Simple;

$v_get_xml_weather = new Voice_Cmd('Get XML weather data');

# Create trigger
if ($Reload) {
    &trigger_set(
        "time_cron '15 * * * *'",
        "run_voice_cmd('Get XML weather data')",
        'NoExpire',
        'get xml weather'
    ) unless &trigger_get('get xml weather');
}

if ( said $v_get_xml_weather) {
    if (&net_connect_check) {
        $v_get_xml_weather->respond("app=weather Retrieving XML weather...");
        #
        # read XML file
        $NWSdata = $xml->XMLin(
            get(
                "http://www.weather.gov/data/current_obs/" . $station . ".xml"
            )
        );

        # hash used to temporarily store weather info before selective load into %Weather
        my %w = ();

        $w{TempOutdoor}  = NA_to_zero( $NWSdata->{temp_f} );
        $w{HumidOutdoor} = NA_to_zero( $NWSdata->{relative_humidity} );
        $w{HumidOutdoorMeasured} =
          1;    # tell Weather_Common that we directly measured humidity
        $w{WindAvgDir}   = convert_wind_dir_text_to_num( $NWSdata->{wind_dir} );
        $w{WindAvgSpeed} = NA_to_zero( $NWSdata->{wind_mph} );

        $w{WindGustSpeed} = NA_to_zero( $NWSdata->{wind_gust_mph} );
        $w{Barom}         = NA_to_zero( $NWSdata->{pressure_in} );
        $w{WindChill}     = NA_to_zero( $NWSdata->{windchill_f} );
        $w{DewOutdoor}    = NA_to_zero( $NWSdata->{dewpoint_f} );
        $w{Summary_Short} = $NWSdata->{weather};

        &populate_internet_weather( \%w );
        &weather_updated;

        if ( $Debug{weather} ) {
            foreach my $key ( sort( keys(%w) ) ) {
                &print_log( "weather_xml: $key is " . $w{$key} );
            }
        }

        &print_log( "weather_xml: finished retrieving weather for station "
              . $station );
        $v_get_xml_weather->respond( 'app=weather connected=0 Weather data for '
              . $NWSdata->{location}
              . ' retrieved.' );

    }
    else {
        $v_get_xml_weather->respond(
            "I must be connected to the Internet to get weather data.");
    }
}

sub NA_to_zero {
    my $check = shift;
    if ( $check ne "NA" ) {
        return ($check);
    }
    else {
        return (0);
    }

}
