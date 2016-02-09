# Category = xPL

my $xpllastcommand;
my $xpljabberdevice;

$xpl_balloon = new xPL_Item( 'medusa-balloon.klierpc',
    'log.basic' => { speech => '$state' } );
$xpl_jabber      = new xPL_Item('doghouse-blabber.archeserver20');
$xpl_jabber_resp = new xPL_Item(
    'doghouse-blabber.archestar20',
    'control.basic' => {
        device  => 'brian.klier@gmail.com/BlackBerry4BF62086',
        current => '$state'
    }
);

if ( $state = state_now $xpl_jabber) {
    my $xpljabberdevice = $xpl_jabber->{'sensor.basic'}{'device'};

    #print_log "Jabberdevice: $xpljabberdevice";
    my $xpljabbertype = $xpl_jabber->{'sensor.basic'}{'type'};

    #print_log "Jabbertype: $xpljabbertype";
    my $xpljabbercommand = $xpl_jabber->{'sensor.basic'}{'current'};

    #print_log "Jabbercommand: $xpljabbercommand";
    my $xpljabberdevicecon = substr( $xpljabberdevice, 0, 11 );

    #print_log "Jabberdeviceconcat: $xpljabberdevicecon";

    if (    ( $xpljabberdevicecon eq 'brian.klier' )
        and ( $xpljabbertype eq 'message' )
        and ( $xpljabbercommand ne $xpllastcommand ) )
    {
        $xpllastcommand = $xpljabbercommand;
        run_voice_cmd $xpljabbercommand;

        #my $test123 = "testmessage";
        #&xAP::send('xPL', 'doghouse-blabber.archestar20', 'control.basic' => $test123, 'message' => $test123);
        #&xAP::send('xPL', 'doghouse-blabber.archestar20', 'sensor.basic'set $xpl_jabber
        speak "Ran Jabber Command: $xpljabbercommand";
        $page_email = "Ack: $xpljabbercommand";
        set $xpl_jabber_resp 'Ack';
    }
}

if ( state_now $bed_heater eq 'off' ) {
    set $xpl_balloon "The Bed Heater is now off";
}

if ( state_now $cid_interface1 eq 'ring' ) {
    set $xpl_balloon "RING RING RING";
}

#set $xpl_balloon "$Time_Now" if $New_Minute;

#$xpl_cid = new xPL_Item('ag-asterisk.asterisk1local');
#
#if ($state = state_now $xpl_cid) {
#       my $cidname=$xpl_cid->{'cid.asterisk'}{'cln'};
#       my $cidnumber=$xpl_cid->{'cid.asterisk'}{'phone'};
#       print_log "Incoming call from $cidname, number is $cidnumber";
#}
#
#
#
#>04/12/05 08:06:35 AM xpl data: cid.asterisk : cln = 7856336488 |
#>cid.asterisk : calltype = inbound | cid.asterisk : ccs = ring | cid.asterisk
#>: phone = 7856336488 | xpl-trig : source = ag-asterisk.asterisk1local |
#>xpl-trig : target = * | xpl-trig : hop = 1 |
