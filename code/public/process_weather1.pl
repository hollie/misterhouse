# Category = Internet

=begin comment

process_weather.pl
1.0	Created by Dean Junk (deanpjunk@mchsi.com) 3/7/2002

This script reads the weather forecasts downloaded by mh/bin/get_weather and 
and creates a probability if it is going to rain in the next week.  It also 
stores all data in a mysql database for future reporting. It looks for key 
words (i.e. rain, cloudy, sunny, etc...) and assigns a probability for that day.
The percent chance of rain is considered in the formula as well.

It also checks the current temperature to make sure it is OK to water without 
freezing and keeps the average low and high to determine how long to water.  
Next items will be searching the database to see when it rained/water last 
to determine if it needs to be started as well.  As of now, if it is going 
to rain today, the day is marked as a watering day and the system will skip 
watering until the day after.  So, it will never water 2 days in a row.

I have been running this script all summer with no major problems reported.  
Every now and then the web site for the weather forecast will get changed and
you will need to modify this script.  If anything, it is probably more 
conservative than it need to be just because I am cheap:)

The sprinklers can be started multiple ways.  1. This script. i
2. The button on the controller.  3. A remote controller.

=cut

# Setup timers for each zone. (I only have 7 zones)

use DBI;

my $dbh;
my $sth;
my $query;
my $database     = "your_database";
my $dbuser       = "your_user";
my $dbpass       = "your_password";
my $host         = "your_hostname";
my $mail_account = 'your_email_address';

$irr_zone1_timer = new Timer();
$irr_zone2_timer = new Timer();
$irr_zone3_timer = new Timer();
$irr_zone4_timer = new Timer();
$irr_zone5_timer = new Timer();
$irr_zone6_timer = new Timer();
$irr_zone7_timer = new Timer();

my $duration;
my $default_duration = 20;
my $irr_state;

# This is to allow for decreasing zone times for zones that have better coverage than the rest.
# (i.e. if the duration is 20 minutes for all zones and irr_zone5_percent is set at .9, the
# duration will be 18 minutes instead of the default 20.

my $irr_zone1_percent = 1;
my $irr_zone2_percent = 1;
my $irr_zone3_percent = 1;
my $irr_zone4_percent = 1;
my $irr_zone5_percent = 1;
my $irr_zone6_percent = 1;
my $irr_zone7_percent = 1;

my $my_time;
my $weather_results = "$config_parms{data_dir}/weather_results.txt";
my @run_dates;
my @run_prob;
my $wday = ( localtime( time() ) )[6];
my $ManualStart;
my $start_type;
my $ProcessStart;

# Run this everyday at 7:30am to see if we need to water.

