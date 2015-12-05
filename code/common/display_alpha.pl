
# Category = MisterHouse
# $Date$
# $Revision$

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

use vars '$mh_volume'
  ; #(From status line Web script) In case mh_sound is not running ( *** Should use eval to trap errors here, rather than declaring the var)

# noloop=start
my $now_playing;   #last displayed song title
my $player_mode;   #last reported mode
my $timer_set_by;  #app that last set the display timer
my $temp_flag;     # alternates between indoor and outdoor temperatures on clock

# noloop=stop

# Voice commands

$display_alpha_test1 = new Voice_Cmd
  "Test alpha display mode [hold,flash,rollup,rolldown,rollleft,rollright,wipeup,wipedown,wipeleft,wiperight,rollup2,auto,wipein2,wipeout2,wipein,wipeout,rotates,explode,clock,sparkle,twinkle,snow,interlock,switch,slide,spray,starburst,welcome,slotmachine,newsflash,trumpet,cyclecolors,thankyou,nosmoking,dontdrinkanddrive,runninganimal,fireworks,turbocar,cherrybomb]";
$display_alpha_test1->set_info('Tests alphanumeric display modes');
$display_alpha_test2 = new Voice_Cmd
  "Test alpha display color [red,green,amber,darkred,darkgreen,brown,orange,yellow,rainbow1,rainbow2,mix,auto]";
$display_alpha_test2->set_info('Tests alphanumeric display colors');
$display_alpha_test3 =
  new Voice_Cmd "Test alpha display font [small,large,fancy]";
$display_alpha_test3->set_info('Tests alphanumeric display fonts');

if ($Reload) {

    # *** Only hook up if each is configured properly (and user wants to hook these into sign)

    &AOLim_Message_add_hook( \&display_im_message );
    &MSNim_Message_add_hook( \&display_im_message );
    &Jabber_Message_add_hook( \&display_im_message );
    &ICQim_Message_add_hook( \&display_im_message );

    &AOLim_Status_add_hook( \&display_im_status );
    &MSNim_Status_add_hook( \&display_im_status );
    &Jabber_Presence_add_hook( \&display_im_status );
    &ICQim_Status_add_hook( \&display_im_status );

    &AOLim_Disconnected_add_hook( \&display_AOLim_disconnect );
    &ICQim_Disconnected_add_hook( \&display_ICQim_disconnect );

}

sub set_display_timer {
    my ( $seconds, $setby ) = @_;

    set $display_alpha_timer $seconds;
    $timer_set_by = $setby;
}

# TODO: Need to queue discarded messages

sub display_im_message {
    my ( $from, $text, $pgm ) = @_;

    if ( &can_interrupt('im') ) {

        #&display('wait=1 speed=faster device=alpha image=space3 mode=sparkle font=small .');
        #&display('wait=1 speed=faster device=alpha image=space2 font=small .');
        #&display('wait=1 device=alpha image=space mode=sparkle font=small .');
        &display( "device=alpha mode=sparkle app="
              . ( ( lc($pgm) eq 'aol' ) ? 'aim' : lc($pgm) )
              . " $from:\x1c2$text" );
        &set_display_timer( 10, 'im' );
    }
}

sub display_im_status {
    my ( $user, $status, $status_old, $pgm ) = @_;
    if (    &can_interrupt('im')
        and $status ne $status_old
        and $user ne $config_parms{net_aim_name} )
    {
        &display( "device=alpha app="
              . ( ( lc($pgm) eq 'aol' ) ? 'aim' : lc($pgm) )
              . " $user $status" );
        &set_display_timer( 10, 'im' );
    }
}

sub display_AOLim_disconnect {
    &display("device=alpha app=aol mode=flash AOL Disconnected");
    set_display_timer 10, 'im';
}

sub display_ICQim_disconnect {
    &display("device=alpha app=icq mode=flash ICQ Disconnected");
    set_display_timer 10, 'im';
}

sub can_interrupt {    # apps can interrupt their own messages only
    $_ = shift;
    return ( ( inactive $display_alpha_timer) or $_ eq $timer_set_by );
}

