# Category=Weather
#
#
#@ This code will retrieve and parse data from the XML feeds provided
#@ by the Natiional Weather service. (MH5 Updated)
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

 Version 2        September 19, 2017
 Version 0.1      December 8, 2006
 Initial version

=cut

# use module
use XML::Simple;
use LWP::Simple;
use Weather_Common;

my $NWSdata;
my $station = $config_parms{weather_noaa_station};
my $internet_weather_noaa_file = $config_parms{data_dir} . '/web/weather_noaa.html';

$station = 'KARR' unless $station;

# create object
$xml = new XML::Simple;

$v_get_xml_weather = new Voice_Cmd('Get XML weather data');
$p_internet_weather_noaa_fetch = new Process_Item(qq{get_url -quiet "http://www.weather.gov/data/current_obs/$station.xml" "$internet_weather_noaa_file"});

# Create trigger
if ($Reload) {
    &trigger_set( "time_cron '15 * * * *'", "run_voice_cmd('Get XML weather data')", 'NoExpire', 'get xml weather' ) unless &trigger_get('get xml weather');
    $Weather_Common::weather_module_enabled = 1;

}

if ( said $v_get_xml_weather) {
    start $p_internet_weather_noaa_fetch;
    $v_get_xml_weather->respond("app=weather Retrieving XML weather...");
}

if ( done_now $p_internet_weather_noaa_fetch or $Reload ) {
    &process_noaa;
}

sub process_noaa {
        my $data = file_read $internet_weather_noaa_file;
        return unless ($data);
        # read XML file
        $NWSdata = $xml->XMLin( $data );

print Dumper $NWSdata;

        # hash used to temporarily store weather info before selective load into %Weather
        my %w = ();

        $w{TempOutdoor}          = NA_to_zero( $NWSdata->{temp_f} );
        $w{HumidOutdoor}         = NA_to_zero( $NWSdata->{relative_humidity} );
        $w{HumidOutdoorMeasured} = 1;                                                      # tell Weather_Common that we directly measured humidity
        $w{WindAvgDir}           = convert_wind_dir_text_to_num( $NWSdata->{wind_dir} );
        $w{WindAvgSpeed}         = NA_to_zero( $NWSdata->{wind_mph} );

        $w{WindGustSpeed} = NA_to_zero( $NWSdata->{wind_gust_mph} );
        $w{Barom}         = NA_to_zero( $NWSdata->{pressure_in} );
        $w{WindChill}     = NA_to_zero( $NWSdata->{windchill_f} );
        $w{DewOutdoor}    = NA_to_zero( $NWSdata->{dewpoint_f} );
        $w{Summary_Short} = $NWSdata->{weather};

        ($w{LastUpdated}) = $NWSdata->{observation_time} =~ /Last Updated on (.*)$/;

        $w{IsRaining}     = 0;
        $w{IsRaining}     = 1 if ($NWSdata->{weather} =~ m/rain/i);
        
        $w{IsSnowing}     = 0;
        $w{IsSnowing}     = 1 if ($NWSdata->{weather} =~ m/snow/i);

        $w{Clouds}        = $NWSdata->{weather};
        $w{Clouds}        = "" if ($NWSdata->{weather} =~ m/fair/i);    
        

        &populate_internet_weather( \%w );
        &weather_updated;

        if ( $Debug{weather} ) {
            foreach my $key ( sort( keys(%w) ) ) {
                &print_log( "weather_xml: $key is " . $w{$key} );
            }
        }

        &print_log( "weather_xml: finished retrieving weather for station " . $station );
        $v_get_xml_weather->respond( 'app=weather connected=0 Weather data for ' . $NWSdata->{location} . ' retrieved.' );

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
