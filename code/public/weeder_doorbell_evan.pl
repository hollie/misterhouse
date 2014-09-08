#Category=Doorbell

#############################
#
# doorbell.pl 		Evan Graham
#
# This script operates the doorbell
# Uses weeder digitial i/o card 'A', bit 'N' to detect a dorbell button press at
# at the front door and bit 'M' to detect a doorbell button press at the back.
# The $f_doorbell, and $b_doorbell variables are defined in definitions.pl and the
# weeder card is initialized in misc.pl
#
# Version History
#
# 10/11/2003	1.2
# Added doorbell failure detection
#
# 9/13/2003 	1.1
# Added back doorbell. Changed from $f_doorbell to $f_doorbell and $b_doorbell variables.
#
# ?/?/2000	1.0
# Initial Release
############################

$v_test_dorbell = new Voice_Cmd("Test Doorbell");
$v_set_f_bell_sound =
  new Voice_Cmd("Set Front Doorbell Sound to [Chimes,Jetsons]");
$v_set_b_bell_sound =
  new Voice_Cmd("Set Back Doorbell Sound to [Chimes,Jetsons]");
$f_doorbell_timer = new Timer();   # timer used to prevent annoying double rings
$b_doorbell_timer = new Timer();   # timer used to prevent annoying double rings
$read_timer       = new Timer();
$f_fail_timer     = new Timer();
$b_fail_timer     = new Timer();
my $f_doorbell_fail = 0;
my $b_doorbell_fail = 0;
my $f_counter       = 0;
my $b_counter       = 0;

my $db_state;

$Save{f_doorbell_sound} = "doorbell.wav" unless $Save{f_doorbell_sound};
$Save{b_doorbell_sound} = "doorbell.wav" unless $Save{b_doorbell_sound};

$Save{doorbell_vol} = '40' unless $Save{doorbell_vol};

if ( $db_state = said $v_set_f_bell_sound) {

    if ( $db_state eq "Jetsons" ) {
        $Save{f_doorbell_sound} = "jetson_bell.wav";
        $Save{doorbell_vol}     = '20';
        print_log "Setting front doorbell sound to Jetsons";
    }

    if ( $db_state eq "Chimes" ) {
        $Save{f_doorbell_sound} = "doorbell.wav";
        $Save{doorbell_vol}     = '40';
        print_log "Setting front doorbell sound to Chimes";
    }

}

if ( $db_state = said $v_set_b_bell_sound) {

    if ( $db_state eq "Jetsons" ) {
        $Save{b_doorbell_sound} = "jetson_bell.wav";
        $Save{doorbell_vol}     = '20';
        print_log "Setting back doorbell sound to Jetsons";
    }

    if ( $db_state eq "Chimes" ) {
        $Save{f_doorbell_sound} = "doorbell.wav";
        $Save{doorbell_vol}     = '40';
        print_log "Setting back doorbell sound to Chimes";
    }

}

#*********************  Code for Front Doorbell Ring ****************************

if ( state_now $f_doorbell eq 'rung' ) {
    $f_counter++;    #increment ring counter used to detect doorbell failure
    print_log "Front DB Press: $f_counter \n";
    set $f_fail_timer 20;    #time increment to test for failures
    if ( $f_counter >= 10 and not $f_doorbell_fail )
    {    #10 rings in 20 seconds indicates a failure, disable doorbell
        $f_doorbell_fail = 1;    #set broken doorbell flag
        speak(
            volume => 100,
            rooms  => 'all',
            voice  => 'crystal',
            text   => "The front doorbell has been disabled at $Time_Now"
        );
    }

    if ( inactive $f_doorbell_timer and not $f_doorbell_fail ) {
        play(
            rooms  => 'all',
            mode   => 'unmuted',
            volume => $Save{doorbell_vol},
            file   => $sound_dir . $Save{f_doorbell_sound}
        );
        logit(
            "$config_parms{data_dir}/logs/doorbell/doorbell.$Year_Month_Now.log",
            "Front Doorbell"
        );
        $Save{last_doorbell_time} = "$Date_Now $Time_Now";
        print_log "Front Doorbell";
        set $f_doorbell_timer 3;
    }
}

if ( expired $f_fail_timer)
{   #if there have been no rings in the last 20 seconds, the doorbell will reset
    $f_counter = 0;    #reset ring counter
    if ($f_doorbell_fail) {
        $f_doorbell_fail = 0;    #reset doorbell failure flag
        speak(
            volume => 100,
            rooms  => 'all',
            voice  => 'crystal',
            text   => "The front doorbell has been enabled at $Time_Now"
        );
    }
}

if ( time_cron '30 18 * * *' and $f_doorbell_fail )
{                                # Send reminder that doorbell is broken
    speak(
        volume => 100,
        rooms  => 'all',
        voice  => 'crystal',
        text   => "The front doorbell is currently not functional"
    );
}

#*********************  Code for Back Doorbell Ring ****************************

if ( state_now $b_doorbell eq 'rung' ) {

    $b_counter++;    #increment ring counter used to detect doorbell failure
    print_log "Back DB Press: $b_counter \n";
    set $b_fail_timer 20;    #time increment to test for failures
    if ( $b_counter >= 10 and not $b_doorbell_fail )
    {    #10 rings in 20 seconds indicates a failure, disable doorbell
        print_log "count: $b_counter f_flag: $b_doorbell_fail\n";
        $b_doorbell_fail = 1;    #set broken doorbell flag
        speak(
            volume => 100,
            rooms  => 'all',
            voice  => 'crystal',
            text   => "The back doorbell has been disabled at $Time_Now"
        );
    }

    if ( inactive $b_doorbell_timer and not $b_doorbell_fail ) {
        play(
            rooms  => 'all',
            mode   => 'unmuted',
            volume => $Save{doorbell_vol},
            file   => $sound_dir . $Save{b_doorbell_sound}
        );
        logit(
            "$config_parms{data_dir}/logs/doorbell/doorbell.$Year_Month_Now.log",
            "Back Doorbell"
        );
        $Save{last_doorbell_time} = "$Date_Now $Time_Now";
        print_log "Back Doorbell";
        set $b_doorbell_timer 3;
    }
}

if ( expired $b_fail_timer)
{   #if there have been no rings in the last 20 seconds, the doorbell will reset
    $b_counter = 0;    #reset ring counter
    if ($b_doorbell_fail) {
        $b_doorbell_fail = 0;    #reset doorbell failure flag
        speak(
            volume => 100,
            rooms  => 'all',
            voice  => 'crystal',
            text   => "The back doorbell has been enabled at $Time_Now"
        );
    }
}

if ( time_cron '31 18 * * *' and $b_doorbell_fail )
{                                # Send reminder that doorbell is broken
    speak(
        volume => 100,
        rooms  => 'all',
        voice  => 'crystal',
        text   => "The back doorbell is currently not functional"
    );
}
