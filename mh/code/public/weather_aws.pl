####################################################
#
# weather_aws.pl
#
# This function will retrieve and parse data from an 
# AWS weather station. It stores the results in the 
# specified hash arry.
#
# Example usage:
#    
#  #Download HTML
#  &retrieve_AWS();
#
#  #Parse weather data
#  &read_AWS($data, \%weather, $debug);
#
# A complete usage example in:
# weather_monitor_aws.pl
#
# Use these mh.ini parms
#  aws_id=TMISC
#
# See weather_monitor_aws.pl for more details on the
# aws_id, and how to find your nearest monitoring station.
#
# Credit to Ernie Oporto, and Bruce Winter who's weather.pl, and 
# weather_monitor.pl as well as weather_wx200.pl, were merged to 
# create this script.
#
# Brian Rudy 
# brudy@praecogito.com
# September 14, 2000
#
# Version 0.1 September 14, 2000
# Yea, it works!
#
####################################################


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

# Category=Weather

                                # Parse wx200 datastream into array pointed at with $wptr
                                # Lots of good info on the WX200 from:  http://wx200.planetfall.com/

                                # Set up array of data types, including group index,
                                # group name, length of data, and relevant subroutine 
my %wx_datatype = (0x8f => ['humid', 35, \&wx_humid],
                   0x9f => ['temp',  34, \&wx_temp],
                   0xaf => ['barom', 31, \&wx_baro],
                   0xbf => ['rain',  14, \&wx_rain],
                   0xcf => ['wind',  27, \&wx_wind]);

my @cell;  
my $AWS_ID = $config_parms{aws_id};
my $AWSWeatherFile=$AWS_ID;
my $f_awsweather_html = "$config_parms{data_dir}/web/$AWSWeatherFile.html";

# noloop=start
my $AWSWeatherURL="http://www.instaweather.com/full.asp?id=$AWS_ID"; 
# noloop=stop

$p_awsweather_page = new Process_Item("get_url \"$AWSWeatherURL\" \"$f_awsweather_html\"");


# This sub gives $p_awsweather_page a chance to finish before read_AWS is invoked.
sub retrieve_AWS {

   if (&net_connect_check) {
       print_log "Retrieving $AWSWeatherFile weather...";
       # Use start instead of run so we can detect when it is done
       start $p_awsweather_page;
   }
   else {
       speak "Sorry, you must be logged onto the net";
   }
}



        
sub read_AWS {
    my ($data, $wptr, $debug) = @_;

    my @data = unpack('C*', $data);

#    print "done->", done $p_awsweather_page, "<-\n";
#    print "done_now->", $p_awsweather_page->done_now, "<-\n";
# This isn't working for some reason
#   if (done_now $p_awsweather_page) {
   if ((done $p_awsweather_page) > 0) {

    print_log "Parsing AWS data...";

    my $html = file_read $f_awsweather_html;

    use HTML::TableExtract;

    my $html = file_read $f_awsweather_html;
    my $te = new HTML::TableExtract( depth => 1, count => 1, subtables => 1);

    $te->parse($html);

    @cell = $te->rows;

#    my $group = $data[0];
#    my $dtp = $wx_datatype{$group};
#    my @data2 = splice(@data, 0, $$dtp[1]);

    # This is a bit kludgy, but I can't get Bruce's while loop working.
    wx_humid($wptr, $debug, $data);
    wx_temp($wptr, $debug, $data);
    wx_baro($wptr, $debug, $data);
    wx_rain($wptr, $debug, $data);
    wx_wind($wptr, $debug, $data);

#    while (@data) {
#        my $group = $data[0];
#        my $dtp = $wx_datatype{$group};
#
#                                # Check for valid datatype
#        unless ($dtp) {
#            my $length = @data;
#            printf("Bad weather data.  group=%x length=$length\n", $group);
#            return; 
#        }
#                         # If we don't have enough data, return what is left for next pass
#        if ($$dtp[1] > @data) {
#            return pack('C*', @data);
#        }
#
                                # Pull out the number of bytes needed for this data type
#        my @data2 = splice(@data, 0, $$dtp[1]);
#
                                # Check the checksum
#        my $checksum1 = pop @data2;
#        my $checksum2 = 0;
#        for (@data2) {
#            $checksum2 += $_;
#        }
#        $checksum2 &= 0xff;     # Checksum is lower 8 bits of the sum
#        if ($checksum1 != $checksum2) {
#            print "Warning, bad wx200 type=$$dtp[0] checksum: cs1=$checksum1 cs2=$checksum2\n";
#            next;
#        }
                                # Process the data
#         print "process data $$dtp[0], $$dtp[1]\n";
#         &{$$dtp[2]}($wptr, $debug, @data2);
#         &($wptr, $debug, @data2);

#     }

   }
}


