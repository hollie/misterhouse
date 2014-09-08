# Category = Weather
#
# $Revision$
# $Date$
#
#@ Weather METAR parser
#@
#@ $Revision$
#@
#@ To get the closest station name in Canada, go to
#@ http://www.flightplanning.navcanada.ca and choose METAR/TAF
#@
#@ For non-Canadian locations, do a web search for ICAO
#@ one lookup site: http://www.jfast.org/Tools/Port2PortAirDist/GeoLookup.asp
#@
#@ Place name of country (Canada or "other") in mh.ini as weather_metar_country
#@ Place name of nearest station in mh.ini as weather_metar_station
#@ Use weather_uom_* configs to choose units
#
# by Matthew Williams

# noloop=start
use Weather_Common;

my $station = uc( $config_parms{weather_metar_station} );
my $country = lc( $config_parms{weather_metar_country} );

$station = 'CYOW'  unless $station;
$country = 'other' unless $country;

my $url;
if ( $country eq 'canada' ) {
    $url =
      "http://www.flightplanning.navcanada.ca/cgi-bin/Fore-obs/metar.cgi?NoSession=NS_Inconnu&format=raw&Langue=anglais&Region=can&Location=&Stations="
      . $station;
}
else {
    $url = "http://weather.noaa.gov/cgi-bin/mgetmetar.pl?Submit=SUBMIT&cccc="
      . $station;
}

my $weather_metar_file = $config_parms{data_dir} . '/web/weather_metar.html';

$p_weather_metar_page =
  new Process_Item(qq{get_url -quiet "$url" "$weather_metar_file"});

$v_get_metar_weather = new Voice_Cmd('get metar weather');

# noloop=stop

if ($Reload) {
    &trigger_set(
        '$New_Minute and $Minute == 5',
        '$p_weather_metar_page->start',
        'NoExpire',
        'Update weather information via METAR'
    ) unless &trigger_get('Update weather information via METAR');
}

if ( said $v_get_metar_weather) {
    start $p_weather_metar_page;
    $v_get_metar_weather->respond(
        'Updating weather information from latest METAR');
}

if ( done_now $p_weather_metar_page or $Reload ) {
    &process_metar;
}

