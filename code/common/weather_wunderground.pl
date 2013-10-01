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
	my $wunderground_getweather_file;
	my $wunderground_stationid=$config_parms{wunderground_stationid};
	my $wunderground_url;
	$p_weather_wunderground_getweather =  new Process_Item();
	
	my $wunderground_states = 'getweather,debug';
	$v_wunderground = new Voice_Cmd("wunderground [$wunderground_states]");
# noloop=stop

if ($Reload) {
	$wunderground_stationid=$config_parms{wunderground_stationid};
	$wunderground_stationid='KNYROCHE41' unless $wunderground_stationid;
	$wunderground_getweather_file=$config_parms{data_dir}.'/web/weather_wunderground_getweather.xml';
	$wunderground_url='http://api.wunderground.com/weatherstation/WXCurrentObXML.asp?ID='.$wunderground_stationid;
	
	set $p_weather_wunderground_getweather qq{get_url -quiet "$wunderground_url" "$wunderground_getweather_file"};
	#$p_weather_wunderground_getweather-set_output("$wunderground_getweather_file");
	
	&trigger_set('($New_Minute_10) or $Reload', "run_voice_cmd 'wunderground getweather'", 'NoExpire', 'Update current weather conditions via wunderground')
	  unless &trigger_get('Update current weather conditions via wunderground');
}

my $wunderground_state = 'blank';
if ($wunderground_state = $v_wunderground ->{said}) {
	if ($wunderground_state eq 'getweather'){
		start $p_weather_wunderground_getweather;
	}
}

my(%wunderground_data,@wunderground_keys);
if (done_now $p_weather_wunderground_getweather) {
	$Weather{wunderground_obsv_valid} = 0; #Set to not valid unless proven
  	#my $wunderground_xml=file_read $wunderground_getweather_file;
	print_log "wunderground getweather finished.";
	my $twig = new XML::Twig;
  	$twig->parsefile($wunderground_getweather_file);
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

sub weather_wunderground_addelem {
	my ($w_root,$w_dest,$w_src) = @_;
	if(my $w_srcval=$w_root->first_child_text("$w_src")) {
		$wunderground_data{$w_dest}=$w_srcval;
		push(@wunderground_keys, $w_dest);
	}
}