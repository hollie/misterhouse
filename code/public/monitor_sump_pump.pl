
=begin comment

From Craig Schaeffer on 2/5/00

I just added some code to handle monitoring my sump pump. I have a weeder
digital I/O kit with a magnetic reed switch hooked up to the float on my sump
pump. I was surprised to see that it pumps as much as 140 times/day (after some
rain last week). I was concerned that I would not know if the pump should fail,
so I coded up the following:

=cut

$sump_pump_dead = new Timer();

# increment the counter and reset the timer each time it pumps
if ( state_now $sump_pump_a eq 'empty' ) {
    $Save{sump}++;
    set $sump_pump_dead $Save{sump_timer};
}

# log the count, re-calc the timer, and reset the counter
# the timer value is 5 * the average interval between cycles
# (during the last 24 hours)
if ( time_now '23:59' ) {
    logit( "$config_parms{data_dir}/logs/sump.log", $Save{sump}, 11 );
    $Save{sump_timer} = int( 5 * 86400 / ( $Save{sump} + 1 ) );
    $Save{sump} = 0;
}

# warn if we haven't pumped in a while
if ( expired $sump_pump_dead) {
    speak "The sump pump may be dead";
    print_log "The sump pump may be dead";
    &alarm_trip( 0, "The sump pump may be dead" );
    set $sump_pump_dead $Save{sump_timer};
}

if ( $Startup or $Reload ) {
    set $sump_pump_dead $Save{sump_timer} if inactive $sump_pump_dead;
}
