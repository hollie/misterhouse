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
# Credit to Ernie Oporto, and Bruce Winter who's weather.pl, and 
# weather_monitor.pl, respectively were merged to create this script.

# Brian Rudy
# brudy@praecogito.com
# September 14, 2000

# Version 0.1    September 14, 2000
#
# Yea, it works! First functional version, not released.
# Lots of left-over, unused code/variables.

# Version 0.2    September 18, 2000
# Added string replacement to make wind direction pronunciation intelligable.

#my %weather;                   # This is where all the current weather data is stored
use vars '%weather';            # use var so we can access from web files

                                # Add tk weather widgets
#&tk_label(\$weather{TempIndoor}, \$weather{TempOutdoor}, \$weather{WindChill},
#          \$weather{WindAvgSpeed}, \$weather{HumidOutdoor});
#&tk_label(\$weather{Summary});
#&tk_label(\$weather{SummaryWind});
#&tk_label(\$weather{SummaryRain});

                                # Set up pointers to random weather comments
$remark_on_humidity      = new File_Item("$config_parms{data_dir}/remarks/list_humid.txt");
$remark_on_temp_below_0  = new File_Item("$config_parms{data_dir}/remarks/list_temp_below_0.txt");
$remark_on_temp_below_20 = new File_Item("$config_parms{data_dir}/remarks/list_temp_below_20.txt");

$v_what_temp = new  Voice_Cmd('What is the [outside] temperature');
#$v_what_temp = new  Voice_Cmd('What is the [,inside,outside] temperature');
$v_what_temp-> set_info('Returns the humidity, temperature, and windchill, as measured by AWS weather station');

if ($state = said $v_what_temp) {

#   my $temp     = round($analog{temp_outside});
#   my $humidity = round($analog{humidity_outside});
    
    if (defined $weather{TempOutdoor} and $weather{TempOutdoor} ne 'unknown') {
        my $temp     = round($weather{TempOutdoor});
# Don't have a sensor for this yet.
#        my $temp_in  = round($weather{TempIndoor});
        my $windchill= round($weather{WindChill});
        my $humidity = round($weather{HumidOutdoor});
# Don't have a sensor for this yet.
#        my $humidity_in = round($weather{HumidIndoor});
        my ($remark, $text);

                                # Need a 'is raining' test here
        if ($humidity > 80 and $temp > 70) {
            $remark =  read_next $remark_on_humidity;
        }
        if ($windchill < 0) {
            $remark =  read_next $remark_on_temp_below_0;
        }
        if ($windchill < 20) {
            $remark =  read_next $remark_on_temp_below_20;
        }

        my $temp_out = " $temp degrees ";
        if ($temp < 50 and $windchill < $temp) {
            $temp_out .= " $windchill degree windchill outside";
        }
        else {
            $temp_out .= " $humidity percent humidity outside";
        }

#        if ($state eq 'inside') {
#            $text = "It is $temp_in degrees $humidity_in percent inside.";
#        }
#        elsif ($state eq 'outside') {
         if ($state eq 'outside') {
            $text = "It is $temp_out.";
        }
        else {
#            $text = "It is $temp_in degrees $humidity_in percent inside, $temp_out. $remark ";
            $text = "It is $temp_out outdoors. $remark ";
              
        }
#        speak "rooms=$request_temp->{room} $text";
         speak "$text";
    }
    else {
#        speak "rooms=$request_temp->{room} Sorry, no weather info";
        speak "Sorry, no weather info";
    }   
}

#$v_downstairs_humidity = new  Voice_Cmd('What is the downstairs humidity');
#$v_downstairs_humidity-> set_info('Returns the downstairs humidity, as measured by a weeder analog port');
#speak('The downstairs humidity is ' . state_now $humidity_inside . ' %') if said $v_downstairs_humidity;

$v_what_wind = new  Voice_Cmd('What is the wind speed');
$v_what_wind-> set_info('The wind speed is measured by an AWS weather station');
if (said $v_what_wind) {
    undef $temp;
    if ($weather{WindGustSpeed} == 0  and $weather{WindGustSpeed} == 0) {
        $temp .= "There is currently no wind.";  
    }
    else {

        $temp  .= "The winnd is gusting at " . 
            round($weather{WindGustSpeed}) . " miles per hour from the " . $weather{WindGustDir};
        $temp .= ".  Average speed is " . 
            round($weather{WindAvgSpeed}) . " miles per hour from the " . $weather{WindAvgDir} . ".";

        $temp =~ s/\s+N\./ north./g;
        $temp =~ s/\s+NE\./ northeast./g; 
        $temp =~ s/\s+NNE\./ north by northeast./g;
        $temp =~ s/\s+NNW\./ north by northwest./g;
        $temp =~ s/\s+E\./ east./g;
        $temp =~ s/\s+SE\./ southeast./g;
        $temp =~ s/\s+W\./ west./g;
        $temp =~ s/\s+SW\./ south west./g;
        $temp =~ s/\s+S\./ south./g;
        $temp =~ s/\s+NW\./ northwest./g;
        $temp =~ s/\s+SSE\./ south by southeast./g;
        $temp =~ s/\s+SSW\./ south by southwest./g;
    }
    speak $temp;
}

