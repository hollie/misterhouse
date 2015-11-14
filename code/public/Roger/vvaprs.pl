# Category=APRS

# Roger Bille

use DBI;
my (
    $dbh2,    $query_update2, $query_insert2, $query_select2,
    $sth2,    $sth3,          @row2,          $count,
    $aprs_vv, $aprs_time2
);
my ($myTime);
my (
    $myraw,  $myTyp,  $myLan, $myLatLon, $myID,
    $myNamn, $myDesc, $i,     $k,        $objName
);
my ( $mySecond, $myMinute, $myHour,  $myMday, $myMonth, $myYear );
my ( $RID,      $RName,    $RLatLon, $LID,    $LName,   $LLatLon );

#$tnc_output	= new Socket_Item(undef, undef,	'192.168.75.2:14579');	 # Nordic feed
#$tnc_output3	= new Socket_Item(undef, undef,	'192.168.75.102:1448');

#unless (active $tnc_output3)	{
#   print_log "Starting a connection	to tnc_output3";
#   start $tnc_output3;
#   set $tnc_output3 "user SM5NRK-1 pass 18346 vers Perl 1.0\n\r";
#   print_log "Tracking Interface has been Initialized...Callsign $HamCall";
#}

$vv_aprs = new Voice_Cmd('[Send] vv aprs');
$vv_aprs->set_info('Send vv aprs');

#if (said $vv_aprs eq 'Send' or time_cron('23 * * * *') or $New_Minute) {
if ( new_second 20 ) {

    # 	my ($myraw, $myLage, $myNamn, $myTyp, $myBer, $myRes, $myBesk) = @_;
    #	if ($myraw !~ /Läge:Namn:Typ:/ and $myLage !~ /^Lv/) {
    $dbh2   = DBI->connect('DBI:ODBC:vv');
    $myTime = $Time - 1800;
##		$myTime = $Time - 60;  # Used for debug
    #		print_msg "$Time $myTime";
    $query_select2 =
      "SELECT raw,LatLon,ID,Typ,Lan,Namn FROM Roadwork WHERE Sent < $myTime and LatLon <> Null and Send = Yes ORDER BY Sent ";
    $sth2 = $dbh2->prepare($query_select2)
      or print "Can't prepare $query_select2: $dbh2->errstr\n";
    $sth2->execute() or print "can't execute the query: $sth2->errstr\n";
    $count = 0;

    #		$myTime = $Year . "-" . $Month . "-" . $Mday . " " . $Time_Now;
    while ( ( $myraw, $myLatLon, $myID, $myTyp, $myLan, $myNamn ) =
        $sth2->fetchrow_array )
    {
        $count++;

        #			print_msg "==> $myraw";
        if ( $count <= 1 ) {

            #				print "==> @row2\n";
            #				print "==> $row[1]\n";

            # Create APRS packet
            # SM5NRK-3>APU24L,TRACE3-3:;TEST     *211938z6023.49N\01528.53E! rb
            # Let $i equals	the	number of spaces for object name
            $objName = "SM" . $myLan . "-" . $myID;
            $i       = ( 9 - length($objName) );
            $k       = ' ';
            $k       = ( $k x $i );
            ( $mySecond, $myMinute, $myHour, $myMday, $myMonth, $myYear ) =
              gmtime $Time;
            if ( $myMday < 10 )   { $myMday   = "0" . $myMday }
            if ( $myHour < 10 )   { $myHour   = "0" . $myHour }
            if ( $myMinute < 10 ) { $myMinute = "0" . $myMinute }

            #				print_msg gmtime();
            $myDesc = substr( $myTyp . $myNamn, 0, 43 );

            #				print_msg ($myDesc);
            $aprs_vv = "SM5NRK-1>APRS,TRACE3-3:;" . $objName . $k . "*";
            $aprs_vv = $aprs_vv . $myMday . $myHour . $myMinute . "z";
            $aprs_vv = $aprs_vv . $myLatLon . "n" . $myDesc;
            print_msg "$aprs_vv";
            set $tnc_output $aprs_vv;

            #				set	$tnc_output3	$aprs_vv;

            $query_update2 =
              "UPDATE Roadwork SET Sent = $Time,Send = No WHERE raw = \'$myraw\'";
            $sth3 = $dbh2->prepare($query_update2)
              or print "Can't prepare $query_update2: $dbh2->errstr\n";
            $sth3->execute()
              or print "can't execute the query: $sth3->errstr\n";
        }

    }

    #		@row2=$sth2->fetchrow_array;
    #    	print "==> @row2\n";
    #		($BerStart, $BerStopp) = split(/--/,$myBer);
    #		$myTime = $Year . "-" . $Month . "-" . $Mday . " " . $Time_Now;
    #   	if ($row[0] eq "") {
    #	   		$query_insert = "INSERT into Roadwork (raw,Lage,Namn,Typ,Ber,Start,Stopp,Res,Besk,Last,Add) values (\'$myLage $myNamn $myTyp\',\'$myLage\',\'$myNamn\',\'$myTyp\',\'$myBer\',\'$BerStart\',\'$BerStopp\',\'$myRes\',\'$myBesk\',\'$myTime\',\'$myTime\')";
    #			$sth = $dbh->prepare($query_insert) or print "Can't prepare $query_insert: $dbh->errstr\n";
    #    		$sth->execute() or print "can't execute the query: $sth->errstr\n";
    #    	} else {
    #	   		$query_update = "UPDATE Roadwork SET Last = \'$myTime\' WHERE raw = \'$myLage $myNamn $myTyp\'";
    # 			$sth = $dbh->prepare($query_update) or print "Can't prepare $query_update: $dbh->errstr\n";
    #    		$sth->execute() or print "can't execute the query: $sth->errstr\n";
    #		}
    $sth2->finish();
    $dbh2->disconnect();

    #    }
}

