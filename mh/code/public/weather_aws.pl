# Category=Weather

#package Weather_aws;

# This code will retrieve and parse data from an
# AWS weather station. It stores the results in the
# %Weather hash arry.
#
# Get live weather data from a nearby AWS site for those not lucky enough
# to have an attached weather sensor array. TMISC is a mile from my house,
# so this works out well for me.
#
# Most AWS sites are schools and non profit organizations like museums.
# Most sites upload their data in real time to AWS whenever a request is
# made via a remote site. Some only update their sensor data when their
# internet connection is up (usually during the school day).
#
# If you need real-time data, you should check the 'staleness' of the
# timestamp on the returned data to make sure it's current.
#
# You need to have HTML::TableExtract installed to use this program. 
#
# If using Unix do the following:
#
# >su root 
# >perl -MCPAN -eshell 
# cpan> install HTML::TableExtract
#
# Check http://www.instaweather.com for the nearest site's station id
# then add the id to the aws_id global in your mh.ini
# ex. aws_id=TMISC 
#
#
#
# Brian Rudy
# brudy@praecogito.com
# December 13, 2000
#
# Version 1.1      April 13, 2002
# Updated table depth per Ron Wright's suggestion.
#
# Version 1.0      December 13, 2000
# Complete re-write supporting MH 2.36's Weather_Item, and 
# Bruce's weather_log.pl, and weather_monitor.pl.
# Added hooks to use as library. 
#
# Version 0.2      September 20, 2000
# Updated $AWSWeatherURL to reflect change on AWS's web site.
#
# Version 0.1      September 14, 2000
# Yea, it works!
#
####################################################




my $AWS_ID = $config_parms{aws_id};
my $AWSWeatherFile=$AWS_ID;
my $f_awsweather_html = "$config_parms{data_dir}/web/$AWSWeatherFile.html";

# noloop=start
#my $AWSWeatherURL="http://www.aws.com/full.asp?id=$AWS_ID";
my $AWSWeatherURL="http://aws.com/full.asp?id=$AWS_ID";
# noloop=stop

$p_awsweather_page = new Process_Item("get_url \"$AWSWeatherURL\" \"$f_awsweather_html\"");


# These values aren't provided by this code, but leaving them 
# undefined causes problems with logging. Comment them out
# if you have external code to fill them with usefull data.
#$main::Weather{TempIndoor} = 0; 
$main::Weather{HumidIndoor} = 0; 



# Do this every five minutes
if (time_cron '0,5,10,15,20,25,30,35,40,45,50,55 * * * *') {

   # Comment this out if you don't have an indoor iButton temp sensor
   $main::Weather{TempIndoor} = read_temp $ib_temp1;

   if (&net_connect_check) {
       print_log "Retrieving $AWSWeatherFile weather...";
       # Use start instead of run so we can detect when it is done
       start $p_awsweather_page;
   }
   else {
       speak "Sorry, you must be logged onto the net";
   }
}


