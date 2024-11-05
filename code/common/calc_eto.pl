# Category = Irrigation

# Fall 2024
# v4.0
# Included ability to write to Opensprinkler Home Assistant Object

# April 2023
# v3.0
# -reverted to WU model and migrated to VisualCrossing

# June 2018
# v1.3
# - added check if wudata returns null data
# - Email has clearer information on start times and run length.
# - if run after sunrise, then use the sunset times and max 2 cycles
# - write predicted daily rain to the RRD.

#@ This module allows MisterHouse to calculate daily EvapoTranspiration based on a
#@ Data feed from Weatherunderground (WU). To use it you need to sign up for a weatherundeground key
#@ The free developer account provides a low-volume hobbyist service that will work for these calcs
#@ A location is also required. Best is a lat/long pair.
#@ By default wuData is written to $Data_Dir/wuData and the eto logs are written to $Data_Dir/eto
#@
#@ The ET programs can be automatically uploaded to an OpenSprinkler. (need >= v1.1 of the lib)

###########################################################################################################
##                                   Credits                                                             ##
###########################################################################################################
## portions of code provided by Zimmerman method used by OpenSprinkler                                   ##
## portions of code provided/edited by Ray and Samer of OpenSprinkler                                    ##
## eto library provided by Mark Richards                                                                 ##
## Original python code provided by Shawn Harte 2014 no copyright reserved                               ##
## python cleanup and first pass my Neil Cherry                                                          ##
## Code was used with utmost respect to the original authors, your efforts have prevented the            ##
## re-invention of the wheel                                                                             ##
###########################################################################################################

#The script accounts for wind, freezing conditions, and current/recent
#rainfall when considering start and run times.  It will avoid watering
#during midday, unless early morning winds prevent earlier start times.
#The starts are serialized so no odd overlaps should occur.  Mornings
#are preferred to evenings to allow for the best use of water and
#absorption without causing mold and fungus growth by leaving grass wet
#overnight.  The script is commented quite heavily, so that anyone can
#edit or use it to their liking.  Please be mindful that other authors
#work was used or modified when the code seemed generalized enough that
#I shouldn’t be stepping on toes.  Please do not pester the original
#author if something doesn’t work for you, as they will probably have
#enough on their own plate with their own original works.
#
#Everything is done based off your latitude and longitude, however, the
#script can find the info when provided with a city/state or country, a
#US Zip Code, or a PWS ID.

#Usage:
#Create a config_parm{eto_zone_1mm} with the number of seconds to distribute 1mm of water in the zone.
#Create a config_parm{eto_zone_crop} with 1's and 0's (1=grass, 0=shrubs/garden)
#Find your closest weatherunderground location and store it in config_parms{eto_location}
#Get your wu api key and store it in config_parms{wu_key}

#TODO
# - the safefloat and safeint subs are from python. don't know if they're needed

#VERIFY
# - line  430 sub getConditionsData chkcond array isn't checked yet
# - line   63 Use use JSON qw(decode_json) instead of JSON::XS
# - line  360 test timezone subroutine, confirm that it actually works
# - line  610 read in multiple water times for overall aggregate
# - line  711 when multiple times are scheduled, only one entry was written to the logs.

#WU Data elements mapping (useful if we want to look to another provider)
#$hist = $wuData->{history}->{dailysummary}[0];
#$wuData->{history}->{observations}
#$wuData->{history}->{observations}->[$period]->{date}->{hour}
#$wuData->{history}->{observations}->[$period]->{conds}

#$tzone = $data->{current_observation}->{local_tz_long};
#$mm  = $data->[$day]->{qpf_allday}->{mm};
#$cor = $data->[$day]->{pop};
#$rHour = safe_int( $data->{'sunrise'}->{'hour'}, 6 );
#$rMin  = safe_int( $data->{'sunrise'}->{'minute'} );
#$sHour = safe_int( $data->{'sunset'}->{'hour'}, 18 );
#$sMin  = safe_int( $data->{'sunset'}->{'minute'} );
#$conditions->{ $current->{weather} }
#$current->{wind_kph} ), 10 );
#$cTemp = safe_float( $current->{temp_c}, 20 );
#$cmm      = safe_float( $current->{precip_today_metric} );                            
#$predicted->{avewind}->{kph}   
#$pLowTemp = safe_float( $predicted->{low}->{celsius} );                               
#$pCoR     = safe_float( $predicted->{pop} );                                    
#$pmm      = safe_float( $predicted->{qpf_allday}->{mm} );   

use eto;
use LWP::UserAgent;
use HTTP::Request::Common;

#use JSON::XS;
use JSON qw(decode_json);
use List::Util qw(min max sum);

#use Data::Dumper;
use Time::Local;
use Date::Calc qw(Day_of_Year);
my $debug = 0;
my $msg_string;
my $rrd = "";
my $vc_eto = "";
my $ha_send_email_on_fail = 0;

$p_wu_forecast = new Process_Item
  qq[get_url --quiet "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/$config_parms{vc_location}?unitGroup=metric&key=$config_parms{vc_key}" "$config_parms{data_dir}/wuData/wu_data.json"];
##  qq[get_url --quiet ""];


$p_vc_et = new Process_Item
  qq[get_url --quiet "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/$config_parms{vc_location}?unitGroup=metric&elements=et0&key=$config_parms{vc_key}&contentType=json" "$config_parms{data_dir}/wuData/vc_eto_data.json"];
#  qq[get_url --quiet ""];


$v_get_eto           = new Voice_Cmd("Update ETO Programs");
$t_wu_forecast_timer = new Timer;

my $eto_data_dir = $config_parms{data_dir} . "/eto";
$eto_data_dir = $config_parms{eto_data_dir} if ( defined $config_parms{eto_data_dir} );

my $eto_calc_time = "3:00 AM";
$eto_calc_time = $config_parms{eto_calc_time} if ( defined $config_parms{eto_calc_time} );
$eto_calc_time = " " . $eto_calc_time         if ( $eto_calc_time =~ m/^\d:\d\d\s/ );        #time_now has a space in front if only a single digit hour

my $eto_retries = 3;
$eto_retries = $config_parms{eto_retries} if ( defined $config_parms{eto_retries} );
my $eto_retries_today;

$config_parms{eto_rainfallsatpoint} = 25     unless ( defined $config_parms{eto_rainfallsatpoint} );
$config_parms{eto_minmax}           = "5,15" unless ( defined $config_parms{eto_minmax} );

$debug = $Debug{eto} if defined $Debug{eto};

$osp_ha_object = new HA_Item( 'switch', $config_parms{eto_HAopensprinkler_program_name} . "_program_enabled|" . $config_parms{eto_HAopensprinkler_program_name} . "_.*_station_duration|" . $config_parms{eto_HAopensprinkler_program_name} . "_.*day_enabled|" . $config_parms{eto_HAopensprinkler_program_name} . "_start.*_time_offset|" . $config_parms{eto_HAopensprinkler_program_name} . "_start.*_time_offset_type", $ha_house, "delay_between_messages=4" ) if ((defined $config_parms{eto_irrigation}) and (lc $config_parms{eto_irrigation} eq "opensprinkler-ha"));
$ha_send_email_on_fail = 1 if ( defined $config_parms{eto_email} );

my $eto_ready;

