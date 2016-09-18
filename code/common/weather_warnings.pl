# Category = Weather
#@Monitor weather forecast from internet_weather.pl to parse and announce weather warnings
# $Date$
# $Revision$

#@ This script parses weather warning info from the weather forecasts downloaded by
#@ internet_weather.pl (US only).  If there is WARNING text at the top of the forecast
#@ an announcement is made.
#@ The forecast is updated when a new internet weather forecast is received.
#@ To modify when it is spoken (or disable it), go to the
#@ <a href=/bin/triggers.pl> triggers page </a>
#@ and modify the 'read weather warnings' trigger.

# 01/05/2014 Created by Steve Switzer (steve@switzerny.org)

$f_weather_forecast_warning =
  new File_Item "$config_parms{data_dir}/web/weather_forecast.txt";
set_watch $f_weather_forecast_warning if $Reload;

$v_get_weather_warning = new Voice_Cmd 'Get the weather warnings', 0;
$v_get_weather_warning->set_info('Gets weather warnings');

$v_weather_warning = new Voice_Cmd 'Read weather warnings', 0;
$v_weather_warning->set_info('Reads and weather warnings, if present.');
$v_weather_warning->set_authority('anyone');

if ( said $v_weather_warning) {
    my $response = $Weather{Warning};
    print_log($response);
    $v_weather_warning->respond(
        "app=weatherwarning important=1 Weather Warning: $response")
      unless $response =~ /^$/i;
}

if (   said $v_get_weather_warning
    or changed $f_weather_forecast_warning
    or $Reload )
{
    #$v_get_weather_warning ->respond("app=weather Checking weather warnings...") if said $v_get_weather_warning;

    set_watch $f_weather_forecast_warning;

    undef $Weather{Warning};
    foreach my $line ( read_all $f_weather_forecast_warning) {
        next if $line =~ /^as of/i;
        if ( $line =~ /^warning:(.*)/i ) {
            $Weather{Warning} .= '';
            chomp;
            $line = $1;
            $line =~ s/\ est\ / /i;
            $line =~ s/\ am\ / A M /i;
            $line =~ s/...$/ /i;
            $Weather{Warning} .= ' ' if $Weather{Warning} ne '';
            $Weather{Warning} .= $line;
            next;
        }
    }
    $Weather{Warning} =~ s/^\ \ *$//;

    #$v_get_weather_warning ->respond("app=weather Weather warnings prepared.") if said $v_get_weather_warning;

    run_voice_cmd 'Read weather warnings' unless $Reload;

}

# lets allow the user to control via triggers
if ($Reload) {
    &trigger_set(
        "time_cron '11 8,11,16,19 * * *'",
        "run_voice_cmd 'Read weather warnings'",
        'NoExpire',
        'read weather warnings'
    ) unless &trigger_get('read weather warnings');
}

=begin comment
Examples of different WANRING texts...

The forecast is As of 3:32pm Sat Dec 21, 2013:
WARNING: Ice storm warning in effect until noon est sunday...
WARNING: Flood watch in effect through sunday evening...
Tonight: Rain and freezing rain. Ice accumulation of one tenth to one half
    of an inch. Lows in the lower 30s. Northeast winds 10 to 20 mph with
    gusts up to 30 mph after midnight. Chance of precipitation near 100
    percent.
Sunday: Rain and freezing rain in the morning...Then a chance of rain
    showers in the afternoon. Ice accumulation of up to one tenth of an
    inch. Breezy with highs ranging from the lower 40s along the lake
    ontario shore to the mid 40s inland. Northeast winds 10 to 15 mph,
    becoming light. Chance of precipitation near 100 percent.

...

As of 8:31pm Sun Jan 5, 2014:
WARNING: High wind warning in effect from 1 am to 10 am est monday...
WARNING: Lake effect snow advisory in effect from 1 pm monday to 7 pm est
WARNING: Tuesday...
WARNING: Wind chill warning in effect from 6 pm monday to 6 pm est
WARNING: Tuesday...
Rest Of Tonight: Rain. Very windy with lows around 30. Southeast winds 10
    to 15 mph, becoming south and increasing to 25 to 35 mph with gusts up
    to 55 mph. Chance of rain near 100 percent.
Monday: Mostly cloudy with scattered rain and snow showers in the morning,
    then partly sunny with snow showers likely in the afternoon.
    Accumulation an inch or less. Strong winds. Early morning highs in the
    mid 30s, then temperatures falling to between 10 and 15 inland and to
    between 15 and 20 along the lake ontario shore. Southwest winds 35 to
    50 mph with gusts up to 60 mph, becoming west and diminishing to 30 to
    40 mph. Chance of precipitation 60 percent.
=cut

