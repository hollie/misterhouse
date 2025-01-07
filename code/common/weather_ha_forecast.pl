# Category = Weather

# $Date$
# $Revision$

#@ Retrieves the daily forecast every hour to populate the Weather_forecast items
#@ Requires two mh.ini parameters
#@ weather_HA_forecast_entity= name of home assistant weather entity
#@ weather_HA_server_object= name of the HA_Server Item to call the action against

use Weather_Common;
use Data::Dumper;
use POSIX qw(strftime);
use Time::Local;

#noloop=start
$v_get_HA_forecast = new Voice_Cmd('[Get,Print] Home Assistant Forecast data');
my $ha_latest_forecast = "";
#noloop=stop


if (my $action = said $v_get_HA_forecast) {
	print_log "Running $action Home Assistant forecast data";
	
	unless ($config_parms{weather_HA_forecast_entity}) {
		print_log "[weather_ha_forecast]: Error: weather_HA_forecast_entity is not set";
		return;
	}
	if (lc $action eq "get") {
		my $object = get_object_by_name($config_parms{weather_HA_server_object});
		if ($object) {
			my $ha_object = "weather." . $config_parms{weather_HA_forecast_entity} . ".get_forecasts";
			$object->ha_perform_action( $ha_object, {'type'=>'daily'}, \&weather_ha_forecast_response_callback, \$ha_latest_forecast );
		} else {
		print_log "[weather_ha_forecast]: Error: Error weather_HA_server_object not found";
		}
	} elsif (lc $action eq "print") {
		print_log "[weather_ha_forecast]: $ha_latest_forecast";
	} else {
		print_log "[weather_ha_forecast]: unknown voice command action: $action";	
	}
}
sub weather_ha_forecast_response_callback {
    my ($success, $response, $parm ) = @_;
    unless ($success) {
    	&print_log( "[weather_ha_forecast]: Error. Callback did not return success, error response=" . $response );
    	return 0;
   }
    
    my $entity = (keys (%{$response}))[0];
    #&print_log( "got response on weather request $entity $parm: keys:" . scalar (keys (%{$response})) . "\n" .  Dumper $response );
    if (scalar (keys (%{$response})) > 1) {
    	&print_log( "[weather_ha_forecast]: Warning, received more than a single entity on weather forecast response" );
    }
    my $forecast_found = 0;
    my $current_date = strftime "%Y/%m/%d", localtime($Time);

	#Forecasts are an array 
    for my $forecast_day (@{$response->{$entity}->{forecast}}) {
    	my ($year, $mon, $day, $hour, $min, $sec) = ((split /\D/,$forecast_day->{datetime})[0..5]);
        my $time = timegm($sec, $min, $hour, $day, ($mon-1), $year);
        my $forecast_date = strftime "%Y/%m/%d", localtime($time);
        if ($current_date eq $forecast_date) {
        	$main::Weather{ForecastHigh} = $forecast_day->{temperature};
        	$main::Weather{ForecastLow} = $forecast_day->{templow};
        	$main::Weather{ForecastConditions} = $forecast_day->{condition};
        	${$parm} = "Forecast for $forecast_date: Low:" . $forecast_day->{templow} . " High:" . $forecast_day->{temperature} . " Conditions: " .$forecast_day->{condition};

        	print_log "[weather_ha_forecast]: " .${$parm};
    		#call update weather
    		&Weather_Common::weather_updated;
    		$forecast_found = 1;
    		last;
        }
    }
    unless ($forecast_found) {
    	&print_log( "[weather_ha_forecast]: Warning, could not locate a forecast for $current_date" );
    	return 0;
	} 
	return 1;
}

if ($New_Hour) {
	print_log("Updating Daily Weather forecast from Home Assistant");
	run_voice_cmd("Get Home Assistant Forecast data");
}
