
# Category = MisterHouse

#@ Display a clock and status information on and echoes speech to AlphaNet Alphanumeric LED signs.  For example, the the Alpha 213C
#@ (aka Beta Brite, 2" x 24", 14 character, available at Sam's Club around $150),
#@ has multiple colors and either scrolling or fixed text.
#@ See mh/lib/Display_Alpha.pm for more info.
#@
#@ Optional configuration parameters:
#@
#@ Display_Alpha_clock_update_freq = (in minutes, default 15) controls how often status info is displayed
#@ Display_Alpha_clock_options = commma-delimited list of information provider names (defined in this module.)  Default is all currently available options: sun,mode,playing,email,weather,temp,demo

# Display duration timer

$display_alpha_timer = new Timer;

# These are used to report new songs
# Works with apps that set $Save{NowPlaying}
# Optionally set $Save{mp3_mode} to display player mode (mp3_winamp does this currently)

# noloop=start
my $now_playing; #last displayed song title
my $player_mode; #last reported mode
my $timer_set_by; #app that last set the display timer
# noloop=stop

# Voice commands

$display_alpha_test1 = new Voice_Cmd "Test alpha display mode [hold,flash,rollup,rolldown,rollleft,rollright,wipeup,wipedown,wipeleft,wiperight,rollup2,auto,wipein2,wipeout2,wipein,wipeout,rotates,explode,clock,sparkle,twinkle,snow,interlock,switch,slide,spray,starburst,welcome,slotmachine,newsflash,trumpet,cyclecolors,thankyou,nosmoking,dontdrinkanddrive,runninganimal,fireworks,turbocar,cherrybomb]";
$display_alpha_test1->set_info('Tests alphanumeric display modes');
$display_alpha_test2 = new Voice_Cmd "Test alpha display color [red,green,amber,darkred,darkgreen,brown,orange,yellow,rainbow1,rainbow2,mix,auto]";
$display_alpha_test2->set_info('Tests alphanumeric display colors');
$display_alpha_test3 = new Voice_Cmd "Test alpha display font [small,large,fancy]";
$display_alpha_test3->set_info('Tests alphanumeric display fonts');

sub can_interrupt { # apps can interrupt their own messages only
	$_ = shift;
	return ((inactive $display_alpha_timer) or $_ eq $timer_set_by);	
}

sub set_timer2 {
	my ($seconds, $setby) = @_;

	set $display_alpha_timer $seconds;
	$timer_set_by = $setby;	
}

# called every minute by trigger (disable for custom clock/status app)

