# The script creates the weather text that MisterHouse will speak from the
# web page you've chosen.  If this script is called "weather.txt", please
# rename it to "weather.pl" adn place into your MisterHouse code directory.
#
# Go to www.wunderground.com, find out what the equivalent URL is for 
# your local weather, and change the URL environment variable to it.
# Unmodified, you can hear what the weather will be like where I live.
# Take it as you see it.  Improve it, and let me know what you've done with
# it.
#

# ernie_oporto@mentorg.com
# October 7, 1999

my $Country = $config_parms{country};
my $StateProvince = $config_parms{state};
my $CityPage = $config_parms{city};

my $text;

my $HtmlFindFlag=0;
my $WeatherURL="http://www.wunderground.com/$Country/$StateProvince/$CityPage";
my $WeatherFile=(split(/\./, (split(/\//,$WeatherURL))[5] ))[0];

my $f_weather_page = "$config_parms{data_dir}/web/$WeatherFile.txt";
my $f_weather_html = "$config_parms{data_dir}/web/$WeatherFile.html";
$p_weather_page = new Process_Item("get_url $WeatherURL/index.html:80 $f_weather_html");
$v_weather_page = new  Voice_Cmd('[Get,Read,Show] internet weather');


if (said $v_weather_page eq 'Read') {
    $text = file_read $f_weather_page;
    speak $text;
}
display($f_weather_page) if said $v_weather_page eq 'Show';

if (said $v_weather_page eq 'Get') {

    # Do this only if we the file has not already been updated today and it is not empty
    if (0 and -s $f_weather_html > 10 and
        time_date_stamp(6, $f_weather_html) eq time_date_stamp(6)) {
        print_log "Weather page is current";
        display $f_weather_page;
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving $WeatherFile weather...$WeatherURL";

            # Use start instead of run so we can detect when it is done
            start $p_weather_page;
        }
        else {
            speak "Sorry, you must be logged onto the net";
        }
    }            
}

    
if (done_now $p_weather_page) {
    my $html = file_read $f_weather_html;

    $text = HTML::FormatText->new(leftmargin => 0, rightmargin => 150)->format(HTML::TreeBuilder->new()->parse($html));

    # chop off stuff we don't care to hear read
    $text =~ s/.+\Forecast as of (.+)/Forecast as of $1/s;
    $text =~ s/(.+)Forecast Weather Graph.+/$1/s;


    # convert any weather related acronyms or abbreviations to readable forms

    # HTML::FormatText converts &#176; to the 'degrees' string °.
    # which is ascii decimal 176 or hex b0.
    $text =~ s/\xb0/ degrees /g;
    # weed out all other unwanted verbage
    $text =~ s/\q&nbsp\;/ /g;
    $text =~ s/\[IMAGE\]//g;
    $text =~ s/\(Click for forecast\)//g;
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

    file_write($f_weather_page, $text);
    display $f_weather_page;
}



