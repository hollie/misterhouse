
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

 Place this file in your code directory, and you are ready to go. 

=cut

my $stationid = $config_parms{wunderground_stationid};
my $passwd    = $config_parms{wunderground_password};
      
#use POSIX qw(strftime);
 
$p_weather_update = new Process_Item;
$v_weather_update = new Voice_Cmd '[Show results from,Run] wunderground.com upload';
my $f_weather_update_html = "$config_parms{data_dir}/web/wu-result.html";

$state = said $v_weather_update;
display($f_weather_update_html) if $state eq 'Show results from';

if (new_minute 15 or $state eq 'Run') {
#   print_log "Logging weather with id=$stationid and pw=$passwd";

    my $clouds;
    $clouds = 'CLR' if $Weather{Conditions} eq 'Clear';
    $clouds = 'OVC' if $Weather{Conditions} eq 'Cloudy';

                                # strftime tries its own savings time conversion and messes things up
#   $utc = strftime("%Y-%m-%d %H:%M:%S", gmtime());
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =  gmtime();
    my $utc = sprintf "%s-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;

    my $url = sprintf 'http://weatherstation.wunderground.com/weatherstation/updateweatherstation.php?ID=%s&PASSWORD=%s&dateutc=%s&winddir=%s&windspeedmph=%d&windgustmph=%d&tempf=%.1f&rainin=%.2f&baromin=%.2f&dewptf=%.2f&humidity=%s&weather=&clouds=%s&softwaretype=%s&action=updateraw',
	$stationid, $passwd, $utc,
	$Weather{WindAvgDir},
	$Weather{WindAvgSpeed},
	$Weather{WindGustSpeed},
	$Weather{TempOutdoor},
	$Weather{RainRate},
# To set your sea level pressure, add one millibar to your station pressure for every 10 meters of altitude.
#   - lets do this in Weather_wx200.pm instead, as other devices are smarter :)
#	($Weather{Barom} + $altitude/10) * 0.029529987508, # convert millibars to inches Hg
	$Weather{BaromSea} * 0.029529987508, # convert millibars to inches Hg
	$Weather{DewOutdoor},
	$Weather{HumidOutdoor},
    $clouds,
#	'Misterhouse ' . $Version;
	'Misterhouse';
    $url =~ s/ /\%20/g;
#   print "wunderground: sun=$Weather{sun_sensor} $url\n";  # do not print this to print_log, as it has the password in it
    set $p_weather_update qq|get_url -quiet "$url" $f_weather_update_html|;
    start $p_weather_update;
}


# No need to convert ... results are a simple text file?
#if (done_now $p_weather_update) {
#    my $html = file_read $f_weather_update_html;
#    $text = HTML::FormatText->new(leftmargin => 0, rightmargin => 150)->format(HTML::TreeBuilder->new()->parse($html));
#    file_write($f_weather_update_page, $text);
#}

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
