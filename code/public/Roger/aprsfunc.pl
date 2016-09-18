# Category=APRS

# Roger Bille 2002-01-07

# This script include all position subroutines

use Math::Trig;

#
# APRSPosition is called when a position packet has been received
#
sub APRSPosition {
    my ( $Source, $Dest, $Data ) = @_;
    my ($i);    # one time variables, can be reused
    my ( $lat, $lon, $speed, $course );
    my ( $Dist, $Bearing );

    $i = substr( $Data, 0, 1 );

    # 	if ($i =~ /[!\/=@]/ ) {			# Match !/=@ for clear text position
    if ( $i eq '!' or $i eq '/' or $i eq '=' or $i eq '@' )
    {           # Match !/=@ for clear text position
        ( $lat, $lon, $speed, $course ) = split( ',', &APRSPos($Data) );
    }
    elsif ( $i eq '$' ) {    # GPS
        ( $lat, $lon, $speed, $course ) = split( ',', &APRSPosGPS($Data) );
    }
    else {                   # Only Mic-E remain
        ( $lat, $lon, $speed, $course ) =
          split( ',', &APRSPosMicE( $Dest, $Data ) );
    }
    $lat = round( $lat, 4 );
    $lon = round( $lon, 4 );

    print_msg "$Source $Data";

    ( $Dist, $Bearing ) = split(
        ',',
        &CalcDistance(
            $config_parms{latitude}, $config_parms{longitude},
            $lat, $lon
        )
    );

    #	$Dist = round(&CalcDistance ($config_parms{latitude}, $config_parms{longitude}, $lat, $lon),1);
    #	$Bearing = round(&CalcBearing($config_parms{latitude}, $config_parms{longitude}, $lat, $lon));
    #	$Bearing = &CalcBearing($config_parms{latitude}, $config_parms{longitude}, $lat, $lon);

    $Dist = round( $Dist, 1 );
    $Bearing = round($Bearing);

    print_msg sprintf( "%-9s => %2.4f %2.4f %4d %4d %4.1f %d",
        $Source, $lat, $lon, $speed, $course, $Dist, $Bearing );

    &vvRoad( $speed, $lat, $lon );    # Chech if Roadwork should be sent

}

sub APRSPos {
    my ($Data) = @_;
    my ( $lat, $lon, $speed, $course );
    my ($o);                          # Payload offset
    $o = 0;
    if ( substr( $Data, 0, 1 ) =~ /[\/@]/ ) { $o = 7 }
    ;                                 # If / or @, it is with timestamp
    print_msg "Processing lat-lon";
    $lat = ( substr( $Data, $o + 1, 2 ) + ( substr( $Data, $o + 3, 5 ) / 60 ) );
    $lon =
      ( substr( $Data, $o + 11, 2 ) + ( substr( $Data, $o + 13, 5 ) / 60 ) );
    $speed  = 0;
    $course = 0;

    if (    substr( $Data, $o + 19, 1 ) ne '_'
        and substr( $Data, $o + 23, 1 ) eq '/' )
    {    # Packet is not a weather packat and has speed/course
        print_msg "Processing course-speed";
        $course = substr( $Data, $o + 20, 3 );
        $speed  = substr( $Data, $o + 24, 3 );
        $speed = ( $speed * 1.853248 );    # km/h
    }
    return join( ',', $lat, $lon, $speed, $course );
}

sub APRSPosGPS {
    my ($Data) = @_;
    my ( $lat, $lon, $speed, $course );
    if ( substr( $Data, 0, 6 ) eq '$GPRMC' ) {
        ( $lat, $lon, $speed, $course ) = ( split( ',', $Data ) )[ 3, 5, 7, 8 ];
        $lat = ( substr( $lat, 0, 2 ) + ( substr( $lat, 2, 8 ) / 60 ) );
        $lon = ( substr( $lon, 0, 3 ) + ( substr( $lon, 3, 8 ) / 60 ) );
        $speed = ( $speed * 1.853248 );    # km/h
    }
    if ( substr( $Data, 0, 6 ) eq '$GPGGA' ) {
        ( $lat, $lon ) = ( split( ',', $Data ) )[ 2, 4 ];
        $lat = ( substr( $lat, 0, 2 ) + ( substr( $lat, 2, 8 ) / 60 ) );
        $lon = ( substr( $lon, 0, 3 ) + ( substr( $lon, 3, 8 ) / 60 ) );
        $speed  = 0;
        $course = 0;
    }
    return join( ',', $lat, $lon, $speed, $course );
}

