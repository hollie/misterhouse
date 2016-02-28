
# Category=Weather
#
# This code requests weather data from a weather server supporting the
# weather server protocol described at
#   http://www.thedrumms.org/~tony/WxServer.html
#
# A wxservices deamon that will serve Peet Brother weather station
# data (e.g. Ultimeter 2000) can be found here:
#   http://gonzo.thedrumms.org/~tony/WxServices.shtml
#
# To use:
#       Insert a line in your mh.ini or mh.private.ini indicating the
#       name and port of the weather server, such as
#               wxserver_host_port = localhost:16255
#       or
#               wxserver_host_port = www.thedrumms.org:16255
#
# I have not yet added a default, so this parm must exist to use this file!
#
# Created 11 January 2001 by A.D. Drumm
#

my $wxhost = $config_parms{wxserver_host_port};
$WxServer = new Socket_Item( undef, undef, $wxhost, undef, 'tcp', 'raw' );

my $CurrentWxRequest = 0;
my $DataToReceive    = 0;

# These are the wxserver commands for the data we want.
# We'll request them in sequence.
my @WxCommand = (
    "TCOTv",    # Today     Current Outside Temp      value
    "TCITv",    # Today     Current Inside  Temp      value
    "TCWSv",    # Today     Current Wind    Speed     value
    "TCWDv",    # Today     Current Wind    Direction value
    "TCWCv",    # Today     Current Wind    Chill     value
    "TCGSv",    # Today     Current Gust    Speed     value
    "TCGDv",    # Today     Current Gust    Direction value
    "TCOHv",    # Today     Current Outside Humidity  value
    "TCIHv",    # Today     Current Inside  Humidity  value
    "TCDPv",    # Today     Current Dew     Point     value
    "TCPRv",    # Today     Current PRessure          value
    "TCRAv",    # Today     Current RAin              value
    "YHRAv",    # Yesterday High    RAin              value
    "TCRHv"     # Today     Current Rain    Hourly    value
);

if ($Startup) {
    $WxServer->start;
    print_log "Starting the wxserver to $config_parms{wxserver_host_port}";
}

#if( time_cron('0,5,10,15,20,25,30,35,40,45,50,55 * * * *') )
if ( new_minute 1 ) {
    print_log "Collecting wxserver data";
    $CurrentWxRequest = 1;
    $WxServer->set( @WxCommand[ $CurrentWxRequest - 1 ] );
}

# Now watch for server response
if ($CurrentWxRequest) {
    if ( !$DataToReceive ) {

        # Start by sending request to the weather server
        $DataToReceive = 1;
        if ( $CurrentWxRequest <= 14 ) {
            $WxServer->set( @WxCommand[ $CurrentWxRequest - 1 ] );
        }
        else {
            # All done - store summary elements and go back to waiting state
            $DataToReceive    = 0;
            $CurrentWxRequest = 0;

            #$WxServer->stop;
            $Weather{Summary_Short} = sprintf(
                "%4.1f/%2d/%2d %3d%% %3d%%",
                $Weather{TempIndoor}, $Weather{TempOutdoor},
                $Weather{WindChill},  $Weather{HumidIndoor},
                $Weather{HumidOutdoor}
            );
            $Weather{Summary} = sprintf(
                "In/out/chill: %4.1f/%2d/%2d Humid:%3d%% %3d%%",
                $Weather{TempIndoor}, $Weather{TempOutdoor},
                $Weather{WindChill},  $Weather{HumidIndoor},
                $Weather{HumidOutdoor}
            );
            $Weather{SummaryRain} =
              sprintf( "Rain Recent/Total: %3.1f / %4.1f  Barom: %4d",
                $Weather{RainRate}, $Weather{RainTotal}, $Weather{Barom} );
            $Weather{SummaryWind} =
              sprintf( "Wind avg/gust:%3d /%3d  from the %s",
                $Weather{WindAvgSpeed}, $Weather{WindGustSpeed},
                &main::convert_direction( $Weather{WindAvgDir} ) );
        }
    }

    elsif ( my $data = $WxServer->said ) {
        $DataToReceive = 0;
        if ( $CurrentWxRequest == 1 ) {
            $data                 = ( $data * 9 / 5 ) + 32;
            $data                 = round( $data, 1 );
            $Weather{TempOutdoor} = $data;
            print_log "Outside temp is ${data} F";
        }
        elsif ( $CurrentWxRequest == 2 ) {
            $data                = ( $data * 9 / 5 ) + 32;
            $data                = round( $data, 1 );
            $Weather{TempIndoor} = $data;
            print_log "Inside temp is ${data} F";
        }
        elsif ( $CurrentWxRequest == 3 ) {
            $data                  = $data / 1.609;
            $data                  = round( $data, 1 );
            $Weather{WindAvgSpeed} = $data;
            print_log "Wind speed is ${data} mph";
        }
        elsif ( $CurrentWxRequest == 4 ) {
            $Weather{WindAvgDir} = $data;
            print_log "Wind direction is ${data} degrees";
        }
        elsif ( $CurrentWxRequest == 5 ) {
            $data               = ( $data * 9 / 5 ) + 32;
            $data               = round( $data, 1 );
            $Weather{WindChill} = $data;
            print_log "Wind chill is ${data} F";
        }
        elsif ( $CurrentWxRequest == 6 ) {
            $data                   = $data / 1.609;
            $data                   = round( $data, 1 );
            $Weather{WindGustSpeed} = $data;
            print_log "Gust speed is ${data} mph";
        }
        elsif ( $CurrentWxRequest == 7 ) {
            $Weather{WindGustDir} = $data;
            print_log "Gust direction is ${data} degrees";
        }
        elsif ( $CurrentWxRequest == 8 ) {
            $Weather{HumidOutdoor} = $data;
            print_log "Outdoor humidity is ${data} %";
        }
        elsif ( $CurrentWxRequest == 9 ) {
            $Weather{HumidIndoor} = $data;
            print_log "Indoor Humidity is ${data} %";
        }
        elsif ( $CurrentWxRequest == 10 ) {
            $data                = ( $data * 9 / 5 ) + 32;
            $data                = round( $data, 1 );
            $Weather{DewOutdoor} = $data;
            print_log "Dew point is ${data} F";
        }
        elsif ( $CurrentWxRequest == 11 ) {
            $Weather{BaromSea} = $data;
            $Weather{Barom}    = $data;
            print_log "Barametric pressure is ${data} mb";
        }
        elsif ( $CurrentWxRequest == 12 ) {
            $data               = $data / 25.4;
            $data               = round( $data, 2 );
            $Weather{RainTotal} = $data;
            print_log "Rain today is ${data} in";
        }
        elsif ( $CurrentWxRequest == 13 ) {
            $data              = $data / 25.4;
            $data              = round( $data, 2 );
            $Weather{RainYest} = $data;
            print_log "Rain yesterday is ${data} in";
        }
        elsif ( $CurrentWxRequest == 14 ) {
            $data              = $data / 25.4;
            $data              = round( $data, 2 );
            $Weather{RainRate} = $data;
            print_log "Rain within last hour is ${data} in";
        }

        $CurrentWxRequest++;
    }
}

