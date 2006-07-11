# Category=Weather
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

my $RRD_STEP = 60;		# seconds between recorded data samples
my $RRD_HEARTBEAT = 300;	# seconds before data becomes *unknown*
my $RRD_LAZY = 1;		# set to 1 to use --lazy
my $RRD_LAST;

#==============================================================================
# Principal script
#==============================================================================

# Initialisation
if ($Reread) {
    $config_parms{weather_graph_frequency} = 10 unless $config_parms{weather_graph_frequency};
    $config_parms{weather_data_rrd} = "$config_parms{data_dir}/rrd/weather_data.rrd" unless $config_parms{weather_data_rrd};
    $config_parms{weather_graph_dir} = "$config_parms{data_dir}/rrd" unless $config_parms{weather_graph_dir};
    $config_parms{weather_graph_footer} = 'Last updated $Time_Date, Dominique Benoliel, www.domotix.net' unless $config_parms{weather_graph_footer};
    mkdir $config_parms{weather_graph_dir} unless -d $config_parms{weather_graph_dir};
    $config_parms{weather_graph_sensor_names} = "temp => Temperature outdoor, humid => Humidity outdoor, dew => Temperature dewpoint outdoor, press => Pressure outdoor, dir => Wind direction, avgdir => Wind average direction, speed => Wind speed, avgspeed => Wind average speed, apparent => Apparent temperature, rate => Rain rate, rain => Rain total, intemp => Temperature indoor, inhumid => Humidity indoor, indew => Temperature dewpoint indoor, tempspare1 => Temperature extra sensor 1, humidspare1 => Humidity extra sensor 1, dewspare1 => Temperature dewpoint extra sensor 1, tempspare2 => Temperature extra sensor 2, humidspare2 => Humidity extra sensor 2, dewspare2 => Temperature dewpoint extra sensor 2, tempspare3 => Temperature extra sensor 3, humidspare3 => Humidity extra sensor 3, dewspare3 => Temperature dewpoint extra sensor 3, tempspare4 => Temperature extra sensor 4, humidspare4 => Humidity extra sensor 4, tempspare5 => Temperature extra sensor 5, humidspare5 => Humidity extra sensor 5, tempspare6 => Temperature extra sensor 6, humidspare6 => Humidity extra sensor 6, tempspare7 => Temperature extra sensor 7, humidspare7 => Humidity extra sensor 7, tempspare8 => Temperature extra sensor 8, humidspare8 => Humidity extra sensor 8, tempspare9 => Temperature extra sensor 9, humidspare9 => Humidity extra sensor 9, tempspare10 => Temperature extra sensor 10, humidspare10 => Humidity extra sensor 10 " unless $config_parms{weather_graph_sensor_names};
    $config_parms{altitude}=0 unless $config_parms{altitude};
    $config_parms{ratio_sea_baro} = 10 unless $config_parms{ratio_sea_baro};
    $config_parms{weather_graph_format} = "PNG" unless $config_parms{weather_graph_format};
    tr/a-z/A-Z/ for $config_parms{weather_graph_format};
    &weather_rrd_rename_chill_to_apparent;
   }

sub weather_rrd_rename_chill_to_apparent {
	my $rrd=$config_parms{weather_data_rrd};
	# get info from rrd
	my $hashPtr=RRDs::info($rrd);

	my $error=RRDs::error;

	if ($error) {
		print_log ("weather_rrd: can't get info on $rrd");
		return;
	}

	# if we still have a chill type
	if (defined $$hashPtr{'ds[chill].type'}) {
		RRDs::tune($rrd,'--data-source-rename','chill:apparent');
		$error=RRDs::error;
		if ($error) {
			&print_log ("weather_rrd: can't rename chill to apparent: $error");
		} else {
			&print_log ("weather_rrd: successfully renamed chill to apparent");
		}
	}
}

# Debug mode
my $debug = 1 if $main::Debug{weather_graph};

# If debug mode, force the graph generation
$RRD_LAZY = 0 if $debug;

# Update RRD database every 1 minute
if ($New_Minute) {
    my $rrd_TempOutdoor = (defined $Weather{TempOutdoor}) ? $Weather{TempOutdoor} : $Weather{TempInternet};
    $rrd_TempOutdoor = 'U' unless defined $rrd_TempOutdoor;

    my $rrd_HumidOutdoor = defined $Weather{HumidOutdoor} ? $Weather{HumidOutdoor} : 'U';
    my $rrd_DewOutdoor = defined $Weather{DewOutdoor} ? $Weather{DewOutdoor} : 'U';
    my $rrd_Barom = defined $Weather{Barom} ? $Weather{Barom} : 'U';
    my $rrd_WindGustDir = defined $Weather{WindGustDir} ? $Weather{WindGustDir} : 'U';
    my $rrd_WindAvgDir = defined $Weather{WindAvgDir} ? $Weather{WindAvgDir} : 'U';
    my $rrd_WindGustSpeed = defined $Weather{WindGustSpeed} ? $Weather{WindGustSpeed} : 'U';
    my $rrd_WindAvgSpeed = defined $Weather{WindAvgSpeed} ? $Weather{WindAvgSpeed} : 'U';
    my $rrd_ApparentTemp = defined $Weather{TempOutdoorApparent} ? $Weather{TempOutdoorApparent} : 'U';
    my $rrd_RainRate = defined $Weather{RainRate} ? $Weather{RainRate} : 'U';
    my $rrd_RainTotal = defined $Weather{RainTotal} ? $Weather{RainTotal} : 'U';
    my $rrd_TempIndoor = defined $Weather{TempIndoor} ? $Weather{TempIndoor} : 'U';
    my $rrd_HumidIndoor = defined $Weather{HumidIndoor} ? $Weather{HumidIndoor} : 'U';
    my $rrd_DewIndoor = defined $Weather{DewIndoor} ? $Weather{DewIndoor} : 'U';
    my $rrd_TempSpare1 = defined $Weather{TempSpare1} ? $Weather{TempSpare1} : 'U';
    my $rrd_HumidSpare1 = defined $Weather{HumidSpare1} ? $Weather{HumidSpare1} : 'U';
    my $rrd_DewSpare1 = defined $Weather{DewSpare1} ? $Weather{DewSpare1} : 'U';
    my $rrd_TempSpare2 = defined $Weather{TempSpare2} ? $Weather{TempSpare2} : 'U';
    my $rrd_HumidSpare2 = defined $Weather{HumidSpare2} ? $Weather{HumidSpare2} : 'U';
    my $rrd_DewSpare2 = defined $Weather{DewSpare2} ? $Weather{DewSpare2} : 'U';
    my $rrd_TempSpare3 = defined $Weather{TempSpare3} ? $Weather{TempSpare3} : 'U';
    my $rrd_HumidSpare3 = defined $Weather{HumidSpare3} ? $Weather{HumidSpare3} : 'U';
    my $rrd_DewSpare3 = defined $Weather{DewSpare3} ? $Weather{DewSpare3} : 'U';

    my $rrd_TempSpare4 = defined $Weather{TempSpare4} ? $Weather{TempSpare4} : 'U';
    my $rrd_HumidSpare4 = defined $Weather{HumidSpare4} ? $Weather{HumidSpare4} : 'U';
    my $rrd_TempSpare5 = defined $Weather{TempSpare5} ? $Weather{TempSpare5} : 'U';
    my $rrd_HumidSpare5 = defined $Weather{HumidSpare5} ? $Weather{HumidSpare5} : 'U';
    my $rrd_TempSpare6 = defined $Weather{TempSpare6} ? $Weather{TempSpare6} : 'U';
    my $rrd_HumidSpare6 = defined $Weather{HumidSpare6} ? $Weather{HumidSpare6} : 'U';
    my $rrd_TempSpare7 = defined $Weather{TempSpare7} ? $Weather{TempSpare7} : 'U';
    my $rrd_HumidSpare7 = defined $Weather{HumidSpare7} ? $Weather{HumidSpare7} : 'U';
    my $rrd_TempSpare8 = defined $Weather{TempSpare8} ? $Weather{TempSpare8} : 'U';
    my $rrd_HumidSpare8 = defined $Weather{HumidSpare8} ? $Weather{HumidSpare8} : 'U';
    my $rrd_TempSpare9 = defined $Weather{TempSpare9} ? $Weather{TempSpare9} : 'U';
    my $rrd_HumidSpare9 = defined $Weather{HumidSpare9} ? $Weather{HumidSpare9} : 'U';
    my $rrd_TempSpare10 = defined $Weather{TempSpare10} ? $Weather{TempSpare10} : 'U';
    my $rrd_HumidSpare10 = defined $Weather{HumidSpare10} ? $Weather{HumidSpare10} : 'U';

    my $RRD = "$config_parms{weather_data_rrd}";

    my $time = time;
    my @d;

    &create_rrd($time) unless -e $RRD;

    if ($config_parms{weather_uom_temp} eq 'C') {
      grep { $_=convert_c2f($_) } ($rrd_TempOutdoor, $rrd_TempIndoor,
        $rrd_TempSpare1, $rrd_TempSpare2, $rrd_TempSpare3, $rrd_TempSpare4,
        $rrd_TempSpare5, $rrd_TempSpare6, $rrd_TempSpare7, $rrd_TempSpare8,
        $rrd_TempSpare9, $rrd_TempSpare10, $rrd_DewOutdoor, $rrd_DewIndoor,
        $rrd_DewSpare1, $rrd_DewSpare2, $rrd_DewSpare3, $rrd_ApparentTemp);
    }

    if ($config_parms{weather_uom_baro} eq 'mb') {
      grep { $_=convert_mb2in($_) } ($rrd_Barom);
    }

    if ($config_parms{weather_uom_wind} eq 'kph') {
      grep { $_=convert_km2mile($_) } ($rrd_WindGustSpeed, $rrd_WindAvgSpeed);
    }

    if ($config_parms{weather_uom_wind} eq 'm/s') {
      grep { $_=convert_mps2mph($_) } ($rrd_WindGustSpeed, $rrd_WindAvgSpeed);
    }

    if ($config_parms{weather_uom_rain} eq 'mm') {
      grep { $_=convert_mm2in($_)} ($rrd_RainTotal);
    }

    if ($config_parms{weather_uom_rainrate} eq 'mm/hr') {
      grep { $_=convert_mm2in($_)  } ($rrd_RainRate);
    }

    @d = ($rrd_TempOutdoor, $rrd_HumidOutdoor, $rrd_DewOutdoor, $rrd_Barom,
	  $rrd_WindGustDir, $rrd_WindAvgDir, $rrd_WindGustSpeed, $rrd_WindAvgSpeed,
	  $rrd_ApparentTemp, $rrd_RainRate, $rrd_RainTotal, $rrd_TempIndoor,
	  $rrd_HumidIndoor, $rrd_DewIndoor, $rrd_TempSpare1, $rrd_HumidSpare1,
    	  $rrd_DewSpare1, $rrd_TempSpare2, $rrd_HumidSpare2, $rrd_DewSpare2,
    	  $rrd_TempSpare3, $rrd_HumidSpare3, $rrd_DewSpare3,
    	  $rrd_TempSpare4, $rrd_HumidSpare4, $rrd_TempSpare5, $rrd_HumidSpare5,
    	  $rrd_TempSpare6, $rrd_HumidSpare6, $rrd_TempSpare7, $rrd_HumidSpare7,
    	  $rrd_TempSpare8, $rrd_HumidSpare8, $rrd_TempSpare9, $rrd_HumidSpare9,
    	  $rrd_TempSpare10, $rrd_HumidSpare10);
    #print "@d\n";

    # Store data in rrd database
    $" = ':';
    &update_rrd($time, @d);
    $" = ' ';

    # Store data in csv file
    &update_csv($time, @d) if $config_parms{weather_data_csv};
  }

