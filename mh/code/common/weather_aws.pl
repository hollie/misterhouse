# Category=Weather

#@ This code will retrieve and parse data from an AWS weather station via
#@ their website.
#@
#@ Check <a href="http://www.instaweather.com">http://www.instaweather.com</a>
#@ for the nearest site's station id
#@ then add the id to the aws_id config parameter in your mh.ini or 
#@ mh.private.ini:<br><br>
#@ 
#@ aws_id = TMISC 
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


my $AWS_ID = $config_parms{aws_id};
my $f_awsweather_html = "$config_parms{data_dir}/web/$AWS_ID.html";
my $prev_timestamp;

# noloop=start
#y $AWSWeatherURL="http://aws.com/full.asp?id=$AWS_ID";
my $AWSWeatherURL="http://www.aws.com/AWS/full.asp?id=$AWS_ID";
# noloop=stop

$p_awsweather_page = new Process_Item("get_url -quiet \"$AWSWeatherURL\" \"$f_awsweather_html\"");


# These values aren't provided by this code, but leaving them undefined causes 
# problems with logging. Leave them commented out if you have external code to 
# fill them with usefull data.
#$Weather{TempIndoor}  = 0.00; 
#$Weather{HumidIndoor} = 0.00; 


sub convert_simple_direction {
 my ($dir) = @_;
    return 'NA' if $dir !~ /^[\d \.]+$/;
    return 'N'  if $dir <  30 or $dir >= 330;
    return 'NE' if $dir <  60;
    return 'E'  if $dir < 120;
    return 'SE' if $dir < 150;
    return 'S'  if $dir < 210;
    return 'SW' if $dir < 240;
    return 'W'  if $dir < 300;
    return 'NW' if $dir < 330;
    return 'NA';
}

sub convert_to_degrees {
  my ($temp) = @_;
  $temp =~ s/NE/45/g;
  $temp =~ s/NNE/23/g;
  $temp =~ s/NNW/338/g;
  $temp =~ s/SE/135/g;
  $temp =~ s/SW/225/g;
  $temp =~ s/NW/315/g;
  $temp =~ s/SSE/158/g;
  $temp =~ s/SSW/203/g;
  $temp =~ s/WNW/293/g;
  $temp =~ s/ESE/113/g;
  $temp =~ s/ENE/68/g;
  $temp =~ s/S/180/g;
  $temp =~ s/W/270/g;
  $temp =~ s/E/90/g;
  $temp =~ s/N/0/g;
  return $temp;
}

$v_get_aws_weather = new  Voice_Cmd('Get AWS weather data');

# Do this every five minutes
if (($New_Minute and !($Minute % 5)) or said $v_get_aws_weather) {

   if (&net_connect_check) {
       print_log "Retrieving $AWS_ID weather...";
       # Use start instead of run so we can detect when it is done
       start $p_awsweather_page;
   }
   else {
       speak "Sorry, you must be logged onto the net to get weather data.";
   }
}

