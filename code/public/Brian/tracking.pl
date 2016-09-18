######################################################
# Klier Home Automation - Tracking Module            #
# Version 7.00                                       #
# By: Brian J. Klier, N0QVC                          #
# November 13, 2010                                  #
# E-Mail: brian@kliernetwork.net                     #
# Webpage: http://www.kliernetwork.net               #
######################################################
#
# For more information on hardware needed for this system to function:
#   - Check out http://www.kliernetwork.net/aprs    and
#               http://www.kliernetwork.net/aprs/mine
#
# New in Version 7.00:
#   - No TNC Necessary!  Now uses APRS-IS to connect and communicate with the APRS network
#   - Fixed bearing of mobile/weather stations from our own
#   - System to execute commands when my station is close to home
#
# New in Version 6.00:
#   - Added numerous position and operational fixes
#
# New in Version 4.92:
#   - Added Roger Bille's "Longitude Hundreds" Fix
#
# New in Version 4.91:
#   - Fixed bugs in "EMAIL2" Procedure
#   - Added ALPHA Procedure to take data from Telnet Port and transmit
#     on the air (for WinAPRS Connectivity)
#
# New in Version 4.9:
#   - Fixed bugs in the HTML Based Logging System.
#
# New in Version 4.8 and 4.8a:
#   - Added HTML Based Logging (from Bruce's tracking_bruce.pl) for GPS's.
#
# New in Version 4.7:
#   - Added Speaking of POSFILE Positions for Weather Stations
#
# New in Version 4.62:
#   - Fixed problem with tracking_withname and speaking EVERY position
#     instead of checking to see if it was the same as the last one.
#   - Added ability to respond to ?WX? queries with current temperature.
#
# New in Version 4.6:
#   - 4.61 ALPHA - Continued work on proper implementation.
#   - Added tracking_shortannounce and tracking_withname variables.
#   - NOTE: I STILL need to implement tracking_withname=2!!!
#
# New in Version 4.5:
#   - 4.52 ALPHA - MHATS now ignores "acks" that are sent - does not talk
#                  to them.  Also added msg # to "msg received" messages.
#   - 4.51 ALPHA - Fix Small Bug in X-10 Message Response...
#   - ALPHA - Working on Temperature Graphs
#   - Changed "EMAIL" gateway to "EMAIL2" so it doesn't interfere with the
#     main APRS IGATES.
#
# New in Version 4.4:
#   - Fixed all the messaging/X10 Packet Remote Control stuff.
#   - Bulletin feature still needs to be tested for operation.
#
# Next Version Wishlist:
#   - Check for duplicate messages in a row (like when they pass through
#     a digipeater to make sure an X10 command isn't sent twice)

# Category=Vehicles

# Declare Variables

$timer_email_digipeat    = new Timer;
$timer_myvehicle_process = new Timer;
$enable_transmit         = new Generic_Item;
use vars '$GPSSpeakString', '$GPSSpeakString2', '$WXSpeakString',
  '$WXSpeakString2', '$CurrentTemp', '$CurrentChill', '$WXWindDirVoice',
  '$WXWindSpeed', '$WXHrPrecip';

my ( $APRSFoundAPRS, $APRSPacketDigi, $GPSTime, $APRSStatus, $MsgLine );
my (
    $GPSLatitudeDegrees,  $GPSLatitudeMinutes,
    $GPSLongitudeDegrees, $GPSCallsign
);
my (
    $GPSLongitudeMinutes, $GPSLatitude, $GPSLongitude,
    $GPSDistance,         $GPSLongitudeMinutes100
);
my ( $GPSLstBr, $GPSLstBrLat, $GPSLstBrLon );

my ( @gpscomplines, $GPSTempCompPlace, $GPSTempCompDist, $GPSTempCompLine );
my ( $GPSTempCompLat, $GPSTempCompLong );
my ( $GPSCompPlace, $GPSCompLat, $GPSCompLong, $GPSCompDist );
my ( $GPSCompLstBr, $GPSCompLstBrLat, $GPSCompLstBrLon );

my ( $WXTempCompPlace, $WXTempCompDist, $WXTempCompLine );
my ( $WXTempCompLat, $WXTempCompLong );
my ( $WXCompPlace, $WXCompLat, $WXCompLong, $WXCompDist );
my ( $WXCompLstBr, $WXCompLstBrLat, $WXCompLstBrLon );

my ( @namelines, $TempName, $TempNameCall, $TempNameName );

my ( $i, $j, $k, $CallsignPart, $PacketPart, $GPSSpeed, $GPSCourse,
    $GPSCourseVoice );
my ( $ToCallsignPart, $LastGPSCallsign,  $LastGPSDistance, $LastGPSLstBr );
my ( $APRSCallsign,   $APRSStringLength, $APRSString,      $MessageX10Command );
my ($MessageX10Action);
my ( $GPSSpeakString3, $MessageAck, $APRSCallsignVoice, $HamCall, $HamName );
my ( $WXTime, $WXLatitudeDegrees, $WXLatitudeMinutes, $WXLongitudeDegrees );
my ( $WXLongitudeMinutes, $WXLatitude, $WXLongitude, $WXDistance, $WXTemp );
my ( $WXLstBr, $WXLstBrLat, $WXLstBrLon );
my ( $WXCallsign, $WXWindDir, $WX24HrPrecip, $RealAPRSCallsign );
my ( $CurrentTempDist, $WXWindChill );
my ( $LastWXCallsign, $LastWXTemp, $LastWXDistance, $LastWXWindDir );
my ( $LastWXWindSpeed, $LastWXWindChill, $APRSCallsignNoSSID );
my ( $LastWXHrPrecip, $LastWX24HrPrecip, $CurrentHrPrecip, $Current24HrPrecip );

# Setup TELNET Server 2 (port 14439) to output what the TNC hears

$telnet = new Socket_Item( '#Welcome to MisterHouse APRS Tracking!',
    'APRSWelcome', 'server_aprs' );

# Send Welcome Message out port 2 if connected.
set $telnet 'APRSWelcome' if active_now $telnet;
set $telnet
  'APRSERVE>APRS:javaTITLE:N0QVC MisterHouse - tracking.pl - Brian Klier, N0QVC'
  if active_now $telnet;

my $socket_speak_loop;
if ( my $telnetdata = said $telnet) {
    print_log "Data Transmitted from Telnet Port: $telnetdata";
    set $tnc_output $telnetdata;
}

# TNC Output Lines

$tnc_output = new Socket_Item(
    'user MYCALL pass MYPASS vers Misterhouse Win32 filter f/N0QVC-1/75',
    'login', 'midwest.aprs2.net:14580', undef, 'tcp', 'records' );
$tnc_output->add( '?WX?', 'wxquery' );
$tnc_output->add(
    sprintf(
        "MYCALL>APRSMH,TCPIP*:=%2d%05.02fN/0%2d%05.02fW- *** %s MisterHouse Tracking System ***",
        int( $config_parms{latitude} ),
        abs( $config_parms{latitude} - int( $config_parms{latitude} ) ) * 60,
        abs( int( $config_parms{longitude} ) ),
        abs( $config_parms{longitude} - int( $config_parms{longitude} ) ) * 60,
        $config_parms{tracking_callsign}
    ),
    ,
    'position'
);
set_casesensitive $tnc_output;

# Set TNC to Converse and send position on Startup

if ($Reload) {
    set $timer_email_digipeat 1;
    set $timer_myvehicle_process 1;
    set $enable_transmit 'yes';
    $HamCall = $config_parms{tracking_callsign};  # Feed in my Tracking Callsign
    open( GPSCOMP, "$config_parms{code_dir}/tracking.pos" );    # Open for input
    @gpscomplines = <GPSCOMP>;                                  # Open array and
                                                                # read in data
    close GPSCOMP;                                              # Close the file

    open( GPSNAME, "$config_parms{code_dir}/tracking.nam" );    # Open for input
    @namelines = <GPSNAME>;                                     # Open array and
                                                                # read in data
    close GPSNAME;                                              # Close the file
}

if ($Startup) {
    mkdir "$Pgm_Root/web/javAPRS", 777 unless -d "$Pgm_Root/web/javAPRS";
    set $timer_email_digipeat 1;
    set $timer_myvehicle_process 1;
    set $enable_transmit 'yes';
    open( APRSLOG, ">$Pgm_Root/web/javAPRS/aprs.tnc" );         # CLEAR Log
    close APRSLOG;
    $tnc_output->start;
    sleep 1;
    set $tnc_output 'login';
    print_log "Starting connection to APRS-IS Server";
    set $tnc_output 'position';
    print_msg "Tracking Interface has been Initialized...Callsign $HamCall";
    print_log "Tracking Interface has been Initialized...Callsign $HamCall";
}

if ( active_now $tnc_output) {
    print_log "Sending Login";
    set $tnc_output 'login';
    set $tnc_output 'position';
}

if ( inactive_now $tnc_output) {
    print_log "Telnet: session closed";
    $tnc_output->start;
    print_log "Starting connection to APRS-IS Server";
}

# Voice Responses
$v_send_position = new Voice_Cmd("Send my Position");

if ( $state = said $v_send_position) {
    set $tnc_output 'position';
    print_log "Position Sent.";
    speak "Position Sent.";
}

$v_send_status = new Voice_Cmd("Send my Status Report");

if ( $state = said $v_send_status) {
    $APRSStatus =
      "$HamCall>APRSMH,TCPIP*:>Frnt Move $motion_detector_frontdoor->{state}-Bck Move $motion_detector_backdoor->{state}-Kitc Move $motion_detector_kitchen->{state}-Garg Move $motion_detector_garage->{state}-Temp: $CurrentTemp";
    set $tnc_output $APRSStatus;
    print_log "Status Sent.";
    speak "Status Sent.";
}

$v_wx_query = new Voice_Cmd("Weather Query");

if ( $state = said $v_wx_query) {
    set $tnc_output 'wxquery';
    print_log "Weather Query Requested.";
    speak "Weather Query Requested.";
}

$v_last_callsign = new Voice_Cmd("Last Callsign");

