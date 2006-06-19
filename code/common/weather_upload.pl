
# Category = Weather

#@ Upload data from your local weather station to wunderground.com.
#@ See code for info on wunderground_* mh.ini parms

=begin comment

 weather_upload.pl by David Norwood, dnorwood2@yahoo.com

 This code will upload your weather station data to wunderground.com.
 Look here for info and examples:
  http://www.wunderground.com/weatherstation/index.asp
  http://www.wunderground.com/weatherstation/ListStations.asp

 The URL to sign up for an account and get back a station id is:
  http://www.wunderground.com/weatherstation/usersignup.asp

 Add/update these mh.ini parms:

  wunderground_stationid = KMNROCHE3
  wunderground_password  = xyz
  wunderground_frequency = 10

  NOTE: last parameter is optional and defaults to 10

 Place this file in your code directory, and you are ready to go.

# 01/12/05 Dominique Benoliel
# - change $Weather{Barom} with $Weather{BaromSea} for WMR928 weather station
# 01/23/05 Dominique Benoliel
# - make some conversions with mh parameters weather_uom_...

=cut

#use POSIX qw(strftime);

$p_weather_update = new Process_Item;
$v_weather_update = new Voice_Cmd '[Show results from,Run] wunderground.com upload';
my $weather_update_html_path = "$config_parms{data_dir}/web/wu-result.html"; #noloop


# Create trigger

if ($Reload and $Run_Members{'trigger_code'}) {
	my $command = "new_minute " . (($config_parms{wunderground_frequency})?$config_parms{wunderground_frequency}:10);

	eval qq(
            &trigger_set("$command", "run_voice_cmd('Run wunderground.com upload')", 'NoExpire', 'upload weather') 
              unless &trigger_get('upload weather');
        );
}

# Events

display($weather_update_html_path) if said $v_weather_update eq 'Show results from';

