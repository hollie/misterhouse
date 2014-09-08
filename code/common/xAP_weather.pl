# Category = xAP

# $Date$
# $Revision$

#@ This code will monitor the xAP weather client from <a href=http://www.mi4.biz>mi4.biz</a>
#@ and stores the weather in the Weather hash.  Set mh.ini parm weather_source=station_name
#@ (e.g. weather_source=egll) to have the standard $Weather keys also set (used in the web status line).
#@ To find your station name, go to http://www.nws.noaa.gov/tg/siteloc.shtml,
#@ then use that when you start the program (e.g. weather.exe krst).
#@ If you don't specify a code it will default to London, Heathrow (EGLL).

#xAP_weather = new xAP_Item('weather.report', 'mi4.weather.krst');
#xAP_weather = new xAP_Item('weather.report', 'mi4.weather.egll');
$xAP_weather = new xAP_Item('weather.report');

if ( $state = state_now $xAP_weather) {
    my $source = $xAP_weather->{'xap-header'}{source};
    $source =~ s/mi4.weather.//;    # Drop prefix
    my $data;
    for my $key ( sort keys %{ $xAP_weather->{'weather.report'} } ) {
        my $value = $xAP_weather->{'weather.report'}{$key};
        $Weather{$source}{$key} = $value;
        $data .= "$key=$value, " unless $key eq 'date';
    }
    print_log "xAP weather $source: $data" if $Debug{xap};

    # Optionally set standard Weather keys (used in web status line)
    if ( lc $config_parms{weather_source} eq $source ) {
        if ( $config_parms{weather_uom_temp} eq 'C' ) {
            $Weather{TempOutdoor}  = $xAP_weather->{'weather.report'}{tempc};
            $Weather{DewOutdoor}   = $xAP_weather->{'weather.report'}{dewc};
            $Weather{WindAvgSpeed} = $xAP_weather->{'weather.report'}{windk};
        }
        else {
            $Weather{TempOutdoor}  = $xAP_weather->{'weather.report'}{tempf};
            $Weather{DewOutdoor}   = $xAP_weather->{'weather.report'}{dewf};
            $Weather{WindAvgSpeed} = $xAP_weather->{'weather.report'}{windm};
        }
        $Weather{WindAvgDir} = $xAP_weather->{'weather.report'}{winddirc};
        $Weather{Barom}      = $xAP_weather->{'weather.report'}{airpressure};
        $Weather{Icon}       = $xAP_weather->{'weather.report'}{icon};

        $Weather{Summary_Short} = "$Weather{Icon} $Weather{TempOutdoor}";
        $Weather{Summary_Short} .= ", barom=$Weather{Barom}" if $Weather{Barom};
        $Weather{Wind} = "$Weather{WindAvgSpeed} from the $Weather{WindAvgDir}";
        print_log "xAP weather: $Weather{Summary_Short} wind $Weather{Wind}"
          if $Debug{xap};
    }
}

# Example data:
#xAP weather krst: dewc=19.0, dewf=66.2, icon=sunny, tempc=28.0, tempf=82.4, utc=22:54, winddirc=W, winddird=280, windk=20.4, windm=12.7,
#xap-header
#{
#    v=12
#    hop=1
#    uid=FF263106
#    class=weather.report
#    source=mi4.weather.krst
#}
#weather.report
#{
#    DewF=66.2
#    Icon=sunny
#    DewC=19.0
#    TempF=82.4
#    UTC=22:54
#    Date=20030704
#    WindDirC=W
#    WindM=12.7
#    WindDirD=280
#    WindK=20.4
#    TempC=28.0
#}
