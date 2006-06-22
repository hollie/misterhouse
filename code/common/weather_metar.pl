# Category = Weather
#
# $Revision$
# $Date$
#
#@ Weather METAR parser
#@ 
#@ Revision: $Revision$ 
#@
#@ To get the closest station name in Canada, go to 
#@ http://www.flightplanning.navcanada.ca and choose METAR/TAF
#@
#@ For non-Canadian locations, do a web search for ICAO
#@ one lookup site: http://www.jfast.org/Tools/Port2PortAirDist/GeoLookup.asp
#@
#@ Place name of country (Canada or "other") in mh.ini as weather_metar_country
#@ Place name of nearest station in mh.ini as weather_metar_station
#@
#
# by Matthew Williams

# noloop=start
use Weather_Common;

my $station=uc($config_parms{weather_metar_station});
my $country=lc($config_parms{weather_metar_country});

$station='CYOW' unless $station;
$country='other' unless $country;

my $url;
if ($country eq 'canada') {
	$url="http://www.flightplanning.navcanada.ca/cgi-bin/Fore-obs/metar.cgi?NoSession=NS_Inconnu&format=raw&Langue=anglais&Region=can&Location=&Stations=".$station;
} else {
	$url="http://weather.noaa.gov/cgi-bin/mgetmetar.pl?Submit=SUBMIT&cccc=".$station;
}

my $file=$config_parms{data_dir}.'/web/weather_metar.html';

$p_weather_metar_page= new Process_Item(qq{get_url -quiet "$url" "$file"});

$v_get_metar_weather = new Voice_Cmd('get metar weather');

# noloop=stop

if (($New_Minute and $Minute==5) or said $v_get_metar_weather) {
	start $p_weather_metar_page;
	if (said $v_get_metar_weather) {
		$v_get_metar_weather->respond('Updating weather information from latest METAR');
	}
}

# useful for debugging
$v_show_weather=new Voice_Cmd('show weather');

if (said $v_show_weather) {
	my $metric;
	my $response='';
	foreach $metric (keys(%Weather)) {
		$response.= "Weather $metric is $Weather{$metric}\n";
	}
	$v_show_weather->respond($response);
}

