#Category=Weather

#@ This module gets the pollen forecast from www.pollen.com and puts the pollen
#@ type and pollen count into the %Weather hash.
#@
#@ Uses mh.ini parameter zip_code

# get pollen count forecast from www.pollen.com and put it and the pollen
# type into the %Weather hash.
# Technically there is a 4 day forecast, but I have seen it vary so widely
# from day 2 and what day 1 will say tomorrow that I don't count on it for
# more than the current day.
#
#uses mh.ini parameter zip_code=
#
#info from:
#http://www.pollen.com/forecast.asp?PostalCode=64119


$v_get_pollen_forecast = new Voice_Cmd('[Get,Check] pollen forecast');
# *** set info

$v_read_pollen_forecast = new Voice_Cmd('Read pollen forecast');

$p_pollen_forecast = new Process_Item("get_url http://www.pollen.com/forecast.asp?postalcode=$config_parms{zip_code} $config_parms{data_dir}/web/pollen_forecast.html");

&parse_pollen_forecast if $Reload;

sub parse_pollen_forecast {

	my $count1;
	open(FILE,"$config_parms{data_dir}/web/pollen_forecast.html");
	while (<FILE>) {
		if (/Predominant pollen:\s+(.+)\.<\/A>/i) {
			$main::Weather{TodayPollenType}=$1;
		} elsif ((/fimages\/std\/(\d+\.\d).gif/i) and (!defined($count1))) {
			$count1="r";
			$main::Weather{TodayPollenCount}=$1;
		}

	}
	close(FILE);

}


if ($state = said $v_get_pollen_forecast) {
	$v_get_pollen_forecast->respond("app=pollen Retrieving pollen forecast...");
	start $p_pollen_forecast;
}

if (done_now $p_pollen_forecast){
	&parse_pollen_forecast();
	if ($v_get_pollen_forecast->{state} eq 'Check') {
		$v_get_pollen_forecast->respond("app=pollen Today's pollen count is $main::Weather{TodayPollenCount}. The predominant pollens are " . lc($main::Weather{TodayPollenType}));
	}
	else {
		$v_get_pollen_forecast->respond("app=pollen Pollen forecast retrieved");
	}


}

if (said $v_read_pollen_forecast) {
	if ($Weather{TodayPollenCount}) {
		$v_read_pollen_forecast->respond("app=pollen Today's pollen count is $main::Weather{TodayPollenCount}. The predominant pollens are " . lc($main::Weather{TodayPollenType}));
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
