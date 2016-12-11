# Category = Informational

#@ This module will announce when International Space Station (ISS) is
#@ visible in the local sky
#@ You must have valid latitude, longitude, and time_zone values set
#@ in your mh.private.ini file.  Optionally set a mh.ini
#@ iss_brightness parm to limit announcments of only the brigher passes.

=begin comment

Note: Correct long. and time_zone parms for those of us in the 
      Western Hemisphere will be negative numbers.

=cut

$iss_check = new Voice_Cmd '[lee,lista,visualiza] pases ISS';
$iss_check->set_info(
    'Lista horarios y localizaciones de los pases de la Estación Espacial Internacional (ISS)'
);

run_voice_cmd 'lee pases ISS' if $New_Day;

# Their web site uses dorky Time Zone strings,
# so use UCT (GMT+0) and translate.
my $iss_check_e = "$Code_Dirs[0]/iss_check_events.pl";
my $iss_check_f = "$config_parms{data_dir}/web/iss.html";
my $iss_check_u =
    "http://www.heavens-above.com/PassSummary.asp?"
  . "lat=$config_parms{latitude}&lng=$config_parms{longitude}&alt=0&TZ=UCT&satid=25544&"
  . "loc=$config_parms{city}";
$iss_check_p = new Process_Item qq[get_url "$iss_check_u" "$iss_check_f"];

$state = said $iss_check;
start $iss_check_p   if $state eq 'lee';
browser $iss_check_f if $state eq 'visualiza';

if ( done_now $iss_check_p or $state eq 'lista' ) {
    my (
        $display,    $time_s,    $azimuth_s, $time_m, $azimuth_m,
        $time_e,     $azimuth_e, $sec_s,     $sec_m,  $sec_e,
        $time_start, $time_max,  $time_end
    );
    my $html = file_read $iss_check_f;

    # Add a base href, so we can click on links
    $html =~ s|</head>|\n<BASE href='http://www.heavens-above.com/'>|i;
    file_write $iss_check_f, $html;

    my $text = &html_to_text($html);

    #   print "ISS_TEXT:\n $text \n";

    open( MYCODE, ">$iss_check_e" )
      or print_log "Error in writing to $iss_check_e";
    print MYCODE "\n#@ Auto-generated from code/common/internet_iss.pl\n\n";
    print MYCODE "\n\$iss_timer = new Timer;\n\n";

    print MYCODE <<'eof';
        if ($New_Second and my $time_left = int seconds_remaining $iss_timer) {
          my %iss_timer_intervals = map {$_, 1} (15,30,60);
          if ($iss_timer_intervals{$time_left}) {
             my $pitch = int 10*(1 - $time_left/60);
             $pitch = '';	# Skip this idea ... not all TTS engines do pitch that well
             speak "app=timer pitch=$pitch $time_left segundos para el paso de la Estación Espacial";

          }
       }
       if (expired $iss_timer) {
          speak "app=timer pitch=10 Comienza el paso de la Estación Espacial";
          play 'timer2';              # Set in event_sounds.pl
       }

eof

    for ( split "\n", $text ) {
        if (/^\d+\s/) {
            s/\xb0//g;       # Drop ^o (degree) symbol
            s/\(.+?\)//g;    # Drop the (NSEW ) strings
            my @a = split;

            #           print "db t=$text\na=@a\n";
            #           print "db testing time: $a[1]/$a[0] $a[3]\n";
            $time_s = my_str2time(
                $config_parms{date_format} =~ /ddmm/
                ? "$a[0]/$a[1] $a[3]"
                : "$a[1]/$a[0] $a[3]"
              ) +
              3600 * $config_parms{time_zone};
            $time_s += 3600
              if (localtime)[8];    # Adjust for daylight savings time
            $time_m = my_str2time(
                $config_parms{date_format} =~ /ddmm/
                ? "$a[0]/$a[1] $a[6]"
                : "$a[1]/$a[0] $a[6]"
              ) +
              3600 * $config_parms{time_zone};
            $time_m += 3600
              if (localtime)[8];    # Adjust for daylight savings time
            $time_e = my_str2time(
                $config_parms{date_format} =~ /ddmm/
                ? "$a[0]/$a[1] $a[9]"
                : "$a[1]/$a[0] $a[9]"
              ) +
              3600 * $config_parms{time_zone};
            $time_e += 3600
              if (localtime)[8];    # Adjust for daylight savings time
            ( $time_start, $sec_s ) = time_date_stamp( 9, $time_s );
            ( $time_max,   $sec_m ) = time_date_stamp( 9, $time_m );
            ( $time_end,   $sec_e ) = time_date_stamp( 9, $time_e );
            $time_s = time_date_stamp( 13, $time_s );
            $time_m = time_date_stamp( 13, $time_m );
            $time_e = time_date_stamp( 13, $time_e );
            $azimuth_s = convert_direction( &convert_to_degrees( $a[5] ) );
            $azimuth_m = convert_direction( &convert_to_degrees( $a[8] ) );
            $azimuth_e = convert_direction( &convert_to_degrees( $a[11] ) );
            $display .= sprintf "ISS: %s, mag=%2d, alt=%3d, azimuth=%s\n",
              $time_start, @a[ 2, 4 ], $azimuth_s;

            next unless $a[7] > 20;    # We can not see them if they are too low

            # Create a seperate code file with a time_now for each event
            print MYCODE<<eof;
            if (\$Dark and time_now '$time_start - 0:02' and $a[2] <= \$config_parms{iss_brightness}) {
                my \$msg = "Aviso: Dentro de 2 minutos la Estación Espacial Internacional pasará con magnitud $a[2], ";
		\$msg .= "Empezará a verse por el $azimuth_s, con una elevación de $a[4], ";
		\$msg .= "alcanzará una elevación máxima de $a[7], a las $time_m, por el $azimuth_m, ";
		\$msg .= "y dejará de verse a las $time_e, por el $azimuth_e, con una elevación de $a[10].";
                speak "app=timer \$msg";
                display "ISS: $time_start.  \\n" . \$msg, 600;
                set \$iss_timer 120 + $sec_s;
            }
            if (\$Dark and time_now('$time_max', $sec_m)) {
		my \$msg = "Elevación máxima de la Estación Espacial de $a[7], por el $azimuth_m.";
                speak "\$msg";
            }
            if (\$Dark and time_now('$time_end', $sec_e)) {
		my \$msg = "Fin de paso de la Estación Espacial, por el $azimuth_e.";
                speak "\$msg";
            }
eof

        }
    }
    close MYCODE;
    display $display, 120, 'ISS list', 'fixed';

    do_user_file $iss_check_e;    # This will enable the above MYCODE
}