if ( $state = said $v_last_callsign and $APRSCallsign ne '' ) {
    print_log "Callsign is $APRSCallsign.";
    speak "Call sign is $APRSCallsign.";
}
elsif ( $state = said $v_last_callsign and $APRSCallsign eq '' ) {
    print_log "No packets received.";
    speak "No packets received.";
}

$v_last_mobile = new Voice_Cmd("Last Mobile Report");

if ( $state = said $v_last_mobile and $GPSCallsign ne '' ) {
    print_log "$GPSSpeakString";
    speak $GPSSpeakString;
}
elsif ( $state = said $v_last_mobile and $GPSCallsign eq '' ) {
    print_log "No mobile packets received.";
    speak "No mobile packets received.";
}

$v_last_wxrpt = new Voice_Cmd("Last Weather Report");

if ( $state = said $v_last_wxrpt) {
    if ( $WXTemp ne '' ) {
        print_log "$WXSpeakString";
        speak $WXSpeakString;
    }
    elsif ( $WXTemp eq '' ) {
        print_log "No weather packets received.";
        speak "No weather packets received.";
    }
}

$v_curr_cond = new Voice_Cmd("Current Conditions");

if ( $state = said $v_curr_cond) {
    if ( $CurrentTemp ne '' ) {
        if ( $CurrentTemp eq $CurrentChill ) {
            print_log "Temperature is $CurrentTemp degrees.";
            speak "Temperature is $CurrentTemp degrees.";
        }
        if ( $CurrentTemp ne $CurrentChill ) {
            print_log
              "Temperature is $CurrentTemp degrees.  Wind Chill is $CurrentChill degrees.";
            speak
              "Temperature is $CurrentTemp degrees.  Winnd Chill is $CurrentChill degrees.";
        }
        if ( $CurrentHrPrecip != 0 ) {
            print_log
              "$CurrentHrPrecip inches of rain in the last hour. $Current24HrPrecip total inches of rain today.";
            speak
              "$CurrentHrPrecip inches of rain in the last hour. $Current24HrPrecip total inches of rain today.";
        }
    }
    elsif ( $CurrentTemp eq '' ) {
        print_log "No weather packets received.";
        speak "No weather packets received.";
    }
}

$v_curr_precip = new Voice_Cmd("Current Precipitation");

if ( $state = said $v_curr_precip) {
    if ( $CurrentHrPrecip != 0 ) {
        print_log
          "$CurrentHrPrecip inches of rain in the last hour. $Current24HrPrecip total inches of rain today.";
        speak
          "$CurrentHrPrecip inches of rain in the last hour. $Current24HrPrecip total inches of rain today.";
    }
    elsif ( $CurrentTemp eq '' ) {
        print_log "No weather packets received.";
        speak "No weather packets received.";
    }
    else {
        print_log "No rain to report.";
        speak "No rain to report.";
    }
}

# Procedure to Log Temperature and Stats every 10 minutes

if ( time_cron('0,10,20,30,40,50 * * * *') or $Startup ) {
    logit( "$Pgm_Path/../web/mh/weather.html",
        "<FONT SIZE=-2>Temp: $CurrentTemp &nbsp;&nbsp;&nbsp;Wind Chill: $CurrentChill &nbsp;&nbsp;&nbsp;Wind: $LastWXWindDir/$LastWXWindSpeed &nbsp;&nbsp;&nbsp;Precipitation: $WXHrPrecip/$WX24HrPrecip<BR></FONT>"
    );
    logit( "$Pgm_Path/../data/logs/weather.log",
        ",$CurrentTemp,$LastWXWindDir,$LastWXWindSpeed,$WXHrPrecip,$WX24HrPrecip"
    );
}

# Daily Weather and Tracking Log Backup

if ( time_cron('0 0 * * *') ) {
    print_log "Backing up Weather Log.";
    open( WXGRAPHIN, ">$Pgm_Path/../data/logs/weather.log" );    # CLEAR Log
    close WXGRAPHIN;
    open( WXGRAPHIN, ">$Pgm_Path/../web/mh/weather.html" );      # CLEAR Log
    close WXGRAPHIN;
    open( NEWDAY, ">$config_parms{html_dir}/mh/tracking/today.html" );
    close NEWDAY;
    my $html =
      qq[<link rel="STYLESHEET" href="/default.css" type="text/css">\n<table>\n];
    $html .=
      qq[<tr><td><b>Date Time</b></td><td><b>Vehicle Heading and Speed</b></td><td><b>Location</b></td><td><b>New Location</b></td></tr>\n];
    logit "$config_parms{html_dir}/mh/tracking/today.html", $html, 0, 1;
    logit "$config_parms{html_dir}/mh/tracking/week1.html", "<hr>\n", 0, 1;
}

if ( time_cron('0 0 * * 0') ) {
    open( NEWWEEK, ">$config_parms{html_dir}/mh/tracking/week1.html" );
    close NEWWEEK;

    #file_cat "$config_parms{html_dir}/mh/tracking/week2.html", "$config_parms{html_dir}/mh/tracking/old/${Year_Month_Now}.html";
    #rename "$config_parms{html_dir}/mh/tracking/week1.html", "$config_parms{html_dir}/mh/tracking/week2.html"  or print_log "Error in aprs rename 2: $!";
    my $html =
      qq[<link rel="STYLESHEET" href="/default.css" type="text/css">\n<table>\n];
    $html .=
      qq[<tr><td><b>Date Time</b></td><td><b>Vehicle Heading and Speed</b></td><td><b>Location</b></td><td><b>New Location</b></td></tr>\n];
    logit "$config_parms{html_dir}/mh/tracking/week1.html", $html, 1;
}

# Procedure to occasionally send out APRS Position Report and Status String,
##### 7/29/05: and update Current Temp with Internet Temp from KFBL

if ( state $enable_transmit eq 'yes' and time_cron('0 * * * *') ) {
    set $tnc_output 'position';
    $APRSStatus =
      "$HamCall>APRSMH,TCPIP*:>Frnt Move $motion_detector_frontdoor->{state}-Bck Move $motion_detector_backdoor->{state}-Kitc Move $motion_detector_kitchen->{state}-Garg Move $motion_detector_garage->{state}-Temp: $CurrentTemp";
    set $tnc_output $APRSStatus;
#####
    #    $CurrentTemp = $Weather{TempInternet};
}

# Main TNC Parse Procedure

