# Category=Phone

$phone_modem = new Serial_Item ('ATE1V1X4&C1&D2S0=0+VCID=1', 'init', 'serial3');

if ($Reload) {
    set $phone_modem 'init';               # Initialize MODEM
    print_log "Caller ID Interface has been Initialized...";
}

my $caller_id_data;
if ($state = said $phone_modem) {
    $caller_id_data .= ' ' . $state;
    if ($state =~ /NAME/) {
        my ($caller, $cid_number, $cid_name, $cid_time) = &Caller_ID::make_speakable($caller_id_data, 2);
        speak("rooms=all " . $caller);
        print_log "callerid data: $caller_id_data";
        print_log "callerid data: number=$cid_number name=$cid_name time=$cid_time";
        logit("$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",  "$cid_number $cid_name");
        logit_dbm("$config_parms{data_dir}/phone/callerid.dbm", $cid_number, "$Time_Now $Date_Now $Year name=$cid_name");
        undef $caller_id_data;
    }
}