# Create the graphs
$p_weather_graph = new Process_Item "&create_rrdgraph_all";
$tell_generate_graph = new Voice_Cmd "Generate weather graphs";

if (new_minute $config_parms{weather_graph_frequency} or said $tell_generate_graph) {

	if (said $tell_generate_graph) {
		$tell_generate_graph->respond('Updating weather graphs');
	}

	my $RRD = "$config_parms{weather_data_rrd}";
	$RRD_LAST = RRDs::last $RRD;
   	my $err=RRDs::error;
   	die "ERROR : unable to get last : $err\n" if $err;
	#print "Last : $RRD_LAST\n";

	# weather graphs creation
    $OS_win ? &create_rrdgraph_all : start $p_weather_graph;
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

    'RRA:AVERAGE:0.5:1:801',	# details for 6 hours (agregate 1 minute)

    'RRA:MIN:0.5:2:801',	# 1 day (agregate 2 minutes)
    'RRA:AVERAGE:0.5:2:801',
    'RRA:MAX:0.5:2:801',

    'RRA:MIN:0.5:5:641',	# 2 day (agregate 5 minutes)
    'RRA:AVERAGE:0.5:5:641',
    'RRA:MAX:0.5:5:641',

    'RRA:MIN:0.5:18:623',	# 1 week (agregate 18 minutes)
    'RRA:AVERAGE:0.5:18:623',
    'RRA:MAX:0.5:18:623',

    'RRA:MIN:0.5:35:618',	# 2 weeks (agregate 35 minutes)
    'RRA:AVERAGE:0.5:35:618',
    'RRA:MAX:0.5:35:618',

    'RRA:MIN:0.5:75:694',	# 1 month (agregate 1h15mn)
    'RRA:AVERAGE:0.5:75:694',
    'RRA:MAX:0.5:75:694',

    'RRA:MIN:0.5:150:694',	# 2 months (agregate 2h30mn)
    'RRA:AVERAGE:0.5:150:694',
    'RRA:MAX:0.5:150:694',

    'RRA:MIN:0.5:1080:268',	# 6 months (agregate 18 hours)
    'RRA:AVERAGE:0.5:1080:268',
    'RRA:MAX:0.5:1080:268',

    'RRA:MIN:0.5:2880:209',	# 12 months (agregate 2 days)
    'RRA:AVERAGE:0.5:2880:209',
    'RRA:MAX:0.5:2880:209',

    'RRA:MIN:0.5:4320:279',	# 2 years (agregate 3 days)
    'RRA:AVERAGE:0.5:4320:279',
    'RRA:MAX:0.5:4320:279',

    'RRA:MIN:0.5:8640:334',	# 5 months (agregate 6 days)
    'RRA:AVERAGE:0.5:8640:334',
    'RRA:MAX:0.5:8640:334';

    die "unable to create $RRD: $err\n" if $err = RRDs::error;
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
	my ($time, @data) = @_;

	print "** Parametre **\n" if $debug;
	print "OLD DATA : time = $last data = @last\n" if $debug;
	print "NEW DATA : time = $time data = @data\n" if $debug;

	@last = @data unless @last;
	$last = $time unless $last;
	$i = 0;
	# Zero change -> fill in flat lines
	if (0 >= grep $_ ne $last[$i++], @data) {
	    print "WARNING, loop 1...\n" if $debug;
	    print "No data change\n" if $debug;
	    for ($i = $last + $RRD_STEP; $i < $time; $i += $RRD_STEP) {
		    print "WARNING, loop 2...\n" if $debug;
		    print "...fill bucket\n" if $debug;
		    print "...bucket time = $i data = @last\n" if $debug;

		RRDs::update $RRD, "$i:@last";

		next if $err = RRDs::error and $err =~ /mininum one second step/;
		warn "$err\n" if $err;
		}
	    } elsif (($i = $time - $last) > $RRD_HEARTBEAT) {
		         print "WARNING, DETECT BUCKET...!\n" if $debug;
		         print "... $time - $last = $i\n" if $debug;
			 #$max = $i if $i > $max;
			 #$gaps++;# note number of gaps and max size
			}

			print "DATA INSERT : time = $time data = @data\n" if $debug;
      	RRDs::update $RRD, "$time:@data";	# add current data

	$last = $time;
	@last = @data;
	return if $err = RRDs::error and $err =~ /min.*one second step/;
	warn "$err\n" if $err;
}
#==============================================================================
# Create and/or update CSV file
#==============================================================================
sub update_csv {
	my ($time, @data) = @_;
	my $row_header;
	my $row_data;
	my $log_annee = (localtime)[5]+1900;
	my $log_mois = (localtime)[4]+1;
	my $log_jour = (localtime)[3];
	my $log_heure = (localtime)[2];
	my $log_minute = (localtime)[1];
	my $log_seconde = (localtime)[0];

	# Create flat file, useful to recreate RRD database
    	unless (-e "$config_parms{weather_data_csv}.$Year_Month_Now") {
	 $row_header = join(";",
	  'Epoch','Year','Month','Day','Hour','Minute','Seconde',
	  'Outdoor Temp', 'Outdoor Humidity', 'Temperature dewpoint',
	  'Pression', 'Direction wind', 'Direction average wind',
	  'Wind Speed', 'Average wind speed', 'Apparent Temperature',
	  'Rain rate', 'Total rain', 'Temperature indoor',
	  'Humidity indoor', 'Dewpoint indoor', 'Temperature module 1',
    	  'Humidity module 1', 'Dewpoint module 1', 'Temperature module 2',
    	  'Humidity module 2', 'Dewpoint module 2', 'Temperature module 3',
    	  'Humidity module 3', 'Dewpoint module 3',
    	  'Temperature 4', 'Humidity module 4', 'Temperature 5','Humidity module 5',
    	  'Temperature 6', 'Humidity module 6', 'Temperature 7','Humidity module 7',
    	  'Temperature 8', 'Humidity module 8', 'Temperature 9','Humidity module 9',
    	  'Temperature 10', 'Humidity module 10',"\n");

	 &logit("$config_parms{weather_data_csv}.$Year_Month_Now", $row_header,0);
    	}
       $row_data = join(";",
	  $time,$log_annee,$log_mois,$log_jour,$log_heure,$log_minute,$log_seconde,
	  $data[0], $data[1], $data[2], $data[3], $data[4], $data[5],
	  $data[6], $data[7], $data[8], $data[9], $data[10], $data[11],
	  $data[12], $data[13], $data[14], $data[15], $data[16], $data[17],
	  $data[18], $data[19], $data[20], $data[21], $data[22],
	  $data[23], $data[24], $data[25], $data[26], $data[27], $data[28], $data[29],
	  $data[30], $data[31], $data[32], $data[33], $data[34], $data[35], $data[36],
	  "\n");

       &logit("$config_parms{weather_data_csv}.$Year_Month_Now", $row_data,0);
}
#==============================================================================
# Generate all the weather graphs
#==============================================================================
sub create_rrdgraph_all {

	my %sensor_names;

        &main::read_parm_hash(\%sensor_names, $main::config_parms{weather_graph_sensor_names});

	&create_rrdgraph_tempout unless ($config_parms{weather_graph_skip} =~ /tempout/);
	&create_rrdgraph_humout unless ($config_parms{weather_graph_skip} =~ /humout/);
	&create_rrdgraph_tempin(%sensor_names) unless ($config_parms{weather_graph_skip} =~ /tempin/);
	&create_rrdgraph_humin(%sensor_names) unless ($config_parms{weather_graph_skip} =~ /humin/);
	&create_rrdgraph_winddir unless ($config_parms{weather_graph_skip} =~ /winddir/);
	&create_rrdgraph_press unless ($config_parms{weather_graph_skip} =~ /press/);
	&create_rrdgraph_windspeed unless ($config_parms{weather_graph_skip} =~ /windspeed/);
	&create_rrdgraph_raintotal unless ($config_parms{weather_graph_skip} =~ /raintotal/);
	&create_rrdgraph_rainrate unless ($config_parms{weather_graph_skip} =~ /rainrate/);
}
#==============================================================================
# rrdtool 1.2 and newer is picky about colons in the comment line
# so build the footers differently depending on the version
#==============================================================================
sub get_weather_footer1 {
  my $colon;
  my $footer;
  my $starttime;
  my ($start, $step, $datapoint) = @_;
  $starttime = CORE::localtime($start);
  if ( $RRDs::VERSION >= 1.2 ) {
    $colon = '\\\\:';
    $starttime =~ s/:/\\\\:/g;
  } else {
    $colon= ':';
  }
  $footer="Start time$colon $starttime   Step size$colon " . convertstep($step) . "   Data points$colon $datapoint";
  # print_log "Footer: $footer";
  return $footer;
}

