# Category=Phone

$callerid            = new  Serial_Item('I');
$phonetone           = new  Serial_Item('O');

my ($caller_id_data, $phonetone_data);

                                # Speak incoming callerID data and log it
if ($caller_id_data = state_now $callerid) {

    $Save{phone_last} = $caller_id_data; # Save last caller for display in lcdproc.pl

                                # On startup, old callerid strings might be sent ... ignore them
    my ($caller, $cid_number, $cid_name) = &Caller_ID::make_speakable($caller_id_data);
    speak("rooms=all " . $caller) if time > ($Time_Startup_time + 15);
    print_log "callerid data: $caller_id_data";
    logit("$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",  "$cid_number $cid_name");
    logit_dbm("$config_parms{data_dir}/phone/callerid.dbm", $cid_number, "$Time_Now $Date_Now $Year name=$cid_name");
}

                                # Log outgoing phone numbers
logit("$config_parms{data_dir}/phone/logs/phone.$Year_Month_Now.log", $phonetone_data)
    if $phonetone_data = state_now $phonetone;
