# Category = Informational

#@ This module will announce when an Iridium Satellite flash is about
#@ to occur. There are 66 or so Iridium communications
#@ satellites that periodically reflect the sun's rays to the ground.
#@ You must have valid latitude, longitude, and time_zone values set
#@ in your mh.private.ini file.  Optionally set a mh.ini
#@ iridium_brightness parm to limit announcments of only the brigher flares.

=begin comment

There are 66 or so (defunct) Iridium communications satellites that that
reflect Sun rays at a magnitude -8 (brighter than the brightest star)
to an observer on the ground when the geometry is correct.  This code
will announce when one of the short (1-3 second) flashes is about to 
occur, using the lat, long, and time_zone mh.ini parms.

Note: Correct long. and time_zone parms for those of us in the 
      Western Hemisphere will be negative numbers.

=cut

$iridium_check = new Voice_Cmd '[lee,lista,visualiza] destellos irídium';
$iridium_check->set_info(
    'Lista horarios y localizaciones de los destellos de satelites irídium');

run_voice_cmd 'lee destellos irídium' if $New_Day;

# Their web site uses dorky Time Zone strings,
# so use UCT (GMT+0) and translate.
my $iridium_check_e = "$Code_Dirs[0]/iridium_check_events.pl";
my $iridium_check_f = "$config_parms{data_dir}/web/iridium.html";
my $iridium_check_u =
    "http://www.heavens-above.com/iridium.asp?"
  . "lat=$config_parms{latitude}&lng=$config_parms{longitude}&alt=0&TZ=UCT&Dur=7&"
  . "loc=$config_parms{city}";
$iridium_check_p =
  new Process_Item qq[get_url "$iridium_check_u" "$iridium_check_f"];

#$iridium_check_p = new Process_Item "get_url '$iridium_check_u' '$iridium_check_f'";

$state = said $iridium_check;
start $iridium_check_p   if $state eq 'lee';
browser $iridium_check_f if $state eq 'visualiza';

if ( done_now $iridium_check_p or $state eq 'lista' ) {
    my ( $display, $time, $sec, $time_sec );
    my $html = file_read $iridium_check_f;

    # Add a base href, so we can click on links
    $html =~ s|</head>|\n<BASE href='http://www.heavens-above.com/'>|i;
    file_write $iridium_check_f, $html;

    #   my $text = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($html));
    my $text = &html_to_text($html);

    open( MYCODE, ">$iridium_check_e" )
      or print_log "Error in writing to $iridium_check_e";
    print MYCODE "\n#@ Auto-generated from code/common/internet_iridium.pl\n\n";
    print MYCODE "\n\$iridium_timer = new Timer;\n\n";

    print MYCODE <<'eof';
        if ($New_Second and my $time_left = int seconds_remaining $iridium_timer) {
          my %iridium_timer_intervals = map {$_, 1} (15,30,90);
          if ($iridium_timer_intervals{$time_left}) {
             my $pitch = int 10*(1 - $time_left/60);
             $pitch = '';	# Skip this idea ... not all TTS engines do pitch that well
             speak "app=timer pitch=$pitch $time_left segundos para el destello";

          }
       }
       if (expired $iridium_timer) {
          speak "app=timer pitch=10 Se esta produciendo ahora mismo un destello Iridium";
          play 'timer2';              # Set in event_sounds.pl
       }

eof

    for ( split "\n", $text ) {
        if (/Iridium \d+$/) {
            s/\xb0//g;       # Drop ^o (degree) symbol
            s/\(.+?\)//g;    # Drop the (NSEW ) strings
            my @a = split;

            #           print "db t=$text\na=@a\n";
            #           print "db testing time: $a[1]/$a[0] $a[2]\n";
            $time = my_str2time(
                $config_parms{date_format} =~ /ddmm/
                ? "$a[0]/$a[1] $a[2]"
                : "$a[1]/$a[0] $a[2]"
              ) +
              3600 * $config_parms{time_zone};
            $time += 3600 if (localtime)[8];  # Adjust for daylight savings time
            ($time_sec) =
              time_date_stamp( 6, $time ) . ' ' . time_date_stamp( 16, $time );
            ( $time, $sec ) = time_date_stamp( 9, $time );
            $display .= sprintf "%s, mag=%2d, alt=%3d, azimuth=%3d, %s %s\n",
              $time_sec, @a[ 3, 4, 5, 9, 10 ];

            next unless $a[4] > 20;    # We can not see them if they are too low

            # Create a seperate code file with a time_now for each event
            print MYCODE<<eof;
            if (\$Dark and time_now '$time - 0:02' and $a[3] <= \$config_parms{iridium_brightness}) {
                my \$msg = "Aviso: $a[9] satelite $a[10] va producir un destello de  magnitud $a[3] en 2 minutos ";
                \$msg .= "con una elevación de $a[4], y azimut de $a[5].";
                speak "app=timer \$msg";
                display "Destello Iridium a las: $time_sec.  \\n" . \$msg, 600;
                set \$iridium_timer 120 + $sec;
            }
eof

        }
    }
    close MYCODE;
    display $display, 120, 'Iridium list', 'fixed';

    #   display $iridium_check_e;
    do_user_file $iridium_check_e;    # This will enable the above MYCODE
}

# This timer will be triggered by the timer set in the above MYCODE

=begin example

Example of data after html table -> text

19 Feb 01:06:13 -2 47^o 160^o (SSE) 22.6 km (W) -8 Iridium 33

20 Feb 01:00:09 -4 47^o 159^o (N ) 10.5 km (E) -8 Iridium 59

=cut