if ( time_cron '30 7 * * *' ) {

    my $weather_file = "$config_parms{data_dir}/weather.txt";
    my @days         = (
        'Sunday',   'Monday', 'Tuesday', 'Wednesday',
        'Thursday', 'Friday', 'Saturday'
    );
    my @rain_probability   = ( '1',  '.8',  '.6',  '.4',  '.2',  '0', '0' );
    my @sunny_probability  = ( '-1', '-.8', '-.6', '-.4', '-.2', '0', '0' );
    my @cloudy_probability = ( '.2', '.05', '.05', '.05', '.05', '0', '0' );
    my $high_cnt           = 0;
    my $low_cnt            = 0;
    my $high_avg           = 0;
    my $low_avg            = 0;
    my $num_sunny          = 0;
    my $num_cloudy         = 0;
    my $num_rainy          = 0;
    my $probability        = 0;
    my $percent_chance     = 0;
    my $sunny              = 0;
    my $cloudy             = 0;
    my $rain               = 0;
    my $high               = 0;
    my $low                = 0;
    my $rain_today         = 0;
    my $tempreg0;
    my $tempreg1;
    my $tempreg2;
    my $tempreg3;
    my $tempreg4;
    my $tempreg5;
    my $tempreg6;
    my $tempreg7;
    my $tempreg8;
    my $tempreg9;
    my $tempreg11;
    my $tempreg12;
    my $cur_temp = 0;
    my $i;
    my $index;
    my $tindex1;
    my $tindex2;
    my $tindex3;
    my @forecast;
    my $weather;
    my $dewpoint;
    my $humidity;
    my $avg_prob;

    open( WEATHER, "$weather_file" )     || die "Cannot open $weather_file";
    open( RESULTS, ">$weather_results" ) || die "Cannot open $weather_results";
    $dbh = DBI->connect( "DBI:mysql:database=$database:$host",
        $dbuser, $dbpass, { PrintError => 0 } )
      || die $DBI::errstr;

    undef($/);
    $weather = <WEATHER>;
    close(WEATHER);
    $/ = "\n";

    $ProcessStart = 0;
    $ManualStart  = 0;
    $my_time      = localtime;
    print RESULTS "$my_time - Today is $days[$wday] ...\n";

    if ( $weather =~ /Temperature (\d+\d*) degrees/is ) {
        $cur_temp = $1;
    }

    if ( $weather =~ /Humidity (\d+\d*)%/is ) {
        $humidity = $1;
    }

    if ( $weather =~ /Dew Point (\d+\d*) degrees/is ) {
        $dewpoint = $1;
    }

    if ( $weather =~ /(^.*)(Forecast for Polk.*)$/is ) {
        $weather = $2;
    }

    if ( $weather =~ /(.*)(Forecast Weather Graph.*)$/is ) {
        $weather = $1;
    }

    if ( $wday == 6 ) {
        $index = 0;
    }
    else {
        $index = $wday + 1;
    }

    $query =
      "insert into history_forecast (water_date, forecast) values (now(), \"$weather\")";

    $sth = $dbh->prepare($query) || die $dbh->errstr;
    $sth->execute || die $dbh->errstr;

    $tempreg0 = "^(.*)$days[$index]\[^ \].*";

    if ( $weather =~ /$tempreg0$/is ) {

        #print RESULTS "Tempreg0 = $tempreg0\n";
        #print RESULTS "<1 - $1>\n";
        $forecast[0] = $1;
    }

    for ( $i = 1; $i <= 6; $i++ ) {
        if ( ( $wday + $i ) > 6 ) {
            $index = ( $wday + $i ) - 7;
        }
        else {
            $index = $wday + $i;
        }

        if ( ( $index + 1 ) > 6 ) {
            $tindex1 = ( $index + 1 ) - 7;
            $tindex2 = ( $index + 2 ) - 7;
            $tindex3 = ( $index + 3 ) - 7;
        }
        elsif ( ( $index + 2 ) > 6 ) {
            $tindex1 = $index + 1;
            $tindex2 = ( $index + 2 ) - 7;
            $tindex3 = ( $index + 3 ) - 7;
        }
        elsif ( ( $index + 3 ) > 6 ) {
            $tindex1 = $index + 1;
            $tindex2 = $index + 2;
            $tindex3 = ( $index + 3 ) - 7;
        }
        else {
            $tindex1 = $index + 1;
            $tindex2 = $index + 2;
            $tindex3 = $index + 3;
        }

        $tempreg1  = "\\s*($days[$index]\[^ \].*)$days[$tindex1]\[^ \].*";
        $tempreg11 = "\\s*($days[$index]\[^ \].*)$days[$tindex1].*";
        $tempreg2 =
          "\\s*($days[$index]\[^ \].*)$days[$tindex1] and $days[$tindex2].*";
        $tempreg3 =
          "\\s*($days[$index] and $days[$tindex1].*)$days[$tindex2]\[^ \].*";
        $tempreg4 =
          "\\s*($days[$index] and $days[$tindex1].*)$days[$tindex2] and $days[$tindex3].*";
        $tempreg5  = "\\s*($days[$index] and $days[$tindex1].*)";
        $tempreg12 = "\\s*($days[$index].*)$days[$tindex1].*";
        $tempreg6 =
          "\\s*($days[$index]\[^ \].*)$days[$tindex1] through $days[$tindex3].*";
        $tempreg7 = "\\s*($days[$index] through $days[$tindex2].*)";
        $tempreg8 = "\\s*($days[$index] through $days[$tindex3].*)";
        $tempreg9 = "\\s*($days[$index].*)";

        if ( $weather =~ /$tempreg4$/is ) {
            $forecast[$i] = $1;
            $i++;
            $forecast[$i] = $1;
        }
        elsif ( $weather =~ /$tempreg3$/is ) {
            $forecast[$i] = $1;
            $i++;
            $forecast[$i] = $1;
        }
        elsif ( $weather =~ /$tempreg2$/is ) {
            $forecast[$i] = $1;
        }
        elsif ( $weather =~ /$tempreg1$/is ) {
            $forecast[$i] = $1;
        }
        elsif ( $weather =~ /$tempreg11$/is ) {
            $forecast[$i] = $1;
        }
        elsif ( $weather =~ /$tempreg5$/is ) {
            $forecast[$i] = $1;
            $i++;
            $forecast[$i] = $1;
        }
        elsif ( $weather =~ /$tempreg12$/is ) {
            $forecast[$i] = $1;
        }
        elsif ( $weather =~ /$tempreg6$/is ) {
            $forecast[$i] = $1;
        }
        elsif ( $weather =~ /$tempreg7$/is ) {
            $forecast[$i] = $1;
            $i++;
            $forecast[$i] = $1;
            $i++;
            $forecast[$i] = $1;
        }
        elsif ( $weather =~ /$tempreg8$/is ) {
            $forecast[$i] = $1;
            $i++;
            $forecast[$i] = $1;
            $i++;
            $forecast[$i] = $1;
            $i++;
            $forecast[$i] = $1;
        }
        elsif ( $weather =~ /$tempreg9$/is ) {
            $forecast[$i] = $1;
        }
        else {
            print RESULTS "No Match\n";
            print RESULTS "Tempreg0  = $tempreg0\n";
            print RESULTS "Tempreg1  = $tempreg1\n";
            print RESULTS "Tempreg2  = $tempreg2\n";
            print RESULTS "Tempreg3  = $tempreg3\n";
            print RESULTS "Tempreg4  = $tempreg4\n";
            print RESULTS "Tempreg5  = $tempreg5\n";
            print RESULTS "Tempreg6  = $tempreg6\n";
            print RESULTS "Tempreg7  = $tempreg7\n";
            print RESULTS "Tempreg8  = $tempreg8\n";
            print RESULTS "Tempreg9  = $tempreg9\n";
            print RESULTS "Tempreg11 = $tempreg11\n";
            print RESULTS "Tempreg12 = $tempreg12\n";
        }
    }

    for ( $i = 0; $i <= 6; $i++ ) {

        $percent_chance = 0;
        $sunny          = 0;
        $cloudy         = 0;
        $rain           = 0;
        $high           = 0;
        $low            = 0;

        if ( $forecast[$i] =~
            /.*Chance+\s+of+\s+[rain|showers|thunderstorms]+\s+(\d+\d*).+$/is )
        {
            $percent_chance = $1;
        }

        if ( $percent_chance == 0 ) {
            if ( $forecast[$i] =~ /.*(\d+\d+)\s+percent+\s+chance+.+$/is ) {
                $percent_chance = $1;
            }
        }

        if ( $percent_chance > 50 || $percent_chance == 0 ) {
            $rain = ( $forecast[$i] =~ /rain|thunderstorm|shower/is );
            $rain_today = 1 if ( $i == 1 && $rain );
        }
        elsif ( $percent_chance <= 50 && $percent_chance > 0 ) {
            $cloudy = 1;
        }

        if ( !($rain) && !($cloudy) ) {
            $sunny = ( $forecast[$i] =~ /sunny|warm|hot|clear/is );
        }

        if ( !($sunny) && !($rain) && !($cloudy) ) {
            $cloudy = ( $forecast[$i] =~ /cloudy|cool|overcast|sprinkles/is );
        }

        if ( $forecast[$i] =~
            /.*((High|Highs)+\s+(in\s+the|near|around)+\s+(upper|lower|mid)+\s+(to)+\s*(mid|upper|lower)+\s+)(\d+\d*)s*.*$/is
          )
        {
            $high = $7 + 5;
        }
        elsif ( $forecast[$i] =~
            /.*((High|Highs)+\s+(near|in\s+the|around)+\s+(upper|lower|mid)+\s+)(\d+\d*)s*.*$/is
          )
        {
            $high = $5 + 5;
        }
        elsif ( $forecast[$i] =~
            /.*((High|Highs)+\s+(near|in\s+the|around|from)+\s*(upper|lower|mid)*\s+)(\d+\d*)s*.*$/is
          )
        {
            $high = $5 + 5;
        }
        elsif ( $forecast[$i] =~ /.*High (\d+\d*)s*.*$/is ) {
            $high = $1 + 5;
        }

        if ( $forecast[$i] =~
            /.*((Low|Lows)+\s+(near|in\s+the|around)+\s+(upper|lower|mid)+\s+(to)+\s*(mid|upper|lower)+\s+)(\d+\d*)s*.*$/is
          )
        {
            $low = $7;
        }
        elsif ( $forecast[$i] =~
            /.*((Low|Lows)+\s+(near|in\s+the|around)+\s+(upper|lower|mid)+\s+)(\d+\d*)s*.*$/is
          )
        {
            $low = $5;
        }
        elsif ( $forecast[$i] =~
            /.*((Low|Lows)+\s+(near|in\s+the|around)+\s*(upper|lower|mid)*\s+)(\d+\d*)s*/is
          )
        {
            $low = $5;
        }
        elsif ( $forecast[$i] =~ /.*Low (\d+\d*)s*/is ) {
            $low = $1;
        }

        if ($high) {
            $high_avg += $high;
            $high_cnt++;
        }

        if ($low) {
            $low_avg += $low;
            $low_cnt++;
        }

        $num_rainy++  if ($rain);
        $num_cloudy++ if ($cloudy);
        $num_sunny++  if ($sunny);

        $probability += $rain_probability[$i]   if ($rain);
        $probability += $cloudy_probability[$i] if ($cloudy);
        $probability += $sunny_probability[$i]  if ($sunny);

        print RESULTS
          "<High = $high, Low = $low, Probability = $probability, Percent = $percent_chance\n $forecast[$i]>\n";
    }

    $high_avg /= $high_cnt if ( $high_cnt > 0 );
    $low_avg  /= $low_cnt  if ( $low_cnt > 0 );

    # Basically, the more negative the number is, the less likely it will rain in the next 5 days.
    # The range of the probability is from +3 to -3.

    $duration = 0;
    $my_time  = localtime;
    print RESULTS "\n\n$my_time - Summary information:\n\n";
    print RESULTS "Run Yesterday? = $Save{run_sprinkler_yesterday}\n";

    $run_prob[$wday] = $probability;

    # Looking at average probability for the fun of it for now...

    for ( $i = 0; $i < 7; $i++ ) {
        $avg_prob += $run_prob[$i];
    }

    $avg_prob = $avg_prob / 7;

    # Make sure it is in season to run, the temperature is warm enough, it's not raining today,
    # and it didn't water yesterday.  Then we figure out the master duration.

    if (   ( $Season eq "Spring" || $Season eq "Summer" || $Season eq "Fall" )
        && ( $cur_temp > 40 )
        && ( $Save{run_sprinkler_yesterday} == 0 )
        && ( $high_avg > 0 )
        && ( $low_avg > 0 )
        && !($rain_today) )
    {

        if ( $high_avg < 75 ) {
            $duration = 15 if ( $probability < .4 and $probability > -3 );
        }
        elsif ( $high_avg >= 75 && $high_avg < 85 ) {
            $duration = 15 if ( $probability < .4 and $probability > -1 );
            $duration = 20 if ( $probability < -1 and $probability > -2 );
            $duration = 25 if ( $probability < -2 and $probability > -3 );
        }
        elsif ( $high_avg >= 85 && $high_avg < 95 ) {
            $duration = 15 if ( $probability < .4 and $probability > -1 );
            $duration = 30 if ( $probability < -1 and $probability > -2 );
            $duration = 35 if ( $probability < -2 and $probability > -3 );
        }
        elsif ( $high_avg >= 95 ) {
            $duration = 15 if ( $probability < .4 and $probability > -1 );
            $duration = 30 if ( $probability < -1 and $probability > -2 );
            $duration = 45 if ( $probability < -2 and $probability > -3 );
        }

    }

    $Save{run_sprinkler_yesterday} = 0;

    if ( $duration > 0 || $probability > 1 ) {
        $run_dates[$wday] = 1;
        $Save{run_sprinkler_yesterday} = 1;
    }
    else {
        $run_dates[$wday] = 0;
        $Save{run_sprinkler_yesterday} = 0;
    }

    print RESULTS "Average High   = $high_avg\n";
    print RESULTS "Average Low    = $low_avg\n";
    print RESULTS "Current Temp   = $cur_temp\n";
    print RESULTS "Humidity       = $humidity\n";
    print RESULTS "Dew Point      = $dewpoint\n";
    print RESULTS "Num rainy      = $num_rainy\n";
    print RESULTS "Num cloudy     = $num_cloudy\n";
    print RESULTS "Num Sunny      = $num_sunny\n";
    print RESULTS "Rain Today     = $rain_today\n";
    print RESULTS "Probability    = $probability\n";
    print RESULTS "Avg Prob       = $avg_prob\n";
    print RESULTS "Run Duration   = $duration\n";

    $query =
      "insert into history_master (water_date, duration, high_avg, low_avg, probability, dewpoint, temperature, humidity, num_rainy, num_cloudy, num_sunny, season) values (now(), $duration, $high_avg, $low_avg, $probability, $dewpoint, $cur_temp, $humidity, $num_rainy, $num_cloudy, $num_sunny, \"$Season\")";
    $sth = $dbh->prepare($query) || die $dbh->errstr;
    $sth->execute || die $dbh->errstr;

    if ( $duration > 0 ) {
        $irr_state = "Auto";
        $query =
          "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Front_Garage', $irr_zone1_percent, $duration, \"$irr_state\", 'ON')";
        $sth = $dbh->prepare($query) || die $dbh->errstr;
        $sth->execute || die $dbh->errstr;
        $dbh->disconnect;

        $my_time = localtime;
        print RESULTS "$my_time - Turning on Front Garage Irrigation\n";
        print "$my_time - Turning on Front Garage Irrigation\n";
        $ProcessStart = 1;
        $ManualStart  = 0;
        set $irr_zone1_timer ( ( $duration * 60 ) * $irr_zone1_percent );
        set $irr_zone2_timer (0);
        set $irr_zone3_timer (0);
        set $irr_zone4_timer (0);
        set $irr_zone5_timer (0);
        set $irr_zone6_timer (0);
        set $irr_zone7_timer (0);
        set $Irr_Front_Garage 'ON';
    }
    else {
        $dbh->disconnect;
        close(RESULTS);
        net_mail_send(
            to      => $mail_account,
            file    => $weather_results,
            subject => 'Results from process_weather.pl'
        );
    }

}