if (said $v_weather_update eq 'Run') {

    $v_weather_update->respond('app=wunderground Uploading weather data...');

    my $stationid = $config_parms{wunderground_stationid};
    my $passwd    = $config_parms{wunderground_password};
    my $clouds='';
    my $weather_conditions='';




    # Make some conversions if necessary
    my $weather_tempoutdoor = $config_parms{default_temp} =~ /^celsius$/i ? convert_c2f($Weather{TempOutdoor}):$Weather{TempOutdoor};
    my $weather_dewoutdoor = $config_parms{default_temp} =~ /^celsius$/i ? convert_c2f($Weather{DewOutdoor}):$Weather{DewOutdoor};
    my $weather_barom = $config_parms{weather_uom_baro} eq 'mb' ? convert_mb2in($Weather{Barom}):$Weather{Barom};
    my $weather_baromsea = $config_parms{weather_uom_baro} eq 'mb' ? convert_mb2in($Weather{BaromSea}):$Weather{BaromSea};

    my $weather_windgustspeed = $config_parms{weather_uom_wind} eq 'kph' ? convert_km2mile($Weather{WindGustSpeed}):$Weather{WindGustSpeed};
    my $weather_windavgspeed = $config_parms{weather_uom_wind} eq 'kph' ? convert_km2mile($Weather{WindAvgSpeed}):$Weather{WindAvgSpeed};

    $weather_windgustspeed = convert_mps2mph($Weather{WindGustSpeed}) if $config_parms{weather_uom_wind} eq 'm/s';
    $weather_windavgspeed = convert_mps2mph($Weather{WindAvgSpeed}) if $config_parms{weather_uom_wind} eq 'm/s';

    my $weather_rainrate = $config_parms{weather_uom_rainrate} eq 'mm/hr' ? convert_mm2in($Weather{RainRate}):$Weather{RainRate};

    if ($config_parms{serial_wmr968_module} eq "Weather_wmr968") {
	        # ---- CLOUDS ----
		# SKC = Sky Clear
	$clouds = 'SKC' if $Weather{WxTendency} eq 'Sunny';
		# SCT = Scattered
	$clouds = 'SCT' if $Weather{WxTendency} eq 'Partly cloudy';
		# BKN = Broken
	$clouds = 'BKN' if $Weather{WxTendency} eq 'Cloudy';
		# OVC = Overcast
	$clouds = 'OVC' if $Weather{WxTendency} eq 'Rain';
		# ----CONDITIONS WEATHERS ----
		# MI = Shallow clouds
	$weather_conditions = "MI" if $Weather{WxTendency} eq 'Sunny';
		# BC = Patches clouds
	$weather_conditions = "BC" if $Weather{WxTendency} eq 'Partly cloudy';
		# PR = Partial clouds
	$weather_conditions = "PR" if $Weather{WxTendency} eq 'Cloudy';
		# RA = Rain
	$weather_conditions = "RA" if $Weather{WxTendency} eq 'Rain';
		# ---- BAROM ----
	$weather_barom = $weather_baromsea;
    }
    else {
        $clouds = 'CLR' if $Weather{Conditions} eq 'Clear';
        $clouds = 'OVC' if $Weather{Conditions} eq 'Cloudy';
	$clouds = 'SCT' if $Weather{Conditions} eq 'Partly cloudy' or $Weather{Conditions} eq 'Partly sunny';
	$clouds = 'SKC' if $Weather{Conditions} eq 'Sunny';
		# MI = Shallow clouds
	$weather_conditions = "MI" if $Weather{Conditions} eq 'Partly sunny';
		# BC = Patches clouds
	$weather_conditions = "BC" if $Weather{Conditions} eq 'Partly cloudy';
		# PR = Partial clouds
	$weather_conditions = "PR" if $Weather{Conditions} eq 'Cloudy';
		# RA = Rain
	$weather_conditions = "RA" if $Weather{Raining} or $Weather{Conditions} eq 'Light rain';



        # wx200 stores in millibars, 968 stores in Hg
        unless ($weather_barom = $Weather{BaromSea_hg}) {
	    $weather_barom = $Weather{BaromSea};
	    $weather_barom  *= 0.029529987508 if $weather_barom > 100;  # hg should be around 29.
	}
	# for (default) Internet weather, frog, etc.
	$weather_barom = $Weather{Barom} if !$weather_barom;
    }

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =  gmtime();
    my $utc = sprintf "%s-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;
    $utc = &escape($utc);

    my $url = sprintf 'http://weatherstation.wunderground.com/weatherstation/updateweatherstation.php?ID=%s&PASSWORD=%s&dateutc=%s&winddir=%s&windspeedmph=%d&windgustmph=%d&tempf=%.1f&rainin=%.2f&baromin=%.2f&dewptf=%.2f&humidity=%s&weather=%s&clouds=%s&softwaretype=%s&action=updateraw',
	$stationid, $passwd, $utc,
	$Weather{WindAvgDir}?$Weather{WindAvgDir}:$Weather{WindGustDir},
	$weather_windavgspeed,
	$weather_windgustspeed,
	$weather_tempoutdoor,
	$weather_rainrate,
# To set your sea level pressure, add one millibar to your station pressure for every 10 meters of altitude.
#   - lets do this in Weather_wx200.pm instead, as other devices are smarter :)
#	($Weather{Barom} + $altitude/10) * 0.029529987508, # convert millibars to inches Hg
	$weather_barom,
	$weather_dewoutdoor,
	$Weather{HumidOutdoor},
	$weather_conditions,
    	$clouds,
	'Misterhouse';

   print "wunderground: sun=$Weather{sun_sensor} $url\n";  # do not print this to print_log, as it has the password in it
    set $p_weather_update qq|get_url -quiet "$url" $weather_update_html_path|;
    start $p_weather_update;
}

# *** Need to parse the response to look for errors

if (done_now $p_weather_update) {
	$v_weather_update->respond('app=wunderground connected=0 Weather upload completed.');

}

# -------------------
#
# Here is the URL used in the uploading (if you go here without parameters
# you will get a brief usage):
# http://weatherstation.wunderground.com/weatherstation/updateweatherstation.php
# usage
# action [action=updateraw]
# ID [ID as registered by wunderground.com]
# PASSWORD [PASSWORD registered with this ID]
# dateutc - [YYYY-MM-DD HH:MM:SS (mysql format)]
# winddir - [0-360]
# windspeedmph - [mph]
# windgustmph - [windgustmph ]
# humidity - [%]
# tempf - [temperature F]
# rainin - [rain in (hourly)]
# baromin - [barom in]  ... sea level
# dewptf- [dewpoint F]
# weather - [text] -- metar style (+RA)
# clouds - [text] -- SKC, FEW, SCT, BKN, OVC
# softwaretype - [text] ie: vws or weatherdisplay

# Cloud types:
#  CLR No clouds overhead below 10,000 feet.
#  SCT "Scattered" clouds. Refers to cloud coverage of less than 3/10 of the visible sky.
#  BKN "Broken" clouds. Refers to a cloud cover of 6/10 to 9/10 of the visible sky.
#  OVC "Overcast". Refers to cloud coverage of 10/10.

# IF we wanted to try updated Conditions, this pointer might help:
#  http://www.qisfl.net/home/hurricanemike/codedobhelp.htm
