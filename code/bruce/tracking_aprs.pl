# Category=Vehicles

#@ Code for tracking cars with GPS sensors and aprs enabled ham radios.
#@ Example hardware is listed <a href=http://www.gpstracker.com>here</a>

=begin comment

This is a subset of what is in Brian's tracking.pl #
code.  It only does GPS tracking.                  #
To enable, use these mh.ini parms:

serial_tnc_port=COM7
serial_tnc_baudrate=9600
serial_tnc_handshake=dtr

An example of my tracking log can be found here:

 http://misterhouse.net:8080/aprs

You need a ham radio licence which you can get after passing
a test (pretty easy if you have an engineering or technical
background).  They give the test 1->4 times a year in the bigger cities.


mh.in parms:

tracking_dir=/misterhouse/web/aprs      @ Where to put the tracking data
tracking_callsign=                      @ Ham Callsign
tracking_speakflag=0                    #  0 = No Speaking
                                        #  1 = Speak GPS Reports Only
                                        #  2 = Speak WX Reports Only
                                        #  3 = All Speaking

=cut

$monitor_vehicles = new Generic_Item;    # Can be used by other code

my ( @gps_complines, %gps_names, $gps_tracked );

#&tk_radiobutton('APRS Speak', \$config_parms{tracking_speakflag}, ['none', 'family', 'GPS', 'WX', 'all']);
#&tk_radiobutton('APRS Print', \$config_parms{tracking_printflag}, ['none', 'family', 'GPS', 'WX', 'all']);

# Define TNC Output strings
$tnc_output = new Serial_Item( 'CONV', 'converse', 'serial_tnc' );
$tnc_output->add( '?WX?', 'wxquery', 'serial_tnc' );

#$tnc_output-> add             (sprintf("=%2d%05.02fN/%2d%05.02fW- *** %s MisterHouse Tracking System, bruce\@misterhouse.net ***",
$tnc_output->add(
    sprintf(
        "=%2d%05.02fN/%03d%05.02fW- *** %s MisterHouse Tracking System ***",
        int( $config_parms{latitude} ),
        abs( $config_parms{latitude} - int( $config_parms{latitude} ) ) * 60,
        int( $config_parms{longitude} ),
        abs( $config_parms{longitude} - int( $config_parms{longitude} ) ) * 60,
        $config_parms{tracking_callsign}
    ),
    'position',
    'serial_tnc'
);

$timer_tracking_email = new Timer;

# Re-read tracking.pos and tracking.names on Reload, if changed
&reload_aprs_data if $Reread;

# noloop=start      Need to call this out-of-the-loop, so we can create $gps_tracked for voice_cmds
&reload_aprs_data;

# noloop=stop

sub reload_aprs_data {
    if ( $Reload or file_change "$config_parms{data_dir}/tracking.pos" ) {
        print_log "Reloading tracking.pos";
        open( GPS, "$config_parms{data_dir}/tracking.pos" );
        @gps_complines = <GPS>;
        close GPS;
    }
    $gps_tracked = '';
    if ( $Reload or file_change "$config_parms{data_dir}/tracking.names" ) {
        print_log "Reloading tracking.names";
        open( GPS, "$config_parms{data_dir}/tracking.names" );
        while (<GPS>) {
            next if /^\#/;    # Allow for comments
            chomp;
            my ( $callsign, $name, $group ) = split( /, */, $_ );
            $name                        = lc $name;
            $gps_names{$callsign}{name}  = $name;
            $gps_names{$callsign}{group} = $group;
            $gps_names{$name}{callsign} = $callsign if $name;
            $gps_tracked .= lc $name . ',' if $group and $group eq 'family';
        }
        close GPS;
    }

    #   print "dbx Tracked aprs names: $gps_tracked\n";
}

# Set TNC to Converse and send position on Startup
#if ($Startup or $Reload) {
if ($Startup) {

    # These transmits something on startup ... not just inits the modem ??

    set $tnc_output 'MRPT OFF';        # Do NOT Show Digipeater Path
    set $tnc_output 'HEADERLN OFF';    # Keep Header and data on the same line

    set $tnc_output 'converse';
    print_log
      "Tracking Interface has been Initialized...Callsign $config_parms{tracking_callsign}";
}

