# Category=Phone

# Note: These examples assume you have enabled generic serial ports
#       by editing the serialx parms in mh.ini (or mh.private.ini)
# Pete Flaherty 7-17-2004 (or thereabouts)

$merlin_data = new Serial_Item( undef, undef, 'serial1' );
my (
    $ph_id,   $ph_date, $ph_time,    $cid_number, $ph_duration,
    $ph_line, $ph_extn, $ph_account, $ph_type
);

# get the data if it's there
if ( my $data = said $merlin_data) {

    # Split it up into it's parts
    (
        $ph_id, $ph_date, $ph_time, $cid_number, $ph_duration, $ph_line,
        $ph_extn, $ph_account
    ) = split( /\s+/, $data );

    # All the outgoing calls are Id'd wit a C
    if ( $ph_id eq "C" and $cid_number ne "IN" ) {
        $cid_number = substr( $cid_number, 0, 11 );
        my $ph_nm =
          "Ln " + $ph_line + " ext " + $ph_extn + " for " + $ph_duration;
        $cid_number = "O$cid_number";    #Starts With a cap 'o' not 0 zero

        #	print_log "Serial data received ",$data;
        #	print_log "full", $ph_date, $ph_time, $cid_number, $ph_duration, $ph_extn;
        #	print_log $cid_number ;

        if ( $ph_line == '801' ) { $ph_type = 'POTS'; }
        if ( $ph_line == '802' ) { $ph_type = 'VOIP'; }
        if ( $ph_line == '803' ) { $ph_type = 'VOIP'; }
        if ( $ph_line == '804' ) { $ph_type = 'VOIP'; }

        # We're gaurenteed only one string at a time, without duplicates
        # So log it
        # Tue 04/27/04 08:15:41 O1234567
        logit( "$config_parms{data_dir}/phone/logs/phone.$Year_Month_Now.log",
            "$cid_number name=$ph_duration ext=$ph_extn line=$ph_line type=$ph_type"
        );

        #		&::logit("$::config_parms{data_dir}/phone/logs/phone.$::Year_Month_Now.log",
        #		" $l_number name=$l_name line=$ph_line type=$tempsource");

        logit_dbm(
            "$config_parms{data_dir}/phone/phone.dbm",
            $cid_number,
            "$Time_Now $Date_Now $Year",
            "name=$ph_duration line=$ph_line"
        );

        #           logit_dbm("$config_parms{data_dir}/phone/callerid.dbm", $cid_number, "$Time_Now $Date_Now $Year name=$cid_name");
    }
}