sub get_weather_footer2 {
  my $footer;
  if ( $RRDs::VERSION >= 1.2 ) {
    $footer='$footer ' . "= \"$config_parms{weather_graph_footer}\";";
    eval $footer;
    $footer =~ s/:/\\\\:/g;
  } else {
    $footer= $config_parms{weather_graph_footer};
  }
  return $footer;
}
#==============================================================================
# Convert step size in seconds to string format
# Input : step size in numeric format
# Output : step size in string format
# Note : d = day, h = hour, mn = minute, s = second
#==============================================================================
sub convertstep {
	my ($stepnum) = @_;
	my $stepchar = '';
	my $temp;
	my $reste;

	if ( ($temp=int($stepnum/(24*3600))) > 0) {
		$stepchar=$temp . 'd';
	  }
	$reste=$stepnum-(24*3600*int($stepnum/(24*3600)));
	if ( ($temp=int($reste/3600)) > 0) {
		$stepchar.=$temp . 'h';
	  }
	$reste=$reste-3600*int($reste/3600);
	if ( ($temp=int($reste/60)) > 0) {
		$stepchar.=$temp . 'mn';
	  }
	$reste=$reste-60*int($reste/60);
	if ( $reste > 0) {
		$stepchar.=$reste . 's';
	  }
	return $stepchar;
}
#==============================================================================
# Build call function RRD::GRAPH for outdoor temperature
#==============================================================================
sub create_rrdgraph_tempout {
    my $tabgtime;
    my $celgtime;
    my $create_graph;
    my $height = 250;		# graph drawing area --height in pixels
    my $width = 600;		# graph drawing area --width in pixels
    my $coloraltbg = 'EEEEEE';	# alternating (with white) background color
    my $colortempavg = 'ff0000';	# color of primary variable average line
    my $colorna = 'C0C0C0';		# color for unknown area or 0 for gaps
    my $colortemp = '330099';	# color of primary variable range area
    my $colortempin = '990099';	# indoor RGB color or 0 for no indoor lines
    my $colorzero = '000000';	# color of zero line
    my $colordew = '00ff00';	# color of dew point
    my $colorapparent = '3300FF';	# color of apparent temperature
    my $colorwhite = 'ffffff';	# color white
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;

    my $time1;
    my $time2;
    my $err;
    my ($start,$step,$names,$array);
    my $datapoint;
    my $starttime;
    my $secs;
    my $footer1;
    my $footer2;

    $footer2 = get_weather_footer2();

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;
    my $rrd_format = $config_parms{weather_graph_format} ;
    tr/A-Z/a-z/ for $rrd_format ;

    $tabgtime =  [
  ['6hour',  'Temperatures last 6 hours','--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF',"24000"],
  ['12hour',  'Temperatures last 12 hours','--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF',"45000"],
  ['1day',  'Temperatures last 1 day','--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF',"90000"],
  ['2day',  'Temperatures last 2 days','--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF',"180000"],
  ['1week', 'Temperatures last 1 week','--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"648000"],
  ['2week', 'Temperatures last 2 weeks','--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"1260000"],
  ['1month', 'Temperatures last 1 month','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"2700000"],
  ['2month', 'Temperatures last 2 months','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"5400000"],
  ['6month', 'Temperatures last 6 months','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"16848000"],
  ['1year', 'Temperatures last 1 year','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"33696000"],
  ['2year', 'Temperatures last 2 years','--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"67392000"],
  ['5year', 'Temperatures last 5 years','--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF',"168480000"]
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {

     $secs = $celgtime->[4];
     $time1  = $secs/600*int(($RRD_LAST-$secs)/($secs/600));
     $time2  = $secs/600*int(($RRD_LAST)/($secs/600));

     ($start,$step,$names,$array) = RRDs::fetch "$config_parms{weather_data_rrd}", "AVERAGE", "-s", "$time1", "-e", "$time2" ;
     $err=RRDs::error;
     die "ERROR : function RRDs::fetch : $err\n" if $err;
     $datapoint = $#$array + 1;
     $footer1 = get_weather_footer1($start, $step, $datapoint);

     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_tempout_$celgtime->[0].$rrd_format",
"--title", "$celgtime->[1]",
"--height","$height",
"--width", "$width",
"--imgformat", "$config_parms{weather_graph_format}",
"--units-exponent", "0",
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^
. "\"--start\"," . "\"$time1\","
. "\"--end\"," . "\"$time2\","
. ($RRD_LAZY ? "\"--lazy\"," : '')
. "\"--vertical-label\","
. ($config_parms{weather_uom_temp} eq 'C' ? "\"Degrees Celsius\"," : "\"Degrees Fahrenheit\",")
. qq^"$celgtime->[2]",
"DEF:var=$rrd_dir:temp:AVERAGE",
^
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fvar=var,32,-,5,9,/,*\"," : "\"CDEF:fvar=var\",")
."\"$celgtime->[3]\","
."\"DEF:mintemp=$rrd_dir:temp:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintemp=mintemp,32,-,5,9,/,*\"," : "\"CDEF:fmintemp=mintemp\",")
."\"DEF:maxtemp=$rrd_dir:temp:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtemp=maxtemp,32,-,5,9,/,*\"," : "\"CDEF:fmaxtemp=maxtemp\",")
."\"DEF:mindew=$rrd_dir:dew:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmindew=mindew,32,-,5,9,/,*\"," : "\"CDEF:fmindew=mindew\",")
."\"DEF:maxdew=$rrd_dir:dew:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxdew=maxdew,32,-,5,9,/,*\"," : "\"CDEF:fmaxdew=maxdew\",")
."\"DEF:dew=$rrd_dir:dew:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fdew=dew,32,-,5,9,/,*\"," : "\"CDEF:fdew=dew\",")
."\"DEF:apparent=$rrd_dir:apparent:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fapparent=apparent,32,-,5,9,/,*\"," : "\"CDEF:fapparent=apparent\",")
."\"DEF:minapparent=$rrd_dir:apparent:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fminapparent=minapparent,32,-,5,9,/,*\"," : "\"CDEF:fminapparent=minapparent\",")
."\"DEF:maxapparent=$rrd_dir:apparent:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxapparent=maxapparent,32,-,5,9,/,*\"," : "\"CDEF:fmaxapparent=maxapparent\",")
."\"DEF:minintemp=$rrd_dir:intemp:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fminintemp=minintemp,32,-,5,9,/,*\"," : "\"CDEF:fminintemp=minintemp\",")
."\"DEF:maxintemp=$rrd_dir:intemp:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxintemp=maxintemp,32,-,5,9,/,*\"," : "\"CDEF:fmaxintemp=maxintemp\",")
."\"DEF:intemp=$rrd_dir:intemp:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fintemp=intemp,32,-,5,9,/,*\"," : "\"CDEF:fintemp=intemp\",")
."\"DEF:indew=$rrd_dir:indew:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:findew=indew,32,-,5,9,/,*\"," : "\"CDEF:findew=indew\",")
. qq^
"CDEF:wipeout=var,UN,INF,UNKN,IF",
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF",
"AREA:background#$coloraltbg",
^
. ($config_parms{weather_uom_temp} eq 'C' ? "\"HRULE:0#$colorzero\",":"\"HRULE:32#$colorzero\",")
. qq^
"LINE2:fvar#$colortemp:Outdoor temperature ",
"GPRINT:fmintemp:MIN:Min  \\\\: %5.1lf",
"GPRINT:fmaxtemp:MAX:Max  \\\\: %5.1lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %5.1lf",
"GPRINT:fvar:LAST:Last    \\\\: %5.1lf\\\\n",

"LINE2:fapparent#$colorapparent:Apparent Temperature",
"GPRINT:fminapparent:MIN:Min  \\\\: %5.1lf",
"GPRINT:fmaxapparent:MAX:Max  \\\\: %5.1lf",
"GPRINT:fapparent:AVERAGE:Avg \\\\: %5.1lf",
"GPRINT:fapparent:LAST:Last    \\\\: %5.1lf\\\\n",

"LINE2:fdew#$colordew:Dew Point           ",
"GPRINT:fmindew:MIN:Min  \\\\: %5.1lf",
"GPRINT:fmaxdew:MAX:Max  \\\\: %5.1lf",
"GPRINT:fdew:AVERAGE:Avg \\\\: %5.1lf",
"GPRINT:fdew:LAST:Last    \\\\: %5.1lf\\\\n",

"LINE2:fvar#$colortempavg:Average outdoor temperature",
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna",
^
. "\"COMMENT:$footer1\\\\c\","
. "\"COMMENT:$footer2\\\\c\""
. ")";

   print "\n$str_graph \n" if $debug;
   eval $str_graph;
   my $err=RRDs::error;
   die "ERROR : function RRDs::graph : $err\n" if $err;
   }
  }
}
#==============================================================================
# Build call function RRD::GRAPH for indoor temperature
#==============================================================================
sub create_rrdgraph_tempin {
    my $tabgtime;
    my $celgtime;
    my $create_graph;
    my $height = 250;		# graph drawing area --height in pixels
    my $width = 600;		# graph drawing area --width in pixels
    my $coloraltbg = 'EEEEEE';	# alternating (with white) background color
    my $colortempavg = 'ff0000';	# color of primary variable average line
    my $colorna = 'C0C0C0';		# color for unknown area or 0 for gaps
    my $colortemp = '330099';	# color of primary variable range area
    my $colortempin = '990099';	# indoor RGB color or 0 for no indoor lines
    my $colorzero = '000000';	# color of zero line
    my $colordew = '00ff00';	# color of dew point
    my $colorwchill = '3300FF';	# color of wind chill
    my $colorwhite = 'ffffff';	# color white
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;
    my $rrd_format = $config_parms{weather_graph_format} ;
    tr/A-Z/a-z/ for $rrd_format ;

    my $time1;
    my $time2;
    my $err;
    my ($start,$step,$names,$array);
    my $datapoint;
    my $starttime;
    my $secs;
    my $footer1;
    my $footer2;

    my %sensor_names = @_;

    # Sensors list for this graph
    my @list_sensors_graph = ('intemp', 'indew', 'tempspare1', 'tempspare2', 'tempspare3', 'tempspare4', 'tempspare5', 'tempspare6', 'tempspare7', 'tempspare8', 'tempspare9', 'tempspare10');

    # Calcul max lenght of sensor name
    my $max=0;
    for my $sensor (@list_sensors_graph) {
	    if (length($sensor_names{$sensor}) > $max) {
	    	$max=length($sensor_names{$sensor});
	 	}
 	}
    print "Max sensor length name : ",$max,"\n" if $debug;

    $footer2 = get_weather_footer2();

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

        $tabgtime =  [
  ['6hour',  'Temperatures last 6 hours','--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF',"24000"],
  ['12hour',  'Temperatures last 12 hours','--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF',"45000"],
  ['1day',  'Temperatures last 1 day','--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF',"90000"],
  ['2day',  'Temperatures last 2 days','--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF',"180000"],
  ['1week', 'Temperatures last 1 week','--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"648000"],
  ['2week', 'Temperatures last 2 weeks','--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"1260000"],
  ['1month', 'Temperatures last 1 month','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"2700000"],
  ['2month', 'Temperatures last 2 months','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"5400000"],
  ['6month', 'Temperatures last 6 months','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"16848000"],
  ['1year', 'Temperatures last 1 year','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"33696000"],
  ['2year', 'Temperatures last 2 years','--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"67392000"],
  ['5year', 'Temperatures last 5 years','--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF',"168480000"]
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {

     $secs = $celgtime->[4];
     $time1  = $secs/600*int(($RRD_LAST-$secs)/($secs/600));
     $time2  = $secs/600*int(($RRD_LAST)/($secs/600));

     ($start,$step,$names,$array) = RRDs::fetch "$config_parms{weather_data_rrd}", "AVERAGE", "-s", "$time1", "-e", "$time2" ;
     $err=RRDs::error;
     die "ERROR : function RRDs::fetch : $err\n" if $err;
     $datapoint = $#$array + 1;
     $footer1 = get_weather_footer1($start, $step, $datapoint);

     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_tempin_$celgtime->[0].$rrd_format",
"--title", "$celgtime->[1]",
"--height","$height",
"--width", "$width",
"--imgformat", "$config_parms{weather_graph_format}",
"--units-exponent", "0",
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^
. "\"--start\"," . "\"$time1\","
. "\"--end\"," . "\"$time2\","
. ($RRD_LAZY ? "\"--lazy\"," : '')
. "\"--vertical-label\","
. ($config_parms{weather_uom_temp} eq 'C' ? "\"Degrees Celsius\"," : "\"Degrees Fahrenheit\",")
. qq^"$celgtime->[2]",
"DEF:var=$rrd_dir:temp:AVERAGE",
^
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fvar=var,32,-,5,9,/,*\"," : "\"CDEF:fvar=var\",")
."\"$celgtime->[3]\","
."\"DEF:mintemp=$rrd_dir:temp:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintemp=mintemp,32,-,5,9,/,*\"," : "\"CDEF:fmintemp=mintemp\",")
."\"DEF:maxtemp=$rrd_dir:temp:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtemp=maxtemp,32,-,5,9,/,*\"," : "\"CDEF:fmaxtemp=maxtemp\",")

."\"DEF:minintemp=$rrd_dir:intemp:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fminintemp=minintemp,32,-,5,9,/,*\"," : "\"CDEF:fminintemp=minintemp\",")
."\"DEF:maxintemp=$rrd_dir:intemp:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxintemp=maxintemp,32,-,5,9,/,*\"," : "\"CDEF:fmaxintemp=maxintemp\",")
."\"DEF:intemp=$rrd_dir:intemp:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fintemp=intemp,32,-,5,9,/,*\"," : "\"CDEF:fintemp=intemp\",")

."\"DEF:minindew=$rrd_dir:indew:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fminindew=minindew,32,-,5,9,/,*\"," : "\"CDEF:fminindew=minindew\",")
."\"DEF:maxindew=$rrd_dir:indew:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxindew=maxindew,32,-,5,9,/,*\"," : "\"CDEF:fmaxindew=maxindew\",")
."\"DEF:indew=$rrd_dir:indew:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:findew=indew,32,-,5,9,/,*\"," : "\"CDEF:findew=indew\",")

."\"DEF:mintempspare1=$rrd_dir:tempspare1:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintempspare1=mintempspare1,32,-,5,9,/,*\"," : "\"CDEF:fmintempspare1=mintempspare1\",")
."\"DEF:maxtempspare1=$rrd_dir:tempspare1:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtempspare1=maxtempspare1,32,-,5,9,/,*\"," : "\"CDEF:fmaxtempspare1=maxtempspare1\",")
."\"DEF:tempspare1=$rrd_dir:tempspare1:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:ftempspare1=tempspare1,32,-,5,9,/,*\"," : "\"CDEF:ftempspare1=tempspare1\",")