# Send position 4 times a day (server flushes data every 6 hours)
# Tracked at: http://map.aprs.net:8000/kc0eqv-1
# Tracked at: http://www.findu.com/cgi-bin/find.cgi?kc0eqv-1
$v_send_position = new Voice_Cmd("Send my APRS Position");
set_info $v_send_position
  "Send the house latitude/longitude: $config_parms{latitude}, $config_parms{longitude}."
  . "Not all that useful, since the house does not move too often :)";

if ( $state = said $v_send_position or time_cron('0 2,8,14,20 * * *') ) {
    set $tnc_output 'position';

    #   speak "Position sent for $config_parms{tracking_callsign}";
    print_log "aprs position string: $tnc_output->{id_by_state}{position}";
}
$v_wx_query = new Voice_Cmd("APRS Weather Query");
$v_wx_query->set_info(
    'Send out a weather query to nearby APRS weather stations');
if ( $state = said $v_wx_query) {
    set $tnc_output 'wxquery';
    respond "Weather query requested";
}

$v_send_test_email = new Voice_Cmd("Send APRS email to myself");
set_info $v_send_test_email
  'Use an APRS internet gateway to send a test email from my house,'
  . 'thru the ham radio, to an Inetnet gateway receiver, and thru the internet back to my house.  Pretty useful eh?';
if ( $state = said $v_send_test_email) {
    print_log
      "aprs mail sent to $config_parms{net_mail_user}\@$config_parms{net_mail_server}";
    set $tnc_output
      ":EMAIL    :$config_parms{net_mail_user}\@$config_parms{net_mail_server} Test E-Mail - $Time";
    respond "Email sent";
}

$v_send_test_icq = new Voice_Cmd("Send APRS ICQ msg to myself");
$v_send_test_icq->set_info(
    'Send a test ICQ message, via a ham radio APRS connection');
if ( $state = said $v_send_test_icq) {
    set $tnc_output ":ICQSERVE :967794 Test Msg - $Time";
    respond "ICQ message sent";
}

