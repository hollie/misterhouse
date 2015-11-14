# Category=Weather

# The script creates the weather text that MisterHouse will speak from the
# web page you've chosen.  If this script is called "weather.txt", please
# rename it to "weather.pl" and place into your MisterHouse code directory.
#
# Go to www.wunderground.com, find out what the equivalent URL is for
# your local weather, and change the URL environment variable to it.
# Take it as you see it.  Improve it, and let me know what you've done with
# it.
#
# If you are not in USA, you will probably need to add a parameter in
# mh.private.ini, in this format: wunderground_locality=global/stations/03772
# Find the URL for your location by checking at www.wunderground.com
#
#

# ernie_oporto@mentorg.com
# October 7, 1999

# up-dated Clive Freedman. 9 June 2001
# scf@fircone.co.uk

# up-dated Mick Furlong , 10th June 2001
# dorsai@dircon.co.uk
# added 'Short' radio style announcement
# uses the last data from 'Get'

my $Country       = $config_parms{country};
my $StateProvince = $config_parms{state};
my $CityPage      = $config_parms{city};
my $Locality      = $config_parms{wunderground_locality};
my ( $text, $log_text, $log_html, $WeatherURL, $update_time, $temp_F );
my $textshort    = $log_text;
my $HtmlFindFlag = 0;
$WeatherURL =
  ($Locality)
  ? "http://www.wunderground.com/$Locality.html"
  : "http://www.wunderground.com/$Country/$StateProvince/$CityPage";

# my $WeatherFile=(split(/\./, (split(/\//,$WeatherURL))[5] ))[0];
my $WeatherFile = "wunderground";

my $f_weather_page     = "$config_parms{data_dir}/web/$WeatherFile.txt";
my $f_weather_html     = "$config_parms{data_dir}/web/$WeatherFile.html";
my $f_weather_log_text = "$config_parms{data_dir}/web/${WeatherFile}_log.txt";
my $f_weather_log_html = "$config_parms{data_dir}/web/${WeatherFile}_log.html";
my $f_weather_short    = "$config_parms{data_dir}/web/${WeatherFile}_short.txt";

$p_weather_page = new Process_Item;
$v_weather_page = new Voice_Cmd('[Get,Read,Show,Short] internet weather');
$v_weather_page->set_info(
    "Weather conditions and forecast for $config_parms{city}, $config_parms{state}  $config_parms{country}"
);
$v_weather_page->set_authority('anyone');

#speak($f_weather_page)
if ( said $v_weather_page eq 'Read' ) {
    $text = file_read $f_weather_page;
    speak $text;
}

display($f_weather_page) if said $v_weather_page eq 'Show';

#speak($f_weather_page)
if ( said $v_weather_page eq 'Short' ) {
    $text = file_read $f_weather_short;
    speak $text;
}

if ( said $v_weather_page eq 'Get' ) {

    #    # Do this only if we the file has not already been updated today and it is not empty
    #    if (0 and -s $f_weather_html > 10 and
    #        time_date_stamp(6, $f_weather_html) eq time_date_stamp(6)) {
    #        print_log "Weather page is current";
    #        display $f_weather_page;
    #    }
    #    else {
    if (&net_connect_check) {
        set $p_weather_page "get_url $WeatherURL $f_weather_html";
        start $p_weather_page;
        print_log "Retrieving $WeatherFile weather...";
        speak "Retrieving weather";

        # Use start instead of run so we can detect when it is done
        start $p_weather_page;
    }
    else {
        speak "Sorry, you must be logged onto the net";
    }

    #    }
}