sub process_metar {
    my $html = file_read $weather_metar_file;
    return unless $html;

    # NavCanada changed their format to break reports into multiple lines
    $html =~ s/\n<br>\n//g;
    my %metar;
    my $last_report = 'none';
    my ( $pressure, $weather, $clouds, $winddirname, $windspeedtext );
    my ( $metricpressure, $pressuretext, $apparenttemp, $dewpoint );
    $apparenttemp = 'none';

    # apparenttemp is either windchill or humidex

    while ( $html =~
        m#((METAR) |(SPECI) )?$station \d{6}Z (AUTO )?(COR )?(CCA )?(\d{3}|VRB)\d{2}(G\d{2})?KT .+?\n#g
      )
    {
        $last_report = $&;
        chop $last_report;
        $weather = '';
        $clouds  = '';
        my $notCurrent = 0;
        $metar{IsRaining} = 0;
        $metar{IsSnowing} = 0;

        print_log "Parsing METAR report: $last_report";

        ( $metar{WindAvgDir}, $metar{WindAvgSpeed}, $metar{WindGustSpeed} ) =
          $last_report =~ m#(\d{3}|VRB)(\d{2})(G\d{2})?KT#;    # speeds in knots
        if ( $last_report =~ m#\s(M?\d{2})/(M?\d{2})\s# ) {
            ( $metar{TempOutdoor}, $metar{DewOutdoor} ) = ( $1, $2 );
        }
        ;    # temperatures are in Celsius
        if ( $last_report =~ m#\sA(\d{4})\s# ) {
            $metar{BaromSea} = convert_in2mb( $1 / 100 );
        }
        ;    # pressure in inches of mercury, converted to mb
        if ( $last_report =~ m#\sQ(\d{4})\s# ) { $metar{BaromSea} = $1; }
        ;    # pressure in hPa (mb)
        my $element;
        foreach $element ( split( / /, $last_report ) ) {
            if ( $element eq $station ) { next; }
            ;    # don't decode station
            if ( $element =~ m#^RMK# ) { last; }
            ;    # end of current conditions
            if ( $element eq 'CAVOK' ) {
                $weather .= 'ceiling and visibility OK';
            }
            if ( $element eq 'SKC' or $element eq 'CLR' ) {
                $clouds = 'sky clear ';
            }
            if ( $element eq 'METAR' or $element eq 'SPECI' ) { next; }
            if ( $element eq 'CCA' ) { next; }
            ;    # correction
            if ( $element eq 'AUTO' ) { next; }
            ;    # automated station
            if ( $element =~ m#^FEW# ) { $clouds = 'few clouds'; }
            if ( $element =~ m#^SCT# ) { $clouds = 'scattered clouds'; }
            if ( $element =~ m#^BKN# ) { $clouds = 'broken clouds'; }
            if ( $element =~ m#^OVC# ) { $clouds = 'overcast'; }

            if ( $element =~ m#\d# ) { next; }
            ;    # precipitation has no digits
            $element =~ /^\+/ && do { $weather .= 'heavy ' };
            $element =~ /^\-/ && do { $weather .= 'light ' };
            ($element) = $element =~ m#^[\+\-]?(.+)#;
            while ( $element =~ m#(.{2})#g ) {
                if ( $1 eq 'MI' ) { $weather .= 'shallow ' }
                if ( $1 eq 'PR' ) { $weather .= 'partial ' }
                if ( $1 eq 'BC' ) { $weather .= 'patches of ' }
                if ( $1 eq 'DR' ) { $weather .= 'low drifting ' }
                if ( $1 eq 'BL' ) { $weather .= 'blowing ' }
                if ( $1 eq 'SH' ) { $weather .= 'showers ' }
                ;    # could be snow or rain
                if ( $1 eq 'TS' ) { $weather .= 'thunderstorm ' }
                if ( $1 eq 'FZ' ) { $weather .= 'freezing ' }
                if ( $1 eq 'DZ' ) { $weather .= 'drizzle ' }

                if ( $1 eq 'RA' ) {
                    $weather .= 'rain ';
                    $metar{IsRaining} = 1 unless $notCurrent;
                }
                if ( $1 eq 'SN' ) {
                    $weather .= 'snow ';
                    $metar{IsSnowing} = 1 unless $notCurrent;
                }
                if ( $1 eq 'SG' ) {
                    $weather .= 'snow grains ';
                    $metar{IsSnowing} = 1 unless $notCurrent;
                }
                if ( $1 eq 'IC' ) {
                    $weather .= 'ice crystals ';
                    $metar{IsSnowing} = 1 unless $notCurrent;
                }
                if ( $1 eq 'PL' ) {
                    $weather .= 'ice pellets ';
                    $metar{IsSnowing} = 1 unless $notCurrent;
                }
                if ( $1 eq 'GR' ) { $weather .= 'hail ' }
                if ( $1 eq 'GS' ) { $weather .= 'small hail ' }
                if ( $1 eq 'UP' ) { $weather .= 'unknown precipitation ' }
                if ( $1 eq 'BR' ) { $weather .= 'mist ' }
                if ( $1 eq 'FG' ) { $weather .= 'fog ' }
                if ( $1 eq 'FU' ) { $weather .= 'smoke ' }
                if ( $1 eq 'VA' ) { $weather .= 'volcanic ash ' }
                if ( $1 eq 'DU' ) { $weather .= 'widespread dust haze ' }
                if ( $1 eq 'SA' ) { $weather .= 'sand ' }
                if ( $1 eq 'HZ' ) { $weather .= 'haze ' }
                if ( $1 eq 'PY' ) { $weather .= 'spray ' }
                if ( $1 eq 'PO' ) { $weather .= 'dust/sand whirls ' }
                if ( $1 eq 'SQ' ) { $weather .= 'squalls ' }
                if ( $1 eq 'FC' ) { $weather .= 'funnel cloud ' }
                if ( $1 eq 'SS' ) { $weather .= 'sandstorm ' }
                if ( $1 eq 'DS' ) { $weather .= 'duststorm ' }
                $notCurrent = 0;
                if ( $1 eq 'VC' ) { $weather .= 'distant '; $notCurrent = 1; }
                if ( $1 eq 'RE' ) { $weather .= 'recent ';  $notCurrent = 1; }
            }
        }
    }

    if ( $last_report eq 'none' ) {    # didn't find a report
        &print_log(
            "weather_metar: couldn't find a valid METAR report.  Retrieved data can be found in ${weather_metar_file}."
        );
        return;
    }

    $weather =~ s/ $//;                # remove trailing space

    $metar{Conditions} = $weather;
    $metar{Clouds}     = $clouds;

    # remove G from gust measurement
    $metar{WindGustSpeed} =~ s/^G//g;

    # remove leading zeros
    grep { $metar{$_} =~ s/^0// } qw(WindAvgSpeed WindGustSpeed);

    if ( $metar{WindGustSpeed} eq '' ) {
        $metar{WindGustSpeed} = $metar{WindAvgSpeed};
    }
    if ( $metar{WindAvgDir} eq 'VRB' ) {    # variable winds
        $metar{WindAvgDir} = 0;             # North is as good direction as any
    }
    $metar{WindGustDir} = $metar{WindAvgDir};

    # change M to minus sign
    $metar{TempOutdoor} =~ s/M/-/;

    # remove leading 0 if present
    $metar{TempOutdoor} =~ s/^(-?)0/$1/;

    # change M to minus sign
    $metar{DewOutdoor} =~ s/M/-/;

    # remove leading 0 if present
    $metar{DewOutdoor} =~ s/^(-?)0/$1/;

    if ( $config_parms{weather_uom_temp} eq 'F' ) {
        grep { $metar{$_} = convert_c2f( $metar{$_} ) }
          qw(TempOutdoor DewOutdoor);
    }
    if ( $config_parms{weather_uom_wind} eq 'mph' ) {
        grep { $metar{$_} = convert_nm2mile( $metar{$_} ) }
          qw(WindAvgSpeed WindGustSpeed);
    }
    if ( $config_parms{weather_uom_wind} eq 'm/s' ) {
        grep { $metar{$_} = convert_knots2mps( $metar{$_} ) }
          qw(WindAvgSpeed WindGustSpeed);
    }
    if ( $config_parms{weather_uom_wind} eq 'kph' ) {
        grep { $metar{$_} = convert_nm2km( $metar{$_} ) }
          qw(WindAvgSpeed WindGustSpeed);
    }

    $metar{Barom} =
      &Weather_Common::convert_sea_barom_to_local_mb( $metar{BaromSea} );

    if ( $config_parms{weather_uom_baro} eq 'in' ) {
        grep { $metar{$_} = convert_mb2in( $metar{$_} ) } qw(Barom BaromSea);
    }
    else {
        grep { $metar{$_} = sprintf( "%.1f", $metar{$_} ) } qw(Barom BaromSea);
    }

    grep { $metar{$_} = sprintf( '%.0f', $metar{$_} ) } qw(
      TempOutdoor
      DewOutdoor
      WindAvgSpeed
      WindGustSpeed
    );

    if ( $Debug{weather} ) {
        foreach my $key ( sort( keys(%metar) ) ) {
            &print_log( "weather_metar: $key is " . $metar{$key} );
        }
    }

    &Weather_Common::populate_internet_weather( \%metar,
        $config_parms{weather_internet_elements_metar} );
    &Weather_Common::weather_updated;
}

# useful for debugging
$v_show_weather = new Voice_Cmd('show weather');

if ( said $v_show_weather) {
    my $metric;
    my $response = '';
    foreach $metric ( sort( keys(%Weather) ) ) {
        $response .= "Weather $metric is $Weather{$metric}\n";
    }
    $v_show_weather->respond($response);
}

sub uninstall_weather_metar {
    &trigger_delete('Update weather information via METAR');
}
