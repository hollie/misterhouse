# Category=Informational

#@ Announces time and date info (e.g. sun/moon times and holidays)

#noloop=start

# Time

$v_what_time = new Voice_Cmd( 'Tell me the time', 0 );
$v_what_time->set_info('Says the time and date');
$v_what_time->set_authority('anyone');
$v_what_time2 = new Voice_Cmd( 'What time is it', 0 );
$v_what_time2->set_info('Says the time and date');
$v_what_time2->set_authority('anyone');
$v_what_time->tie_event("&announce_time(\$v_what_time,\$state)");
$v_what_time2->tie_event("&announce_time(\$v_what_time2,\$state)");

# Sun

$v_sun_set = new Voice_Cmd( 'When will the sun [set,rise]', 0 );
$v_sun_set->set_info(
    "Calculates sunrise and sunset for latitude=$config_parms{latitude}, longitude=$config_parms{longitude}"
);
$v_sun_set->set_authority('anyone');
$v_sun_set->tie_event("&announce_sun(\$state)");

# Moon

$v_moon_info1 = new Voice_Cmd "When is the next [new,full] moon",  0;
$v_moon_info2 = new Voice_Cmd "When was the last [new,full] moon", 0;
$v_moon_info3 = new Voice_Cmd "What is the phase of the moon",     0;
$v_moon_info3->set_info(
    'Phase will be: New, One-Quarter Waxing, Half Waxing, Three-Quarter Waxing, Full, and same for Waning'
);
$v_moon_info1->set_authority('anyone');
$v_moon_info2->set_authority('anyone');
$v_moon_info3->set_authority('anyone');
$v_moon_info1->tie_event("&announce_next_moon(\$state)");
$v_moon_info2->tie_event("&announce_previous_moon(\$state)");
$v_moon_info3->tie_event("&announce_moon()");

# Full moon remarks

$f_full_moon = new File_Item("$config_parms{data_dir}/remarks/full_moon.txt");

#noloop=stop

# Create triggers

if ($Reload) {
    my $command = 'time_now $Time_Sunset and $Moon{phase} =~ /^full/i';
    &trigger_set( $command, "&announce_full_moon()", 'NoExpire',
        'announce full moon' )
      unless &trigger_get('announce full moon');

    $command = "time_cron '30 9,12,19 * * *' and " . '$Holiday';
    &trigger_set( $command,
        'speak "app=holiday force_chime=1 Today is $Holiday"',
        'NoExpire', 'announce holiday' )
      unless &trigger_get('announce holiday');

    $command = 'time_now $Time_Sunrise';
    &trigger_set(
        $command,
        'speak "force_chime=1 app=sunrise Notice, the sun is now rising at $Time_Sunrise"',
        'NoExpire',
        'announce sunrise'
    ) unless &trigger_get('announce sunrise');

    $command = 'time_now $Time_Sunset';
    &trigger_set(
        $command,
        'speak "force_chime=1 app=sunset Notice, the sun is now setting at $Time_Sunset"',
        'NoExpire',
        'announce sunset'
    ) unless &trigger_get('announce sunset');
}

# events (tied to voice commands)

sub announce_time {
    my ( $object, $state ) = @_;
    my $msg;

    my $time = $Time_Now;
    $time =~ s/:/\x20/;    # ???  Says "colon."
    $msg = "It is $time on $Date_Now_Speakable.";
    $msg .= ". It is $Holiday." if $Holiday;
    $object->respond("app=time $msg");
}

sub announce_sun {
    my $state = shift;
    if ( $state eq 'set' ) {
        $v_sun_set->respond("app=sunset Sunset today is at $Time_Sunset.");
    }
    else {
        $v_sun_set->respond("app=sunrise Sunrise today is at $Time_Sunrise.");
    }
}

sub announce_moon {
    $v_moon_info3->respond(
        qq[The moon is $Moon{phase}, $Moon{brightness}% bright, and $Moon{age} days old]
    );
}

sub announce_previous_moon {
    my $state = shift;
    my $days = &time_diff( $Moon{"time_${state}_prev"}, $Time );
    $v_moon_info2->respond(
        qq[The last $state moon was $days ago, on $Moon{"${state}_prev"}]);
}

sub announce_next_moon {
    my $state = shift;
    my $days = &time_diff( $Moon{"time_$state"}, $Time );
    $v_moon_info1->respond(
        qq[The next $state moon is in $days, on $Moon{$state}]);
}

sub announce_full_moon {
    speak "app=moon Notice, tonight is a full moon.  "
      . ( read_next $f_full_moon);
}

# Uninstall (must be called prior to removing this module from code_select.txt)
# *** Web admin script must be updated to do this with an eval per module removed

sub uninstall_time_info {
    &trigger_delete('announce sunrise');
    &trigger_delete('announce sunset');
    &trigger_delete('announce full moon');
    &trigger_delete('announce holiday');
}