."\"DEF:mintempspare2=$rrd_dir:tempspare2:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintempspare2=mintempspare2,32,-,5,9,/,*\"," : "\"CDEF:fmintempspare2=mintempspare2\",")
."\"DEF:maxtempspare2=$rrd_dir:tempspare2:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtempspare2=maxtempspare2,32,-,5,9,/,*\"," : "\"CDEF:fmaxtempspare2=maxtempspare2\",")
."\"DEF:tempspare2=$rrd_dir:tempspare2:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:ftempspare2=tempspare2,32,-,5,9,/,*\"," : "\"CDEF:ftempspare2=tempspare2\",")

."\"DEF:mintempspare3=$rrd_dir:tempspare3:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintempspare3=mintempspare3,32,-,5,9,/,*\"," : "\"CDEF:fmintempspare3=mintempspare3\",")
."\"DEF:maxtempspare3=$rrd_dir:tempspare3:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtempspare3=maxtempspare3,32,-,5,9,/,*\"," : "\"CDEF:fmaxtempspare3=maxtempspare3\",")
."\"DEF:tempspare3=$rrd_dir:tempspare3:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:ftempspare3=tempspare3,32,-,5,9,/,*\"," : "\"CDEF:ftempspare3=tempspare3\",")

."\"DEF:mintempspare4=$rrd_dir:tempspare4:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintempspare4=mintempspare4,32,-,5,9,/,*\"," : "\"CDEF:fmintempspare4=mintempspare4\",")
."\"DEF:maxtempspare4=$rrd_dir:tempspare4:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtempspare4=maxtempspare4,32,-,5,9,/,*\"," : "\"CDEF:fmaxtempspare4=maxtempspare4\",")
."\"DEF:tempspare4=$rrd_dir:tempspare4:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:ftempspare4=tempspare4,32,-,5,9,/,*\"," : "\"CDEF:ftempspare4=tempspare4\",")

."\"DEF:mintempspare5=$rrd_dir:tempspare5:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintempspare5=mintempspare5,32,-,5,9,/,*\"," : "\"CDEF:fmintempspare5=mintempspare5\",")
."\"DEF:maxtempspare5=$rrd_dir:tempspare5:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtempspare5=maxtempspare5,32,-,5,9,/,*\"," : "\"CDEF:fmaxtempspare5=maxtempspare5\",")
."\"DEF:tempspare5=$rrd_dir:tempspare5:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:ftempspare5=tempspare5,32,-,5,9,/,*\"," : "\"CDEF:ftempspare5=tempspare5\",")

."\"DEF:mintempspare6=$rrd_dir:tempspare6:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintempspare6=mintempspare6,32,-,5,9,/,*\"," : "\"CDEF:fmintempspare6=mintempspare6\",")
."\"DEF:maxtempspare6=$rrd_dir:tempspare6:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtempspare6=maxtempspare6,32,-,5,9,/,*\"," : "\"CDEF:fmaxtempspare6=maxtempspare6\",")
."\"DEF:tempspare6=$rrd_dir:tempspare6:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:ftempspare6=tempspare6,32,-,5,9,/,*\"," : "\"CDEF:ftempspare6=tempspare6\",")

."\"DEF:mintempspare7=$rrd_dir:tempspare7:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintempspare7=mintempspare7,32,-,5,9,/,*\"," : "\"CDEF:fmintempspare7=mintempspare7\",")
."\"DEF:maxtempspare7=$rrd_dir:tempspare7:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtempspare7=maxtempspare7,32,-,5,9,/,*\"," : "\"CDEF:fmaxtempspare7=maxtempspare7\",")
."\"DEF:tempspare7=$rrd_dir:tempspare7:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:ftempspare7=tempspare7,32,-,5,9,/,*\"," : "\"CDEF:ftempspare7=tempspare7\",")

."\"DEF:mintempspare8=$rrd_dir:tempspare8:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintempspare8=mintempspare8,32,-,5,9,/,*\"," : "\"CDEF:fmintempspare8=mintempspare8\",")
."\"DEF:maxtempspare8=$rrd_dir:tempspare8:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtempspare8=maxtempspare8,32,-,5,9,/,*\"," : "\"CDEF:fmaxtempspare8=maxtempspare8\",")
."\"DEF:tempspare8=$rrd_dir:tempspare8:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:ftempspare8=tempspare8,32,-,5,9,/,*\"," : "\"CDEF:ftempspare8=tempspare8\",")

."\"DEF:mintempspare9=$rrd_dir:tempspare9:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintempspare9=mintempspare9,32,-,5,9,/,*\"," : "\"CDEF:fmintempspare9=mintempspare9\",")
."\"DEF:maxtempspare9=$rrd_dir:tempspare9:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtempspare9=maxtempspare9,32,-,5,9,/,*\"," : "\"CDEF:fmaxtempspare9=maxtempspare9\",")
."\"DEF:tempspare9=$rrd_dir:tempspare9:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:ftempspare9=tempspare9,32,-,5,9,/,*\"," : "\"CDEF:ftempspare9=tempspare9\",")

."\"DEF:mintempspare10=$rrd_dir:tempspare10:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmintempspare10=mintempspare10,32,-,5,9,/,*\"," : "\"CDEF:fmintempspare10=mintempspare10\",")
."\"DEF:maxtempspare10=$rrd_dir:tempspare10:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxtempspare10=maxtempspare10,32,-,5,9,/,*\"," : "\"CDEF:fmaxtempspare10=maxtempspare10\",")
."\"DEF:tempspare10=$rrd_dir:tempspare10:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:ftempspare10=tempspare10,32,-,5,9,/,*\"," : "\"CDEF:ftempspare10=tempspare10\",")

. qq^
#"CDEF:fdeltachill=fvar,fminchill,-",
"CDEF:wipeout=var,UN,INF,UNKN,IF",
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF",
"AREA:background#$coloraltbg",
^
. ($config_parms{weather_uom_temp} eq 'C' ? "\"HRULE:0#$colorzero\",":"\"HRULE:32#$colorzero\",")

. ($sensor_names{intemp} ?
	"\"LINE2:fintemp#990000:" . sprintf("%-${max}s",$sensor_names{intemp}) . "\","
	."\"GPRINT:fminintemp:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxintemp:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:fintemp:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:fintemp:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{indew} ?
	"\"LINE2:findew#ff9900:" . sprintf("%-${max}s",$sensor_names{indew}) . "\","
	."\"GPRINT:fminindew:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxindew:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:findew:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:findew:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{tempspare1} ?
	"\"LINE2:ftempspare1#FF0000:" . sprintf("%-${max}s",$sensor_names{tempspare1}) . "\","
	."\"GPRINT:fmintempspare1:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxtempspare1:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:ftempspare1:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:ftempspare1:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{tempspare2} ?
	"\"LINE2:ftempspare2#990099:" . sprintf("%-${max}s",$sensor_names{tempspare2}) . "\","
	."\"GPRINT:fmintempspare2:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxtempspare2:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:ftempspare2:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:ftempspare2:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{tempspare3} ?
	"\"LINE2:ftempspare3#CC0099:" . sprintf("%-${max}s",$sensor_names{tempspare3}) . "\","
	."\"GPRINT:fmintempspare3:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxtempspare3:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:ftempspare3:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:ftempspare3:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{tempspare4} ?
	"\"LINE2:ftempspare4#CC33CC:" . sprintf("%-${max}s",$sensor_names{tempspare4}) . "\","
	."\"GPRINT:fmintempspare4:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxtempspare4:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:ftempspare4:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:ftempspare4:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{tempspare5} ?
	"\"LINE2:ftempspare5#FF00FF:" . sprintf("%-${max}s",$sensor_names{tempspare5}) . "\","
	."\"GPRINT:fmintempspare5:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxtempspare5:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:ftempspare5:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:ftempspare5:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{tempspare6} ?
	"\"LINE2:ftempspare6#FF99CC:" . sprintf("%-${max}s",$sensor_names{tempspare6}) . "\","
	."\"GPRINT:fmintempspare6:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxtempspare6:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:ftempspare6:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:ftempspare6:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{tempspare7} ?
	"\"LINE2:ftempspare7#99FF00:" . sprintf("%-${max}s",$sensor_names{tempspare7}) . "\","
	."\"GPRINT:fmintempspare7:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxtempspare7:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:ftempspare7:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:ftempspare7:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{tempspare8} ?
	"\"LINE2:ftempspare8#006600:" . sprintf("%-${max}s",$sensor_names{tempspare8}) . "\","
	."\"GPRINT:fmintempspare8:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxtempspare8:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:ftempspare8:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:ftempspare8:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{tempspare9} ?
	"\"LINE2:ftempspare9#66FFFF:" . sprintf("%-${max}s",$sensor_names{tempspare9}) . "\","
	."\"GPRINT:fmintempspare9:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxtempspare9:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:ftempspare9:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:ftempspare9:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{tempspare10} ?
	"\"LINE2:ftempspare10#0000CC:" . sprintf("%-${max}s",$sensor_names{tempspare10}) . "\","
	."\"GPRINT:fmintempspare10:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:fmaxtempspare10:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:ftempspare10:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:ftempspare10:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. qq^
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna",
^
. "\"COMMENT:$footer1\\\\c\","
. "\"COMMENT:$footer2\\\\c\""
. ")";

   print "\n$str_graph \n" if $debug;
   eval $str_graph;
   my $err=RRDs::error;
   die "ERROR : function RRDs::graph : $err\n" if $err;
   }
  }
}

