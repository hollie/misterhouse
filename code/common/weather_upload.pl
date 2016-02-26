
# Category = Weather

#@ Upload data from your local weather station to wunderground.com.
#@ See code for info on wunderground_* mh.ini parms

# $Date$
# $Revision$

=begin comment

 weather_upload.pl by David Norwood, dnorwood2@yahoo.com

 This code will upload your weather station data to wunderground.com.
 Look here for info and examples:
  http://www.wunderground.com/weatherstation/index.asp
  http://www.wunderground.com/weatherstation/ListStations.asp

 The URL to sign up for an account and get back a station id is:
  http://www.wunderground.com/weatherstation/usersignup.asp

 Add/update these mh.ini parms:

  wunderground_stationid = KMNROCHE3
  wunderground_password  = xyz
  wunderground_frequency = 10

  NOTE: last parameter is optional and defaults to 10

 Place this file in your code directory, and you are ready to go.

# 01/12/05 Dominique Benoliel
# - change $Weather{Barom} with $Weather{BaromSea} for WMR928 weather station
# 01/23/05 Dominique Benoliel
# - make some conversions with mh parameters weather_uom_...

=cut

#use POSIX qw(strftime);

$p_weather_update = new Process_Item;
$v_weather_update =
  new Voice_Cmd '[Show results from,Run] wunderground.com upload';
my $weather_update_html_path =
  "$config_parms{data_dir}/web/wu-result.html";    #noloop

# Create trigger

if ($Reload) {
    my $command = "new_minute "
      . (
        ( $config_parms{wunderground_frequency} )
        ? $config_parms{wunderground_frequency}
        : 10
      );

    &trigger_set( $command, "run_voice_cmd('Run wunderground.com upload')",
        'NoExpire', 'upload weather' )
      unless &trigger_get('upload weather');
}

# Events

display($weather_update_html_path)
  if said $v_weather_update eq 'Show results from';