if ( $Startup or $Reload ) {
    $eto_ready = 1;
    print_log "[calc_eto] v4.0 Startup.";
    print_log "[calc_eto] DEBUG Enabled" if ($debug);
    print_log "[calc_eto] Checking Configuration...";
    mkdir "$eto_data_dir"                  unless ( -d "$eto_data_dir" );
    mkdir "$eto_data_dir/ET"               unless ( -d "$eto_data_dir/ET" );
    mkdir "$eto_data_dir/logs"             unless ( -d "$eto_data_dir/logs" );
    mkdir "$config_parms{data_dir}/wuData" unless ( -d "$config_parms{data_dir}/wuData" );
    mkdir "$eto_data_dir/weatherprograms"  unless ( -d "$eto_data_dir/weatherprograms" );

    if ( defined $config_parms{eto_location} ) {
        print_log "[calc_eto] Location : $config_parms{eto_location}";
    }
    else {
        print_log "[calc_eto] ERROR! eto_location undefined!!";
        $eto_ready = 0;
    }
    if ( defined $config_parms{eto_zone_1mm} ) {
        print_log "[calc_eto] 1mm zone runtimes (in seconds) : $config_parms{eto_zone_1mm}";
    }
    else {
        print_log "[calc_eto] ERROR! eto_zone_1mm undefined!!";
        $eto_ready = 0;
    }
    if ( defined $config_parms{eto_zone_crop} ) {
        print_log "[calc_eto] 1mm crop definitions : $config_parms{eto_zone_crop}";
    }
    else {
        print_log "[calc_eto] ERROR! eto_zone_crop undefined!!";
        $eto_ready = 0;
    }
    if ( defined $config_parms{wu_key} ) {
        print_log "[calc_eto] ERROR! Weather Underground no longer supported. Need a Visual Crossing Key";
        $eto_ready = 0;
    }
    unless ( defined $config_parms{vc_key} ) {
        print_log "[calc_eto] ERROR! No Visual Crossing API key specified";
        $eto_ready = 0;
    }
    unless ( defined $config_parms{vc_location} ) {
        print_log "[calc_eto] ERROR! No Visual Crossing location specified";
        $eto_ready = 0;
    }    
    if ( defined $config_parms{eto_rrd} ) {
        if ($config_parms{eto_rrd} eq "metric") {
            print_log "[calc_eto] Will write daily rain to RRD (mms)";
            $rrd = "m";
        } elsif ($config_parms{eto_rrd} eq "in") {
            print_log "[calc_eto] Inches to RRD not supported yet";
            $rrd = "";
        } else {
            print_log "[calc_eto] Unknown RRD option $config_parms{eto_rrd}";
            $rrd = "";
        }
    }
    if ( defined $config_parms{eto_irrigation} ) {
        print_log "[calc_eto] $config_parms{eto_irrigation} set as programmable irrigation system";
    }
    else {
        print_log "[calc_eto] WARNING! no sprinkler system defined!";
    }  
    if ($eto_ready) {
        print_log "[calc_eto] Configuration good. ETo Calcuations Ready";
        print_log "[calc_eto] Will email results to $config_parms{eto_email}" if ( defined $config_parms{eto_email} );
    }
    else {
        print_log "[calc_eto] ERROR! ETo configuration problem. ETo will not calcuate";
    }
}

if ( ( said $v_get_eto) or ( $New_Minute and ( $Time_Now eq $eto_calc_time ) ) ) {
    if ($eto_ready) {
        print_log "[calc_eto] Starting Daily ETO Calculation Process...";
        $eto_retries_today = 0;
        start $p_wu_forecast;
        ##start $p_vc_et; disabled due to not being available through free license.
    }
    else {
        print_log "[calc_eto] ERROR! ETo configuration problem. ETo will not calcuate";
    }
}

#This requires a corporate license, so leave in the stub but don't enable VC ET
if ( done_now $p_vc_et) {
    my $write_secs = time() - ( stat("$config_parms{data_dir}/wuData/vc_eto_data.json") )[9];
    if ( $write_secs > 300 ) { 
        print_log "[calc_eto] Stale ETo Data, ignoring vc ETo. VC Data written $write_secs seconds ago...";
        $vc_eto = "Invalid"; 
    }
    else {
    }
    my $etdata;
    if ( open( my $fh, "$config_parms{data_dir}/wuData/vc_eto_data.json" ) ) {
        local $/;    #otherwise raw_data is empty?
        my $raw_etdata = <$fh>;

        #			eval { $data = JSON::XS->new->decode($raw_data) };
        eval { $etdata = decode_json($raw_etdata) };
        if ($@) {
            print_log "[calc_eto] ERROR Problem parsing et data vc_eto_data.json! $@\n";
        }
        close($fh);
    }
    else {
        print_log "[calc_eto] ERROR Problem opening er data vc_eto_data.json\n";
        close($fh);
    }
    print_log "[calc_eto] VC ET Data:\n";
    print Dumper $etdata;
    start $p_wu_forecast
}

if ( done_now $p_wu_forecast) {
    my $write_secs = time() - ( stat("$config_parms{data_dir}/wuData/wu_data.json") )[9];
    if ( $write_secs > 300 ) { 
        print_log "[calc_eto] Stale Data, not calculating ETo. WU Data written $write_secs seconds ago...";
    }
    else {
        my $program_data = &calc_eto_runtimes( $eto_data_dir, "file", $config_parms{eto_location}, "$config_parms{data_dir}/wuData/wu_data.json" );
        if ($program_data) {
            if ( defined $config_parms{eto_irrigation} ) {
                if ( lc $config_parms{eto_irrigation} eq "opensprinkler" ) {
                    my $os_program = &get_object_by_name( $config_parms{eto_opensprinkler_program} );
                    my ( $run_times, $run_seconds ) = $program_data =~ /\[\[(.*)\],\[(.*)\]\]/;
                    print_log "[calc_eto] Loading values $run_times,$run_seconds into Opensprinkler program $config_parms{eto_opensprinkler_program}";
                    $os_program->set_program( $Day, $run_times, $run_seconds );
                    
                } elsif  ( lc $config_parms{eto_irrigation} eq "opensprinkler-ha" ) {
                     print_log "[calc_eto] Loading values program_data into Home Assistant program $config_parms{eto_opensprinkler_program}";
                     my $ha_retries = 5;
                     $ha_retries = $config_parms{eto_HAopensprinkler_retries} if (defined $config_parms{eto_HAopensprinkler_retries});
                     my $ha_retry_delay = 120;
                     $ha_retry_delay = $config_parms{eto_HAopensprinkler_retry_delay} if (defined $config_parms{eto_HAopensprinkler_retry_delay});
                     update_osp_ha_entities( $program_data, $ha_retries, $ha_retry_delay );	
                } else {
                     print_log "[calc_eto] WARNING No irrigation system specified to upload program!";
		}
            }
        }
        else {
            if ( $eto_retries_today < $eto_retries ) {
                $eto_retries_today++;
                print_log "[calc_eto] WARNING! bad program data, retry attempt $eto_retries_today";
                set $t_wu_forecast_timer 600;
            }
            else {
                print_log "[calc_eto] ERROR! retry max $eto_retries reaches. Aborting calculation attempt";
            }
        }
    }
}

if ( expired $t_wu_forecast_timer) {
    start $p_wu_forecast;
}

#-------------------------------------------------------------------------------------------------------------------------------#
# Mapping of conditions to a level of shading.
# Since these are for sprinklers any hint of snow will be considered total cover (10)
# Don't worry about wet conditions like fog these are accounted for below we are only concerned with how much sunlight is blocked at ground level

our $conditions = {
    'clear'                        => 0,
    'partial fog'                  => 2,
    'patches of fog'               => 2,
    'haze'                         => 2,
    'shallow fog'                  => 3,
    'scattered clouds'             => 4,
    'unknown'                      => 5,
    'fog'                          => 5,
    'partly cloudy'                => 5,
    'partially cloudy'             => 5,
    'mostly cloudy'                => 8,
    'mist'                         => 10,
    'light drizzle'                => 10,
    'light freezing drizzle'       => 10,
    'light freezing rain'          => 10,
    'light freezing fog'           => 5,
    'light ice pellets'            => 10,
    'light rain'                   => 10,
    'light rain showers'           => 10,
    'light snow'                   => 10,
    'light snow grains'            => 10,
    'light snow showers'           => 10,
    'light thunderstorms and rain' => 10,
    'low drifting snow'            => 10,
    'rain'                         => 10,
    'rain showers'                 => 10,
    'snow'                         => 10,
    'snow showers'                 => 10,
    'thunderstorm'                 => 10,
    'thunderstorms and rain'       => 10,
    'blowing snow'                 => 10,
    'chance of snow'               => 10,
    'freezing rain'                => 10,
    'unknown precipitation'        => 10,
    'overcast'                     => 10,
};

# List of precipitation conditions we don't want to water in, the conditions will be checked to see if they contain these phrases.

our $chkcond = {
    'flurries' => 1,
    'rain'     => 1,
    'sleet'    => 1,
    'snow'     => 1,
    'storm'    => 1,
    'hail'     => 1,
    'ice'      => 1,
    'squall'   => 1,
    'precip'   => 1,
    'funnel'   => 1,
    'drizzle'  => 1,
    'mist'     => 1,
    'freezing' => 1,
};

#
################################################################################
# -[ Functions ]----------------------------------------------------------------

# define safe functions for variable conversion, preventing errors with NaN and Null as string values
# 's'=value to convert 'dv'=value to default to on error make sure this is a legal float or integer value

#just stub for testing, have to fix up the floats and int
sub safe_float {
    my ( $arg, $val ) = @_;

    #	$val = "0.0" unless ($val);
    #	$arg = $val unless ($arg);
    return ($arg);
}

