# Category=Weather
# $Date$
# $Revision$
#####################################################################
#  NOM		: weather_rrd_update.pl
#  DESCRIPTION 	:
#@ Create/update RRD database with the weather informations,
#@ Create/update CSV file database with the weather informations,
#@ Create weather graphs with RRD database,
#@ - temperature graphs
#@ - others graphs for next release
#@ To allow for logging of data into a RRD (Round Robin) database,
#@ install the perl RRDs.pm module, and fill in the mh.ini parm.
#@
#@ Windows users can install RRD by extracting the files in
#@ http://people.ee.ethz.ch/~oetiker/webtools/rrdtool/pub/
#@ rrdtool-1.0.40.x86distr.zip-5.8.zip,
#@ (or similar) then cd to perl-shared and type: ppm install rrds.ppd
#@ RRD is available from
#@ http://ee-staff.ethz.ch/~oetiker/webtools/rrdtool
#@ Examples graphs : http://www.domotix.net
#  Script inspired from T. Oetiker wx200 monitor
#  http://wx200d.sourceforge.net
#--------------------------------------------------------------------
# If you use the graphs on an Internet Web site, please add a link
# to www.misterhouse.net and www.domotix.net for your contribution
#--------------------------------------------------------------------
# In input, mh variables $Weather{...} are in the unit of measure :
#    Temperature	°F
#    Humidity		%
#    Wind dir		degree
#    Rain rate		in/hr
#    Total rainfall	in
#    Pressure		inhg
#    Wind speed		mph
#  MH.ini parameters :
#  - Unit of measure of weather data
#    weather_uom_temp = C		(C, F)
#    weather_uom_baro = in		(mb, in)
#    weather_uom_wind = mph		(m/s, mph, kph)
#    weather_uom_rain = in		(mm, in)
#    weather_uom_rainrate = in/hr 	(mm/hr, in/hr)
#  - RRD database weather data
#    weather_data_rrd = F:/Misterhouse286/data/rrd/wmr928.rrd
#  - Archive weather data in flat file (type csv), blank to disable
#    File is suffixed by $Year_Month_Now
#    weather_data_csv = F:/Misterhouse286/data/rrd/wmr928_hist.csv
#  - PNG graph file directory
#    weather_graph_dir = $config_parms{data_dir}/rrd
#  - Web dir for PNG graph file
#    html_alias_rrd = $config_parms{data_dir}/rrd
#    weather_rrd_format = PNG / GIF (PNG is default)
#  - frequency for graphs generation (minute)
#    weather_graph_frequency = 10
#  - Footer center line graph, for example
#    weather_graph_footer = Last updated $Time_Date, copyright www.domotix.net
#  - Skip generation graphs, blank to generate all the graphs, possible
#    values : tempout tempin windspeed winddir raintotal rainrate press
#             humout humin
#    weather_graph_skip =
#  - Skip generation graphs for specific periods, blank to generate
#    graphs for all periods
#    values : 6hour 12hour 1day 2day 1week 2week 1month 2month
#             6month 1year 2year 5year
#    weather_graph_period_skip =
#  - Sensor name for indoor temperature and humidity graphs
#    weather_graph_sensor_names = sensor => name, ...
#    Values : sensor names = intemp, tempspare1,..., tempspare10, inhumid,
#    humidspare1,...,humidspare10
#  - Altitude in meters to add the barometric pressure to 1 millibar.
#    Ratio to calculate the sea level barometric pressure in the weather graphs
#    ratio_sea_baro = 10 (default value)
#  - Initialize the altitude of the local weather station,
#    In feet, used to calculate the sea level barometric pressure
#    altitude = 0
#--------------------------------------------------------------------
# 				HISTORY
#--------------------------------------------------------------------
#   DATE   REVISION    AUTHOR	        DESCRIPTION
#--------------------------------------------------------------------
# 26/10/03   1.0   Dominique Benoliel
# Creation script
# 13/03/04   1.1   Dominique Benoliel (thanks to Robin van Oosten)
# - add "--lazy" to generate a graph only if data has changed or a
#   graph does not exist (also speed up the generation of the graphs)
# - change the label for the wind direction
# - suppress default html_alias_weather_graph initialisation
# - change format to keep an alignment with negative numbers
# - fix problems with the vertical axis for the rain rate
# - fix the numeric length of the rain rate and rain total
# - changements to have the best RRA database
# - suppress alias suppress html_alias_weather_graph in reload
#   section
# - add total for rain total graph
# - add start date, step size, data points
# - extend to a maximum of 11 sensors (indoor temperature and humidity)
# - new mh.ini parameter weather_graph_sensor_names
#    04/04   1.2   Bruce Winter
# - Allow for sending graphs via email
# 15/05/04   1.3   Dominique Benoliel
# - change default labels for $config_parms{weather_graph_sensor_names}
# 18/05/04   1.4   Dominique Benoliel
# - Change min/max value for RRD DS press (Thanks to Clive Freedman)
# - add comment : unit of neasure of mh variable $Weather{...} in input
# 30/07/04   1.5   Dominique Benoliel
# - add sea level barometric pressure (label in pressure graph)
# - change label "barometric pressure" by "absolute barometric
#   pressure",
# 05/12/04   1.6   Bruce Winter & Tom Valdes
# - modifed script with the GlobalVars defined for Internet
# 28/12/04   1.7   Dominique Benoliel
# - change $Reload with $Reread (clive Freedman)
# - correct Wind Direction ratio with "--y-grid" ,"45:1" (Tine Gornik)
# - correct Rain Rate with "--alt-y-grid"
# - correct Rain Total with "--alt-y-grid"
# 01/01/05   1.8   Matthew Williams
# - added unit conversion routines when using metric units
# - NB: unit conversion requires main mh binary > 2.96
# - added full support for m/s for wind speed
# - changed dew point ranges to allow negative dew points
#  1/15/05   1.9   Pete Flaherty
# - added ability to specify alternate graph format eg GIF
#   $config_parms{weather_graph_format}
# 3/10/05    2.0   Mark Radke
# - Corrected "SeaLevel" line in Barometric graph to include the
# - calculation for In/Hg when $config_params{weather_uom_baro} = "in"
# - changed format for Sealevel pressure in In/Hg to have two (2)
# - decimal places
#####################################################################
use RRDs;

