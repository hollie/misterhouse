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
#    html_alias_weather_graph = $config_parms{data_dir}/rrd
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
#--------------------------------------------------------------------
# 				HISTORY
#--------------------------------------------------------------------
#   DATE   REVISION    AUTHOR	        DESCRIPTION
#--------------------------------------------------------------------
# 26/10/03   1.0   Dominique Benoliel	Creation script
#####################################################################
use RRDs;

my $RRDSTEP = 10;		# seconds between recorded data samples
my $RRDHEARTBEAT = 60 * 5;	# seconds before data becomes *unknown*

#==============================================================================
# Principal script
#==============================================================================

# Default mh parameters
if ($Reload) {
    $config_parms{weather_graph_frequency} = 10 unless $config_parms{weather_graph_frequency};
    $config_parms{weather_data_rrd} = "$config_parms{data_dir}/rrd/weather_data.rrd" unless $config_parms{weather_data_rrd};
    $config_parms{weather_graph_dir} = "$config_parms{data_dir}/rrd" unless $config_parms{weather_graph_dir};
    $config_parms{html_alias_weather_graph} = "$config_parms{data_dir}/rrd" unless $config_parms{html_alias_weather_graph};
    $config_parms{weather_graph_footer} = 'Last updated $Time_Date, Dominique Benoliel, www.domotix.net' unless $config_parms{weather_graph_footer};
    mkdir $config_parms{weather_graph_dir} unless -d $config_parms{weather_graph_dir};
   }