if ( ( state_now $Irr_Remote eq OFF ) ) {
    set $irr_zone1_timer (0);
    set $irr_zone2_timer (0);
    set $irr_zone3_timer (0);
    set $irr_zone4_timer (0);
    set $irr_zone5_timer (0);
    set $irr_zone6_timer (0);
    set $irr_zone7_timer (0);
    set $Irr_Front_Garage 'OFF';
    set $Irr_Deck_Steps 'OFF';
    set $Irr_Along_Fence 'OFF';
    set $Irr_Right_Of_Deck 'OFF';
    set $Irr_Back_Right 'OFF';
    set $Irr_Middle_Right_Blvd 'OFF';
    set $Irr_Front_Yard 'OFF';
}

if ( ( state_now $Irr_Manual_Start eq ON ) || ( state_now $Irr_Remote eq ON ) )
{

    $duration  = $default_duration;
    $irr_state = "Manual";
    $dbh       = DBI->connect( "DBI:mysql:database=$database:$host",
        $dbuser, $dbpass, { PrintError => 0 } )
      || die $DBI::errstr;
    $query =
      "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Front_Garage', $irr_zone1_percent, $duration, \"$irr_state\", 'ON')";
    $sth = $dbh->prepare($query) || die $dbh->errstr;
    $sth->execute || die $dbh->errstr;
    $dbh->disconnect;

    open( RESULTS, ">$weather_results" ) || die "Cannot open $weather_results";
    $Save{run_sprinkler_yesterday} = 1;
    $run_dates[$wday]              = 1;
    $my_time                       = localtime;
    $ManualStart                   = 1;
    $ProcessStart                  = 0;
    print "$my_time - Starting sprinklers manually\n";
    print "$my_time - Turning on Front Garage Irrigation\n";
    set $irr_zone1_timer ( ( $duration * 60 ) * $irr_zone1_percent );
    set $irr_zone2_timer (0);
    set $irr_zone3_timer (0);
    set $irr_zone4_timer (0);
    set $irr_zone5_timer (0);
    set $irr_zone6_timer (0);
    set $irr_zone7_timer (0);
    set $Irr_Front_Garage 'ON';
}