# 15 detents (0-9,A-E)

sub volume_image {
    my $volume = shift;
    return 'volum' . lc( sprintf( "%01x", int( $volume / 7 ) ) )
      if defined $volume;
}

# called every minute by trigger (disable for custom clock/status app)

sub update_clock {

    if ( inactive $display_alpha_timer) {
        my $display;
        my $freq = 15;    # status update every fifteen minutes by default

        $freq = $config_parms{Display_Alpha_clock_update_freq}
          if $config_parms{Display_Alpha_clock_update_freq};

        #   my $display = &time_date_stamp(21);  # 12:52 Sun 25
        $display = &time_date_stamp(8);    # 12:52
        my $font = 'small';

        # Allow for older format, displaying indoor/outdoor at the same time
        if ( $config_parms{Display_Alpha_clock_format} == 1 ) {
            $display = &time_date_stamp(8);    # 12:52
            $display .= ' '
              . int( $Weather{TempIndoor} ) . ' '
              . int( $Weather{TempOutdoor} );

            #	$display .= ' ' . int($Weather{HumidOutdoor}) if defined $Weather{HumidOutdoor};
            $display .= ' ' . substr( $Day, 0, 1 ) . $Mday;
            $display .= ' ' . $Save{display_text}
              if $Save{display_text} and ( $Time - $Save{display_time} ) < 400;
            $font = 'large';
        }
        else {
            $display .= ' ' . substr( $Day, 0, 2 ) . " " . $Mday;

            if (    defined $Weather{TempIndoor}
                and defined $Weather{TempOutdoor} )
            {
                # *** truncuate to integer or it won't fit!
                my $color = '4';
                $color = '7' if $Weather{TempOutdoor} < 80;
                $color = '2' if $Weather{TempOutdoor} < 60;

                $display .=
                    ($temp_flag)
                  ? ( " \x1c7\x1a5" . int( $Weather{TempIndoor} + .5 ) )
                  : ( " \x1c$color\x1a5" . int( $Weather{TempOutdoor} + .5 ) );
                $temp_flag = !$temp_flag;
            }
            else {
                if ( defined $Weather{TempIndoor} ) {  # Can fit one temperature
                    $display .= " \x1c7\x1a5"
                      . int( $Weather{TempIndoor} + .5 )
                      ;    # '\x1c7' is inline code for color 7
                }
                elsif ( defined $Weather{TempOutdoor} ) {
                    my $color = '4';
                    $color = '2' if $Weather{TempOutdoor} < 80;
                    $display .=
                      " \x1c$color\x1a5" . int( $Weather{TempOutdoor} + .5 );
                }
            }
        }

        #   $display .= ' ' . substr($Day, 0, 3);
        $display .= ' ' . $Save{display_text}
          if $Save{display_text} and ( $Time - $Save{display_time} ) < 400;

        if ( new_minute and !( $Minute % $freq ) )
        { #display optional extra info every n minutes (and not when clock is forced after timer!)

            my $options =
              ( $config_parms{Display_Alpha_clock_options} )
              ? $config_parms{Display_Alpha_clock_options}
              : 'sun,mode,volume,playing,temp,tv,news,stocks,weather,email,demo';
            my @parms = split ',', $options;

            for my $parm (@parms) {
                if ( $parm =~ /sun/ ) {
                    if ( $parm eq 'sun' ) {
                        $parm = (
                                 time_less_than "$Time_Sunrise + 2:00"
                              or time_greater_than "$Time_Sunset  + 2:00"
                        ) ? 'sunrise' : 'sunset';
                    }
                    if ( $parm eq 'sunrise' ) {
                        &display(
                            "wait=1 device=alpha app=sunrise image=sunset Rise $Time_Sunrise"
                        );
                        &display(
                            "wait=1 device=alpha app=sunrise Rise $Time_Sunrise"
                        );
                    }
                    else {
                        &display(
                            "wait=1 device=alpha app=sunset image=sunrise Set $Time_Sunset"
                        );
                        &display(
                            "wait=1 device=alpha app=sunset Set $Time_Sunset");
                    }

                    #display(device=>'alpha', speed=>'faster', mode=>'hold', image=>'sunrise', wait => 1, font=>'small', text=>"Sunset $Time_Sunset");
                    #display(device=>'alpha', mode=>'hold', image=>'sunrise2', wait => 1, font=>'small', text=>"Sunset $Time_Sunset");
                    #display(device=>'alpha', mode=>'hold', image=>'sunset', font=>'small', text=>"Sunset $Time_Sunset")

                }
                elsif ( $parm eq 'mode' ) {
                    if ( $Save{mode} ne 'normal' ) {
                        &display(
                            "wait=1 device=alpha image=house color=red mode=flash app=mode $Save{mode} mode"
                        );
                    }
                    else {
                        &display(
                            "wait=1 device=alpha image=house app=mode Normal mode"
                        );
                    }
                    if ( $mode_security->{state} eq 'armed' ) {
                        &display(
                            "wait=1 device=alpha color=red mode=flash app=security Security armed"
                        );
                    }
                    else {
                        &display(
                            "wait=1 device=alpha app=security Security unarmed"
                        );
                    }
                    if ( $mode_sleeping->{state} ne 'nobody' ) {
                        &display(
                            "wait=1 device=alpha color=red mode=flash app=security "
                              . ucfirst( $mode_sleeping->{state} )
                              . " are asleep" );
                    }
                }
                elsif ( $parm eq 'im' ) {
                    if ($oscar::aim_connected) {
                        &display(
                            "wait=1 device=alpha app=aol Connected to AOL");
                    }
                    if ($oscar::icq_connected) {
                        &display(
                            "wait=1 device=alpha app=icq Connected to ICQ");
                    }
                }
                elsif ( $parm eq 'volume' ) {

                    if ($mh_volume) {
                        my $sl_vol    = state $mh_volume;
                        my $vol_image = &volume_image($sl_vol);

                        &display(
                            "wait=1 device=alpha app=volume image=$vol_image Volume: $sl_vol"
                        ) if defined $sl_vol;
                    }

                }

                elsif ( $parm eq 'playing' ) {

                    if ( $Save{NowPlayingPlaylist} ) {
                        my $playlist = $Save{NowPlayingPlaylist};
                        $playlist =~ s/_/\x20/;
                        &display(
                            "wait=1 device=alpha app=music Playlist: $playlist"
                        );
                    }

                    my $playing = $Save{NowPlaying};

                    if ($playing) {

                        my ( $artist, $song ) = $playing =~ /(.*) - (.*)/;
                        $song = $playing unless $song;

                        if ( $Save{mp3_mode} == 1 ) {    #playing
                            &display(
                                "wait=1 device=alpha app=music image=play $song"
                            );
                        }
                        elsif ( $Save{mp3_mode} == 3 ) {    #paused
                            &display(
                                "wait=1 device=alpha app=music image=pause $song"
                            );
                        }
                        elsif ( $Save{mp3_mode} == 0 ) {    #stopped
                            &display(
                                "wait=1 device=alpha app=music image=stop $song"
                            );
                        }
                        &display("wait=1 device=alpha mode=auto $artist")
                          if $artist;
                    }

                    use vars '$dvd_marquee'
                      ;    # In case no DVD-ROM or player installed/configured
                    use vars '$dvd_player'
                      ;    # In case no DVD-ROM or player installed/configured

                    # *** Test without dvd module loaded!

                    if ($dvd_player) {
                        my $movie;
                        if ( my $title = $dvd_player->get_title() ) {
                            $movie = $title;
                        }
                        elsif ($dvd_marquee) {
                            $movie = $dvd_marquee->{state};

                        }
                        &display("wait=1 device=alpha app=movie $movie")
                          if $movie;
                    }

                }
                elsif ( $parm eq 'email' ) {
                    &display(
                        "wait=1 device=alpha app=email Email: $Save{email_flag}"
                    ) if $Save{email_flag};
                }
                elsif ( $parm eq 'weather' ) {

                    # *** Need to record/check time stamp on warning
                    &display(
                        wait   => 1,
                        device => 'alpha',
                        app    => 'weather',
                        mode   => 'auto',
                        image  => 'warning',
                        color  => 'red',
                        text   => "WARNING: $Weather{Warning}"
                      )
                      if $Weather{Warning}
                      and $Weather{Warning} !~ /adjusted/i
                      and $Weather{Warning} !~ /updated/i
                      and $Weather{Warning} !~ /removed/i;
                    &display(
                        "wait=1 device=alpha app=weather $Weather{Summary_Short}"
                    ) if $Weather{Summary_Short};
                    &display(
                        "wait=1 device=alpha app=weather $Weather{chance_of_rain}"
                    ) if $Weather{chance_of_rain};
                }
                elsif ( $parm eq 'news' ) {
                    &display(
                        "wait=1 device=alpha app=news $Save{news_ap_headline}")
                      if $Save{news_ap_headline};
                }
                elsif ( $parm eq 'stocks' ) {
                    &display(
                        "wait=1 device=alpha app=stocks $Save{stock_data1} $Save{stock_data2}"
                    ) if $Save{stock_data1};
                }
                elsif ( $parm eq 'tv' ) {
                    &display("wait=1 device=alpha app=tv $Save{tv_favorites}")
                      if $Save{tv_favorites};
                }
                elsif ( $parm eq 'temp' ) {
                    &display( 'wait=1 device=alpha app=temperature In: '
                          . int( $Weather{TempIndoor} )
                          . ' Out: '
                          . int( $Weather{TempOutdoor} ) )
                      if defined $Weather{TempOutdoor}
                      and defined $Weather{TempIndoor};
                }
                elsif ( $parm eq 'holiday' ) {
                    &display(
                        "wait=1 device=alpha app=holiday Today is $Holiday");
                }
                elsif ( $parm eq 'demo' )
                { # useless stuff to pad out default sequence (looks stupid if there aren't enough info providers)
                    &display(
                        "wait=1 device=alpha mode=nosmoking font=small It's bad for me"
                    );
                    &display(
                        "wait=1 device=alpha app=games mode=slotmachine Play again in $freq minutes"
                    );
                    &display(
                        "wait=1 device=alpha app=control mode=fireworks Misterhouse is cool!"
                    );
                }

            }
            set_display_timer 60,
              undef;    # *** Need heuristic here (60 may not be appropriate!)
        }
        display
          device => 'alpha',
          text   => $display,
          app    => 'clock',
          font   => $font;
    }
}

