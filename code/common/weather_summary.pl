# Category=Weather

#@ This code allows the status bar (status_line.pl)
#@ to display the current readings from the wrm968.
#@
#@ This functionality was in the Weather_wmr200.pm module, but
#@ seems to have been left out of the Weather_wmr968.pm module.
#@
#@ This code restores that functionality and makes it easier to
#@ customize
#@
##
## Mark Radke
##

if ( $Startup || $Reload ) {
    &Weather_Common::weather_add_hook( \&weather_summary_update );
}

$v_weather_summary_update = new Voice_Cmd("Update weather summary");
if ( said $v_weather_summary_update) { &weather_summary_update; }

sub weather_summary_update {
##
## '&#176' puts in a degree symbol
##
    #$Weather{Summary_Short}= sprintf("%3.1f/%3d/%3d %3d%% %3d%%", #orig
    $Weather{Summary_Short} = sprintf(
        "%3.1f&#176in|%3d&#176out|%3d&#176wc|%3d%%RH in|%3d%%RH out",   # Mark's
        $Weather{TempIndoor},
        $Weather{TempOutdoor},
        $Weather{WindChill},
        $Weather{HumidIndoor},
        $Weather{HumidOutdoor}
    );
    $Weather{Wind} = " $Weather{WindAvgSpeed}/$Weather{WindGustSpeed} " .

      #&main::convert_direction($Weather{WindGustDir});# long i.e. 'north west'
      convert_summary_direction( $Weather{WindGustDir} );    # short i.e. 'NW'
## ^^^^^^^^^^^^^^^^^^^^^
## Using WindGustDir because there is no AVG wind direction in WMR-968
##

}

sub convert_summary_direction {
    my ($dir) = @_;
    return 'NA' if $dir !~ /^[\d \.]+$/;
    return 'N'  if $dir < 30 or $dir >= 330;
    return 'NE' if $dir < 60;
    return 'E'  if $dir < 120;
    return 'SE' if $dir < 150;
    return 'S'  if $dir < 210;
    return 'SW' if $dir < 240;
    return 'W'  if $dir < 300;
    return 'NW' if $dir < 330;
    return 'NA';
}
