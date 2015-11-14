# Category=Phone

#@ Use to monitor incoming and outgoing calls with the Weeder
#@ interfaces (now discontinued)

$callerid  = new Serial_Item('I');
$phonetone = new Serial_Item('O');

# Speak incoming callerID data and log it
if ( my $caller_id_data = state_now $callerid) {

    print "Weeder cid=$caller_id_data\n";

    # Ignore garbage data (ascii is between ! thru ~)
    $caller_id_data = '' if $caller_id_data !~ /^[\n\r\t !-~]+$/;

    my ( $caller, $cid_number, $cid_name ) =
      &Caller_ID::make_speakable($caller_id_data);
    if ( $caller =~ /\.wav$/ ) {
        $caller =
          "phone_call.wav,$caller,phone_call.wav,$caller"; # Prefix 'phone call'
    }
    else {
        $caller = "Call from $caller.  Line 1 call is from $caller.";
    }

    print "callerid data : $caller_id_data\n";

    # If we have other callerID interfaces (e.g. phone_modem.pl)
    # lets not repeat ourselfs here.
    unless ( $Time - $Save{phone_callerid_Time} < 3 ) {
        $Save{phone_callerid_data} =
          sprintf( "%02d:%02d %s\n%s", $Hour, $Minute, $cid_number, $caller );
        $Save{phone_callerid_Time} = $Time;

        # On startup, old callerid strings might be sent ... ignore them
        speak("rooms=all_and_out mode=unmuted $caller")
          if time > ( $Time_Startup_time + 15 );

        #       speak("address=piano $caller");
        logit(
            "$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",
            "$cid_number name=$cid_name data=$caller_id_data line=1"
        );
        logit_dbm( "$config_parms{data_dir}/phone/callerid.dbm",
            $cid_number, "$Time_Now $Date_Now $Year name=$cid_name" );
    }
}

# Log outgoing phone numbers
if ( $state = state_now $phonetone) {
    logit( "$config_parms{data_dir}/phone/logs/phone.$Year_Month_Now.log",
        $state );
    print_log "Phone data: $state";
}