&update_clock()
  if
  expired $display_alpha_timer; #will step on messages sent from other modules (logic belongs in pm)

# Allow for various incoming xAP data to be displayed
# *** xAP monitoring of weather data belongs in its own module!
# *** Does not rely on (or even involve) a Beta Brite!
$xap_monitor_display_alpha = new xAP_Item;

if ( $state = state_now $xap_monitor_display_alpha) {
    my $class = $$xap_monitor_display_alpha{'xap-header'}{class};
    print "  - xap monitor: lc=$Loop_Count class=$class state=$state\n"
      if $Debug{display_alpha} == 3;

    my ( $text, $duration, $mode, $color );
    my $p = $xap_monitor_display_alpha;

    # Store weather data
    # *** This needs to go (see above)
    if ( $class eq 'weather.report' ) {
        $Weather{WindAvgSpeed}  = $$p{'weather.report'}{windm};
        $Weather{AvgDir}        = $$p{'weather.report'}{winddirc};
        $Weather{WindGustSpeed} = $$p{'weather.report'}{windgustsm};
        $Weather{TempOutdoor}   = $$p{'weather.report'}{tempf};
        $Weather{TempIndoor}    = $$p{'weather.report'}{tempindoorf};
        $Weather{HumidOutdoor}  = $$p{'weather.report'}{humidf};
        $Weather{HumidIndoor}   = $$p{'weather.report'}{humidindoorf};
        $Weather{DewOutdoor}    = $$p{'weather.report'}{dewf};
        $Weather{Barom}         = $$p{'weather.report'}{airpressure};
    }

    # Echo xAP speech?
    # *** Also belongs elsewhere
    if ( $class eq 'tts.speak' ) {

        #      $text = $$p{'tts.speak'}{say};
    }

    # Grab xAP data sent to slimserver and Alpha diplays.
    # For example, data sent by other mh boxes running code/common/display_slimserver.pl
    elsif ( $class eq 'xap-osd.display' ) {
        if ( $state =~ /display.slimp3/ ) {
            $text     = $$p{'display.slimp3'}{line1};
            $duration = $$p{'display.slimp3'}{duration};
            $color    = 'green';
        }
        elsif ( $state =~ /display.alpha/ )
        {    # *** What module sends these packets?
            $text     = $$p{'display.alpha'}{text};
            $mode     = $$p{'display.alpha'}{mode};
            $color    = $$p{'display.alpha'}{color};
            $duration = $$p{'display.alpha'}{duration};
        }
    }

    # Echo new music tracks (e.g. sent by slimserver)
    elsif ( $class eq 'xap-audio.playlist.event' and $state =~ /now.playing/ ) {
        $text  = $$p{'now.playing'}{artist} . ': ' . $$p{'now.playing'}{title};
        $color = 'orange';
        $duration = 10;
    }
    if ($text) {
        $mode     = 'rotate' unless $mode;
        $duration = 45       unless $duration;
        set $display_alpha_timer $duration;
        display
          device => 'alpha',
          text   => $text,
          mode   => $mode,
          color  => $color;
    }
}

