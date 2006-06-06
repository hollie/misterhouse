# $Revision$
# $Date$

# Simple script to return current weather conditions.
# Useful for getting mh stored weather info into other programs.
# Note that the data is returned as plain text, not HTML
#
# by Matthew Williams

my $weather=qq[HTTP/1.0 200 OK
Server: MisterHouse
Content-Type: text/plain
Cache-Control: no-cache

];

if ($Weather{SummaryLong}) { 
	$weather.=$Weather{SummaryLong};
} else {
	$weather.='Temperature: '.$Weather{TempOutdoor}.'&deg;';
	$weather.='  Humidity: '.$Weather{HumidOutdoor}.'%';
	$weather.='  Wind: ';
	if ($Weather{WindAvgSpeed}==0) {
		$weather.='No Wind';
	} else {
		my $windDirName=qw{ N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW }[(($Weather{WindAvgDir}+11.25)/22.5)%16];
		$weather.=$windDirName.' at '.$Weather{WindAvgSpeed};
		if ($Weather{WindGustSpeed} > $Weather{WindAvgSpeed}) {
			$weather.=' gusting to '.$Weather{WindAvgSpeed};
		}
	}
	$weather.='  Air Pressure: '.$Weather{Barom};
}

return $weather;
