
$test_state = new Voice_Cmd 'Test state [0,1,2]';

print_log "state_now    = $state" if defined( $state = state_now $test_state);
print_log "state_change = $state"
  if defined( $state = state_changed $test_state);
