# Category = Weather

#@ Updates live weather variables from http://api.wunderground.com. 

=begin comment
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

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut
# noloop=start
	use Weather_Common;
	use XML::Twig;
	my $wunderground_file_getweather;
	my $wunderground_file_getforecast;
	$p_weather_wunderground_getweather	= new Process_Item();
	$p_weather_wunderground_getforecast	= new Process_Item();
	
	my $wunderground_states = 'getweather,getforecast,debug';
	$v_wunderground = new Voice_Cmd("wunderground [$wunderground_states]");
# noloop=stop

if ($Reload) {
	$wunderground_file_getweather=$config_parms{data_dir}.'/web/weather_wunderground_weather.xml';
	$wunderground_file_getforecast=$config_parms{data_dir}.'/web/weather_wunderground_forecast.xml';
	if($config_parms{wunderground_stationid} eq '') {
		print_log("Warning: wunderground_stationid is not defined in mh.private.ini.");
	}
	if($config_parms{wunderground_apikey} eq '') {
		print_log("Warning: wunderground_apikey is not defined in mh.private.ini.");
	}
	if($config_parms{state} eq '') {
		print_log("Warning: state is not defined in mh.private.ini.");
	}
	if($config_parms{wunderground_city} eq '') {
		print_log("Warning: wunderground_city is not defined in mh.private.ini.");
	}
	
	#$p_weather_wunderground_getweather-set_output("$wunderground_file_getweather");
	
	&trigger_set('($New_Minute_10) or $Reload', "run_voice_cmd 'wunderground getweather'", 'NoExpire', 'Update current weather conditions via wunderground')
	  unless &trigger_get('Update current weather conditions via wunderground');
	&trigger_set('($New_Minute && $Minute == 5) or $Reload', "run_voice_cmd 'wunderground getforecast'", 'NoExpire', 'Update forecast via wunderground')
	  unless &trigger_get('Update forecast via wunderground');
}

my $wunderground_state = 'blank';
if ($wunderground_state = $v_wunderground->{said}) {
	if ($wunderground_state eq 'debug'){
		#Not implemented
	} elsif ($wunderground_state eq 'getweather'){
		if($config_parms{wunderground_stationid} eq '') {
			print_log("ERROR: wunderground_stationid is not defined in mh.private.ini.");
		} else {
			my $wunderground_url='http://api.wunderground.com/weatherstation/WXCurrentObXML.asp?ID='.$config_parms{wunderground_stationid};
			print_log('Retrieving: '.$wunderground_url);
			set $p_weather_wunderground_getweather qq{get_url -quiet "$wunderground_url" "$wunderground_file_getweather"};
			start $p_weather_wunderground_getweather;
		}
	} elsif ($wunderground_state eq 'getforecast'){
		my $wundergrounderror=0;
		if($config_parms{wunderground_apikey} eq '') {
			print_log("ERROR: wunderground_apikey is not defined in mh.private.ini.");
			$wundergrounderror++;
		}
		if($config_parms{state} eq '') {
			print_log("ERROR: state is not defined in mh.private.ini.");
			$wundergrounderror++;
		}
		if($config_parms{wunderground_city} eq '') {
			print_log("ERROR: wunderground_city is not defined in mh.private.ini.");
			$wundergrounderror++;
		}
		if ($wundergrounderror == 0) {
			my $wustate=uc $config_parms{state};
			my $wucity=$config_parms{wunderground_city};
			my $wunderground_url='https://api.wunderground.com/api/'.$config_parms{wunderground_apikey}.'/forecast/q/'.$wustate.'/'.$wucity.'.xml';
			print_log('Retrieving: '.$wunderground_url);
			set $p_weather_wunderground_getforecast qq{get_url -quiet "$wunderground_url" "$wunderground_file_getforecast"};
			start $p_weather_wunderground_getforecast;
		}
	}
}

my(%wunderground_data,@wunderground_keys);

if (done_now $p_weather_wunderground_getweather) {
	$Weather{wunderground_obsv_valid} = 0; #Set to not valid unless proven
  	#my $wunderground_xml=file_read $wunderground_file_getweather;
	print_log "wunderground getweather finished.";
	my $twig = new XML::Twig;
	$twig->parsefile($wunderground_file_getweather);
	my $root = $twig->root;
	my $channel = $root->first_child("current_observation");
	
	my $w_stationid = $root->first_child_text("station_id");
	
	print_log "WUnderground: Received stationid: $w_stationid\n";
	
	if($config_parms{wunderground_stationid} eq $w_stationid) {
		%wunderground_data={};
		@wunderground_keys=[];
		#TempOutdoor
		weather_wunderground_addelem($root,'TempOutdoor','temp_f');
		#DewOutdoor
		weather_wunderground_addelem($root,'DewOutdoor','dewpoint_f');
		#WindAvgDir
		weather_wunderground_addelem($root,'WindAvgDir','wind_dir');
		#WindAvgSpeed
		weather_wunderground_addelem($root,'WindAvgSpeed','wind_mph');
		#WindGustDir
		#WindGustSpeed
		#WindGustTime
		#Clouds
		#Conditions
		#Barom
		weather_wunderground_addelem($root,'Barom','pressure_mb');
		#BaromSea
		#BaromDelta
		#HumidOutdoorMeasured
		#HumidOutdoor
		weather_wunderground_addelem($root,'HumidOutdoor','relative_humidity');
		#IsRaining
		#IsSnowing
		#RainTotal
		#RainRate
		
		#use Data::Dumper;
		#print Dumper %wunderground_data;
		
		&Weather_Common::populate_internet_weather(\%wunderground_data, $config_parms{weather_wunderground_elements});
		&Weather_Common::weather_updated;
		      
	} else {
		print_log "WUnderground: ERROR! Received a station ID we didn't want. Aborting.";
	}
	
}

if (done_now $p_weather_wunderground_getforecast) {
	$Weather{wunderground_obsv_valid} = 0; #Set to not valid unless proven
  	#my $wunderground_xml=file_read $wunderground_file_getweather;
	print_log "wunderground getforecast finished.";
	my $twig = new XML::Twig;
	print_log('Reading file: '.$wunderground_file_getforecast);
	$twig->parsefile($wunderground_file_getforecast);
	my $root = $twig->root;
	my $fcast = $root->first_child("forecast");
	my $txtfcast = $fcast->first_child("txt_forecast");
	my $fcdays = $txtfcast->first_child('forecastdays');
	
	my @forecast = $fcdays->children('forecastdays');
	
	print "\n\n";
	print $fcdays->text();
	print "\n\n";

	foreach my $fcday (@forecast) {
		print_log($fcday->first_child_text('fcttext'));
	}
	
	use Data::Dumper;
	#print Dumper @forecast;
}

sub weather_wunderground_addelem {
	my ($w_root,$w_dest,$w_src) = @_;
	if(my $w_srcval=$w_root->first_child_text("$w_src")) {
		$wunderground_data{$w_dest}=$w_srcval;
		push(@wunderground_keys, $w_dest);
	}
}
