
$v_wakeup_time = new Voice_Cmd(
    "Wakeup Time Is Set To [3:30 AM,4:00 AM,4:30 
AM,5:00 AM,5:30 AM,6:00 AM]"
);

if ( $state = said $v_wakeup_time) {
    $Save{wakeup_time} = $state;
    speak "Wake up time is at $state.";
    print_log "Wake up time is set for $state.";
}

$v_wakeup_time_toggle = new Voice_Cmd("Set Wake up Time");
if ( said $v_wakeup_time_toggle) {
    if ( $Save{wakeup_time} eq '3:30 AM' ) {
        $Save{wakeup_time} = '3:30 AM';
    }
    elsif ( $Save{wakeup_time} eq '4:00 AM' ) {
        $Save{wakeup_time} = '4:00 AM';
    }

    elsif ( $Save{wakeup_time} eq '4:30 AM' ) {
        $Save{wakeup_time} = '4:30 AM';
    }

    elsif ( $Save{wakeup_time} eq '5:00 AM' ) {
        $Save{wakeup_time} = '5:00 AM';
    }
    elsif ( $Save{wakeup_time} eq '5:30 AM' ) {
        $Save{wakeup_time} = '5:30 AM';
    }
    elsif ( $Save{wakeup_time} eq '6:00 AM' ) {
        $Save{wakeup_time} = '6:00 AM';
    }
    else {
        $Save{wakeup_time} = '6:30 AM';
    }

    # mode => force cause speech even in mute or
    offline mode &speak(
        wakeup_time => 'unmuted',
        rooms       => 'all',
        text        => "MisterHouse is 
set to $Save{wakeup_time} wakeup time"
    );

}

#$Save{wakeup_time} = '6:00 AM' unless $Save{wakeup_time};

$v_wakeup_parents = new Voice_Cmd('Wakeup the parents');
$v_wakeup_parents->set_info("Do not do this!  Parents like to sleep.");

if (
    (
            time_now( $Save{wakeup_time} )
        and $Weekday
        and $Save{mode} ne 'offline'
    )
    or said $v_wakeup_parents)
{
    $Save{mode}             = 'normal';
    $Save{mode_set}         = '';
    $Save{sleeping_parents} = 0;
    $Save{sleeping_kids}    = 0;
    &pa_sleep_mode( 'all', 0 );
    speak(
        "rooms=bedroom Good morning Parents.  It is now $Time_Now on 
$Date_Now_Speakable."
    );
    speak(
        "rooms=bedroom Sunrise today is at $Time_Sunrise, sunset is at 
$Time_Sunset"
    );
}