# Process incoming APRS data
my %callsign_data;
if ( my $APRSString = said $tnc_output) {

    print_log "TRACK: $APRSString"
      if $config_parms{tracking_printflag} eq 'all';

    # Decode the Callsign and different parts from the Packet
    #TRACK: KC0EQV>APRS:!4404.87N/09230.26W>
    #TRACK: KC0EQV>APRS:$GPRMC,210314,A,4404.8861,N,09230.2205,W,000.0,206.4,161099,001.2,E*6A
    #TRACK: KC0FOW-9>GPSLK:$GPRMC,195439,A,4403.907,N,09230.074,W,000.0,258.3,161099,001.2,E*68
    #TRACK: N0EST-9>GPSMV:$GPRMC,203921,A,4400.2593,N,09228.6660,W,0.000,0.0,161099,1.5,E*67
    #TRACK: N0EST>APW226:=4405.70NN09229.60W#PHG6260/Rochester MN W/R/T -MNOLMROCHESTE-226-<530>
    #TRACK: AA0SM>APW227:=4405.00N/09231.50W_PHG5100/Tony in Rochester, MN -MNOLMROCHESTE-227-<520>
    #TRACK: W0IBM>APW227:}N0HZN>APW231,TCPIP,W0IBM*:=4401.90N/09231.96WyPHG2000/WinAPRS 2.3.1 -OLROCMN      -231-<630>
    #       N0FKU-9>GPS:$GPRMC,123333,V,,,,,,,030800,,*39

    #TRACK: $GPRMC,213707.00,A,4432.6416,N,09320.2
    #TRACK: W0IBM>APRS:}N0HZN>APW245,TCPIP,W0IBM*:=4401.90N/09231.96W_PHG2000/WinAPRS 2.4.5 -MNOLMROCHESTE-245-<630>
    #TRACK: KC0EQV-9>APRS:$GPRMC,215659,V,4404.8999,N,09230.2287,W,000.0,000.0,050800,001.2,E*73

    #       KC0EQV-9>APRS:$GPRMC,031831,A,3616.6824,N,11502.3395,W,064.2,245.3,010801,013.7,E*60

    my ( $callsign, $tocall, $data ) = $APRSString =~ /(\S+?)\>(\S+?)\:(\S+)/;
    print "db callsign=$callsign tocall=$tocall data=$data\n" if $Debug{'aprs'};

    my ( $GPSTime, $GPSLatitude, $GPSLongitude, $GPSSpeed, $GPSCourse ) =
      ( split( ',', $data ) )[ 1, 3, 5, 7, 8 ];

    # Ignore data that does not have a position and
    # Ignore data if that callsign recently sent data (usually duplicate)
    if (    $GPSLatitude
        and ( $Time - $callsign_data{$callsign}{time} ) > 30
        and substr( $data, 0, 6 ) eq '$GPRMC' )
    {

        $GPSSpeed  = 0 unless $GPSSpeed;     # Change from '' to 0
        $GPSCourse = 0 unless $GPSCourse;    # Change from '' to 0

        $callsign_data{$callsign}{time} = $Time;

        # Convert from minutes-seconds
        $GPSLatitude = (
            substr( $GPSLatitude, 0, 2 ) +
              ( substr( $GPSLatitude, 2, 8 ) / 60 ) );
        $GPSLongitude = (
            substr( $GPSLongitude, 0, 3 ) +
              ( substr( $GPSLongitude, 3, 8 ) / 60 ) );

        # convert the GPS Speed to MPH
        $GPSSpeed = round( ( $GPSSpeed * 1.853248 ) / 1.609344 );

        # aprs longitude is not negative
        my $GPSDistance =
          &great_circle_distance( $GPSLatitude, $GPSLongitude,
            $config_parms{latitude}, abs $config_parms{longitude} );

        # Skip if the car has not moved since last time or its been a while (unless distant internet data)
        if (
               ( $Debug{'aprs'} )
            or
            ( abs( $callsign_data{$callsign}{distance} - $GPSDistance ) > .1 )
            or ( ( $Time - $callsign_data{$callsign}{time_logged} ) > 1800
                and $GPSDistance < 500 )
          )
        {

            $callsign_data{$callsign}{distance}    = $GPSDistance;
            $callsign_data{$callsign}{time_logged} = $Time;

            # Calculate bearing from the Position file
            my ( $GPSCompPlace, $GPSCompDist, $GPSCompCourse );
            $GPSCompDist = 99999;
            for my $GPSTempCompLine (@gps_complines) {
                chomp $GPSTempCompLine;

                #               my ($GPSTempCompPlace, $GPSTempCompLat, $GPSTempCompLong) = (split(',', $GPSTempCompLine))[0, 1, 2];
                my ( $GPSTempCompPlace, $GPSTempCompLat, $GPSTempCompLong ) =
                  $GPSTempCompLine =~ /(.+), *(\S+), *(\S+)/;
                next unless $GPSTempCompLong;
                next if $GPSTempCompPlace =~ /^\#/;    # Allow for comments

                # Calculate distance station is away from pos file
                my $GPSTempCompDist = &great_circle_distance(
                    $GPSLatitude,    $GPSLongitude,
                    $GPSTempCompLat, $GPSTempCompLong
                );

                #               print "tracking db $GPSTempCompPlace, $GPSTempCompLat, $GPSTempCompLong dist=$GPSTempCompDist.\n";
                if ( $GPSTempCompDist < $GPSCompDist ) {
                    $GPSCompPlace = $GPSTempCompPlace;
                    $GPSCompDist  = $GPSTempCompDist;

                    # Calculate direction
                    $GPSCompCourse = int(
                        atan2(
                            $GPSTempCompLong - $GPSLongitude,
                            $GPSLatitude - $GPSTempCompLat
                        ) * 180 / 3.14159265
                    );
                    $GPSCompCourse += 360 if $GPSCompCourse < 0;
                    $GPSCompCourse = convert_direction $GPSCompCourse;

                    #               print " $GPSCompCourse place=$GPSCompPlace dist=$GPSCompDist\n  GPSCompCourse xy = $GPSTempCompLong - $GPSLongitude, $GPSTempCompLat - $GPSLatitude\n";
                }
            }

            logit( "$config_parms{data_dir}/logs/aprs_gps.$Year_Month_Now.log",
                "$callsign $GPSLatitude $GPSLongitude $GPSSpeed $GPSCourse $GPSDistance $GPSCompDist $GPSCompPlace"
            );

            $GPSCompPlace = 'home'       unless $GPSCompPlace;
            $GPSCompDist  = $GPSDistance unless $GPSCompDist;

            $GPSCourse =
              convert_direction $GPSCourse;    # Convert from degrees to NSEW.

            my $callsign2 =
              ( $gps_names{$callsign}{name} )
              ? $gps_names{$callsign}{name}
              : $callsign;

            my ( $msg1, $msg2, $msg3 );
            $GPSCompDist = round $GPSCompDist, 0;
            $msg2 =
              ( $GPSCompDist < 1 )
              ? " near $GPSCompPlace"
              : &plural( $GPSCompDist, 'mile' )
              . " $GPSCompCourse of $GPSCompPlace";
            if ($GPSSpeed) {
                $msg1 = sprintf( '%-10s is traveling %10s at %2d mph ',
                    $callsign2, $GPSCourse, $GPSSpeed );
            }
            else {
                #               $msg1 = sprintf('%10s is parked %24s', $callsign2);
                $msg1 =
                  sprintf( '%-10s is parked    %10s          ', $callsign2 );
                $msg2 =~ s/ near / at   /;
            }
            $msg3 = $msg1 . $msg2;

            if (
                ( $callsign2 =~ /$config_parms{tracking_printflag}/i )
                or ( $gps_names{$callsign}{group} eq
                    $config_parms{tracking_printflag} )
                or (   $config_parms{tracking_printflag} eq 'all'
                    or $config_parms{tracking_printflag} eq 'GPS' )
              )
            {
                print_log $msg3;
            }

            my $track_flag =
              ( $gps_names{$callsign}{group} eq
                  $config_parms{tracking_speakflag} )
              or ( $callsign2 =~ /$config_parms{tracking_speakflag}/i );

            if (   $track_flag
                or $config_parms{tracking_speakflag} eq 'all'
                or $config_parms{tracking_speakflag} eq 'GPS' )
            {
                speak "rooms=all voice=male3 " . $msg3;
                $msg3 = ucfirst $msg3;
                set $monitor_vehicles $msg3;

                my ( $x, $y, $html );
                $x = -$GPSLongitude;
                $y = $GPSLatitude;

                #http://www.mapblast.com/myblast/map.mb?CT=44.079669%3A-92.506829%3A10000                             pre 09/2002
                #http://www.vicinity.com/gif?&CT=44.3189816666667:-91.9015866666667:10000&FAM=myblast&W=600&H=350    post 09/2002

                $html =
                  qq[<FORM ACTION='/SET:last_response' target='speech';\n];
                $html .= qq[<tr><td>$Date_Now $Time_Now</td><td>$msg1</td>\n];

                #               $html .= qq|<td><a href="http://www.mapblast.com/myblast/map.mb?CT=$y\%3A$x\%3A10000">$msg2</a></td>\n|;
                #               $html .= qq|<td><a href="http://www.vicinity.com/gif?&CT=$y\%3A$x\%3A10000&FAM=myblast&W=600&H=350">$msg2</a></td>\n|;
                my $msg_map = "On $Date_Now $msg1 $msg2";
                $msg_map =~ s/ /%20/g;
                $html .=
                  qq|<td><a href="/bin/display_map.pl?$x&$y&$msg_map">$msg2</a></td>\n|;

                $html .=
                  qq[<td><INPUT name=aprs_location_name type='text' SIZE=10 onChange=submit>\n];
                $x = -$x;    # For logging form data in .pos
                $html .=
                  qq[<INPUT name=aprs_location_loc type='hidden' value='$y,$x'></td></tr></FORM>\n\n];

                #               $html  = qq[<li>$Date_Now $Time_Now:   $msg1 <a href=\"http://www.mapblast.com/myblast/map.mb?];
                #               $html .= qq[CT=$y\%3A$x\%3A10000">];
##              $html .= qq[&GC=X:$x|Y:$y|LT:$y|LN:$x|LS:8000|&IC=$y:$x:100:$callsign2&CMD=MAP\">];
                #               $html .= qq[\n$msg2</a>\n\n];

                logit "$config_parms{tracking_dir}/today.txt", $msg3 . "\n",
                  undef, 1;
                logit "$config_parms{tracking_dir}/week1.txt", $msg3 . "\n",
                  undef, 1;
                logit "$config_parms{tracking_dir}/today.html", $html, 0, 1;
                logit "$config_parms{tracking_dir}/week1.html", $html, 0, 1;

                # If we have not sent email recently, set a timer
                # so we send it shortly after the car has stopped.
                if ( ( $Save{tracking_email_time} + 1800 ) < time ) {
                    set $timer_tracking_email 5 *
                      60;    # Send 5 minutes after the car has stopped
                }
            }

            if ($track_flag) {

                # Save last know location
                $msg3 =~ s/ is / was /;
                $Save{ 'aprs_whereis_' . lc $callsign2 } = 'On '
                  . &time_date_stamp(15) . ' at '
                  . &time_date_stamp(5) . ', '
                  . $msg3;
                $Save{ 'aprs_whereis2_' . lc $callsign2 } =
                  sprintf "%2d:%02d %2d", $Hour, $Minute, .5 + $GPSDistance;

                # Start/stop internet monitor if needed
                if ( $gps_names{$callsign}{group} eq 'family' ) {
                    if ( !$Save{"aprs_track_$callsign2"} and $GPSDistance > 20 )
                    {
                        $Save{"aprs_track_$callsign2"} = $Time;
                        speak
                          "voice=female2 $callsign2 is $GPSDistance miles from home.  Starting an internet aprs monitor";
                    }
                    elsif ( $Save{"aprs_track_$callsign2"}
                        and $GPSDistance < 20 )
                    {
                        $Save{"aprs_track_$callsign2"} = 0;
                        speak
                          "voice=female2 $callsign2 is $GPSDistance miles from home.  Stopping the internet aprs monitor";
                    }
                }
            }

        }
    }
}

