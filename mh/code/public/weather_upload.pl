
# Category = Weather

# weather_upload.pl
# By David Norwood, dnorwood2@yahoo.com

# This code will upload your weather station data to wunderground.com. 
# Look here for info and examples: 
#
# http://www.wunderground.com/weatherstation/index.asp
# http://www.wunderground.com/weatherstation/ListStations.asp
# 
# The URL to sign up for an account and get back a station id is:
# http://www.wunderground.com/weatherstation/usersignup.asp 
# 
# After you have obtained a station id and password, enter them below, then
# place this file in your code directory, and you are ready to go. 

#y $stationid = "KCATHOUS1";
my $stationid = $config_parms{wunderground_stationid};
my $passwd    = $config_parms{wunderground_password};
      
#use POSIX qw(strftime);
 
my ($utc, $url);
my $p_weather_update = new Process_Item;

my $f_weather_update_page = "$config_parms{data_dir}/web/wu-result.txt";
my $f_weather_update_html = "$config_parms{data_dir}/web/wu-result.html";

$v_weather_update = new  Voice_Cmd('Show latest wunderground.com upload results');
display($f_weather_update_page) if said $v_weather_update;

if (new_minute 15) {
#   print_log "Logging weather with id=$stationid and pw=$passwd";

                                # strftime tries its own savings time conversion and messes things up
#   $utc = strftime("%Y-%m-%d %H:%M:%S", gmtime());
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =  gmtime();
    $utc = sprintf "%s-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec;

    $url = sprintf 'http://weatherstation.wunderground.com/weatherstation/updateweatherstation.php?ID=%s&PASSWORD=%s&dateutc=%s&winddir=%s&windspeedmph=%d&windgustmph=%d&tempf=%.1f&rainin=%.2f&baromin=%.2f&dewptf=%.2f&humidity=%s&weather=&clouds=&softwaretype=%s&action=updateraw',
	$stationid, $passwd, $utc,
	$Weather{WindAvgDir},
	$Weather{WindAvgSpeed},
	$Weather{WindGustSpeed},
	$Weather{TempOutdoor},
	$Weather{RainRate},
	$Weather{Barom} * 0.029529987508,      # convert millibars to inches Hg
	$Weather{DewOutdoor},
	$Weather{HumidOutdoor},
	"Misterhouse " . $Version;
    $url =~ s/ /\%20/g;
    set $p_weather_update qq|get_url -quiet "$url" $f_weather_update_html|;
    start $p_weather_update;
}


if (done_now $p_weather_update) {
    my $html = file_read $f_weather_update_html;

    $text = HTML::FormatText->new(leftmargin => 0, rightmargin => 150)->format(HTML::TreeBuilder->new()->parse($html));

    file_write($f_weather_update_page, $text);
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
# baromin - [barom in]
# dewptf- [dewpoint F]
# weather - [text] -- metar style (+RA) 
# clouds - [text] -- SKC, FEW, SCT, BKN, OVC
# softwaretype - [text] ie: vws or weatherdisplay


