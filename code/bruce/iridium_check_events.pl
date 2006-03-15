
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

            if ($Dark and time_now '01/25/04  07:03 PM - 0:02' and -4 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 53 will have a magnitude -4 flare in 2 minutes ";
                $msg .= "at an altitude of 37, azimuth of 159.";
                speak "app=timer $msg";
                display "Flare will occur at: Sun, Jan 25 01/25/04 07:03:55 PM.  \n" . $msg, 600;
                set $iridium_timer 120 + 55;
            }
            if ($Dark and time_now '01/26/04  06:57 PM - 0:02' and -1 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 54 will have a magnitude -1 flare in 2 minutes ";
                $msg .= "at an altitude of 36, azimuth of 159.";
                speak "app=timer $msg";
                display "Flare will occur at: Mon, Jan 26 01/26/04 06:57:52 PM.  \n" . $msg, 600;
                set $iridium_timer 120 + 52;
            }
            if ($Dark and time_now '01/27/04  05:25 PM - 0:02' and -6 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 61 will have a magnitude -6 flare in 2 minutes ";
                $msg .= "at an altitude of 27, azimuth of 208.";
                speak "app=timer $msg";
                display "Flare will occur at: Tue, Jan 27 01/27/04 05:25:13 PM.  \n" . $msg, 600;
                set $iridium_timer 120 + 13;
            }
            if ($Dark and time_now '01/28/04  07:30 AM - 0:02' and -1 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 12 will have a magnitude -1 flare in 2 minutes ";
                $msg .= "at an altitude of 72, azimuth of 353.";
                speak "app=timer $msg";
                display "Flare will occur at: Wed, Jan 28 01/28/04 07:30:09 AM.  \n" . $msg, 600;
                set $iridium_timer 120 + 9;
            }
            if ($Dark and time_now '01/30/04  06:42 PM - 0:02' and -8 <= $config_parms{iridium_brightness}) {
                my $msg = "Notice: Iridium satellite 13 will have a magnitude -8 flare in 2 minutes ";
                $msg .= "at an altitude of 39, azimuth of 169.";
                speak "app=timer $msg";
                display "Flare will occur at: Fri, Jan 30 01/30/04 06:42:41 PM.  \n" . $msg, 600;
                set $iridium_timer 120 + 41;
            }
