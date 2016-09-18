
=begin comment 

#@ Monitors the cm11 controller and resets if down (optionally "tickles" via a cm17 to ensure that the cm11 comes back up immediately.) Timeout is set with cm11_timeout parameter. cm11_tickle_address is the address sent by the cm17 on reset.  To disable automated resets, reset the cm11_auto_reset parameter (set it to 0.)

=cut

# Category = X10

$cm11_monitor         = new Generic_Item();
$timer_x10_inactivity = new Timer();
$v_cm11_control       = new Voice_Cmd "[Start,Stop,Reset] the CM11 port";
$v_cm11_control->set_info(
    'Controls the CM11 X10 controller. Reset if it sticks.');
if ($Reload) {
    Serial_data_add_hook( \&cm11_monitor );
    my $timeout = $config_parms{cm11_timeout};
    $timeout = 1800 unless $timeout;
    set $timer_x10_inactivity $timeout, \&cm11_unstick;
}

sub cm11_monitor {
    my $state = shift;
    my $current_unit;
    return unless $state =~ /^X/;

    # *** These signals could come from a different controller (like a Lynx or proxy, etc.)
    # Need way to do this (inside of cm11 object makes most sense.)

    $current_unit = $1 if ( $state =~ /^X([A-P][1-9A-G])/ );

    set $cm11_monitor 'up' if ( $cm11_monitor->{state} ne 'up' );

    print_log "Reset cm11 inactivity timer $current_unit $state"
      if $config_parms{x10_errata} >= 3;
    set $timer_x10_inactivity 1800, \&cm11_unstick
      ; #every half hour without activity triggers a restart.  Otherwise cm11 remains lost in space."
}

sub cm11_unstick {
    set $cm11_monitor 'down';
    if ( !defined $config_parms{'cm11_auto_reset'}
        or $config_parms{'cm11_auto_reset'} )
    {
        speak "app=system Restarting automation controller after inactivity.";

        # default is to reset the port after inactivity (can be turned off with 0)
        &cm11_control('Reset');
        set $cm11_monitor 'reset';
    }
    my $timeout = $config_parms{cm11_timeout};
    $timeout = 1800 unless $timeout;
    set $timer_x10_inactivity $timeout, \&cm11_unstick;
}

sub cm11_control {
    my $state = shift;

    if ( defined $main::Serial_Ports{'cm11'}{object} ) {

        if ( $state eq 'Stop' or $state eq 'Reset' ) {
            if ( $main::Serial_Ports{'cm11'}{object}->close ) {
                print "CM11 port was closed\n" if $Debug{cm11};
                delete $Serial_Ports{object_by_port}
                  { $Serial_Ports{'cm11'}{port} };
            }
            else {
                print "CM11 port failed to close\n" if $Debug{cm11};
            }
        }

        if ( $state eq 'Start' or $state eq 'Reset' ) {
            if ( &main::serial_port_open('cm11') ) {
                print "CM11 port was re-opened\n" if $Debug{cm11};
            }
            else {
                print "CM11 port failed to re-open\n" if $Debug{cm11};
            }
        }

        # "Tickle" controller w/ X10 signal via CM17 (if exists)

        if ( $state eq 'Reset' ) {
            if ( &main::serial_port_open('cm17') ) {
                print "Sending X10 signal via CM17\n" if $Debug{cm11};

                ControlX10::CM17::send(
                    (
                          $config_parms{'cm11_tickle_address'}
                        ? $config_parms{'cm11_tickle_address'}
                        : 'A1'
                    )
                    . 'K'
                );    # send an off command to the dummy tickle address

            }
        }

        $v_cm11_control->respond("app=cm11 CM11 port has been set to $state.");

    }
    else {
        $v_cm11_control->respond("app=error CM11 port does not exist.");
    }

}

if ( said $v_cm11_control) {
    &cm11_control( $v_cm11_control->{state} );
}