sub safe_int {
    my ( $arg, $val ) = @_;

    #	$val = "0" unless ($val);
    #	$arg = $val unless ($arg);
    return ($arg);
}

sub isInt {
    my ($arg) = @_;
    return ( $arg - int($arg) ) ? 0 : 1;
}

sub isFloat {
    my ($arg) = @_;
    return 1;

    #return ($arg - int($arg))? 1 : 0;
}

sub round {
    my ( $number, $places ) = @_;
    my $sign = ( $number < 0 ) ? '-' : '';
    my $abs = abs($number);

    if ( $places < 0 ) {
        print_log "[calc_eto] ERROR! rounding to $places";
        return $number;
    }
    else {
        my $p10 = 10**$places;
        return $sign . int( $abs * $p10 + 0.5 ) / $p10;
    }
}

sub findwuLocation {
    my ($loc) = @_;
    my ( $whttyp, $ploc, $noData, $tzone, $lat, $lon );
    my $ua = new LWP::UserAgent( keep_alive => 1 );

    my $request = HTTP::Request->new( GET => "http://autocomplete.wunderground.com/aq?format=json&query=$loc" );
    my $responseObj = $ua->request($request);
    my $data;

    #    eval { $data = JSON::XS->new->decode( $responseObj->content ); };
    eval { $data = decode_json( $responseObj->content ); };
    my $responseCode      = $responseObj->code;
    my $isSuccessResponse = $responseCode < 400;
    if ( $isSuccessResponse and defined $data->{RESULTS} ) {
        my $chk = $data->{RESULTS}->[0]->{ll};    # # ll has lat and lon in one spot no matter how we search
        if ($chk) {
            my @ll = split( ' ', $chk );
            if ( scalar(@ll) == 2 and isFloat( $ll[0] ) and isFloat( $ll[1] ) ) {
                $lat = $ll[0];
                $lon = $ll[1];
            }
        }

        $chk = $data->{RESULTS}->[0]->{tz};
        if ($chk) {
            $tzone = $chk;
        }
        else {
            my $chk2 = $data->{RESULTS}->[0]->{tz_long};
            if ($chk2) {
                $tzone = $chk2;
            }
            else {
                $tzone = "None";
            }
        }

        $chk = $data->{RESULTS}->[0]->{name};    # # this is great for showing a pretty name for the location
        if ($chk) {
            $ploc = $chk;
        }

        $chk = $data->{RESULTS}->[0]->{type};
        if ($chk) {
            $whttyp = $chk;
        }

    }
    else {
        $noData = 1;
        $lat    = "None";
        $lon    = "None";
        $tzone  = "None";
        $ploc   = "None";
        $whttyp = "None";
    }
    return ( $whttyp, $ploc, $noData, $tzone, $lat, $lon );
}

sub getwuData {
    my ( $loc, $key ) = @_;
    my $tloc = split( ',', $loc );

    #return if ($key == '' or (scalar ($tloc) < 2));
    my $ua = new LWP::UserAgent( keep_alive => 1 );

    my $request = HTTP::Request->new( GET => "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/$config_parms{vc_location}?unitGroup=metric&key=$config_parms{vc_key}" );

    my $responseObj = $ua->request($request);
    my $data;

    #   eval { $data = JSON::XS->new->decode( $responseObj->content ); };
    eval { $data = decode_json( $responseObj->content ); };
    if ($@) {
        print_log "[calc_eto] ERROR problem parsing json from web call";
    }
    my $responseCode      = $responseObj->code;
    my $isSuccessResponse = $responseCode < 400;
    print "code=$responseCode\n" if ($debug);

    return ($data);

}

sub getwuDataTZOffset {
    my ( $data, $tzone ) = @_;

    #HP TODO - I'm not sure if this works as expected
    if ( $tzone eq "None" or $tzone eq "" ) {
        $tzone = $data->{tzoffset};
    }
    my $tdelta;

    if ($tzone) {
        my @tnow = localtime(time);
        $tdelta = timegm(@tnow) - timelocal(@tnow);

        #            tdelta = tnow.astimezone(pytz.timezone(tz)).utcoffset()
    }
    if ($tdelta) {
        return ( { 't' => ( $tdelta / 900 + 48 ), 'gmt' => ( $tdelta / 3600 ) } );
    }
    else {
        return ( { 't' => "None", 'gmt' => "None" } );
    }
}

# Calculate an adjustment based on predicted rainfall
# Rain forecast should lessen current watering and reduce rain water runoff, making the best use of rain.
# returns tadjust (???)
sub getForecastData {
    my ($data) = @_;

    #HP TODO - I don't know why the python wanted to create a bunch of arrays (mm, cor, wfc). It seems like
    #HP TODO -  just the end result is needed

#print Dumper $data->{days};

    if ( @{ $data->{days} } ) {


        my $fadjust = 0;
#        for ( my $day = 1; (($day < scalar( @{ $data->{days} }) and ($day < 4)); $day++ ) { #only look 4 days out
        for ( my $day = 1; ($day < scalar( @{ $data->{days} }) and ($day < 4)); $day++ ) { #only look 4 days out

            my $mm  = $data->{days}->[$day]->{precip};
            my $cor = $data->{days}->[$day]->{precipprob};
            my $wfc = 1 / $day**2;                         #HP I assume this is to modify that further days out are more volatile?
            $fadjust += safe_float( $mm, -1 ) * ( safe_float( $cor, -1 ) / 100 ) * safe_float( $wfc, -1 );
            print "gfd mm=$mm cor=$cor wfc=$wfc fa=$fadjust\n" if ($debug);
        }
        return $fadjust;
    }
    return -1;
}

# Grab the sunrise and sunset times in minutes from midnight
sub getAstronomyData {
    my ($data) = @_;

    if ( not $data ) {
        return ( { "rise" => -1, "set" => -1 } );
    }

    my $rHour = ( localtime($data->{currentConditions}->{sunriseEpoch}))[2];
    my $rMin  = ( localtime($data->{currentConditions}->{sunriseEpoch}))[1];
    my $sHour = ( localtime($data->{currentConditions}->{sunsetEpoch}))[2];
    my $sMin  = ( localtime($data->{currentConditions}->{sunsetEpoch}))[1];
    if ( $rHour, $rMin, $sHour, $sMin ) {
        return ( { "rise" => $rHour * 60 + $rMin, "set" => $sHour * 60 + $sMin } );
    }
    else {
        return ( { "rise" => -1, "set" => -1 } );
    }
}

# Let's check the current weather and make sure the wind is calm enough, it's not raining, and the temp is above freezing
# We will also look at what the rest of the day is supposed to look like, we want to stop watering if it is going to rain,
# or if the temperature will drop below freezing, as it would be bad for the pipes to contain water in these conditions.
# Windspeed for the rest of the day is used to determine best low wind watering time.

sub getConditionsData {
    my ( $current, $predicted, $conditions ) = @_;

    my $nowater = 1;
    my $whynot  = 'Unknown';
    unless ( $current and $predicted ) {
        return ( 0, 1, 'No conditions data' );
    }

    my $cWeather = "";
    $cWeather = safe_float( $conditions->{ $current->{conditions} }, 5 );

    unless ( defined $conditions->{ $current->{conditions} } ) {

        # check if any of the chkcond words exist in the $current-{weather}

        my $badcond = 0;
        foreach my $chkword ( split( ' ', lc $current->{conditions} ) ) {
            $badcond = 1 if ( defined $chkcond->{$chkword} );
        }

        #		if (defined $conditions->{$current->{weather}} ) {
        if ($badcond) {
            $cWeather = 10;
        }
        else {
#            print_log '[calc_eto] INFO Cound not find current conditions ' . $current->{conditions};
            $cWeather = 5;
        }
    }

    my $cWind = &eto::wind_speed_2m( safe_float( $current->{windspeed} ), 10 );
    my $cTemp = safe_float( $current->{temp}, 20 );

    # current rain will only be used to adjust watering right before the start time

    my $cmm      = safe_float( $current->{precip} );                            # Today's predicted rain (mm)
    my $pWind    = &eto::wind_speed_2m( safe_float( $predicted->{windspeed} ), 10 );    # Today's predicted wind (kph)
    my $pLowTemp = safe_float( $predicted->{tempmin} );                               # Today's predicted low  (C)
    my $pCoR     = safe_float( $predicted->{precipprob} ) / 100;                                    # Today's predicted POP  (%)  (Probability of Precipitation)
    my $pmm      = safe_float( $predicted->{precip} );                             # Today's predicted QFP  (mm) (Quantitative Precipitation Forecast)
                                                                                             #

    # Let's check to see if it's raining, windy, or freezing.  Since watering is based on yesterday's data
    # we will see how much it rained today and how much it might rain later today.  This should
    # help reduce excess watering, without stopping water when little rain is forecast.

    $nowater = 0;
    $whynot  = '';

    # Its precipitating
    #HP TODO - this triggered on 'Clear'?
    if ( $cWeather == 10 and lc $current->{conditions} ne 'overcast' ) {
        $nowater = 1;
        $whynot .= 'precipitation (' . $current->{conditions} . ') ';
    }

    # Too windy
    if ( $cWind > $pWind and $pWind > 6 or $cWind > 8 ) {
        $nowater = 1;
        $whynot .= 'wind (' . round( $cWind, 2 ) . ' kph) ';
    }

    # Too cold
    if ( $cTemp < 4.5 or $pLowTemp < 1 ) {
        $nowater = 1;
        $whynot .= 'cold (current ' . round( $cTemp, 2 ) . ' C / predicted ' . round( $pLowTemp, 2 ) . ' C) ';
    }

    $cmm += $pmm * $pCoR if ($pCoR);

    #HP TODO  - Don't know where this except comes from
    #HP    except:
    #HP        print 'we had a problem and just decided to water anyway'
    #HP        nowater = 0
    #
    #print "[$cmm,$nowater,$whynot]\n";
    return ( $cmm, $nowater, $whynot );
}