sub wx_humid {
#    print "Starting wx_humid...\n";
    my ($wptr, $debug, @data) = @_;
#    $$wptr{HumidIndoor}  = sprintf('%x', $data[8]);
#    $$wptr{HumidOutdoor} = sprintf('%x', $data[20]);
    $cell[2][1] =~ m/\s+(\d+).(\d+)/;
     $$wptr{HumidOutdoor} = join(".", $1, $2);
#    print "humidity = $$wptr{HumidIndoor}, $$wptr{HumidOutdoor}\n" if $debug;
    print "humidity = $$wptr{HumidOutdoor}\n" if $debug;
#   $wx_counts{time}++;
}
#8F. 8	DD	all	Humid	Indoor:    10<ab<97 % @ 1
#8F.20	DD	all	Humid	Outdoor:    10<ab<97 % @ 1

sub wx_temp {
#    print "Starting wx_temp...\n";
    my ($wptr, $debug, @data) = @_;
#    $$wptr{TempIndoor}  = &wx_temp2(@data[1..2]);
#    $$wptr{TempOutdoor} = &wx_temp2(@data[16..17]);
    $cell[1][1] =~ m/\s+(\d+).(\d+)/;
    $$wptr{TempOutdoor} = join(".", $1, $2);

#    print "temp = $$wptr{TempIndoor}, $$wptr{TempOutdoor}\n"  if $debug;
    print "temp = $$wptr{TempOutdoor}\n"  if $debug;

    $$wptr{Summary_Short} = sprintf("%4.1f/%2d/%2d %3d%% %3d%%",
                              $$wptr{TempIndoor}, $$wptr{TempOutdoor}, $$wptr{WindChill},
                              $$wptr{HumidIndoor}, $$wptr{HumidOutdoor});
    $$wptr{Summary} = sprintf("In/out/chill: %4.1f/%2d/%2d Humid:%3d%% %3d%%",
                              $$wptr{TempIndoor}, $$wptr{TempOutdoor}, $$wptr{WindChill},
                              $$wptr{HumidIndoor}, $$wptr{HumidOutdoor});

#   $wx_counts{temp}++;
}
#9F. 1	DD	all	Temp	Indoor: 'bc' of 0<ab.c<50 degrees C @ 0.1
#9F. 2	-B	0-2	Temp	Indoor: 'a' of <ab.c> C
#9F. 2	-B	3	Temp	Indoor: Sign 0=+, 1=-
#9F.16	DD	all	Temp	Outdoor: 'bc' of -40<ab.c<60 degrees C @ 0.1
#9F.17	-B	0-2	Temp	Outdoor: 'a' of <ab.c> C
#9F.17	-B	3	Temp	Outdoor: Sign 0=+, 1=-

#sub wx_temp2 {
#    my ($n1, $n2) = @_;
#    my $temp   =  sprintf('%x%02x', 0x07 & $n2, $n1);
#    substr($temp, 2, 0) = '.';
#    $temp *= -1 if 0x08 & $n2;
#    $temp = &convert_c2f($temp);
#    return $temp;
#}

