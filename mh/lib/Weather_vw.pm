use strict;

package Weather_vw;

# This code reads Virtual Weatherstation log data
# To use it, add these mh.ini parms
#   weather_vwlog_file=c:\vwweather\weather.log
#   weather_vwlog_module=Weather_vw

sub startup {
    &::MainLoop_pre_add_hook(  \&Weather_vw::UpdateVwWeather, 1 );
}

my @weather_vwtype = qw(Year Month Day Hour Minute Second
WindAvgSpeed WindGustSpeed WindAvgDir 
HumidIndoor HumidOutdoor
TempIndoor TempOutdoor
Barom
RainTotal
RainYest
RainRate
WeatherCondition);
my $timer_vwweather_date = new Timer();

sub UpdateVwWeather 
{
    return unless $main::New_Second and $main::Second == 30;

    my ($time) = time;
    my $tail;
    
    # 2000,6,7,23,58,9,0,0,357,35,84,77,53,28.00,0.28,0.00,0.00,0

    if($::New_Day)
    {
        $main::Weather{WindHighDir} = undef
        $main::Weather{WindHighSpeed} = undef;

        $main::Weather{HumidIndoorH} = undef;
        $main::Weather{HumidIndoorL} = undef;
        $main::Weather{HumidOutdoorH} = undef;
        $main::Weather{HumidOutdoorL} = undef;

        $main::Weather{TempIndoorH} = undef;
        $main::Weather{TempIndoorL} = undef;
        $main::Weather{TempOutdoorH} = undef;
        $main::Weather{TempOutdoorL} = undef;
    }

    # Read and parse data into %weather array
    my($min, $hour, $mday, $mon, $year) = (localtime($time))[1,2,3,4,5];
    my($wdate, $wyear, $wmonth, $wday, $whour, $wmin, $wsec);
    my $date = sprintf("%02d%02d%4d", 1+$mon, $mday, 1900 + $year);
    my $file = $main::config_parms{weather_vwlog_file};

    return unless -e $file;

    my @temp;
    open (SBDATA, $file) or print "Warning, could not open weather file $file: $!\n";
    for (<SBDATA>) 
    {
        @temp = split /,/;
    }

    if(@temp != 18)
    {
        print "Invalid data read from weather file $file\n";
        return;
    }


    # Check to see if weather data is current
    ($wyear, $wmonth, $wday, $whour, $wmin) = @temp;
    $wdate = sprintf("%02d%02d%4d", $wmonth, $wday, $wyear);

    my $time_diff = ($hour + $min/60) - ($whour + $wmin/60);
    
    # Make sure we have the right date, and if today, we are with an hour

    if (($date ne $wdate and $hour > 1) or ($time == time and $time_diff > 1)) 
    {
        if (inactive $timer_vwweather_date and (time - $main::Time_Startup_time) > 60 * 2 ) 
        {
            ::print_log "Weather data is not operational";
            set $timer_vwweather_date 60*60; # only warn once an hour
        }
        return;
    }

    print "db date=$date,$wdate hour=$hour,$whour min=$min,$wmin\n" if $main::config_parms{debug} eq 'weather';

    # If we got valid data
    my $raintotal_prev = $main::Weather{RainTotal};

    my $i = 0;
    map{$main::Weather{$weather_vwtype[$i++]} = $_} @temp;

    $main::Weather{HumidOutdoor} = 100 if $main::Weather{HumidOutdoor} > 100;

    $main::Weather{WindHighDir} = $main::Weather{WindAvgDir} if $main::Weather{WindAvgSpeed} > $main::Weather{WindHighSpeed} or $main::Weather{WindHighDir} eq undef;
    $main::Weather{WindHighSpeed} = $main::Weather{WindAvgSpeed} if $main::Weather{WindAvgSpeed} > $main::Weather{WindHighSpeed} or $main::Weather{WindHighSpeed} eq undef;
    $main::Weather{WindHighSpeed} = $main::Weather{WindGustSpeed} if $main::Weather{WindGustSpeed} > $main::Weather{WindHighSpeed};

    $main::Weather{HumidIndoorH} = $main::Weather{HumidIndoor} if $main::Weather{HumidIndoor} > $main::Weather{HumidIndoorH} or $main::Weather{HumidIndoorH} eq undef;
    $main::Weather{HumidIndoorL} = $main::Weather{HumidIndoor} if $main::Weather{HumidIndoor} < $main::Weather{HumidIndoorL} or $main::Weather{HumidIndoorL} eq undef;
    $main::Weather{HumidOutdoorH} = $main::Weather{HumidOutdoor} if $main::Weather{HumidOutdoor} > $main::Weather{HumidOutdoorH} or $main::Weather{HumidOutdoorH} eq undef;
    $main::Weather{HumidOutdoorL} = $main::Weather{HumidOutdoor} if $main::Weather{HumidOutdoor} < $main::Weather{HumidOutdoorL} or $main::Weather{HumidOutdoorL} eq undef;

    $main::Weather{TempIndoorH} = $main::Weather{TempIndoor} if $main::Weather{TempIndoor} > $main::Weather{TempIndoorH} or $main::Weather{TempIndoorH} eq undef;
    $main::Weather{TempIndoorL} = $main::Weather{TempIndoor} if $main::Weather{TempIndoor} < $main::Weather{TempIndoorL} or $main::Weather{TempIndoorL} eq undef;
    $main::Weather{TempOutdoorH} = $main::Weather{TempOutdoor} if $main::Weather{TempOutdoor} > $main::Weather{TempOutdoorH} or $main::Weather{TempOutdoorH} eq undef;
    $main::Weather{TempOutdoorL} = $main::Weather{TempOutdoor} if $main::Weather{TempOutdoor} < $main::Weather{TempOutdoorL} or $main::Weather{TempOutdoorL} eq undef;

    $main::Weather{RainRecent} = ::round(($main::Weather{RainTotal} - $raintotal_prev), 2) if $raintotal_prev > 0;
    if ($main::Weather{RainRecent} > 0) 
    {
        #speak "Notice, it just rained $main::Weather{RainRecent} inches";
        $main::Weather{IsRaining}++;
    }
    elsif ($main::Minute % 20) 
    {   # Reset every 20 minutes
        $main::Weather{IsRaining} = 0;
    }

}

1;