my $RRD_STEP      = 60;     # seconds between recorded data samples
my $RRD_HEARTBEAT = 300;    # seconds before data becomes *unknown*

# noloop=start
my @rrd_sensors = qw(
  TempOutdoor
  HumidOutdoor
  DewOutdoor
  Barom
  WindGustDir
  WindAvgDir
  WindGustSpeed
  WindAvgSpeed
  TempOutdoorApparent
  RainRate
  RainTotal
  TempIndoor
  HumidIndoor
  DewIndoor
  TempSpare1
  HumidSpare1
  DewSpare1
  TempSpare2
  HumidSpare2
  DewSpare2
  TempSpare3
  HumidSpare3
  DewSpare3
  TempSpare4
  HumidSpare4
  TempSpare5
  HumidSpare5
  TempSpare6
  HumidSpare6
  TempSpare7
  HumidSpare7
  TempSpare8
  HumidSpare8
  TempSpare9
  HumidSpare9
  TempSpare10
  HumidSpare10
);

my $rrdDataTransferFile = $config_parms{data_dir} . '/rrdtransfer.pl';

# noloop=stop

# need to add values for tempspares and humidspares
#==============================================================================
# Principal script
#==============================================================================

# Initialisation
if ($Reread) {
    $config_parms{weather_graph_frequency} = 10
      unless $config_parms{weather_graph_frequency};
    $config_parms{weather_data_rrd} =
      "$config_parms{data_dir}/rrd/weather_data.rrd"
      unless $config_parms{weather_data_rrd};
    $config_parms{weather_graph_dir} = "$config_parms{data_dir}/rrd"
      unless $config_parms{weather_graph_dir};
    $config_parms{weather_graph_footer} =
      'Last updated $Time_Date, Dominique Benoliel, www.domotix.net'
      unless $config_parms{weather_graph_footer};
    mkdir $config_parms{weather_graph_dir}
      unless -d $config_parms{weather_graph_dir};
    $config_parms{weather_graph_sensor_names} =
      "temp => Temperature outdoor, humid => Humidity outdoor, dew => Temperature dewpoint outdoor, press => Pressure outdoor, dir => Wind direction, avgdir => Wind average direction, speed => Wind speed, avgspeed => Wind average speed, apparent => Apparent temperature, rate => Rain rate, rain => Rain total, intemp => Temperature indoor, inhumid => Humidity indoor, indew => Temperature dewpoint indoor, tempspare1 => Temperature extra sensor 1, humidspare1 => Humidity extra sensor 1, dewspare1 => Temperature dewpoint extra sensor 1, tempspare2 => Temperature extra sensor 2, humidspare2 => Humidity extra sensor 2, dewspare2 => Temperature dewpoint extra sensor 2, tempspare3 => Temperature extra sensor 3, humidspare3 => Humidity extra sensor 3, dewspare3 => Temperature dewpoint extra sensor 3, tempspare4 => Temperature extra sensor 4, humidspare4 => Humidity extra sensor 4, tempspare5 => Temperature extra sensor 5, humidspare5 => Humidity extra sensor 5, tempspare6 => Temperature extra sensor 6, humidspare6 => Humidity extra sensor 6, tempspare7 => Temperature extra sensor 7, humidspare7 => Humidity extra sensor 7, tempspare8 => Temperature extra sensor 8, humidspare8 => Humidity extra sensor 8, tempspare9 => Temperature extra sensor 9, humidspare9 => Humidity extra sensor 9, tempspare10 => Temperature extra sensor 10, humidspare10 => Humidity extra sensor 10 "
      unless $config_parms{weather_graph_sensor_names};
    $config_parms{altitude}       = 0 unless $config_parms{altitude};
    $config_parms{ratio_sea_baro} = 8 unless $config_parms{ratio_sea_baro};
    $config_parms{weather_graph_format} = "PNG"
      unless $config_parms{weather_graph_format};

    if ( $RRDs::VERSION >= 1.2 and lc( $config_parms{weather_graph_format} eq 'gif' ) ) {
        &print_log(
            "weather_rrd: WARNING, RRD version 1.2+ does not support GIFs");
    }

    &weather_rrd_rename_chill_to_apparent;
}

