# Category=GPS tracking


######################################################
# This is a subset of what is in Brian's tracking.pl #
# code.  It only does GPS tracking.                  #
######################################################

my (@gps_complines, %gps_names);

&tk_radiobutton('APRS Speak', \$config_parms{tracking_speakflag}, ['none', 'family', 'GPS', 'WX', 'all']);
&tk_radiobutton('APRS Print', \$config_parms{tracking_printflag}, ['none', 'family', 'GPS', 'WX', 'all']);


                                # Define TNC Output strings
$tnc_output = new Serial_Item ('CONV', 'converse', 'serial1');
$tnc_output-> add             ('?WX?', 'wxquery', 'serial1');
#$tnc_output-> add             (sprintf("=%2d%05.02fN/%2d%05.02fW- *** %s MisterHouse Tracking System, bruce\@misterhouse.net ***",
$tnc_output-> add             (sprintf("=%2d%05.02fN/%03d%05.02fW- *** %s MisterHouse Tracking System ***",
                                       int($config_parms{latitude}),
                                       ($config_parms{latitude} - int($config_parms{latitude}))*60,
                                       int($config_parms{longitude}),
                                       ($config_parms{longitude} -int($config_parms{longitude}))*60,
                                       $config_parms{tracking_callsign}),
                               'position', 'serial1');

$timer_tracking_email = new  Timer;

                                # Re-read tracking.pos and tracking.names on Reload, if changed
if ($Reread) {
    if ($Reload or file_change "$config_parms{code_dir}/tracking.pos") {
        print_log "Reloading tracking.pos";
        open(GPS, "$config_parms{code_dir}/tracking.pos");
        @gps_complines = <GPS>;
        close GPS;
    }
    if ($Reload or file_change "$config_parms{code_dir}/tracking.names") {
        print_log "Reloading tracking.names";
        open(GPS, "$config_parms{code_dir}/tracking.names");
        while (<GPS>) {
            next if /^\#/;      # Allow for comments
            chomp;
            my ($callsign, $name, $group) = split(/, */, $_);
            $gps_names{$callsign}{name}  = $name;
            $gps_names{$callsign}{group} = $group;
        }
        close GPS;
    }
}

                                # Set TNC to Converse and send position on Startup
#if ($Startup or $Reload) {
if ($Startup) {
    set $tnc_output 'converse';
    print_log "Tracking Interface has been Initialized...Callsign $config_parms{tracking_callsign}";
}

                                # Send position 4 times a day (server flushes data every 6 hours)
                                # Tracked at: http://map.aprs.net:8000/kc0eqv-1
$v_send_position = new Voice_Cmd("Send my APRS Position");
set_info $v_send_position "Send the house latitude/longitude: $config_parms{latitude}, $config_parms{longitude}." .
    "Not all that useful, since the house does not move too often :)";

if ($state = said $v_send_position or time_cron('0 2,8,14,20 * * *')) {
    set $tnc_output 'position';
    speak "Position sent for $config_parms{tracking_callsign}";
    print_log "aprs position string: $tnc_output->{id_by_state}{position}";
}
$v_wx_query = new Voice_Cmd("APRS Weather Query");
$v_wx_query-> set_info('Send out a weather query to nearby APRS weather stations');
if ($state = said $v_wx_query) {
    set $tnc_output 'wxquery';
    speak "Weather query requested";
}

$v_send_test_email = new Voice_Cmd("Send APRS email to myself");
set_info $v_send_test_email 'Use an APRS internet gateway to send a test email from my house,' .
    'thru the ham radio, to an Inetnet gateway receiver, and thru the internet back to my house.  Pretty useful eh?';
if ($state = said $v_send_test_email) {
    print_log "aprs mail sent to $config_parms{net_mail_user}\@$config_parms{net_mail_server}";
    set $tnc_output ":EMAIL    :$config_parms{net_mail_user}\@$config_parms{net_mail_server} Test E-Mail - $Time";
    speak "Email sent";
}

$v_send_test_icq = new Voice_Cmd("Send APRS ICQ msg to myself");
$v_send_test_icq-> set_info('Send a test ICQ message, via a ham radio APRS connection');
if ($state = said $v_send_test_icq) {
    set $tnc_output ":ICQSERVE :967794 Test Msg - $Time";
    speak "ICQ message sent";
}



                                # Process incoming APRS data
