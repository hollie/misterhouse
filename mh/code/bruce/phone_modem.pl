# Category=Phone

# Add these entries to your mh.ini file:
#  serial_modem_port=COM12  
#  serial_modem_baudrate=9600
#  serial_modem_handshake=dtr

use vars '$PhoneModemString';         # Used in voicemodem.pl

# David L. reports a no-name external Rockwell modem wants #CID=1 (instead of +VCID=1)
$phone_modem = new Serial_Item ('ATE1V1X4&C1&D2S0=0+VCID=1', 'init', 'serial_modem');

if ($Reload) {
    set $phone_modem 'init';               # Initialize MODEM
    print_log "Caller ID Interface has been Initialized...";
}

my $caller_id_data;
if ($PhoneModemString = said $phone_modem) {
    my $l = length $PhoneModemString;
    print "Modem said: $PhoneModemString\n" if $l < 80;
#   print "db Modem: l=$l\n" if $l > 80;
    $caller_id_data .= ' ' . $PhoneModemString;
    if ($PhoneModemString =~ /NAME/) {
        my ($caller, $cid_number, $cid_name, $cid_time) = &Caller_ID::make_speakable($caller_id_data, 2);
        speak("rooms=all Call from $caller.  Phone call is from $caller.");
        print_log "callerid data: $caller_id_data";
        print_log "callerid data: number=$cid_number name=$cid_name time=$cid_time";
        logit("$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",  "$cid_number $cid_name");
        logit_dbm("$config_parms{data_dir}/phone/callerid.dbm", $cid_number, "$Time_Now $Date_Now $Year name=$cid_name");
        undef $caller_id_data;
    }
}

                                # Allow the port to be shared
$v_port_control1 = new Voice_Cmd("[Start,Stop] Phone Modem port monitoring");
if ($state = said $v_port_control1) {
    print_log "Phone Modem monitoring has been set to $state.";
    ($state eq 'Start') ? start $phone_modem : stop $phone_modem;
}

if ($New_Minute and is_stopped $phone_modem and is_available $phone_modem) {
    start $phone_modem;
    set $phone_modem 'init';
    print_msg "MODEM Reinitialized...";
    print_log "MODEM Reinitialized...";
}