sub great_circle_distance {
    my ( $lat1, $lon1, $lat2, $lon2 ) = map { &degrees_to_radians($_) } @_;

    #   my $radius = 6367; # km
    my $radius = 3956;                              # miles
    my $d = ( sin( ( $lat2 - $lat1 ) / 2 ) )**2 +
      cos($lat1) * cos($lat2) * ( sin( ( $lon2 - $lon1 ) / 2 ) )**2;
    $d = $radius * 2 * atan2( sqrt($d), sqrt( 1 - $d ) );

    #   print "db d=$d l=$lat1,$lon1,$lat2,$lon2\n";
    return round( $d, 1 );
}

#EGIN { $::pi = 4 * atan2(1,1); }
sub degrees_to_radians {
    return $_[0] * 3.14159265 / 180.0;
}

#aprs_whereis  = new Voice_Cmd 'Where is [the car,the van]';
$aprs_whereis = new Voice_Cmd "Where is [$gps_tracked]";
$aprs_whereis->set_info('This will give the last known location of our cars');
$aprs_whereis->set_authority('anyone');
print_log "debug aprs $state."       if $state = said $aprs_whereis;
respond $Save{"aprs_whereis_$state"} if $state = said $aprs_whereis;

$v_send_tracking = new Voice_Cmd 'Send tracking log';
$v_send_tracking->set_info(
    'Send the APRS car tracking log to instant message.');
