# Category=Phone
#
# Monitor a ISDN4BSD/ISDN4Linux logfile for incoming calls
# and report/file them.
#
# Author: Ron Klinkien ron@zappa.demon.nl
#
# You need this parm in your mh.private.ini file:
#    callerisdn_log=/var/isdn/isdnd.log
#
# Note: This code is just a starting point...

$callerisdn_log = new File_Item( $config_parms{callerisdn_log} );

if ($Reload) {
    print_msg "ISDN CallerID initialized";
}
if ( $New_Second and $state = said $callerisdn_log) {

    #Log line format to look for:
    #06.10.2001 21:47:52 CHD 00005 I4BTEL alerting: incoming call from 012345678 to 012345678 ()
    if ( $state =~ /(incoming call from)/ ) {
        my ( $cid_number, $to ) = $state =~ / (\S+) to (\S+)/;
        $Save{phone_callerid_nmbr} = $cid_number;
        $Save{phone_callerid_time} = "$Hour:$Minute";
        $Save{phone_callerid_Time} = $Time_Date;

        # Have to implement an interface to CallerID:: to get name etc.
        my $caller_id_data = "None";
        my $cid_name       = "Unknown";
        my $caller_id_data = "Unknown";

        print_log
          "Callerid data: number=$cid_number name=$cid_name time=$Time to=$to";
        logit(
            "$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",
            "$cid_number name=$cid_name data=$caller_id_data line=$to"
        );
        logit_dbm( "$config_parms{data_dir}/phone/callerid.dbm",
            $cid_number, "$Time_Now $Date_Now $Year name=$cid_name" );
        speak("Incoming call from $cid_number");
    }
}