sub weather_rrd_rename_chill_to_apparent {
    my $rrd = $config_parms{weather_data_rrd};

    # get info from rrd
    my $hashPtr = RRDs::info($rrd);

    my $error = RRDs::error;

    if ($error) {
        print_log("weather_rrd: can't get info on $rrd");
        return;
    }

    # if we still have a chill type
    if ( defined $$hashPtr{'ds[chill].type'} ) {
        RRDs::tune( $rrd, '--data-source-rename', 'chill:apparent' );
        $error = RRDs::error;
        if ($error) {
            &print_log("weather_rrd: can't rename chill to apparent: $error");
        }
        else {
            &print_log("weather_rrd: successfully renamed chill to apparent");
        }
    }
}

# Debug mode
my $debug = 1 if $main::Debug{weather_graph};

# Update RRD database every 1 minute
if ($New_Minute) {
    my (
        $rrd_TempOutdoor,   $rrd_HumidOutdoor, $rrd_DewOutdoor,
        $rrd_Barom,         $rrd_WindGustDir,  $rrd_WindAvgDir,
        $rrd_WindGustSpeed, $rrd_WindAvgSpeed, $rrd_TempOutdoorApparent,
        $rrd_RainRate,      $rrd_RainTotal,    $rrd_TempIndoor,
        $rrd_HumidIndoor,   $rrd_DewIndoor,    $rrd_TempSpare1,
        $rrd_HumidSpare1,   $rrd_DewSpare1,    $rrd_TempSpare2,
        $rrd_HumidSpare2,   $rrd_DewSpare2,    $rrd_TempSpare3,
        $rrd_HumidSpare3,   $rrd_DewSpare3,    $rrd_TempSpare4,
        $rrd_HumidSpare4,   $rrd_TempSpare5,   $rrd_HumidSpare5,
        $rrd_TempSpare6,    $rrd_HumidSpare6,  $rrd_TempSpare7,
        $rrd_HumidSpare7,   $rrd_TempSpare8,   $rrd_HumidSpare8,
        $rrd_TempSpare9,    $rrd_HumidSpare9,  $rrd_TempSpare10,
        $rrd_HumidSpare10
    );

    foreach my $sensor (@rrd_sensors) {

        # this command says that only use the sensor if it is defined and composed of an optional negative sign, digits and decimal points
        my $command = '$rrd_'
          . $sensor
          . ' = (defined $Weather{'
          . $sensor
          . '} and $Weather{'
          . $sensor
          . '} =~ /^\s*-?[\d\.]+\s*$/) ? $Weather{'
          . $sensor
          . '} : "U";';
        eval $command;
    }

    my $RRD = "$config_parms{weather_data_rrd}";

    my $time = time;
    my @d;

    &create_rrd($time) unless -e $RRD;

    if ( $config_parms{weather_uom_temp} eq 'C' ) {
        grep { $_ = convert_c2f($_) unless $_ eq 'U' } (
            $rrd_TempOutdoor, $rrd_TempIndoor,
            $rrd_TempSpare1,  $rrd_TempSpare2,
            $rrd_TempSpare3,  $rrd_TempSpare4,
            $rrd_TempSpare5,  $rrd_TempSpare6,
            $rrd_TempSpare7,  $rrd_TempSpare8,
            $rrd_TempSpare9,  $rrd_TempSpare10,
            $rrd_DewOutdoor,  $rrd_DewIndoor,
            $rrd_DewSpare1,   $rrd_DewSpare2,
            $rrd_DewSpare3,   $rrd_TempOutdoorApparent
        );
    }

    if ( $config_parms{weather_uom_baro} eq 'mb' ) {
        grep { $_ = convert_mb2in($_) unless $_ eq 'U' } ($rrd_Barom);
    }

    if ( $config_parms{weather_uom_wind} eq 'kph' ) {
        grep { $_ = convert_km2mile($_) unless $_ eq 'U' }
          ( $rrd_WindGustSpeed, $rrd_WindAvgSpeed );
    }

    if ( $config_parms{weather_uom_wind} eq 'm/s' ) {
        grep { $_ = convert_mps2mph($_) unless $_ eq 'U' }
          ( $rrd_WindGustSpeed, $rrd_WindAvgSpeed );
    }

    if ( $config_parms{weather_uom_rain} eq 'mm' ) {
        grep { $_ = convert_mm2in($_) unless $_ eq 'U' } ($rrd_RainTotal);
    }

    if ( $config_parms{weather_uom_rainrate} eq 'mm/hr' ) {
        grep { $_ = convert_mm2in($_) unless $_ eq 'U' } ($rrd_RainRate);
    }

    @d = (
        $rrd_TempOutdoor,   $rrd_HumidOutdoor, $rrd_DewOutdoor,
        $rrd_Barom,         $rrd_WindGustDir,  $rrd_WindAvgDir,
        $rrd_WindGustSpeed, $rrd_WindAvgSpeed, $rrd_TempOutdoorApparent,
        $rrd_RainRate,      $rrd_RainTotal,    $rrd_TempIndoor,
        $rrd_HumidIndoor,   $rrd_DewIndoor,    $rrd_TempSpare1,
        $rrd_HumidSpare1,   $rrd_DewSpare1,    $rrd_TempSpare2,
        $rrd_HumidSpare2,   $rrd_DewSpare2,    $rrd_TempSpare3,
        $rrd_HumidSpare3,   $rrd_DewSpare3,    $rrd_TempSpare4,
        $rrd_HumidSpare4,   $rrd_TempSpare5,   $rrd_HumidSpare5,
        $rrd_TempSpare6,    $rrd_HumidSpare6,  $rrd_TempSpare7,
        $rrd_HumidSpare7,   $rrd_TempSpare8,   $rrd_HumidSpare8,
        $rrd_TempSpare9,    $rrd_HumidSpare9,  $rrd_TempSpare10,
        $rrd_HumidSpare10
    );

    #print "@d\n";

    # Store data in rrd database
    $" = ':';
    &update_rrd( $time, @d );
    $" = ' ';

    # Store data in csv file
    &update_csv( $time, @d ) if $config_parms{weather_data_csv};
}

