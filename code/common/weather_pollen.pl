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

$f_pollen_forecast = new File_Item("$config_parms{data_dir}/web/pollen_forecast.html");

$v_get_pollen_forecast = new Voice_Cmd('Get Pollen Forecast');

if ($state = said $v_get_pollen_forecast) {
	print_log "Getting Pollen forecast";
	run "get_url http://www.pollen.com/forecast.asp?postalcode=$config_parms{zip_code} $config_parms{data_dir}/web/pollen_forecast.html";
}

if (time_cron('0 5 * * *')) {
	print_log "Getting Pollen forecast";
	run_voice_cmd "Get Pollen Forecast";
}

if (($New_Second and file_changed($f_pollen_forecast->name)) or $Reload){
	print_log "Parsing pollen forecast";
	my $count1;
	open(FILE,$f_pollen_forecast->name);
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

$v_read_pollen_forecast = new Voice_Cmd('Read Pollen Forecast');

if ($state = said $v_read_pollen_forecast) {
	speak "Today's pollen count is $main::Weather{TodayPollenCount}. The predominant pollen is $main::Weather{TodayPollenType}";
}
