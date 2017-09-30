# Category = Weather
#@ Updates live weather variables from http://api.wunderground.com. (Updated MH5)

=begin
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	weather_wunderground.pl

Description:
	Updates live weather variables from http://api.wunderground.com.

Author:
	Steve Switzer (Pmatis)
	steve@switzerny.org

License:
	This free software is licensed under the terms of the GNU public license.

Requires:
	Weather_Common.pl
	XML::Twig

Special Thanks to:
	Bruce Winter - MH
	Everyone else - GPL examples to learn from
	J. Serack & David Norwood - Weatherbug code template

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

# noloop=start
use Weather_Common;
use Data::Dumper;
use XML::Twig;
my $wunderground_getweather_file;
my $wunderground_stationid = $config_parms{wunderground_stationid};
my $wunderground_apikey    = $config_parms{wunderground_apikey};
my $wunderground_units     = "f";
$wunderground_units        = $config_parms{wunderground_units} if (defined $config_parms{wunderground_units});
my $wunderground_units2    = "mph";
$wunderground_units2       = "kph" if ((defined $config_parms{wunderground_units}) and (lc $config_parms{wunderground_units} eq "c"));

my $wunderground_url;
my %wunderground_data;
my @wunderground_keys;
$p_weather_wunderground_getweather = new Process_Item();

my $wunderground_states = 'getweather,parsefile,debug';
$v_wunderground = new Voice_Cmd("wunderground [$wunderground_states]");
$Weather_Common::weather_module_enabled = 1;

# noloop=stop

if ($Reload) {
    $wunderground_stationid       = $config_parms{wunderground_stationid};
    $wunderground_apikey          = $config_parms{wunderground_apikey};
    $wunderground_stationid       = '' unless $wunderground_stationid;
    $wunderground_getweather_file = $config_parms{data_dir} . '/web/weather_wunderground_getweather.xml';

    if ( $config_parms{wunderground_apikey} eq '' ) {
        print_log("[WUnderground] ERROR: wunderground_apikey is not defined in mh.private.ini.");
    }
    else {
        if ( $wunderground_stationid ne '' ) {
            print_log "[WUnderground] Using Weather underground StationID: $wunderground_stationid" if $Debug{weather};
            $wunderground_url = 'http://api.wunderground.com/api/' . $wunderground_apikey . '/conditions/q/pws:' . $wunderground_stationid . '.xml';
        }
        elsif ( $config_parms{zip_code} ne '' ) {
            print_log "[WUnderground] Using ZIP Code: " . $config_parms{zip_code} if $Debug{weather};
            $wunderground_url = 'http://api.wunderground.com/api/' . $wunderground_apikey . '/conditions/q/' . $config_parms{zip_code} . '.xml';
        }
        else {
            print_log
              "[WUnderground] WARNING: wunderground_stationid and zip_core are both blank in mh.private.ini. Leaving it to Weather underground to guess your location by IP address..."
              if $Debug{weather};
            $wunderground_url = 'http://api.wunderground.com/api/' . $wunderground_apikey . '/conditions/q/autoip.xml';
        }

        print_log "[WUnderground] Using URL: '" . $wunderground_url if $Debug{weather};

        &trigger_set(
            qq|time_cron('*/15 * * * *') or \$Reload|,
            "run_voice_cmd 'wunderground getweather'",
            'NoExpire',
            'Update current weather conditions via wunderground'
        ) unless &trigger_get('Update current weather conditions via wunderground');
    }
}

my $wunderground_state = 'blank';
if ( $wunderground_state = $v_wunderground->{said} ) {
    if ( $wunderground_state eq 'getweather' ) {
        print_log "[WUnderground] Getting data from $wunderground_url" if $Debug{weather};
        set $p_weather_wunderground_getweather qq{get_url -quiet "$wunderground_url" "$wunderground_getweather_file"};
        start $p_weather_wunderground_getweather;
    }
}

