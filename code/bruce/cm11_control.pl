# Category=MisterHouse

#@ This might help un-stick a stuck CM11 module??

$v_cm11_control1 = new Voice_Cmd "[Start,Stop] the CM11 port";
if ( $state = said $v_cm11_control1) {
    print_log "CM11 port has been set to $state.";
    if ( $state eq 'Start' ) {
        if ( &main::serial_port_open('cm11') ) {
            print "CM11 port was re-opened\n";
        }
        else {
            print "CM11 port failed to re-open\n";
        }
    }
    else {
        if ( $main::Serial_Ports{'cm11'}{object}->close ) {
            print "CM11 port was closed\n";
            delete $Serial_Ports{object_by_port}{ $Serial_Ports{'cm11'}{port} };
        }
        else {
            print "CM11 port failed to close\n";
        }

    }
}