if (done_now $p_weather_metar_page or $Reload) {
	my $html=file_read $file;
	return unless $html;

	# NavCanada changed their format to break reports into multiple lines
	$html =~ s/\n<br>\n//g;
	my %metar; 
	my $last_report;
	my ($pressure, $weather, $clouds, $winddirname, $windspeedtext);
	my ($metricpressure,$pressuretext, $apparenttemp, $dewpoint);
	my $apparenttemp='none';
	# apparenttemp is either windchill or humidex

	while ($html =~ m#((METAR) |(SPECI) )?$station \d{6}Z (AUTO )?(COR )?(CCA )?\d{3}\d{2}(G\d{2})?KT .+?\n#g) {
		$last_report=$&;
		chop $last_report;
		$weather='';
		$clouds='';

		print_log "Parsing METAR report: $last_report";
	
		($metar{WindAvgDir},$metar{WindAvgSpeed},$metar{WindGustSpeed})=$last_report =~ m#(\d{3})(\d{2})(G\d{2})?KT#; # speeds in knots
		if ($last_report =~ m#(M?\d{2})/(M?\d{2})#) { ($metar{TempOutdoor},$metar{DewOutdoor})=($1,$2);	}; # temperatures are in Celsius
		if ($last_report =~ m#A(\d{4})#) { $metar{BaromSea}=convert_in2mb($1/100) }; # pressure in inches of mercury, converted to mb
		if ($last_report =~ m#Q(\d{4})#) { $metar{BaromSea}=$1; };	# pressure in hPa (mb)
		my $element;
		foreach $element (split (/ /,$last_report)) {
			if ($element eq $station) { next; }; # don't decode station
			if ($element =~ m#^RMK#) { last; }; # end of current conditions
			if ($element eq 'CAVOK') { $weather .= 'ceiling and visibility OK'; };
			if ($element eq 'SKC' or $element eq 'CLR') { $clouds = 'sky clear '; };
			if ($element eq 'METAR' or $element eq 'SPECI') { next; };
			if ($element eq 'CCA') { next; }; # correction
			if ($element eq 'AUTO') { next; }; # automated station
			if ($element =~ m#^FEW# ) { $clouds = 'few clouds'; };
			if ($element =~ m#^SCT# ) { $clouds = 'scattered clouds'; };
			if ($element =~ m#^BKN# ) { $clouds = 'broken clouds'; };
			if ($element =~ m#^OVC# ) { $clouds = 'overcast'; };
		
			if ($element =~ m#\d#) { next; }; # precipitation has no digits
			$element =~ /^\+/ && do { $weather.='heavy ' };
			$element =~ /^\-/ && do { $weather.='light ' };
			($element) = $element =~ m#^[\+\-]?(.+)#;
			while ($element =~ m#(.{2})#g) {
				if ($1 eq 'MI') { $weather .= 'shallow ' };
				if ($1 eq 'PR') { $weather .= 'partial ' };
				if ($1 eq 'BC') { $weather .= 'patches of ' };
				if ($1 eq 'DR') { $weather .= 'low drifting ' };
				if ($1 eq 'BL') { $weather .= 'blowing ' };
				if ($1 eq 'SH') { $weather .= 'showers ' };
				if ($1 eq 'TS') { $weather .= 'thunderstorm ' };
				if ($1 eq 'FZ') { $weather .= 'freezing ' };
				if ($1 eq 'DZ') { $weather .= 'drizzle ' };
				if ($1 eq 'RA') { $weather .= 'rain ' };
				if ($1 eq 'SN') { $weather .= 'snow ' };
				if ($1 eq 'SG') { $weather .= 'snow grains ' };
				if ($1 eq 'IC') { $weather .= 'ice crystals ' };
				if ($1 eq 'PL') { $weather .= 'ice pellets ' };
				if ($1 eq 'GR') { $weather .= 'hail ' };
				if ($1 eq 'GS') { $weather .= 'small hail ' };
				if ($1 eq 'UP') { $weather .= 'unknown precipitation ' };
				if ($1 eq 'BR') { $weather .= 'mist ' };
				if ($1 eq 'FG') { $weather .= 'fog ' };
				if ($1 eq 'FU') { $weather .= 'smoke ' };
				if ($1 eq 'VA') { $weather .= 'volcanic ash ' };
				if ($1 eq 'DU') { $weather .= 'widespread dust haze ' };
				if ($1 eq 'SA') { $weather .= 'sand ' };
				if ($1 eq 'HZ') { $weather .= 'haze ' };
				if ($1 eq 'PY') { $weather .= 'spray ' };
				if ($1 eq 'PO') { $weather .= 'dust/sand whirls ' };
				if ($1 eq 'SQ') { $weather .= 'squalls ' };
				if ($1 eq 'FC') { $weather .= 'funnel cloud ' };
				if ($1 eq 'SS') { $weather .= 'sandstorm ' };
				if ($1 eq 'DS') { $weather .= 'duststorm ' };
				if ($1 eq 'VC') { $weather .= 'distant ' };
				if ($1 eq 'RE') { $weather .= 'recent ' };
			}
		}
	}
	
	$weather =~ s/ $//; # remove trailing space
	$weather = 'average' if $weather eq '';

	$metar{Conditions}=$weather;
	$metar{Clouds}=$clouds;

	# remove G from gust measurement
	$metar{WindGustSpeed} =~ s/^G//g;

	# remove leading zeros
	grep {$metar{$_} =~ s/^0//} qw(WindAvgSpeed, WindGustSpeed);

	if ($metar{WindGustSpeed} eq '') {
		$metar{WindGustSpeed}=$metar{WindAvgSpeed};
	}
	$metar{WindGustDir}=$metar{WindAvgDir};
	# change M to minus sign
	$metar{TempOutdoor} =~ s/M/-/;
	# remove leading 0 if present
	$metar{TempOutdoor} =~ s/^(-?)0/$1/;
	# change M to minus sign
	$metar{DewOutdoor}  =~ s/M/-/;
	# remove leading 0 if present
	$metar{DewOutdoor} =~ s/^(-?)0/$1/;

	if ($config_parms{weather_uom_temp} eq 'F') {
		grep {$metar{$_}=convert_c2f($_)} qw(TempOutdoor, DewOutdoor);
	}
	if ($config_parms{weather_uom_wind} eq 'mph') {
		grep {$metar{$_}=convert_nm2mile($_)} qw(WindAvgSpeed,WindGustSpeed);
	}
	if ($config_parms{weather_uom_wind} eq 'm/s') {
		grep {$metar{$_}=convert_knots2mps($_)} qw(WindAvgSpeed,WindGustSpeed);
	}
	if ($config_parms{weather_uom_wind} eq 'kph') {
		grep {$metar{$_}=convert_nm2km($_)} qw(WindAvgSpeed,WindGustSpeed);
	}

	$metar{Barom}=convert_sea_barom_to_local_mb($metar{BaromSea});

	if ($config_parms{weather_uom_baro} eq 'in') {
		grep {$metar{$_}=convert_mb2in($_)} qw(Barom, BaromSea);
	} else {
		grep {$metar{$_}=sprintf("%.1f",$metar{$_})} qw(Barom, BaromSea);
	}

	grep {$metar{$_}=sprintf('%.0f',$metar{$_})} qw(
		TempOutdoor
		DewOutdoor
		WindAvgSpeed
		WindGustSpeed
	);

	&populate_internet_weather(\%metar);
	&weather_updated;
}

