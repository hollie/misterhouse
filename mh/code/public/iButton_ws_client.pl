# Category = Weather

# Test talking to an iButton weather station via the 
# Henriksen Weather Station server, available at  http://weather.henriksens.net/
#
#21.4 22.2 20.3 0.0 0.0 2.1 2 2 0.500 0.500 16.38 6.49
#21.5 22.2 20.3 0.0 0.0 0.0 -1 0 0.000 0.000 16.38 6.49
#21.5 22.2 20.3 0.0 0.0 2.1 2 2 0.500 0.500 16.38 6.49
#21.7 23.6 19.4 0.0 0.4 2.1 1 1 0.000 0.000 16.44 6.41
#Ccur Chi  Clo  Wcr Wpk Whi Wd WA TdRn  WkRn Sunst Sunrs
#
#where Ccur is current temp in C
#Chi is today's high in C
#Clo is today's low in C 
#Wcr is current wind speed in meters/sec
#Wpk is peak wind speed in meters/sec
#Whi is today's hi in meters/sec
#Wd is the current wind direction
#WA is the 10 minute average wind direction
#TdRn is today's Rain in inches
#MnRn is month's Rain in inches
#Sunst is today's sunset
#Sunrs is today's sunrise
#
#Wind directions are enumerated 0 through 15 corresponding to the 16 compass directions 
#N NNE NE ENE E ESE SE SSE S SSW SW WSW W WNW NW NNW.  
#I don't know why it had -1 at one point for the wind direction, but it didn't do any time
#that I was recently playing with the station.  It may have been a bug with one of the 
#past versions, but I'm using his version ws15112k at the moment.
#

$WindSpeed = new Weather_Item 'WindSpeed';
$WindSpeed-> tie_event('print_log "Wind speed is now at $state"');

#ibws   = new  Socket_Item(undef, undef, 'localhost:8888', 'ibws', 'tcp', 'raw');
$ibws   = new  Socket_Item(undef, undef, 'www.shokk.com:4263', 'ibws', 'tcp', 'raw');

$ibws_v = new  Voice_Cmd "[Start,Stop,Speak] the ibutton weather station client";
$ibws_v-> set_info('Connects to the ibutton weather station server');



if (time_cron '02 8,10,12,14,16,18,20 * * *')
{
    run_voice_cmd 'Start the ibutton weather station client';
    set $weather_timer 5;
}

if (expired $weather_timer) {
    run_voice_cmd 'Stop the ibutton weather station client';
    run_voice_cmd 'Speak the ibutton weather station client';
}



my @weather_vars = qw(TempOutdoor TempOutdoorHigh TempOutdoorLow
                      WindSpeed WindSpeadPeak WindSpeedHigh WindDir WindSpeedAvg
                      RainToday RainMonth SunRise SunSet);

#set $ibws_v 'Start' if $Startup;

if (my $data = said $ibws) {
    print_log "ibws server said: $data...";
    my @data = split ' ', $data;
    my $i = @data;
    if ($i == 12) {
        for ($i = 0; $i < 12; $i++) {
            my $key = $weather_vars[$i];
            if ($i < 3) {
                $Weather{$key} = convert_c2f $data[$i];
            }
            else {
                $Weather{$key} = $data[$i];
            }
        }
    }
    else {
        print_log "Bad ibws data, $i datapoints";
    }
}

my @direction=("North","North North East","North East","East North East","East","East South East","South East","South South East","South","South South West","South West","West South West","West","West North West","North West","North North West");

if ($state = said $ibws_v) {
    print_log "${state}ing the ibutton weather station client";
    if ($state eq 'Start') {
        unless (active $ibws) {
            print_log 'Starting a connection to ibws';
            start $ibws;
        }
    }
    elsif ($state eq 'Stop' and active $ibws) {
        print_log "closing ibws";
        stop $ibws;
    }
    elsif ($state eq 'Speak') {
        my $msg = "Current Temp is $Weather{TempOutdoor}.  High of $Weather{TempOutdoorHigh}, low of $Weather{TempOutdoorLow}.";
        $msg .= "Current wind speed is $Weather{WindSpeed} meters per second, peak of $Weather{WindSpeedPeak}, high of $Weather{WindSpeedHigh}, current direction $direction[$Weather{WindDir}] averaging $direction[$Weather{WindSpeedAvg}].";
        $msg .= "Today's rainfall is $Weather{RainToday} inches with $Weather{RainMonth} inches for the month";
        print_log $msg;
        speak $msg;
    }
}
