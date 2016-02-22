# Category=weather
#####################################################################
# NOM		: csv2rrd_weather.pl
# DESCRIPTION 	: convert CSV files to new RRD database
#                 (Misterhouse 2.87)
# AUTHOR        : Dominique Benoliel (www.domotix.net)
# REMARKS       :
# Use this script only if mh parameter weather_data_csv is enable,
# for example :
#    weather_data_csv = F:/Misterhouse286/data/rrd/wmr928_hist.csv
#    Archive weather data in flat file (type csv), blank to disable
#    This File is suffixed by $Year_Month_Now
# Input :
#    source CSV files
#    important : before launch, update variables :
#         $RRD = ... (target RRD database)
#         $RRD_CSV_DIR = ... (CSV files directory)
#         $RRD_CSV_FILE = ... (CSV files without suffix $Year_Month_Now)
# Output :
#    target RRD database
#    target CSV files if $RRD2CSV is true
#--------------------------------------------------------------------
# 				HISTORY
#--------------------------------------------------------------------
#   DATE   REVISION    AUTHOR	        DESCRIPTION
#--------------------------------------------------------------------
# 14/03/04   1.0   Dominique Benoliel	Creation
# 18/05/04   1.1   Dominique Benoliel
# - Change min/max value for RRD DS press (Thanks to Clive Freedman)
# - local variable row_header not declared
#####################################################################
use Time::Local;
use RRDs;
use Text::ParseWords;
use File::Copy;

#==============================================================================
# Principal script
#==============================================================================
# Initialisation des variables
my $err;
my @d;
my @d_rrd;
my $d_log;
my @last;
my $last;
my $i;
my $row;
my $datedeb;
my $time;
my ( $jour, $mois, $annee, $heure, $minute, $seconde );
my %files;
my $jour_old = '';
my $jour_new;

my $STEP      = 60;     # seconds between recorded data samples
my $HEARTBEAT = 300;    # seconds before data becomes *unknown*

# Create target CSV file
my $RRD2CSV = 0;

#-----------------------------------------------------
# BEGIN SECTION
# MODIFY VARIABLES BEFORE LUNCH THE PROGRAM
#-----------------------------------------------------
# target RRD database
my $RRD = 'C:\DB-programmes\Misterhouse-db/wmr928.rrd';

# source CSV file directory
my $RRD_CSV_DIR = 'C:/DB-programmes/Misterhouse-db';

# source CSV file without suffix $Year_Month_Now
my $RRD_CSV_FILE = 'wmr928_hist.csv';

#-----------------------------------------------------
# END SECTION
#-----------------------------------------------------

# Rename RRD if exist
move "$RRD", "$RRD\.old" if -e "$RRD";

# create list CSV files
my @listcsv = &read_table_files($RRD_CSV_DIR);
print "\nCSV files list : @listcsv\n\n";

# Convert each CSV file
for my $filecsv (@listcsv) {
    convert_csv( $files{$filecsv} );
}

# END principal script