# Create the graphs
$p_weather_graph =
  new Process_Item qq:weather_rrd_update_graphs "$rrdDataTransferFile":;
$tell_generate_graph = new Voice_Cmd "Generate weather graphs";

if (   new_minute $config_parms{weather_graph_frequency}
    or said $tell_generate_graph)
{
    if ( said $tell_generate_graph) {
        $tell_generate_graph->respond('Updating weather graphs');
    }
    &update_graphs;
}

sub update_graphs {
    my $RRD      = "$config_parms{weather_data_rrd}";
    my $RRD_LAST = RRDs::last $RRD;
    my $err      = RRDs::error;
    if ($err) {
        &print_log("weather_rrd : unable to get last : $err");
        return;
    }

    if ( !open( RRDDATATRANSFER, '>' . $rrdDataTransferFile ) ) {
        &print_log(
            "weather_rrd: can't open $rrdDataTransferFile for writing: $!");
        return;
    }

    my $footer;
    $footer = eval qq!\$footer ="$config_parms{weather_graph_footer}";!;

    my $rrd_format = $config_parms{weather_graph_format};

    print RRDDATATRANSFER qq!# RRD Data Transfer file
# Used to transfer configuration parameters 
# to mh/bin/weather_rrd_update_graphs.
# Running this is harmless, but won't do anything either.
# This file will be automatically updated every few minutes, so don't bother 
# editing it.

\$RRD="$config_parms{weather_data_rrd}";
\$RRD_LAST="$RRD_LAST";
\$rrd_graph_dir="$config_parms{weather_graph_dir}";
\$rrd_format = "$rrd_format";
\$weather_graph_footer = "$footer" ;
\$weather_graph_skip = "$config_parms{weather_graph_skip}";
\$weather_graph_period_skip = "$config_parms{weather_graph_period_skip}";
\$altitude = "$config_parms{altitude}";
\$ratio_sea_baro = "$config_parms{ratio_sea_baro}";
\$weather_convert_png_to_gif = "$config_parms{weather_convert_png_to_gif}";
!;

    foreach my $key ( keys(%config_parms) ) {
        next if $key !~ /^weather_rrd_color_(.*)/;   # we only want certain keys
        next if $key =~ /_MHINTERNAL_/;              # not internal copies
        my $element = $1;
        my $color   = $config_parms{ "weather_rrd_color_" . $element };
        &print_log("weather_rrd: found element -$element- value is -$color-")
          if $Debug{weather_graph};
        next if $color eq '';
        print RRDDATATRANSFER qq:\$color$element='$color';\n:;
    }

    foreach my $key ( keys(%config_parms) ) {
        next if $key !~ /^weather_uom_(.*)/;         # we only want certain keys
        next if $key =~ /_MHINTERNAL_/;              # not internal copies
        &print_log("weather_rrd: found key $key") if $Debug{weather_graph};
        print RRDDATATRANSFER
          qq:\$weather_uom_$1="$config_parms{"weather_uom_".$1}";\n:;
    }

    my %sensor_names;
    &main::read_parm_hash( \%sensor_names,
        $main::config_parms{weather_graph_sensor_names} );

    foreach my $key ( keys(%sensor_names) ) {
        print RRDDATATRANSFER qq:\$sensor_names{$key}="$sensor_names{$key}";\n:;
    }

    close(RRDDATATRANSFER);
    &print_log("weather_rrd: updating weather graphs") if $Debug{weather_graph};
    start $p_weather_graph; # We are now safe to do this in Windows as all of the processing is done in an external file
}

