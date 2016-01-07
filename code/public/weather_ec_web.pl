# Utilty functions for formatting the weather for HTML display. This was
# originally a companion to the Environment Canada weather fetcher, but is
# probably useful on its own.
#
# chk@pobox.com February 19, 2002
#
# $Id$
#
# The latest version of this code can be found at
# <http://www.cfrq.net/~chk/mh/weather_ec_web.pl>

# dump the %Weather array as HTML; for debugging.
sub weather_dump {
    my $data = '<table border="1">' . "\n";
    my $key;
    foreach $key ( sort( keys(%Weather) ) ) {
        $data .=
          "<tr><td>" . $key . "</td><td>" . $Weather{$key} . "</td></tr>\n";
    }
    $data .= "</table>\n";

    return $data;
}

# Format the information in %Weather and @Weather_Forecast into a simple yet
# useful web page. This code is called from a server-side include in the HTML
# interface.
sub weather_ec_web {
    my $data = '<table><tr><td valign="top">' . "\n";
    my $label;

    # WEATHER
    $data .= '<table border="1">' . "\n";
    $data .= '<tr><th colspan="2">Current Conditions</th></tr>' . "\n";
    foreach $label
      qw(TimeObserved Conditions TempOutdoor Barom HumidOutdoor Humidex DewpointOutdoor Wind WindChill Visibility)
    {
        my $item;
        if ( $label =~ /Time/ ) {
            $item = time_date_stamp( 6, $Weather{$label} ) . " "
              . time_date_stamp( 5, $Weather{$label} );
        }
        else {
            $item = $Weather{$label};
        }
        $data .=
            "<tr><td>"
          . &weather_getlabel($label)
          . "</td><td>"
          . $item
          . "</td></tr>\n";
    }
    $data .= "</table>\n";

    $data .= '</td><td width="100"></td><td valign="top">' . "\n";

    # HISTORY

    $data .= '<table border="1">' . "\n";
    $data .= '<tr><th colspan="2">Almanac Data</th></tr>' . "\n";
    foreach $label
      qw(TempMaxOutdoor TempMinOutdoor RainTotal TempMaxNormal TempMinNormal TempMeanNormal)
    {
        $data .=
            "<tr><td>"
          . &weather_getlabel($label)
          . "</td><td>"
          . $Weather{$label}
          . "</td></tr>";
    }
    $data .= "<tr><td>Sunrise</td><td>" . $Time_Sunrise . "</td></tr>\n";
    $data .= "<tr><td>Sunset</td><td>" . $Time_Sunset . "</td></tr>\n";
    $data .= "<tr><td>Moonrise</td><td>" . $Weather{Moonrise} . "</td></tr>\n";
    $data .= "<tr><td>Moonset</td><td>" . $Weather{Moonset} . "</td></tr>\n";

    $data .= "</table>\n";

    $data .= "</td></table>\n";

    # FORECAST

    $data .= '<h2>Forecast:</h2>' . "\n";
    $data .= join "<br>\n", @Weather_Forecast;

    # links

    $data .= '<br>' . "\n" . '<h2>Links:</h2> ';
    $data .=
      '<a href="http://weatheroffice.ec.gc.ca/forecast/city_e.html?yyz">Toronto Airport</a>'
      . "\n";
    $data .=
      '<a href="http://weatheroffice.ec.gc.ca/forecast/24_hour_conditions_e.html?yyz&unit=m">[24 hour stats]</a>'
      . "\n";
    $data .=
      '<a href="http://weatheroffice.ec.gc.ca/forecast/city_e.html?ytz">Toronto Island</a>'
      . "\n";
    $data .=
      '<a href="http://weatheroffice.ec.gc.ca/forecast/24_hour_conditions_e.html?ytz&unit=m">[24 hour stats]</a>'
      . "\n";

    return $data;
}

if ($Reload) {
    $Password_Allow{'weather_ec_web'} = 1;
}

my %weather_textlabels = qw(TimeObserved Observed
  TempOutdoor Temp.
  Barom Pressure
  HumidOutdoor Humidity
  DewpointOutdoor Dewpoint
  TempMaxOutdoor High
  TempMinOutdoor Low
  RainTotal Rainfall
  TempMaxNormal NormalHigh
  TempMinNormal NormalLow
  TempMeanNormal NormalMean);

sub weather_getlabel {
    my $name = shift;
    if ( $weather_textlabels{$name} ) {
        return $weather_textlabels{$name};
    }
    else {
        return $name;
    }
}