if ( expired $timer_tracking_email or said $v_send_tracking) {
    $Save{tracking_email_time} = time;
    print_log "Sending email tracker to $config_parms{tracking_mailto}";

    #    &net_mail_send(subject => "Car tracking report for $Time_Now on $Date_Now",
    #                   to => $config_parms{tracking_mailto}, mime => 1,
    #                   file => "$config_parms{tracking_dir}/today.html");

    if ( $config_parms{net_aim_name} ) {

        #        print_log "Sending tracking log to AIM id $config_parms{net_aim_name_send}";
        #        &net_im_send(text => "APRS tracking update", file => "$config_parms{tracking_dir}/today.txt");
    }

}

# Allow for finding vehicles via aprs->internet gateways
$aprs_whereis3   = new Voice_Cmd "Find [$gps_tracked]";
$aprs_whereis3m1 = new Voice_Cmd
  "Start [$gps_tracked] aprs monitor";    # Only turn on during road trips
$aprs_whereis3m2 = new Voice_Cmd
  "Stop [$gps_tracked] aprs monitor";     # Only turn on during road trips
$aprs_whereis3->set_info(
    'This will find a vehicle using internet gateway data when it is away from home'
);
$get_aprs_p = new Process_Item;

$Save{"aprs_track_$state"} = $Time if $state = state_now $aprs_whereis3m1;
$Save{"aprs_track_$state"} = 0     if $state = state_now $aprs_whereis3m2;

if ( new_minute 20 ) {
    for my $car ( split ',', $gps_tracked ) {

        #       print "Aprs searching for $car.\n";
        run_voice_cmd "Find $car" if $Save{"aprs_track_$car"};
    }
}

my $get_aprs_f = "$config_parms{data_dir}/web/get_aprs.html";
if ( $state = said $aprs_whereis3) {
    my $vehicle = $gps_names{$state}{callsign};
    set $get_aprs_p
      qq[get_url "http://www.findu.com/cgi-bin/rawposit.cgi?call=$vehicle&start=12&length=12" "$get_aprs_f"];
    start $get_aprs_p;
}

