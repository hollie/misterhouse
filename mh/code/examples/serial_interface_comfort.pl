
# An example of reading/writing to the Comfort HA interface

# Set these mh.ini parms
#serial_comfort_port=\\.\COM11
#serial_comfort_baudrate=9600
#serial_comfort_handshake=dtr

my $C3 = chr 3;

$comfort = new Serial_Item($C3 . "LI1234\n", 'init', 'serial_comfort');

if ($Reload) {
    set $comfort 'init';        # Login
    print_log "Comfort interface has been initialized...";
}

$test1 = new Voice_Cmd 'Run comfort test [1,2,3]';
if ($state = said $test1) {
    print_log "Running test $state";
    set $comfort $C3 . "X!A0105\n" if $state == 1;
}

if ($state = said $comfort) {
    print_log "Comfort said: $state";
}
