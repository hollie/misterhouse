# Category = MisterHouse

#@ This code ancommon/monitory_memory.pl sets these vars.  This code announces leaks

if ( new_minute 10 and $Info{memory_virtual_prev} ) {
    my $memory_diff = int $Info{memory_virtual} - $Info{memory_virtual_prev};
    if ( $memory_diff > 2 ) {
        speak "MisterHouse just leaked $memory_diff megabytes of memory"

          #       run_voice_cmd  'Restart Mister House';
    }
}

if ( new_minute and $Info{memory_virtual_prev} > 200 ) {
    speak "Mister House has leaked too much memory, so is restarting";
    run_voice_cmd 'Restart Mister House';
}