sub sun_block {

    # Difference from Python script. If there are multiple forecasts for a given hour (ie overcast and scattered clouds), then it will
    # take the last entry for calculating cover. Could average it, but really the difference isn't that huge I don't think.
    my ( $wuData, $sunrise, $sunset, $conditions ) = @_;
    my $sh                 = 0;
    my $previousCloudCover = 0;

    for ( my $hour = int( $sunrise / 60 ); $hour < int( $sunset / 60 + 1 ); $hour++ ) {

        # Set a default value so we know we found missing data and can handle the gaps
        my $cloudCover = -1;

        # Now let's find the data for each hour there are more periods than hours so only grab the first
        #in range(len(wuData['history']['observations'])):
        for ( my $period = 0; $period < 23 ; $period++ ) {
            if ( (localtime($wuData->{days}->[0]->{hours}->[$period]->{datetimeEpoch}))[2] == $hour ) {
                if ( $wuData->{days}->[0]->{hours}->[$period]->{conditions} ) {
                    $cloudCover = safe_float( $conditions->{ lc $wuData->{days}->[0]->{hours}->[$period]->{conditions} }, 5 ) / 10;
                    print "CC1 [$hour,"
                      . lc $wuData->{days}->[0]->{hours}->[$period]->{conditions} . ","
                      . $conditions->{ lc $wuData->{days}->[0]->{hours}->[$period]->{conditions} } . "] cloudCover=$cloudCover\n" if ($debug);
                    unless ( defined $conditions->{ lc $wuData->{days}->[0]->{hours}->[$period]->{conditions} }  ) {
                        $cloudCover = 1;
                        print_log '[calc_eto] INFO Sun Block Condition not found ' . $wuData->{days}->[0]->{hours}->[$period]->{conditions};
                    }
                }
            }
        }

        # Found nothing, let's assume it was the same as last hour
        $cloudCover = $previousCloudCover if ( $cloudCover == -1 );
        print "CC2 [hour=$hour,cond=$cloudCover]\n" if ($debug);
        #

        $previousCloudCover = $cloudCover;

        # Got something now? let's check
        $sh += 1 - $cloudCover if ( $cloudCover != -1 );
        print "total sh=$sh cloudcover=$cloudCover\n" if ($debug);

    }
    return ($sh);
}

sub getHourlyElements {

    # Difference from WU data. DarkSkies has humidity forecast every hour, so look forward 24 hours to find the min and max.
        # take the last entry for calculating cover. Could average it, but really the difference isn't that huge I don't think.
    my ( $wuData) = @_;
    my ($rh_min, $rh_max);
    my $meanwindspeed = 0;

    $rh_min = $wuData->{days}->[0]->{hours}->[0]->{humidity}; 
    $rh_max = $wuData->{days}->[0]->{hours}->[0]->{humidity}; 

    for ( my $period = 1; $period < 23 ; $period++ ) {
        $rh_min = $wuData->{days}->[0]->{hours}->[$period]->{humidity} if ($wuData->{days}->[0]->{hours}->[$period]->{humidity} < $rh_min);
        $rh_max = $wuData->{days}->[0]->{hours}->[$period]->{humidity} if ($wuData->{days}->[0]->{hours}->[$period]->{humidity} > $rh_max); 
        $meanwindspeed +=  $wuData->{days}->[0]->{hours}->[$period]->{windspeed};
        print "RH min $rh_min max $rh_max  ws $meanwindspeed\n" if ($debug);
        
    }

    my $rh_mean       = ( $rh_min + $rh_max ) / 2;
    $meanwindspeed = $meanwindspeed / 24;
    return ( $rh_min, $rh_max, $rh_mean, $meanwindspeed );
}

# We need to know how much it rained yesterday and how much we watered versus how much we required
sub mmFromLogs {
    my ( $_1mmProg, $logsPath, $ETPath ) = @_;

    my $prevLogFname = int( ( time - ( time % 86400 ) - 1 ) / 86400 );

    #look that the $prevLogFname exists for both logs and ET. if not look for up to 7 days back for a
    #day that they both exist
    my $tmpLogFname = $prevLogFname;
    my $fnamefound  = 0;
    for ( my $fx = $tmpLogFname; $fx > $tmpLogFname - 7; $fx-- ) {
        print "***** Looking for $fx\n" if ($debug);
        if ( ( -e "$logsPath/$fx" ) and ( -e "$ETPath/$fx" ) ) {
            print "log file found $fx\n" if ($debug);
            $prevLogFname = $fx;
            $fnamefound   = 1;
            last;
        }
    }
    print_log "[calc.eto] WARNING! Couldn't find log/ET files less than 7 days old" unless ($fnamefound);

    my $nStations = scalar( @{ $_1mmProg->{mmTime} } );

    my @ydur = (-1) x $nStations;
    my @ymm  = (-1) x $nStations;

    my @yET = ( 0, 0 );    # Yesterday's Evap (evapotranspiration, moisture losses mm/day)
    my @tET = ( 0, 0 );

    # -[ Logs ]-----------------------------------------------------------------
    my @logs = ();

    if ( open( FILE, "$logsPath/$prevLogFname" ) ) {
        my $d_logs = <FILE>;
        my $t_logs;

        #		eval { $t_logs = JSON::XS->new->decode($d_logs) };
        eval { $t_logs = decode_json($d_logs); };
        @logs = @$t_logs;
        close(FILE);
    }
    else {
        print_log "[calc_eto] WARNING Can't open file $logsPath/$prevLogFname!";
        close(FILE);
    }

    ### the original code first looked for yesterday's log file and used that
    ### filename to get the json from ETPath and LogsPath.
    ### I simply check for yesterday's files and if I get an exception I create
    ### default vaules of 0 (in the appropriate array format)
    ### We now look 7 days back to find the last file. If nothing exists for 7 days, then use 0's

    # -[ ET ]-------------------------------------------------------------------
    if ( open( FILE, "$ETPath/$prevLogFname" ) ) {
        my $d_yET = <FILE>;
        my $t_yET;

        #		eval { $t_yET = JSON::XS->new->decode($d_yET) };
        eval { $t_yET = decode_json($d_yET) };
        @yET = @$t_yET;
        close(FILE);
    }
    else {
        print_log "[calc_eto] WARNING Can't open file $ETPath/$prevLogFname!";
        close(FILE);
    }

    # add all the run times together (a zone can have up to 4 daily runtimes) to get the overall amount of water
    for ( my $x = 0; $x < scalar(@logs); $x++ ) {
        $ydur[ $logs[$x][1] ] += $logs[$x][2];
        print "[logs[$x][2] = " . $logs[$x][2] . " ydur[$logs[$x][1]] = " . $ydur[ $logs[$x][1] ] . "]\n" if ($debug);
    }

    for ( my $x = 0; $x < $nStations; $x++ ) {
        if ( $_1mmProg->{mmTime}[$x] ) {

            # 'mmTime': [15, 16, 20, 10, 30, 30] sec/mm
            # 'crop': [1, 1, 1, 1, 0, 0] 1 = grasses, 0 = shrubs
            #ymm[x] = round( (safe_float(yET[safe_int(_1mmProg['crop'][x])])) - (ydur[x]/safe_float(_1mmProg['mmTime'][x])), 4) * (-1)
            # Rewritten to make it readable (nothing more)
            my $yesterdaysET       = safe_float( $yET[ safe_int( $_1mmProg->{crop}[$x] ) ] );    # in seconds
            my $yesterdaysDuration = $ydur[$x];                                                  # in mm
            my $mmProg             = safe_float( $_1mmProg->{mmTime}[$x] );                      # in seconds/mm
                 # ymm = yET - (ydur / mmTime)  // mm - (sec / sec/mm) Units look correct!
            $ymm[$x] = round( ( $yesterdaysET - ( $yesterdaysDuration / $mmProg ) ), 4 ) * (-1);
            $tET[ int( $_1mmProg->{crop}[$x] ) ] = $ymm[$x];
            print "[$x yesterdaysET=$yesterdaysET yesterdaysDuration=$yesterdaysDuration mmProg=$mmProg ymm[$x] = "
              . $ymm[$x] . " tET["
              . int( $_1mmProg->{crop}[$x] ) . "] = "
              . $ymm[$x] . "]\n"
              if ($debug);
            print "E:   $x $ymm[$x] = ( " . $yET[ $_1mmProg->{crop}[$x] ] . " ) - ( $ydur[$x] / " . $_1mmProg->{mmTime}[$x] . " ) * -1\n" if ($debug);
            print "E:   $x _1mmProg['crop'][$x] = " . $_1mmProg->{crop}[$x] . "\n"                                                        if ($debug);
            print "E:   $x tET[" . int( $_1mmProg->{crop}[$x] ) . "] = " . $tET[ int( $_1mmProg->{crop}[$x] ) ] . "\n"                    if ($debug);
        }
        else {
            $ymm[$x] = 0;
        }
    }

    print "E: Done - mmFromLogs\n" if ($debug);
    return ( \@ymm, \@tET );
}

