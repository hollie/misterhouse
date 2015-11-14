
# An example of how to detect motion direction

$test_motion_sensor = new Serial_Item( 'XA2AJ', 'stair bot' );
$test_motion_sensor->add( 'XA3AJ', 'stair top' );
$test_motion_prev  = new Generic_Item;
$test_motion_dir   = new Generic_Item;
$test_motion_timer = new Timer;

if ( $state = state_now $test_motion_sensor) {
    if ( active $test_motion_timer) {
        if ( $state eq 'stair top' and 'stair bot' eq state $test_motion_prev) {
            set $test_motion_dir 'stair up';
            unset $test_motion_timer;
        }
        if ( $state eq 'stair bot' and 'stair top' eq state $test_motion_prev) {
            set $test_motion_dir 'stair down';
            unset $test_motion_timer;
        }
    }
    else {
        set $test_motion_prev $state;
        set $test_motion_timer 15;
        print_log "Motion detected: $state";
    }
}

print_log "Motion direction: $state" if $state = state_now $test_motion_dir;

