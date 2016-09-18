####################################################
#
# weather_sbweather.pl
#
# Author: Bruce Winter
#
# This file shows how to read the weather logs created by the sbWeather program
#
# Note: I used to use this before I wrote some perl code to parse the RadioShack Wx200
#       data stream directly (see mh/code/bruce/weather_wx200.pl)
#       SbWeather (http://smbaker.simplenet.com/sbweather) has a
#       nice gui, but is uses up 10% of the user/GDI Windows98 resources.
#
####################################################

# Don't do it on the minute ... that is when sbweather updates!
if ( ( $New_Second and $Second == 30 ) ) {

    # Take the 2nd to last record from todays file
    my @temp = get_weather_record(time);

    my @keys =
      qw(TimeStamp TempIndoor TempIndoorH TempIndoorL TempOutdoor TempOutdoorH TempOutdoorL
      HumidIndoor HumidIndoorH HumidIndoorL HumidOutdoor HumidOutdoorH HumidOutdoorL
      WindGustSpeed WindGustDir WindAvgSpeed WindAvgDir WindHighSpeed WindHighDir
      Barom BaromSea RainTotal RainRate RainYest
      DewIndoor DewIndoorH DewIndoorL DewOutdoor DewOutdoorH DewOutdoorL WindChill WindChillL);

    #   print "db $Weather{TimeStamp} temp=$Weather{TempOutdoor} gust=$Weather{WindGustSpeed}\n";
    #   print "db $Weather{TimeStamp} wind1=$Weather{WindGustSpeed} dir=$Weather{WindGustDir}\n";
    #   print "db $Weather{TimeStamp} wind2=$Weather{WindAvgSpeed} dir=$Weather{WindAvgDir}\n";
    my $i = 0;

    # If we got valid data
    my $raintotal_prev = $Weather{RainTotal};
    if ( @temp < 2 ) {
        %Weather = map { @keys[ $i++ ], 'unknown' } @keys;
    }
    else {
        %Weather = map { @keys[ $i++ ], $_ } @temp;

        $Weather{HumidOutdoor} = 100 if $Weather{HumidOutdoor} > 100;

        # Note interesting weather events
        $timer_wind_gust = new Timer();
        if ( $Weather{WindGustSpeed} > 12
            and not $Save{sleeping_parents} )
        {
            if ( $Weather{WindGustSpeed} > $Save{WindGustMax} ) {
                $Save{WindGustMax} = $Weather{WindGustSpeed};
                speak "rooms=all Weather alert.  The winnd is now gusting at "
                  . round( $Weather{WindGustSpeed} ) . " MPH.";
                set $timer_wind_gust 120 * 60;
            }
            elsif ( inactive $timer_wind_gust) {
                set $timer_wind_gust 120 * 60;
                speak "rooms=all Weather alert.  A winnd gust of "
                  . round( $Weather{WindGustSpeed} )
                  . " MPH was just recorded.";
            }
        }
        $Save{WindGustMax} = 0 if $New_Day;

        $Weather{RainRecent} =
          round( ( $Weather{RainTotal} - $raintotal_prev ), 2 )
          if $raintotal_prev > 0;
        if ( $Weather{RainRecent} > 0 ) {
            speak "Notice, it just rained $Weather{RainRecent} inches";
            $Weather{IsRaining}++;
        }
        elsif ( $Minute % 20 ) {    # Reset every 20 minutes
            $Weather{IsRaining} = 0;
        }

        #   print "Notice, 1 it just rained $Weather{RainRecent} inches (total=$Weather{RainTotal}).\n" if $Weather{RainRecent} > 0;
        #   print "Notice, 2 it just rained $Weather{RainRate} inches\n" if $Weather{RainRate};

    }

}

sub get_weather_record {
    my ($time) = @_;
    my $tail;

    #10/28/1998 08:35:32,72.500000,86.360000,63.860000,46.940000,98.060000,29.120000,45.000000,78.000000,33.000000,97.000000,97.000000,29.000000,0.000000,296.000000,0.000000,296.000000,41.831900,29.000000,28.850810,28.850810,13.818898,0.000000,0.905512,51.800000,75.200000,39.200000,46.400000,78.800000,32.000000,46.400000,14.000000

    # Read and parse data into %Weather array
    my ( $min, $hour, $mday, $mon, $year ) =
      ( localtime($time) )[ 1, 2, 3, 4, 5 ];
    my ( $wdate, $wtime, $whour, $wmin );
    my $date = sprintf( "%02d%02d%4d", 1 + $mon, $mday, 1900 + $year );
    my $file = "d:/sbweather/$date.txt";

    return unless -e $file;

    # If looking for current record, just tail the current file ... much faster
    if ( $time > ( time - 120 ) ) {
        my @tail = &file_tail($file);
        $tail = $tail[-2];    # Last record may not be complete
    }

    # Otherwise, parse the appropriate file till we get a time that matches
    else {
        open( SBDATA, $file )
          or print "Warning, could not open weather file $file: $!\n";
        while (<SBDATA>) {
            ( $wdate, $whour, $wmin ) = $_ =~ /^(\S+) +(\S+):(\S+):\S+\,/;

            #           print "db whour=$whour wmin=$wmin\n";
            if ( $whour >= $hour and $wmin >= $min ) {
                $tail = $_;

                #               print "db min=$min tail=$tail\n";
                last;
            }
        }
        print "db date=$date,$wdate hour=$hour,$whour min=$min,$wmin\n";
    }

    #   print "db time=$time file_date=$date tail=$tail\n";

    my @data = split( ',', $tail );

    # Check to see if weather data is current
    ( $wdate, $wtime ) = split( ' ', $data[0] );
    ( $whour, $wmin )  = split( ':', $wtime );
    $wdate =~ s/\///g;
    my $time_diff = ( $hour + $min / 60 ) - ( $whour + $wmin / 60 );

    $timer_weather_date = new Timer();

    # Make sure we have the right date, and if today, we are with an hour

    if (   ( $date ne $wdate and $hour > 1 )
        or ( $time == time and $time_diff > 1 ) )
    {
        print_log "Weather data is not operational";
        if ( inactive $timer_weather_date
            and ( time - $Time_Startup_time ) > 60 * 5 )
        {
            #           speak "rooms=all Notice, the weather station is not operational." unless $Save{sleeping_parents};
            set $timer_weather_date 60 * 60;    # only warn once an hour
        }
        return;
    }
    else {
        #       print "db d=@data\n";
        return @data;
    }
}