sub writeResults {
    my ( $ETG, $ETS, $sun, $todayRain, $tadjust, $noWater, $logsPath, $ETPath, $WPPath ) = @_;

    my @ET = ( $ETG, $ETS );
    my $msg;
    my $pid = 2;    #for legacy purposes, can probably remove it, but for now want the log files
                    #to be similar to keep the file structure the same to validate against python
    my $data_1mm;

    # Get 1mm & crop data from config_parms
    @{ $data_1mm->{mmTime} } = split( /,/, $config_parms{eto_zone_1mm} );
    @{ $data_1mm->{crop} }   = split( /,/, $config_parms{eto_zone_crop} );

    my @minmax;
    if ( defined $config_parms{eto_minmax} ) {
        @minmax = split( /,/, $config_parms{eto_minmax} );
    }
    else {
        @minmax = ( 5, 15 );
    }

    my $fname = int( (time) / 86400 );

    my $minRunmm = 5;
    $minRunmm = min @minmax if ( scalar(@minmax) > 0 ) and ( ( min @minmax ) >= 0 );
    my $maxRunmm = 15;
    $maxRunmm = max @minmax if ( scalar(@minmax) > 1 ) and ( ( max @minmax ) >= $minRunmm );
    my $times = 0;

    my ( $ymm, $yET ) = mmFromLogs( $data_1mm, $logsPath, $ETPath );

    print "ymm = " . join( ',', @$ymm ) . "\n" if ($debug);
    print "yET = " . join( ',', @$yET ) . "\n" if ($debug);

    my @tET = [0] x scalar(@ET);

    for ( my $x = 0; $x < scalar(@ET); $x++ ) {
        print "[ET[$x] = $ET[$x] yET[$x] = @$yET[$x]]\n" if ($debug);
        $ET[$x] -= @$yET[$x];
    }

    my @runTime = ();
    for ( my $x = 0; $x < scalar( @{ $data_1mm->{mmTime} } ); $x++ ) {
        my $aET      = safe_float( $ET[ $data_1mm->{crop}[$x] ] - $todayRain - @$ymm[$x] - $tadjust );    # tadjust is global ?
        my $pretimes = $times;

        #HP TODO This will determine if a 2nd, 3rd or 4th time is required.
        $times = 1 if ( ( $aET / $minRunmm ) > 1 );    #if the minium threshold is met, then run at least once.
        $times = int( max( min( $aET / $maxRunmm, 4 ), $times ) );    # int(.999999) = 0
        print "[calc_eto] DB: times=$times aET=$aET minRunm=$minRunmm maxRunm=$maxRunmm\n" if ($debug);
        print "E:   aET[$x] = $aET (" . $aET / $maxRunmm . ") // mm/Day\n" if ($debug);
        print "E:   times = $times (max "
          . max( min( $aET / $maxRunmm, 4 ), $times ) . "/min "
          . min( $aET / $maxRunmm, 4 )
          . " max(min("
          . $aET / $maxRunmm
          . ", 4), $pretimes))\n"
          if ($debug);
        #
        #
        # @FIXME: this is way too hard to read

        #            runTime.append(min(max(safe_int(data['mmTime'][x] * ((aET if aET >= minRunmm else 0)) * (not noWater)), 0), \
        #                                   safe_int(data['mmTime'][x]) * maxRunmm))
        my $tminrun = safe_int( $data_1mm->{mmTime}[$x] );
        $tminrun = 0 unless $aET >= $minRunmm;
        $tminrun = int( $tminrun * $aET );
        $tminrun = 0 if $noWater;
        my $tmaxrun = safe_int( $data_1mm->{mmTime}[$x] ) * $maxRunmm;
        print "E: HP mmTime = " . $data_1mm->{mmTime}[$x] . " tminrun=$tminrun tmaxrum=$tmaxrun\n" if ($debug);
        push( @runTime, min( $tminrun, $tmaxrun ) );
    }

    # #########################################
    # # Real logs will be written already    ##
    # #########################################

    print "runTime count [" . scalar(@runTime) . "]\n" if ($debug);
    if ( open( FILE, ">$logsPath/$fname" ) ) {
        my $logData = "[";
        for ( my $x = 0; $x < scalar(@runTime); $x++ ) {
            for ( my $y = 0; $y < $times; $y++ ) {
                my $delim = "";
                $delim = ", " unless ( ( $x == 0 ) and ( $y == 0 ) );
                $logData .= $delim . "[$pid, $x, " . $runTime[$x] . "]";
            }
        }
        $logData .= "]";
        print FILE $logData;
        close(FILE);
    }
    else {
        print_log "[calc_eto] ERROR Can't open log file $logsPath/$fname!";
        close(FILE);
    }

    # #########################################
    # # Write final daily water balance      ##
    # #########################################
    if ( open( FILE, ">$ETPath/$fname" ) ) {
        my $Data = "[";
        for ( my $x = 0; $x < scalar(@ET); $x++ ) {
            my $delim = "";
            $delim = ", " unless $x == 0;
            $Data .= $delim . $ET[$x];
        }
        $Data .= "]";
        print FILE $Data;
        close(FILE);
    }
    else {
        print_log "[calc_eto] ERROR Can't open ET file $ETPath/$fname!";
        close(FILE);
    }

    # ##########################################

    #HP - ok, this is explained by the opensprinker setup, a program can have up to 4 runtimes
    #HP - useful to avoid grass saturation. So if really dry and needs lots of moisture, then run
    #HP - multiple programs
    #HP - also set the number of times to water to 0 if $noWater is set.
    $times = 0 if ($noWater);

    my @startTime = (-1) x 4;
    my @availTimes = ( $sun->{rise} - sum(@runTime) / 60, $sun->{rise} + 60, $sun->{set} - sum(@runTime) / 60, $sun->{set} + 60 );

    #if the current time is after $sun->{rise} then add two more options to $sun->{set}
    if (time_greater_than($Time_Sunrise)) {
        print_log "[calc_eto] It's after sunrise, so run extra programs at night";
        @availTimes = ($sun->{set} - sum(@runTime) / 60, $sun->{set} + 60, $sun->{set} + 120, $sun->{set} - (sum(@runTime) / 60) - 60 );         
    }

    print "[times=$times, sun->{rise}=" . $sun->{rise} . " sum=" . sum(@runTime) / 60 . "]\n" if ($debug);

    for ( my $i = 0; $i < $times; $i++ ) {
        $startTime[$i] = int( $availTimes[$i] );
    }
    my $runTime_str = "[[" . join( ',', @startTime ) . "],[" . join( ',', @runTime ) . "]]";
    $msg = "[calc_eto] Current logged ET [" . join( ',', @ET ) . "]";
    print_log $msg;
    $msg_string .= $msg . "\n";
    $msg = "[calc_eto] Current 1mm times [" . join( ',', @{ $data_1mm->{mmTime} } ) . "]";
    print_log $msg;
    $msg_string .= $msg . "\n";
    $msg = "[calc_eto] Current Calc time $runTime_str";
    print_log $msg;
    $msg_string .= $msg . "\n";

    if ( open( FILE, ">$WPPath/run" ) ) {
        ;
        print FILE $runTime_str;
        close(FILE);
    }
    else {
        print_log "[calc_eto] ERROR Can't open run file $WPPath/run!";
        close(FILE);
    }
    return $runTime_str;
}

