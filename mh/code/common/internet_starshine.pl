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

$starshine_check = new Voice_Cmd '[get,list,browse] starshine flares';
$starshine_check ->set_info('Lists times and locations of visible starshine 3 satellite passes');

run_voice_cmd 'get starshine flares' if $New_Week;

                                # Their web site uses dorky Time Zone strings,
                                # so use UCT (GMT+0) and translate.
my $starshine_check_e = "$config_parms{code_dir}/starshine_check_events.pl";
my $starshine_check_f = "$config_parms{data_dir}/web/starshine.html";
my $starshine_check_u = "http://www.heavens-above.com/PassSummary.asp?" . 
                      "lat=$config_parms{latitude}&lng=$config_parms{longitude}&alt=0&TZ=UCT&satid=26929";
$starshine_check_p = new Process_Item qq[get_url "$starshine_check_u" "$starshine_check_f"];
#$starshine_check_p = new Process_Item "get_url '$starshine_check_u' '$starshine_check_f'";

$state = said $starshine_check;
start   $starshine_check_p if $state eq 'get';
browser $starshine_check_f if $state eq 'browse';

if (done_now $starshine_check_p or $state eq 'list') {
    my ($display, $time, $sec, $time_sec);
    my $html = file_read $starshine_check_f;
                                # Add a base href, so we can click on links
    $html =~ s|</head>|\n<BASE href='http://www.heavens-above.com/'>|i;
    file_write $starshine_check_f, $html;

    my $text = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($html));
    open(MYCODE, ">$starshine_check_e") or print_log "Error in writing to $starshine_check_e";
    for (split "\n", $text) {
        if (/^\d{2}\s\S{3}\s/) {
            my @a = split;
            $time = my_str2time("$a[1]/$a[0] $a[3]") + 3600*$config_parms{time_zone};
            $time += 3600 if (localtime)[8]; # Adjust for daylight savings time
            ($time_sec)   = time_date_stamp(6, $time) . ' ' . time_date_stamp(16, $time);
            ($time, $sec) = time_date_stamp(9, $time);
            $display .= sprintf "%s, alt=%3d, azimuth=%s\n", $time_sec, @a[4,5];

            next unless $a[4] > 20; # We can not see them if they are too low

                                # Create a seperate code file with a time_now for each event
            print MYCODE<<eof;
            if ($Dark and time_now '$time - 0:02') {
                my \$msg = "Notice: Starshine 3 satellite will have a flare in 2 minutes ";
                \$msg .= "at an altitude of $a[4], azimuth of $a[5].";
                speak "app=timer \$msg";
                display \$msg, 600;
                set \$starshine_timer 120 + $sec;
            }
eof

        }
    }
    close MYCODE;
    display $display, 0, 'Starshine list', 'fixed';
#   display $starshine_check_e;
    do_user_file $starshine_check_e; # This will enable the above MYCODE 
}

                                # This timer will be triggered by the timer set in the above MYCODE
$starshine_timer = new Timer;
my %starshine_timer_intervals = map {$_, 1} (15,30,90);
if ($New_Second and my $time_left = int seconds_remaining $starshine_timer) {
    if ($starshine_timer_intervals{$time_left}) {
        my $pitch = int 10*(1 - $time_left/60);
        speak "app=timer pitch=$pitch $time_left seconds till flash";
    }
}
if (expired $starshine_timer) {
    speak "app=timer pitch=10 Starshine flash now occuring";
    play 'timer2';              # Set in event_sounds.pl
}