#==============================================================================
# Convert data for a CSV file
#==============================================================================
sub convert_csv {
    my ($filecsv) = @_;
    my $filecsv2 = $filecsv . '.new';

    # Rename target CSV file if exist
    move "$filecsv2", "$filecsv2\.old" if -e "$filecsv2";

    print "---------------------------\n";
    print "Convert CSV file : $filecsv\n";
    open( LOG1, $filecsv ) or print "Warning, could not open file\n";
    my @data = <LOG1>;

    # Ignorer le Header
    $row = shift @data;

    # Recuperer la date de debut apres le Header (premier enregistrement de donnees)
    # DATE DE DEBUT : 1067810161
    $row  = shift @data;
    @d    = quotewords( ";", 0, $row );
    $time = $d[0];
    print "Begin date   : $time\n";

    # Create RRD database
    &create_rrd($time) unless -e $RRD;

    while (@data) {
        $time     = $d[0];
        $annee    = $d[1];
        $mois     = $d[2];
        $jour     = $d[3];
        $jour_new = $d[3];
        $heure    = $d[4];
        $minute   = $d[5];
        $seconde  = $d[6];
        if ( $jour_old != $jour_new ) {
            $jour_old = $jour_new;
            print "$jour/$mois/$annee\n";
        }

        # here, make some conversions if necessary
        # default : no conversion
        if (0) {
            $d[7]  = $d[7];     # Température exterieure
            $d[9]  = $d[9];     # Temperature point de rosee exterieur
            $d[10] = $d[10];    # Pression
            $d[13] = $d[13];    # Vitesse actuelle du vent
            $d[14] = $d[14];    # Vitesse moyenne du vent
            $d[15] = $d[15];    # Temperature de rafale de vent
            $d[16] = $d[16];    # Taux de precipitation
            $d[17] = $d[17];    # Total precipitation
            $d[18] = $d[18];    # Température du salon
            $d[20] = $d[20];    # Point de rosée interieure
            $d[21] = $d[21];    # Température module 1
            $d[23] = $d[23];    # Point de rosée module 1
            $d[24] = $d[24];    # Température module 2
            $d[26] = $d[26];    # Point de rosée module 2
            $d[27] = $d[27];    # Température module 3
            $d[29] = $d[29];    # Point de rosée module 3
        }

        @d_rrd = (
            $d[7],              # Température exterieure
            $d[8],              # Humidite esterieure
            $d[9],              # Temperature point de rosee exterieur
            $d[10],             # Pression
            $d[11],             # Direction du vent instantanee
            $d[12],             # Direction moyenne du vent
            $d[13],             # Vitesse actuelle du vent
            $d[14],             # Vitesse moyenne du vent
            $d[15],             # Temperature de rafale de vent
            $d[16],             # Taux de precipitation
            $d[17],             # Total precipitation
            $d[18],             # Température du salon
            $d[19],             # Humidite interieure
            $d[20],             # Point de rosée interieure
            $d[21],             # Température module 1
            $d[22],             # Humidité module 1
            $d[23],             # Point de rosée module 1
            $d[24],             # Température module 2
            $d[25],             # Humidité module 2
            $d[26],             # Point de rosée module 2
            $d[27],             # Température module 3
            $d[28],             # Humidité module 3
            $d[29],             # Point de rosée module 3
            $d[30], $d[31], $d[32], $d[33], $d[34], $d[35], $d[36],
            $d[37], $d[38], $d[39], $d[40], $d[41], $d[42], $d[43]
        );

        # Historiser les données dans la base RRD
        $" = ':';
        &update( $time, @d_rrd );
        $" = ' ';

        # Formater les donnees pour stockage dans un fichier plat CSV
        $d_log = join(
            ";",
            $time, $annee, $mois, $jour, $heure, $minute, $seconde,
            $d[7],     # Température exterieure
            $d[8],     # Humidite esterieure
            $d[9],     # Temperature point de rosee exterieur
            $d[10],    # Pression
            $d[11],    # Direction du vent instantanee
            $d[12],    # Direction moyenne du vent
            $d[13],    # Vitesse actuelle du vent
            $d[14],    # Vitesse moyenne du vent
            $d[15],    # Temperature de rafale de vent
            $d[16],    # Taux de precipitation
            $d[17],    # Total precipitation
            $d[18],    # Température du salon
            $d[19],    # Humidite interieure
            $d[20],    # Point de rosée interieure
            $d[21],    # Température module 1
            $d[22],    # Humidité module 1
            $d[23],    # Point de rosée module 1
            $d[24],    # Température module 2
            $d[25],    # Humidité module 2
            $d[26],    # Point de rosée module 2
            $d[27],    # Température module 3
            $d[28],    # Humidité module 3
            $d[29],    # Point de rosée module 3
            $d[30] == '' ? 'U' : $d[30],
            $d[31] == '' ? 'U' : $d[31],
            $d[32] == '' ? 'U' : $d[32],
            $d[33] == '' ? 'U' : $d[33],
            $d[34] == '' ? 'U' : $d[34],
            $d[35] == '' ? 'U' : $d[35],
            $d[36] == '' ? 'U' : $d[36],
            $d[37] == '' ? 'U' : $d[37],
            $d[38] == '' ? 'U' : $d[38],
            $d[39] == '' ? 'U' : $d[39],
            $d[40] == '' ? 'U' : $d[40],
            $d[41] == '' ? 'U' : $d[41],
            $d[42] == '' ? 'U' : $d[42],
            $d[43] == '' ? 'U' : $d[43],
            "\n"
        ) if $RRD2CSV;

        # Historiser les données dans un fichier plat
        unless ( -e $filecsv2 or !$RRD2CSV ) {
            my $row_header = join( ";",
                'Epoch',
                'Annee',
                'Mois',
                'Jour',
                'Heure',
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
                'Temperature windchill',
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
                'Humidity module 10' )
              . "\n";

            &logit( $filecsv2, $row_header, 0 );
        }

        &logit( $filecsv2, $d_log, 0 ) if $RRD2CSV;

        $row = shift @data;
        @d = quotewords( ";", 0, $row );
    }
}

