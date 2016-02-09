# Category = Informational

#@ This module announces when a visible pass of the starshine
#@ satellite is about to occur.
#@
#@ You must have valid latitude, longitude, and time_zone values set
#@ in your mh.private.ini file.

=begin comment

internet_starshine.pl
 1.0 Original version by Tim Doyle <tim@greenscourt.com>
     using internet_iridium.pl as an example - 11/11/2001

The Starshine 3 project designed to encourage students around the world to participate in
an actual space mission. The spacecraft is like a large disco ball with many small mirrors
which glint in the sunlight as the spacecraft rotates and make it visible to observers on the ground.

This code will announce when one of the visible passes is about to
occur, using the lat, long, and time_zone mh.ini parms.

Note: Correct long. and time_zone parms for those of us in the
      Western Hemisphere will be negative numbers.

=cut

$v_starshine_check = new Voice_Cmd '[Get,List,Browse] starshine flares';
$v_starshine_check->set_info(
    'Lists times and locations of visible starshine 3 satellite passes');

# Create trigger

if ($Reload) {
    &trigger_set(
        '$New_Week', "run_voice_cmd('Get starshine flares')",
        'NoExpire',  'get starshine info'
    ) unless &trigger_get('get starshine info');
}

sub uninstall_internet_starshine {
    &trigger_delete('get starshine info');
}

# Their web site uses dorky Time Zone strings,
# so use UCT (GMT+0) and translate.
my $starshine_check_e = "$Code_Dirs[0]/starshine_check_events.pl";
my $f_starshine_check = "$config_parms{data_dir}/web/starshine.html";
my $starshine_check_u = "http://www.heavens-above.com/PassSummary.asp?"
  . "lat=$config_parms{latitude}&lng=$config_parms{longitude}&alt=0&TZ=UCT&satid=26929";
$p_starshine_check =
  new Process_Item qq[get_url "$starshine_check_u" "$f_starshine_check"];

sub respond_starshine {
    my $connected = shift;
    my $display   = &list_starshine();
    if ($display) {
        $v_starshine_check->respond(
            "app=starshine connected=$connected Listing starshine data.");
        display $display, 0, 'Starshine list', 'fixed';
    }
    else {
        $v_starshine_check->respond(
            "app=starshine connected=$connected Nothing to report.");
    }
}

sub list_starshine {

    my ( $display, $time, $sec, $time_sec );
    my $html = file_read $f_starshine_check;

    # Add a base href, so we can click links
    $html =~ s|</head>|\n<BASE href='http://www.heavens-above.com/'>|i;
    file_write $f_starshine_check, $html;

    my $text = &html_to_text($html);

    open( MYCODE, ">$starshine_check_e" )
      or print_log "Error in writing to $starshine_check_e";
    print MYCODE
      "\n#@ Auto-generated from code/common/internet_starshine.pl\n\n";
    for ( split "\n", $text ) {
        if (/^\d{2}\s\S{3}\s/) {
            my @a = split;
            $time = my_str2time("$a[1]/$a[0] $a[3]") +
              3600 * $config_parms{time_zone};
            $time += 3600 if (localtime)[8];  # Adjust for daylight savings time
            ($time_sec) =
              time_date_stamp( 6, $time ) . ' ' . time_date_stamp( 16, $time );
            ( $time, $sec ) = time_date_stamp( 9, $time );
            $display .= sprintf "%s, alt=%3d, azimuth=%s\n", $time_sec,
              @a[ 4, 5 ];

            next unless $a[4] > 20;    # We can not see them if they are too low

            # Create a seperate code file with a time_now for each event
            print MYCODE<<eof;
            if ($Dark and time_now '$time - 0:02') {
                my \$msg = "Notice: Starshine 3 satellite will have a flare in 2 minutes ";
                \$msg .= "at an altitude of $a[4], azimuth of $a[5].";
                speak "app=starshine \$msg";
                display \$msg, 600;
                set \$t_starshine_timer 120 + $sec;
            }
eof

        }
    }
    close MYCODE;
    return $display;

    do_user_file $starshine_check_e; # This will enable the code file written above (MYCODE)
}

if ( said $v_starshine_check) {
    my $state  = $v_starshine_check->{state};
    my $state2 = $state;
    $state2 = 'Brows' if $state2 eq 'Browse';
    $state2 = 'Gett'  if $state2 eq 'Get';
    start $p_starshine_check if $state eq 'Get';
    &browser($f_starshine_check) if $state eq 'Browse';
    if ( $state eq 'List' ) {
        &respond_starshine(1);
    }
    else {
        $v_starshine_check->respond(
            "app=starshine $state2" . 'ing starshine report...' );
    }
}

&respond_starshine(0) if ( done_now $p_starshine_check);

# This timer will be triggered by the timer set in the above MYCODE
$t_starshine_timer = new Timer;
my %starshine_timer_intervals = map { $_, 1 } ( 15, 30, 90 );
if ( $New_Second and my $time_left = int seconds_remaining $t_starshine_timer) {
    if ( $starshine_timer_intervals{$time_left} ) {
        my $pitch = int 10 * ( 1 - $time_left / 60 );
        speak "app=starshine pitch=$pitch $time_left seconds till flash...";
    }
}
if ( expired $t_starshine_timer) {
    speak "app=starshine pitch=10 Starshine flash now occuring!";
    play 'timer2';    # Set in event_sounds.pl
}