if ( done_now $p_weather_wunderground_getweather or 'parsefile' eq said $v_wunderground) {
    $Weather{wunderground_obsv_valid} = 0;    #Set to not valid unless proven
                                              #my $wunderground_xml=file_read $wunderground_getweather_file;
    print_log "[WUnderground] getweather finished, data written to $wunderground_getweather_file" if $Debug{weather};
    my $twig = new XML::Twig();
    $twig->parsefile($wunderground_getweather_file);
    $twig->print if $Debug{weather} >= 5;
    my $root    = $twig->root;
    my $channel = $root->first_child("current_observation");

    print_log "[WUnderground] " . Dumper $channel if $Debug{weather} >= 5;

    my $w_stationid = $root->first_child_text("station_id");

    print_log "[WUnderground] Received stationid: $w_stationid" if $Debug{weather};

    $config_parms{wunderground_stationid} = $w_stationid;

    if ( $config_parms{wunderground_stationid} eq $w_stationid ) {
        %wunderground_data = {};
        @wunderground_keys = [];

        #TempOutdoor
        weather_wunderground_addelem( $channel, 'TempOutdoor', 'temp_' . $wunderground_units );

        #DewOutdoor
        weather_wunderground_addelem( $channel, 'DewOutdoor', 'dewpoint_' . $wunderground_units );

        #WindAvgDir
        weather_wunderground_addelem( $channel, 'WindAvgDir', 'wind_dir' );

        #WindAvgSpeed
        weather_wunderground_addelem( $channel, 'WindAvgSpeed', 'wind_' . $wunderground_units2 );

        #WindGustDir
        #WindGustSpeed
        weather_wunderground_addelem( $channel, 'WindGustSpeed', 'wind_gust' . $wunderground_units2 );

        #WindGustTime
        #Conditions
        weather_wunderground_addelem( $channel, 'Conditions', 'weather' );
        #Clouds
        weather_wunderground_addelem( $channel, 'Clouds', 'weather' );

        #Barom
        weather_wunderground_addelem( $channel, 'Barom', 'pressure_mb' );

        #BaromSea
        #BaromDelta
        #HumidOutdoorMeasured
        #HumidOutdoor
        weather_wunderground_addelem( $channel, 'HumidOutdoor', 'relative_humidity' );

        #IsRaining
        $wunderground_data{IsRaining} = 0;
        $wunderground_data{IsRaining} = 1 if ($wunderground_data{Conditions} =~ m/rain/i);

        #IsSnowing
        $wunderground_data{IsSnowing} = 0;
        $wunderground_data{IsSnowing} = 1 if ($wunderground_data{Conditions} =~ m/snow/i);
        
        weather_wunderground_addelem( $channel, 'Clouds', 'weather' );

        #RainTotal
        weather_wunderground_addelem( $channel, 'RainTotal', 'precip_today_in' );

        #RainRate
        weather_wunderground_addelem( $channel, 'LastUpdated', 'observation_time' );
        $wunderground_data{LastUpdated} =~ s/^Last Updated on //;

        print_log "[WUnderground] " . Dumper %wunderground_data if $Debug{weather} >= 5;
        print_log "[WUnderground] Using elements: $config_parms{weather_wunderground_elements}" if $Debug{weather};
        &Weather_Common::populate_internet_weather( \%wunderground_data, $config_parms{weather_wunderground_elements} );
        &Weather_Common::weather_updated;

    }
    else {
        print_log "[WUnderground] ERROR! Received a station ID we didn't want. Aborting.";
    }

}

sub weather_wunderground_addelem {
    my ( $w_twigroot, $w_dest, $w_src ) = @_;
    print_log "[WUnderground] Looking for $w_src" if $Debug{weather};

    if ( my $w_srcval = $w_twigroot->first_child_text("$w_src") ) {
        $w_srcval =~ s/%$//;
        print_log sprintf( "WUnderground: Data: %15s = %8s (%s)", $w_dest, $w_srcval, $w_src ) if $Debug{weather};
        $wunderground_data{$w_dest} = $w_srcval;
        push( @wunderground_keys, $w_dest );
    }
}