$v_what_rain = new  Voice_Cmd('How much rain have we had in the last ' .
                              '[hour,2 hours,6 hours,12 hours,day,2 days,3 days,4 days,5 days,6 days,week,2 weeks,3 weeks,month,' .
                              '2 months,3 months,4 months,6 months]');
$v_what_rain-> set_info('Rainfall, measured by the AWS weather station and logged by mh');
if (my $period = said $v_what_rain) {
    undef $temp;
    my $days;
    # Get last record from the day in question
    my ($number, $unit) = $period =~ /(\d*) ?(\S+)/;
    $number = 1 unless $number;
    
    if ($unit =~ /hour/) {
        $days = $number / 24;
    }
    elsif ($unit =~ /day/) {
        $days = $number;
    }
    elsif ($unit =~ /week/) {
        $days = $number * 7;
    }
    elsif ($unit =~ /month/) {
        $days = $number * 30;
    }
    else {
        print "\n\nError in weather_monitor.pl code. period=$period\n";
    }
#   print "db period=$period unit=$unit number=$number days=$days\n";
    
    my @temp = get_weather_record(time - $days*3600*24);

    if ($weather{RainTotal} eq 'unknown' or !defined $weather{RainTotal}) {
        $temp = "Sorry, I don't have current weather info on rainfall";
    }
    elsif (!@temp) {
        $temp = "Sorry, I don't have a log of the weather from $days days ago.\n";
    }
    else {
        my $rain_total_yesterday = $temp[21];
        my $rain_diff = $weather{RainTotal} - $rain_total_yesterday;
#   print "db rt_previous=$rain_total_yesterday rt_today=$weather{RainTotal} diff=$rain_diff\n";
        if ($rain_diff) {
            $temp  .= "We have had " .
                round($rain_diff, 2) . " inches of rain ";
        }
        else {
            $temp .= "No rain has fallen ";
        }
        if ($period eq 'day') {
            $temp .= 'in the last 24 hours';
        }
        else {
            $temp .= "in the last $period";
        }
    }
    speak $temp;
}

                                # This code gets archived weather data
sub get_weather_record {
    speak 'Sorry, not implemented yet';
}


                                # Read incoming data from AWS station 

#$wx200_port = new  Serial_Item(undef, undef, 'serial_wx200');
$timer_wind_gust = new Timer();

my $data;

$v_get_weather_data = new  Voice_Cmd('Get weather data');
$v_process_weather_data = new  Voice_Cmd('Process weather data');


# This is a work-around for #p_awsweather_page not returning done_now.
# It introduces an artificial one minute delay between HTML page retrieval and parsing.
if ((time_cron('0,5,10,15,20,25,30,35,40,45,50,55 * * * *')) or (said $v_get_weather_data)) {
#   my $bs = &retrieve_AWS();
   &retrieve_AWS();
}


if ((time_cron('1,6,11,16,21,26,31,36,41,46,51,56 * * * *')) or (said $v_process_weather_data)) {
#if (my $data = said $AWS_ID) {

                       # Process data, and reset incomplete data not processed this pass
    my $debug = 1 if $config_parms{debug} eq 'weather';
    my $remainder = &read_AWS($data, \%weather, $debug);
#    set_data $wx200_port $remainder if $remainder;

    my $raintotal_prev = 0;
                                # Note interesting weather events
    if ($weather{WindGustSpeed} > 12 and 
        not $Save{sleeping_parents}) {
        if ($weather{WindGustSpeed} > $Save{WindGustMax}) {
            $Save{WindGustMax} = $weather{WindGustSpeed};
            speak "rooms=all Weather alert.  The wind is now gusting at " . round($weather{WindGustSpeed}) . 
                " MPH.";
            set $timer_wind_gust 120*60;
        }
        elsif (inactive $timer_wind_gust) {
            set $timer_wind_gust 120*60;
            speak "rooms=all Weather alert.  A wind gust of " . round($weather{WindGustSpeed}) . 
                " MPH was just recorded.";
        }
    }
    $Save{WindGustMax} = 0 if $New_Day;
    
    $weather{RainRecent} = round(($weather{RainTotal} - $raintotal_prev), 2) if $raintotal_prev > 0;
    if ($weather{RainRecent} > 0) {
        speak "Notice, it just rained $weather{RainRecent} inches";
        $weather{IsRaining}++;
    }
    elsif ($Minute % 20) {  # Reset every 20 minutes
        $weather{IsRaining} = 0;
    }
#   print "Notice, 1 it just rained $weather{RainRecent} inches (total=$weather{RainTotal}).\n" if $weather{RainRecent} > 0;
#   print "Notice, 2 it just rained $weather{RainRate} inches\n" if $weather{RainRate};

}                             