if ( expired $irr_zone1_timer) {
    $dbh = DBI->connect( "DBI:mysql:database=$database:$host",
        $dbuser, $dbpass, { PrintError => 0 } )
      || die $DBI::errstr;
    $query =
      "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Front_Garage', $irr_zone1_percent, $duration, \"$irr_state\", 'OFF')";
    $sth = $dbh->prepare($query) || die $dbh->errstr;
    $sth->execute || die $dbh->errstr;

    set $Irr_Front_Garage 'OFF';
    if ( $ProcessStart || $ManualStart ) {
        $query =
          "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Deck_Steps', $irr_zone2_percent, $duration, \"$irr_state\", 'ON')";
        $sth = $dbh->prepare($query) || die $dbh->errstr;
        $sth->execute || die $dbh->errstr;

        $my_time = localtime;
        print "$my_time - Turning on Deck Steps Irrigation\n";
        print RESULTS "$my_time - Turning on Deck Steps Irrigation\n";
        set $irr_zone2_timer ( ( $duration * 60 ) * $irr_zone2_percent );
        set $Irr_Deck_Steps 'ON';
    }
    $dbh->disconnect;
}

if ( expired $irr_zone2_timer) {
    $dbh = DBI->connect( "DBI:mysql:database=$database:$host",
        $dbuser, $dbpass, { PrintError => 0 } )
      || die $DBI::errstr;
    $query =
      "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Deck_Steps', $irr_zone2_percent, $duration, \"$irr_state\", 'OFF')";
    $sth = $dbh->prepare($query) || die $dbh->errstr;
    $sth->execute || die $dbh->errstr;

    set $Irr_Deck_Steps 'OFF';
    if ( $ProcessStart || $ManualStart ) {
        $query =
          "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Along_Fence', $irr_zone3_percent, $duration, \"$irr_state\", 'ON')";
        $sth = $dbh->prepare($query) || die $dbh->errstr;
        $sth->execute || die $dbh->errstr;

        $my_time = localtime;
        print "$my_time - Turning on Fence Irrigation\n";
        print RESULTS "$my_time - Turning on Fence Irrigation\n";
        set $irr_zone3_timer ( ( $duration * 60 ) * $irr_zone3_percent );
        set $Irr_Along_Fence 'ON';
    }
    $dbh->disconnect;
}

