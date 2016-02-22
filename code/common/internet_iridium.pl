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

$v_iridium_check = new Voice_Cmd '[Get,List,Browse] iridium flares';
$v_iridium_check->set_info(
    'Lists times and locations flares from iridium satellites');

# Create trigger

if ($Reload) {
    &trigger_set(
        '$New_Week', "run_voice_cmd('Get iridium flares')",
        'NoExpire',  'get iridium info'
    ) unless &trigger_get('get iridium info');
}

sub uninstall_internet_iridium {
    &trigger_delete('get iridium info');
}

# Their web site uses dorky Time Zone strings,
# so use UCT (GMT+0) and translate.
my $iridium_check_e = "$Code_Dirs[0]/iridium_check_events.pl";
my $iridium_check_f = "$config_parms{data_dir}/web/iridium.html";
my $iridium_check_u =
    "http://www.heavens-above.com/iridium.asp?"
  . "lat=$config_parms{latitude}&lng=$config_parms{longitude}&alt=0&TZ=UCT&Dur=7&"
  . "loc=$config_parms{city}";
$p_iridium_check =
  new Process_Item qq[get_url "$iridium_check_u" "$iridium_check_f"];

sub respond_iridium {
    my $connected = shift;
    my $display   = &list_iridium();
    if ($display) {
        $v_iridium_check->respond(
            "app=iridium connected=$connected Listing iridium data.");
        display $display, 0, 'Iridium list', 'fixed';
    }
    else {
        $v_iridium_check->respond(
            "app=iridium connected=$connected Nothing to report.");
    }
}

sub list_iridium {
    my ( $display, $time, $sec, $time_sec );
    my $html = file_read $iridium_check_f;

    # Add a base href, so we can click on links
    $html =~ s|</head>|\n<BASE href='http://www.heavens-above.com/'>|i;
    file_write $iridium_check_f, $html;

    my $text = &html_to_text($html);

    open( MYCODE, ">$iridium_check_e" )
      or print_log "Error in writing to $iridium_check_e";
    print MYCODE "\n#@ Auto-generated from code/common/internet_iridium.pl\n\n";
    print MYCODE "\n\$t_iridium_timer = new Timer;\n\n";

    print MYCODE <<'eof';
        if ($New_Second and my $time_left = int seconds_remaining $t_iridium_timer) {
          my %iridium_timer_intervals = map {$_, 1} (15,30,90);
          if ($iridium_timer_intervals{$time_left}) {
             my $pitch = int 10*(1 - $time_left/60);
             $pitch = '';	# Skip this idea ... not all TTS engines do pitch that well
             speak "app=iridium pitch=$pitch $time_left seconds till flash";

          }
       }
       if (expired $t_iridium_timer) {
          speak "app=iridium pitch=10 Iridium flash now occuring";
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
                set \$t_iridium_timer 120 + $sec;
                my \$msg = "Notice: $a[9] satellite $a[10] will have a magnitude $a[3] flare in 2 minutes ";
                \$msg .= "at an altitude of $a[4], azimuth of $a[5].";
                speak "app=iridium \$msg";
                display "Flare will occur at: $time_sec.  \\n" . \$msg, 600;
            }
eof

        }
    }
    close MYCODE;
    do_user_file $iridium_check_e;    # This will enable the above MYCODE
    return $display;
}

if ( said $v_iridium_check) {
    my $state  = $v_iridium_check->{state};
    my $state2 = $state;
    $state2 = 'Browsing' if $state2 eq 'Browse';
    $state2 = 'Getting'  if $state2 eq 'Get';
    start $p_iridium_check if $state eq 'Get';
    if ( $state eq 'Browse' ) {
        if ( -e $iridium_check_f ) {
            browser $iridium_check_f;
        }
        else {
            $state2 = 'I do not have any iridium data.';
        }
    }

    if ( $state eq 'List' ) {
        &respond_iridium(1);
    }
    else {
        $v_iridium_check->respond(
            "app=iridium $state2" . ' iridium report...' );
    }

}

&respond_iridium(0) if done_now $p_iridium_check;

=begin example

Example of data after html table -> text

19 Feb 01:06:13 -2 47^o 160^o (SSE) 22.6 km (W) -8 Iridium 33

20 Feb 01:00:09 -4 47^o 159^o (N ) 10.5 km (E) -8 Iridium 59

=cut