#==============================================================================
# Find full paths to all files in requested dirs
#==============================================================================
sub file_read_dir {
    my @dirs = @_;
    for my $dir (@dirs) {
        opendir( DIR, $dir )
          or print
          "\nError in file_dir_read, can not open directory:  $dir. $!\n";
        my @files = readdir(DIR);
        close DIR;

        # Create a hash that shows the full file pathname.  First one wins
        for my $member (@files) {
            $files{$member} = "$dir/$member" unless $files{$member};
        }
    }
    return %files;
}

#==============================================================================
# read files in the directory
#==============================================================================
sub read_table_files {
    my @Code_Dirs  = @_;
    my %file_paths = &file_read_dir(@Code_Dirs);
    my @files_read = sort keys %file_paths;
    @files_read = grep( /^$RRD_CSV_FILE.*$/i, @files_read );
    return @files_read;
}

#==============================================================================
# Add row into CSV file
#==============================================================================
sub logit {
    my ( $log_file, $log_data, $log_format, $head_tail ) = @_;
    $log_format = 14 unless defined $log_format;
    unless ( $log_format == 0 ) {
        $log_data =~ s/[\n\r]+/ /g;    # So log only takes one line.
        my $time_date = &main::time_date_stamp($log_format);
        $log_data = "$time_date $log_data\n";
    }
    if ( $head_tail and -e $log_file ) {
        open( LOG, $log_file )
          or print "Warning, could not open log file $log_file: $!\n";
        my @data = <LOG>;
        unshift @data, $log_data;
        open( LOG, ">$log_file" )
          or print "Warning, could not open log file $log_file: $!\n";
        print LOG @data;
    }
    else {
        open( LOG, ">>$log_file" )
          or print "Warning, could not open log file $log_file: $!\n";
        print LOG $log_data;
    }
    close LOG;
}

#==============================================================================
# Creation des bases RRD : new format
#==============================================================================
sub create_rrd {
    print "Create RRD database : $RRD\n";
    RRDs::create $RRD,
      '-b', $_[0], '-s', $STEP,
      "DS:temp:GAUGE:$HEARTBEAT:-150:150",
      "DS:humid:GAUGE:$HEARTBEAT:0:100",
      "DS:dew:GAUGE:$HEARTBEAT:0:150",
      "DS:press:GAUGE:$HEARTBEAT:23:33",
      "DS:dir:GAUGE:$HEARTBEAT:0:360",
      "DS:avgdir:GAUGE:$HEARTBEAT:0:360",
      "DS:speed:GAUGE:$HEARTBEAT:0:100",
      "DS:avgspeed:GAUGE:$HEARTBEAT:0:100",
      "DS:chill:GAUGE:$HEARTBEAT:-150:150",
      "DS:rate:GAUGE:$HEARTBEAT:0:999",
      "DS:rain:GAUGE:$HEARTBEAT:0:9999",
      "DS:intemp:GAUGE:$HEARTBEAT:-150:150",
      "DS:inhumid:GAUGE:$HEARTBEAT:0:100",
      "DS:indew:GAUGE:$HEARTBEAT:0:150",
      "DS:tempspare1:GAUGE:$HEARTBEAT:-150:150",
      "DS:humidspare1:GAUGE:$HEARTBEAT:0:100",
      "DS:dewspare1:GAUGE:$HEARTBEAT:0:150",
      "DS:tempspare2:GAUGE:$HEARTBEAT:-150:150",
      "DS:humidspare2:GAUGE:$HEARTBEAT:0:100",
      "DS:dewspare2:GAUGE:$HEARTBEAT:0:150",
      "DS:tempspare3:GAUGE:$HEARTBEAT:-150:150",
      "DS:humidspare3:GAUGE:$HEARTBEAT:0:100",
      "DS:dewspare3:GAUGE:$HEARTBEAT:0:150",

      "DS:tempspare4:GAUGE:$HEARTBEAT:-150:150",
      "DS:humidspare4:GAUGE:$HEARTBEAT:0:100",
      "DS:tempspare5:GAUGE:$HEARTBEAT:-150:150",
      "DS:humidspare5:GAUGE:$HEARTBEAT:0:100",
      "DS:tempspare6:GAUGE:$HEARTBEAT:-150:150",
      "DS:humidspare6:GAUGE:$HEARTBEAT:0:100",
      "DS:tempspare7:GAUGE:$HEARTBEAT:-150:150",
      "DS:humidspare7:GAUGE:$HEARTBEAT:0:100",
      "DS:tempspare8:GAUGE:$HEARTBEAT:-150:150",
      "DS:humidspare8:GAUGE:$HEARTBEAT:0:100",
      "DS:tempspare9:GAUGE:$HEARTBEAT:-150:150",
      "DS:humidspare9:GAUGE:$HEARTBEAT:0:100",
      "DS:tempspare10:GAUGE:$HEARTBEAT:-150:150",
      "DS:humidspare10:GAUGE:$HEARTBEAT:0:100",

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

    die "unable to create $RRD: $err\n" if $err = RRDs::error;
}