sub Display_Alpha::send_hook {
    my (%parms) = @_;

    my $duration;

    return unless $parms{text};
    return if $parms{nolog};    # Do not display if we are not logging
    $parms{text} =~ s/[\n\r ]+/ /gm;    # Drop extra blanks and newlines
    $parms{device} = 'alpha';

    # Add defaults if missing (sign defaults to red and big text)
    # App parameter defeats this as it may have its own mode and color
    # *** Move this to display_alpha in pm

    $parms{color} = 'amber'   unless $parms{color} or $parms{app};
    $parms{mode}  = 'rotates' unless $parms{mode}  or $parms{app};

    delete $parms{mode}
      if $parms{mode} eq 'unmuted'
      or $parms{mode} eq 'mute'
      or $parms{mode} eq 'normal';

    display %parms;

    # Do not display clock until message has been displayed for a minimum number of seconds

    # Duration parameter is not associated with apps (must pass explicitly)
    # Probably should peek at the app parameters here

    $duration = $parms{duration};
    $duration = $config_parms{Display_Alpha_echo_duration} unless $duration;
    $duration = 45 unless $duration;    #default is 45 seconds

    set_display_timer $duration,
      undef;    #keeps the clock from overwriting the message too quickly
}

if ( $state = said $display_alpha_test1) {
    if (
        $config_parms{Display_Alpha_type} eq 'old'
        and (  $state eq 'clock'
            or $state eq 'explode'
            or $state eq 'twinkle'
            or $state eq 'newsflash'
            or $state eq 'cyclecolors' )
      )
    {
        respond
          "This mode does not work on older displays. Default display should be in $state mode.";
    }
    else {
        respond "Default display should be in $state mode.";
    }
    display device => 'alpha', text => "Testing mode $state", mode => $state;

}