if ( expired $irr_zone3_timer) {
    $dbh = DBI->connect( "DBI:mysql:database=$database:$host",
        $dbuser, $dbpass, { PrintError => 0 } )
      || die $DBI::errstr;
    $query =
      "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Along_Fence', $irr_zone3_percent, $duration, \"$irr_state\", 'OFF')";
    $sth = $dbh->prepare($query) || die $dbh->errstr;
    $sth->execute || die $dbh->errstr;

    set $Irr_Along_Fence 'OFF';
    if ( $ProcessStart || $ManualStart ) {
        $query =
          "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Right_Of_Deck', $irr_zone4_percent, $duration, \"$irr_state\", 'ON')";
        $sth = $dbh->prepare($query) || die $dbh->errstr;
        $sth->execute || die $dbh->errstr;
        $my_time = localtime;
        print "$my_time - Turning on Right Of Deck Irrigation\n";
        print RESULTS "$my_time - Turning on Right Of Deck Irrigation\n";
        set $irr_zone4_timer ( ( $duration * 60 ) * $irr_zone4_percent );
        set $Irr_Right_Of_Deck 'ON';
    }
    $dbh->disconnect;
}

if ( expired $irr_zone4_timer) {
    $dbh = DBI->connect( "DBI:mysql:database=$database:$host",
        $dbuser, $dbpass, { PrintError => 0 } )
      || die $DBI::errstr;
    $query =
      "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Right_Of_Deck', $irr_zone4_percent, $duration, \"$irr_state\", 'OFF')";
    $sth = $dbh->prepare($query) || die $dbh->errstr;
    $sth->execute || die $dbh->errstr;

    set $Irr_Right_Of_Deck 'OFF';
    if ( $ProcessStart || $ManualStart ) {
        $query =
          "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Back_Right', $irr_zone5_percent, $duration, \"$irr_state\", 'ON')";
        $sth = $dbh->prepare($query) || die $dbh->errstr;
        $sth->execute || die $dbh->errstr;
        $my_time = localtime;
        print "$my_time - Turning on Back Right Irrigation\n";
        print RESULTS "$my_time - Turning on Back Right Irrigation\n";
        set $irr_zone5_timer ( ( $duration * 60 ) * $irr_zone5_percent );
        set $Irr_Back_Right 'ON';
    }
    $dbh->disconnect;
}

