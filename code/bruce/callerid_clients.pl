
# Add one of these for each YAC client:  http://www.sunflowerhead.com/software/yac

$cid_client1 = new CID_Server_YAC('localhost');
$cid_client2 = new CID_Server_YAC('192.168.0.11');    # P4

#$cid_client3 = new CID_Server_YAC('192.168.0.85');
#$cid_client4 = new CID_Server_YAC('192.168.0.3');   # C1
#$cid_client5 = new CID_Server_YAC('192.168.0.4');   # C2

# Echo Outgoing numbers to xAP
if ( $state = state_now $phonetone) {
    print_log "xAP CID $state";
    &xAP::send(
        'xAP',
        'CID.Meteor',
        'Outgoing.CallComplete' => {
            DateTime       => &time_date_stamp(20),
            Duration       => '00:00:10',
            Phone          => $state,
            Formatted_Date => $Date_Now,
            Formatted_Time => $Time_Now
        }
    );
}