# This would be far more efficient if AWS allowed access to 
# their SQL db. Might be time for a little reverse engineering...
if (done_now $p_awsweather_page) {

  my $html = file_read $f_awsweather_html;
  return unless $html; 

#  my $te = new HTML::TableExtract( depth => 1, count => 1, subtables => 1);
  my $te = new HTML::TableExtract( depth => 2, count => 1, subtables => 1);

  $te->parse($html);

  my @cell = $te->rows;


  # Timestamp of last sucessfull data retrieval from internet node
  $cell[0][0] =~ m/\s+(\d+)\/(\d+)\/(\d+) - (\d+):(\d+):(\d+) (\w+)/;
  my $timestamp = "$1$2$3$4$5$6$7";
  return unless $timestamp and $timestamp ne $prev_timestamp;
  $prev_timestamp = $timestamp;
  #print "Timestamp of last sucessfull data retrieval: $1\/$2\/$3 $4:$5:$6 $7\n";

  $cell[1][1] =~ m/\s+(-?\d+).(\d+)/;
  #print "Current temperature: ", join(".", $1, $2), "°F\n";
  $Weather{TempOutdoor} = join(".", $1, $2);

  #$cell[1][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Min temp: ", join(".", $1, $2), "°F at ", "$3:$4 $5\n";
  #print "Max temp: ", join(".", $6, $7), "°F at ", "$8:$9 $10\n";

  # Currently no way to determine if increasing or decreasing.
  # Need to parse image name at the end of this cell to get it.
  #$cell[1][3] =~ m/\s+(\d+).(\d+)/;
  #print "Temperature hourly increase/decrease: ", join(".", $1, $2), "\n";

  $cell[2][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current humidity: ", join(".", $1, $2), "\n";
  $Weather{HumidOutdoor} = join(".", $1, $2);

  #$cell[2][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Min humidity: ", join(".", $1, $2), "\% at ", "$3:$4 $5\n";
  #print "Max humidity: ", join(".", $6, $7), "\% at ", "$8:$9 $10\n";

  # Currently no way to determine if increasing or decreasing.
  # Need to parse image name at the end of this cell to get it.
  #$cell[2][3] =~ m/\s+(\d+).(\d+)/;
  #print "Humidity hourly increase/decrease: ", join(".", $1, $2), "\n";

  $cell[3][1] =~ m/(\w+) at\s+(\d+).(\d+)/;
  #print "Current wind direction: $1, Speed: ", join(".", $2, $3), "\n";
  #$Weather{WindAvgDir} = $1;
  my $newdirection = $1;
  $Weather{WindAvgSpeed} = join(".", $2, $3);
  $Weather{WindAvgDir} = convert_to_degrees($newdirection);

  $cell[3][2] =~ m/\s+(\w+)\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Max wind direction: $1, Speed: ", join(".", $2, $3), " at $4:$5 $6\n";
  my $newgustdir = $1;
  my $newgusttime = "$4:$5 $6";
  if ($Weather{WindGustTime} ne $newgusttime) {
    $Weather{WindGustSpeed} = join(".", $2, $3);
    $Weather{WindGustDir} = convert_to_degrees($newgustdir);
    $Weather{WindGustTime} = $newgusttime;
  }
  else {
    $Weather{WindGustSpeed} = 0 if $Weather{WindGustSpeed};
  }

  $cell[4][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current rain: ", join(".", $1, $2), "\n";
  $Weather{RainTotal} = join(".", $1, $2) unless $config_parms{aws_ignore_rain};

  # Don't know how to parse this until it rains and we get some data.
  #$cell[4][2] =~ m/\s+(\d+).(\d+)\s+\"\/h\s+at\s+(\d+):(\d+)(\D+)/
  #print "Rain max of ", join("." $1, $2), " at ", join(":", $2, $3), $4, "\n" unless $config_parms{aws_ignore_rain};
  

  $cell[4][3] =~ m/\s+(\d+).(\d+)/;
  #print "Rain hourly increase/decrease: ", join(".", $1, $2), "\n";
  $Weather{RainRate} = join(".", $1, $2) unless $config_parms{aws_ignore_rain};

  $cell[5][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current pressure: ", join(".", $1, $2), "in Hg\n";
  $Weather{Barom} = join(".", $1, $2);

  #$cell[5][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Max pressure: ", join(".", $1, $2), "in Hg at ", "$3:$4 $5\n";
  #print "Min pressure: ", join(".", $6, $7), "in Hg at ", "$8:$9 $10\n";

  #$cell[5][3] =~ m/\s+(\d+).(\d+)/;
  #print "Pressure hourly increase/decrease: ", join(".", $1, $2), "\n";


  $cell[6][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current light: ", join(".", $1, $2), "\%\n";
  $Weather{sun_sensor} = join(".", $1, $2);

  #$cell[6][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Max light: ", join(".", $1, $2), "\% at ", "$3:$4 $5\n";
  #print "Min light: ", join(".", $6, $7), "\% at ", "$8:$9 $10\n";

  #$cell[6][3] =~ m/\s+(\d+).(\d+)/;
  #print "Light hourly increase/decrease: ", join(".", $1, $2), "\n";

  #$cell[7][0] =~ m/\n\s+\w+ \w+\n\n\s+(\d+).(\d+) /;
  $cell[7][0] =~ m/(-?\d+).(\d+) /;
  # heat index/wind chill
  #print "Heat index: ", join(".", $1, $2), "°F\n";
  $Weather{WindChill} = join(".", $1, $2);

  #$cell[7][1] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
  #print "Monthly rain: ", join(".", $1, $2), "in\n";

  $cell[7][2] =~ m/\s\w+ \w+\s+(-?\d+).(\d+) /;
  #print "Dew point: ", join(".", $1, $2), "°F\n";
  $Weather{DewOutdoor} = join(".", $1, $2);

  #$cell[7][3] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
  #print "Wet bulb: ", join(".", $1, $2), "°F\n";


  # Update the summary info for the web page
# $Weather{Summary_Short}= sprintf("%4.1f/%2d/%2d %3d%% %3d%%", 
  $Weather{Summary_Short}= sprintf("%3.1f/%3d/%3d %3d%% %3d%%", 
                                    $Weather{TempIndoor}, 
                                    $Weather{TempOutdoor}, 
                                    $Weather{WindChill},
                                    $Weather{HumidIndoor}, 
                                    $Weather{HumidOutdoor});
  $Weather{Wind} = " $Weather{WindAvgSpeed}/$Weather{WindGustSpeed} " .
                      convert_simple_direction($Weather{WindAvgDir});

}
