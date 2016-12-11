
#@ Auto-generated from code/common/internet_iridium.pl

$iridium_timer = new Timer;

if ( $New_Second and my $time_left = int seconds_remaining $iridium_timer) {
    my %iridium_timer_intervals = map { $_, 1 } ( 15, 30, 90 );
    if ( $iridium_timer_intervals{$time_left} ) {
        my $pitch = int 10 * ( 1 - $time_left / 60 );
        $pitch = ''; # Skip this idea ... not all TTS engines do pitch that well
        speak "app=timer pitch=$pitch $time_left seconds till flash";

    }
}
if ( expired $iridium_timer) {
    speak "app=timer pitch=10 Iridium flash now occuring";
    play 'timer2';    # Set in event_sounds.pl
}

if (    $Dark
    and time_now '03/20/06  07:40 PM - 0:02'
    and -0 <= $config_parms{iridium_brightness} )
{
    set $iridium_timer 120 + 10;
    my $msg =
      "Notice: Iridium satellite 42 will have a magnitude -0 flare in 2 minutes ";
    $msg .= "at an altitude of 58, azimuth of 132.";
    speak "app=timer $msg";
    display "Flare will occur at: Mon, Mar 20 03/20/06 07:40:10 PM.  \n" . $msg,
      600;
}
if (    $Dark
    and time_now '03/21/06  07:34 PM - 0:02'
    and -8 <= $config_parms{iridium_brightness} )
{
    set $iridium_timer 120 + 7;
    my $msg =
      "Notice: Iridium satellite 80 will have a magnitude -8 flare in 2 minutes ";
    $msg .= "at an altitude of 58, azimuth of 132.";
    speak "app=timer $msg";
    display "Flare will occur at: Tue, Mar 21 03/21/06 07:34:07 PM.  \n" . $msg,
      600;
}
if (    $Dark
    and time_now '03/22/06  07:28 PM - 0:02'
    and -1 <= $config_parms{iridium_brightness} )
{
    set $iridium_timer 120 + 3;
    my $msg =
      "Notice: Iridium satellite 81 will have a magnitude -1 flare in 2 minutes ";
    $msg .= "at an altitude of 57, azimuth of 131.";
    speak "app=timer $msg";
    display "Flare will occur at: Wed, Mar 22 03/22/06 07:28:03 PM.  \n" . $msg,
      600;
}
