
# Category = MisterHouse

#@ Display data to Alpha LED signs.  For example, the the Alpha 213C 
#@ (a.k.a. BetaBrite, 2" x 24", 14 character, local Sam's Club for $150),
#@ has multiple colors and either scrolling or fixed text.
#@ See mh/lib/Display_Alpha.pm for more info.


				# Display Time once a minute, unless busy displaying other data
$display_alpha_timer = new Timer;

if ($Reread or expired $display_alpha_timer or (new_minute and inactive $display_alpha_timer)) {
#   my $display = &time_date_stamp(21);  # 12:52 Sun 25
    my $display = &time_date_stamp(8);   # 12:52 
    $display .= ' ' . int($Weather{TempIndoor}) . ' ' . int($Weather{TempOutdoor});
    $display .= ' ' . substr($Day, 0, 1) . $Mday;
#   $display .= ' ' . substr($Day, 0, 3);
    $display .= ' ' . $Save{display_text} if $Save{display_text} and ($Time - $Save{display_time}) < 400;
    display device => 'alpha', color => 'amber', text => $display, mode => 'wipeout';
}

                 # Allow for various incoming xAP data to be displayed
$xap_monitor_display_alpha = new xAP_Item;

if ($state = state_now $xap_monitor_display_alpha) {
    my $class   = $$xap_monitor_display_alpha{'xap-header'}{class};
    print "  - xap monitor: lc=$Loop_Count class=$class state=$state\n" if $Debug{display_alpha} == 3;

    my ($text, $duration, $mode, $color);
    my $p = $xap_monitor_display_alpha;

				# Store weather data
    if ($class eq 'weather.report') {
        $Weather{WindAvgSpeed}  = $$p{'weather.report'}{windm};
        $Weather{AvgDir}        = $$p{'weather.report'}{winddirc};
        $Weather{WindGustSpeed} = $$p{'weather.report'}{windgustsm};
        $Weather{TempOutdoor}   = $$p{'weather.report'}{tempf};
        $Weather{TempIndoor}    = $$p{'weather.report'}{tempindoorf};
        $Weather{DewOutdoor}    = $$p{'weather.report'}{dewf};
        $Weather{Barom}         = $$p{'weather.report'}{airpressure};
    }
				# Echo xAP speech?
    if ($class eq 'tts.speak') {
#      $text = $$p{'tts.speak'}{say};
    }
				# Grab xAP data sent to slimserver and Alpha diplays.
				# For example, data sent by other mh boxes running code/common/display_slimserver.pl
    elsif ($class eq 'xap-osd.display') {
        if ($state =~ /display.slimp3/) {
            $text     = $$p{'display.slimp3'}{line1};
            $duration = $$p{'display.slimp3'}{duration};
            $color    = 'green';
        }
        elsif ($state =~ /display.alpha/) {
            $text     = $$p{'display.alpha'}{text};
            $mode     = $$p{'display.alpha'}{mode};
            $color    = $$p{'display.alpha'}{color};
            $duration = $$p{'display.alpha'}{duration};
        }
    }
				# Echo new music tracks (e.g. sent by slimserver)
    elsif ($class eq 'xap-audio.playlist.event' and $state =~ /now.playing/) {
        $text = $$p{'now.playing'}{artist} . ': ' . 
                $$p{'now.playing'}{title};
        $color = 'orange';
        $duration = 10;
    }
    if ($text) {
        $mode     = 'rotate' unless $mode;
        $duration = 30       unless $duration;
        set $display_alpha_timer $duration;
        display device => 'alpha', text => $text, mode => $mode, color => $color;
    }
}

				# Echo local speech to the display
&Speak_pre_add_hook(\&Display_Alpha::send_hook) if $Reload;
sub Display_Alpha::send_hook {
    my (%parms) = @_;

    return unless $parms{text};
    return if $parms{nolog};          # Do not display if we are not logging
    $parms{text} =~ s/[\n\r ]+/ /gm;  # Drop extra blanks and newlines

    $parms{mode}   = 'rotate' unless $parms{mode};
    $parms{color}  = 'yellow' unless $parms{color};
    $parms{device} = 'alpha';
    display %parms;
    set $display_alpha_timer 30;
}

my $display_alpha_modes = 'rotate,hold,flash,auto,rollup,rolldown,rollleft,rollright,' .
  'wipeup,wipedown,wipeleft,wiperight,rollup2,rainbow,auto2,' .
  'wipein,wipeout,wipein2,wipeout2,rotates';

my $display_alpha_colors = 'red,green,amber,darkred,darkgreen,brown,orange,yellow,rainbow1,rainbow2,mix,auto,off';

$display_alpha_test1 = new Voice_Cmd "Test alpha display mode [$display_alpha_modes]";
$display_alpha_test2 = new Voice_Cmd "Test alpha display color [$display_alpha_colors]";

display device => 'alpha', text => "Testing alpha mode $state",  mode  => $state if $state = said $display_alpha_test1;
display device => 'alpha', text => "Testing alpha color $state", color => $state if $state = said $display_alpha_test2;

