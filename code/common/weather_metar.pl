# Category = Weather
#
# $Revision$
# $Date$
#
#@ Weather METAR parser
#@ 
#@ V 1.63
#@
#@ To get the closest station name in Canada, go to 
#@ http://www.flightplanning.navcanada.ca and choose METAR/TAF
#@
#@ For non-Canadian locations, do a web search for ICAO
#@ one lookup site: http://www.jfast.org/Tools/Port2PortAirDist/GeoLookup.asp
#@
#@ Place name of country (Canada or "other") in mh.ini as weather_metar_country
#@ Place name of nearest station in mh.ini as weather_metar_station
#@ Place unit preference (metric or imperial) in mh.ini as weather_metar_units
#@
#
# by Matthew Williams
#
# V 1.63
# - Added ability to read from automated stations (AUTO tag)
# - Added ability to understand COR (alternate correction tag)
#
# V 1.62
# - Added ability to add hooks that are called when new forecasts are retrieved.
# - Added new SummaryLong key to Weather Hash
#
# V 1.61
# - Fixed typo that corrupted Weather{TempOutdoor}
#
# V 1.6
# - Added imperial units
#
# V 1.5
# - fixed a typo.  I hate typos.  I really should test this thing more before
#   I send out updates. :-)
#
# V 1.4
# - based on Michael Brown's suggestion, the Weather hash now contains
#   values that are nicely rounded.
#
# V 1.3
# - fixed code to handle RMK without a space after it
# - allowed for CCA (correction)
#
# V 1.2
# - accounted for change in NavCanada format
# 
# V 1.1
# - added relative humidity calculation based on dewpoint
# - added humidex calculation
#
# V 1.0
# - initial release

# noloop=start
my $station=uc($config_parms{weather_metar_station});
my $country=lc($config_parms{weather_metar_country});
my $units=lc($config_parms{weather_metar_units});
my @weather_metar_hooks;

$station='CYOW' unless $station;
$country='other' unless $country;
$units='metric' unless $units;

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
}

# useful for debugging
$v_show_weather=new Voice_Cmd('show weather');

if (said $v_show_weather) {
  my $metric;
  my $response='';
  foreach $metric (keys(%Weather)) {
    $response.= "Weather $metric is $Weather{$metric}\n";
  }
  respond($response);
}