sub update_clock {

 if (inactive $display_alpha_timer) {
  my $display;
  my $freq = 15; # status update every fifteen minutes by default

  $Weather{TempIndoor} = 72;
  $Weather{TempOutdoor} = 52;

    $freq = $config_parms{Display_Alpha_clock_update_freq} if $config_parms{Display_Alpha_clock_update_freq};



#   my $display = &time_date_stamp(21);  # 12:52 Sun 25
    $display = &time_date_stamp(8);   # 12:52
    $display .= ' ' . substr($Day, 0, 2) . " " . $Mday;
    if (defined $Weather{TempIndoor}) { # Can fit one temperature
        $display .= " \x1c7\x1a5$Weather{TempIndoor}"; # '\x1c7' is inline code for color 7
    }
    elsif (defined $Weather{TempOutdoor}) {
        $display .= " \x1c2\x1a5$Weather{TempOutdoor}";
    }
#   $display .= ' ' . substr($Day, 0, 3);
    $display .= ' ' . $Save{display_text} if $Save{display_text} and ($Time - $Save{display_time}) < 400;


  if (new_minute and !($Minute % $freq)) { #display optional extra info every n minutes (and not when clock is forced after timer!)

	my $options = ($config_parms{Display_Alpha_clock_options})?$config_parms{Display_Alpha_clock_options}:'sun,mode,playing,email,weather,temp,demo';
	my @parms = split ',', $options;

	for my $parm (@parms) {
		if ($parm =~ /sun/) {
			if ($parm eq 'sun') {
            			$parm = (time_less_than "$Time_Sunrise + 2:00" or
                     		time_greater_than "$Time_Sunset  + 2:00") ? 'sunrise' : 'sunset';
        		}
        		if ($parm eq 'sunrise') {
            			&display("wait=1 device=alpha app=sunrise Sunrise $Time_Sunrise");
        		}
        		else {
            			&display("wait=1 device=alpha app=sunset Sunset $Time_Sunset");
        		}
			
			
		}
		elsif ($parm eq 'mode') {
			if ($Save{mode} ne 'normal') {
         			&display("wait=1 device=alpha image=house color=red mode=flash app=mode $Save{mode} mode");
        		}
		        else {
         			&display("wait=1 device=alpha image=house app=mode Normal mode");
		        }
			if ($mode_security->{state} eq 'armed') {
         			&display("wait=1 device=alpha color=red mode=flash app=security Security armed");
        		}
		        else {
         			&display("wait=1 device=alpha app=security Security unarmed");
		        }
			if ($mode_sleeping->{state} eq 'nobody') {
         			&display("wait=1 device=alpha color=red mode=flash app=security " . ucfirst($mode_sleeping->{state}) . " are asleep");
        		}

			use vars '$mh_volume';  #(From status line Web script) In case mh_sound is not running ( *** Should use eval to trap errors here, rather than declaring the var)
		        if ($mh_volume) {
		        	my $sl_vol = state $mh_volume;
         			&display("wait=1 device=alpha app=sound Volume: $sl_vol") if $sl_vol;
		        }
		}
		elsif ($parm eq 'playing') {

			if ($Save{NowPlayingPlaylist}) {
				&display("wait=1 device=alpha app=music Playlist: $Save{NowPlayingPlaylist}");
			}

			my $playing = $Save{NowPlaying};
			$playing =~ s/(.*) - (.*)/$2 $1/;


			if ($playing) {
				if ($Save{mp3_mode} == 1) { #playing
					&display("wait=1 device=alpha app=music image=play $playing");
				}
				elsif ($Save{mp3_mode} == 3) {
					&display("wait=1 device=alpha app=music image=pause $playing");	
				}
				elsif ($Save{mp3_mode} == 0) {
					&display("wait=1 device=alpha app=music image=stop $playing");
				}
			}
		}
		elsif ($parm eq 'email') {
			&display("wait=1 device=alpha app=email Email: $Save{email_flag}") if $Save{email_flag};
		}
		elsif ($parm eq 'weather') {
			&display("wait=1 device=alpha app=weather $Weather{Summary_Short}") if $Weather{Summary_Short};
		}
		elsif ($parm eq 'temp') {
		        &display ('wait=1 device=alpha app=temperature In: ' . int($Weather{TempIndoor}) . ' Out: ' . int($Weather{TempOutdoor})) if defined $Weather{TempOutdoor} and defined $Weather{TempIndoor};		}
		elsif ($parm eq 'holiday') {
			&display("wait=1 device=alpha app=holiday Today is $Holiday");	
		}		
		elsif ($parm eq 'demo') { # useless stuff to pad out default sequence (looks stupid if there aren't enough info providers)
			&display("wait=1 device=alpha mode=nosmoking font=small It's bad for me");
			&display("wait=1 device=alpha app=games mode=slotmachine Play again in $freq minutes");
			&display("wait=1 device=alpha app=control mode=fireworks Misterhouse is cool!");		
		}

	
	}
    set $display_alpha_timer 60;	
  }

    display device => 'alpha', text => $display, app => 'clock';	



 }
}

&update_clock() if expired $display_alpha_timer; #will step on messages sent from other modules (logic belongs in pm)

                 # Allow for various incoming xAP data to be displayed
		 # *** xAP monitoring of weather data belongs in its own module!
		 # *** Does not rely on (or even involve) a Beta Brite!
$xap_monitor_display_alpha = new xAP_Item;

