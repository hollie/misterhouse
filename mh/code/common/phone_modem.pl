# Category=Phone

#@ Uses a callerid modem to announce and log incoming phone calls.
#@ Add these entries to your mh.ini file:
#@  serial_modem_port=COM1  
#@  serial_modem_baudrate=38400
#@  serial_modem_handshake=dtr
#@  modem_init=ATE1V1X4&C1&D2S0=0+VCID=1  (tune to your modem)

=cut comment

Some good advice from chaz on debuging modems:

 First make sure it properly works in windows. Try to connect with it through "hyperterminal".
 Just send it a "at" command, and see if it returns "OK". If you get that far, 
 that should get rid of the error message in mh. To see if it supports callerid, 
 and figure out which kind of commands it takes, try in hyperterminal
  "at+cid=1", "at+vcid=1", "at#cid=1", "at#vcid=1". 
 One of these will give you an "OK" if it supports it (is there any other format???). 
 Then you'll have to change the init string in mh accordingly. 
 Any modem that supports callerid will work in mh, but some (most?) of them will miss some calls.

=cut

use vars '$PhoneModemString';         # Used in voicemodem.pl

my $language_code="english";
#my $language_code="swiss-german";

$phone_modem = new Serial_Item (undef, undef, 'serial_modem');

if ($Reload) {
    my $init = $config_parms{modem_init};
# David L. reports a no-name external Rockwell modem wants #CID=1 (instead of +VCID=1)
# Zyxel 2864I-Switzerland:  ATE1V1S40.2=1S41.6=1S42.2=1&L1M3N1'
    $init = 'ATE1V1X4&C1&D2S0=0+VCID=1' unless $init;
    set $phone_modem $init;     # Initialize MODEM
    print_log "Caller ID Interface has been Initialized...";
}

my $caller_id_data;
if ($PhoneModemString = said $phone_modem) {
                                # Ignore garbage data (ascii is between ! thru ~)
    $PhoneModemString = '' if $PhoneModemString !~ /^[\n\r\t !-~]+$/;
    $caller_id_data .= ' ' . $PhoneModemString;
    print "Modem data: $PhoneModemString\n" if $config_parms{debug} eq 'phone';
	if ($caller_id_data =~ /NAME.+NMBR/ or
        $caller_id_data =~ /NMBR.+NAME/ or
        $caller_id_data =~ /FM:/) {
        print_log "Modem callerid: $caller_id_data\n";
                                # Example of data from Switzerland
                                #   - Modem said: FM:07656283xx TO:86733xx

        my ($caller, $cid_number, $cid_name, $cid_time) = &Caller_ID::make_speakable($caller_id_data, 2,$language_code);
        $Save{phone_callerid_data} = sprintf("%02d:%02d %s\n%s", $Hour, $Minute, $cid_number, $caller);
        $Save{phone_callerid_Time} = $Time;
        if ($caller =~ /\.wav$/) {
            play "rooms=all phone_call.wav,$caller";  # Prefix 'phone call'
        }
        else {
            if ($language_code =~/swiss-german/) {
                $caller = "Anruf von $cid_number.  Anruf ist von $caller.";
                $cid_name = $caller;
            }
            else {
                $caller = "Call from $caller.  Phone call is from $caller.";
            }
        }

        print_log "Modem callerid data: number=$cid_number name=$cid_name time=$cid_time data=$caller_id_data\n"
          if $config_parms{debug} eq 'phone';

                                # If we have other callerID interfaces (e.g. phone_netcallerid.pl)
                                # lets not repeat ourselfs here. 
        unless ($Time - $Save{phone_callerid_Time} < 3) {
            $Save{phone_callerid_data} = sprintf("%02d:%02d %s\n%s", $Hour, $Minute, $cid_number, $caller);
            $Save{phone_callerid_Time} = $Time;

            speak("rooms=all_and_out mode=unmuted $caller");
            logit("$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",  
                  "$cid_number name=$cid_name data=$caller_id_data line=2");
            logit_dbm("$config_parms{data_dir}/phone/callerid.dbm", $cid_number, "$Time_Now $Date_Now $Year name=$cid_name");
        }
        undef $caller_id_data;

        # Optionally log calls that are not in our database.
        # If this caller is not in our caller_id_file, let's save their info
        # in the same format as caller_id_file but to a different file.
        # then we can periodically copy lines from this 2nd file into
        # our caller_id_file. this doesn't check to see if the caller is already
        # in caller_id_file2, because it might be meaningful to see how many
        # calls you receive from a number not in your caller_id_file list.
        unless($Caller_ID::name_by_number{$cid_number}){
            if ($config_parms{caller_id_file2}) {
                logit($config_parms{caller_id_file2}, "$cid_number $caller \n", 0);
            }
        }

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

