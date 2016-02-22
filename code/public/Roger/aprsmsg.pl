# Category=APRS

# Roger Bille 2002-01-12

# This script handle all incoming APRS messages

sub APRSMsg {
    my ( $Source, $Dest, $Data ) = @_;
    my ($Ack);
    my $HamCall =
      $config_parms{tracking_callsign};    # Feed	in my Tracking Callsign

    if ( substr( $Data, 1, 6 ) eq 'EMAIL9' ) { &APRSMsgEmail( $Source, $Data ) }
    if ( substr( $Data, 1, length($HamCall) ) eq $HamCall ) {
        ( $Data, $Ack ) = ( split( '{', $Data ) )[ 0, 1 ];   # Extract Acknumber
        $Data = ( split( ':', $Data ) )[2];                  # Extract message
        &APRSSendAck( $Source, $Ack );                       # Send Ack
        print_msg
          "New Message recieved from $Source: /cvsroot/misterhouse/mh/code/public/Roger/aprsmsg.pl,v $Data";
        if ( substr( $Data, 0, 2 ) eq 'R ' ) { &APRSMsgRoad($Data) }
    }

}

sub APRSSendAck {
    my ( $Source, $Ack ) = @_;
    my ($packet);
    $packet =
        $config_parms{tracking_callsign}
      . ">APRS:"
      . $Source
      . ( ' ' x ( 9 - length($Source) ) ) . ":ack"
      . $Ack;
    set $tnc_output $packet;
}

sub APRSMsgEmail {
    my ( $Source, $Data ) = @_;
    my ( $EmailAdr, $EmailBody );
    my ($packet);
    my $HamCall =
      $config_parms{tracking_callsign};    # Feed	in my Tracking Callsign
    ( $EmailAdr, $EmailBody ) = split( ' ', $Data, 2 );

    print_log "Email gateway: Callsign=$Source, to=$EmailAdr data=$EmailBody\n";

    # Send the mail!!
    &net_mail_send(
        to      => $EmailAdr,
        subject => "From $Source via APRS Gateway",
        text => "From: $Source\n\n$EmailBody\n\nSent via $HamCall APRS Gateway"
    );
    $packet =
        $HamCall
      . ">APRS:"
      . $Source
      . ( ' ' x ( 9 - length($Source) ) )
      . ":Your E-Mail Message has been sent."
      ;    # Removed {7 at	end	to not get ack
    set $tnc_output $packet;
}

sub APRSMsgRoad {
    my ($Data) = @_;
    my ( $dbh6, $sth7, $query_update6 );
    my $myLan = substr( $Data, 2, 2 );

    #	print "Lan = $myLan\n";
    $dbh6 = DBI->connect('DBI:ODBC:vv');
    if ( $myLan eq "AL" ) {
        $query_update6 = "UPDATE Roadwork SET Send = Yes";
    }
    else {
        $query_update6 =
          "UPDATE Roadwork SET Send = Yes WHERE Lan = \'$myLan\'";
    }

    #	print_msg "$query_update6\n";
    $sth7 = $dbh6->prepare($query_update6)
      or print "Can't prepare $query_update6: $dbh6->errstr\n";
    $sth7->execute() or print "can't execute the query: $sth7->errstr\n";
    $sth7->finish();
    $dbh6->disconnect();
    print_log "Send all Road messages for $myLan Lan";
}
