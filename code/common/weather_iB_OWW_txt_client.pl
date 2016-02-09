# Category = Weather

#@ Reads iButton One Wire Weather Station data broadcast from the OWW program.
#@  This program is freely available from <a href=http://oww.sourceforge.net/>here</a>.
#@  This is a multiplatform networkable weatherstation server/client for use
#@  with the Dallas One wire weather station (all versions).
#@ Default parameters are for the station to be running on the localhost
#@  at port 8891, you can override this with the owwserver_host_txt_port ini
#@  parameter.  This may point to a machine other than the localhost.
#@  The text tcp port from OWW can be configured to display field names
#@  as well as field values. This code can map temperature field names
#@  into Weather field names via an ini parameters temperature_sensor_keys,
#@ humidity_sensor_keys, dewpoint_sensor_keys, so that the code doesn't
#@ have to be modified as you add temperature or humidity sensors.

=begin_comment
"
version 1.0     Jan. 17 2005 Steve Goldman
		Modified version of weather_iB_OWW_client.pl code.
		Instead of taking the fixed form Arne port we take data
		from the txt tcp port which can be in any format that
		we request from OWW. We require a format that is
		self descriptive and extensible as far as temperature and humidity
		sensors are concerned.

"
=cut

#
# Here is the mapping of $Weather keys to sensor names that weather_rrd_update.pl will
# plot. The mapping is $Weather_name => sensor_name
#

#weather_to_sensor_map =
#    TempOutdoor  => temp,
#    HumidOutdoor  => humid,
#    DewOutdoor  => dew,
#    Barom  => press,
#    WindGustDir  => dir,
#    WindAvgDir  => avgdir,
#    WindGustSpeed  => speed,
#    WindAvgSpeed  => avgspeed,
#    WindChill  => chill,
#    RainRate  => rate,
#    RainTotal  => rain,
#    TempIndoor  => intemp,
#    HumidIndoor  => inhumid,
#    DewIndoor  => indew,
#    TempSpare1  => tempspare1,
#    HumidSpare1  => humidspare1,
#    DewSpare1  => dewspare1,
#    TempSpare2  => tempspare2,
#    HumidSpare2  => humidspare2,
#    DewSpare2  => dewspare2,
#    TempSpare3  => tempspare3,
#    HumidSpare3  => humidspare3,
#    DewSpare3  => dewspare3,
#    TempSpare4  => tempspare4,
#    HumidSpare4  => humidspare4,
#    TempSpare5  => tempspare5,
#    HumidSpare5  => humidspare5,
#    TempSpare6  => tempspare6,
#    HumidSpare6  => humidspare6,
#    TempSpare7  => tempspare7,
#    HumidSpare7  => humidspare7,
#    TempSpare8  => tempspare8,
#    HumidSpare8  => humidspare8,
#    TempSpare9  => tempspare9,
#    HumidSpare9  => humidspare9,
#    TempSpare10  => tempspare10,
#    HumidSpare10  => humidspare10

# So we must convert readings from OWW into values into the $Weather hash. I like to use different
# names in OWW than the $Weather names so for the temperature, humidity, dewpoint sensors there
# is another map that converts OWW names to $Weather names. Here's a sample of what I use.
#
# temperature_sensor_keys    = outdoor => TempOutdoor,
#                             hangar => TempIndoor,
#                             basement => TempSpare2,
#			     FloorInput => TempSpare3,
#			     FloorReturn => TempSpare4,
#			     Spa => TempSpare5,
#			     Spa2 => TempSpare6
#
# If you use OWW names that match up to the $Weather names then you don't need to define any values
# for the hashes: temperature_sensor_keys, humidity_sensor_keys, dewpoint_sensor_keys.
# See the parsing code below for more details.

#
# in order to get the initialization of the socket to work correctly
# here we must force misterhouse to keep all of this code out of the loop
# body. Otherwise the new Socket line will be moved out of the loop body
# but the config_parms lines are in the loop body which happens afterwards.
# Without this you must have a definition of the port in an .ini file
# as the default here gets applied too late.
#

# noloop=start
$config_parms{owwserver_host_deadman_minutes} = 2
  unless defined $config_parms{owwserver_host_deadman_minutes};
$config_parms{owwserver_host_txt_port} = "localhost:8891"
  unless defined $config_parms{owwserver_host_txt_port};
$ibwstxt =
  new Socket_Item( undef, undef, $config_parms{owwserver_host_txt_port},
    'ibwstxt', 'tcp', 'raw' );

# noloop=stop

# Initialisation
if ($Reload) {
    $config_parms{temperature_sensor_keys} =
      "outdoor => TempOutdoor, indoor => TempIndoor"
      unless defined $config_parms{temperature_sensor_keys};
}

# Debug mode
my $debug = 1 if $main::Debug{oww_text};
my $ibws_deadman;

my %temp_sensor_keys;

# read keys preserve case
&main::read_parm_hash( \%temp_sensor_keys,
    $main::config_parms{temperature_sensor_keys}, 1 );

