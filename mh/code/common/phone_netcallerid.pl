# Category = Phone
#

#@ This will announce caller id and call waiting id names
#@ using the $30 NetCallerID device.
#@ from <a href=http://ugotcall.com/nci.htm>ugotcall.com</a>
#@ also available from <a href=http://www.cyberguys.com>cyberguys.com</a>
#@ Use these mh.ini parms:
#@   serial_netcallerid_port     = COM2
#@   serial_netcallerid_baudrate = 4800



=begin comment

 This will do callerid and call waiting id (tells you who is 
 calling even you are on the phone).
 To enable call waiting id, you need to have this device
 in series with your phones.  If hooked in parallel, it will
 only do normal caller id.
 You also need the 'caller waiting id' service.

 One user also needed this parm, as for some reason the
 default break characters of \n or \r was not being seen:
  serial_netcallerid_break    = \+\+\+

 Another version of code is Timothy Spaulding mh/code/public/NetCallerID.pl

=cut


$NetCallerID = new Serial_Item (undef, undef, 'serial_netcallerid');

                                # Speak incoming callerID data and log it
if (my $caller_id_data = said $NetCallerID) {
    
    print_log "NetCallerID data=$caller_id_data";

    my ($caller, $cid_number, $cid_name) = &Caller_ID::make_speakable($caller_id_data, 4);
    if ($caller =~ /\.wav$/) {
        $caller = "phone_call.wav,$caller,phone_call.wav,$caller";  # Prefix 'phone call'
    }
    else {
        $caller = "Call from $caller.  Call is from $caller.";
    }

                                # If we have other callerID interfaces (e.g. phone_modem.pl)
                                # lets not repeat ourselfs here. 
    unless ($Time - $Save{phone_callerid_Time} < 3) {
        $Save{phone_callerid_data} = sprintf("%02d:%02d %s\n%s", $Hour, $Minute, $cid_number, $caller);
        $Save{phone_callerid_Time} = $Time;

        unless ($Caller_ID::reject_name_by_number{$cid_number}) {
            play rooms => 'all', file => 'ringin.wav,ringin.wav'; # Simulate a phone ring
            speak("rooms=all_and_out mode=unmuted $caller");
#           speak("address=piano $caller");
        }
        logit("$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",  
              "$cid_number name=$cid_name data=$caller_id_data line=W");
        logit_dbm("$config_parms{data_dir}/phone/callerid.dbm", $cid_number, "$Time_Now $Date_Now $Year name=$cid_name");
    }
}

                                # Log outgoing phone numbers
if ($state = state_now $phonetone) {
    logit("$config_parms{data_dir}/phone/logs/phone.$Year_Month_Now.log", $state);
    print_log "Phone data: $state";
}