# This timer will be triggered by the timer set in the above MYCODE

=begin example

Example of data after html table -> text

23 Oct 2.4 04:25:40 11 NNE 04:25:40 11 NNE 04:25:51 10 NNE

23 Oct 2.0 05:59:09 10 NNW 05:59:50 11 N 06:00:30 10 N

=cut

# convert text wind direction to degrees.
sub convert_to_degrees {
    my $text = shift;
    my $dir;

    ( $text eq 'N' )   && ( $dir = 0 );
    ( $text eq 'NNE' ) && ( $dir = 22 );
    ( $text eq 'NE' )  && ( $dir = 45 );
    ( $text eq 'ENE' ) && ( $dir = 67 );

    ( $text eq 'E' )   && ( $dir = 90 );
    ( $text eq 'ESE' ) && ( $dir = 112 );
    ( $text eq 'SE' )  && ( $dir = 135 );
    ( $text eq 'SSE' ) && ( $dir = 157 );

    ( $text eq 'S' )   && ( $dir = 180 );
    ( $text eq 'SSW' ) && ( $dir = 202 );
    ( $text eq 'SW' )  && ( $dir = 225 );
    ( $text eq 'WSW' ) && ( $dir = 247 );

    ( $text eq 'W' )   && ( $dir = 270 );
    ( $text eq 'WNW' ) && ( $dir = 292 );
    ( $text eq 'NW' )  && ( $dir = 315 );
    ( $text eq 'NNW' ) && ( $dir = 337 );

    return $dir;
}

