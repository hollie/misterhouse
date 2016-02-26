# Category=Weather

# The script parses the summary weather pages from weatheroffice.ec.gc.ca,
# and places the data into the %Weather hash for use by other parts of
# misterhouse.
#
# Go to weatheroffice.ec.gc.ca and find out what the 3-letter station code
# for your area is; it's usually the local airport code, and can be found
# in the "city=xxx" argument in the URL.
#
# Unmodified, you'll get the weather for Pearson International on the
# outskirts of Toronto.
#
# Take it as you see it.  Improve it, and let me know what you've done with
# it.
#
# chk@pobox.com
# February 12, 2002
#
# $Id$
#
# The latest version of this code is usually available from
# <http://www.cfrq.net/~chk/mh/weather_ec.txt>.
#

# A separate global for the 5-day forecast.
use vars qw(@Weather_Forecast);

# Temporary file used to get weather data back from the parser subprocess into
# misterhouse. This must currently match the file configured into
# get_weather_ca; I'll fix that later.
my $f_weather_data = "$config_parms{data_dir}/weather_data";
$f_weather_file = new File_Item($f_weather_data);

# The obligatory voice command.
$v_weather_page = new Voice_Cmd('[Reget,Get,Read,Show] internet weather');
$v_weather_page->set_info(
    "Weather conditions and forecast for $config_parms{weather_city}");
$v_weather_page->set_authority('anyone');

$v_weather_forecast = new Voice_Cmd('[Read,Show] weather forecast');
$v_weather_forecast->set_info(
    "Weather forecast for $config_parms{weather_city}");
$v_weather_forecast->set_authority('anyone');

speak &format_ec_weather   if said $v_weather_page eq 'Read';
respond &format_ec_weather if said $v_weather_page eq 'Show';

speak &format_ec_forecast   if said $v_weather_forecast eq 'Read';
respond &format_ec_forecast if said $v_weather_forecast eq 'Show';

# Here is the guts of the asynchronous processing. get_ec_weather starts the
# fetch subprocess. When it is done, fetch_ec_weather reads the resulting data
# back into the main misterhouse process.

&get_ec_weather(0)
  if ( ( said $v_weather_page eq 'Get' )
    or time_cron("0 6,9-17,21 * * *") );
&get_ec_weather(1) if ( said $v_weather_page eq 'Reget' );

&fetch_ec_weather if ( changed $f_weather_file);
&fetch_ec_weather if ($Startup);

if ( $Startup || $Reload ) {

    # ugly; we need temperature sensors instead...
    $Weather{TempIndoor}  = '20';
    $Weather{HumidIndoor} = '50';
}

# Other code modules (eg. internet_jabber.pl) can call these without having to
# worry about implementation changes.
sub read_ec_weather {
    respond &format_ec_weather;
}

sub display_ec_weather {
    display &format_ec_weather;
}

# This subroutine formats a speakable (well, mostly) summary of the current
# weather conditions and short term forecast.
sub format_ec_weather {
    my $data;

    # simple summary for now.
    $temp = $Weather{TempOutdoor};
    $temp =~ s/C/degrees celsius/;
    $temp =~ s/F/degrees farenheit/;

    $data = "The weather is " . $Weather{Conditions} . ". ";
    $data .= "It is " . $temp . " degrees outside";
    $data .= ", with a windchill of " . $Weather{WindChill} . " degrees"
      if ( $Weather{WindChill} );
    $data .= ". ";

    if ( $Weather{TempOutdoor} > 15 ) {
        $data .=
            "The humidity is "
          . $Weather{HumidOutdoor}
          . "%, with a humidex of "
          . $Weather{Humidex}
          . " and a dewpoint of "
          . $Weather{DewpointOutdoor} . ". ";
    }

    if ( $Weather{WindAvg} ) {
        $data .=
            "The wind is from the "
          . convert_direction( $Weather{WindAvgDir} ) . " at "
          . $Weather{WindAvg}
          . " kilometers per hour";
        $data .= ", gusting to " . $Weather{WindGust} . " kilometers per hour"
          if ( $Weather{WindGust} );
        $data .= ". ";
    }
    else {
        $data .= "There is no wind. ";
    }

    $data .= $Weather_Forecast[1];

    $data =~ s%km/h%kilometers per hour%;

    return $data;
}