if ( said $v_weather_update eq 'Run' ) {

    $v_weather_update->respond('app=wunderground Uploading weather data...');

    my $stationid          = $config_parms{wunderground_stationid};
    my $passwd             = $config_parms{wunderground_password};
    my $weather_clouds     = '';
    my $weather_conditions = '';

    my $weather_winddir = $Weather{WindAvgDir};
    $weather_winddir = $Weather{WindGustDir} unless $weather_winddir;

    # Make some conversions if necessary
    my $weather_tempoutdoor = $Weather{TempOutdoor};
    my $weather_dewoutdoor  = $Weather{DewOutdoor};

    if ( $config_parms{weather_uom_temp} eq 'C' ) {
        grep { $_ = convert_c2f($_) if defined $_; }
          ( $weather_tempoutdoor, $weather_dewoutdoor );
    }

    my $weather_baromsea = $Weather{BaromSea};
    if ( not defined $weather_baromsea ) {
        if ( defined $Weather{Barom} ) {
            $weather_baromsea = convert_local_barom_to_sea( $Weather{Barom} );
            print_log("weather_upload warning: using non sea-level pressure");
        }
        else {
            print_log("weather_upload warning: no pressure reading available");
        }
    }

    if ( defined $weather_baromsea and $config_parms{weather_uom_baro} eq 'mb' )
    {
        $weather_baromsea = convert_mb2in($weather_baromsea);
    }

    my $weather_windgustspeed = $Weather{WindGustSpeed};
    my $weather_windavgspeed  = $Weather{WindAvgSpeed};

    if ( $config_parms{weather_uom_wind} eq 'kph' ) {
        grep { $_ = convert_km2mile($_) if defined $_; }
          ( $weather_windgustspeed, $weather_windavgspeed );
    }
    if ( $config_parms{weather_uom_wind} eq 'm/s' ) {
        grep { $_ = convert_mps2mph($_) if defined $_; }
          ( $weather_windgustspeed, $weather_windavgspeed );
    }

    my $weather_rainrate = $Weather{RainRate};
    if ( defined $weather_rainrate
        and $config_parms{weather_uom_rainrate} eq 'mm/hr' )
    {
        $weather_rainrate = convert_mm2in($weather_rainrate);
    }

    # note, the WxTendency -> current conditions stuff was removed
    # as WxTendency is a forecast of weather 24-48 hours in advance,
    # not current conditions, see rev 626 for a copy of the old code

    # see code/common/weather_metar.pl for a definition of the METAR codes
    # used in $weather_conditions and $weather_clouds
    # add new codes here iff we can detect the conditions
    # note that "MI", "BC" and "PR" are not complete codes by themselves
    # and that cloud conditions are already passed along via $clouds

    if ( $Weather{Conditions} =~ /rain/i or $Weather{Raining} ) {
        $weather_conditions = 'RA';
        if ( defined $weather_rainrate ) {
            if ( $weather_rainrate >= 1 ) {    # 1+ inches per hour sounds heavy
                $weather_conditions = '+RA';
            }
            if ( $weather_rainrate <= 0.1 )
            {    # 0.1- inches per hour sounds light
                $weather_conditions = '-RA';
            }
        }
    }
    $weather_conditions = 'SN' if $Weather{Conditions} =~ /snow/i;

    if ( defined $Weather{Clouds} ) {
        if ( $Weather{Clouds} =~ /overcast/i ) {
            $weather_clouds = 'OVC';
        }
        elsif ( $Weather{Clouds} =~ /broken/i ) {
            $weather_clouds = 'BKN';
        }
        elsif ( $Weather{Clouds} =~ /few/i ) {
            $weather_clouds = 'FEW';
        }
        elsif ( $Weather{Clouds} =~ /scattered/i ) {
            $weather_clouds = 'SCT';
        }
        elsif ( $Weather{Clouds} =~ /clear/i ) {
            $weather_clouds = 'SKC';
        }
    }

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      gmtime();
    my $utc = sprintf "%s-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1,
      $mday, $hour, $min, $sec;
    $utc = &escape($utc);

    my $url =
      sprintf
      'http://weatherstation.wunderground.com/weatherstation/updateweatherstation.php?ID=%s&dateutc=%s&softwaretype=Misterhouse&action=updateraw',
      $stationid, $utc;

    $url .= "&winddir=$weather_winddir" if defined $weather_winddir;
    $url .= "&windspeedmph=$weather_windavgspeed"
      if defined $weather_windavgspeed;
    $url .= "&windgustmph=$weather_windgustspeed"
      if defined $weather_windgustspeed;
    $url .= "&tempf=$weather_tempoutdoor" if defined $weather_tempoutdoor;
    $url .= "&rainin=$weather_rainrate"   if defined $weather_rainrate;
    $url .= "&baromin=$weather_baromsea"  if defined $weather_baromsea;
    $url .= "&dewptf=$weather_dewoutdoor" if defined $weather_dewoutdoor;
    $url .= "&humidity=$Weather{HumidOutdoor}"
      if defined $Weather{HumidOutdoor};
    $url .= "&weather=$weather_conditions";
    $url .= "&clouds=$weather_clouds" if $weather_clouds ne '';

    print_log("wunderground: $url") if $Debug{weather};

    $url .= "&PASSWORD=${passwd}";

    set $p_weather_update qq|get_url -quiet "$url" $weather_update_html_path|;
    start $p_weather_update;
}

# *** Need to parse the response to look for errors

if ( done_now $p_weather_update) {
    $v_weather_update->respond(
        'app=wunderground connected=0 Weather upload completed.');

}

# -------------------
#
# Here is the URL used in the uploading (if you go here without parameters
# you will get a brief usage):
# http://weatherstation.wunderground.com/weatherstation/updateweatherstation.php
# usage
# action [action=updateraw]
# ID [ID as registered by wunderground.com]
# PASSWORD [PASSWORD registered with this ID]
# dateutc - [YYYY-MM-DD HH:MM:SS (mysql format)]
# winddir - [0-360]
# windspeedmph - [mph]
# windgustmph - [windgustmph ]
# humidity - [%]
# tempf - [temperature F]
# rainin - [rain in (hourly)]
# baromin - [barom in]  ... sea level
# dewptf- [dewpoint F]
# weather - [text] -- metar style (+RA)
# clouds - [text] -- SKC, FEW, SCT, BKN, OVC
# softwaretype - [text] ie: vws or weatherdisplay

# Cloud types:
#  CLR No clouds visible
#  SCT "Scattered" clouds. Refers to cloud coverage of 1/8 or 2/8 of the visible sky.
#  FEW "few clouds"  3/8 or 4/8 of the sky covered
#  BKN "Broken" clouds. Refers to a cloud cover of 5/8 to 7/8 of the visible sky.
#  OVC "Overcast". Refers to cloud coverage of 8/8

# IF we wanted to try updated Conditions, this pointer might help:
#  http://www.qisfl.net/home/hurricanemike/codedobhelp.htm