# -[ Data ]---------------------------------------------------------------------

sub writewuData {
    my ( $wuData, $noWater, $wuDataPath ) = @_;
    my $fname = int( ( time - ( time % 86400 ) - 1 ) / 86400 );
    if ( open( FILE, ">$wuDataPath/$fname" ) ) {
        print FILE "observation_epoch, " . $wuData->{currentConditions}->{datetimeEpoch} . "\n";
        print FILE "weather, " . $wuData->{currentConditions}->{conditions} . "\n";
        print FILE "temp, " . $wuData->{currentConditions}->{temp} . "\n";
        print FILE "relative_humidity, " . $wuData->{currentConditions}->{humidity} . "\n";
        print FILE "wind_degrees, " . $wuData->{currentConditions}->{winddir} . "\n";
        print FILE "wind_speed, " . $wuData->{currentConditions}->{windspeed} . "\n";
        print FILE "precip_chance, " . $wuData->{currentConditions}->{precipprob} . "\n";
        print FILE "precipitation, " . $wuData->{currentConditions}->{precip} . "\n";
        print FILE "noWater, " . $noWater . "\n";
        close(FILE);
    }
    else {
        print_log "[calc_eto] WARNING Can't open wuData file $wuDataPath/$fname for writing!\n";
    }
}

#calc_eto_runtimes(".","wu",$config_parms{eto_location},$config_parms{wu_key});
sub calc_eto_runtimes {
    my ( $datadir, $method, $loc, $arg1, $arg2 ) = @_;
    my ( $rt, $data );
    my $success = 0;
    if ( lc $method eq "file" ) {
        if ( open( my $fh, "$arg1" ) ) {
            local $/;    #otherwise raw_data is empty?
            my $raw_data = <$fh>;

            #			eval { $data = JSON::XS->new->decode($raw_data) };
            eval { $data = decode_json($raw_data) };
            if ($@) {
                print_log "[calc_eto] ERROR Problem parsing data $arg1! $@\n";
            }
            else {
                $success = 1;
            }
            close($fh);
        }
        else {
            print_log "[calc_eto] ERROR Problem opening data $arg1\n";
            close($fh);
        }
    }
    elsif ( lc $method eq "wu" ) {
        $data = getwuData( $loc, $arg1 );
        $success = 1 if ($data);
    }
    if ($success) {
        $rt = main_calc_eto( $datadir, $loc, $data );
    }
    else {
        print_log "[calc_eto] ERROR Data not available.\n";
    }
    return $rt;
}

sub detailSchedule {
    my ($stime) = @_;
    my ($times, $lengths) = $stime =~ /\[\[(.*)\],\[(.*)\]\]/;
    my $msg = "";
    my $total_time = 0;
    foreach my $time (split /,/, $times) {
        next if ($time == -1); 
        my $station_id = 1;
        $time = $time * 60; #add in seconds
        foreach my $station (split /,/, $lengths) {
            $total_time += $station;
            my $run_hour = 0;
            if ($station > 3600) {
                $run_hour = int($station / 3600);
                $station = int($station % 3600);
            }
            my $run_min = int($station / 60);
            my $run_sec = int($station % 60);
            $msg .= "[calc_eto] : " . formatTime($time) . " : Station:" .sprintf("%2s",$station_id) . "   Run Time:" .sprintf("%02d:%02d:%02d",$run_hour,$run_min,$run_sec) . "\n" unless ($station == 0);
            $station_id++;
            $time += $run_sec + ($run_min * 60) + ($run_hour * 3600);
        }  
        if ($total_time > 0) {
            my $t_hours = 0;
            if ($total_time > 3600) {
                $t_hours = int($total_time / 3600);
                $total_time = int($total_time % 3600);
            }
            my $t_min = int($total_time / 60);
            my $t_sec = int($total_time % 60);
            $msg .= "[calc_eto] : Total Run Time: " . sprintf("%02d:%02d:%02d",$t_hours,$t_min,$t_sec) . "\n"; 
        }  
    }
    return ($msg);
    
    sub formatTime {
        my ($t) = @_;
        my $hour = int($t / 3600);
        my $min = int(($t % 3600) / 60);
        my $sec = int(($t % 3600) % 60);
        my $ampm = "AM";
        if ($hour > 12) {
            $ampm = "PM";
            $hour = $hour - 12;
        }
        return(sprintf("%2s:%02d:%02d",$hour,$min,$sec) . " $ampm"); 
    }  
}