# This would be far more efficient if AWS allowed access to 
# their SQL db. Might be time for a little reverse engineering...
if (done_now $p_awsweather_page) {

  my $html = file_read $f_awsweather_html;

  use HTML::TableExtract;

#  my $te = new HTML::TableExtract( depth => 1, count => 1, subtables => 1);
  my $te = new HTML::TableExtract( depth => 2, count => 1, subtables => 1);

  $te->parse($html);

  my @cell = $te->rows;



  # Timestamp of last sucessfull data retrieval from internet node
  #$cell[0][0] =~ m/\s+(\d+)\/(\d+)\/(\d+) - (\d+):(\d+):(\d+) (\w+)/;
  #print "Timestamp of last sucessfull data retrieval\n$1\/$2\/$3\n";
  #print "$4:$5:$6 $7\n";

  $cell[1][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current temperature: ", join(".", $1, $2), "°F\n";
  $main::Weather{TempOutdoor} = join(".", $1, $2);

  #$cell[1][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Min temp: ", join(".", $1, $2), "°F at ", "$3:$4 $5\n";
  #print "Max temp: ", join(".", $6, $7), "°F at ", "$8:$9 $10\n";

  # Currently no way to determine if increasing or decreasing.
  # Need to parse image name at the end of this cell to get it.
  #$cell[1][3] =~ m/\s+(\d+).(\d+)/;
  #print "Temperature hourly increase/decrease: ", join(".", $1, $2), "\n";

  $cell[2][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current humidity: ", join(".", $1, $2), "\n";
  $main::Weather{HumidOutdoor} = join(".", $1, $2);

  #$cell[2][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Min humidity: ", join(".", $1, $2), "\% at ", "$3:$4 $5\n";
  #print "Max humidity: ", join(".", $6, $7), "\% at ", "$8:$9 $10\n";

  # Currently no way to determine if increasing or decreasing.
  # Need to parse image name at the end of this cell to get it.
  #$cell[2][3] =~ m/\s+(\d+).(\d+)/;
  #print "Humidity hourly increase/decrease: ", join(".", $1, $2), "\n";

  $cell[3][1] =~ m/\s+(\w+) at\s+(\d+).(\d+)/;
  #print "Current wind direction: $1, Speed: ", join(".", $2, $3), "\n";
  $main::Weather{WindAvgDir} = $1;
  $main::Weather{WindAvgSpeed} = join(".", $2, $3);

  $cell[3][2] =~ m/\s+(\w+)\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Max wind direction: $1, Speed: ", join(".", $2, $3), " at $4:$5 $6\n";
  $main::Weather{WindGustDir} = $1;
  $main::Weather{WindGustSpeed} = join(".", $2, $3);

  $cell[4][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current rain: ", join(".", $1, $2), "\n";
  $main::Weather{RainTotal} = join(".", $1, $2);

  # Don't know how to parse this until it rains and we get some data.
  #$cell[4][2] =~ m/\s+(\d+).(\d+)\s+\"\/h\s+at\s+(\d+):(\d+)(\D+)/
  #print "Rain max of ", join("." $1, $2), " at ", join(":", $2, $3), $4, "\n";
  

  $cell[4][3] =~ m/\s+(\d+).(\d+)/;
  #print "Rain hourly increase/decrease: ", join(".", $1, $2), "\n";
  $main::Weather{RainRate} = join(".", $1, $2);

  $cell[5][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current pressure: ", join(".", $1, $2), "in Hg\n";
  $main::Weather{Barom} = join(".", $1, $2);

  #$cell[5][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Max pressure: ", join(".", $1, $2), "in Hg at ", "$3:$4 $5\n";
  #print "Min pressure: ", join(".", $6, $7), "in Hg at ", "$8:$9 $10\n";

  #$cell[5][3] =~ m/\s+(\d+).(\d+)/;
  #print "Pressure hourly increase/decrease: ", join(".", $1, $2), "\n";


  $cell[6][1] =~ m/\s+(\d+).(\d+)/;
  #print "Current light: ", join(".", $1, $2), "\%\n";
  $main::Weather{sun_sensor} = join(".", $1, $2);

  #$cell[6][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
  #print "Max light: ", join(".", $1, $2), "\% at ", "$3:$4 $5\n";
  #print "Min light: ", join(".", $6, $7), "\% at ", "$8:$9 $10\n";

  #$cell[6][3] =~ m/\s+(\d+).(\d+)/;
  #print "Light hourly increase/decrease: ", join(".", $1, $2), "\n";

  $cell[7][0] =~ m/\n\s+\w+ \w+\n\n\s+(\d+).(\d+) /;
  # heat index/wind chill
  #print "Heat index: ", join(".", $1, $2), "°F\n";
  $main::Weather{WindChill} = join(".", $1, $2);

  #$cell[7][1] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
  #print "Monthly rain: ", join(".", $1, $2), "in\n";

  $cell[7][2] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
  #print "Dew point: ", join(".", $1, $2), "°F\n";
  $main::Weather{DewOutdoor} = join(".", $1, $2);

  #$cell[7][3] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
  #print "Wet bulb: ", join(".", $1, $2), "°F\n";


  # Some stuff from weather_vw.pl
  my $raintotal_prev = $main::Weather{RainTotal};

  $main::Weather{RainRecent} = ::round(($main::Weather{RainTotal} - $raintotal_prev), 2) if $raintotal_prev > 0;

  if ($main::Weather{RainRecent} > 0) {
      #speak "Notice, it just rained $main::Weather{RainRecent} inches";
      $main::Weather{IsRaining}++;
  }
  elsif ($main::Minute % 20){   
      # Reset every 20 minutes
      $main::Weather{IsRaining} = 0;
  }


}

#1;