if ( $state = said $display_alpha_test2) {
    respond "Default display should be in $state.";
    display device => 'alpha', text => "Testing color $state", color => $state;

}

if ( $state = said $display_alpha_test3) {
    respond "Default display should be in $state font.";
    display
      device => 'alpha',
      text =>
      "Testing font $state !@#$%^&*()0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
      font => $state;

}

# Trigger to update clock

if ($Reload) {
    &trigger_set( 'new_minute', '&update_clock', 'NoExpire',
        'update alpha clock' )
      unless &trigger_get('update alpha clock');
}

# The bookend for this is in display_alpha.pm (one should be moved)

if ($Startup) {
    display( device => 'alpha', text => 'System restarted', app => 'startup' );
    set $display_alpha_timer 7
      ;    # set timer here as this does not go through speech hook
}

# Echo local speech to the display

&Speak_pre_add_hook( \&Display_Alpha::send_hook ) if $Reload;

# check for new song (this really belongs in a second trigger)

if (    &can_interrupt('music')
    and $Save{NowPlaying}
    and
    ( $now_playing ne $Save{NowPlaying} or $player_mode != $Save{mp3_mode} ) )
{
    if ( $Save{mp3_mode} == 1 ) {    #playing
        my $playing = $Save{NowPlaying};
        my ( $artist, $song ) = $playing =~ /(.*) - (.*)/;
        $song = $playing unless $song;

        if ($artist) {
            &display(
                device => 'alpha',
                app    => 'music',
                text   => $song,
                wait   => 1
            );
            &display("device=alpha font=small mode=auto $artist");
        }
        else {
            &display(
                device => 'alpha',
                app    => 'control',
                image  => 'play',
                text   => $song
            );
        }
        &set_display_timer( 12, 'music' );   #show new song title for 12 seconds
    }
    $now_playing = $Save{NowPlaying};
    $player_mode = $Save{mp3_mode};
}

