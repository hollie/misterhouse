
#@ Auto-generated from code/common/internet_iridium.pl

        if ($New_Second and my $time_left = int seconds_remaining $iridium_timer) {
          my %iridium_timer_intervals = map {$_, 1} (15,30,90);
          if ($iridium_timer_intervals{$time_left}) {
             my $pitch = int 10*(1 - $time_left/60);
             $pitch = '';	# Skip this idea ... not all TTS engines do pitch that well
             speak "app=timer pitch=$pitch $time_left seconds till flash";

          }
       }
       if (expired $iridium_timer) {
          speak "app=timer pitch=10 Iridium flash now occuring";
          play 'timer2';              # Set in event_sounds.pl
       }

            if ($Dark and time_now '12/22/03  06:14 PM - 0:02' and -7 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 32 will have a magnitude -7 flare in 2 minutes ";
                $msg .= "at an altitude of 30, azimuth of 177.";
                speak "app=timer $msg";
                display "Flare will occur at: Mon, Dec 22 12/22/03 06:14:21 PM.  \n" . $msg, 600;
                set $iridium_timer 120 + 21;
            }
            if ($Dark and time_now '12/24/03  04:59 PM - 0:02' and -1 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 45 will have a magnitude -1 flare in 2 minutes ";
                $msg .= "at an altitude of 24, azimuth of 277.";
                speak "app=timer $msg";
                display "Flare will occur at: Wed, Dec 24 12/24/03 04:59:41 PM.  \n" . $msg, 600;
                set $iridium_timer 120 + 41;
            }
            if ($Dark and time_now '12/25/03  04:53 PM - 0:02' and -2 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 11 will have a magnitude -2 flare in 2 minutes ";
                $msg .= "at an altitude of 24, azimuth of 276.";
                speak "app=timer $msg";
                display "Flare will occur at: Thu, Dec 25 12/25/03 04:53:42 PM.  \n" . $msg, 600;
                set $iridium_timer 120 + 42;
            }
            if ($Dark and time_now '12/26/03  05:59 PM - 0:02' and -7 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 57 will have a magnitude -7 flare in 2 minutes ";
                $msg .= "at an altitude of 29, azimuth of 185.";
                speak "app=timer $msg";
                display "Flare will occur at: Fri, Dec 26 12/26/03 05:59:16 PM.  \n" . $msg, 600;
                set $iridium_timer 120 + 16;
            }
            if ($Dark and time_now '12/26/03  05:58 PM - 0:02' and -5 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 94 will have a magnitude -5 flare in 2 minutes ";
                $msg .= "at an altitude of 30, azimuth of 185.";
                speak "app=timer $msg";
                display "Flare will occur at: Fri, Dec 26 12/26/03 05:58:17 PM.  \n" . $msg, 600;
                set $iridium_timer 120 + 17;
            }
            if ($Dark and time_now '12/27/03  05:53 PM - 0:02' and -0 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 60 will have a magnitude -0 flare in 2 minutes ";
                $msg .= "at an altitude of 29, azimuth of 185.";
                speak "app=timer $msg";
                display "Flare will occur at: Sat, Dec 27 12/27/03 05:53:15 PM.  \n" . $msg, 600;
                set $iridium_timer 120 + 15;
            }