if ( $APRSString = said $tnc_output) {

    open( APRSLOG, ">>$Pgm_Root/web/javAPRS/aprs.tnc" );    # Log it
    print APRSLOG "$APRSString\n";
    close APRSLOG;

    print_msg "TRACK: $APRSString";    # Monitor to Msg Window

    $APRSFoundAPRS    = "";                         # Reset Found Flag
                                                    # $APRSPacketDigi = "";
    $APRSStringLength = ( length($APRSString) );    # Save Length of Ser

    # Send the packet out TELNET if connected...
    set $telnet $APRSString if active $telnet;

    # Decode the Callsign and different parts from the Packet

    ( $CallsignPart, $MsgLine ) =
      ( split( '::', $APRSString ) )[ 0, 1 ];       #New Line for Msging
    ( $CallsignPart, $PacketPart ) = ( split( ':', $APRSString ) )[ 0, 1 ];
    ( $APRSCallsign, $ToCallsignPart ) =
      ( split( '>', $CallsignPart ) )[ 0, 1 ];
    ( $APRSCallsignNoSSID, $j ) = ( split( '-', $APRSCallsign ) )[ 0, 1 ];

    # Save the APRS Callsign for Message Reading Procedure (non-spaced)

    $RealAPRSCallsign = $APRSCallsign;

    # Make APRS Callsign so it is spoken properly

    $j = '';
    for ( $i = 0; $i != ( length($APRSCallsign) ); ++$i ) {
        $j = $j . substr( $APRSCallsign, $i, 1 );
        $j = $j . " ";
    }
    $APRSCallsign = $j;

    # MAIN LOOP

    if ( $APRSFoundAPRS != 1 ) {

        # If it's a $GPRMC, $GPGGA, or Mic-E statement for GPS,
        if (   ( substr( $PacketPart, 0, 6 ) eq '$GPRMC' )
            || ( substr( $PacketPart, 0, 6 ) eq '$GPGGA' )
            || ( substr( $PacketPart, 0, 1 ) eq '`' )
            || ( substr( $PacketPart, 0, 1 ) eq "'" ) )
        {
            $APRSFoundAPRS       = 1;                # Found an APRS String
            $GPSCallsign         = $APRSCallsign;    # Reset Variables
            $GPSTime             = "";
            $GPSLatitudeDegrees  = "";
            $GPSLatitudeMinutes  = "";
            $GPSLongitudeDegrees = "";
            $GPSLongitudeMinutes = "";
            $GPSLatitude         = "";
            $GPSLongitude        = "";
            $GPSDistance         = "";
            $GPSSpeed            = "";
            $GPSCourse           = "";
            $GPSCourseVoice      = "";
            $GPSLstBr            = "";
            $GPSLstBrLat         = "";
            $GPSLstBrLon         = "";
            $GPSCompPlace        = "";
            $GPSCompLat          = "";
            $GPSCompLong         = "";
            $GPSCompDist         = "9999";
            $GPSSpeakString2     = "";
            $GPSTempCompPlace    = "";
            $GPSTempCompDist     = "";

            # Find out the user defined "name" for this callsign.

            $j = '0';

            foreach $TempName (@namelines) {
                if ( $j eq '0' ) {
                    ( $TempNameCall, $TempNameName ) =
                      ( split( ',', $TempName ) )[ 0, 1 ];
                    if ( $TempNameCall eq $APRSCallsignNoSSID ) {
                        $HamName = $TempNameName;
                        chomp $HamName;
                        $j = '1';
                    }
                }
            }

            # If there is NO defined name, make $HamName equal to the callsign

            if ( $j eq '0' ) {
                $HamName = $APRSCallsign;

                #print_msg "$APRSString -> No callsign Found\n";
            }

            if ( substr( $PacketPart, 0, 6 ) eq '$GPRMC' ) {
                ( $GPSTime, $GPSLatitude, $GPSLongitude, $GPSSpeed, $GPSCourse )
                  = ( split( ',', $PacketPart ) )[ 1, 3, 5, 7, 8 ];
            }

            if ( substr( $PacketPart, 0, 6 ) eq '$GPGGA' ) {
                ( $GPSTime, $GPSLatitude, $GPSLongitude ) =
                  ( split( ',', $PacketPart ) )[ 1, 2, 4 ];
            }

            if (   ( substr( $PacketPart, 0, 6 ) eq '$GPRMC' )
                || ( substr( $PacketPart, 0, 6 ) eq '$GPGGA' ) )
            {

                $GPSTime = ( substr( $GPSTime, 0, 6 ) );    # Get the GPS Time
                $GPSLatitudeDegrees = ( substr( $GPSLatitude, 0, 2 ) );
                $GPSLatitudeMinutes = ( substr( $GPSLatitude, 2, 8 ) );
                $GPSLatitude =
                  ( $GPSLatitudeDegrees + ( $GPSLatitudeMinutes / 60 ) );
                $GPSLongitudeDegrees = ( substr( $GPSLongitude, 0, 3 ) );
                $GPSLongitudeMinutes = ( substr( $GPSLongitude, 3, 8 ) );
                $GPSLongitude =
                  ( $GPSLongitudeDegrees + ( $GPSLongitudeMinutes / 60 ) );

                # Convert the GPS Speed to MPH
                $GPSSpeed = ( $GPSSpeed * 1.853248 ) / 1.609344;
            }

            if (
                ( substr( $PacketPart, 0, 1 ) eq '`' ) ||    # If a Mic-E,
                ( substr( $PacketPart, 0, 1 ) eq "'" )
              )
            {

                $GPSLongitudeDegrees = ( substr( $PacketPart, 1, 1 ) );
                $GPSLongitudeDegrees =
                  ( unpack( 'C', $GPSLongitudeDegrees ) ) - 28;
                if (    $GPSLongitudeDegrees >= 180
                    and $GPSLongitudeDegrees <= 189 )
                {
                    $GPSLongitudeDegrees = $GPSLongitudeDegrees - 80;
                }
                if (    $GPSLongitudeDegrees >= 190
                    and $GPSLongitudeDegrees <= 199 )
                {
                    $GPSLongitudeDegrees = $GPSLongitudeDegrees - 190;
                }

                $GPSLongitudeMinutes = ( substr( $PacketPart, 2, 1 ) );
                $GPSLongitudeMinutes =
                  ( unpack( 'C', $GPSLongitudeMinutes ) ) - 28;
                if ( $GPSLongitudeMinutes > 60 ) {
                    $GPSLongitudeMinutes = $GPSLongitudeMinutes - 60;
                }

                # Added Lines from Roger
                $GPSLongitudeMinutes100 = ( substr( $PacketPart, 3, 1 ) );
                $GPSLongitudeMinutes100 =
                  ( unpack( 'C', $GPSLongitudeMinutes100 ) ) - 28;

                $GPSLongitude =
                  ( $GPSLongitudeDegrees +
                      ( $GPSLongitudeMinutes / 60 ) +
                      ( $GPSLongitudeMinutes100 / 6000 ) );

                $GPSSpeed = ( substr( $PacketPart, 4, 1 ) );
                $GPSSpeed = ( ( unpack( 'C', $GPSSpeed ) ) - 28 ) * 10;

                # $CallsignPart simply used as a temp variable
                $CallsignPart = ( substr( $PacketPart, 5, 1 ) );
                $GPSSpeed = ( ( ( unpack( 'C', $CallsignPart ) ) - 28 ) / 10 ) +
                  $GPSSpeed;

                $GPSCourse = ( ( unpack( 'C', $CallsignPart ) ) - 28 ) % 10;

                # $CallsignPart simply used as a temp variable
                $CallsignPart = ( substr( $PacketPart, 6, 1 ) );
                $GPSCourse =
                  ( ( unpack( 'C', $CallsignPart ) ) - 28 ) + $GPSCourse;

                # Last minute course and speed adjustments per specs
                if ( $GPSSpeed >= 800 )  { $GPSSpeed  = $GPSSpeed - 800 }
                if ( $GPSCourse >= 400 ) { $GPSCourse = $GPSCourse - 400 }

                # Convert the GPS Speed to MPH
                $GPSSpeed = ( $GPSSpeed * 1.853248 ) / 1.609344;

                # Truncate Course to max of 3 numbers for parsing below
                $GPSCourse = substr( $GPSCourse, 0, 3 );

                # Round the Speed to the nearest integer
                $GPSSpeed = round($GPSSpeed);

                # Load the tens digit of Degrees Latitude
                $GPSLatitudeDegrees = ( substr( $ToCallsignPart, 0, 1 ) );
                $GPSLatitudeDegrees =
                  ( unpack( 'C', $GPSLatitudeDegrees ) ) - 32;
                $GPSLatitudeDegrees = ( $GPSLatitudeDegrees & 15 ) * 10;

                # Load the ones digit of Degrees Latitude (temp variable used)
                $GPSDistance = ( substr( $ToCallsignPart, 1, 1 ) );
                $GPSDistance = ( unpack( 'C', $GPSDistance ) ) - 32;
                $GPSDistance = ( $GPSDistance & 15 );

                # Here's our Degrees Latitude
                $GPSLatitudeDegrees = $GPSLatitudeDegrees + $GPSDistance;

                # Load the tens digit of Minutes Latitude
                $GPSLatitudeMinutes = ( substr( $ToCallsignPart, 2, 1 ) );
                $GPSLatitudeMinutes =
                  ( unpack( 'C', $GPSLatitudeMinutes ) ) - 32;
                $GPSLatitudeMinutes = ( $GPSLatitudeMinutes & 15 ) * 10;

                # Load the ones digit of Minutes Latitude (temp variable used)
                $GPSDistance = ( substr( $ToCallsignPart, 3, 1 ) );
                $GPSDistance = ( unpack( 'C', $GPSDistance ) ) - 32;
                $GPSDistance = ( $GPSDistance & 15 );

                # Here's our Minutes Latitude
                $GPSLatitudeMinutes = $GPSLatitudeMinutes + $GPSDistance;

                # Load the tens digit of hundreds of Minutes Latitude
                # $CallsignPart simply used as a temp variable
                $CallsignPart = ( substr( $ToCallsignPart, 4, 1 ) );
                $CallsignPart = ( unpack( 'C', $CallsignPart ) ) - 32;
                $CallsignPart = ( $CallsignPart & 15 ) * 10;

                # Load the ones digit of hundreds of Minutes Latitude
                # (temp variable used)
                $GPSDistance = ( substr( $ToCallsignPart, 5, 1 ) );
                $GPSDistance = ( unpack( 'C', $GPSDistance ) ) - 32;
                $GPSDistance = ( $GPSDistance & 15 );

                # Here's our hundreds of Minutes Latitude
                $CallsignPart = $CallsignPart + $GPSDistance;

                $GPSLatitude =
                  ( $GPSLatitudeDegrees +
                      ( $GPSLatitudeMinutes / 60 ) +
                      ( $CallsignPart / 6000 ) );
            }

            # --- Do the following for all received GPS Strings

            # Calculate distance station is away
            $GPSDistance = &great_circle_distance(
                $GPSLatitude, $GPSLongitude,
                abs $config_parms{latitude},
                abs $config_parms{longitude}
            );
            $GPSDistance = round( $GPSDistance, 1 );

            # Calculate bearing from the Position file
            foreach $GPSTempCompLine (@gpscomplines) {
                ( $GPSTempCompPlace, $GPSTempCompLat, $GPSTempCompLong ) =
                  ( split( ',', $GPSTempCompLine ) )[ 0, 1, 2 ];

                # Calculate distance station is away from pos file
                $GPSTempCompDist = &great_circle_distance(
                    $GPSLatitude,    $GPSLongitude,
                    $GPSTempCompLat, abs $GPSTempCompLong
                );
                $GPSTempCompDist = round( $GPSTempCompDist, 1 );

                if ( $GPSTempCompDist < 15 and $GPSTempCompDist < $GPSCompDist )
                {
                    $GPSCompPlace = $GPSTempCompPlace;
                    $GPSCompDist  = $GPSTempCompDist;
                    $GPSCompLat   = $GPSTempCompLat;
                    $GPSCompLong  = $GPSTempCompLong;
                }
            }

            # Calculate if station is north/west/east/south of POSFILE
            $GPSCompLstBrLat = ( $GPSCompLat - $GPSLatitude );
            $GPSCompLstBrLon = ( $GPSCompLong - $GPSLongitude );
            if ( $GPSCompLstBrLat < 0 and $GPSCompLstBrLon < 0 ) {
                $GPSCompLstBr = 'northwest';
            }
            if ( $GPSCompLstBrLat > 0 and $GPSCompLstBrLon < 0 ) {
                $GPSCompLstBr = 'southwest';
            }
            if ( $GPSCompLstBrLat < 0 and $GPSCompLstBrLon > 0 ) {
                $GPSCompLstBr = 'northeast';
            }
            if ( $GPSCompLstBrLat > 0 and $GPSCompLstBrLon > 0 ) {
                $GPSCompLstBr = 'southeast';
            }
            if ( $GPSCompLstBrLat <= 0
                and ( $GPSCompLstBrLon * 2 ) < $GPSCompLstBrLat )
            {
                $GPSCompLstBr = 'north';
            }
            if ( $GPSCompLstBrLat >= 0
                and ( $GPSCompLstBrLon * 2 ) < $GPSCompLstBrLat )
            {
                $GPSCompLstBr = 'south';
            }
            if ( $GPSCompLstBrLon <= 0
                and ( $GPSCompLstBrLat * 2 ) < $GPSCompLstBrLon )
            {
                $GPSCompLstBr = 'west';
            }
            if ( $GPSCompLstBrLon >= 0
                and ( $GPSCompLstBrLat * 2 ) < $GPSCompLstBrLon )
            {
                $GPSCompLstBr = 'east';
            }

            # Calculate if station is north/west/east/south of ours
            $GPSLstBrLat = ( $config_parms{latitude} - $GPSLatitude );
            $GPSLstBrLon = ( $config_parms{longitude} - $GPSLongitude );

            if ( $GPSLstBrLat < 0 and $GPSLstBrLon < 0 ) {
                $GPSLstBr = 'northwest';
            }
            if ( $GPSLstBrLat > 0 and $GPSLstBrLon < 0 ) {
                $GPSLstBr = 'southwest';
            }
            if ( $GPSLstBrLat < 0 and $GPSLstBrLon > 0 ) {
                $GPSLstBr = 'northeast';
            }
            if ( $GPSLstBrLat > 0 and $GPSLstBrLon > 0 ) {
                $GPSLstBr = 'southeast';
            }
            if ( $GPSLstBrLat <= 0 and ( $GPSLstBrLon * 2 ) < $GPSLstBrLat ) {
                $GPSLstBr = 'north';
            }
            if ( $GPSLstBrLat >= 0 and ( $GPSLstBrLon * 2 ) < $GPSLstBrLat ) {
                $GPSLstBr = 'south';
            }
            if ( $GPSLstBrLon <= 0 and ( $GPSLstBrLat * 2 ) < $GPSLstBrLon ) {
                $GPSLstBr = 'west';
            }
            if ( $GPSLstBrLon >= 0 and ( $GPSLstBrLat * 2 ) < $GPSLstBrLon ) {
                $GPSLstBr = 'east';
            }

            # Add bearing from station in position file IF it's a new position report
            if (
                (
                       ( $GPSCallsign ne $LastGPSCallsign )
                    || ( $GPSDistance ne $LastGPSDistance )
                )
                and ( $GPSCompDist ne '9999' )
              )
            {
                $GPSSpeakString2 =
                  "Currently $GPSCompDist miles $GPSCompLstBr of $GPSCompPlace.";

                # and form a special speak string just for on the air
                $GPSSpeakString3 =
                  "$HamCall>APRSMH,TCPIP*:>$RealAPRSCallsign $GPSCompDist mi $GPSCompLstBr of $GPSCompPlace.";

                if ( $GPSDistance <= 0.2 ) {
                    $GPSSpeakString2 = "Currently near $GPSCompPlace.";
                    $GPSSpeakString3 =
                      "$HamCall>APRSMH,TCPIP*:>$RealAPRSCallsign near $GPSCompPlace.";
                }
                if (    ( substr( $PacketPart, 0, 6 ) eq '$GPRMC' )
                    and ( $GPSDistance <= 0.1 )
                    and ( $GPSSpeed <= 1 ) )
                {
                    $GPSSpeakString2 = "Currently parked at $GPSCompPlace.";
                    $GPSSpeakString3 =
                      "$HamCall>APRSMH,TCPIP*:>$RealAPRSCallsign parked at $GPSCompPlace.";
                }
                if (    ( substr( $PacketPart, 0, 6 ) eq '$GPGGA' )
                    and ( $GPSDistance <= 0.1 ) )
                {
                    $GPSSpeakString2 = "Currently at $GPSCompPlace.";
                    $GPSSpeakString3 =
                      "$HamCall>APRSMH,TCPIP*:>$RealAPRSCallsign at $GPSCompPlace.";
                }

### ***         ### REMARKED OUT, DON'T TRANSMIT WHERE PEOPLE ARE AT
                #                if (state $enable_transmit eq 'yes') {set $tnc_output $GPSSpeakString3};
            }

            # If It's a $GPRMC or Mic-E String,

            if (   ( substr( $PacketPart, 0, 6 ) eq '$GPRMC' )
                || ( substr( $PacketPart, 0, 1 ) eq "'" )
                || ( substr( $PacketPart, 0, 1 ) eq '`' ) )
            {

                # Only Calculate Course & Speed if it's a $GPRMC string,
                if ( substr( $PacketPart, 0, 6 ) eq '$GPRMC' ) {

                    # Truncate Course to max of 3 numbers for parsing below
                    $GPSCourse = substr( $GPSCourse, 0, 3 );

                    # Round the Speed to the nearest integer
                    $GPSSpeed = round($GPSSpeed);
                }

                $GPSCourseVoice = "north"
                  if ( $GPSCourse >= 0 and $GPSCourse <= 11 );
                $GPSCourseVoice = "north-northeast"
                  if ( $GPSCourse >= 12 and $GPSCourse <= 33 );
                $GPSCourseVoice = "northeast"
                  if ( $GPSCourse >= 34 and $GPSCourse <= 55 );
                $GPSCourseVoice = "east-northeast"
                  if ( $GPSCourse >= 56 and $GPSCourse <= 77 );
                $GPSCourseVoice = "east"
                  if ( $GPSCourse >= 78 and $GPSCourse <= 99 );
                $GPSCourseVoice = "east-southeast"
                  if ( $GPSCourse >= 100 and $GPSCourse <= 121 );
                $GPSCourseVoice = "southeast"
                  if ( $GPSCourse >= 122 and $GPSCourse <= 143 );
                $GPSCourseVoice = "south-southeast"
                  if ( $GPSCourse >= 144 and $GPSCourse <= 165 );
                $GPSCourseVoice = "south"
                  if ( $GPSCourse >= 166 and $GPSCourse <= 187 );
                $GPSCourseVoice = "south-southwest"
                  if ( $GPSCourse >= 188 and $GPSCourse <= 209 );
                $GPSCourseVoice = "southwest"
                  if ( $GPSCourse >= 210 and $GPSCourse <= 231 );
                $GPSCourseVoice = "west-southwest"
                  if ( $GPSCourse >= 232 and $GPSCourse <= 253 );
                $GPSCourseVoice = "west"
                  if ( $GPSCourse >= 254 and $GPSCourse <= 275 );
                $GPSCourseVoice = "west-northwest"
                  if ( $GPSCourse >= 276 and $GPSCourse <= 297 );
                $GPSCourseVoice = "northwest"
                  if ( $GPSCourse >= 298 and $GPSCourse <= 319 );
                $GPSCourseVoice = "north-northwest"
                  if ( $GPSCourse >= 320 and $GPSCourse <= 341 );
                $GPSCourseVoice = "north"
                  if ( $GPSCourse >= 342 and $GPSCourse <= 360 );

                if ( $config_parms{tracking_withname} == 1 ) {
                    $GPSCallsign = $HamName;
                }

                # If It's not the same as the last report, say it.

                if (
                    (
                           ( $GPSCallsign ne $LastGPSCallsign )
                        || ( $GPSDistance ne $LastGPSDistance )
                    )
                    and ( $GPSSpeed ne '0' )
                  )
                {

                    if ( $config_parms{tracking_shortannounce} == 0 ) {
                        $GPSSpeakString =
                          "$GPSCallsign is $GPSDistance miles $GPSLstBr of us, heading $GPSCourseVoice at $GPSSpeed miles an hour.  $GPSSpeakString2";
                    }

                    if ( $config_parms{tracking_shortannounce} == 1 ) {
                        $GPSSpeakString = "$GPSCallsign is $GPSSpeakString2";
                        if ( $GPSSpeakString2 eq '' ) {
                            $GPSSpeakString =
                              "$GPSCallsign is $GPSDistance miles $GPSLstBr of us, heading $GPSCourseVoice at $GPSSpeed miles an hour.";
                        }
                    }

                    print_log "$GPSSpeakString";
                    set $telnet "# $GPSSpeakString" if active $telnet;

                    if (   ( $config_parms{tracking_speakflag} == 1 )
                        || ( $config_parms{tracking_speakflag} == 3 ) )
                    {
                        speak $GPSSpeakString;
                    }

                    if (    $config_parms{tracking_trackself} == 1
                        and $APRSCallsignNoSSID eq $HamCall )
                    {
                        speak $GPSSpeakString;
                    }
                }

                # If the GPS is Stationary, say the following.

                if (
                    (
                           ( $GPSCallsign ne $LastGPSCallsign )
                        || ( $GPSDistance ne $LastGPSDistance )
                    )
                    and ( $GPSSpeed eq '0' )
                  )
                {

                    if ( $config_parms{tracking_shortannounce} == 0 ) {
                        $GPSSpeakString =
                          "$GPSCallsign is parked $GPSDistance miles $GPSLstBr of us.  $GPSSpeakString2";
                    }

                    if ( $config_parms{tracking_shortannounce} == 1 ) {
                        $GPSSpeakString = "$GPSCallsign is $GPSSpeakString2";
                        if ( $GPSSpeakString2 eq '' ) {
                            $GPSSpeakString =
                              "$GPSCallsign is parked $GPSDistance miles $GPSLstBr of us.";
                        }
                    }

                    print_log "$GPSSpeakString";
                    set $telnet "# $GPSSpeakString" if active $telnet;

                    if (   ( $config_parms{tracking_speakflag} == 1 )
                        || ( $config_parms{tracking_speakflag} == 3 ) )
                    {
                        speak $GPSSpeakString;
                    }

                    if (    $config_parms{tracking_trackself} == 1
                        and $APRSCallsignNoSSID eq $HamCall )
                    {
                        speak $GPSSpeakString;
                    }
                }
            }

            # If It's a $GPGGA String,

            if ( substr( $PacketPart, 0, 6 ) eq '$GPGGA' ) {

                if ( $config_parms{tracking_withname} == 1 ) {
                    $GPSCallsign = $HamName;
                }

                if (   ( $GPSCallsign ne $LastGPSCallsign )
                    || ( $GPSDistance ne $LastGPSDistance ) )
                {

                    if ( $config_parms{tracking_shortannounce} == 0 ) {
                        $GPSSpeakString =
                          "$GPSCallsign is $GPSDistance miles $GPSLstBr of us.  $GPSSpeakString2";
                    }

                    if ( $config_parms{tracking_shortannounce} == 1 ) {
                        $GPSSpeakString = "$GPSCallsign is $GPSSpeakString2";
                        if ( $GPSSpeakString2 eq '' ) {
                            $GPSSpeakString =
                              "$GPSCallsign is $GPSDistance miles $GPSLstBr of us.";
                        }
                    }

                    print_log "$GPSSpeakString";
                    set $telnet "# $GPSSpeakString" if active $telnet;

                    if (   ( $config_parms{tracking_speakflag} == 1 )
                        || ( $config_parms{tracking_speakflag} == 3 ) )
                    {
                        speak $GPSSpeakString;
                    }

                    if (    $config_parms{tracking_trackself} == 1
                        and $APRSCallsignNoSSID eq $HamCall )
                    {
                        speak $GPSSpeakString;
                    }
                }
            }

            $LastGPSCallsign = $GPSCallsign;    # Save last GPS rpt
            $LastGPSDistance = $GPSDistance;
            $LastGPSLstBr    = $GPSLstBr;

            # Procedure to Complete a process when my vehicle is close to home
            # But only every 5 minutes, we don't want this process happening every time a position is received.

            if (
                (
                    substr( $RealAPRSCallsign, 0, ( length($HamCall) ) ) eq
                    $HamCall
                )
                and ( $GPSDistance < 0.2 )
                and expired $timer_myvehicle_process)
            {
                print_log "*** MY VEHICLE IS NEARBY ***";
                set $timer_myvehicle_process 5;
            }

            # Log File Procedure for Tracking

            $i = -$GPSLongitude;
            $j = $GPSLatitude;

            my $html = qq[<FORM ACTION='/SET:last_response' target='speech'>\n];
            $html .=
              qq[<tr><td>$Date_Now $Time_Now </td><td>$GPSSpeakString</td>\n];
            $html .= qq[<td><a href="http://www.mapblast.com/myblast/map.mb?];
            $html .= qq|CT=$j\%3A$i\%3A10000">$GPSSpeakString2</a></td>\n|;
            $html .=
              qq[<td><INPUT name=aprs_location_name type='text' SIZE=10 onChange=submit>\n];
            $i = -$i;    # For logging form data in .pos
            $html .=
              qq[<INPUT name=aprs_location_loc type='hidden' value='$j,$i'></td></tr></FORM>\n\n];

            logit "$config_parms{html_dir}/mh/tracking/today.html", $html, 0;
            logit "$config_parms{html_dir}/mh/tracking/week1.html", $html, 0;

            # Add an index entry for the new months entry in aprs/old

            #if ($New_Month) {
            #    my $html = qq[<li><a href=\"$Year_Month_Now.html\">$Year_Month_Now.html</a>\n];
            #    logit "$config_parms{html_dir}/mh/tracking/old/index.html", $html, 1;
            #}
        }    #  **END** GPS Parse

        # Send E-Mail from APRS messages with "EMAIL2"

        if ( ( substr( $MsgLine, 0, 6 ) eq 'EMAIL2' )
            and expired $timer_email_digipeat)
        {
            $APRSFoundAPRS = 1;

            ( $MsgLine,      $MessageAck ) = ( split( '{', $MsgLine ) )[ 0, 1 ];
            ( $CallsignPart, $PacketPart ) = ( split( ':', $MsgLine ) )[ 0, 1 ];
            ( $CallsignPart, $PacketPart ) =
              ( split( '>', $PacketPart ) )[ 0, 1 ];

            # Let $i equals the number of spaces to put before :ack
            $i = ( 9 - length($RealAPRSCallsign) );
            $k = ' ';
            $k = ( $k x $i );

            print_log
              "Email gateway: Callsign=$RealAPRSCallsign, to=$CallsignPart data=$PacketPart\n";
            set $timer_email_digipeat 10;    # ensure it doesn't send twice

            # Send the mail!!
            #if (&net_connect_check) {
            $i =
                "$HamCall>APRSMH,TCPIP*::"
              . $RealAPRSCallsign
              . $k . ":ack"
              . $MessageAck;
            if ( state $enable_transmit eq 'yes' ) { set $tnc_output $i }

            &net_mail_send(
                to      => $CallsignPart,
                subject => "A message from $RealAPRSCallsign (APRS)",
                text =>
                  "The following is an E-Mail sent to you through the $HamCall MisterHouse APRS Radio Gateway\n\n$PacketPart"
            );

            $i =
                "$HamCall>APRSMH,TCPIP*::"
              . $RealAPRSCallsign
              . $k
              . ":Your E-Mail Message has been sent.{7";
            if ( state $enable_transmit eq 'yes' ) { set $tnc_output $i }

            #}
            #else {
            #    $i = $RealAPRSCallsign . $k . ":ack" . $MessageAck;
            #    set $tnc_output $i;
            #    $i = "$HamCall>APRSMH,TCPIP*::" . $RealAPRSCallsign . $k . ":Sorry, Gateway is currently closed.{8";
            #    set $tnc_output $i;
            #}
        }

        # Speak any incoming APRS Bulletins

        if ( substr( $MsgLine, 0, 3 ) eq 'BLN' ) {
            $APRSFoundAPRS = 1;

            ( $CallsignPart, $CallsignPart, $PacketPart ) =
              ( split( ':', $APRSString ) )[ 0, 1, 2 ];
            print_log "Incoming Bulletin from $APRSCallsign: $PacketPart";
        }

        # If It's an APRS Message, either say it or process the voice command:

        if ( substr( $MsgLine, 0, length($HamCall) ) eq $HamCall ) {
            $APRSFoundAPRS = 1;

            ( $MsgLine, $MessageAck ) = ( split( '{', $MsgLine ) )[ 0, 1 ];

            # $CallsignPart simply used as a temp variable in next line
            ( $MessageAck, $CallsignPart ) =
              ( split( '}', $MessageAck ) )[ 0, 1 ];
            ( $CallsignPart, $PacketPart ) = ( split( ':', $MsgLine ) )[ 0, 1 ];

            # Let $i equals the number of spaces to put before :ack
            $i = ( 9 - length($RealAPRSCallsign) );
            $k = ' ';
            $k = ( $k x $i );

            # Check to see if it is a voice command to process from our CALLSIGN:

            if (    substr( $PacketPart, 0, 4 ) eq 'X10-'
                and substr( $RealAPRSCallsign, 0, length($HamCall) ) eq
                $HamCall )
            {

                # Split the line so $PacketPart is actually the message received to process.
                ( $CallsignPart, $PacketPart ) =
                  ( split( '-', $PacketPart ) )[ 0, 1 ];

                run_voice_cmd $PacketPart;
                print_log "X10 received from APRS: $PacketPart";
                speak "X10 received from A P R S: $PacketPart";

                $i =
                    "$HamCall>APRSMH,TCPIP*::"
                  . $RealAPRSCallsign
                  . $k . ":ack"
                  . $MessageAck;
                if ( state $enable_transmit eq 'yes' ) { set $tnc_output $i }
                $i =
                    "$HamCall>APRSMH,TCPIP*::"
                  . $RealAPRSCallsign
                  . $k
                  . ":X-10 Message Received.{9";
                if ( state $enable_transmit eq 'yes' ) { set $tnc_output $i }
                $MsgLine = "";
            }

            # Check to see if its an ack.  If so, don't speak it.

            elsif ( substr( $PacketPart, 0, 3 ) eq 'ack' ) {
                print_log "Acknowledgement received from $RealAPRSCallsign";
            }

            # Respond to ?WX? requests with the temperature.

            elsif ( substr( $PacketPart, 0, 4 ) eq '?WX?' ) {
                $i =
                    "$HamCall>APRSMH,TCPIP*::"
                  . $RealAPRSCallsign
                  . $k . ":ack"
                  . $MessageAck;
                if ( state $enable_transmit eq 'yes' ) { set $tnc_output $i }
                $i =
                    "$HamCall>APRSMH,TCPIP*::"
                  . $RealAPRSCallsign
                  . $k
                  . ": Current Temperature: $CurrentTemp.{4";
                if ( state $enable_transmit eq 'yes' ) { set $tnc_output $i }
                $MsgLine = "";
            }

            # Respond to ?PHONE? requests with last call.

            elsif ( substr( $PacketPart, 0, 7 ) eq '?PHONE?' ) {
                $i =
                    "$HamCall>APRSMH,TCPIP*::"
                  . $RealAPRSCallsign
                  . $k . ":ack"
                  . $MessageAck;
                if ( state $enable_transmit eq 'yes' ) { set $tnc_output $i }
                $i =
                    "$HamCall>APRSMH,TCPIP*::"
                  . $RealAPRSCallsign
                  . $k
                  . ": Last Call: $PhoneName ($PhoneNumber){6";
                if ( state $enable_transmit eq 'yes' ) { set $tnc_output $i }
                $MsgLine = "";
            }

            # If it's not a voice command, than assume it's a standard message:

            else {
                print_log "Incoming Message from $APRSCallsign: $PacketPart";
                speak "Incoming Message from $APRSCallsign. $PacketPart";
                $i =
                    "$HamCall>APRSMH,TCPIP*::"
                  . $RealAPRSCallsign
                  . $k . ":ack"
                  . $MessageAck;
                if ( state $enable_transmit eq 'yes' ) { set $tnc_output $i }
                if ( state $enable_transmit eq 'yes' ) { set $tnc_output $i }
                $MsgLine = "";
            }
        }

        # If it's a U2k or UII Weather Station,
        # AA0SM>APRSW,N0EST,WIDE*,WIDE:_02050122c168s005g010t011r000p000P000h91b10224wU2K
        # N0QV>APRS,TCPIP*,qAC,FIRST:@131334z4407.94N/09359.39W_000/013g022t031r000p009P002h00b10143
        # At miles of us, temperature is 31 degrees.  Winnd is out of the north at 4N/ miles an hour.

        if (
            ( substr( $APRSString, ( $APRSStringLength - 4 ), 2 ) eq 'dU' )
            || (
                substr( $APRSString, ( $APRSStringLength - 6 ), 6 ) eq
                'dU2kFM' )
            || ( substr( $APRSString, ( $APRSStringLength - 4 ), 2 ) eq 'wU' )
            || ( substr( $APRSString, ( $APRSStringLength - 4 ), 4 ) eq 'DsVP' )
            || (    substr( $PacketPart, 38, 1 ) eq 't'
                and substr( $PacketPart, 42, 1 ) eq 'r' )
            || ( substr( $APRSString, ( $APRSStringLength - 2 ), 2 ) eq 'WD' )
            || ( substr( $APRSString, ( $APRSStringLength - 3 ), 2 ) eq 'WX' )
            || ( substr( $APRSString, ( $APRSStringLength - 5 ), 2 ) eq 'WD' )
          )
        {
            $APRSFoundAPRS      = 1;
            $WXCallsign         = $APRSCallsign;    # Reset Variables
            $WXTime             = "";
            $WXLatitudeDegrees  = "";
            $WXLatitudeMinutes  = "";
            $WXLongitudeDegrees = "";
            $WXLongitudeMinutes = "";
            $WXLatitude         = "";
            $WXLongitude        = "";
            $WXDistance         = "";
            $WXTemp             = "";
            $WXWindDir          = "";
            $WXWindSpeed        = "";
            $WXWindChill        = "";
            $WXHrPrecip         = "";
            $WX24HrPrecip       = "";
            $WXLstBr            = "";
            $WXLstBrLat         = "";
            $WXLstBrLon         = "";
            $WXCompPlace        = "";
            $WXCompLat          = "";
            $WXCompLong         = "";
            $WXCompDist         = "9999";
            $WXSpeakString2     = "";
            $WXTempCompPlace    = "";
            $WXTempCompDist     = "";

            # If It's a DOS Weather String,

            if (
                ( substr( $APRSString, ( $APRSStringLength - 4 ), 2 ) eq 'dU' )
                || (
                    substr( $APRSString, ( $APRSStringLength - 6 ), 6 ) eq
                    'dU2kFM' )
              )
            {

                $WXTime = ( substr( $PacketPart, 3, 4 ) );   # Time of WX Report
                $WXWindDir = ( substr( $PacketPart, 27, 3 ) );  # Wind Direction
                $WXWindSpeed = ( substr( $PacketPart, 31, 3 ) );    # Wind Speed

                # Get rid of those damn 0's in the Speed
                if ( substr( $WXWindSpeed, 0, 2 ) eq '00' ) {
                    $WXWindSpeed = ( substr( $WXWindSpeed, 2, 1 ) );
                }
                if ( $WXWindSpeed ne '0' ) {    # Except if wind speed IS 0
                    if ( substr( $WXWindSpeed, 0, 1 ) eq '0' ) {
                        $WXWindSpeed = ( substr( $WXWindSpeed, 1, 2 ) );
                    }
                }

                $WXLatitudeDegrees = ( substr( $PacketPart, 8,  2 ) );
                $WXLatitudeMinutes = ( substr( $PacketPart, 10, 5 ) );
                $WXLatitude =
                  ( $WXLatitudeDegrees + ( $WXLatitudeMinutes / 60 ) );
                $WXLongitudeDegrees = ( substr( $PacketPart, 17, 3 ) );
                $WXLongitudeMinutes = ( substr( $PacketPart, 20, 5 ) );
                $WXLongitude =
                  ( $WXLongitudeDegrees + ( $WXLongitudeMinutes / 60 ) );

                $WXDistance = &great_circle_distance(
                    $WXLatitude, $WXLongitude,
                    abs $config_parms{latitude},
                    abs $config_parms{longitude}
                );
                $WXDistance = round( $WXDistance, 1 );

                # Calculate if station is north/west/east/south of ours
                $WXLstBrLat = ( abs $config_parms{latitude} - $WXLatitude );
                $WXLstBrLon = ( abs $config_parms{longitude} - $WXLongitude );
                if ( $WXLstBrLat < 0 and $WXLstBrLon < 0 ) {
                    $WXLstBr = 'northwest';
                }
                if ( $WXLstBrLat > 0 and $WXLstBrLon < 0 ) {
                    $WXLstBr = 'southwest';
                }
                if ( $WXLstBrLat < 0 and $WXLstBrLon > 0 ) {
                    $WXLstBr = 'northeast';
                }
                if ( $WXLstBrLat > 0 and $WXLstBrLon > 0 ) {
                    $WXLstBr = 'southeast';
                }
                if ( $WXLstBrLat <= 0 and ( $WXLstBrLon * 2 ) < $WXLstBrLat ) {
                    $WXLstBr = 'north';
                }
                if ( $WXLstBrLat >= 0 and ( $WXLstBrLon * 2 ) < $WXLstBrLat ) {
                    $WXLstBr = 'south';
                }
                if ( $WXLstBrLon <= 0 and ( $WXLstBrLat * 2 ) < $WXLstBrLon ) {
                    $WXLstBr = 'west';
                }
                if ( $WXLstBrLon >= 0 and ( $WXLstBrLat * 2 ) < $WXLstBrLon ) {
                    $WXLstBr = 'east';
                }
            }

            # For New Windows UII/U2000 String Only

            if (
                ( substr( $APRSString, ( $APRSStringLength - 4 ), 2 ) eq 'wU' )
                || (
                    substr( $APRSString, ( $APRSStringLength - 2 ), 2 ) eq
                    'WD' )
                || (
                    substr( $APRSString, ( $APRSStringLength - 5 ), 2 ) eq
                    'WD' )
                || (
                    substr( $APRSString, ( $APRSStringLength - 3 ), 2 ) eq
                    'WX' )
                || (    substr( $PacketPart, 38, 1 ) eq 't'
                    and substr( $PacketPart, 42, 1 ) eq 'r' )
                || (
                    substr( $APRSString, ( $APRSStringLength - 4 ), 4 ) eq
                    'DsVP' )
              )
            {

                $WXTime = ( substr( $PacketPart, 5, 4 ) );   # Time of WX Report
                $WXWindDir = ( substr( $PacketPart, 10, 3 ) );  # Wind Direction
                $WXWindSpeed = ( substr( $PacketPart, 14, 3 ) );    # Wind Speed

                # Get rid of those damn 0's in the Speed
                if ( substr( $WXWindSpeed, 0, 2 ) eq '00' ) {
                    $WXWindSpeed = ( substr( $WXWindSpeed, 2, 1 ) );
                }
                if ( $WXWindSpeed ne '0' ) {    # Except if wind speed IS 0
                    if ( substr( $WXWindSpeed, 0, 1 ) eq '0' ) {
                        $WXWindSpeed = ( substr( $WXWindSpeed, 1, 2 ) );
                    }
                }
            }

            # All Weather Stations Process the Following

            $WXWindDirVoice = "north"
              if ( $WXWindDir >= 0 and $WXWindDir <= 11 );
            $WXWindDirVoice = "north-northeast"
              if ( $WXWindDir >= 12 and $WXWindDir <= 33 );
            $WXWindDirVoice = "northeast"
              if ( $WXWindDir >= 34 and $WXWindDir <= 55 );
            $WXWindDirVoice = "east-northeast"
              if ( $WXWindDir >= 56 and $WXWindDir <= 77 );
            $WXWindDirVoice = "east"
              if ( $WXWindDir >= 78 and $WXWindDir <= 99 );
            $WXWindDirVoice = "east-southeast"
              if ( $WXWindDir >= 100 and $WXWindDir <= 121 );
            $WXWindDirVoice = "southeast"
              if ( $WXWindDir >= 122 and $WXWindDir <= 143 );
            $WXWindDirVoice = "south-southeast"
              if ( $WXWindDir >= 144 and $WXWindDir <= 165 );
            $WXWindDirVoice = "south"
              if ( $WXWindDir >= 166 and $WXWindDir <= 187 );
            $WXWindDirVoice = "south-southwest"
              if ( $WXWindDir >= 188 and $WXWindDir <= 209 );
            $WXWindDirVoice = "southwest"
              if ( $WXWindDir >= 210 and $WXWindDir <= 231 );
            $WXWindDirVoice = "west-southwest"
              if ( $WXWindDir >= 232 and $WXWindDir <= 253 );
            $WXWindDirVoice = "west"
              if ( $WXWindDir >= 254 and $WXWindDir <= 275 );
            $WXWindDirVoice = "west-northwest"
              if ( $WXWindDir >= 276 and $WXWindDir <= 297 );
            $WXWindDirVoice = "northwest"
              if ( $WXWindDir >= 298 and $WXWindDir <= 319 );
            $WXWindDirVoice = "north-northwest"
              if ( $WXWindDir >= 320 and $WXWindDir <= 341 );
            $WXWindDirVoice = "north"
              if ( $WXWindDir >= 342 and $WXWindDir <= 360 );

            # Calculate bearing from the Position file
            foreach $WXTempCompLine (@gpscomplines) {
                ( $WXTempCompPlace, $WXTempCompLat, $WXTempCompLong ) =
                  ( split( ',', $WXTempCompLine ) )[ 0, 1, 2 ];

                # Calculate distance station is away from pos file
                $WXTempCompDist = &great_circle_distance(
                    $WXLatitude, $WXLongitude,
                    abs $WXTempCompLat,
                    abs $WXTempCompLong
                );
                $WXTempCompDist = round( $WXTempCompDist, 1 );

                if ( $WXTempCompDist < 150 and $WXTempCompDist < $WXCompDist ) {
                    $WXCompPlace = $WXTempCompPlace;
                    $WXCompDist  = $WXTempCompDist;
                    $WXCompLat   = $WXTempCompLat;
                    $WXCompLong  = $WXTempCompLong;
                }
            }

            # Calculate if station is north/west/east/south of POSFILE
            $WXCompLstBrLat = ( $WXCompLat - $WXLatitude );
            $WXCompLstBrLon = ( $WXCompLong - $WXLongitude );
            if ( $WXCompLstBrLat < 0 and $WXCompLstBrLon < 0 ) {
                $WXCompLstBr = 'northwest';
            }
            if ( $WXCompLstBrLat > 0 and $WXCompLstBrLon < 0 ) {
                $WXCompLstBr = 'southwest';
            }
            if ( $WXCompLstBrLat < 0 and $WXCompLstBrLon > 0 ) {
                $WXCompLstBr = 'northeast';
            }
            if ( $WXCompLstBrLat > 0 and $WXCompLstBrLon > 0 ) {
                $WXCompLstBr = 'southeast';
            }
            if ( $WXCompLstBrLat <= 0
                and ( $WXCompLstBrLon * 2 ) < $WXCompLstBrLat )
            {
                $WXCompLstBr = 'north';
            }
            if ( $WXCompLstBrLat >= 0
                and ( $WXCompLstBrLon * 2 ) < $WXCompLstBrLat )
            {
                $WXCompLstBr = 'south';
            }
            if ( $WXCompLstBrLon <= 0
                and ( $WXCompLstBrLat * 2 ) < $WXCompLstBrLon )
            {
                $WXCompLstBr = 'west';
            }
            if ( $WXCompLstBrLon >= 0
                and ( $WXCompLstBrLat * 2 ) < $WXCompLstBrLon )
            {
                $WXCompLstBr = 'east';
            }

            # Add bearing from station in position file IF it's a new position report
            if (
                (
                       ( $WXCallsign ne $LastWXCallsign )
                    || ( $WXDistance ne $LastWXDistance )
                )
                and ( $GPSCompDist ne '9999' )
              )
            {
                $WXSpeakString2 =
                  "Station is located $WXCompDist miles $WXCompLstBr of $WXCompPlace.";
            }

            if ( substr( $PacketPart, 35, 1 ) eq 'T' ) {    # If a traditional,
                $WXTemp = ( substr( $PacketPart, 36, 3 ) );

                # Get rid of those damn 0's in the Temperature
                if ( substr( $WXTemp, 0, 2 ) eq '00' ) {
                    $WXTemp = ( substr( $WXTemp, 2, 1 ) );
                }
                if ( $WXTemp ne '0' ) {    # Except if temp IS 0
                    if ( substr( $WXTemp, 0, 1 ) eq '0' ) {
                        $WXTemp = ( substr( $WXTemp, 1, 2 ) );
                    }
                }

                # Calculate Wind Chill if temp is less than 45 degrees
                if ( $WXTemp <= 45 ) {
                    $WXWindChill =
                      .0817 *
                      ( 3.71 * sqrt($WXWindSpeed) + 5.81 - .25 * $WXWindSpeed )
                      * ( $WXTemp - 91.4 ) + 91.4;
                    $WXWindChill = round( $WXWindChill, 0 );
                    if ( $WXWindSpeed <= 5 ) { $WXWindChill = $WXTemp }
                }

                # If Temperature is above freezing, make it equal.
                if ( $WXTemp >= 46 ) {
                    $WXWindChill = $WXTemp;
                }

                # Add Readings for Last Hour Precip and Last 24 Hour Precip
                $WXHrPrecip = ( substr( $PacketPart, 41, 3 ) );

                # Get rid of those damn 0's in the Precip
                if ( substr( $WXHrPrecip, 0, 2 ) eq '00' ) {
                    $WXHrPrecip = ( substr( $WXHrPrecip, 2, 1 ) );
                }
                if ( $WXHrPrecip ne '0' ) {    # Except if precip IS 0
                    if ( substr( $WXHrPrecip, 0, 1 ) eq '0' ) {
                        $WXHrPrecip = ( substr( $WXHrPrecip, 1, 2 ) );
                    }
                }

                # Divide Precip by 10
                $WXHrPrecip = $WXHrPrecip / 10;
                $WX24HrPrecip = ( substr( $PacketPart, 45, 3 ) );

                # Get rid of those damn 0's in the 24 hr Precip
                if ( substr( $WX24HrPrecip, 0, 2 ) eq '00' ) {
                    $WX24HrPrecip = ( substr( $WX24HrPrecip, 2, 1 ) );
                }
                if ( $WX24HrPrecip ne '0' ) {    # Except if precip IS 0
                    if ( substr( $WX24HrPrecip, 0, 1 ) eq '0' ) {
                        $WX24HrPrecip = ( substr( $WX24HrPrecip, 1, 2 ) );
                    }
                }

                # Divide Precip by 10
                $WX24HrPrecip = $WX24HrPrecip / 10;

                # If It's not the same as the last report, say it.

                if (
                    (
                           ( $WXCallsign ne $LastWXCallsign )
                        || ( $WXDistance ne $LastWXDistance )
                        || ( $WXTemp ne $LastWXTemp )
                    )
                    and ( $WXWindSpeed ne '0' )
                  )
                {
                    $WXSpeakString =
                      "At $WXDistance miles $WXLstBr of us, temperature is $WXTemp degrees.  Winnd is out of the $WXWindDirVoice at $WXWindSpeed miles an hour.";
                    if ( $WXTemp <= 45 and $WXTemp ne $WXWindChill ) {
                        $WXSpeakString =
                          $WXSpeakString . "  The winnd chill is $WXWindChill.";
                    }
                    if ( $WXHrPrecip != 0 ) {
                        $WXSpeakString = $WXSpeakString
                          . "  $WXHrPrecip inches of rain in the last hour.";
                    }
                    $WXSpeakString = $WXSpeakString . "  $WXSpeakString2";

                    print_log "$WXSpeakString";
                    set $telnet "# $WXSpeakString" if active $telnet;

                    if (   ( $config_parms{tracking_speakflag} == 2 )
                        || ( $config_parms{tracking_speakflag} == 3 ) )
                    {
                        speak $WXSpeakString;
                    }
                }

                # If the wind is calm, say the following.

                if (
                    (
                           ( $WXCallsign ne $LastWXCallsign )
                        || ( $WXDistance ne $LastWXDistance )
                        || ( $WXTemp ne $LastWXTemp )
                    )
                    and ( $WXWindSpeed eq '0' )
                  )
                {
                    $WXSpeakString =
                      "At $WXDistance miles $WXLstBr of us, temperature is $WXTemp degrees.  Winnd is calm.";
                    if ( $WXHrPrecip != 0 ) {
                        $WXSpeakString = $WXSpeakString
                          . "  $WXHrPrecip inches of rain in the last hour.";
                    }
                    $WXSpeakString = $WXSpeakString . "  $WXSpeakString2";

                    print_log "$WXSpeakString";
                    set $telnet "# $WXSpeakString" if active $telnet;

                    if (   ( $config_parms{tracking_speakflag} == 2 )
                        || ( $config_parms{tracking_speakflag} == 3 ) )
                    {
                        speak $WXSpeakString;
                    }
                }

                $LastWXCallsign   = $WXCallsign;  # Save last WX rpt information
                $LastWXDistance   = $WXDistance;
                $LastWXTemp       = $WXTemp;
                $LastWXWindDir    = $WXWindDir;
                $LastWXWindSpeed  = $WXWindSpeed;
                $LastWXWindChill  = $WXWindChill;
                $LastWXHrPrecip   = $WXHrPrecip;
                $LastWX24HrPrecip = $WX24HrPrecip;
            }

            elsif ( substr( $PacketPart, 38, 1 ) eq 't' ) {   # If a new format,
                $WXTemp = ( substr( $PacketPart, 39, 3 ) );

                # Get rid of those damn 0's in the Temperature
                if ( substr( $WXTemp, 0, 2 ) eq '00' ) {
                    $WXTemp = ( substr( $WXTemp, 2, 1 ) );
                }
                if ( $WXTemp ne '0' ) {    # Except if temp IS 0
                    if ( substr( $WXTemp, 0, 1 ) eq '0' ) {
                        $WXTemp = ( substr( $WXTemp, 1, 2 ) );
                    }
                }

                # Calculate Wind Chill if temp is less than 45 degrees
                if ( $WXTemp <= 45 ) {
                    $WXWindChill =
                      .0817 *
                      ( 3.71 * sqrt($WXWindSpeed) + 5.81 - .25 * $WXWindSpeed )
                      * ( $WXTemp - 91.4 ) + 91.4;
                    $WXWindChill = round( $WXWindChill, 0 );
                    if ( $WXWindSpeed <= 5 ) { $WXWindChill = $WXTemp }
                }

                # If Temperature is above freezing, make it equal.
                if ( $WXTemp >= 46 ) {
                    $WXWindChill = $WXTemp;
                }

                # Add Readings for Last Hour Precip and Last 24 Hour Precip
                $WXHrPrecip = ( substr( $PacketPart, 43, 3 ) );

                # Get rid of those damn 0's in the Precip
                if ( substr( $WXHrPrecip, 0, 2 ) eq '00' ) {
                    $WXHrPrecip = ( substr( $WXHrPrecip, 2, 1 ) );
                }
                if ( $WXHrPrecip ne '0' ) {    # Except if precip IS 0
                    if ( substr( $WXHrPrecip, 0, 1 ) eq '0' ) {
                        $WXHrPrecip = ( substr( $WXHrPrecip, 1, 2 ) );
                    }
                }

                # Divide Precip by 10
                $WXHrPrecip = $WXHrPrecip / 10;
                $WX24HrPrecip = ( substr( $PacketPart, 47, 3 ) );

                # Get rid of those damn 0's in the 24 hr Precip
                if ( substr( $WX24HrPrecip, 0, 2 ) eq '00' ) {
                    $WX24HrPrecip = ( substr( $WX24HrPrecip, 2, 1 ) );
                }
                if ( $WX24HrPrecip ne '0' ) {    # Except if precip IS 0
                    if ( substr( $WX24HrPrecip, 0, 1 ) eq '0' ) {
                        $WX24HrPrecip = ( substr( $WX24HrPrecip, 1, 2 ) );
                    }
                }

                # Divide Precip by 10
                $WX24HrPrecip = $WX24HrPrecip / 10;

                # If It's not the same as the last report, say it.

                if (
                    (
                           ( $WXCallsign ne $LastWXCallsign )
                        || ( $WXDistance ne $LastWXDistance )
                        || ( $WXTemp ne $LastWXTemp )
                    )
                    and ( $WXWindSpeed ne '0' )
                  )
                {
                    $WXSpeakString =
                      "At $WXDistance miles $WXLstBr of us, temperature is $WXTemp degrees.  Winnd is out of the $WXWindDirVoice at $WXWindSpeed miles an hour.";
                    if ( $WXTemp <= 45 and $WXTemp ne $WXWindChill ) {
                        $WXSpeakString =
                          $WXSpeakString . "  The winnd chill is $WXWindChill.";
                    }
                    if ( $WXHrPrecip != 0 ) {
                        $WXSpeakString = $WXSpeakString
                          . "  $WXHrPrecip inches of rain in the last hour.";
                    }
                    if ( $WX24HrPrecip != 0 ) {
                        $WXSpeakString = $WXSpeakString
                          . "  $WX24HrPrecip inches of rain total today.";
                    }
                    $WXSpeakString = $WXSpeakString . "  $WXSpeakString2";

                    print_log "$WXSpeakString";
                    set $telnet "# $WXSpeakString" if active $telnet;

                    if (   ( $config_parms{tracking_speakflag} == 2 )
                        || ( $config_parms{tracking_speakflag} == 3 ) )
                    {
                        speak $WXSpeakString;
                    }
                }

                # If the wind is calm, say the following.

                if (
                    (
                           ( $WXCallsign ne $LastWXCallsign )
                        || ( $WXDistance ne $LastWXDistance )
                        || ( $WXTemp ne $LastWXTemp )
                    )
                    and ( $WXWindSpeed eq '0' )
                  )
                {
                    $WXSpeakString =
                      "At $WXDistance miles $WXLstBr of us, temperature is $WXTemp degrees.  Winnd is calm.";
                    if ( $WXHrPrecip != 0 ) {
                        $WXSpeakString = $WXSpeakString
                          . "  $WXHrPrecip inches of rain in the last hour.";
                    }
                    if ( $WX24HrPrecip != 0 ) {
                        $WXSpeakString = $WXSpeakString
                          . "  $WX24HrPrecip inches of rain total today.";
                    }
                    $WXSpeakString = $WXSpeakString . "  $WXSpeakString2";

                    print_log "$WXSpeakString";
                    set $telnet "# $WXSpeakString" if active $telnet;

                    if (   ( $config_parms{tracking_speakflag} == 2 )
                        || ( $config_parms{tracking_speakflag} == 3 ) )
                    {
                        speak $WXSpeakString;
                    }
                }

                $LastWXCallsign   = $WXCallsign;  # Save last WX rpt information
                $LastWXDistance   = $WXDistance;
                $LastWXTemp       = $WXTemp;
                $LastWXWindDir    = $WXWindDir;
                $LastWXWindSpeed  = $WXWindSpeed;
                $LastWXWindChill  = $WXWindChill;
                $LastWXHrPrecip   = $WXHrPrecip;
                $LastWX24HrPrecip = $WX24HrPrecip;

            }

            elsif ( substr( $PacketPart, 21, 1 ) eq 't' ) { # If WINDOWS format,
                $WXDistance = 999.9;                        # Because we don't
                                                            # have the position
                $WXTemp = ( substr( $PacketPart, 22, 3 ) );

                # Get rid of those damn 0's in the Temperature
                if ( substr( $WXTemp, 0, 2 ) eq '00' ) {
                    $WXTemp = ( substr( $WXTemp, 2, 1 ) );
                }
                if ( $WXTemp ne '0' ) {    # Except if temp IS 0
                    if ( substr( $WXTemp, 0, 1 ) eq '0' ) {
                        $WXTemp = ( substr( $WXTemp, 1, 2 ) );
                    }
                }

                # Calculate Wind Chill if temp is less than 45 degrees
                if ( $WXTemp <= 45 ) {
                    $WXWindChill =
                      .0817 *
                      ( 3.71 * sqrt($WXWindSpeed) + 5.81 - .25 * $WXWindSpeed )
                      * ( $WXTemp - 91.4 ) + 91.4;
                    $WXWindChill = round( $WXWindChill, 0 );
                    if ( $WXWindSpeed <= 5 ) { $WXWindChill = $WXTemp }
                }

                # If Temperature is above freezing, make it equal.
                if ( $WXTemp >= 45 ) {
                    $WXWindChill = $WXTemp;
                }

                # Add Readings for Last Hour Precip and Last 24 Hour Precip
                $WXHrPrecip = ( substr( $PacketPart, 26, 3 ) );

                # Get rid of those damn 0's in the Precip
                if ( substr( $WXHrPrecip, 0, 2 ) eq '00' ) {
                    $WXHrPrecip = ( substr( $WXHrPrecip, 2, 1 ) );
                }
                if ( $WXHrPrecip ne '0' ) {    # Except if precip IS 0
                    if ( substr( $WXHrPrecip, 0, 1 ) eq '0' ) {
                        $WXHrPrecip = ( substr( $WXHrPrecip, 1, 2 ) );
                    }
                }

                # Divide Precip by 10
                $WXHrPrecip = $WXHrPrecip / 10;
                $WX24HrPrecip = ( substr( $PacketPart, 30, 3 ) );

                # Get rid of those damn 0's in the 24 hr Precip
                if ( substr( $WX24HrPrecip, 0, 2 ) eq '00' ) {
                    $WX24HrPrecip = ( substr( $WX24HrPrecip, 2, 1 ) );
                }
                if ( $WX24HrPrecip ne '0' ) {    # Except if precip IS 0
                    if ( substr( $WX24HrPrecip, 0, 1 ) eq '0' ) {
                        $WX24HrPrecip = ( substr( $WX24HrPrecip, 1, 2 ) );
                    }
                }

                # Divide Precip by 10
                $WX24HrPrecip = $WX24HrPrecip / 10;

                # If It's not the same as the last report, say it.

                if (
                    (
                           ( $WXCallsign ne $LastWXCallsign )
                        || ( $WXDistance ne $LastWXDistance )
                        || ( $WXTemp ne $LastWXTemp )
                    )
                    and ( $WXWindSpeed ne '0' )
                  )
                {
                    $WXSpeakString =
                      "$APRSCallsign reports temperature of $WXTemp degrees.  Winnd is out of the $WXWindDirVoice at $WXWindSpeed miles an hour.";
                    if ( $WXTemp <= 45 and $WXTemp ne $WXWindChill ) {
                        $WXSpeakString =
                          $WXSpeakString . "  The winnd chill is $WXWindChill.";
                    }
                    if ( $WXHrPrecip != 0 ) {
                        $WXSpeakString = $WXSpeakString
                          . "  $WXHrPrecip inches of rain in the last hour.";
                    }
                    if ( $WX24HrPrecip != 0 ) {
                        $WXSpeakString = $WXSpeakString
                          . "  $WX24HrPrecip inches of rain total today.";
                    }

                    print_log "$WXSpeakString";
                    set $telnet "# $WXSpeakString" if active $telnet;

                    if (   ( $config_parms{tracking_speakflag} == 2 )
                        || ( $config_parms{tracking_speakflag} == 3 ) )
                    {
                        speak $WXSpeakString;
                    }
                }

                # If the wind is calm, say the following.

                if (
                    (
                           ( $WXCallsign ne $LastWXCallsign )
                        || ( $WXDistance ne $LastWXDistance )
                        || ( $WXTemp ne $LastWXTemp )
                    )
                    and ( $WXWindSpeed eq '0' )
                  )
                {
                    $WXSpeakString =
                      "$APRSCallsign reports temperature of $WXTemp degrees.  Winnd is calm.";
                    if ( $WXHrPrecip != 0 ) {
                        $WXSpeakString = $WXSpeakString
                          . "  $WXHrPrecip inches of rain in the last hour.";
                    }
                    if ( $WX24HrPrecip != 0 ) {
                        $WXSpeakString = $WXSpeakString
                          . "  $WX24HrPrecip inches of rain total today.";
                    }

                    print_log "$WXSpeakString";
                    set $telnet "# $WXSpeakString" if active $telnet;

                    if (   ( $config_parms{tracking_speakflag} == 2 )
                        || ( $config_parms{tracking_speakflag} == 3 ) )
                    {
                        speak $WXSpeakString;
                    }
                }

                $LastWXCallsign   = $WXCallsign;  # Save last WX rpt information
                $LastWXDistance   = $WXDistance;
                $LastWXTemp       = $WXTemp;
                $LastWXWindDir    = $WXWindDir;
                $LastWXWindSpeed  = $WXWindSpeed;
                $LastWXWindChill  = $WXWindChill;
                $LastWXHrPrecip   = $WXHrPrecip;
                $LastWX24HrPrecip = $WX24HrPrecip;
            }

            else {
                print_log "*** Unknown Weather Station Format Detected.";
            }

            if ( $CurrentTempDist >= $WXDistance ) {    # If a closer rpt,
                $CurrentTempDist   = $WXDistance;       # change the current
                $CurrentTemp       = $WXTemp;           # temp variable.
                $CurrentChill      = $WXWindChill;
                $CurrentHrPrecip   = $WXHrPrecip;
                $Current24HrPrecip = $WX24HrPrecip;
            }

            if ( $CurrentTempDist eq '' ) {             # If 1st report
                $CurrentTempDist   = $WXDistance;       # of the day, change
                $CurrentTemp       = $WXTemp;           # the temp variable.
                $CurrentChill      = $WXWindChill;
                $CurrentHrPrecip   = $WXHrPrecip;
                $Current24HrPrecip = $WX24HrPrecip;
            }
        }

        #elsif (substr($APRSString, $i, 1) eq '*') {     # Else if we find a "*",
        #    $APRSPacketDigi = 1;                        # It got digipeated
        #    print_log "Packet was Digipeated.";
        #}
        #else
        #{
        #}

    }
}

sub great_circle_distance {
    my ( $lat1, $lon1, $lat2, $lon2 ) = map { &degrees_to_radians($_) } @_;

    #   my $radius = 6367; # km
    my $radius = 3956;                              # miles
    my $d = ( sin( ( $lat2 - $lat1 ) / 2 ) )**2 +
      cos($lat1) * cos($lat2) * ( sin( ( $lon2 - $lon1 ) / 2 ) )**2;
    $d = $radius * 2 * atan2( sqrt($d), sqrt( 1 - $d ) );
    return round( $d, 1 );
}

#EGIN { $::pi = 4 * atan2(1,1); }
sub degrees_to_radians {
    return $_[0] * 3.14159265 / 180.0;
}