#==============================================================================
# Creation bases RRD
#==============================================================================
sub create_rrd {
    my $err;
    my $RRD = "$config_parms{weather_data_rrd}";

    print "Create RRD database : $RRD\n" if $debug;

    RRDs::create $RRD,
      '-b', $_[0], '-s', $RRD_STEP,
      "DS:temp:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humid:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:dew:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:press:GAUGE:$RRD_HEARTBEAT:23:33",
      "DS:dir:GAUGE:$RRD_HEARTBEAT:0:360",
      "DS:avgdir:GAUGE:$RRD_HEARTBEAT:0:360",
      "DS:speed:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:avgspeed:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:apparent:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:rate:GAUGE:$RRD_HEARTBEAT:0:999",
      "DS:rain:GAUGE:$RRD_HEARTBEAT:0:9999",
      "DS:intemp:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:inhumid:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:indew:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:tempspare1:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humidspare1:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:dewspare1:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:tempspare2:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humidspare2:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:dewspare2:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:tempspare3:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humidspare3:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:dewspare3:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:tempspare4:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humidspare4:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:tempspare5:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humidspare5:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:tempspare6:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humidspare6:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:tempspare7:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humidspare7:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:tempspare8:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humidspare8:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:tempspare9:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humidspare9:GAUGE:$RRD_HEARTBEAT:0:100",
      "DS:tempspare10:GAUGE:$RRD_HEARTBEAT:-150:150",
      "DS:humidspare10:GAUGE:$RRD_HEARTBEAT:0:100",

      'RRA:AVERAGE:0.5:1:801',    # details for 6 hours (agregate 1 minute)

      'RRA:MIN:0.5:2:801',        # 1 day (agregate 2 minutes)
      'RRA:AVERAGE:0.5:2:801', 'RRA:MAX:0.5:2:801',

      'RRA:MIN:0.5:5:641',        # 2 day (agregate 5 minutes)
      'RRA:AVERAGE:0.5:5:641', 'RRA:MAX:0.5:5:641',

      'RRA:MIN:0.5:18:623',       # 1 week (agregate 18 minutes)
      'RRA:AVERAGE:0.5:18:623', 'RRA:MAX:0.5:18:623',

      'RRA:MIN:0.5:35:618',       # 2 weeks (agregate 35 minutes)
      'RRA:AVERAGE:0.5:35:618', 'RRA:MAX:0.5:35:618',

      'RRA:MIN:0.5:75:694',       # 1 month (agregate 1h15mn)
      'RRA:AVERAGE:0.5:75:694', 'RRA:MAX:0.5:75:694',

      'RRA:MIN:0.5:150:694',      # 2 months (agregate 2h30mn)
      'RRA:AVERAGE:0.5:150:694', 'RRA:MAX:0.5:150:694',

      'RRA:MIN:0.5:1080:268',     # 6 months (agregate 18 hours)
      'RRA:AVERAGE:0.5:1080:268', 'RRA:MAX:0.5:1080:268',

      'RRA:MIN:0.5:2880:209',     # 12 months (agregate 2 days)
      'RRA:AVERAGE:0.5:2880:209', 'RRA:MAX:0.5:2880:209',

      'RRA:MIN:0.5:4320:279',     # 2 years (agregate 3 days)
      'RRA:AVERAGE:0.5:4320:279', 'RRA:MAX:0.5:4320:279',

      'RRA:MIN:0.5:8640:334',     # 5 months (agregate 6 days)
      'RRA:AVERAGE:0.5:8640:334', 'RRA:MAX:0.5:8640:334';

    die "weather_rrd_update : unable to create $RRD: $err\n"
      if $err = RRDs::error;
}

