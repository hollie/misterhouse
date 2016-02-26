# Category=X10
#@ Stops and starts the cm11 automation controller
#execute unstick if ack/done cycle fails

$v_cm11_control1 = new Voice_Cmd "[Start,Stop,Reset] the CM11 port";
if ( said $v_cm11_control1) {
    my $state = $v_cm11_control1->{state};

    if ( defined $main::Serial_Ports{'cm11'}{object} ) {

        if ( $state eq 'Stop' or $state eq 'Reset' ) {
            if ( $main::Serial_Ports{'cm11'}{object}->close ) {
                print "CM11 port was closed\n";
                delete $Serial_Ports{object_by_port}
                  { $Serial_Ports{'cm11'}{port} };
            }
            else {
                print "CM11 port failed to close\n";
            }
        }

        if ( $state eq 'Start' or $state eq 'Reset' ) {
            if ( &main::serial_port_open('cm11') ) {
                print "CM11 port was re-opened\n";
            }
            else {
                print "CM11 port failed to re-open\n";
            }
        }

        $v_cm11_control1->respond("app=cm11 CM11 port has been set to $state.");

    }
    else {
        $v_cm11_control1->respond("app=error CM11 port does not exist.");
    }
}

