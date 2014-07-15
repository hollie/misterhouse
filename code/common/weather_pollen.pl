#Category=Weather

#@ This module gets the pollen forecast from Claritin.com and puts the predominant pollen
#@ type and pollen count into the %Weather hash.
#@
#@ Uses mh.ini parameter zip_code

# Get pollen count forecast from Claritin.com and put it and the predominant pollen
# type into the %Weather hash.
# Technically there is a 4 day forecast, but I have seen it vary so widely
# from day 2 and what day 1 will say tomorrow that I don't count on it for
# more than the current day.
#
#uses mh.ini parameter zip_code=
#
#info from:
#http://www.claritin.com/weatherpollenservice/weatherpollenservice.svc/getforecast/64119
#

# weather_pollen.pl
# Original Author:  Kent Noonan
# Revision:  1.3
# Date:  07/14/2014

=begin comment

 1.0 Initial Release
     Kent Noonan - ca. 12/16/2001
 1.1 Revisions
     David J. Mark - 06/12/2006
 1.2 Updated to use new Trigger design.
     Bruce Winter - 06/25/2006
 1.3 Updated to use the JSON WeatherPollenService from Claratin.com
     since Pollen.com has added countermeasures to prevent screenscraping
     that would take much more code to parse.  The WeatherPollenService
     has a better API that seems to provide the same data as most other
     online pollen forecasting services.  In addition to switching service
     providers, I've also done some general cleanup & improvements.
     Jared J. Fernandez - 07/14/2014

=cut

use JSON qw( decode_json );

my $pollen_file = "$config_parms{data_dir}/web/pollen_forecast.json";

$v_get_pollen_forecast = new Voice_Cmd('[Get,Check] pollen forecast');
$v_get_pollen_forecast->set_info("Downloads and parses the pollen forecast data.  The 'check' option reads out the result after parsing is complete.");

$v_read_pollen_forecast = new Voice_Cmd('Read pollen forecast');
$v_read_pollen_forecast->set_info("Reads out the previously fetched pollen forecast.");

$p_pollen_forecast = new Process_Item("get_url http://www.claritin.com/weatherpollenservice/weatherpollenservice.svc/getforecast/$config_parms{zip_code} $pollen_file");

&parse_pollen_forecast if (($Reload) && (-e $pollen_file));

sub parse_pollen_forecast {
	my @pollen_data = file_read($pollen_file) || warn "Unable to open pollen data file.";
	# The JSON file that is retuned by the service is malformed; these substitutions clean it up so that the perl JSON module can parse it.
	for (@pollen_data) {
		s/\"\{/\{/;
		s/\\//g;
		s/\}\"/\}/;
	}
	my $json = decode_json(@pollen_data) || warn "Error parsing pollen info from file.";
	$main::Weather{TodayPollenCount} = $json->{pollenForecast}{forecast}[0];
	$main::Weather{TomorrowPollenCount} = $json->{pollenForecast}{forecast}[1];
	$main::Weather{TodayPollenType} = $json->{pollenForecast}{pp};
	$main::Weather{TodayPollenType} =~ s/\.//;
}

if ($state = said $v_get_pollen_forecast) {
	$v_get_pollen_forecast->respond("app=pollen Retrieving pollen forecast...");
	start $p_pollen_forecast;
}

if (done_now $p_pollen_forecast){
	&parse_pollen_forecast();
	if ($v_get_pollen_forecast->{state} eq 'Check') {
		$v_get_pollen_forecast->respond("app=pollen Today's pollen count is $main::Weather{TodayPollenCount}. The predominant pollens are from " . lc($main::Weather{TodayPollenType} . "."));
	}
	else {
		$v_get_pollen_forecast->respond("app=pollen Pollen forecast retrieved.");
	}
}

if (said $v_read_pollen_forecast) {
	if ($Weather{TodayPollenCount}) {
		$v_read_pollen_forecast->respond("app=pollen Today's pollen count is $main::Weather{TodayPollenCount}. The predominant pollens are from " . lc($main::Weather{TodayPollenType}) . ".");
	}
	else {
		$v_read_pollen_forecast->respond("app=pollen I do not know the pollen count at the moment.");
	}
}

# create trigger to download pollen forecast

if ($Reload) {
    if ($Run_Members{'internet_dialup'}) {
        &trigger_set("state_now \$net_connect eq 'connected'", "run_voice_cmd 'Get pollen forecast'", 'NoExpire', 'get pollen forecast')
          unless &trigger_get('get pollen forecast');
    }
    else {
        &trigger_set("time_cron '0 5 * * *' and net_connect_check", "run_voice_cmd 'Get Pollen forecast'", 'NoExpire', 'get pollen forecast')
          unless &trigger_get('get pollen forecast');
    }
}