if ( expired $irr_zone5_timer) {
    $dbh = DBI->connect( "DBI:mysql:database=$database:$host",
        $dbuser, $dbpass, { PrintError => 0 } )
      || die $DBI::errstr;
    $query =
      "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Back_Right', $irr_zone5_percent, $duration, \"$irr_state\", 'OFF')";
    $sth = $dbh->prepare($query) || die $dbh->errstr;
    $sth->execute || die $dbh->errstr;

    set $Irr_Back_Right 'OFF';
    if ( $ProcessStart || $ManualStart ) {
        $query =
          "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Middle_Right_Bvld', $irr_zone6_percent, $duration, \"$irr_state\", 'ON')";
        $sth = $dbh->prepare($query) || die $dbh->errstr;
        $sth->execute || die $dbh->errstr;
        $my_time = localtime;
        print "$my_time - Turning on Middle Right & Blvd Irrigation\n";
        print RESULTS "$my_time - Turning on Middle Right & Blvd Irrigation\n";
        set $irr_zone6_timer ( ( $duration * 60 ) * $irr_zone6_percent );
        set $Irr_Middle_Right_Blvd 'ON';
    }
    $dbh->disconnect;
}

if ( expired $irr_zone6_timer) {
    $dbh = DBI->connect( "DBI:mysql:database=$database:$host",
        $dbuser, $dbpass, { PrintError => 0 } )
      || die $DBI::errstr;
    $query =
      "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Middle_Right_Bvld', $irr_zone6_percent, $duration, \"$irr_state\", 'OFF')";
    $sth = $dbh->prepare($query) || die $dbh->errstr;
    $sth->execute || die $dbh->errstr;

    set $Irr_Middle_Right_Blvd 'OFF';
    if ( $ProcessStart || $ManualStart ) {
        $query =
          "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Front_Yard', $irr_zone7_percent, $duration, \"$irr_state\", 'ON')";
        $sth = $dbh->prepare($query) || die $dbh->errstr;
        $sth->execute || die $dbh->errstr;
        $my_time = localtime;
        print "$my_time - Turning on Front Yard Irrigation\n";
        print RESULTS "$my_time - Turning on Front Yard Irrigation\n";
        set $irr_zone7_timer ( ( $duration * 60 ) * $irr_zone7_percent );
        set $Irr_Front_Yard 'ON';
    }
    $dbh->disconnect;
}

if ( expired $irr_zone7_timer) {
    $dbh = DBI->connect( "DBI:mysql:database=$database:$host",
        $dbuser, $dbpass, { PrintError => 0 } )
      || die $DBI::errstr;
    $query =
      "insert into history_detail (water_date, zone, zone_percent, duration, start_type, irr_state) values (now(), 'Irr_Front_Yard', $irr_zone7_percent, $duration, \"$irr_state\", 'OFF')";
    $sth = $dbh->prepare($query) || die $dbh->errstr;
    $sth->execute || die $dbh->errstr;
    $dbh->disconnect;

    set $Irr_Front_Yard 'OFF';
    $my_time = localtime;
    print "$my_time - Turning off Front Yard Irrigation\n";
    print RESULTS "$my_time - Turning off Front Yard Irrigation\n";
    $duration     = 0;
    $ManualStart  = 0;
    $ProcessStart = 0;
    close(RESULTS);
    net_mail_send(
        to      => $mail_account,
        file    => $weather_results,
        subject => 'Results from process_weather.pl'
    );
}