sub APRSPosMicE {    # This is mainly coming from Brian Kliers tracking.pl
    my ( $Dest, $Data ) = @_;
    my ( $lat, $lon, $speed, $course );
    my ( $GPSLongitudeDegrees, $GPSLongitudeMinutes, $GPSLongitudeMinutes100 );
    my ( $GPSLatitudeDegrees,  $GPSLatitudeMinutes,  $GPSDistance );
    my ($temp);

    $GPSLongitudeDegrees = ( substr( $Data, 1, 1 ) );
    $GPSLongitudeDegrees = ( unpack( 'C', $GPSLongitudeDegrees ) ) - 28;
    if ( $GPSLongitudeDegrees >= 180 and $GPSLongitudeDegrees <= 189 ) {
        $GPSLongitudeDegrees = $GPSLongitudeDegrees - 80;
    }
    if ( $GPSLongitudeDegrees >= 190 and $GPSLongitudeDegrees <= 199 ) {
        $GPSLongitudeDegrees = $GPSLongitudeDegrees - 190;
    }
    $GPSLongitudeMinutes = ( substr( $Data, 2, 1 ) );
    $GPSLongitudeMinutes = ( unpack( 'C', $GPSLongitudeMinutes ) ) - 28;
    if ( $GPSLongitudeMinutes > 60 ) {
        $GPSLongitudeMinutes = $GPSLongitudeMinutes - 60;
    }
    $GPSLongitudeMinutes100 = ( substr( $Data, 3, 1 ) );
    $GPSLongitudeMinutes100 = ( unpack( 'C', $GPSLongitudeMinutes100 ) ) - 28;

    $lon =
      ( $GPSLongitudeDegrees +
          ( $GPSLongitudeMinutes / 60 ) +
          ( $GPSLongitudeMinutes100 / 6000 ) );

    $speed = ( substr( $Data, 4, 1 ) );
    $speed = ( ( unpack( 'C', $speed ) ) - 28 ) * 10;
    $temp = ( substr( $Data, 5, 1 ) );
    $speed = ( ( ( unpack( 'C', $temp ) ) - 28 ) / 10 ) + $speed;

    $course = ( ( unpack( 'C', $temp ) ) - 28 ) % 10;
    $temp = ( substr( $Data, 6, 1 ) );
    $course = ( ( unpack( 'C', $temp ) ) - 28 ) + $course;

    if ( $speed >= 800 ) { $speed = $speed - 800 }
    ;    # Last minute course and speed adjustments per specs
    if ( $course >= 400 ) { $course = $course - 400 }

    $speed = ( $speed * 1.853248 );     # km/h
    $course = substr( $course, 0, 3 )
      ;    # Truncate Course to max of	3 numbers for parsing below

    $speed = round($speed);    # Round	the	Speed to the nearest integer

    $GPSLatitudeDegrees =
      ( substr( $Dest, 0, 1 ) );    # Load the tens	digit of Degrees Latitude
    $GPSLatitudeDegrees = ( unpack( 'C', $GPSLatitudeDegrees ) ) - 32;
    $GPSLatitudeDegrees = ( $GPSLatitudeDegrees & 15 ) * 10;

    $GPSDistance = ( substr( $Dest, 1, 1 ) )
      ;    # Load the ones	digit of Degrees Latitude (temp	variable used)
    $GPSDistance = ( unpack( 'C', $GPSDistance ) ) - 32;
    $GPSDistance = ( $GPSDistance & 15 );

    $GPSLatitudeDegrees =
      $GPSLatitudeDegrees + $GPSDistance;    # Here's our Degrees Latitude

    $GPSLatitudeMinutes =
      ( substr( $Dest, 2, 1 ) );    # Load the tens	digit of Minutes Latitude
    $GPSLatitudeMinutes = ( unpack( 'C', $GPSLatitudeMinutes ) ) - 32;
    $GPSLatitudeMinutes = ( $GPSLatitudeMinutes & 15 ) * 10;

    $GPSDistance = ( substr( $Dest, 3, 1 ) )
      ;    # Load the ones	digit of Minutes Latitude (temp	variable used)
    $GPSDistance = ( unpack( 'C', $GPSDistance ) ) - 32;
    $GPSDistance = ( $GPSDistance & 15 );

    $GPSLatitudeMinutes =
      $GPSLatitudeMinutes + $GPSDistance;    # Here's our Minutes Latitude

    $temp = ( substr( $Dest, 4, 1 ) )
      ;    # Load the tens	digit of hundreds of Minutes Latitude
    $temp = ( unpack( 'C', $temp ) ) - 32;
    $temp = ( $temp & 15 ) * 10;

    $GPSDistance = ( substr( $Dest, 5, 1 ) )
      ;    # Load the ones	digit of hundreds of Minutes Latitude
    $GPSDistance = ( unpack( 'C', $GPSDistance ) ) - 32;
    $GPSDistance = ( $GPSDistance & 15 );

    $temp = $temp + $GPSDistance;    # Here's our hundreds of Minutes Latitude
    $lat =
      ( $GPSLatitudeDegrees + ( $GPSLatitudeMinutes / 60 ) + ( $temp / 6000 ) );

    return join( ',', $lat, $lon, $speed, $course );
}