sub main_calc_eto {
    my ( $datadir, $loc, $wuData ) = @_;

    # -[ Init ]---------------------------------------------------------------------
    $msg_string = "";
    my $msg;
    $datadir .= '/' unless ( ( substr( $datadir, -1 ) eq "/" ) or ( substr( $datadir, -1 ) eq "\\" ) );
    my $logsPath   = $datadir . 'logs';
    my $ETPath     = $datadir . 'ET';
    my $wuDataPath = "$config_parms{data_dir}/wuData";
    my $WPPath     = $datadir . 'weatherprograms';

    my $tzone;

    my $rainfallsatpoint = 25;
    $rainfallsatpoint = $config_parms{eto_rainfallsatpoint} if ( defined $config_parms{eto_rainfallsatpoint} );

#########################################
## We need your latitude and longitude ##
## Let's try to get it with no api call##
#########################################

    # Hey we were given what we needed let's work with it
    our ( $lat, $t1, $lon ) = $loc =~ /^([-+]?\d{1,2}([.]\d+)?),\s*([-+]?\d{1,3}([.]\d+)?)$/;
    $lat = "None" unless ($lat);
    $lon = "None" unless ($lon);

    # We got a 5+4 zip code, we only need the 5
    $loc =~ s/\-\d\d\d\d//;
    #

    # We got a pws id, we don't need to tell wunderground,
    # they know how to deal with the id numbers
    $loc =~ s/'pws:'//;
    #

    # Okay we finally have our loc ready to look up
    my $noData = 0;
    my ( $whttyp, $ploc );
    if ( $lat eq "None" and $lon eq "None" ) {
        ( $whttyp, $ploc, $noData, $tzone, $lat, $lon ) = findwuLocation($loc);
    }

    # Okay if all went well we got what we needed and snuck in a few more items we'll store those somewhere

    if ( $lat and $lon ) {
        if ( $lat and $lon and $whttyp and $ploc ) {
            print_log "[calc_eto] INFO For the $whttyp named: $ploc the lat, lon is: $lat, $lon, and the timezone is $tzone";
        }
        else {
            print_log "[calc_eto] INFO Resolved your lat:$lat, lon:$lon";
        }
        $loc = $lat . ',' . $lon;
    }
    else {
        if ($noData) {
            print_log "[calc_eto] ERROR couldn't reach Weather Underground check connection";
        }
        else {
            print_log "[calc_eto] ERROR $loc can't resolved try another location";
        }
    }

    # -[ Main ]---------------------------------------------------------------------

    our ($offsets) = getwuDataTZOffset( $wuData, $tzone );

    unless ($wuData) {
        print_log "[calc_eto] ERROR WU data appears to be empty, exiting";
        return "[[-1,-1,-1,-1],[0]]";
    }

    # Calculate an adjustment based on predicted rainfall
    my $tadjust = getForecastData( $wuData );
    my $sun     = getAstronomyData( $wuData );
    my ( $todayRain, $noWater, $whyNot ) =
      getConditionsData( $wuData->{currentConditions}, $wuData->{days}[0], $conditions );

######################## Quick Ref Names For wuData ########################################
    my $hist = $wuData->{days}[0];

########################### Required Data ##################################################
    $lat = safe_float($lat);
    my $tmin          = safe_float( $hist->{tempmin} );
    my $tmax          = safe_float( $hist->{tempmax} );
    my $tmean         = ( $tmin + $tmax ) / 2;
    my $alt           = 0 ; #TODOv3 Find Elevation
    my $tdew          = safe_float( $hist->{dew} );

   my ($cday,$cmon,$cyear) = (localtime($hist->{datetimeEpoch}))[3,4,5];
    #it looks like a 0 is the same as undef, so if $cmon == 0 then add 1.
    $cmon++ if ($cmon == 0);    

    if ($cday == undef || $cmon == undef || $cyear == undef) {
        #problem with the data
        my $msg = "[calc_eto] ERROR: Bad Data received from Provider. A date field is empty";
        print_log $msg;
        my $msg2 = "[calc_eto] ERROR: Undefined Parameter: Year=[$cyear] Month=[$cmon] Day=[$cday]"; 
        print_log $msg2;
        if ( defined $config_parms{eto_email} ) {
            print_log "[calc_eto] Emailing Error";
            net_mail_send( to => $config_parms{eto_email}, subject => "EvapoTranspiration Failed to retrieve data", text => $msg . "\n" . $msg2 );
        }
        return "[[-1,-1,-1,-1],[0]]";    
    }
    $cmon++ unless ($cmon == 1); #timelocal months start at 0, don't double adjust for january
    $cyear += 1900;
    
    my $doy           = Day_of_Year( $cyear, $cmon, $cday );
    my $sun_hours     = sun_block( $wuData, ((localtime($wuData->{currentConditions}->{sunriseEpoch}))[2] * 60 + (localtime($wuData->{currentConditions}->{sunriseEpoch}))[1]), ((localtime($wuData->{currentConditions}->{sunsetEpoch}))[2] * 60 + (localtime($wuData->{currentConditions}->{sunsetEpoch}))[1]), $conditions );
    my ($rh_min, $rh_max, $rh_mean, $meanwindspeed) = getHourlyElements($wuData);
#    my $rh_min        = safe_float( $hist->{minhumidity} );
#    my $rh_max        = safe_float( $hist->{maxhumidity} );
#    my $rh_mean       = ( $rh_min + $rh_max ) / 2;
#    my $meanwindspeed = safe_float( $hist->{meanwindspdm} );
    my $rainfall      = min( safe_float( $hist->{precip} ), safe_float($rainfallsatpoint) );

############################################################################################
##                             Calculations                                               ##
############################################################################################
    # Calc Rn

    print
      "pl1 [lat=$lat,tmin=$tmin,tmax=$tmax,tmean=$tmean,alt=$alt,tdew=$tdew,doy=$doy,shour=$sun_hours,rmin=$rh_min,rmax=$rh_max,$meanwindspeed,$rainfall,$rainfallsatpoint]\n"
      if ($debug);
    my $e_tmin   = &eto::delta_sat_vap_pres($tmin);
    my $e_tmax   = &eto::delta_sat_vap_pres($tmax);
    my $sd       = &eto::sol_dec($doy);
    my $sha      = &eto::sunset_hour_angle( $lat, $sd );
    my $dl_hours = &eto::daylight_hours($sha);
    my $irl      = &eto::inv_rel_dist_earth_sun($doy);
    my $etrad    = &eto::et_rad( $lat, $sd, $sha, $irl );
    my $cs_rad   = &eto::clear_sky_rad( $alt, $etrad );
    my $Ra       = "";

    print "pl2 [e_tmin=$e_tmin e_tmax=$e_tmax sd=$sd sha=$sha dl_hours=$dl_hours irl=$irl etrad=$etrad cs_rad=$cs_rad]\n" if ($debug);

    my $sol_rad = &eto::sol_rad_from_sun_hours( $dl_hours, $sun_hours, $etrad );
    $sol_rad = &eto::sol_rad_from_t( $etrad, $cs_rad, $tmin, $tmax ) unless ($sol_rad);
    unless ($sol_rad) {
        print_log "[calc_eto] INFO Data for Penman-Monteith ETo not available reverting to Hargreaves ETo\n";

        # Calc Ra
        $Ra = $etrad;
        print_log "[calc_eto] WARNING Not enough data to complete calculations" unless ($Ra);
    }

    $msg = "[calc_eto] RESULTS Sun hours today: $sun_hours";    # tomorrow+2 days forecast rain
    print_log $msg;
    $msg_string .= $msg . "\n";

    my $ea = &eto::ea_from_tdew($tdew);
    $ea = &eto::ea_from_tmin($tmin) unless ($ea);
    $ea = &eto::ea_from_rhmin_rhmax( $e_tmin, $e_tmax, $rh_min, $rh_max ) unless ($ea);
    $ea = &eto::ea_from_rhmax( $e_tmin, $rh_max ) unless ($ea);
    $ea = &eto::ea_from_rhmean( $e_tmin, $e_tmax, $rh_mean ) unless ($ea);
    print_log "[calc_eto] INFO Failed to set actual vapor pressure" unless ($ea);

    my $ni_sw_rad = &eto::net_in_sol_rad($sol_rad);
    my $no_lw_rad = &eto::net_out_lw_rad( $tmin, $tmax, $sol_rad, $cs_rad, $ea );
    my $Rn        = &eto::net_rad( $ni_sw_rad, $no_lw_rad );

    # Calc t

    my $t = ( $tmin + $tmax ) / 2;

    # Calc ws (wind speed)

    my $ws = &eto::wind_speed_2m( $meanwindspeed, 10 );

    # Calc es

    my $es = &eto::mean_es( $tmin, $tmax );

    print "pl3 [sol_rad=$sol_rad ra=$Ra ea=$ea ni_sw_rad=$ni_sw_rad no_lw_rad=$no_lw_rad rn=$Rn t=$t ws=$ws es=$es]\n" if ($debug);

    # ea done in Rn calcs
    # Calc delta_es

    my $delta_es = &eto::delta_sat_vap_pres($t);

    # Calc psy

    my $atmospres = &eto::atmos_pres($alt);
    my $psy       = &eto::psy_const($atmospres);
    print "pl4 [delta_es=$delta_es atmospres=$atmospres psy=$psy]\n" if ($debug);
############################## Print Results ###################################

    $msg = "[calc_eto] RESULTS " . round( $tadjust, 4 ) . " mm precipitation forecast for next 3 days";    # tomorrow+2 days forecast rain
    print_log $msg;
    $msg_string .= $msg . "\n";
    $msg = "[calc_eto] RESULTS " . round( $todayRain, 4 ) . " mm precipitation fallen and forecast for today";    # rain fallen today + forecast rain for today
    print_log $msg;
    $msg_string .= $msg . "\n";

    #write to the RRD if it's enabled
    if ($rrd ne "") {
        $msg = '[calc_eto] Writing fallen and forecast rain to RRD: ' . round( $todayRain, 4 ) . " mm";
        $Weather{RainTotal} = round( $todayRain, 4 );
        print_log $msg;
        $msg_string .= $msg . "\n";
        
    }

    # Binary watering determination based on 3 criteria: 1)Currently raining 2)Wind>8kph~5mph 3)Temp<4.5C ~ 40F
    if ($noWater) {
        $msg = "[calc_eto] RESULTS We will not water because: $whyNot";
        print_log $msg;
        $msg_string .= $msg . "\n";
    }

    my ( $ETdailyG, $ETdailyS );
    if ( not $Ra ) {
        $ETdailyG = round( &eto::ETo( $Rn, $t, $ws, $es, $ea, $delta_es, $psy, 0 ) - $rainfall, 4 );    #ETo for most lawn grasses
        $ETdailyS = round( &eto::ETo( $Rn, $t, $ws, $es, $ea, $delta_es, $psy, 1 ) - $rainfall, 4 );    #ETo for decorative grasses, most shrubs and flowers
        $msg      = "[calc_eto] RESULTS P-M ETo";
        print_log $msg;
        $msg_string .= $msg . "\n";
        $msg = "[calc_eto] RESULTS    $ETdailyG mm lost by grass";
        print_log $msg;
        $msg_string .= $msg . "\n";
        $msg = "[calc_eto] RESULTS    $ETdailyS mm lost by shrubs";
        print_log $msg;
        $msg_string .= $msg . "\n";

    }
    else {
        $ETdailyG = round( &eto::hargreaves_ETo( $tmin, $tmax, $tmean, $Ra ) - $rainfall, 4 );
        $ETdailyS = $ETdailyG;
        $msg      = "[calc_eto] RESULTS H ETo";
        print_log $msg;
        $msg_string .= $msg . "\n";

        $msg = "[calc_eto] RESULTS   $ETdailyG mm lost today";
        print_log $msg;
        $msg_string .= $msg . "\n";

    }

    my $sr_hour = int($sun->{rise} / 60);
    my $sr_min = int($sun->{rise} % 60);
    my $ss_hour = int($sun->{set} / 60);
    my $ss_min = int($sun->{set} % 60);
    
    $msg = "[calc_eto] RESULTS sunrise & sunset from midnight local time: $sr_hour:$sr_min (" . $sun->{rise} . ") $ss_hour:$ss_min (" . $sun->{set} . ")";
    print_log $msg;
    $msg_string .= $msg . "\n";

#    my $stationID = $wuData->{current_observation}->{station_id};
#    $msg = '[calc_eto] RESULTS Weather Station ID:  ' . $stationID;
#    print_log $msg;
#    $msg_string .= $msg . "\n";

    my $updateTime = scalar localtime($wuData->{currentConditions}->{datetimeEpoch});   
    $msg = '[calc_eto] RESULTS Weather data ' . $updateTime;
    print_log $msg;
    $msg_string .= $msg . "\n";

    my ($rtime) = writeResults( $ETdailyG, $ETdailyS, $sun, $todayRain, $tadjust, $noWater, $logsPath, $ETPath, $WPPath );

    #Write the WU data to a file. This can be used for the MH weather data and save an api call
    writewuData( $wuData, $noWater, $wuDataPath );
    
    #$msg = "[calc_eto] RESULTS Calculated Schedule: $rtime";
    #print_log $msg;
    #$msg_string .= $msg . "\n";
    my $rtime2 = "";
    ($rtime2) = detailSchedule($rtime);
    foreach my $detail (split /\n/,$rtime2) {
        print_log $detail;
    }
    $msg_string .= $rtime2;
    if ( defined $config_parms{eto_email} ) {
        print_log "[calc_eto] Emailing results";
        net_mail_send( to => $config_parms{eto_email}, subject => "EvapoTranspiration Results for $Time_Now", text => $msg_string );
    }
    return ($rtime);
}

