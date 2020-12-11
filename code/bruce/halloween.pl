
#@ Halloween events

$halloween_button = new Serial_Item 'XABAJ';

print_log "Halloween sensor" if state_now $halloween_button;
play "Halloween/*.wav"       if state_now $halloween_button;
