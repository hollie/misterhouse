# Category=Phone

if ($Reload) {
    set $phone_modem 'init';    # Initialize MODEM
    print_log "Caller ID Interface has been Initialized...";
}

# Allow the port to be shared
$v_port_control1 = new Voice_Cmd("[Start,Stop] Phone Modem port monitoring");
if ( $state = said $v_port_control1) {
    print_log "Phone Modem monitoring has been set to $state.";
    ( $state eq 'Start' ) ? start $phone_modem : stop $phone_modem;
}

if ( $New_Minute and is_stopped $phone_modem and is_available $phone_modem) {
    start $phone_modem;
    set $phone_modem 'init';
    print_msg "MODEM Reinitialized...";
    print_log "MODEM Reinitialized...";
}