sub format_ec_forecast {
    return join( "\n", @Weather_Forecast );
}

# Fetch the raw HTML weather page from the Environment Canada webserver, and
# update the parsed data file.
sub get_ec_weather {
    my $force = shift;

    my $pgm = "get_weather_ca";
    $pgm .= " -reget" if $force;

    print_log "running $pgm";
    run $pgm;
    print_log "Weather update started";

    set_watch $f_weather_file;
}

# this routine fetches the (raw) weather data from the parsing subprocess, and
# reads it back into the main MH variables. (I cheat by using an eval :-). I
# then do any other formatting necessary; this separates the low-level *parsing*
# from higher-level formatting.
sub fetch_ec_weather {

    #get data from file
    open IN, $f_weather_data;
    local $/ = undef;    # Slurp the whole file at once
    my $weather_data = <IN>;
    close IN;

    # set %Weather and @Weather_Forecast
    eval $weather_data;
    warn "eval failed: $@" if $@;

    # ugly; we need temperature sensors instead...
    $Weather{TempIndoor}  = '20';
    $Weather{HumidIndoor} = '50';

    # calculate the wind chill factor.
    $Weather{WindChill} =
      &windchill( $Weather{TempOutdoor}, $Weather{WindAvg} );

    if ( !$Weather{DewpointOutdoor} ) {
        $Weather{DewpointOutdoor} =
          &dewpoint( $Weather{TempOutdoor}, $Weather{HumidOutdoor} );
    }

    # create the summaries used by the MH web (and tk?) displays.
    $Weather{Summary_Short} = sprintf(
        "%2d/%2d/%2d %3d%% %3d%%",
        $Weather{TempIndoor},  $Weather{TempOutdoor}, $Weather{WindChill},
        $Weather{HumidIndoor}, $Weather{HumidOutdoor}
    );
    $Weather{Summary} = sprintf(
        "In/out/chill: %4.1f/%2d/%2d Humid:%3d%% %3d%%",
        $Weather{TempIndoor},  $Weather{TempOutdoor}, $Weather{WindChill},
        $Weather{HumidIndoor}, $Weather{HumidOutdoor}
    );

    # and for fun, speak the current weather to anyone who is listening.
    &read_ec_weather;
}

# Find the wind chill equivalent temperature (in degrees Celsius) based on a
# given air temperature and wind velocity, using the new (2001) Environment
# Canada formula.
#
# Source: http://www.msc.ec.gc.ca/windchill/science_equations_e.cfm
#
# input is temperature in degrees Celsius, wind velocity in km/h at the
# standard anemometer height of 10m (the formula corrects to face height).
#
# A US version of this formula is available from the US Weather Service :)
#
sub windchill {
    my $temp = shift;
    my $wind = shift;

    my $chill;

    if ( ( $wind < 5 ) || ( $wind > 100 ) || ( $temp < -50 ) || ( $temp > 5 ) )
    {
        $chill = '';
    }
    else {
        $chill =
          ( 13.12 + 0.6215 * $temp -
              11.37 * ( $wind**0.16 ) +
              0.3965 * $temp * ( $wind**0.16 ) );
        $chill = int( $chill + 0.5 );

        print "temp $temp wind $wind chill $chill\n";
    }

    return $chill;
}

# Find the dewpoint, given temperature and relative humidity. Source:
# http://www.atd.ucar.edu/weather_fl/dewpoint.html
#
sub dewpoint {
    my $temp     = shift;
    my $humidity = shift;

    $temp += 273.15;    # convert to Kelvin
    $humidity /= 100;   # convert from percent to fraction

    # saturation vapour pressure
    my $e_sw =
      6.1078 *
      exp( 5.0065 * log( 273.15 / $temp ) ) *
      exp( 24.846 * ( 1 - ( 273.15 / $temp ) ) );

    # current vapour pressure
    my $e_vp = $humidity * $e_sw;

    # final
    my $dewpoint = 0;
    if ( $e_vp != 0 ) {
        $dewpoint =
          ( 237.3 * log( $e_vp / 6.1078 ) ) /
          ( 17.27 - ( log( $e_vp / 6.1078 ) ) );
        $dewpoint = int( $dewpoint + 0.5 );
    }
    return $dewpoint;
}