my %callsign_data;
if (my $APRSString = said $tnc_output) {

    print_log "TRACK: $APRSString" if $config_parms{tracking_printflag} eq 'all';

                                # Decode the Callsign and different parts from the Packet

#TRACK: KC0EQV>APRS:!4404.87N/09230.26W> 
#TRACK: KC0EQV>APRS:$GPRMC,210314,A,4404.8861,N,09230.2205,W,000.0,206.4,161099,001.2,E*6A
#TRACK: KC0FOW-9>GPSLK:$GPRMC,195439,A,4403.907,N,09230.074,W,000.0,258.3,161099,001.2,E*68
#TRACK: N0EST-9>GPSMV:$GPRMC,203921,A,4400.2593,N,09228.6660,W,0.000,0.0,161099,1.5,E*67
#TRACK: N0EST>APW226:=4405.70NN09229.60W#PHG6260/Rochester MN W/R/T -MNOLMROCHESTE-226-<530>
#TRACK: AA0SM>APW227:=4405.00N/09231.50W_PHG5100/Tony in Rochester, MN -MNOLMROCHESTE-227-<520>
#TRACK: W0IBM>APW227:}N0HZN>APW231,TCPIP,W0IBM*:=4401.90N/09231.96WyPHG2000/WinAPRS 2.3.1 -OLROCMN      -231-<630>

    my ($callsign, $tocall, $data) = $APRSString =~ /(\S+?)\>(\S+?)\:(\S+)/;

                                # Ignore data if that callsign recently sent data (usually duplicate)
    next if $Time - $callsign_data{$callsign}{time} < 30;

    $callsign_data{$callsign}{time} = $Time;

    print "db callsign=$callsign tocall=$tocall data=$data\n" if $config_parms{debug} eq 'aprs';

    if (substr($data, 0, 6) eq '$GPRMC') {
        my ($GPSTime, $GPSLatitude, $GPSLongitude, $GPSSpeed, $GPSCourse) = (split(',', $data))[1, 3, 5, 7, 8];

                                # Convert from minutes-seconds
        $GPSLatitude  = (substr($GPSLatitude, 0, 2)  + (substr($GPSLatitude, 2, 8) / 60));
        $GPSLongitude = (substr($GPSLongitude, 0, 3) + (substr($GPSLongitude, 3, 8) / 60));
        
                                # convert the GPS Speed to MPH
        $GPSSpeed = round (($GPSSpeed * 1.853248) / 1.609344);

        my $GPSDistance = (sin $GPSLatitude) * (sin $config_parms{latitude}) +
                          (cos $GPSLatitude) * (cos $config_parms{latitude}) * (cos ($config_parms{longitude}-$GPSLongitude));
        $GPSDistance = 1.852 * 60 * atan2(sqrt(1 - $GPSDistance * $GPSDistance), $GPSDistance);
        $GPSDistance = $GPSDistance / 1.6093440;
        $GPSDistance = round($GPSDistance, 1);
        
                                # Skip if the car has not moved since last time or its been a while
        next unless ($config_parms{debug} eq 'aprs') or
                    (abs($callsign_data{$callsign}{distance} - $GPSDistance) > .1) or
                    (($Time - $callsign_data{$callsign}{time_logged}) > 1800);
                
        $callsign_data{$callsign}{distance} = $GPSDistance;
        $callsign_data{$callsign}{time_logged} = $Time;

       
                                # Calculate bearing from the Position file
        my ($GPSCompPlace, $GPSCompDist, $GPSCompCourse );
        $GPSCompDist = 9999;
        for my $GPSTempCompLine (@gps_complines) {
            chomp $GPSTempCompLine;
#           my ($GPSTempCompPlace, $GPSTempCompLat, $GPSTempCompLong) = (split(',', $GPSTempCompLine))[0, 1, 2];
            my ($GPSTempCompPlace, $GPSTempCompLat, $GPSTempCompLong) = $GPSTempCompLine =~ /(.+), *(\S+), *(\S+)/;
            next unless $GPSTempCompLong;
            next if $GPSTempCompPlace =~ /^\#/; # Allow for comments

                                # Calculate distance station is away from pos file
            my $GPSTempCompDist = (sin $GPSLatitude) * (sin $GPSTempCompLat) +
                (cos $GPSLatitude) * (cos $GPSTempCompLat) * (cos ($GPSTempCompLong-$GPSLongitude));
            $GPSTempCompDist = 1.852 * 60 * atan2(sqrt(1 - $GPSTempCompDist * $GPSTempCompDist), $GPSTempCompDist);
            $GPSTempCompDist = $GPSTempCompDist / 1.6093440;
            $GPSTempCompDist = round($GPSTempCompDist, 1);

#           print "tracking db $GPSTempCompPlace, $GPSTempCompLat, $GPSTempCompLong dist=$GPSTempCompDist.\n";
            if ($GPSTempCompDist < 300 and $GPSTempCompDist < $GPSCompDist) {
                $GPSCompPlace = $GPSTempCompPlace;
                $GPSCompDist = $GPSTempCompDist;

                                # Calculate direction
                $GPSCompCourse = int(atan2($GPSTempCompLong-$GPSLongitude, $GPSLatitude-$GPSTempCompLat) * 180 / 3.14159265);
                $GPSCompCourse += 360 if $GPSCompCourse < 0;
                $GPSCompCourse = convert_direction $GPSCompCourse;
#               print " $GPSCompCourse place=$GPSCompPlace dist=$GPSCompDist\n  GPSCompCourse xy = $GPSTempCompLong - $GPSLongitude, $GPSTempCompLat - $GPSLatitude\n";
            }
        }

        logit("$config_parms{data_dir}/logs/aprs_gps.$Year_Month_Now.log",
              "$callsign $GPSLatitude $GPSLongitude $GPSSpeed $GPSCourse $GPSDistance $GPSCompDist $GPSCompPlace");

        $GPSCompPlace = 'home' unless $GPSCompPlace;
        $GPSCompDist  = $GPSDistance unless $GPSCompDist;

        $GPSCourse = convert_direction $GPSCourse; # Convert from degrees to NSEW.

        my $callsign2 = ($gps_names{$callsign}{name}) ? $gps_names{$callsign}{name} : $callsign;
        
        my ($msg1, $msg2);
        $msg2 = ($GPSCompDist < .1) ? " near $GPSCompPlace" : " $GPSCompDist miles $GPSCompCourse of $GPSCompPlace";
        if ($GPSSpeed) {
            $msg1 = sprintf('%10s is traveling %10s  at %2d mph', $callsign2, $GPSCourse, $GPSSpeed );
        }                
        else {
            $msg1 = sprintf('%10s is parked %24s', $callsign2);
            $msg2 =~ s/ near / at /;
        }                

        if (($callsign2 =~ /$config_parms{tracking_printflag}/i) or
            ($gps_names{$callsign}{group} eq $config_parms{tracking_printflag}) or
            ($config_parms{tracking_printflag} eq 'all' or $config_parms{tracking_printflag} eq 'GPS')) {
            print_log $msg1 . $msg2;
        }
        
        if (($callsign2 =~ /$config_parms{tracking_speakflag}/i) or
            ($gps_names{$callsign}{group} eq $config_parms{tracking_speakflag}) or
            ($config_parms{tracking_speakflag} eq 'all' or $config_parms{tracking_speakflag} eq 'GPS')) {
            speak "rooms=all " . $msg1 . $msg2;

            my ($x, $y, $html);
            $x = -$GPSLongitude;
            $y = $GPSLatitude;
            $html  = qq[<li>$Date_Now $Time_Now:   $msg1 <a href=\"http://www.mapblast.com/mblast/map.mb?];
            $html .= qq[&GC=X:$x|Y:$y|LT:$y|LN:$x|LS:8000|&IC=$y:$x:100:$callsign2&CMD=MAP\">];
            $html .= qq[\n$msg2</a>\n\n];
            logit "$config_parms{tracking_dir}/today.txt",  $msg1 . $msg2 . "\n", undef, 1;
            logit "$config_parms{tracking_dir}/today.html", $html, 0, 1;
            logit "$config_parms{tracking_dir}/week1.html", $html, 0, 1;

                                # If we have not sent email recently, set a timer
                                # so we send it shortly after the car has stopped.
            if (($Save{tracking_email_time} + 1800) < time) {
                set $timer_tracking_email 5*60; # Send 5 minutes after the car has stopped
            }
        }
    }
}

$v_send_tracking = new Voice_Cmd 'Send tracking log';
$v_send_tracking-> set_info('Send the APRS car tracking log to Bruce at work via instant message.');
if (expired $timer_tracking_email or said $v_send_tracking) {
    $Save{tracking_email_time} = time;
    print_log "Sening email tracker to $config_parms{tracking_mailto}";
#    &net_mail_send(subject => "Car tracking report for $Time_Now on $Date_Now",
#                   to => $config_parms{tracking_mailto}, mime => 1,
#                   file => "$config_parms{tracking_dir}/today.html");

    if ($config_parms{net_aim_name}) {
        print_log "Sending tracking log to AIM id $config_parms{net_aim_name_send}";
        &net_im_send(text => "APRS tracking update", file => "$config_parms{tracking_dir}/today.txt");
    }

}

if ($New_Day) {
    unlink "$config_parms{tracking_dir}/today.html";
    unlink "$config_parms{tracking_dir}/today.txt";
    my $html = qq[<link rel="STYLESHEET" href="/default.css" type="text/css">\n];
    logit "$config_parms{tracking_dir}/today.html", $html, 0, 1;
    logit "$config_parms{tracking_dir}/week1.html", "<hr>\n", 0, 1;
}
 
if ($New_Week) {
    file_cat "$config_parms{tracking_dir}/week2.html", "$config_parms{tracking_dir}/old/${Year_Month_Now}.html";
    rename   "$config_parms{tracking_dir}/week1.html", "$config_parms{tracking_dir}/week2.html"  or print_log "Error in aprs rename 2: $!";
    my $html = qq[<link rel="STYLESHEET" href="/default.css" type="text/css">\n];
    logit "$config_parms{tracking_dir}/week1.html", $html, 1;

                                # Add an index entry for the new months entry in aprs/old
    if ($New_Month) {
        my $html = qq[<li><a href=\"$Year_Month_Now.html\">$Year_Month_Now.html</a>\n];
        logit  "$config_parms{tracking_dir}/old/index.html", $html, 1;
    }
}
 