sub update_osp_ha_entities {
    my ($program_string, $retry, $ha_retry_delay) = @_;
    my $changes = 0;
 
    my ( $run_times, $run_seconds ) = $program_string =~ /\[\[(.*)\],\[(.*)\]\]/;
    print_log "[calc_eto] Update_osp_ha_entities: Loading values  [$run_times] : [$run_seconds] for $Day into HA Opensprinkler object. $retry Validations remaining";

    #loop through days to set
    foreach my $d ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday") {
        my $value = "off";
        $value = "on" if (lc $Day eq substr $d, 0, 3); #MH just has the first three letters for days 
        my $state = $osp_ha_object->get_attr($config_parms{eto_HAopensprinkler_program_name} . "_" . $d . '_enabled');
        $state = "" unless (defined $state);
        if (lc $state ne lc $value) {
            print_log '[calc_eto] $osprogram->set_attr("' . $config_parms{eto_HAopensprinkler_program_name} . "_" . $d . '_enabled",' . $value . '); ' if ($debug);
            $osp_ha_object->set_attr($config_parms{eto_HAopensprinkler_program_name} . "_" . $d . '_enabled' , $value);
	    $changes++;
        } else {
            print_log '[calc_eto] Current value for ' . $config_parms{eto_HAopensprinkler_program_name} . "_" . $d . '_enabled [' . $state . '] matches [' . $value . "] so dont change" if ($debug);
        }
    }   
    
    #loop through run_times. -1 means disable the start time
    my $count = 0;    
    my $program_disabled = 0;
    foreach my $s ( split /,/,$run_times ) {
       my $countname = $count;
       $countname = "" if ($count == 0);
       my $state = $osp_ha_object->get_attr($config_parms{eto_HAopensprinkler_program_name} . '_start' . $countname . '_time_offset');
       my $state2 = $osp_ha_object->get_attr($config_parms{eto_HAopensprinkler_program_name} . '_start' . $countname . '_time_offset_type');
       my $program = state $osp_ha_object;       
       $state = "" unless (defined $state);
       $state2 = "" unless (defined $state2);

       if (($s eq "-1") or $program_disabled) { #if the first time is -1, then all times should be disabled.
            if ($count == 0) {
                $program_disabled = 1;
            } else {
                if (lc $state2 ne "disabled") {
                    print_log '[calc_eto] $osprogram->set_attr(' . $config_parms{eto_HAopensprinkler_program_name} . '_start' . $countname . '_time_offset_type, "Disabled");' if ($debug) ;
                    $osp_ha_object->set_attr($config_parms{eto_HAopensprinkler_program_name} . '_start' . $countname . '_time_offset_type', "Disabled");
		   $changes++;
                } else {
                    print_log '[calc_eto] Current value for ' . $config_parms{eto_HAopensprinkler_program_name} . '_start' . $countname . '_time_offset_type [' . $state2 . '] matches [' . $s . "] so dont change" if ($debug);
                }
            }
       } else {
            if (lc $state2 eq "disabled") {
                print_log '[calc_eto] $osprogram->set_attr(' . $config_parms{eto_HAopensprinkler_program_name} . '_start' . $countname . '_time_offset_type, "Midnight");' if ($debug);
                $osp_ha_object->set_attr($config_parms{eto_HAopensprinkler_program_name} . '_start' . $countname . '_time_offset_type', "Midnight");
           $changes++; 
	}
            if (lc $state ne lc $s) {
                print_log '[calc_eto] $osprogram->set_attr("' . $config_parms{eto_HAopensprinkler_program_name} . '_start' . $countname . '_time_offset", ' . $s . '); ' if ($debug);
                $osp_ha_object->set_attr($config_parms{eto_HAopensprinkler_program_name} . '_start' . $countname . '_time_offset', $s);
		$changes++;
            } else {
                print_log '[calc_eto] Current value for ' . $config_parms{eto_HAopensprinkler_program_name} . '_start' . $countname . '_time_offset [' . $state . '] matches [' . $s . "] so dont change" if ($debug);

            }
        }
        $count++;
    }
    
    #loop through all the durations
    $count = 0;
    foreach my $r ( split /,/,$run_seconds) {     
        $count++;
        if (exists $config_parms{"eto_ha_s" . $count}) { 
            my $state = $osp_ha_object->get_attr($config_parms{eto_HAopensprinkler_program_name} . "_" . $config_parms{"eto_ha_s" . $count} . "_station_duration");
            $state = "" unless (defined $state);
            my $m = int($r / 60);
            $m++ if ($r > 0); # add a minute for rounding for non-zero duration stations
            $m = 0 if ($program_disabled); #turn off all stations just in case
            if (lc $state ne lc $m) {
                print_log '[calc_eto] $osprogram->set_attr("' . $config_parms{eto_HAopensprinkler_program_name} . "_" . $config_parms{"eto_ha_s" . $count } . '_station_duration"' . ", $m); " if ($debug);
                $osp_ha_object->set_attr($config_parms{eto_HAopensprinkler_program_name} . "_" . $config_parms{"eto_ha_s" . $count } . '_station_duration', $m);
		$changes++;
            } else {
                print_log '[calc_eto] Current value for ' . $config_parms{eto_HAopensprinkler_program_name} . "_" . $config_parms{"eto_ha_s" . $count} .'_station_duration [' . $state . '] matches [' . $m . "] so dont change" if ($debug);
            }
        } else {
           print_log 'print_log "[calc_eto] No ha entity name config_param for station ' . $count . '";' if ($debug);
        }
     }
    $retry--;
    my $eval_string = "&update_osp_ha_entities( '$program_string' , $retry )";
    if ($changes and $retry) {
    	print_log "[calc_eto] HA Program: Changes made: $changes. Validation Retries left: $retry";
        eval_with_timer($eval_string,$ha_retry_delay);
    } elsif ($changes and !$retry) {
    	print_log "[calc_eto] HA Program: ERROR Changes made: $changes. No validation retries left, Program incomplete!";
        net_mail_send( to => $config_parms{eto_email}, subject => "Calc_ETO failed to set HA Program", text => "Program String: $program_string" ) if ($ha_send_email_on_fail);
    } else {    
	print_log "[calc_eto] HA Program: SUCCESS Changes made: $changes. Program validated and Ready!";
    }
    return;     
}