sub wx_baro {
#    print "Starting wx_baro...\n";
    my ($wptr, $debug, @data) = @_;
#    $$wptr{Barom}    = sprintf('%x%02x', $data[2], $data[1]);
    $cell[5][1] =~ m/\s+(\d+).(\d+)/;
    $$wptr{Barom}    = join(".", $1, $2);
#    $$wptr{BaromSea} = sprintf('%x%02x%02x', 0x0f & $data[5], $data[4], $data[3]);
#    substr($$wptr{BaromSea}, -1, 0) = '.';
#    $$wptr{DewIndoor}  =  &convert_c2f(sprintf('%x', $data[7]));
#    $$wptr{DewOutdoor} =  &convert_c2f(sprintf('%x', $data[18]));
   $cell[7][2] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
   $$wptr{DewOutdoor} = join(".", $1, $2);
#   print "baro = $$wptr{Barom}, $$wptr{BaromSea} dew=$$wptr{DewIndoor}, $$wptr{DewOutdoor}\n"  if $debug;
   print "baro = $$wptr{Barom} dew=$$wptr{DewOutdoor}\n"  if $debug;
#   $wx_counts{baro}++;
}
#AF. 1	DD	all	Barom	Local: 'cd' of 795<abcd<1050 mb @ 1
#AF. 2	DD	all	Barom	Local: 'ab' of <abcd> mb
#AF. 3	DD	all	Barom	SeaLevel: 'de' of 795<abcd.e<1050 mb @ .1
#AF. 4	DD	all	Barom	SeaLevel: 'bc' of <abcd.e> mb
#AF. 5	-D	all	Barom	SeaLevel: 'a' of <abcd.e> mb
#AF. 5	Bx	0,1	Barom	Format: 0=inches, 1=mm, 2=mb, 3=hpa
#AF. 7	DD	all	Dewpt	Indoor:    0<ab<47 degrees C @ 1
#AF.18	DD	all	Dewpt	Outdoor:    0<ab<56 degrees C @ 1

sub wx_rain {
#    print "Starting wx_rain...\n";
    my ($wptr, $debug, @data) = @_;
#    $$wptr{RainRate} = sprintf('%x%02x', 0x0f & $data[2], $data[1]);
    $cell[4][3] =~ m/\s+(\d+).(\d+)/;
    $$wptr{RainRate} = join(".", $1, $2);
#    $$wptr{RainYest} = sprintf('%x%02x',        $data[4], $data[3]);
#    $$wptr{RainTotal}= sprintf('%x%02x',        $data[6], $data[5]);
    $cell[7][1] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
    $$wptr{RainTotal}= join(".", $1, $2);
#    $$wptr{RainRate} = sprintf('%3.1f', $$wptr{RainRate} / 25.4);
#    $$wptr{RainYest} = sprintf('%3.1f', $$wptr{RainYest} / 25.4);
#    $$wptr{RainTotal}= sprintf('%3.1f', $$wptr{RainTotal}/ 25.4);
#    print "rain = $$wptr{RainRate}, $$wptr{RainYest}, $$wptr{RainTotal}\n"  if $debug;
    print "rain = $$wptr{RainRate}, $$wptr{RainTotal}\n"  if $debug;

    $$wptr{SummaryRain} = sprintf("Rain Recent/Total: %3.1f / %4.1f  Barom: %4d",
                                  $$wptr{RainYest}, $$wptr{RainTotal}, $$wptr{Barom});

#   print "rain=@data\n";
#   $wx_counts{rain}++;
}
#BF. 1	DD	all	Rain	Rate: 'bc' of 0<abc<998 mm/hr @ 1
#BF. 2	-D	all	Rain	Rate: 'a' of <abc> mm/hr
#BF. 2	Bx	all
#BF. 3	DD	all	Rain	Yesterday: 'cd' of 0<abcd<9999 mm @ 1
#BF. 4	DD	all	Rain	Yesterday: 'ab' of <abcd> mm
#BF. 5	DD	all	Rain	Total: 'cd' of <abcd> mm
#BF. 6	DD	all	Rain	Total: 'ab' of <abcd> mm