my %humidity_sensor_keys;

# read keys preserve case
&main::read_parm_hash( \%humidity_sensor_keys,
    $main::config_parms{humidity_sensor_keys}, 1 );

my %dewpoint_sensor_keys;

# read keys preserve case
&main::read_parm_hash( \%dewpoint_sensor_keys,
    $main::config_parms{dewpoint_sensor_keys}, 1 );

$ibwstxt_v =
  new Voice_Cmd "[Start,Stop,Speak] the ibutton weather station text client";
$ibwstxt_v->set_info('Connects to the ibutton weather station server');

my $freezing = new Weather_Item 'TempOutdoor', '<', 32;
my $direction;

set $ibwstxt_v 'Start' if $Startup;

# no need for this with the deadman timer
# if (time_cron '31 9-23 * * *') {
#	run_voice_cmd 'Start the ibutton weather station text client';
# }

#if (time_cron '0,15,30,45 7-21 * * *') {
#	run_voice_cmd 'Speak the ibutton weather station text client';
#}

if ( my $data = said $ibwstxt) {
    print_log "ibwstxt server said: $data" if $debug;

    # chomp(@data);
    my @data = split /\s+/, $data;    # Split up the individual Data elements
    my $temp_unit;

    # saw some data from the tcp port
    $ibws_deadman = 0;

    # ----------------------------------------------------------------------------
    #                               ------ COLLECT and Parse the Data -------
    for ( my $i = 2; $i < $#data; $i++ ) {

        # Here is an example of the text line I got from OWW tcp port. We are completely insensitive to order of results
        # but the form of a result must follow desciptions in the parsing below.
        #
        # 01/03/06 22:49:11  T[outdoor]    36.9 °F T[hangar]    40.1 °F T[basement]    56.5 °F T[Spa]   103.3 °F T[Spa2]   104.0 °F T[FloorReturn]    61.2 °F T[FloorInput]    61.5 °F WindSpeed    0.00   MPH Direction       East  90.0   4 WindMax    0.00   MPH WindChill    36.9 °F Rain 452.24 inches RainRate  0.00 inches Baro 30.12 Hg TRH[outdoor]    45.8 Humid[outdoor]   76 Dew[outdoor]    38.9
        #
        # Where is a sample of the txtform input to OWW that I'm using
        #
        #
        # txtform $localtime%m/%d/%y %H:%M:%S$  T[outdoor] $t1%7.1$ $tunit$ T[hangar] $t2%7.1$ $tunit$ T[basement] $t3%7.1$ $tunit$ T[Spa] $t4%7.1$ $tunit$ T[Spa2] $t5%7.1$ $tunit$ T[FloorReturn] $t6%7.1$ $tunit$ T[FloorInput] $t7%7.1$ $tunit$ WindSpeed $wsp%7.2$ $wspunit%5$ Direction $wdrname%10$ $wdrdeg%5.1$ $wdrpoint%3$ WindMax $wspmax%7.2$ $wspunit%5$ WindChill $wchill%7.1$ $tunit$ Rain $rain%5.2$ $rainunit$ RainRate $rainrate%5.2$ $rainunit$ Baro $barinhg1%5.2$ Hg TRH[outdoor] $trhf1%7.1$ Humid[outdoor] $rh1%4.0$ Dew[outdoor] $dpf1%7.1$
        #
        # There is one thing that you can do to simplify the configuration of mh. That is to use the $Weather hash names as the sensor names
        # in the txtform line. Then you don't need to use the conversion keys. For example
        # T[TempOutDoor] $t1%7.1 $tunit
        # will need no mapping as if there is no mapping in $temp_sensor_keys we use the value in the brackets directly.
        # Similarly for the Humid and Dew sensors.
        #

        PARSE:
        {
            $_ = $data[$i];
            /^T\[/ && do {

                # T[<where>] <nn> <units>
                s/T\[//;
                s/]//;
                my $key  = $_;
                my $name = $key;
                if ( defined $temp_sensor_keys{$key} ) {
                    $name = $temp_sensor_keys{$key};
                }
                $Weather{$name} = $data[ $i + 1 ];
                $temp_unit = $data[ $i + 2 ];
                print_log
                  "Temperature at $key ( $name ) is $Weather{$name} $temp_unit"
                  if $debug;
                $i += 2;
                last PARSE;
            };
            /^Humid\[/ && do {

                # Humid[<where>] <nn>
                s/Humid\[//;
                s/]//;
                my $key  = $_;
                my $name = $key;
                if ( defined $humidity_sensor_keys{$key} ) {
                    $name = $humidity_sensor_keys{$key};
                }
                $Weather{$name} = $data[ $i + 1 ];
                print_log "Humidity at $key ( $name ) is $Weather{$name}"
                  if $debug;
                $i += 1;
                last PARSE;
            };
            /^Dew\[/ && do {

                # Dew[<where>] <nn>
                s/Dew\[//;
                s/]//;
                my $key  = $_;
                my $name = $key;
                if ( defined $dewpoint_sensor_keys{$key} ) {
                    $name = $dewpoint_sensor_keys{$key};
                }
                $Weather{$name} = $data[ $i + 1 ];
                print_log "Dewpoint at $key ( $name ) is $Weather{$name}"
                  if $debug;
                $i += 1;
                last PARSE;
            };
            /^WindSpeed/ && do {

                # WindSpeed <nn> <units>
                s/\[//;
                s/]//;
                print_log "WindSpeed is $data[$i+1]" if $debug;
                $Weather{WindSpeed}    = $data[ $i + 1 ];
                $Weather{WindAvgSpeed} = $data[ $i + 1 ];
                $i += 2;
                last PARSE;
            };
            /^WindMax/ && do {

                # WindMax <nn> <units>
                s/\[//;
                s/]//;
                print_log "WindMax is $data[$i+1]" if $debug;
                $Weather{WindSpeedHigh} = $data[ $i + 1 ];
                $Weather{WindGustSpeed} = $data[ $i + 1 ];
                $i += 2;
                last PARSE;
            };
            /^WindChill/ && do {

                # WindChill <nn> <units>
                s/\[//;
                s/]//;
                print_log "WindChill is $data[$i+1]" if $debug;
                $Weather{WindChill} = $data[ $i + 1 ];
                $i += 2;
                last PARSE;
            };
            /^Direction/ && do {

                # Direction <Desc> <degrees>> <vane_number>
                s/\[//;
                s/]//;
                print_log
                  "Wind is $data[$i+1] degrees $data[$i+2] vane $data[$i+3]"
                  if $debug;

                # could convert to longer names...
                $Weather{WindDir}    = $data[ $i + 2 ];
                $Weather{AvgWindDir} = $data[ $i + 2 ];

                # we don't really have this, make it up
                $Weather{WindGustDir} = $data[ $i + 2 ];
                $direction = $data[ $i + 1 ];
                $i += 3;
                last PARSE;
            };
            /^Baro/ && do {

                # Baro <nn> <units>
                print_log "Baro $data[$i+1]" if $debug;
                $Weather{Barom} = $data[ $i + 1 ];
                $i += 2;
                last PARSE;
            };
            /^Rain$/ && do {

                # Rain <nn> <units>
                s/\[//;
                s/]//;
                print_log "Rain total $data[$i+1]" if $debug;
                $Weather{RainToday} = $data[ $i + 1 ];
                $Weather{RainTotal} = $data[ $i + 1 ];
                $i += 2;
                last PARSE;
            };
            /^RainRate/ && do {

                # RainRate <nn> <units>
                s/\[//;
                s/]//;
                print_log "RainRate is $data[$i+1]" if $debug;
                $Weather{RainRate} = $data[ $i + 1 ];
                $i += 2;
                last PARSE;
            };
        }
    }

    # this is the standard short summary for the web interfaces
    $Weather{Summary_Short} = "$Weather{TempOutdoor} $temp_unit ";
    $Weather{Wind} =
      " $Weather{WindAvgSpeed}/$Weather{WindSpeedHigh} $direction";

}

if ($New_Minute) {
    if ( $ibws_deadman >= $config_parms{owwserver_host_deadman_minutes} ) {
        $ibws_deadman = 0;
        print_log "ibutton weather station tcp port seems dead, restarting...";
        run_voice_cmd 'Start the ibutton weather station text client';
    }
    else {
        $ibws_deadman++;
    }
}

# ----------------------------------------------------------------------------

&tk_entry(
    "temp",    \$Weather{TempOutdoor}, "Wind ", \$Weather{Wind},
    "Wchill ", \$Weather{WindChill}
);

if ( $state = said $ibwstxt_v) {
    print_log "${state}ing the ibutton weather station client";

    if ( $state eq 'Start' ) {
        unless ( active $ibwstxt) {
            print_log 'Starting a connection to ibwstxt';
            start $ibwstxt;
        }

    }
    elsif ( $state eq 'Stop' and active $ibwstxt) {
        print_log "closing ibwstxt";
        stop $ibwstxt;

    }
    elsif ( $state eq 'Speak' ) {
        my $msg =
          "\nThe Current temperature is $Weather{TempOutdoor}\nA high of $Weather{TempOutdoorHigh}\nA low of $Weather{TempOutdoorLow}.\n";
        $msg .=
          "Current Wind Speed is $Weather{WindAvgSpeed} miles per hour\nGusts of $Weather{WindSpeedPeak}\nHigh of $Weather{WindSpeedHigh}.\nWind Direction is $direction.\n";

        #   $msg .= "The Current Rainfall Rate is $Weather{RainRate} inches per hour.\nToday's total rainfall is $Weather{RainToday} inches\n$Weather{RainWeek} inches for the week\n$Weather{RainMonth} inches for the month.\n";
        if ( state_now $freezing) {
            $msg .= "Temperature is below freezing.";
        }
        print_log $msg;
        speak $msg;
    }
}