if ($state = state_now $xap_monitor_display_alpha) {
    my $class   = $$xap_monitor_display_alpha{'xap-header'}{class};
    print "  - xap monitor: lc=$Loop_Count class=$class state=$state\n" if $Debug{display_alpha} == 3;

    my ($text, $duration, $mode, $color);
    my $p = $xap_monitor_display_alpha;

				# Store weather data
				# *** This needs to go (see above)
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
				# *** Also belongs elsewhere
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
        elsif ($state =~ /display.alpha/) { # *** What module sends these packets?
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
        $duration = 45       unless $duration;
        set $display_alpha_timer $duration;
        display device => 'alpha', text => $text, mode => $mode, color => $color;
    }
}


sub Display_Alpha::send_hook {
    my (%parms) = @_;

    my $duration;

    return unless $parms{text};
    return if $parms{nolog};          # Do not display if we are not logging
    $parms{text} =~ s/[\n\r ]+/ /gm;  # Drop extra blanks and newlines
    $parms{device} = 'alpha';

    # Add defaults if missing (sign defaults to red and big text)
    # App parameter defeats this as it may have its own mode and color
    # *** Move this to display_alpha in pm

    $parms{color} = 'amber' unless $parms{color} or $parms{app};
    $parms{mode} = 'rotates' unless $parms{mode} or $parms{app};

    delete $parms{mode} if $parms{mode} eq 'unmuted' or $parms{mode} eq 'mute' or $parms{mode} eq 'normal';

    display %parms;

    # Do not display clock until message has been displayed for a minimum number of seconds

    # Duration parameter is not associated with apps (must pass explicitly)
    # Probably should peek at the app parameters here

    $duration = $parms{duration};
    $duration = $config_parms{Display_Alpha_echo_duration} unless $duration;
    $duration = 45 unless $duration; #default is 45 seconds

    set $display_alpha_timer $duration; #keeps the clock from overwriting the message too quickly
}

if ($state = said $display_alpha_test1) {
	if ($config_parms{Display_Alpha_type} eq 'old' and ($state eq 'clock' or $state eq 'explode' or $state eq 'twinkle' or $state eq 'newsflash' or $state eq 'cyclecolors')) {
		respond "This mode does not work on older displays. Default display should be in $state mode.";	
	}
	else {
		respond "Default display should be in $state mode.";
	}
	display device => 'alpha', text => "Testing mode $state", mode  => $state;

}

if ($state = said $display_alpha_test2) {
	respond "Default display should be in $state.";
	display device => 'alpha', text => "Testing color $state", color => $state;

}

if ($state = said $display_alpha_test3) {
	respond "Default display should be in $state font.";
	display device => 'alpha', text => "Testing font $state !@#$%^&*()0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", font => $state;

}


# Trigger to update clock

if ($Reload and $Run_Members{'trigger_code'}) {
	eval qq(
		&trigger_set('new_minute', '\&update_clock', 'NoExpire', 'update alpha clock') unless &trigger_get('update alpha clock');
	);
}

# The bookend for this is in display_alpha.pm (one should be moved)

if ($Startup) {
	display(device=> 'alpha', text => 'System restarted', app => 'startup'); 
        set $display_alpha_timer 7; # set timer here as this does not go through speech hook
}

# Echo local speech to the display

&Speak_pre_add_hook(\&Display_Alpha::send_hook) if $Reload;

# check for new song (this really belongs in a second trigger)

if (&can_interrupt('music') and $Save{NowPlaying} and ($now_playing ne $Save{NowPlaying} or $player_mode != $Save{mp3_mode})) {
	if ($Save{mp3_mode} == 1) { #playing
		my $playing = $Save{NowPlaying};
		$playing =~ s/(.*) - (.*)/$2 $1/;

		&display(device=>'alpha', app=>'music', text=>$playing);
	        &set_timer2(12, 'music'); #show new song title for 12 seconds
	}
	$now_playing = $Save{NowPlaying};
	$player_mode = $Save{mp3_mode};
}