sub wx_wind {
#    print "Starting wx_wind...\n";
    my ($wptr, $debug, @data) = @_;
    my $tempvar;
#    $$wptr{WindGustSpeed} = sprintf('%x%02x', 0x0f & $data[2], $data[1]);
#    $$wptr{WindAvgSpeed}  = sprintf('%x%02x', 0x0f & $data[5], $data[4]);

#    substr($$wptr{WindGustSpeed}, -1, 0) = '.';
#    substr($$wptr{WindAvgSpeed}, -1, 0)  = '.';
                                # Convert from meters/sec to miles/hour  = 1609.3 / 3600
#    $$wptr{WindGustSpeed} = sprintf('%3d', $$wptr{WindGustSpeed} * 2.237);
#    $$wptr{WindAvgSpeed}  = sprintf('%3d', $$wptr{WindAvgSpeed}  * 2.237);
#    $$wptr{WindGustDir}   = sprintf('%x%01x', $data[3], $data[2] >> 4);
#    $$wptr{WindAvgDir}    = sprintf('%x%01x', $data[6], $data[5] >> 4);

    $cell[3][2] =~ m/\s+(\w+)\s+(\d+).(\d+) at\s+(\d+):(\d+)(\D+)\n/;
    $$wptr{WindGustSpeed} = join(".", $2, $3);
    $$wptr{WindGustDir}   = $1;
    $cell[3][1] =~ m/\s+(\w+) at\s+(\d+).(\d+)/;
    $$wptr{WindAvgSpeed}  = join(".", $2, $3);
    $$wptr{WindAvgDir}    = $1;

#    $$wptr{WindChill} = sprintf('%x', $data[16]);
#    $$wptr{WindChill} *= -1 if 0x20 & $data[21];
#    $$wptr{WindChill} = &convert_c2f($$wptr{WindChill});
    $cell[7][3] =~ m/\s\w+ \w+\s+(\d+).(\d+) /;
    $$wptr{WindChill} = join(".", $1, $2);

    $$wptr{SummaryWind} = sprintf("Wind avg/gust:%3d /%3d  from the %s",
                                  $$wptr{WindAvgSpeed}, $$wptr{WindGustSpeed}, convert_direction($$wptr{WindAvgDir}));

    print "wind = $$wptr{WindGustSpeed}, $$wptr{WindAvgSpeed}, $$wptr{WindGustDir}, $$wptr{WindAvgDir} chill=$$wptr{WindChill}\n"  if $debug;

#   print "wind=@data\n";
#   $wx_counts{wind}++;
}
#CF. 1	DD	all	Wind	Gust Speed: 'bc' of 0<ab.c<56 m/s @ 0.2
#CF. 2	-D	all	Wind	Gust Speed: 'a' of <ab.c> m/s
#CF. 2	Dx	all	Wind	Gust Dir:   'c' of 0<abc<359 degrees @ 1
#CF. 3	DD	all	Wind	Gust Dir:   'ab' of <abc>
#CF. 4	DD	all	Wind	Avg Speed:  'bc' of 0<ab.c<56 m/s @ 0.1
#CF. 5	-D	all	Wind	Avg Speed:  'a' of <ab.c> m/s
#CF. 5	Dx	all	Wind	Avg Dir:    'c' of <abc>
#CF. 6	DD	all	Wind	Avg Dir:    'ab' of <abc>
#CF.16	DD	all	Chill	Temp: -85<ab<60 degrees C @ 1
#CF.21	Bx	1	Chill	Temp: Sign 0=+, 1=-
