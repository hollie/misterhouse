# Category=Weather

# $Date$
# $Revision$

#@ This code will retrieve and parse data from an AWS weather station via
#@ their website.

#@ Updated: 2008-01-16
#@ The method for finding the station ID has changed:
#@ Go to http://www.aws.com/aws_2001/broadcasters/asp/Online.asp and enter your zip code:  ie: 30005
#@ It then brings up the following page:
#@ http://weather.weatherbug.com/GA/Alpharetta-weather.html?zcode=z6169
#@ View Source and search for stat=  (DNWDY is the station ID for my location)
#@ The full URL that this code uses looks like: http://www.aws.com/full.asp?id=dnwdy
#@ then add the id to the aws_id config parameter in your mh.ini or
#@ mh.private.ini:<br><br>
#@
#@ aws_id = TMISC
#@ aws_id = STATION1,STATION2,STATION3
#@
#@ As you can see, you can specify multiple stations.  The first station will
#@ always be tried first.  If data is not available, the remaining stations
#@ will be tried in order until we find good data.
#@ <br><br>
#@ The URL containing the ID of the TMISC AWS station is shown for example:
#@ <a href="http://www.aws.com/aws_2001/asp/obsForecast.asp?id=TMISC&obs=full">
#@ http://www.aws.com/aws_2001/asp/obsForecast.asp?id=TMISC&obs=full</a>

=begin comment

 weather_aws.pl
 Created by Brian Rudy (brudyNO@SPAMpraecogito.com)

 This code will retrieve and parse data from an AWS weather station via
 AWS's website.

 Most AWS sites are k-12 schools and non profit organizations like museums.
 Most sites upload their data in real time to AWS whenever a request is
 made via a remote site. Be warned some sites only update their sensor data
 when their internet connection is up (usually during the school day).

 If you need real-time data, you should check the 'staleness' of the
 timestamp on the returned data from your selected site to make sure it's
 current and is being updated when you need the data.


 Revision History

 Version 1.3      January 23, 2003
 Bug fixes from Martin Dolphin (with help from Bruce) to support negative
 temperature, windchill and dewpoint values. Updated weather summary for
 status line.

 Version 1.2      October 26, 2002
 General code cleanup and compatability enhacements. Support for status_line.pl,
 seamless support for Bruce's weather_monitor.pl and weather_log.pl.

 Version 1.1b     October 1, 2002
 Added convert_direction_br as temporary workaround for weather_monitor.pl
 wind direction problem.

 Version 1.1      April 13, 2002
 Updated table depth per Ron Wright's suggestion.

 Version 1.0      December 13, 2000
 Complete re-write supporting MH 2.36's Weather_Item, and
 Bruce's weather_log.pl, and weather_monitor.pl.
 Added hooks to use as library.

 Version 0.2      September 20, 2000
 Updated $AWSWeatherURL to reflect change on AWS's web site.

 Version 0.1      September 14, 2000
 Yea, it works!

=cut

use HTML::TableExtract;
use Weather_Common;

# noloop=start
my $aws_ids=$config_parms{aws_id};
$aws_ids='TMISC' unless $aws_ids;
$aws_ids=~s/\s//g;
my @AWS_IDs = split(/,/,$aws_ids);
$p_awsweather_page = new Process_Item;
my $AWS_ID_index=0;
&set_aws_index($AWS_ID_index);

my $prev_timestamp;
my $AWSWeatherURL="http://www.aws.com/full.asp?id=";
$v_get_aws_weather = new Voice_Cmd('Get AWS weather data');
my $f_awsweather_html;

# noloop=stop

# These values aren't provided by this code, but leaving them undefined causes
# problems with logging. Leave them commented out if you have external code to
# fill them with usefull data.
#$Weather{TempIndoor}  = 0.00;
#$Weather{HumidIndoor} = 0.00;

# *** Conditions?, IsRaining?, etc.

# Create trigger

if ($Reload) {
    &trigger_set("new_minute 5", "run_voice_cmd('Get AWS weather data')", 'NoExpire', 'get aws weather')
      unless &trigger_get('get aws weather');
}

# Events

sub set_aws_index {
	($AWS_ID_index)=@_;

	if ($AWS_ID_index > $#AWS_IDs) {
		$AWS_ID_index = 0;
	}
	my $aws_id=$AWS_IDs[$AWS_ID_index];
	$f_awsweather_html = "$config_parms{data_dir}/web/${aws_id}.html";
	$p_awsweather_page->set(qq!get_url -quiet "${AWSWeatherURL}${aws_id}" "$f_awsweather_html"!);
	return $AWS_ID_index;
}