#==============================================================================
# Update base RRD
# update $RRD with given time and data
#
# To save space wx200d logs only when a variable changes.  So if only
# one variable has changed since the last update, we can assume the
# station was up and fill in the missing data so we don't get false
# unknowns.  If several things changed, we don't fill in and will get
# unknowns only if more than $RRD_HEARTBEAT seconds have passed.
#==============================================================================
sub update_rrd {
    my $err;
    my @last;
    my $last;
    my $i;
    my $RRD = "$config_parms{weather_data_rrd}";
    my ( $time, @data ) = @_;

    print "** Parametre **\n"                      if $debug;
    print "OLD DATA : time = $last data = @last\n" if $debug;
    print "NEW DATA : time = $time data = @data\n" if $debug;

    @last = @data unless @last;
    $last = $time unless $last;
    $i    = 0;

    # Zero change -> fill in flat lines
    if ( 0 >= grep $_ ne $last[ $i++ ], @data ) {
        print "WARNING, loop 1...\n" if $debug;
        print "No data change\n"     if $debug;
        for ( $i = $last + $RRD_STEP; $i < $time; $i += $RRD_STEP ) {
            print "WARNING, loop 2...\n"               if $debug;
            print "...fill bucket\n"                   if $debug;
            print "...bucket time = $i data = @last\n" if $debug;

            RRDs::update $RRD, "$i:@last";

            next if $err = RRDs::error and $err =~ /mininum one second step/;
            warn "$err\n" if $err;
        }
    }
    elsif ( ( $i = $time - $last ) > $RRD_HEARTBEAT ) {
        print "WARNING, DETECT BUCKET...!\n" if $debug;
        print "... $time - $last = $i\n"     if $debug;

        #$max = $i if $i > $max;
        #$gaps++;# note number of gaps and max size
    }

    print "DATA INSERT : time = $time data = @data\n" if $debug;
    RRDs::update $RRD, "$time:@data";    # add current data

    $last = $time;
    @last = @data;
    return if $err = RRDs::error and $err =~ /min.*one second step/;
    warn "$err\n" if $err;
}