if (done_now $p_weather_metar_page or $Reload) {
  my $html=file_read $file;
  return unless $html;
  
  # NavCanada changed their format to break reports into multiple lines
  $html =~ s/\n<br>\n//g;
  my ($winddir, $windspeed, $windgust, $temp, $windchill, $last_report);
  my ($pressure, $weather, $clouds, $winddirname, $windspeedtext);
  my ($metricpressure,$pressuretext, $apparenttemp, $dewpoint);
  my $apparenttemp='none';
  # apparenttemp is either windchill or humidex

  while ($html =~ m#((METAR) |(SPECI) )?$station \d{6}Z (AUTO )?(COR )?(CCA )?\d{3}\d{2}(G\d{2})?KT .+?\n#g) {
    $last_report=$&;
    chop $last_report;
    $weather='';
    $clouds=' ';

    print_log "Parsing METAR report: $last_report";
  
    ($winddir,$windspeed,$windgust)=$last_report =~ m#(\d{3})(\d{2})(G\d{2})?KT#;
    if ($last_report =~ m#(M?\d{2})/(M?\d{2})#) { ($temp,$dewpoint)=($1,$2);  };
    if ($last_report =~ m#A(\d{4})#) { $pressure=$1*0.03386; }; # pressure in mm of mercury
    if ($last_report =~ m#Q(\d{4})#) { $pressure=$1/10; };  # pressure in hPa
    my $element;
    foreach $element (split (/ /,$last_report)) {
      if ($element eq $station) { next; }; # don't decode station
      if ($element =~ m#^RMK#) { last; }; # end of current conditions
      if ($element eq 'CAVOK') { $weather .= 'ceiling and visibility OK'; };
      if ($element eq 'SKC' or $element eq 'CLR') { $clouds = 'sky clear '; };
      if ($element eq 'METAR' or $element eq 'SPECI') { next; };
      if ($element eq 'CCA') { next; }; # correction
      if ($element eq 'AUTO') { next; }; # automated station
      if ($element =~ m#^FEW# ) { $clouds = 'few clouds '; };
      if ($element =~ m#^SCT# ) { $clouds = 'scattered clouds '; };
      if ($element =~ m#^BKN# ) { $clouds = 'broken clouds '; };
      if ($element =~ m#^OVC# ) { $clouds = 'overcast '; };
    
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
  $weather = 'no precipitation' if $weather eq '';

  $windspeed *= 1.85; # convert from knots to km/h
  $windgust =~ s/^G//g;
  $windgust *= 1.85; # convert from knots to km/h
  $temp =~ s/M/-/;
  # remove leading 0 if present
  $temp =~ s/^(-?)0/$1/;
  # remove leading 0 if present
  $dewpoint =~ s/M/-/;
  $dewpoint =~ s/^(-?)0/$1/;
  $winddirname=qw{ N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW }[(($winddir+11.25)/22.5)%16];

  if ($windspeed < 5 or $windspeed > 100 or $temp < -50 or $temp > 5) { 
    $windchill=$temp;
  } else {
    $windchill=13.12+0.6215*$temp-11.37*($windspeed**0.16)+0.3965*$temp*($windspeed**0.16);
    $apparenttemp=$windchill;
  }
  my $vapourPressureSaturation=6.112*10.0**(7.5*$temp/(237.7+$temp));
  my $vapourPressure=6.112*10.0**(7.5*$dewpoint/(237.7+$dewpoint));
  my $humidity=100*$vapourPressure/$vapourPressureSaturation;
  my $humiditytext=sprintf('%.0f%%',$humidity); 
  my $humidex=$temp+(0.5555*($vapourPressure-10));

  # only report humidex if temperature is at least 20 degrees and 
  # humidex is at least 25 degrees
  if (($temp >= 20) && ($humidex >= 25)) {
    $apparenttemp=$humidex;
  }

  my $windunit='km/h';
  my $tempunit='C';
  $metricpressure=$pressure;  # need to save metric pressure for $Weather{Barom}
  if ($units eq 'imperial') {
    grep {$_=convert_c2f($_)} ($temp, $dewpoint, $apparenttemp, $humidex, $windchill);
    grep {$_=convert_km2mile($_)} ($windspeed, $windgust);
    grep {$_/=3.386} ($pressure); # convert from kPa to inHg
    $tempunit='F';
    $windunit='mph';
    $pressuretext=sprintf('%.2f inHg',$pressure);
  } else {
    $pressuretext=sprintf('%.1f kPa',$pressure);
  }

  $windspeedtext = sprintf ("%.0f $windunit",$windspeed);
  my $altwindtext=$windspeedtext;
  if ($windgust > 0 ) {
    $windspeedtext = sprintf ("%.0f (%.0f) $windunit",$windspeed,$windgust);
  } 
  
  if ($windspeed == 0) {
    $Weather{Wind}='no wind';
    $altwindtext='no wind';
  } else {  
    $Weather{Wind}="$winddirname at $windspeedtext";
    $altwindtext="$winddirname at $altwindtext";
  }

  my $apparenttemptext='';
  if ($apparenttemp ne 'none') {
    $apparenttemptext=sprintf(" (%.0f)",$apparenttemp);
  }
  $Weather{Summary_Short}=sprintf('%d&deg;%s%s %s',$temp, $tempunit, $apparenttemptext, $humiditytext);
  $Weather{Summary}=$Weather{Summary_Short}." $pressuretext ${clouds}$weather";
  $Weather{TempOutdoor}=sprintf("%.0f",$temp);
  $Weather{ApparentTemp}=sprintf("%.0f",$apparenttemp);
  $Weather{HumidOutdoor}=sprintf("%.0f",$humidity);
  $Weather{WindAvgDir}=$winddir;
  $Weather{WindAvgSpeed}=sprintf("%.0f",$windspeed);
  $Weather{WindGustDir}=$winddir;
  if ($windgust > 0) {
    $Weather{WindGustSpeed}=sprintf("%.0f",$windgust);
  } else {
    $Weather{WindGustSpeed}=$Weather{WindAvgSpeed};
  }
  $Weather{SummaryLong}='Temperature: '.$Weather{TempOutdoor}.'&deg;'.$tempunit;
  if ($apparenttemp ne 'none') {
    $Weather{SummaryLong}.='  Apparent Temperature: '.$Weather{ApparentTemp}.'&deg;'.$tempunit;
  }
  $Weather{SummaryLong}.='  Humidity: '.$Weather{HumidOutdoor}.'%';
  $Weather{SummaryLong}.='  Wind: '.$altwindtext;
  if ($windgust > 0) {
    $Weather{SummaryLong}.=" gusting to $Weather{WindGustSpeed} $windunit";
  }
  $Weather{SummaryLong}.="  Air Pressure: $pressuretext  Sky: ${clouds} Precipitation: $weather";
  $Weather{WindChill}=sprintf("%.0f",$windchill);
  $Weather{Humidex}=sprintf("%.0f",$humidex);
  $Weather{DewOutdoor}=sprintf("%.0f",$dewpoint);
  $Weather{Barom}=sprintf("%.1f",$metricpressure*10);
  print_log "Weather: $Weather{Summary} $Weather{Wind} dewpoint $Weather{DewOutdoor} humidity $Weather{HumidOutdoor}";
  foreach my $subref (@weather_metar_hooks) {
    &$subref();
  }
}

sub weather_metar_add_hook {
  my ($subref)=@_;
  push @weather_metar_hooks,$subref;
}