# This routine will	calculate the distance in km and bearing between 2 positions.
# The positions	need to	be in decimal degrees
# Arguments	are	lat1, lon1,	lat2, lon2
# Haversine	Formula	is used.
# Reference: http://www.census.gov/cgi-bin/geo/gisfaq?Q5.1
# Roger	Bille 2001-08-04
sub CalcDistance {
    my ( $lat1, $lon1, $lat2, $lon2 ) = @_;
    my ( $sin2lat, $sin2lon, $dist, $distance, $bearing );

    $lat1 = $lat1 * 0.017453293;    # Convert to radians (degress *	pi/180)
    $lon1 = $lon1 * 0.017453293;
    $lat2 = $lat2 * 0.017453293;
    $lon2 = $lon2 * 0.017453293;

    # Haversine	Formula
    $sin2lat =
      ( 1 - cos( 2 * ( ( $lat1 - $lat2 ) / 2 ) ) ) / 2;    # Haversine Formula
    $sin2lon = ( 1 - cos( 2 * ( ( $lon1 - $lon2 ) / 2 ) ) ) / 2;
    $dist = $sin2lat + ( cos $lat1 ) * ( cos $lat2 ) * $sin2lon;
    $dist = 2 * atan2( sqrt($dist), sqrt( 1 - $dist ) );
    $distance = $dist * 6371;    # 6371 km =	Radius ot the Earth where I am

    # Law of Cosines for Spherical Trigonometry (Not normally recommended)

    #	$dist = acos(sin($lat1)*sin($lat2) + cos($lat1)*cos($lat2)*cos($lon1-$lon2));
    #	$distance = $dist * 6371;							# 6371 km =	Radius ot the Earth

    if ( ( sin($dist) * cos($lat1) ) != 0 ) {
        $bearing = acos( ( sin($lat2) - sin($lat1) * cos($dist) ) /
              ( sin($dist) * cos($lat1) ) );
        if ( sin( $lon1 - $lon2 ) > 0 ) {
            $bearing = 2 * 3.1415926536 - $bearing;
        }
        $bearing = $bearing / 0.017453293;    # Back to degrees
    }
    else {
        $bearing = 0;
    }

    return join( ',', $distance, $bearing );
}

#
# This will set Send in Roadwork for all rows which are within 50 km from the mobile APRS station
# when it travel at 20 km/h or more
#
sub vvRoad {
    my ( $mySpeed, $lat, $lon ) = @_;
    my (
        $dbh6,          $sth6, $sth7,     $query_select6,
        $query_update6, $myID, $myLatLon, $myLat,
        $myLon,         $myDist
    );
    my ($myBearing);
    if ( $mySpeed >= 20 ) {
        $dbh6          = DBI->connect('DBI:ODBC:vv');
        $query_select6 = "SELECT ID,LatLon FROM Roadwork WHERE LatLon <> Null";
        $sth6          = $dbh6->prepare($query_select6)
          or print "Can't prepare $query_select6: $dbh6->errstr\n";
        $sth6->execute() or print "can't execute the query: $sth6->errstr\n";
        while ( ( $myID, $myLatLon ) = $sth6->fetchrow_array ) {
            $myLat = (
                substr( $myLatLon, 0, 2 ) +
                  ( substr( $myLatLon, 2, 5 ) / 60 ) );
            $myLon = (
                substr( $myLatLon, 10, 2 ) +
                  ( substr( $myLatLon, 12, 5 ) / 60 ) );
            ( $myDist, $myBearing ) =
              &CalcDistance( $lat, $lon, $myLat, $myLon );
            if ( $myDist <= 50 ) {
                $query_update6 =
                  "UPDATE Roadwork SET Send = Yes WHERE ID = $myID";
                $sth7 = $dbh6->prepare($query_update6)
                  or print "Can't prepare $query_update6: $dbh6->errstr\n";
                $sth7->execute()
                  or print "can't execute the query: $sth7->errstr\n";
                $sth7->finish();
            }
        }
        $sth6->finish();
        $dbh6->disconnect();
    }
}