#==============================================================================
# Create and/or update CSV file
#==============================================================================
sub update_csv {
    my ( $time, @data ) = @_;
    my $row_header;
    my $row_data;
    my $log_annee   = (localtime)[5] + 1900;
    my $log_mois    = (localtime)[4] + 1;
    my $log_jour    = (localtime)[3];
    my $log_heure   = (localtime)[2];
    my $log_minute  = (localtime)[1];
    my $log_seconde = (localtime)[0];

    # Create flat file, useful to recreate RRD database
    unless ( -e "$config_parms{weather_data_csv}.$Year_Month_Now" ) {
        $row_header = join( ";",
            'Epoch',
            'Year',
            'Month',
            'Day',
            'Hour',
            'Minute',
            'Seconde',
            'Outdoor Temp',
            'Outdoor Humidity',
            'Temperature dewpoint',
            'Pression',
            'Direction wind',
            'Direction average wind',
            'Wind Speed',
            'Average wind speed',
            'Apparent Temperature',
            'Rain rate',
            'Total rain',
            'Temperature indoor',
            'Humidity indoor',
            'Dewpoint indoor',
            'Temperature module 1',
            'Humidity module 1',
            'Dewpoint module 1',
            'Temperature module 2',
            'Humidity module 2',
            'Dewpoint module 2',
            'Temperature module 3',
            'Humidity module 3',
            'Dewpoint module 3',
            'Temperature 4',
            'Humidity module 4',
            'Temperature 5',
            'Humidity module 5',
            'Temperature 6',
            'Humidity module 6',
            'Temperature 7',
            'Humidity module 7',
            'Temperature 8',
            'Humidity module 8',
            'Temperature 9',
            'Humidity module 9',
            'Temperature 10',
            'Humidity module 10',
            "\n" );

        &logit( "$config_parms{weather_data_csv}.$Year_Month_Now",
            $row_header, 0 );
    }
    $row_data = join( ";",
        $time,       $log_annee,   $log_mois, $log_jour, $log_heure,
        $log_minute, $log_seconde, $data[0],  $data[1],  $data[2],
        $data[3],    $data[4],     $data[5],  $data[6],  $data[7],
        $data[8],    $data[9],     $data[10], $data[11], $data[12],
        $data[13],   $data[14],    $data[15], $data[16], $data[17],
        $data[18],   $data[19],    $data[20], $data[21], $data[22],
        $data[23],   $data[24],    $data[25], $data[26], $data[27],
        $data[28],   $data[29],    $data[30], $data[31], $data[32],
        $data[33],   $data[34],    $data[35], $data[36], "\n" );

    &logit( "$config_parms{weather_data_csv}.$Year_Month_Now", $row_data, 0 );
}

