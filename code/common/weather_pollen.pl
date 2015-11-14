#Category=Weather

#@ This module gets the pollen forecast from Wunderground.com and puts the predominant pollen
#@ types and pollen count into the %Weather hash.
#@
#@ Uses mh.ini parameter zip_code

# Get pollen count forecast from Wunderground.com and put it and the predominant pollen
# type into the %Weather hash.
# Technically there is a 4 day forecast, but the future forecast varies widely, so not
# all values are included.
#
#uses mh.ini parameter zip_code=
#
#info from:
#http://www.wunderground.com/DisplayPollen.asp?Zipcode=[zipcode]
#

# weather_pollen.pl
# Original Author:  Kent Noonan
# Revision:  1.4
# Date:  08/30/2015

=begin comment

 1.0   Initial Release
       Kent Noonan - ca. 12/16/2001
 1.1   Revisions
       David J. Mark - 06/12/2006
 1.2   Updated to use new Trigger design.
       Bruce Winter - 06/25/2006
 1.3   Updated to use the JSON WeatherPollenService from Claratin.com
       since Pollen.com has added countermeasures to prevent screenscraping
       that would take much more code to parse.  The WeatherPollenService
       has a better API that seems to provide the same data as most other
       online pollen forecasting services.  In addition to switching service
       providers, I've also done some general cleanup & improvements.
       Jared J. Fernandez - 07/14/2014
 1.3.1 Minor change to support newer version of perl that treat single element
       arrays differently.
       Jared J. Fernandez - 07/06/2015
 1.4   Switched to use Wunderground.com because Claritin discontinued support
       of their JSON API service.
       Jared J. Fernandez - 08/30/2015

=cut

use JSON qw( decode_json );

my $pollen_file = "$config_parms{data_dir}/web/pollen_forecast.html";

$v_get_pollen_forecast = new Voice_Cmd('[Get,Check] pollen forecast');
$v_get_pollen_forecast->set_info(
    "Downloads and parses the pollen forecast data.  The 'check' option reads out the result after parsing is complete."
);

$v_read_pollen_forecast = new Voice_Cmd('Read pollen forecast');
$v_read_pollen_forecast->set_info(
    "Reads out the previously fetched pollen forecast.");

$p_pollen_forecast = new Process_Item(
    "get_url http://www.wunderground.com/DisplayPollen.asp?Zipcode=$config_parms{zip_code} $pollen_file"
);

&parse_pollen_forecast if ( ($Reload) && ( -e $pollen_file ) );

sub parse_pollen_forecast {
    my ( $pollentype, $pollencount, $pollenleveltable );
    open( FILE, "$config_parms{data_dir}/web/pollen_forecast.html" )
      || warn "Unable to open pollen data file.";
    while (<FILE>) {
        if (/<h3><strong>Pollen Type:<\/strong>\s?([A-Za-z\/ ,]+)\.?<\/h3>/) {
            $main::Weather{TodayPollenType} = $1;
            $pollentype = 1;
        }
        elsif (/<td class="levels">/) {
            $pollenleveltable = 1;
        }
        elsif ($pollenleveltable) {
            if (/<p>(\d\.\d+)<\/p>/) {
                if ( !defined $pollencount ) {
                    $main::Weather{TodayPollenCount} = $1;
                    $pollencount                     = 1;
                    $pollenleveltable                = '';
                }
                else {
                    $main::Weather{TomorrowPollenCount} = $1;
                    $pollencount++;
                    $pollenleveltable = '';
                }
            }
        }
        last if ( $pollentype && ( $pollencount == 2 ) );
    }
    close(FILE);
    unless ( $pollentype && $pollencount ) {
        warn "Error parsing pollen info.";
    }
}

if ( $state = said $v_get_pollen_forecast) {
    $v_get_pollen_forecast->respond("app=pollen Retrieving pollen forecast...");
    start $p_pollen_forecast;
}

if ( done_now $p_pollen_forecast) {
    &parse_pollen_forecast();
    if ( $v_get_pollen_forecast->{state} eq 'Check' ) {
        $v_get_pollen_forecast->respond(
            "app=pollen Today's pollen count is $main::Weather{TodayPollenCount}. The predominant pollens are from "
              . lc( $main::Weather{TodayPollenType} . "." ) );
    }
    else {
        $v_get_pollen_forecast->respond(
            "app=pollen Pollen forecast retrieved.");
    }
}

if ( said $v_read_pollen_forecast) {
    if ( $Weather{TodayPollenCount} ) {
        $v_read_pollen_forecast->respond(
            "app=pollen Today's pollen count is $main::Weather{TodayPollenCount}. The predominant pollens are from "
              . lc( $main::Weather{TodayPollenType} )
              . "." );
    }
    else {
        $v_read_pollen_forecast->respond(
            "app=pollen I do not know the pollen count at the moment.");
    }
}

# create trigger to download pollen forecast

if ($Reload) {
    if ( $Run_Members{'internet_dialup'} ) {
        &trigger_set(
            "state_now \$net_connect eq 'connected'",
            "run_voice_cmd 'Get pollen forecast'",
            'NoExpire',
            'get pollen forecast'
        ) unless &trigger_get('get pollen forecast');
    }
    else {
        &trigger_set(
            "time_cron '0 5 * * *' and net_connect_check",
            "run_voice_cmd 'Get Pollen forecast'",
            'NoExpire',
            'get pollen forecast'
        ) unless &trigger_get('get pollen forecast');
    }
}
