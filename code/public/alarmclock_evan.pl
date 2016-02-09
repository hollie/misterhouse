# Category= Alarm_Clocks

#--------------------- M_AlarmClock.pl ---------------------------------
# This code implements an alarm clock with snooze
#----------------------------------------------------------------

my $alarm_switch = "off";    # Can be "off" or "set"
my $alarm_state  = "off";    # Can be "off", "waking", "sounding" or "snooze"
my $snooze_time  = '0';

$v_set_alarmclock = new Voice_Cmd('Set The Alarm Clock');

# TK Widgets

#if ($Reload) {
#    &tk_entry('Maggie\'s Alarm', \$Save{alarm1_time});
#}

if ( $state = state_now $XB_J6) {    # This is the Set/Snooze & Alarm Off Button

    ##############################
    # On set/snooze button press #
    ##############################

    if ( $state eq 'on' and $alarm_state eq 'sounding' ) {    # Snooze
        print_log "entering snooze mode";

        #		add code to silence the alarm
        $snooze_time = "$Time_Now+0:09";
        $alarm_state = 'snooze';
        print_log "snooze expires at $snooze_time";
    }

    if ( $state eq 'on' and $alarm_state eq 'off' ) {         # Set
        if ( $Wday < 5 ) {
            $alarm_switch = "set";
            speak
              "Good Night Maggie, Tomorrow is a school day. I have set your alarm for $Save{alarm1_time}";
        }
        speak "Good Night Maggie" if $Wday > 4;

        set $maggie_light1 'off';
        set $maggie_light2 '-95';
        set $maggie_light3 '-95';
        set $maggie_light3 '+45';
        set $fish_light 'off';
    }

    #############################
    #   On 'Off' button press   #
    #############################

    if ( $state eq 'off' ) {
        if ( $alarm_state eq 'waking' ) {    # Pressed during wake-up sequence
            set $maggie_light2 '+95';
        }

        if ( $alarm_state eq 'off' ) {       # Pressed before wake-up sequence
        }

        $alarm_switch = "off";
        $alarm_state  = "off";
        print_log "The alarm has been turned off";

        #		add command to turn off alarm signal
    }
}

#############################
#   On Snooze Expiration    #
#############################

if ( time_now($snooze_time) and $alarm_state eq 'snooze' ) {
    print_log "snooze has expired - now sounding alarm";
    $alarm_state = 'sounding';
    $snooze_time = '0';

    #	add command to turn on alarm (unless past alarm off time?)
}

if ( $alarm_switch eq "set" ) {

    #############################
    #     Wake-up Sequence      #
    #############################

    #	if (time_now("$Save{alarm1_time}+0:15")){
    #		set $mbr_light3 'brighten';
    #	}

    #		if (time_now("$Save{alarm1_time}+0:30")){
    #		set $mbr_light2 'brighten';
    #	}

    if ( time_now("$Save{alarm1_time}") ) {
        print_log "now sounding alarm1";
        $alarm_state = "sounding";

        #	add command to turn alarm signal on
    }

    if ( time_now("$Save{alarm1_time}-0:18") ) {
        $alarm_state = "waking";
    }

    if ( ( $alarm_state eq "waking" ) and $New_Minute ) {
        set $maggie_light3 '+5';
        set $maggie_light2 '+5';
    }

    if ( time_now("$Save{alarm1_time}+0:30") ) {
        $alarm_state  = "off";
        $alarm_switch = "off";

        #	add command to silence the alarm
    }
}