if ( done_now $p_weather_page) {
    my $html = file_read $f_weather_html;

    # This leaks memory!
    #   $text = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($html));

    # This does not.
    $text = &html_to_text($html);

    # chop off stuff we don't care to hear read

    $text =~ s/.+Both(.+)function Observation.+/$1/s;
    $text =~ s/randNum.+?Here'>|flood.wunderground.com|Astronomy//is;
    $text =~ s/Add.+?Favorites.//is;
    $text =~ s/\[FORM.+?Here!//is;
    $text =~ s/.+?Here!//is;

    # convert any weather related acronyms or abbreviations to readable forms

    # HTML::FormatText converts &#176; to the 'degrees' string °.
    # which is ascii decimal 176 or hex b0.
    #   $text =~ s/\&\#176\;/ degrees /g;
    $text =~ s/\xb0/ degrees /g;

    $text =~ s/\n\n/\n/gs;

    #   $text =~ s/\q&nbsp\;/ /g;
    $text =~ s/\[IMAGE\]//g;
    $text =~ s/\[FORM NOT SHOWN\]//g;
    $text =~ s/\(Click for forecast\)//g;
    $text =~ s/approx./ approximately /g;
    $text =~ s/\s+F\s+/ Fahrenheit /g;
    $text =~ s/\s+%\s+/ Percent /g;
    $text =~ s/Moon Phase//g;
    $text =~ s/\s+N\s+/ North /g;
    $text =~ s/\s+NE\s+/ NorthEast /g;
    $text =~ s/\s+NNE\s+/ North by NorthEast /g;
    $text =~ s/\s+NNW\s+/ North by NorthWest /g;
    $text =~ s/\s+E\s+/ East /g;
    $text =~ s/\s+SE\s+/ SouthEast /g;
    $text =~ s/\s+W\s+/ West /g;
    $text =~ s/\s+SW\s+/ South West /g;
    $text =~ s/\s+S\s+/ South /g;
    $text =~ s/\s+NW\s+/ NorthWest /g;
    $text =~ s/\s+SSE\s+/ South by SouthEast /g;
    $text =~ s/\s+SSW\s+/ South by SouthWest /g;

    # Details stored here
    my ($update_time) = $text =~ /Updated: (.+?, 20\d\d)/;
    my ( $temp_F, $temp_C ) =
      $text =~ /Temperature.+?(.+?) degrees.+?\/ (.+?) degrees/;
    my ($humidity) = $text =~ /Humidity (.+?)%/;
    my ( $dewpoint_F, $dewpoint_C ) =
      $text =~ /Dewpoint.+?(.+?) degrees.+?\/ (.+?) degrees/;
    my ( $windchill_F, $windchill_C ) =
      $text =~ /Windchill.+?(.+?) degrees.+?\/ (.+?) degrees/;
    my ( $wind_dir, $wind_mph, $wind_kph ) =
      $text =~ /Wind (.+?) at (\d+?) mph \/ (.+?) km\/h/;
    my ( $pressure_in, $pressure_hPa ) =
      $text =~ /Pressure (.+?) in \/ (.+?) hPa/;
    my ($conditions) = $text =~ /Conditions (.+?)\n/;
    my ($clouds)     = $text =~ /Clouds (.+?)Sunrise/s;
    my ($today)      = $text =~ /Today(.+?)Tonight/s;
    my ($tonight)    = $text =~ /Tonight(.+?)\n.+?day/s;

    $clouds =~ s/\n/ - /s;
    $clouds =~ s/\s\s\s+//s;
    $windchill_C = "?" if !$windchill_C;
    $windchill_F = "?" if !$windchill_F;

    $log_text = "$update_time,$temp_F,$temp_C,$humidity,";
    $log_text .= "$dewpoint_F,$dewpoint_C,";
    $log_text .= "$windchill_F,$windchill_C,";
    $log_text .= "$wind_dir,$wind_mph,$wind_kph,";
    $log_text .= "$pressure_in,$pressure_hPa,";
    $log_text .= "$conditions,$clouds\r\n";
    $log_text .= "-----------------------------------\r\n" if ( $Day eq "Sun" );

    $log_html = "<tr><td>$update_time</td><td>${temp_F}F ${temp_C}C</td>";
    $log_html .= "<td>${humidity}%</td>";
    $log_html .= "<td>${dewpoint_F}F ${dewpoint_C}C</td>";
    $log_html .= "<td>${windchill_F}F ${windchill_C}C</td>";
    $log_html .= "<td>$wind_dir at $wind_mph mph</td>";
    $log_html .= "<td>$pressure_in $pressure_hPa</td>";
    $log_html .= "<td>$conditions</td><td>$clouds</td></tr>";

    my $data   = file_read($f_weather_log_html);
    my $header = "<HTML><HEAD><TITLE>Weather records</TITLE>\r\n";
    $header .=
      "<link rel=STYLESHEET href='../../list.css' type=text/css></HEAD>\r\n";
    $header .= "<BODY><table border=1>\r\n";
    $header .= "<tr><td>Date/time</td><td>Temp</td>\r\n";
    $header .= "<td>Humidity</td><td>Dewpoint</td>\r\n";
    $header .= "<td>Windchill</td><td>Wind</td><td>Pressure</td>\r\n";
    $header .= "<td>Conditions</td><td>Clouds</td></tr>\r\n\r\n";
    $log_html = $header . $log_html if $data !~ /table/;

    logit( $f_weather_log_text, $log_text,  0 );
    logit( $f_weather_log_html, $log_html,  0 );
    logit( $f_weather_log_html, "\r\n\r\n", 0 );

    file_write( $f_weather_short,
        "And here is the weather at $update_time. The Temperature is $temp_F Degrees Fahrenheit. That\'s $temp_C Degrees Centigrade.  The Wind Direction is $wind_dir at $wind_mph Miles Per Hour. The Conditions are $conditions. The forecast for today is $today\r\n"
    );
    file_write( $f_weather_page, $text );
    display $f_weather_page;
    browser
      "http://localhost:$config_parms{http_port}/data/web/${WeatherFile}_log.html";
}
