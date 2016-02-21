
=begin comment

From Paul Estes on 10/2003

NCID Client/Server Network Caller ID Package  http://ncid.sourceforge.net/ 

I use the following code/mine/ncid.pl to monitor NCID's logfile. I haven't
figured out a way to get this worked into CID_Announce or CID_Server, though:

=cut 

# Category = Phone

#@
#@
#@

$NCID = new File_Item('/var/log/cidcall.log');

set_watch $NCID;

if ( my $caller_id_data = said $NCID ) {
    my ( $caller, $cid_number, $cid_name, $time ) =
      &Caller_ID::make_speakable( $caller_id_data, 5 );

    print_log "NCID data=$caller_id_data";
    print "phone number=$cid_number name=$cid_name\n";

    &::logit(
        "$::config_parms{data_dir}/phone/logs/callerid.$::Year_Month_Now.log",
        "$cid_number name=$cid_name line=1 type=in" );
    &::logit_dbm( "$::config_parms{data_dir}/phone/callerid.dbm",
        $cid_number, "$::Time_Now $::Date_Now $::Year name=$cid_name" );
}