if ( done_now $get_aprs_p) {
    my $html = file_read $get_aprs_f;

    # Pick last aprs record
    my ($record) =
      $html =~ /.+^(.+)<br>/sm; # s -> . matches newline  m -> ^ matches newline
    set_data $tnc_output $record unless $record eq $Save{aprs_track_data};
    $Save{aprs_track_data} =
      $record;                  # Save this, so we can see when data changes

    #   print "db2 get_aprs data:$record.\n";
}

#KC0EQV-9>APRS:$GPRMC,031630,A,3617.6014,N,11459.8872,W,067.1,245.0,010801,013.7,E*60 <br>
#KC0EQV-9>APRS:$GPRMC,031831,A,3616.6824,N,11502.3395,W,064.2,245.3,010801,013.7,E*60 <br>

# Now do logging stuff
if ($New_Day) {
    unlink "$config_parms{tracking_dir}/today.html";
    unlink "$config_parms{tracking_dir}/today.txt";
}

if ($New_Week) {
    file_cat "$config_parms{tracking_dir}/week1.html",
      "$config_parms{tracking_dir}/old/${Year_Month_Now}.html", 'top';
    file_cat "$config_parms{tracking_dir}/week1.txt",
      "$config_parms{tracking_dir}/old/${Year_Month_Now}.txt", 'top';
    rename "$config_parms{tracking_dir}/week1.html",
      "$config_parms{tracking_dir}/week2.html"
      or print_log "Error in aprs rename 2: $!";
    rename "$config_parms{tracking_dir}/week1.txt",
      "$config_parms{tracking_dir}/week2.txt"
      or print_log "Error in aprs rename 2: $!";
    my $html =
      qq[<link rel="STYLESHEET" href="/default.css" type="text/css">\n];
    logit "$config_parms{tracking_dir}/week1.html", $html, 1;

}

# Add an index entry for the new months entry in aprs/old
if ($New_Month) {
    my $html =
      qq[<li><a href=\"$Year_Month_Now.html\">$Year_Month_Now.html</a>\n];
    logit "$config_parms{tracking_dir}/old/index.html", $html, 0, 1;
    display 'debug: check aprs/old/index.html for new entry', 0;
}

$v_show_tracking = new Voice_Cmd '{Show,Display} {the, } car log';
$v_show_tracking->set_info(
    'Display the web page that shows where our cars have been');

browser "$config_parms{tracking_dir}/today.html" if said $v_show_tracking;

# Allow updating of location database from the web page
#  - these vars are referenced in the logging html generated above
$aprs_location_loc  = new Generic_Item;
$aprs_location_name = new Generic_Item;

if ( $state = state_now $aprs_location_name) {
    my $loc = state_now $aprs_location_loc;
    print_log "aprs log: $state at $loc";
    respond "Updated location of $state";
    $loc = sprintf "%-24s,   %9.6f,  %9.6f   # %s\n", $state,
      split( ',', $loc ),
      &time_date_stamp( $config_parms{time_format_log}, $Time );
    logit "$config_parms{data_dir}/tracking.pos", $loc, 0
      unless $state =~ /^test/;
    &reload_aprs_data;    # So the above update takes effect
}

# Example format
#Cannon City,                44.33484,   93.21883

# This is called from the lcd/wap menu code ... keep the output short

#Tue 04/17/01 18:53:27 The car    is traveling       east at 37 mph  near Mayo Clinic
#Tue 04/17/01 18:47:24 The car    is traveling      south at 55 mph  near Best Buy
sub menu_vehicle_log {
    my ($name) = @_;
    my ( @data, $count );
    for (
        grep /The $name/,
        &file_read("$config_parms{tracking_dir}/week1.txt"),
        &file_read("$config_parms{tracking_dir}/week2.txt")
      )
    {
        my ( $day, $date, $time, $text ) =
          $_ =~ /(\S+) (\S+) (\S+) The $name + is +(.+)/;
        $time = time_to_ampm $time;
        $text =~ s/traveling +//g;
        $text =~ s/ +/ /g;
        $text = ucfirst $text;
        last if ++$count > 9;
        push @data, "$day $time $text";
    }
    return &menu_format_list( $Menus{response_format}, @data );
}
