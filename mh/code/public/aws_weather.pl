# Category=Weather

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
# Check http://www.instaweather.com for the nearest site's station id
# then add the id to the aws_id global in your mh.ini
# ex. aws_id=TMISC
#
# Credit to Ernie Oporto who's weather.pl was hacked apart 
# to start this program (although little of it remains ;)

# brudy@praecogito.com
# September 7, 2000


#You need to have HTML::TableExtract installed to use these programs. 

#Under Windows, to add HTML::TableExtract to your site Perl, do the following:
#
# cd \perl\bin (modify to match your directory)
# ppm install HTML-TableExtract
#
#If using *NIX do the following:
#
# >su root 
# >perl -MCPAN -eshell 
# cpan> install HTML::TableExtract
#



my $AWS_ID = $config_parms{aws_id};

# noloop=start
my $AWSWeatherURL="http://www.instaweather.com/full.asp?id=$AWS_ID";
# noloop=stop

my $AWSWeatherFile=$AWS_ID;
my $f_awsweather_html = "$config_parms{data_dir}/web/$AWSWeatherFile.html";
$p_awsweather_page = new Process_Item("get_url \"$AWSWeatherURL\" \"$f_awsweather_html\"");
$v_awsweather_page = new  Voice_Cmd('[Get] A W S weather');
$v_awsweather_page-> set_info("Live local weather via an AWS station");

if (said $v_awsweather_page eq 'Get') {

    if (&net_connect_check) {
    print_log "Retrieving $AWSWeatherFile weather...";

    # Use start instead of run so we can detect when it is done
    start $p_awsweather_page;
    }
    else {
        speak "Sorry, you must be logged onto the net";
     }
                
}

    
if (done_now $p_awsweather_page) {
    my $html = file_read $f_awsweather_html;

 use HTML::TableExtract;

 my $html = file_read $f_awsweather_html;
 my $te = new HTML::TableExtract( depth => 1, count => 1, subtables => 1);

 $te->parse($html);

 my @cell = $te->rows;

 # Timestamp of last sucessfull data retrieval from internet node
# print "Unmodified: $cell[0][0]\n";
 $cell[0][0] =~ m/\s+(\d+)\/(\d+)\/(\d+) - (\d+):(\d+):(\d+) (\w+)/;
 print "Timestamp of last sucessfull data retrieval\n$1\/$2\/$3\n";
 print "$4:$5:$6 $7\n";

# print "Unmodified: $cell[1][1]\n";
 $cell[1][1] =~ m/\s+(\d+).(\d+)/;
 print "Current temperature: ", join(".", $1, $2), "°F\n";

# print "Unmodified: $cell[1][2]\n";
 $cell[1][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
 print "Min temp: ", join(".", $1, $2), "°F at ", "$3:$4 $5\n";
 print "Max temp: ", join(".", $6, $7), "°F at ", "$8:$9 $10\n";

 # Currently no way to determine if increasing or decreasing.
 # Need to parse image name at the end of this cell to get it.
# print "Unmodified: $cell[1][3]\n";
 $cell[1][3] =~ m/\s+(\d+).(\d+)/; 
 print "Temperature hourly increase/decrease: ", join(".", $1, $2), "\n";

# print "Unmodified: $cell[2][1]\n";
 $cell[2][1] =~ m/\s+(\d+).(\d+)/;
 print "Current humidity: ", join(".", $1, $2), "\n";

# print "Unmodified: $cell[2][2]\n";
 $cell[2][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
 print "Min humidity: ", join(".", $1, $2), "\% at ", "$3:$4 $5\n"; 
 print "Max humidity: ", join(".", $6, $7), "\% at ", "$8:$9 $10\n";
 
 # Currently no way to determine if increasing or decreasing. 
 # Need to parse image name at the end of this cell to get it.
# print "Unmodified: $cell[2][3]\n";
 $cell[2][3] =~ m/\s+(\d+).(\d+)/;
 print "Humidity hourly increase/decrease: ", join(".", $1, $2), "\n";
 
# print "Unmodified: $cell[3][1]\n";
 $cell[3][1] =~ m/\s+(\w+) at\s+(\d+).(\d+)/;
 print "Current wind direction: $1, Speed: ", join(".", $2, $3), "\n";  

# print "Unmodified: $cell[3][2]\n";
 $cell[3][2] =~ m/\s+(\w+)\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
 print "Max wind direction: $1, Speed: ", join(".", $2, $3), " at $4:$5 $6\n";

# print "Unmodified: $cell[4][1]\n";
 $cell[4][1] =~ m/\s+(\d+).(\d+)/;
 print "Current rain: ", join(".", $1, $2), "\n";


 # Don't know how to parse this until it rains and we get some data.
# print "Unmodified: $cell[4][2]\n";


# print "Unmodified: $cell[4][3]\n";
 $cell[4][3] =~ m/\s+(\d+).(\d+)/;
 print "Rain hourly increase/decrease: ", join(".", $1, $2), "\n";

# print "Unmodified: $cell[5][1]\n";
 $cell[5][1] =~ m/\s+(\d+).(\d+)/;
 print "Current pressure: ", join(".", $1, $2), "in Hg\n";

# print "Unmodified: $cell[5][2]\n"; 
 $cell[5][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
 print "Max pressure: ", join(".", $1, $2), "in Hg at ", "$3:$4 $5\n"; 
 print "Min pressure: ", join(".", $6, $7), "in Hg at ", "$8:$9 $10\n";

# print "Unmodified: $cell[5][3]\n";
 $cell[5][3] =~ m/\s+(\d+).(\d+)/;
 print "Pressure hourly increase/decrease: ", join(".", $1, $2), "\n";


# print "Unmodified: $cell[6][1]\n";
 $cell[6][1] =~ m/\s+(\d+).(\d+)/;
 print "Current light: ", join(".", $1, $2), "\%\n";

# print "Unmodified: $cell[6][2]\n";
 $cell[6][2] =~ m/\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
 print "Max light: ", join(".", $1, $2), "\% at ", "$3:$4 $5\n"; 
 print "Min light: ", join(".", $6, $7), "\% at ", "$8:$9 $10\n";

# print "Unmodified: $cell[6][3]\n";
 $cell[6][3] =~ m/\s+(\d+).(\d+)/;
 print "Light hourly increase/decrease: ", join(".", $1, $2), "\n";

# print "Unmodified: $cell[7][0]\n";
  $cell[7][0] =~ m/\n\s+\w+ \w+\n\n\s+(\d+).(\d+) /;
  print "Heat index: ", join(".", $1, $2), "°F\n";

# print "Unmodified: $cell[7][1]\n";
  $cell[7][1] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
  print "Monthly rain: ", join(".", $1, $2), "in\n";

# print "Unmodified: $cell[7][2]\n";
  $cell[7][2] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
  print "Dew point: ", join(".", $1, $2), "°F\n";

# print "Unmodified: $cell[7][3]\n";
  $cell[7][3] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
  print "Wet bulb: ", join(".", $1, $2), "°F\n";



 # Uncomment the following to get a raw printout of the captured data
 # with cell index values. Should be handy to fix the string matching if 
 # they change the formatting of the cells someday...
 #
 # For some silly reason tracking indexes with loop variables isn't
 # working properly, so $indexi and $indexj are required.

# my $indexi=0; 
# foreach my $row ($te->rows) {
#    my $indexj=0; 
#     foreach my $i (@$row) { 
#            print "Index: $indexi,$indexj: $i\n";
#            $indexj++;
#    }
#   $indexi++;
# }



}