#==============================================================================
# Mise a jour de la base RRD
# update $RRD with given time and data
#
# To save space wx200d logs only when a variable changes.  So if only
# one variable has changed since the last update, we can assume the
# station was up and fill in the missing data so we don't get false
# unknowns.  If several things changed, we don't fill in and will get
# unknowns only if more than $HEARTBEAT seconds have passed.
#==============================================================================
sub update {
    my ( $time, @data ) = @_;

    @last = @data unless @last;
    $last = $time unless $last;
    $i    = 0;

    # Zero change -> fill in flat lines
    if ( 0 >= grep $_ != $last[ $i++ ], @data ) {
        for ( $i = $last + $STEP; $i < $time; $i += $STEP ) {
            RRDs::update $RRD, "$i:@last";
            next if $err = RRDs::error and $err =~ /mininum one second step/;
            warn "$err\n" if $err;
        }
    }
    elsif ( ( $i = $time - $last ) > $HEARTBEAT ) {

        #print "ATTENTION, DETECTION TROU DE...!\n";
        #print "... $time - $last = $i\n";
        #$max = $i if $i > $max;
        #$gaps++;# note number of gaps and max size
    }

    RRDs::update $RRD, "$time:@data";    # add current data

    $last = $time;
    @last = @data;
    return if $err = RRDs::error and $err =~ /min.*one second step/;
    warn "$err\n" if $err;
}

#==============================================================================
# Functions for data conversions
#==============================================================================
sub convert_c2f {    # Convert degrees Celsius to Farenheight
    sprintf( "%3.1f", 32 + ( 9 / 5 ) * ( $_[0] ) );
}

sub convert_f2c {    # Convert degrees fahrenheit to celsius
    sprintf( "%3.2f", ( 5 / 9 ) * ( $_[0] - 32 ) );
}

sub convert_mb2in {    # Pression
    sprintf( "%4.2f", $_[0] * 0.029529987508 );
}

sub convert_in2mb {    # Pression
    sprintf( "%4.2f", $_[0] / 0.029529987508 );
}

sub convert_ms2mih {    # Vitesse vent
    sprintf( "%4.2f", $_[0] * 2.23693632 );
}

sub convert_mih2ms {    # Vitesse vent
    sprintf( "%4.2f", $_[0] / 2.23693632 );
}

sub convert_mih2kmh {
    sprintf( "%4.2f", $_[0] * 1.609344 );
}

sub convert_mm2in {     # precipitation
    sprintf( "%4.2f", $_[0] * 0.0393700787402 );
}

sub convert_in2mm {     # precipitation
    sprintf( "%4.2f", $_[0] / 0.0393700787402 );
}