if (said $v_get_aws_weather) {
   if (&net_connect_check) {
       $v_get_aws_weather->respond("app=weather Retrieving AWS weather...");
       # always start at the 1st station
       &set_aws_index(0);
       # Use start instead of run so we can detect when it is done
       start $p_awsweather_page;
   } else {
       $v_get_aws_weather->respond("I must be connected to the Internet to get weather data.");
   }
}

# This would be far more efficient if AWS allowed access to
# their SQL db. Might be time for a little reverse engineering...
# *** More like a little XML... (if they have it, otherwise forget them.)
if (done_now $p_awsweather_page) {

  my $html = file_read $f_awsweather_html;
  return unless $html;

  if ($html =~ 'Temporarily Unavailable') {
  	&print_log("weather_aws: info not available for station ".$AWS_IDs[$AWS_ID_index]);
  	if (&set_aws_index($AWS_ID_index+1)) {
  		&print_log("weather_aws: moving forward to next station: ".$AWS_IDs[$AWS_ID_index]);
  		$p_awsweather_page->start;
  	} else {
  		&print_log("weather_aws: no more stations to use");
	}
	return;
  }

  # hash used to temporarily store weather info before selective load into %Weather
  my %w=();

  my $te = new HTML::TableExtract( depth => 2, count => 1, subtables => 1);

  $te->parse($html);
  my @cell = $te->rows;

  # Timestamp of last sucessful data retrieval from internet node
  $cell[0][0] =~ m/\s+(\d+)\/(\d+)\/(\d+) - (\d+):(\d+):(\d+) (\w+)/;
  my $timestamp = "$1$2$3$4$5$6$7";
  return unless $timestamp and $timestamp ne $prev_timestamp;
  $prev_timestamp = $timestamp;
  #print "Timestamp of last sucessfull data retrieval: $1\/$2\/$3 $4:$5:$6 $7\n";

  $cell[1][1] =~ m/\s+(-?\d+).(\d+)/;
  #print "Current temperature: ", join(".", $1, $2), "°F\n";
  $w{TempOutdoor} = join(".", $1, $2);

  #$cell[1][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Min temp: ", join(".", $1, $2), "°F at ", "$3:$4 $5\n";
  #print "Max temp: ", join(".", $6, $7), "°F at ", "$8:$9 $10\n";

  # Currently no way to determine if increasing or decreasing.
  # Need to parse image name at the end of this cell to get it.
  #$cell[1][3] =~ m/\s+(\d+).(\d+)/;
  #print "Temperature hourly increase/decrease: ", join(".", $1, $2), "\n";

  $cell[2][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current humidity: ", join(".", $1, $2), "\n";
  $w{HumidOutdoor} = join(".", $1, $2);
  $w{HumidOutdoorMeasured}=1; # tell Weather_Common that we directly measured humidity

  #$cell[2][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Min humidity: ", join(".", $1, $2), "\% at ", "$3:$4 $5\n";
  #print "Max humidity: ", join(".", $6, $7), "\% at ", "$8:$9 $10\n";

  # Currently no way to determine if increasing or decreasing.
  # Need to parse image name at the end of this cell to get it.
  #$cell[2][3] =~ m/\s+(\d+).(\d+)/;
  #print "Humidity hourly increase/decrease: ", join(".", $1, $2), "\n";

  $cell[3][1] =~ m/(\w+) at\s+(\d+).(\d+)/;
  #print "Current wind direction: $1, Speed: ", join(".", $2, $3), "\n";
  #$w{WindAvgDir} = $1;
  my $newdirection = $1;
  $w{WindAvgSpeed} = join(".", $2, $3);
  $w{WindAvgDir} = convert_wind_dir_abbr_to_num($newdirection);

  $cell[3][2] =~ m/\s+(\w+)\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Max wind direction: $1, Speed: ", join(".", $2, $3), " at $4:$5 $6\n";
  my $newgustdir = $1;
  my $newgusttime = "$4:$5 $6";
  if ($Weather{WindGustTime} ne $newgusttime) {
    $w{WindGustSpeed} = join(".", $2, $3);
    $w{WindGustDir} = convert_wind_dir_abbr_to_num($newgustdir);
    $w{WindGustTime} = $newgusttime;
  }
  else {
    $w{WindGustSpeed} = $w{WindAvgSpeed};
    $w{WindGustDir} = $w{WindAvgDir};
  }

  $cell[4][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current rain: ", join(".", $1, $2), "\n";
  $w{RainTotal} = join(".", $1, $2) unless $config_parms{aws_ignore_rain};

	# *** Set IsRaining here


  # Don't know how to parse this until it rains and we get some data.
  #$cell[4][2] =~ m/\s+(\d+).(\d+)\s+\"\/h\s+at\s+(\d+):(\d+)(\D+)/
  #print "Rain max of ", join("." $1, $2), " at ", join(":", $2, $3), $4, "\n" unless $config_parms{aws_ignore_rain};


  $cell[4][3] =~ m/\s+(\d+).(\d+)/;
  #print "Rain hourly increase/decrease: ", join(".", $1, $2), "\n";
  $w{RainRate} = join(".", $1, $2) unless $config_parms{aws_ignore_rain};

  $cell[5][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current pressure: ", join(".", $1, $2), "in Hg\n";
  $w{BaromSea} = join(".", $1, $2);
  $w{Barom}=convert_sea_barom_to_local_in($w{BaromSea});

  #$cell[5][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Max pressure: ", join(".", $1, $2), "in Hg at ", "$3:$4 $5\n";
  #print "Min pressure: ", join(".", $6, $7), "in Hg at ", "$8:$9 $10\n";

  #$cell[5][3] =~ m/\s+(\d+).(\d+)/;
  #print "Pressure hourly increase/decrease: ", join(".", $1, $2), "\n";

  # *** Set rising/falling

  $cell[6][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current light: ", join(".", $1, $2), "\%\n";
  $w{sun_sensor} = join(".", $1, $2);

  # *** Set conditions

  #$cell[6][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Max light: ", join(".", $1, $2), "\% at ", "$3:$4 $5\n";
  #print "Min light: ", join(".", $6, $7), "\% at ", "$8:$9 $10\n";

  #$cell[6][3] =~ m/\s+(\d+).(\d+)/;
  #print "Light hourly increase/decrease: ", join(".", $1, $2), "\n";

  #$cell[7][0] =~ m/\n\s+\w+ \w+\n\n\s+(\d+).(\d+) /;
  $cell[7][0] =~ m/(-?\d+).(\d+) /;
  # heat index/wind chill
  #print "Heat index: ", join(".", $1, $2), "°F\n";

  # wind chill is now calculated by Weather_Common using a modern formula
  #$w{WindChill} = join(".", $1, $2);

  #$cell[7][1] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
  #print "Monthly rain: ", join(".", $1, $2), "in\n";

  $cell[7][2] =~ m/\s\w+ \w+\s+(-?\d+).(\d+) /;
  #print "Dew point: ", join(".", $1, $2), "°F\n";
  $w{DewOutdoor} = join(".", $1, $2);

  #$cell[7][3] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
  #print "Wet bulb: ", join(".", $1, $2), "°F\n";

  if ($config_parms{weather_uom_temp} eq 'C') {
  	grep {$w{$_}=convert_f2c($w{$_});} qw(
  	  TempOutdoor
  	  DewOutdoor
  	);
  }
  if ($config_parms{weather_uom_baro} eq 'mb') {
  	grep {$w{$_}=convert_in2mb($w{$_});} qw(
  	  Barom
  	  BaromSea
  	);
  }
  if ($config_parms{weather_uom_wind} eq 'kph') {
  	grep {$w{$_}=convert_mile2km($w{$_});} qw(
  	  WindGustSpeed
  	  WindAvgSpeed
  	);
  }
  if ($config_parms{weather_uom_wind} eq 'm/s') {
  	grep {$w{$_}=convert_mph2mps($w{$_});} qw(
  	  WindGustSpeed
  	  WindAvgSpeed
  	);
  }

  &populate_internet_weather(\%w, $config_parms{weather_internet_elements_aws});
  &weather_updated;
  if ($Debug{weather}) {
  	foreach my $key (sort(keys(%w))) {
  		&print_log("weather_aws: $key is ".$w{$key});
    }
  }
  &print_log("weather_aws: finished retrieving weather for station $AWS_IDs[$AWS_ID_index]");
  $v_get_aws_weather->respond('app=weather connected=0 Weather data retrieved.');

}