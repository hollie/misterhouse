# Category = Phone
#

=begin comment

 This will recv callerid msgs from an audrey running the 
 acid (audrey caller id) version 2.0.

 You also need the 'caller waiting id' service.

 More info at http://www.timemocksme.com/acid/
 
 Use these mh.ini parm(s) -- 1 line for each audrey:
  audrey_callerid_ip_1     = 192.168.1.67
  audrey_callerid_ip_2     = 192.168.1.67:4550  (w/ optional port, dflt is 4550)

$Date$
$Revision$

=cut

use audrey_cid;
my $audrey_ip;

my $cid_name;
my $cid_number;
( $cid_name, $cid_number ) = &audrey_cid::read();
if ($cid_number) {    # did we get anything?
    my $caller_id_data;

    # Speak incoming callerID data and log it

    my $caller = $cid_name;    #probably need to reformat this.

    if ( $caller eq '' ) {
        $caller = "Unknown";
    }

    if ( $cid_number eq 'Private' ) {
        $caller = "Private";
    }

    if ( $caller eq 'No Data' ) {
        $caller = "Unknown";
    }

    my $cid_string = "Call from $caller";

    print_log "CallerId info : $cid_number [$cid_name]";

    # If we have other callerID interfaces (e.g. phone_modem.pl)
    # lets not repeat ourselfs here.
    unless ( $Time - $Save{phone_callerid_Time} < 3 ) {
        $Save{phone_callerid_nmbr} =
          $cid_number;    # Save last caller for display in lcdproc.pl
        $Save{phone_callerid_time} = "$Hour:$Minute";
        $Save{phone_callerid_Time} = $Time;

        #       play rooms => 'all', file => 'ringin.wav,ringin.wav'; # Simulate a phone ring
        # speak "Call from $caller"; # gv added & deleted previous and this statement
        speak voice => 'Female', text => $cid_string;

        #  speak("rooms=all_and_out mode=unmuted $caller");
        logit(
            "$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",
            "$cid_number name=$cid_name data=NA line=W" );
        logit_dbm( "$config_parms{data_dir}/phone/callerid.dbm",
            $cid_number, "$Time_Now $Date_Now $Year name=$cid_name" );
    }
}