$vv_test = new Voice_Cmd('[Test] Test vv aprs');
$vv_test->set_info('test aprs');

my ( $dbh4, $sth4, $query_delete, $myTime2 );

if ( $New_Day or said $vv_test eq 'Test' ) {
    $dbh4    = DBI->connect('DBI:ODBC:vv');
    $myTime2 = $Year . "-" . $Month . "-" . $Mday;
    print "$myTime2";

    #		$query_delete = "SELECT * FROM Roadwork WHERE Stopp < #$myTime2#";
    $query_delete = "DELETE * FROM Roadwork WHERE Stopp < #$myTime2#";
    $sth4         = $dbh4->prepare($query_delete)
      or print "Can't prepare $query_delete: $dbh4->errstr\n";
    $sth4->execute() or print "can't execute the query: $sth4->errstr\n";

    #		while (@row2=$sth4->fetchrow_array) { print "==> @row2\n" };
    $sth4->finish();
    $dbh4->disconnect();
}

$vv_mail = new Voice_Cmd('[Mail] Mail vv aprs');
$vv_mail->set_info('mail aprs');

my ( $dbh5, $sth5, $query_delete, $myTime3 );

if ( new_minute 15 or said $vv_mail eq 'Mail' ) {
    $dbh5 = DBI->connect('DBI:ODBC:vv');
    $query_select =
      "SELECT Roadwork.ID,Roadwork.Namn,Roadwork.LatLon,Location.ID,Location.Namn,Location.LatLon FROM Roadwork,Location WHERE LocCheck = No and Roadwork.Namn = Location.Namn and (Roadwork.LatLon Is Null or Location.LatLon Is Null)";
    $sth5 = $dbh5->prepare($query_select)
      or print "Can't prepare $query_select: $dbh5->errstr\n";
    $sth5->execute() or print "can't execute the query: $sth5->errstr\n";
    $count = 1;
    while ( ( $RID, $RName, $RLatLon, $LID, $LName, $LLatLon ) =
        $sth5->fetchrow_array )
    {
        $count++;
        print "==> $RID, $RName, $RLatLon, $LID, $LName, $LLatLon";
        if ( $RLatLon eq "" and $LLatLon ne "" ) {
            $query_update2 =
              "UPDATE Roadwork SET LatLon = \'$LLatLon\' WHERE ID = $RID";
            $sth3 = $dbh5->prepare($query_update2)
              or print "Can't prepare $query_update2: $dbh5->errstr\n";
            $sth3->execute()
              or print "can't execute the query: $sth3->errstr\n";
            $sth3->finish();
        }
        if ( $RLatLon ne "" and $LLatLon eq "" ) {
            $query_update2 =
              "UPDATE Location SET LatLon = \'$RLatLon\' WHERE ID = $LID";
            $sth3 = $dbh5->prepare($query_update2)
              or print "Can't prepare $query_update2: $dbh5->errstr\n";
            $sth3->execute()
              or print "can't execute the query: $sth3->errstr\n";
            $sth3->finish();
        }
    }
    $query_insert2 =
      "INSERT into Location (Namn) SELECT DISTINCT Namn FROM Roadwork WHERE Namn not in (select namn from Location) order by namn";
    $sth3 = $dbh5->prepare($query_insert2)
      or print "Can't prepare $query_insert2: $dbh5->errstr\n";
    $sth3->execute() or print "can't execute the query: $sth3->errstr\n";
    $sth3->finish();
    $sth5->finish();

    $myTime3      = $Year . "-" . $Month . "-" . $Mday;
    $query_select = "SELECT * FROM Roadwork WHERE Mail = No and LatLon Is Null";
    $sth5         = $dbh5->prepare($query_select)
      or print "Can't prepare $query_select: $dbh5->errstr\n";
    $sth5->execute() or print "can't execute the query: $sth5->errstr\n";
    while ( @row2 = $sth5->fetchrow_array ) {
        &net_mail_send(
            to      => "roger.bille\@telia.com",
            subject => "APRS VV $row2[0]",
            text    => "@row2"
        );
        $query_update2 = "UPDATE Roadwork SET Mail = Yes WHERE ID = $row2[0]";
        $sth3          = $dbh5->prepare($query_update2)
          or print "Can't prepare $query_update2: $dbh5->errstr\n";
        $sth3->execute() or print "can't execute the query: $sth3->errstr\n";
        $sth3->finish();
    }
    $sth5->finish();
    $dbh5->disconnect();
}