# Update RRD database every 1 minute
if ($New_Minute) {
    my $rrd_TempOutdoor = defined $Weather{TempOutdoor} ? $Weather{TempOutdoor} : 'U';
    my $rrd_HumidOutdoor = defined $Weather{HumidOutdoor} ? $Weather{HumidOutdoor} : 'U';
    my $rrd_DewOutdoor = defined $Weather{DewOutdoor} ? $Weather{DewOutdoor} : 'U';
    my $rrd_Barom = defined $Weather{Barom} ? $Weather{Barom} : 'U';
    my $rrd_WindGustDir = defined $Weather{WindGustDir} ? $Weather{WindGustDir} : 'U';
    my $rrd_WindAvgDir = defined $Weather{WindAvgDir} ? $Weather{WindAvgDir} : 'U';
    my $rrd_WindGustSpeed = defined $Weather{WindGustSpeed} ? $Weather{WindGustSpeed} : 'U';
    my $rrd_WindAvgSpeed = defined $Weather{WindAvgSpeed} ? $Weather{WindAvgSpeed} : 'U';
    my $rrd_WindChill = defined $Weather{WindChill} ? $Weather{WindChill} : 'U';
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

    @d = ($rrd_TempOutdoor, $rrd_HumidOutdoor, $rrd_DewOutdoor, $rrd_Barom,
	  $rrd_WindGustDir, $rrd_WindAvgDir, $rrd_WindGustSpeed, $rrd_WindAvgSpeed,
	  $rrd_WindChill, $rrd_RainRate, $rrd_RainTotal, $rrd_TempIndoor,
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
$tell_generate_graph = new Voice_Cmd "Generate weather graphs";
if (new_minute $config_parms{weather_graph_frequency} or said $tell_generate_graph) {
	&create_rrdgraph_all;
  }
#==============================================================================
# Creation bases RRD
#==============================================================================
sub create_rrd {
  my $err;
  my $RRD = "$config_parms{weather_data_rrd}";
  RRDs::create $RRD,
    '-b', $_[0], '-s', $RRDSTEP,
    "DS:temp:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humid:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:dew:GAUGE:$RRDHEARTBEAT:0:150",
    "DS:press:GAUGE:$RRDHEARTBEAT:0:1500",
    "DS:dir:GAUGE:$RRDHEARTBEAT:0:360",
    "DS:avgdir:GAUGE:$RRDHEARTBEAT:0:360",
    "DS:speed:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:avgspeed:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:chill:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:rate:GAUGE:$RRDHEARTBEAT:0:999",
    "DS:rain:GAUGE:$RRDHEARTBEAT:0:9999",
    "DS:intemp:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:inhumid:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:indew:GAUGE:$RRDHEARTBEAT:0:150",
    "DS:tempspare1:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humidspare1:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:dewspare1:GAUGE:$RRDHEARTBEAT:0:150",
    "DS:tempspare2:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humidspare2:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:dewspare2:GAUGE:$RRDHEARTBEAT:0:150",
    "DS:tempspare3:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humidspare3:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:dewspare3:GAUGE:$RRDHEARTBEAT:0:150",

    "DS:tempspare4:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humidspare4:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:tempspare5:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humidspare5:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:tempspare6:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humidspare6:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:tempspare7:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humidspare7:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:tempspare8:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humidspare8:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:tempspare9:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humidspare9:GAUGE:$RRDHEARTBEAT:0:100",
    "DS:tempspare10:GAUGE:$RRDHEARTBEAT:-150:150",
    "DS:humidspare10:GAUGE:$RRDHEARTBEAT:0:100",

    'RRA:AVERAGE:0.5:1:17280',	# all details for 48 hours (2 day)

    'RRA:MIN:0.5:6:2880',	# 1 minute summary for 48 hours (2 day)
    'RRA:AVERAGE:0.5:6:2880',   # 1 minute summary for 48 hours (2 day)
    'RRA:MAX:0.5:6:2880',       # 1 minute summary for 48 hours (2 day)

    'RRA:MIN:0.5:90:1344',	# 1/4 hour summary for 14 day (2 week)
    'RRA:AVERAGE:0.5:90:1344',  # 1/4 hour summary for 14 day (2 week)
    'RRA:MAX:0.5:90:1344',      # 1/4 hour summary for 14 day (2 week)

    'RRA:MIN:0.5:360:1440',	# 1 hour summary for 60 days (2 month)
    'RRA:AVERAGE:0.5:360:1440', # 1 hour summary for 60 days (2 month)
    'RRA:MAX:0.5:360:1440',     # 1 hour summary for 60 days (2 month)

    'RRA:MIN:0.5:8640:1460',	# 1 daily summary for 1460 days (4 years)
    'RRA:AVERAGE:0.5:8640:1460',# 1 daily summary for 1460 days (4 years)
    'RRA:MAX:0.5:8640:1460',	# 1 daily summary for 1460 days (4 years)

    'RRA:MIN:0.5:43200:1460',	 # 5 day summary for 7300 days (20 years)
    'RRA:AVERAGE:0.5:43200:1460',# 5 day summary for 7300 days (20 years)
    'RRA:MAX:0.5:43200:1460',	 # 5 day summary for 7300 days (20 years)

    'RRA:MIN:0.5:60480:1043',	 # 1 weekly summary for 7300 days (20 years)
    'RRA:AVERAGE:0.5:60480:1043',# 1 weekly summary for 7300 days (20 years)
    'RRA:MAX:0.5:60480:1043';	 # 1 weekly summary for 7300 days (20 years)

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
# unknowns only if more than $RRDHEARTBEAT seconds have passed.
#==============================================================================
sub update_rrd {
        my $err;
	my @last;
	my $last; 
	my $i;
	my $RRD = "$config_parms{weather_data_rrd}";
	my ($time, @data) = @_;

	#print "** Parametre **\n";
	#print "ANCIENNES DONNEES : time = $last data = @last\n";
	#print "NOUVELLES DONNEES : time = $time data = @data\n";

	@last = @data unless @last;
	$last = $time unless $last;
	$i = 0;
	# Zero change -> fill in flat lines
#	if (0 >= grep $_ != $last[$i++], @data) { 
	if (0 >= grep $_ ne $last[$i++], @data) { 
		#print "ATTENTION, dans boucle 1...\n";
		#print "Les données ont pas variées\n";
	    for ($i = $last + $RRDSTEP; $i < $time; $i += $RRDSTEP) {
		    #print "ATTENTION, dans boucle 2...\n";
		    #print "...remplir les trous\n";
		    #print "...trou time = $i data = @last\n";

		RRDs::update $RRD, "$i:@last";

		#print "Err : $err\n";
		next if $err = RRDs::error and $err =~ /mininum one second step/;
		warn "$err\n" if $err;
		}
	    } elsif (($i = $time - $last) > $RRDHEARTBEAT) {
		    #print "ATTENTION, DETECTION TROU DE...!\n";
		    #print "... $time - $last = $i\n";
			#$max = $i if $i > $max;
			#$gaps++;# note number of gaps and max size
			}

			#print "DONNEES INSEREES  : time = $time data = @data\n";
      	RRDs::update $RRD, "$time:@data";	# add current data
	#print "\n";

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
	  'Wind Speed', 'Average wind speed', 'Temperature windchill',
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

	&create_rrdgraph_tempout unless ($config_parms{weather_graph_skip} =~ /tempout/);
	&create_rrdgraph_humout unless ($config_parms{weather_graph_skip} =~ /humout/);
	&create_rrdgraph_tempin unless ($config_parms{weather_graph_skip} =~ /tempin/);
	#&create_rrdgraph_humin unless ($config_parms{weather_graph_skip} =~ /humin/);
	&create_rrdgraph_winddir unless ($config_parms{weather_graph_skip} =~ /winddir/);
	&create_rrdgraph_press unless ($config_parms{weather_graph_skip} =~ /press/);
	&create_rrdgraph_windspeed unless ($config_parms{weather_graph_skip} =~ /windspeed/);
	&create_rrdgraph_raintotal unless ($config_parms{weather_graph_skip} =~ /raintotal/);
	&create_rrdgraph_rainrate unless ($config_parms{weather_graph_skip} =~ /rainrate/);
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
    my $colorwchill = '3300FF';	# color of wind chill
    my $colorwhite = 'ffffff';	# color white
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

    $tabgtime =  [
  ['6hour',  'Temperatures last 6 hours','--start","-6h","--step","1","--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF'],
  ['12hour',  'Temperatures last 12 hours','--start","-12h","--step","1","--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF'],
  ['1day',  'Temperatures last 1 day','--start","-1d1h","--step","1","--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF'],
  ['2day',  'Temperatures last 2 days','--start","-2d1h","--step","1","--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF'],
  ['1week', 'Temperatures last 1 week','--start","-1w12h","--step","900","--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
  ['2week', 'Temperatures last 2 weeks','--start","-2w12h","--step","900","--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
  ['1month', 'Temperatures last 1 month','--start","-1mon2d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
  ['2month', 'Temperatures last 2 months','--start","-2mon3d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
  ['6month', 'Temperatures last 6 months','--start","-6mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
  ['1year', 'Temperatures last 1 year','--start","-12mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
  ['2year', 'Temperatures last 2 years','--start","-2y1w","--step","86400","--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
  ['5year', 'Temperatures last 5 years','--start","-5y1w","--step","86400","--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF']
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {
     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_tempout_$celgtime->[0].png",
"--title", "$celgtime->[1]", 
"--end", "-15",
"--height","$height", 
"--width", "$width", 
"--imgformat", "PNG", 
"--units-exponent", "0", 
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^ 
. "\"--vertical-label\","
. ($config_parms{weather_uom_temp} eq 'C' ? "\"Degrees Celcius\"," : "\"Degrees Fahrenheit\",")
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
."\"DEF:chill=$rrd_dir:chill:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fchill=chill,32,-,5,9,/,*\"," : "\"CDEF:fchill=chill\",") 
."\"DEF:minchill=$rrd_dir:chill:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fminchill=minchill,32,-,5,9,/,*\"," : "\"CDEF:fminchill=minchill\",") 
."\"DEF:maxchill=$rrd_dir:chill:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxchill=maxchill,32,-,5,9,/,*\"," : "\"CDEF:fmaxchill=maxchill\",") 
."\"DEF:minintemp=$rrd_dir:intemp:MIN\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fminintemp=minintemp,32,-,5,9,/,*\"," : "\"CDEF:fminintemp=minintemp\",") 
."\"DEF:maxintemp=$rrd_dir:intemp:MAX\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fmaxintemp=maxintemp,32,-,5,9,/,*\"," : "\"CDEF:fmaxintemp=maxintemp\",") 
."\"DEF:intemp=$rrd_dir:intemp:AVERAGE\","
.($config_parms{weather_uom_temp} eq 'C' ? "\"CDEF:fintemp=intemp,32,-,5,9,/,*\"," : "\"CDEF:fintemp=intemp\",") 
. qq^
"CDEF:fdeltachill=fvar,fminchill,-",
"CDEF:wipeout=var,UN,INF,UNKN,IF", 
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF", 
"AREA:background#$coloraltbg",
^
. ($config_parms{weather_uom_temp} eq 'C' ? "\"HRULE:0#$colorzero\",":"\"HRULE:32#$colorzero\",")
. qq^
"AREA:fmaxtemp#$colortemp:Outdoor temperature",
"AREA:fmintemp#$colortemp",
"GPRINT:fmintemp:MIN:Min  \\\\: %4.1lf", 
"GPRINT:fmaxtemp:MAX:Max  \\\\: %4.1lf", 
"GPRINT:fvar:AVERAGE:Avg \\\\: %4.1lf", 
"GPRINT:fvar:LAST:Last    \\\\: %4.1lf\\\\n",

"AREA:fminchill#$colorwhite", 
"STACK:fdeltachill#$colorwchill:Wind Chill         ",
"GPRINT:fminchill:MIN:Min  \\\\: %4.1lf", 
"GPRINT:fmaxchill:MAX:Max  \\\\: %4.1lf", 
"GPRINT:fchill:AVERAGE:Avg \\\\: %4.1lf", 
"GPRINT:fchill:LAST:Last    \\\\: %4.1lf\\\\n",

"LINE2:fdew#$colordew:Dew Point          ", 
"GPRINT:fmindew:MIN:Min  \\\\: %4.1lf", 
"GPRINT:fmaxdew:MAX:Max  \\\\: %4.1lf", 
"GPRINT:fdew:AVERAGE:Avg \\\\: %4.1lf", 
"GPRINT:fdew:LAST:Last    \\\\: %4.1lf\\\\n",

"LINE2:fvar#$colortempavg:Average outdoor temperature",
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna\\\\n",
"COMMENT:\\\\n",
^
. "\"COMMENT:$config_parms{weather_graph_footer}\\\\c\""
. ")";

   #$create_graph = &create_rrdgraph_tempout($celgtime);
   #print "\n$create_graph \n";
   eval $str_graph;
   my $ERR=RRDs::error;
   die "ERROR : function RRDs::graph : $ERR\n" if $ERR;
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

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

    $tabgtime =  [
  ['6hour',  'Temperatures last 6 hours','--start","-6h","--step","1","--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF'],
  ['12hour',  'Temperatures last 12 hours','--start","-12h","--step","1","--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF'],
  ['1day',  'Temperatures last 1 day','--start","-1d1h","--step","1","--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
   'CDEF:background=fvar,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF'],
  ['2day',  'Temperatures last 2 days','--start","-2d1h","--step","1","--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
   'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF'],
  ['1week', 'Temperatures last 1 week','--start","-1w12h","--step","900","--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
  ['2week', 'Temperatures last 2 weeks','--start","-2w12h","--step","900","--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
   'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
  ['1month', 'Temperatures last 1 month','--start","-1mon2d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
  ['2month', 'Temperatures last 2 months','--start","-2mon3d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
  ['6month', 'Temperatures last 6 months','--start","-6mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
  ['1year', 'Temperatures last 1 year','--start","-12mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
  ['2year', 'Temperatures last 2 years','--start","-2y1w","--step","86400","--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
   'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
  ['5year', 'Temperatures last 5 years','--start","-5y1w","--step","86400","--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
   'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF']
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {
     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_tempin_$celgtime->[0].png",
"--title", "$celgtime->[1]", 
"--end", "-15",
"--height","$height", 
"--width", "$width", 
"--imgformat", "PNG", 
"--units-exponent", "0", 
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^ 
. "\"--vertical-label\","
. ($config_parms{weather_uom_temp} eq 'C' ? "\"Degrees Celcius\"," : "\"Degrees Fahrenheit\",")
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

. qq^
#"CDEF:fdeltachill=fvar,fminchill,-",
"CDEF:wipeout=var,UN,INF,UNKN,IF", 
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF", 
"AREA:background#$coloraltbg",
^
. ($config_parms{weather_uom_temp} eq 'C' ? "\"HRULE:0#$colorzero\",":"\"HRULE:32#$colorzero\",")
. qq^
"LINE2:fintemp#$colortempin:Dining room temperature", 
"GPRINT:fminintemp:MIN:Min \\\\: %4.1lf", 
"GPRINT:fmaxintemp:MAX:Max \\\\: %4.1lf", 
"GPRINT:fintemp:AVERAGE:Avg \\\\: %4.1lf", 
"GPRINT:fintemp:LAST:Last \\\\: %4.1lf\\\\n",

"LINE2:ftempspare3#006600:Room temperature       ", 
"GPRINT:fmintempspare3:MIN:Min \\\\: %4.1lf", 
"GPRINT:fmaxtempspare3:MAX:Max \\\\: %4.1lf", 
"GPRINT:ftempspare3:AVERAGE:Avg \\\\: %4.1lf", 
"GPRINT:ftempspare3:LAST:Last \\\\: %4.1lf\\\\n",

"LINE2:ftempspare2#990000:Office temperature     ", 
"GPRINT:fmintempspare2:MIN:Min \\\\: %4.1lf", 
"GPRINT:fmaxtempspare2:MAX:Max \\\\: %4.1lf", 
"GPRINT:ftempspare2:AVERAGE:Avg \\\\: %4.1lf", 
"GPRINT:ftempspare2:LAST:Last \\\\: %4.1lf\\\\n",

"LINE2:ftempspare1#FF0000:Garage temperature     ", 
"GPRINT:fmintempspare1:MIN:Min \\\\: %4.1lf", 
"GPRINT:fmaxtempspare1:MAX:Max \\\\: %4.1lf", 
"GPRINT:ftempspare1:AVERAGE:Avg \\\\: %4.1lf", 
"GPRINT:ftempspare1:LAST:Last \\\\: %4.1lf\\\\n",

"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna\\\\n",
"COMMENT:\\\\n",
^
. "\"COMMENT:$config_parms{weather_graph_footer}\\\\c\""
. ")";

   #print "\n$create_graph \n";
   eval $str_graph;
   my $ERR=RRDs::error;
   die "ERROR : function RRDs::graph : $ERR\n" if $ERR;
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

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

    $tabgtime =  [
	['6hour',  'Wind direction last 6 hours','--start","-6h","--step","1","--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF'],
	['12hour',  'Wind direction last 12 hours','--start","-12h","--step","1","--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF'],
	['1day',  'Wind direction last 1 day','--start","-1d1h","--step","1","--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF'],
	['2day',  'Wind direction last 2 days','--start","-2d1h","--step","1","--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF'],
	['1week', 'Wind direction last 1 week','--start","-1w12h","--step","900","--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['2week', 'Wind direction last 2 weeks','--start","-2w12h","--step","900","--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['1month', 'Wind direction last 1 month','--start","-1mon2d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2month', 'Wind direction last 2 months','--start","-2mon3d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['6month', 'Wind direction last 6 months','--start","-6mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['1year', 'Wind direction last 1 year','--start","-12mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2year', 'Wind direction last 2 years','--start","-2y1w","--step","86400","--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['5year', 'Wind direction last 5 years','--start","-5y1w","--step","86400","--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
	 'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF']
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {
     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_winddir_$celgtime->[0].png",
"--title", "$celgtime->[1]", 
"--end", "-15",
"--height","$height", 
"--width", "$width", 
"--imgformat", "PNG", 
"--units-exponent", "0", 
"--alt-autoscale",
"-l", "0","-u","360",
"--y-grid" ,"30:1",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^ 
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
"GPRINT:fmindir:MIN:Min \\\\: %2.1lf",
"GPRINT:fmaxdir:MAX:Max \\\\: %2.1lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %2.1lf",
"GPRINT:fvar:LAST:Last \\\\: %2.1lf\\\\n",

"AREA:wipeout2#$colorna\\\\n",
"COMMENT:",
"COMMENT:0 (N) 30 (NE) 60 (E) 120 (SE) 150 (S) 210 (SW) 240 (W) 300 (NW) 330 (N) 360\\\\c",
"COMMENT:\\\\n",
^
. "\"COMMENT:$config_parms{weather_graph_footer}\\\\c\""
. ")";

#"COMMENT:0 (N) 30 (NE) 60 (E) 120 (SE) 150 (S) 210 (SO) 240 (O) 300 (NO) 330 (N) 360\\\\c",
   #print "\n$create_graph \n";
   eval $str_graph;
   my $ERR=RRDs::error;
   die "ERROR : function RRDs::graph : $ERR\n" if $ERR;
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

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

    $tabgtime =  [
	['6hour',  'Humidity last 6 hours','--start","-6h","--step","1","--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF'],
	['12hour',  'Humidity last 12 hours','--start","-12h","--step","1","--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF'],
	['1day',  'Humidity last 1 day','--start","-1d1h","--step","1","--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF'],
	['2day',  'Humidity last 2 days','--start","-2d1h","--step","1","--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF'],
	['1week', 'Humidity last 1 week','--start","-1w12h","--step","900","--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['2week', 'Humidity last 2 weeks','--start","-2w12h","--step","900","--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['1month', 'Humidity last 1 month','--start","-1mon2d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2month', 'Humidity last 2 months','--start","-2mon3d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['6month', 'Humidity last 6 months','--start","-6mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['1year', 'Humidity last 1 year','--start","-12mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2year', 'Humidity last 2 years','--start","-2y1w","--step","86400","--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['5year', 'Humidity last 5 years','--start","-5y1w","--step","86400","--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
	 'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF']
    ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {
     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_humout_$celgtime->[0].png",
"--title", "$celgtime->[1]", 
"--end", "-15",
"--height","$height", 
"--width", "$width", 
"--imgformat", "PNG", 
"--units-exponent", "0", 
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^ 
. qq^"--vertical-label", "Percent %", 
"$celgtime->[2]",

"DEF:var=$rrd_dir:humid:AVERAGE", 
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
"AREA:wipeout2#$colorna\\\\n",
^
. "\"COMMENT:$config_parms{weather_graph_footer}\\\\c\""
. ")";

   #print "\n$create_graph \n";
   eval $str_graph;
   my $ERR=RRDs::error;
   die "ERROR : function RRDs::graph : $ERR\n" if $ERR;
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
    my $colorna = 'C0C0C0';	# color for unknown area or 0 for gaps (barre noire verticale)
    my $colorpress = '330099';		# color of wind chill
    my $colorwhite = 'FFFFFF';		# color white
    my $colorzero = '000000';	# color of zero line
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;
    
    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;
    
    $tabgtime =  [
	['6hour',  'Barometric pressure last 6 hours','--start","-6h","--step","1","--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF'],
	['12hour',  'Barometric Pressure last 12 hours','--start","-12h","--step","1","--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF'],
	['1day',  'Barometric pressure last 1 day','--start","-1d1h","--step","1","--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF'],
	['2day',  'Barometric pressure last 2 days','--start","-2d1h","--step","1","--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF'],
	['1week', 'Barometric pressure last 1 week','--start","-1w12h","--step","900","--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['2week', 'Barometric pressure last 2 weeks','--start","-2w12h","--step","900","--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['1month', 'Barometric pressure last 1 month','--start","-1mon2d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2month', 'Barometric pressure last 2 months','--start","-2mon3d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['6month', 'Barometric pressure last 6 months','--start","-6mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['1year', 'Barometric pressure last 1 year','--start","-12mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2year', 'Barometric pressure last 2 years','--start","-2y1w","--step","86400","--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['5year', 'Barometric pressure last 5 years','--start","-5y1w","--step","86400","--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
	 'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF']
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {
     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_press_$celgtime->[0].png",
"--title", "$celgtime->[1]", 
"--end", "-15",
"--height","$height", 
"--width", "$width", 
"--imgformat", "PNG", 
"--units-exponent", "0", 
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^ 
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
. qq^
"CDEF:wipeout=var,UN,INF,UNKN,IF", 
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF", 
"AREA:background#$coloraltbg",

"LINE2:fvar#$colormoypress:Average barometric pressure\\\\n",
"AREA:fmaxpress#$colorpress:Barometric pressure",
"AREA:fminpress#$colorwhite",
"LINE2:fvar#$colormoypress",
"GPRINT:fminpress:MIN:Min \\\\: %2.1lf",
"GPRINT:fmaxpress:MAX:Max \\\\: %2.1lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %2.1lf",
"GPRINT:fvar:LAST:Last \\\\: %2.1lf\\\\n",
^
. ($config_parms{weather_uom_baro} eq 'mb' ? "\"HRULE:1013.2#$colorzero\",":"\"HRULE:29.9#$colorzero\",")
. qq^
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna\\\\n",
"COMMENT:\\\\n",
^
. "\"COMMENT:$config_parms{weather_graph_footer}\\\\c\""
. ")";

   #print "\n$create_graph \n";
   eval $str_graph;
   my $ERR=RRDs::error;
   die "ERROR : function RRDs::graph : $ERR\n" if $ERR;
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

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;
    
    $tabgtime =  [
	['6hour',  'Wind speed last 6 hours','--start","-6h","--step","1","--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF'],
	['12hour',  'Wind speed last 12 hours','--start","-12h","--step","1","--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF'],
	['1day',  'Wind speed last 1 day','--start","-1d1h","--step","1","--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF'],
	['2day',  'Wind speed last 2 days','--start","-2d1h","--step","1","--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF'],
	['1week', 'Wind speed last 1 week','--start","-1w12h","--step","900","--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['2week', 'Wind speed last 2 weeks','--start","-2w12h","--step","900","--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['1month', 'Wind speed last 1 month','--start","-1mon2d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2month', 'Wind speed last 2 months','--start","-2mon3d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['6month', 'Wind speed last 6 months','--start","-6mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['1year', 'Wind speed last 1 year','--start","-12mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2year', 'Wind speed last 2 years','--start","-2y1w","--step","86400","--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['5year', 'Wind speed last 5 years','--start","-5y1w","--step","86400","--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
	 'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF']
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {
     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_windspeed_$celgtime->[0].png",
"--title", "$celgtime->[1]", 
"--end", "-15",
"--height","$height", 
"--width", "$width", 
"--imgformat", "PNG", 
"--units-exponent", "0", 
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^ 
. "\"--vertical-label\","
. ($config_parms{weather_uom_wind} eq 'kph' ? "\"Killometers per hour (kph)\"," : "\"Miles per hour (mph)\",")
. qq^"$celgtime->[2]",
"DEF:var=$rrd_dir:speed:AVERAGE",
^
.($config_parms{weather_uom_wind} eq 'kph' ? "\"CDEF:fvar=var,1.609344,*\"," : "\"CDEF:fvar=var\",") 

."\"$celgtime->[3]\","
."\"DEF:minspeed=$rrd_dir:speed:MIN\","
.($config_parms{weather_uom_wind} eq 'kph' ? "\"CDEF:fminspeed=minspeed,1.609344,*\"," : "\"CDEF:fminspeed=minspeed\",") 
."\"DEF:maxspeed=$rrd_dir:speed:MAX\","
.($config_parms{weather_uom_wind} eq 'kph' ? "\"CDEF:fmaxspeed=maxspeed,1.609344,*\"," : "\"CDEF:fmaxspeed=maxspeed\",") 
. qq^
"CDEF:wipeout=var,UN,INF,UNKN,IF", 
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF", 
"AREA:background#$coloraltbg",

"LINE2:fvar#$colormoyspeed:Average wind speed\\\\n",
"AREA:fmaxspeed#$colorspeed:Wind speed",
"AREA:fminspeed#$colorwhite",
"LINE2:fvar#$colormoyspeed",

"GPRINT:fminspeed:MIN:Min \\\\: %2.1lf",
"GPRINT:fmaxspeed:MAX:Max \\\\: %2.1lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %2.1lf",
"GPRINT:fvar:LAST:Last \\\\: %2.1lf\\\\n",
"HRULE:0#$colorzero",
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna\\\\n",
"COMMENT:\\\\n",
^
. "\"COMMENT:$config_parms{weather_graph_footer}\\\\c\""
. ")";

   #print "\n$create_graph \n";
   eval $str_graph;
   my $ERR=RRDs::error;
   die "ERROR : function RRDs::graph : $ERR\n" if $ERR;
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
    my $colorrain = '0000CC';		# color of wind chill
    my $colorwhite = 'FFFFFF';		# color white
    my $colorzero = '000000';	# color of zero line
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;
    
    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

    $tabgtime =  [
	['6hour',  'Rain total last 6 hours','--start","-6h","--step","1","--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF'],
	['12hour',  'Rain total last 12 hours','--start","-12h","--step","1","--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF'],
	['1day',  'Rain total last 1 day','--start","-1d1h","--step","1","--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF'],
	['2day',  'Rain total last 2 days','--start","-2d1h","--step","1","--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF'],
	['1week', 'Rain total last 1 week','--start","-1w12h","--step","900","--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['2week', 'Rain total last 2 weeks','--start","-2w12h","--step","900","--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['1month', 'Rain total last 1 month','--start","-1mon2d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2month', 'Rain total last 2 months','--start","-2mon3d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['6month', 'Rain total last 6 months','--start","-6mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['1year', 'Rain total last 1 year','--start","-12mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2year', 'Rain total last 2 years','--start","-2y1w","--step","86400","--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['5year', 'Rain total last 5 years','--start","-5y1w","--step","86400","--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
	 'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF']
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {
     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_raintotal_$celgtime->[0].png",
"--title", "$celgtime->[1]", 
"--end", "-15",
"--height","$height", 
"--width", "$width", 
"--imgformat", "PNG", 
"--units-exponent", "0", 
"--alt-autoscale",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^ 
. "\"--vertical-label\","
. ($config_parms{weather_uom_rain} eq 'mm' ? "\"Millimeters (mm)\"," : "\"Inches (in)\",")
. qq^"$celgtime->[2]",
"DEF:var=$rrd_dir:rain:AVERAGE",
^
.($config_parms{weather_uom_rain} eq 'mm' ? "\"CDEF:fvar=var,0.0393700787402,/\"," : "\"CDEF:fvar=var\",") 

."\"$celgtime->[3]\","
."\"DEF:minrain=$rrd_dir:rain:MIN\","
.($config_parms{weather_uom_rain} eq 'mm' ? "\"CDEF:fminrain=minrain,0.0393700787402,/\"," : "\"CDEF:fminrain=minrain\",") 
."\"DEF:maxrain=$rrd_dir:rain:MAX\","
.($config_parms{weather_uom_rain} eq 'mm' ? "\"CDEF:fmaxrain=maxrain,0.0393700787402,/\"," : "\"CDEF:fmaxrain=maxrain\",") 
. qq^
"CDEF:wipeout=var,UN,INF,UNKN,IF", 
"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF", 
"AREA:background#$coloraltbg",

"AREA:fvar#$colorrain",
"LINE1:fvar#$colormoyrain:Average total rain\\\\n",
"GPRINT:fminrain:MIN:Min \\\\: %2.1lf",
"GPRINT:fmaxrain:MAX:Max \\\\: %2.1lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %2.1lf",
"GPRINT:fvar:LAST:Last \\\\: %2.1lf\\\\n",
"HRULE:0#$colorzero",
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna\\\\n",
"COMMENT:\\\\n",
^
. "\"COMMENT:$config_parms{weather_graph_footer}\\\\c\""
. ")";

   #print "\n$create_graph \n";
   eval $str_graph;
   my $ERR=RRDs::error;
   die "ERROR : function RRDs::graph : $ERR\n" if $ERR;
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
    my $colorrain = '0000CC';		# color of wind chill
    my $colorwhite = 'FFFFFF';		# color white
    my $colorzero = '000000';	# color of zero line
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

    $tabgtime =  [
	['6hour',  'Rain rate last 6 hours','--start","-6h","--step","1","--x-grid","MINUTE:10:HOUR:1:MINUTE:30:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,1200,%,600,LE,INF,UNKN,IF'],
	['12hour',  'Rain rate last 12 hours','--start","-12h","--step","1","--x-grid","MINUTE:15:HOUR:1:HOUR:1:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,3600,%,1800,LE,INF,UNKN,IF'],
	['1day',  'Rain rate last 1 day','--start","-1d1h","--step","1","--x-grid","MINUTE:30:HOUR:1:HOUR:2:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,7200,%,3600,LE,INF,UNKN,IF'],
	['2day',  'Rain rate last 2 days','--start","-2d1h","--step","1","--x-grid","HOUR:1:HOUR:4:HOUR:4:0:%H\:%M',
	 'CDEF:background=var,POP,LTIME,21600,%,10800,LE,INF,UNKN,IF'],
	['1week', 'Rain rate last 1 week','--start","-1w12h","--step","900","--x-grid","HOUR:4:DAY:1:DAY:1:86400:%a %d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['2week', 'Rain rate last 2 weeks','--start","-2w12h","--step","900","--x-grid","HOUR:8:DAY:1:DAY:1:86400:%d',
	 'CDEF:background=var,POP,LTIME,172800,%,86400,LE,INF,UNKN,IF'],
	['1month', 'Rain rate last 1 month','--start","-1mon2d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2month', 'Rain rate last 2 months','--start","-2mon3d","--step","3600","--x-grid","DAY:1:WEEK:1:DAY:2:86400:%d',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['6month', 'Rain rate last 6 months','--start","-6mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['1year', 'Rain rate last 1 year','--start","-12mon1w","--step","86400","--x-grid","WEEK:1:MONTH:1:MONTH:1:2592000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['2year', 'Rain rate last 2 years','--start","-2y1w","--step","86400","--x-grid","WEEK:2:MONTH:2:MONTH:2:5184000:%b-%y',
	 'CDEF:background=var,POP,LTIME,1209600,%,604800,LE,INF,UNKN,IF'],
	['5year', 'Rain rate last 5 years','--start","-5y1w","--step","86400","--x-grid","MONTH:1:YEAR:1:YEAR:1:31104000:%Y',
	 'CDEF:background=var,POP,LTIME,4838400,%,2419200,LE,INF,UNKN,IF']
  ];

# generate graphs for various RRA if no skip
for $celgtime (@$tabgtime) {
  unless ($config_parms{weather_graph_period_skip} =~ /$celgtime->[0]/) {
     $str_graph = qq^RRDs::graph("$rrd_graph_dir/weather_rainrate_$celgtime->[0].png",
"--title", "$celgtime->[1]", 
"--end", "-15",
"--height","$height", 
"--width", "$width", 
"--imgformat", "PNG", 
"--units-exponent", "0", 
"--alt-autoscale",
"-l", "0",
"--y-grid" ,"0.1:1",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^ 
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

"AREA:fvar#$colorrain:Taux de précipitation",
"LINE1:fvar#$colormoyrain:Taux de précipitation moyen\\\\n",
"GPRINT:fminrate:MIN:Min \\\\: %2.1lf",
"GPRINT:fmaxrate:MAX:Max \\\\: %2.1lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %2.1lf",
"GPRINT:fvar:LAST:Last \\\\: %2.1lf\\\\n",
"HRULE:0#$colorzero",
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna\\\\n",
"COMMENT:\\\\n",
^
. "\"COMMENT:$config_parms{weather_graph_footer}\\\\c\""
. ")";

   #print "\n$create_graph \n";
   eval $str_graph;
   my $ERR=RRDs::error;
   die "ERROR : function RRDs::graph : $ERR\n" if $ERR;
   }
  }
}