#==============================================================================
# Build call function RRD::GRAPH for wind direction
#==============================================================================
sub create_rrdgraph_winddir {
    my $tabgtime;
    my $celgtime;
    my $create_graph;
    my $height = 250;		# graph drawing area --height in pixels
    my $width = 600;		# graph drawing area --width in pixels
    my $coloraltbg = 'EEEEEE';		# alternating (with white) background color
    my $colormoydir = 'ff0000';		# color of primary variable average line (red)
    my $colorna = 'C0C0C0';	# color for unknown area or 0 for gaps (barre noire verticale)
    my $colordir = '330099';		# color of wind chill
    my $colorwhite = 'ffffff';		# color white
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;
    my $rrd_format = $config_parms{weather_graph_format} ;
    tr/A-Z/a-z/ for $rrd_format ;

    my $time1;
    my $time2;
    my $err;
    my ($start,$step,$names,$array);
    my $datapoint;
    my $starttime;
    my $secs;
    my $footer1;
    my $footer2;

    $footer2 = get_weather_footer2();

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

    $tabgtime =  [
  ['6hour',  'Wind direction last 6 hours','--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF',"24000"],
  ['12hour',  'Wind direction last 12 hours','--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF',"45000"],
  ['1day',  'Wind direction last 1 day','--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF',"90000"],
  ['2day',  'Wind direction last 2 days','--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF',"180000"],
  ['1week', 'Wind direction last 1 week','--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"648000"],
  ['2week', 'Wind direction last 2 weeks','--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"1260000"],
  ['1month', 'Wind direction last 1 month','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"2700000"],
  ['2month', 'Wind direction last 2 months','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"5400000"],
  ['6month', 'Wind direction last 6 months','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"16848000"],
  ['1year', 'Wind direction last 1 year','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"33696000"],
  ['2year', 'Wind direction last 2 years','--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"67392000"],
  ['5year', 'Wind direction last 5 years','--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF',"168480000"]
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {

     $secs = $celgtime->[4];
     $time1  = $secs/600*int(($RRD_LAST-$secs)/($secs/600));
     $time2  = $secs/600*int(($RRD_LAST)/($secs/600));

     ($start,$step,$names,$array) = RRDs::fetch "$config_parms{weather_data_rrd}", "AVERAGE", "-s", "$time1", "-e", "$time2" ;
     $err=RRDs::error;
     die "ERROR : function RRDs::fetch : $err\n" if $err;
     $datapoint = $#$array + 1;
     $footer1 = get_weather_footer1($start, $step, $datapoint);

     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_winddir_$celgtime->[0].$rrd_format",
"--title", "$celgtime->[1]",
"--height","$height",
"--width", "$width",
"--imgformat", "$config_parms{weather_graph_format}",
"--units-exponent", "0",
"--alt-autoscale",
"-l", "0","-u","360",
"--y-grid" ,"45:1",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^
. "\"--start\"," . "\"$time1\","
. "\"--end\"," . "\"$time2\","
. ($RRD_LAZY ? "\"--lazy\"," : '')
. qq^"--vertical-label", "Degrees",
"$celgtime->[2]",	# start seconds

"DEF:var=$rrd_dir:dir:AVERAGE",
"CDEF:fvar=var",
"$celgtime->[3]",
"DEF:mindir=$rrd_dir:dir:MIN",
"CDEF:fmindir=mindir",
"DEF:maxdir=$rrd_dir:dir:MAX",
"CDEF:fmaxdir=maxdir",

"CDEF:wipeout=var,UN,INF,UNKN,IF",
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF",
"AREA:background#$coloraltbg",

"LINE2:fvar#$colormoydir:Average direction",
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:fmaxdir#$colordir:Direction",
"AREA:fmindir#$colorwhite",
"LINE2:fvar#$colormoydir",
"GPRINT:fmindir:MIN:Min \\\\: %3.1lf",
"GPRINT:fmaxdir:MAX:Max \\\\: %3.1lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %3.1lf",
"GPRINT:fvar:LAST:Last \\\\: %3.1lf\\\\n",

"AREA:wipeout2#$colorna",
"COMMENT:(0 N)-(45 NE)-(90 E)-(135 SE)-(180 S)-(225 SW)-(270 W)-(315 NW)-(360 N)\\\\c",
"COMMENT:\\\\n",
^
. "\"COMMENT:$footer1\\\\c\","
. "\"COMMENT:$footer2\\\\c\""
. ")";

   print "\n$str_graph \n" if $debug;
   eval $str_graph;
   my $err=RRDs::error;
   die "ERROR : function RRDs::graph : $err\n" if $err;
   }
  }
}

#==============================================================================
# Build call function RRD::GRAPH for outdoor humidity
#==============================================================================
sub create_rrdgraph_humout {
    my $tabgtime;
    my $celgtime;
    my $create_graph;
    my $height = 250;		# graph drawing area --height in pixels
    my $width = 600;		# graph drawing area --width in pixels
    my $coloraltbg = 'EEEEEE';		# alternating (with white) background color
    my $colormoyhumid = 'ff0000';		# color of primary variable average line (red)
    my $colorna = 'C0C0C0';	# color for unknown area or 0 for gaps (barre noire verticale)
    my $colorhumid = '330099';		# color of wind chill
    my $colorwhite = 'ffffff';		# color white
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;
    my $rrd_format = $config_parms{weather_graph_format} ;
    tr/A-Z/a-z/ for $rrd_format ;


    my $time1;
    my $time2;
    my $err;
    my ($start,$step,$names,$array);
    my $datapoint;
    my $starttime;
    my $secs;
    my $footer1;
    my $footer2;

    $footer2 = get_weather_footer2();

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

        $tabgtime =  [
  ['6hour',  'Outdoor humidity last 6 hours','--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF',"24000"],
  ['12hour',  'Outdoor humidity last 12 hours','--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF',"45000"],
  ['1day',  'Outdoor humidity last 1 day','--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF',"90000"],
  ['2day',  'Outdoor humidity last 2 days','--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF',"180000"],
  ['1week', 'Outdoor humidity last 1 week','--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"648000"],
  ['2week', 'Outdoor humidity last 2 weeks','--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"1260000"],
  ['1month', 'Outdoor humidity last 1 month','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"2700000"],
  ['2month', 'Outdoor humidity last 2 months','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"5400000"],
  ['6month', 'Outdoor humidity last 6 months','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"16848000"],
  ['1year', 'Outdoor humidity last 1 year','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"33696000"],
  ['2year', 'Outdoor humidity last 2 years','--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"67392000"],
  ['5year', 'Outdoor humidity last 5 years','--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF',"168480000"]
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {

     $secs = $celgtime->[4];
     $time1  = $secs/600*int(($RRD_LAST-$secs)/($secs/600));
     $time2  = $secs/600*int(($RRD_LAST)/($secs/600));

     ($start,$step,$names,$array) = RRDs::fetch "$config_parms{weather_data_rrd}", "AVERAGE", "-s", "$time1", "-e", "$time2" ;
     $err=RRDs::error;
     die "ERROR : function RRDs::fetch : $err\n" if $err;
     $datapoint = $#$array + 1;
     $footer1 = get_weather_footer1($start, $step, $datapoint);

     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_humout_$celgtime->[0].$rrd_format",
"--title", "$celgtime->[1]",
"--height","$height",
"--width", "$width",
"--imgformat", "$config_parms{weather_graph_format}",
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
"--lower-limit","0",
"--upper-limit","100",
"--y-grid", "5:2",
^
. "\"--start\"," . "\"$time1\","
. "\"--end\"," . "\"$time2\","
. ($RRD_LAZY ? "\"--lazy\"," : '')
. qq^"--vertical-label", "Percent %",
"$celgtime->[2]",

"DEF:var=$rrd_dir:humid:AVERAGE",
"CDEF:fvar=var",
"$celgtime->[3]",
"DEF:minhumid=$rrd_dir:humid:MIN",
"DEF:maxhumid=$rrd_dir:humid:MAX",

"CDEF:wipeout=var,UN,INF,UNKN,IF",
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF",
"AREA:background#$coloraltbg",

"LINE2:var#$colormoyhumid:Average outdoor humidity\\\\n",
"AREA:maxhumid#$colorhumid:Outdoor humidity",
"AREA:minhumid#$colorwhite",
"LINE2:var#$colormoyhumid",
"GPRINT:minhumid:MIN:Min \\\\: %2.1lf",
"GPRINT:maxhumid:MAX:Max \\\\: %2.1lf",
"GPRINT:var:AVERAGE:Avg \\\\: %2.1lf",
"GPRINT:var:LAST:Last \\\\: %2.1lf\\\\n",

"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna",
^
. "\"COMMENT:$footer1\\\\c\","
. "\"COMMENT:$footer2\\\\c\""
. ")";

   print "\n$str_graph \n" if $debug;
   eval $str_graph;
   my $err=RRDs::error;
   die "ERROR : function RRDs::graph : $err\n" if $err;
   }
  }
}
#==============================================================================
# Build call function RRD::GRAPH for indoor humidity
#==============================================================================
sub create_rrdgraph_humin {
    my $tabgtime;
    my $celgtime;
    my $create_graph;
    my $height = 250;		# graph drawing area --height in pixels
    my $width = 600;		# graph drawing area --width in pixels
    my $coloraltbg = 'EEEEEE';	# alternating (with white) background color
    my $colormoyhumid = 'ff0000';		# color of primary variable average line (red)
    my $colorna = 'C0C0C0';		# color for unknown area or 0 for gaps
    my $colorhumid = '330099';		# color of wind chill
    my $colorzero = '000000';	# color of zero line
    my $colorwhite = 'ffffff';	# color white
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;

    my $time1;
    my $time2;
    my $err;
    my ($start,$step,$names,$array);
    my $datapoint;
    my $starttime;
    my $secs;
    my $footer1;
    my $footer2;

    $footer2 = get_weather_footer2();

    my $rrd_format = $config_parms{weather_graph_format} ;
    tr/A-Z/a-z/ for $rrd_format ;

    my %sensor_names = @_;

    # Sensors list for this graph
    my @list_sensors_graph = ('inhumid', 'humidspare1', 'humidspare2', 'humidspare3', 'humidspare4', 'humidspare5', 'humidspare6', 'humidspare7', 'humidspare8', 'humidspare9', 'humidspare10');

    # Calcul max lenght of sensor name
    my $max=0;
    for my $sensor (@list_sensors_graph) {
	    if (length($sensor_names{$sensor}) > $max) {
	    	$max=length($sensor_names{$sensor});
	 	}
 	}
    print "Max sensor length name : ",$max,"\n" if $debug;

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

        $tabgtime =  [
  ['6hour',  'Indoor humidity last 6 hours','--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF',"24000"],
  ['12hour',  'Indoor humidity last 12 hours','--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF',"45000"],
  ['1day',  'Indoor humidity last 1 day','--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF',"90000"],
  ['2day',  'Indoor humidity last 2 days','--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF',"180000"],
  ['1week', 'Indoor humidity last 1 week','--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"648000"],
  ['2week', 'Indoor humidity last 2 weeks','--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"1260000"],
  ['1month', 'Indoor humidity last 1 month','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"2700000"],
  ['2month', 'Indoor humidity last 2 months','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"5400000"],
  ['6month', 'Indoor humidity last 6 months','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"16848000"],
  ['1year', 'Indoor humidity last 1 year','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"33696000"],
  ['2year', 'Indoor humidity last 2 years','--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"67392000"],
  ['5year', 'Indoor humidity last 5 years','--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF',"168480000"]
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {

     $secs = $celgtime->[4];
     $time1  = $secs/600*int(($RRD_LAST-$secs)/($secs/600));
     $time2  = $secs/600*int(($RRD_LAST)/($secs/600));

     ($start,$step,$names,$array) = RRDs::fetch "$config_parms{weather_data_rrd}", "AVERAGE", "-s", "$time1", "-e", "$time2" ;
     $err=RRDs::error;
     die "ERROR : function RRDs::fetch : $err\n" if $err;
     $datapoint = $#$array + 1;
     $footer1 = get_weather_footer1($start, $step, $datapoint);

     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_humin_$celgtime->[0].$rrd_format",
"--title", "$celgtime->[1]",
"--height","$height",
"--width", "$width",
"--imgformat", "$config_parms{weather_graph_format}",
"--units-exponent", "0",
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
"--lower-limit","0",
"--upper-limit","100",
"--y-grid", "5:2",
^
. "\"--start\"," . "\"$time1\","
. "\"--end\"," . "\"$time2\","
. ($RRD_LAZY ? "\"--lazy\"," : '')
. "\"--vertical-label\","
. "\"Percent %\","
. qq^"$celgtime->[2]",
"DEF:var=$rrd_dir:inhumid:AVERAGE",
"CDEF:fvar=var",
"$celgtime->[3]",
"DEF:mininhumid=$rrd_dir:inhumid:MIN",
"DEF:maxinhumid=$rrd_dir:inhumid:MAX",

"DEF:humidspare1=$rrd_dir:humidspare1:AVERAGE",
"DEF:minhumidspare1=$rrd_dir:humidspare1:MIN",
"DEF:maxhumidspare1=$rrd_dir:humidspare1:MAX",

"DEF:humidspare2=$rrd_dir:humidspare2:AVERAGE",
"DEF:minhumidspare2=$rrd_dir:humidspare2:MIN",
"DEF:maxhumidspare2=$rrd_dir:humidspare2:MAX",

"DEF:humidspare3=$rrd_dir:humidspare3:AVERAGE",
"DEF:minhumidspare3=$rrd_dir:humidspare3:MIN",
"DEF:maxhumidspare3=$rrd_dir:humidspare3:MAX",

"DEF:humidspare4=$rrd_dir:humidspare4:AVERAGE",
"DEF:minhumidspare4=$rrd_dir:humidspare4:MIN",
"DEF:maxhumidspare4=$rrd_dir:humidspare4:MAX",

"DEF:humidspare5=$rrd_dir:humidspare5:AVERAGE",
"DEF:minhumidspare5=$rrd_dir:humidspare5:MIN",
"DEF:maxhumidspare5=$rrd_dir:humidspare5:MAX",

"DEF:humidspare6=$rrd_dir:humidspare6:AVERAGE",
"DEF:minhumidspare6=$rrd_dir:humidspare6:MIN",
"DEF:maxhumidspare6=$rrd_dir:humidspare6:MAX",

"DEF:humidspare7=$rrd_dir:humidspare7:AVERAGE",
"DEF:minhumidspare7=$rrd_dir:humidspare7:MIN",
"DEF:maxhumidspare7=$rrd_dir:humidspare7:MAX",

"DEF:humidspare8=$rrd_dir:humidspare8:AVERAGE",
"DEF:minhumidspare8=$rrd_dir:humidspare8:MIN",
"DEF:maxhumidspare8=$rrd_dir:humidspare8:MAX",

"DEF:humidspare9=$rrd_dir:humidspare9:AVERAGE",
"DEF:minhumidspare9=$rrd_dir:humidspare9:MIN",
"DEF:maxhumidspare9=$rrd_dir:humidspare9:MAX",

"DEF:humidspare10=$rrd_dir:humidspare10:AVERAGE",
"DEF:minhumidspare10=$rrd_dir:humidspare10:MIN",
"DEF:maxhumidspare10=$rrd_dir:humidspare10:MAX",

"CDEF:wipeout=var,UN,INF,UNKN,IF",
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF",
"AREA:background#$coloraltbg",
^

. ($sensor_names{inhumid} ?
	"\"LINE2:fvar#990000:" . sprintf("%-${max}s",$sensor_names{inhumid}) . "\","
	."\"GPRINT:mininhumid:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxinhumid:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:fvar:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:fvar:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{humidspare1} ?
	"\"LINE2:humidspare1#FF0000:" . sprintf("%-${max}s",$sensor_names{humidspare1}) . "\","
	."\"GPRINT:minhumidspare1:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxhumidspare1:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:humidspare1:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:humidspare1:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{humidspare2} ?
	"\"LINE2:humidspare2#990099:" . sprintf("%-${max}s",$sensor_names{humidspare2}) . "\","
	."\"GPRINT:minhumidspare2:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxhumidspare2:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:humidspare2:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:humidspare2:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{humidspare3} ?
	"\"LINE2:humidspare3#CC0099:" . sprintf("%-${max}s",$sensor_names{humidspare3}) . "\","
	."\"GPRINT:minhumidspare3:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxhumidspare3:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:humidspare3:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:humidspare3:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{humidspare4} ?
	"\"LINE2:humidspare4#CC33CC:" . sprintf("%-${max}s",$sensor_names{humidspare4}) . "\","
	."\"GPRINT:minhumidspare4:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxhumidspare4:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:humidspare4:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:humidspare4:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{humidspare5} ?
	"\"LINE2:humidspare5#FF00FF:" . sprintf("%-${max}s",$sensor_names{humidspare5}) . "\","
	."\"GPRINT:minhumidspare5:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxhumidspare5:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:humidspare5:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:humidspare5:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{humidspare6} ?
	"\"LINE2:humidspare6#FF99CC:" . sprintf("%-${max}s",$sensor_names{humidspare6}) . "\","
	."\"GPRINT:minhumidspare6:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxhumidspare6:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:humidspare6:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:humidspare6:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{humidspare7} ?
	"\"LINE2:humidspare7#99FF00:" . sprintf("%-${max}s",$sensor_names{humidspare7}) . "\","
	."\"GPRINT:minhumidspare7:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxhumidspare7:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:humidspare7:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:humidspare7:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{humidspare8} ?
	"\"LINE2:humidspare8#006600:" . sprintf("%-${max}s",$sensor_names{humidspare8}) . "\","
	."\"GPRINT:minhumidspare8:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxhumidspare8:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:humidspare8:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:humidspare8:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{humidspare9} ?
	"\"LINE2:humidspare9#66FFFF:" . sprintf("%-${max}s",$sensor_names{humidspare9}) . "\","
	."\"GPRINT:minhumidspare9:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxhumidspare9:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:humidspare9:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:humidspare9:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. ($sensor_names{humidspare10} ?
	"\"LINE2:humidspare10#0000CC:" . sprintf("%-${max}s",$sensor_names{humidspare10}) . "\","
	."\"GPRINT:minhumidspare10:MIN:Min \\\\: %5.1lf\","
	."\"GPRINT:maxhumidspare10:MAX:Max \\\\: %5.1lf\","
	."\"GPRINT:humidspare10:AVERAGE:Avg \\\\: %5.1lf\","
	."\"GPRINT:humidspare10:LAST:Last \\\\: %5.1lf\\\\n\","
	:'')
. qq^
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna",
^
. "\"COMMENT:$footer1\\\\c\","
. "\"COMMENT:$footer2\\\\c\""
. ")";

   print "\n$str_graph \n" if $debug;
   eval $str_graph;
   my $err=RRDs::error;
   die "ERROR : function RRDs::graph : $err\n" if $err;
   }
  }
}

#==============================================================================
# Build call function RRD::GRAPH for barometric pressure
#==============================================================================
sub create_rrdgraph_press {
    my $tabgtime;
    my $celgtime;
    my $create_graph;
    my $height = 250;		# graph drawing area --height in pixels
    my $width = 600;		# graph drawing area --width in pixels
    my $coloraltbg = 'EEEEEE';		# alternating (with white) background color
    my $colormoypress = 'ff0000';		# color of primary variable average line (red)
    my $colormoyseapress = 'FFCC00';		# color of primary variable average line (red)
    my $colorna = 'C0C0C0';	# color for unknown area or 0 for gaps (barre noire verticale)
    my $colorpress = '330099';		# color of wind chill
    my $colorwhite = 'FFFFFF';		# color white
    my $colorzero = '000000';	# color of zero line
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;
    my $rrd_format = $config_parms{weather_graph_format} ;
    tr/A-Z/a-z/ for $rrd_format ;


    my $time1;
    my $time2;
    my $err;
    my ($start,$step,$names,$array);
    my $datapoint;
    my $starttime;
    my $secs;
    my $footer1;
    my $footer2;

    $footer2 = get_weather_footer2();

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

        $tabgtime =  [
  ['6hour',  'Barometric pressure last 6 hours','--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF',"24000"],
  ['12hour',  'Barometric pressure last 12 hours','--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF',"45000"],
  ['1day',  'Barometric pressure last 1 day','--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF',"90000"],
  ['2day',  'Barometric pressure last 2 days','--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF',"180000"],
  ['1week', 'Barometric pressure last 1 week','--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"648000"],
  ['2week', 'Barometric pressure last 2 weeks','--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"1260000"],
  ['1month', 'Barometric pressure last 1 month','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"2700000"],
  ['2month', 'Barometric pressure last 2 months','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"5400000"],
  ['6month', 'Barometric pressure last 6 months','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"16848000"],
  ['1year', 'Barometric pressure last 1 year','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"33696000"],
  ['2year', 'Barometric pressure last 2 years','--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"67392000"],
  ['5year', 'Barometric pressure last 5 years','--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF',"168480000"]
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {

     $secs = $celgtime->[4];
     $time1  = $secs/600*int(($RRD_LAST-$secs)/($secs/600));
     $time2  = $secs/600*int(($RRD_LAST)/($secs/600));

     ($start,$step,$names,$array) = RRDs::fetch "$config_parms{weather_data_rrd}", "AVERAGE", "-s", "$time1", "-e", "$time2" ;
     $err=RRDs::error;
     die "ERROR : function RRDs::fetch : $err\n" if $err;
     $datapoint = $#$array + 1;
     $footer1 = get_weather_footer1($start, $step, $datapoint);

     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_press_$celgtime->[0].$rrd_format",
"--title", "$celgtime->[1]",
"--height","$height",
"--width", "$width",
"--imgformat", "$config_parms{weather_graph_format}",
"--units-exponent", "0",
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^
. "\"--start\"," . "\"$time1\","
. "\"--end\"," . "\"$time2\","
. ($RRD_LAZY ? "\"--lazy\"," : '')
. "\"--vertical-label\","
. ($config_parms{weather_uom_baro} eq 'mb' ? "\"Millibars (mb)\"," : "\"inch mercury (inHg)\",")
. qq^"$celgtime->[2]",
"DEF:var=$rrd_dir:press:AVERAGE",
^
.($config_parms{weather_uom_baro} eq 'mb' ? "\"CDEF:fvar=var,0.029529987508,/\"," : "\"CDEF:fvar=var\",")

."\"$celgtime->[3]\","
."\"DEF:minpress=$rrd_dir:press:MIN\","
.($config_parms{weather_uom_baro} eq 'mb' ? "\"CDEF:fminpress=minpress,0.029529987508,/\"," : "\"CDEF:fminpress=minpress\",")
."\"DEF:maxpress=$rrd_dir:press:MAX\","
.($config_parms{weather_uom_baro} eq 'mb' ? "\"CDEF:fmaxpress=maxpress,0.029529987508,/\"," : "\"CDEF:fmaxpress=maxpress\",")
## Calculation for SeaLevel for Millibars and Inches
.($config_parms{weather_uom_baro} eq 'mb' ? "\"CDEF:seafvar=fvar," . $config_parms{altitude} . "," . $config_parms{ratio_sea_baro} . ",3.2808399,*,/,+\"," : "\"CDEF:seafvar=fvar,0.029529987508," . $config_parms{altitude} . "," . $config_parms{ratio_sea_baro} . ",3.2808399,*,/,*,+\",")
. qq^
"CDEF:wipeout=var,UN,INF,UNKN,IF",
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF",
"AREA:background#$coloraltbg",

"LINE2:fvar#$colormoypress:Average absolute barometric pressure\\\\n",
"AREA:fmaxpress#$colorpress:Absolute barometric pressure",
"AREA:fminpress#$colorwhite",
"LINE2:fvar#$colormoypress",
^
## one decimal place for millibars (so it will fit on graph) and 2 for inches
.($config_parms{weather_uom_baro} eq 'mb' ? qq^
"GPRINT:fminpress:MIN:Min \\\\: %2.1lf",
"GPRINT:fmaxpress:MAX:Max \\\\: %2.1lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %2.1lf",
"GPRINT:fvar:LAST:Last \\\\: %2.1lf",
"GPRINT:seafvar:LAST:(sea level \\\\: %2.1lf)\\\\n",
^ : qq^
"GPRINT:fminpress:MIN:Min \\\\: %5.2lf",
"GPRINT:fmaxpress:MAX:Max \\\\: %5.2lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %5.2lf",
"GPRINT:fvar:LAST:Last \\\\: %5.2lf",
"GPRINT:seafvar:LAST:(sea level \\\\: %5.2lf)\\\\n",
^
)

. ($config_parms{weather_uom_baro} eq 'mb' ? "\"HRULE:1013.25#$colorzero\",":"\"HRULE:29.9#$colorzero\",")
. qq^
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna",
^
. "\"COMMENT:$footer1\\\\c\","
. "\"COMMENT:$footer2\\\\c\""
. ")";

   print "\n$str_graph \n" if $debug;
   eval $str_graph;
   my $err=RRDs::error;
   die "ERROR : function RRDs::graph : $err\n" if $err;
   }
  }
}
#==============================================================================
# Build call function RRD::GRAPH for wind speed
#==============================================================================
sub create_rrdgraph_windspeed {
    my $tabgtime;
    my $celgtime;
    my $create_graph;
    my $height = 250;		# graph drawing area --height in pixels
    my $width = 600;		# graph drawing area --width in pixels

    my $coloraltbg = 'EEEEEE';		# alternating (with white) background color
    my $colormoyspeed = 'ff0000';		# color of primary variable average line (red)
    my $colorna = 'C0C0C0';	# color for unknown area or 0 for gaps (barre noire verticale)
    my $colorspeed = '330099';		# color of wind chill
    my $colorwhite = 'FFFFFF';		# color white
    my $colorzero = '000000';	# color of zero line
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;
    my $rrd_format = $config_parms{weather_graph_format} ;
    tr/A-Z/a-z/ for $rrd_format ;

    my $time1;
    my $time2;
    my $err;
    my ($start,$step,$names,$array);
    my $datapoint;
    my $starttime;
    my $secs;
    my $footer1;
    my $footer2;

    $footer2 = get_weather_footer2();

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

        $tabgtime =  [
  ['6hour',  'Wind speed last 6 hours','--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF',"24000"],
  ['12hour',  'Wind speed last 12 hours','--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF',"45000"],
  ['1day',  'Wind speed last 1 day','--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF',"90000"],
  ['2day',  'Wind speed last 2 days','--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF',"180000"],
  ['1week', 'Wind speed last 1 week','--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"648000"],
  ['2week', 'Wind speed last 2 weeks','--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"1260000"],
  ['1month', 'Wind speed last 1 month','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"2700000"],
  ['2month', 'Wind speed last 2 months','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"5400000"],
  ['6month', 'Wind speed last 6 months','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"16848000"],
  ['1year', 'Wind speed last 1 year','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"33696000"],
  ['2year', 'Wind speed last 2 years','--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"67392000"],
  ['5year', 'Wind speed last 5 years','--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF',"168480000"]
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {

     $secs = $celgtime->[4];
     $time1  = $secs/600*int(($RRD_LAST-$secs)/($secs/600));
     $time2  = $secs/600*int(($RRD_LAST)/($secs/600));

     ($start,$step,$names,$array) = RRDs::fetch "$config_parms{weather_data_rrd}", "AVERAGE", "-s", "$time1", "-e", "$time2" ;
     $err=RRDs::error;
     die "ERROR : function RRDs::fetch : $err\n" if $err;
     $datapoint = $#$array + 1;
     $footer1 = get_weather_footer1($start, $step, $datapoint);

     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_windspeed_$celgtime->[0].$rrd_format",
"--title", "$celgtime->[1]",
"--height","$height",
"--width", "$width",
"--imgformat", "$config_parms{weather_graph_format}",
"--units-exponent", "0",
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^
. "\"--start\"," . "\"$time1\","
. "\"--end\"," . "\"$time2\","
. ($RRD_LAZY ? "\"--lazy\"," : '')
. "\"--vertical-label\","
. ($config_parms{weather_uom_wind} eq 'kph' ? "\"Kilometers per hour (kph)\"," : $config_parms{weather_uom_wind} eq 'm/s' ? "Meters per second (m/s)\"," : "\"Miles per hour (mph)\",")
. qq^"$celgtime->[2]",
"DEF:var=$rrd_dir:speed:AVERAGE",
^
.($config_parms{weather_uom_wind} eq 'kph' ? "\"CDEF:fvar=var,1.609344,*\"," : $config_parms{weather_uom_wind} eq 'm/s' ? "\"CDEF:fvar=var,0.23694,/\"," : "\"CDEF:fvar=var\",")

."\"$celgtime->[3]\","
."\"DEF:minspeed=$rrd_dir:speed:MIN\","
.($config_parms{weather_uom_wind} eq 'kph' ? "\"CDEF:fminspeed=minspeed,1.609344,*\"," : $config_parms{weather_uom_wind} eq 'm/s' ? "\"CDEF:fminspeed=minspeed,0.23694,/\"," : "\"CDEF:fminspeed=minspeed\",")
."\"DEF:maxspeed=$rrd_dir:speed:MAX\","
.($config_parms{weather_uom_wind} eq 'kph' ? "\"CDEF:fmaxspeed=maxspeed,1.609344,*\"," : $config_parms{weather_uom_wind} eq 'm/s' ? "\"CDEF:fmaxpeed=maxpeed,0.23694,/\"," : "\"CDEF:fmaxspeed=maxspeed\",")
. qq^
"CDEF:wipeout=var,UN,INF,UNKN,IF",
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF",
"AREA:background#$coloraltbg",

"LINE2:fvar#$colormoyspeed:Average wind speed\\\\n",
"AREA:fmaxspeed#$colorspeed:Wind speed",
"AREA:fminspeed#$colorwhite",
"LINE2:fvar#$colormoyspeed",

"GPRINT:fminspeed:MIN:Min \\\\: %3.1lf",
"GPRINT:fmaxspeed:MAX:Max \\\\: %3.1lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %3.1lf",
"GPRINT:fvar:LAST:Last \\\\: %3.1lf\\\\n",
"HRULE:0#$colorzero",
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna",
^
. "\"COMMENT:$footer1\\\\c\","
. "\"COMMENT:$footer2\\\\c\""
. ")";

   print "\n$str_graph \n" if $debug;
   eval $str_graph;
   my $err=RRDs::error;
   die "ERROR : function RRDs::graph : $err\n" if $err;
   }
  }
}

#==============================================================================
# Build call function RRD::GRAPH for rain total
#==============================================================================
sub create_rrdgraph_raintotal {
    my $tabgtime;
    my $celgtime;
    my $create_graph;
    my $height = 250;		# graph drawing area --height in pixels
    my $width = 600;		# graph drawing area --width in pixels

    my $coloraltbg = 'EEEEEE';		# alternating (with white) background color
    my $colormoyrain = 'ff0000';		# color of primary variable average line (red)
    my $colorna = 'C0C0C0';	# color for unknown area or 0 for gaps (barre noire verticale)
    my $colorrainmax = '000099';
    my $colorrain = '3300FF';
    my $colorwhite = 'FFFFFF';		# color white
    my $colorzero = '000000';	# color of zero line
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;
    my $rrd_format = $config_parms{weather_graph_format} ;
    tr/A-Z/a-z/ for $rrd_format ;

    my $time1;
    my $time2;
    my $err;
    my ($start,$step,$names,$array);
    my $datapoint;
    my $starttime;
    my $secs;
    my $footer1;
    my $footer2;

    $footer2 = get_weather_footer2();

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

        $tabgtime =  [
  ['6hour',  'Rain total last 6 hours','--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF',"24000"],
  ['12hour',  'Rain total last 12 hours','--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF',"45000"],
  ['1day',  'Rain total last 1 day','--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF',"90000"],
  ['2day',  'Rain total last 2 days','--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF',"180000"],
  ['1week', 'Rain total last 1 week','--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"648000"],
  ['2week', 'Rain total last 2 weeks','--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"1260000"],
  ['1month', 'Rain total last 1 month','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"2700000"],
  ['2month', 'Rain total last 2 months','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"5400000"],
  ['6month', 'Rain total last 6 months','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"16848000"],
  ['1year', 'Rain total last 1 year','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"33696000"],
  ['2year', 'Rain total last 2 years','--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"67392000"],
  ['5year', 'Rain total last 5 years','--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF',"168480000"]
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {

     $secs = $celgtime->[4];
     $time1  = $secs/600*int(($RRD_LAST-$secs)/($secs/600));
     $time2  = $secs/600*int(($RRD_LAST)/($secs/600));

     ($start,$step,$names,$array) = RRDs::fetch "$config_parms{weather_data_rrd}", "AVERAGE", "-s", "$time1", "-e", "$time2" ;
     $err=RRDs::error;
     die "ERROR : function RRDs::fetch : $err\n" if $err;
     $datapoint = $#$array + 1;
     $footer1 = get_weather_footer1($start, $step, $datapoint);

     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_raintotal_$celgtime->[0].$rrd_format",
"--title", "$celgtime->[1]",
"--height","$height",
"--width", "$width",
"--imgformat", "$config_parms{weather_graph_format}",
"--units-exponent", "0",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^
#"--alt-autoscale",
. "\"--start\"," . "\"$time1\","
. "\"--end\"," . "\"$time2\","
. ($RRD_LAZY ? "\"--lazy\"," : '')
. "\"--vertical-label\","
. ($config_parms{weather_uom_rain} eq 'mm' ? "\"Millimeters (mm)\"," : "\"Inches (in)\",")
. qq^"$celgtime->[2]",
"DEF:var=$rrd_dir:rain:AVERAGE",
^
."\"--alt-y-grid\","
#."\"--y-grid\","
#. ($config_parms{weather_uom_rain} eq 'mm' ? "\"10:5\"," : "\"0.25:4\",")
.($config_parms{weather_uom_rain} eq 'mm' ? "\"CDEF:fvar=var,0.0393700787402,/\"," : "\"CDEF:fvar=var\",")

."\"$celgtime->[3]\","
."\"DEF:minrain=$rrd_dir:rain:MIN\","
.($config_parms{weather_uom_rain} eq 'mm' ? "\"CDEF:fminrain=minrain,0.0393700787402,/\"," : "\"CDEF:fminrain=minrain\",")
."\"DEF:maxrain=$rrd_dir:rain:MAX\","
.($config_parms{weather_uom_rain} eq 'mm' ? "\"CDEF:fmaxrain=maxrain,0.0393700787402,/\"," : "\"CDEF:fmaxrain=maxrain\",")
. qq^
"CDEF:fsum=PREV,UN,0,PREV,IF,fmaxrain,fminrain,-,+",
"CDEF:wipeout=var,UN,INF,UNKN,IF",
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF",
"AREA:background#$coloraltbg",

"AREA:fmaxrain#$colorrainmax:Total rain",
"AREA:fminrain#$colorrain",
"LINE2:fvar#$colormoyrain:Average total rain",
"GPRINT:fminrain:MIN:Min \\\\: %5.2lf",
"GPRINT:fmaxrain:MAX:Max \\\\: %5.2lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %5.2lf",
"GPRINT:fvar:LAST:Last \\\\: %5.2lf",
"GPRINT:fsum:LAST:Total \\\\: %5.2lf\\\\n",
"HRULE:0#$colorzero",
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna",
^
. "\"COMMENT:$footer1\\\\c\","
. "\"COMMENT:$footer2\\\\c\""
. ")";

   print "\n$str_graph \n" if $debug;
   eval $str_graph;
   my $err=RRDs::error;
   die "ERROR : function RRDs::graph : $err\n" if $err;
   }
  }
}

#==============================================================================
# Build call function RRD::GRAPH for rain rate
#==============================================================================
sub create_rrdgraph_rainrate {
    my $tabgtime;
    my $celgtime;
    my $create_graph;
    my $height = 250;		# graph drawing area --height in pixels
    my $width = 600;		# graph drawing area --width in pixels

    my $coloraltbg = 'EEEEEE';		# alternating (with white) background color
    my $colormoyrain = 'ff0000';		# color of primary variable average line (red)
    my $colorna = 'C0C0C0';	# color for unknown area or 0 for gaps (barre noire verticale)
    my $colorrainmax = '000099';
    my $colorrain = '3300FF';
    my $colorwhite = 'FFFFFF';		# color white
    my $colorzero = '000000';	# color of zero line
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;


    my $time1;
    my $time2;
    my $err;
    my ($start,$step,$names,$array);
    my $datapoint;
    my $starttime;
    my $secs;
    my $footer1;
    my $footer2;

    $footer2 = get_weather_footer2();

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

        $tabgtime =  [
  ['6hour',  'Rain rate last 6 hours','--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF',"24000"],
  ['12hour',  'Rain rate last 12 hours','--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF',"45000"],
  ['1day',  'Rain rate last 1 day','--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF',"90000"],
  ['2day',  'Rain rate last 2 days','--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF',"180000"],
  ['1week', 'Rain rate last 1 week','--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"648000"],
  ['2week', 'Rain rate last 2 weeks','--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF',"1260000"],
  ['1month', 'Rain rate last 1 month','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"2700000"],
  ['2month', 'Rain rate last 2 months','--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"5400000"],
  ['6month', 'Rain rate last 6 months','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"16848000"],
  ['1year', 'Rain rate last 1 year','--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"33696000"],
  ['2year', 'Rain rate last 2 years','--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF',"67392000"],
  ['5year', 'Rain rate last 5 years','--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF',"168480000"]
  ];

#"--y-grid" ,"0.1:1",
# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {

     $secs = $celgtime->[4];
     $time1  = $secs/600*int(($RRD_LAST-$secs)/($secs/600));
     $time2  = $secs/600*int(($RRD_LAST)/($secs/600));
    my $rrd_format = $config_parms{weather_graph_format} ;
    tr/A-Z/a-z/ for $rrd_format ;


     ($start,$step,$names,$array) = RRDs::fetch "$config_parms{weather_data_rrd}", "AVERAGE", "-s", "$time1", "-e", "$time2" ;
     $err=RRDs::error;
     die "ERROR : function RRDs::fetch : $err\n" if $err;
     $datapoint = $#$array + 1;
     $footer1 = get_weather_footer1($start, $step, $datapoint);

     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_rainrate_$celgtime->[0].$rrd_format",
"--title", "$celgtime->[1]",
"--height","$height",
"--width", "$width",
"--imgformat", "$config_parms{weather_graph_format}",
"--units-exponent", "0",
"--alt-autoscale",
"-l", "0",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^
#"--alt-autoscale",
."\"--alt-y-grid\","
#."\"--y-grid\","
#. ($config_parms{weather_uom_rainrate} eq 'mm/hr' ? "\"0.5:1\"," : "\"0.025:4\",")
. "\"--start\"," . "\"$time1\","
. "\"--end\"," . "\"$time2\","
. ($RRD_LAZY ? "\"--lazy\"," : '')
. "\"--vertical-label\","
. ($config_parms{weather_uom_rainrate} eq 'mm/hr' ? "\"Millimeters per hour (mm/hr)\"," : "\"Inches per hour (in/hr)\",")
. qq^"$celgtime->[2]",
"DEF:var=$rrd_dir:rate:AVERAGE",
^
.($config_parms{weather_uom_rainrate} eq 'mm/hr' ? "\"CDEF:fvar=var,0.0393700787402,/\"," : "\"CDEF:fvar=var\",")

."\"$celgtime->[3]\","
."\"DEF:minrate=$rrd_dir:rate:MIN\","
.($config_parms{weather_uom_rainrate} eq 'mm/hr' ? "\"CDEF:fminrate=minrate,0.0393700787402,/\"," : "\"CDEF:fminrate=minrate\",")
."\"DEF:maxrate=$rrd_dir:rate:MAX\","
.($config_parms{weather_uom_rainrate} eq 'mm/hr' ? "\"CDEF:fmaxrate=maxrate,0.0393700787402,/\"," : "\"CDEF:fmaxrate=maxrate\",")
. qq^
"CDEF:wipeout=var,UN,INF,UNKN,IF",
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF",
"AREA:background#$coloraltbg",

"AREA:fmaxrate#$colorrainmax:Rain rate",
"AREA:fminrate#$colorrain",
"LINE2:fvar#$colormoyrain:Average rain rate",
"GPRINT:fminrate:MIN:Min \\\\: %5.2lf",
"GPRINT:fmaxrate:MAX:Max \\\\: %5.2lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %5.2lf",
"GPRINT:fvar:LAST:Last \\\\: %5.2lf\\\\n",
"HRULE:0#$colorzero",
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna",
^
. "\"COMMENT:$footer1\\\\c\","
. "\"COMMENT:$footer2\\\\c\""
. ")";

   print "\n$str_graph \n" if $debug;
   eval $str_graph;
   my $err=RRDs::error;
   die "ERROR : function RRDs::graph : $err\n" if $err;
   }
  }
}

sub analyze_rrd_rain {
	my $RRD = "$config_parms{weather_data_rrd}";

	&print_log('analyze_rrd_rain: updating $Weather{RainLast{x}Hours}');

	my @hours=(1,2,6,12,18,24,48,72,168);
	my $resolution=18*60;  # using 18 minute datapoints - don't change this unless you know what you're doing

	# set default values
	foreach my $hour (@hours) {
		$Weather{"RainLast${hour}Hours"} = 'unknown';
	}

	my $endtime=int(time/$resolution)*$resolution;

	my ($start, $step, $names, $data)=RRDs::fetch(
		$RRD,
		'AVERAGE',
		'-r',$resolution,
		'-e',$endtime,
		'-s','e-168hours'
	);

	my $RRDerror=RRDs::error;

	if ($RRDerror) {
		print_log "weather_rrd_update: having trouble fetching data for rain: $RRDerror";
		return;
	}

	# print "start was ".scalar localtime($start)." and step was $step\n"; # for debugging

	my $rainIndex;
	for ($rainIndex=0; $rainIndex < $#{$names}; $rainIndex++) {
		last if $$names[$rainIndex] eq 'rain';
	}

	if ($rainIndex >= $#{$names}) {
		&print_log ("weather_rrd_update: can't find rain data");
		return;
	}

	# the next bunch of lines gives me a headache ... pointer to an array of pointers?  Who thought that was a good idea?
	my $numSamples=$#{$data};
	#print "numSamples is $numSamples\n"; # for debugging
	my $latestRain=${$$data[$numSamples]}[$rainIndex];
	my $lastRain=0;
	foreach my $hour (@hours) {
		# RRD data is stored in interesting ways every x minutes
		# x was defined to be 18 minutes for data going back a week
		# therefore we need to convert "hours" into y 18 minute intervals
		# This means that we could be off by up to 9 minutes, oh well.
		my $sampleIndex=$numSamples-int(($hour*60)/18+0.5);
		# print "sampleIndex is $sampleIndex at hour $hour\n"; # for debugging

		# stop processing if we didn't get enough data
		last if ($sampleIndex < 0);

		my $rainAtSampleTime=${$$data[$sampleIndex]}[$rainIndex];
		# print "total rain at hour $hour is $rainAtSampleTime\n"; # for debugging
		my $rainAmount=$latestRain-$rainAtSampleTime;

		# if a RainTotal reset to 0 occurs, then rainAmount will be < 0
		next if ($rainAmount < 0); 

		if ($config_parms{weather_uom_rain} eq 'mm') {
			$rainAmount=convert_in2mm($rainAmount);
		}
		$Weather{"RainLast${hour}Hours"}=$rainAmount;
		# print "hour $hour is $rainAmount ".$Weather{"RainLast${hour}Hours"}."\n"; # for debugging
	}

	# check to make sure that the data looks right
	for (my $i=0; $i < ($#hours-1); $i++) {
		my $shorter=Weather{"RainLast".$hours[$i]."Hours"};
		my $longer=Weather{"RainLast".$hours[$i+1]."Hours"};

		# don't check if either value is unknown
		next if $Weather{"RainLast${shorter}Hours"} eq 'unknown';
		next if $Weather{"RainLast${longer}Hours"} eq 'unknown';

		# if the total rain in the last period of time is lower than the
		# next larger period of time, then check the next period
		next if ($Weather{"RainLast${shorter}Hours"} <= $Weather{"RainLast${longer}Hours"});
		# a quirk in the data has caused a smaller period to have a larger
		# value than the next larger period
		# fix it by copying the smaller amount onto the larger amount
		$Weather{"RainLast${shorter}Hours"}=$Weather{"RainLast${longer}Hours"};
	}
	&print_log('analyze_rrd_rain: complete');
}

# Allow for sending graphs via email

$weather_graph_email = new Voice_Cmd 'Email [tempout,tempin,windspeed,winddir,raintotal,rainrate,press,humout,humin] weather chart';

if ($state = said $weather_graph_email) {
    print_log "Sending $state weather charts";
    my $html = &html_file(undef, '../web/bin/weather_graph.pl', $state);
    &net_mail_send(subject => "$state weather charts for $Date_Now",
		   baseref => "$config_parms{http_server}:$config_parms{http_port}/ia5/outside/",
		   to => $config_parms{weather_graph_email},
		   text => $html, mime  => 'html');
#    &net_mail_send(subject => "Weather charts for $Date_Now",
#		   baseref => "$config_parms{http_server}:$config_parms{http_port}/ia5/outside/",
#		   file => "../web/ia5/outside/weather_index.shtml", mime  => 'html');
}