my %da_data;                                 # noloop

if (    &can_interrupt('email')
    and $Save{email_flag}
    and ( $da_data{email_flag} ne $Save{email_flag} ) )
{

    $da_data{email_flag} = $Save{email_flag}
      unless defined $da_data{email_flag};
    my $email_msg;

    if ( $da_data{email_flag} =~ /^[ \d]+$/ ) {
        if ( $da_data{email_flag} < $Save{email_flag} ) {    #You have mail!
            $email_msg =
                'You have '
              . ( $Save{email_flag} )
              . ' email message'
              . ( ( $Save{email_flag} > 1 ) ? 's' : '' );
        }
    }
    else {    # Allow for non-numeric email flags
        if (    $da_data{email_flag}
            and $da_data{email_flag} ne $Save{email_flag} )
        {
            $email_msg = $da_data{email_flag};
        }
    }
    if ($email_msg) {
        &display( device => 'alpha', app => 'email', text => $email_msg );
        &set_display_timer( 12, 'email' );  #show new email count for 12 seconds
    }

    $da_data{email_flag} = $Save{email_flag};
}

if (    &can_interrupt('news')
    and $Save{news_ap_headline}
    and ( $da_data{news_headline} ne $Save{news_ap_headline} ) )
{

    # Only show when it changes (not on reload of module.)

    if ( defined $da_data{news_headline} ) {    #News flash!
        &display(
            device => 'alpha',
            app    => 'news',
            text   => $Save{news_ap_headline}
        );
        &set_display_timer( 30, 'news' );
    }

    $da_data{news_headline} = $Save{news_ap_headline};
}

if ( $Weather{Warning} and ( $da_data{weather_warning} ne $Weather{Warning} ) )
{

    if (    $da_data{weather_warning} ne $Weather{Warning}
        and $Weather{Warning} !~ /updated/i
        and $Weather{Warning} !~ /adjusted/i
        and $Weather{Warning} !~ /removed/i )
    {
        &display(
            device => 'alpha',
            app    => 'weather',
            color  => 'red',
            image  => 'warning',
            text   => "WARNING: $Weather{Warning}"
        );
        &set_display_timer( 60, 'weather' );
    }

    $da_data{weather_warning} = $Weather{Warning};
}

if ( $Info{barcode_data} and ( $da_data{barcode} ne $Info{barcode_data} ) ) {
    $da_data{barcode} = $Info{barcode_data};
    &display( device => 'alpha', app => 'scanner', text => $da_data{barcode} );
    &set_display_timer( 5, 'barcode' );

}

if ( $state = state_now $mh_volume)
{    # *** Oops tk slider widget not setting state
    my $sl_vol    = state $mh_volume;
    my $vol_image = &volume_image($sl_vol);

    # only show when it changes

    &display("device=alpha app=volume image=$vol_image Volume: $sl_vol");
    &set_display_timer( 5, undef );
}