sub analyze_rrd_rain {
    my $RRD = "$config_parms{weather_data_rrd}";

    &print_log('analyze_rrd_rain: updating $Weather{RainLast{x}Hours}')
      if $::Debug{weather_graph};

    my @hours = ( 1, 2, 6, 12, 18, 24, 48, 72, 168 );
    my $resolution = 18 * 60
      ; # using 18 minute datapoints - don't change this unless you know what you're doing

    # set default values
    foreach my $hour (@hours) {
        $Weather{"RainLast${hour}Hours"} = 'unknown';
    }

    my $endtime = int( time / $resolution ) * $resolution;

    my ( $start, $step, $names, $data ) = RRDs::fetch(
        $RRD, 'AVERAGE', '-r', $resolution,
        '-e', $endtime,  '-s', 'e-168hours'
    );

    my $RRDerror = RRDs::error;

    if ($RRDerror) {
        &print_log(
            "weather_rrd_update: having trouble fetching data for rain: $RRDerror"
        );
        return;
    }

    # print "start was ".scalar localtime($start)." and step was $step\n"; # for debugging

    my $rainIndex;
    for ( $rainIndex = 0; $rainIndex < $#{$names}; $rainIndex++ ) {
        last if $$names[$rainIndex] eq 'rain';
    }

    if ( $rainIndex >= $#{$names} ) {
        &print_log("weather_rrd_update: can't find rain data");
        return;
    }

    # print "rainIndex=$rainIndex\n"; # for debugging

    # the next bunch of lines gives me a headache ... pointer to an array of pointers?  Who thought that was a good idea?
    my $lastSample = $#{$data};

    # print "lastSample is $lastSample\n"; # for debugging
    my $latestRain = ${ $$data[$lastSample] }[$rainIndex];

    # some versions of RRD return an empty data set in the last sample
    # so grab the last but one sample if this is the case
    $latestRain = ${ $$data[ $lastSample - 1 ] }[$rainIndex]
      if $latestRain eq '';

    # print "latest rain is $latestRain\n"; # for debugging
    my $lastRain = 0;
    foreach my $hour (@hours) {

        # RRD data is stored in interesting ways every x minutes
        # x was defined to be 18 minutes for data going back a week
        # therefore we need to convert "hours" into y 18 minute intervals
        # This means that we could be off by up to 9 minutes, oh well.
        my $sampleIndex = $lastSample - int( ( $hour * 60 ) / 18 + 0.5 );

        # print "sampleIndex is $sampleIndex at hour $hour\n"; # for debugging

        # stop processing if we didn't get enough data
        last if ( $sampleIndex < 0 );

        my $rainAtSampleTime = ${ $$data[$sampleIndex] }[$rainIndex];

        # print "total rain at hour $hour is $rainAtSampleTime\n"; # for debugging
        my $rainAmount = $latestRain - $rainAtSampleTime;

        # if a RainTotal reset to 0 occurs, then rainAmount will be < 0
        next if ( $rainAmount < 0 );

        # print "rainAmount=$rainAmount\n"; # for debugging

        if ( $config_parms{weather_uom_rain} eq 'mm' ) {
            $rainAmount = convert_in2mm($rainAmount);
        }
        $Weather{"RainLast${hour}Hours"} = $rainAmount;

        # print "hour $hour is $rainAmount ".$Weather{"RainLast${hour}Hours"}."\n"; # for debugging
    }

    # check to make sure that the data looks right
    for ( my $i = 0; $i < ( $#hours - 1 ); $i++ ) {
        my $shorter = $Weather{ "RainLast" . $hours[$i] . "Hours" };
        my $longer  = $Weather{ "RainLast" . $hours[ $i + 1 ] . "Hours" };

        # don't check if either value is unknown
        next if $Weather{"RainLast${shorter}Hours"} eq 'unknown';
        next if $Weather{"RainLast${longer}Hours"} eq 'unknown';

        # if the total rain in the last period of time is lower than the
        # next larger period of time, then check the next period
        next
          if ( $Weather{"RainLast${shorter}Hours"} <=
            $Weather{"RainLast${longer}Hours"} );

        # a quirk in the data has caused a smaller period to have a larger
        # value than the next larger period
        # fix it by copying the smaller amount onto the larger amount
        $Weather{"RainLast${shorter}Hours"} =
          $Weather{"RainLast${longer}Hours"};
    }
    &print_log('analyze_rrd_rain: complete') if $::Debug{weather_graph};
}

# Allow for sending graphs via email

$weather_graph_email = new Voice_Cmd
  'Email [tempout,tempin,windspeed,winddir,raintotal,rainrate,press,humout,humin] weather chart';

if ( $state = said $weather_graph_email) {
    print_log "Sending $state weather charts";
    my $html = &html_file( undef, '../web/bin/weather_graph.pl', $state );
    &net_mail_send(
        subject => "$state weather charts for $Date_Now",
        baseref =>
          "$config_parms{http_server}:$config_parms{http_port}/ia5/outside/",
        to   => $config_parms{weather_graph_email},
        text => $html,
        mime => 'html'
    );

    #    &net_mail_send(subject => "Weather charts for $Date_Now",
    #		   baseref => "$config_parms{http_server}:$config_parms{http_port}/ia5/outside/",
    #		   file => "../web/ia5/outside/weather_index.shtml", mime  => 'html');
}

sub uninstall_weather_rrd_update {
    &trigger_delete('update rain totals from RRD database');
}

if ($Reload) {
    &trigger_set(
        'new_minute(10)', '&analyze_rrd_rain',
        'NoExpire',       'update rain totals from RRD database'
    ) unless &trigger_get('update rain totals from RRD database');
    &analyze_rrd_rain;
}
