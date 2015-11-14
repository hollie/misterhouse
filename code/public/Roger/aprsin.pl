# Category=APRS

# Roger Bille 2002-01-07

# This script will monitor the Nordic feed and act on the incoming packages.

my ( $test1, $test2 );    # For testing only

my ($i);                  # one time variables, can be reused
my ( $APRSPacket, $APRSHeader, $APRSData, $APRSSource, $APRSDest );

# my ($APRSDigi);		# Digi path is not used

if (    ( $APRSPacket = said $tnc_output)
    and ( ( $APRSPacket =~ /^SM|^SK|^SL/ ) || ( $APRSPacket =~ /SM5NRK/ ) ) )
{

##sub APRS {
## 	my ($APRSPacket) = @_;

##	my ($test1, $test2);		# For testing only

##	my ($i);					# one time variables, can be reused
##	my ($APRSHeader, $APRSData, $APRSSource, $APRSDest);
    #	$APRSPacket = "SM5NRK-11>APC099,RELAY,TRACE3-3:\@211239z5848.73N/01652.95E>265/030";
    #	print_msg "$APRSPacket";

    $i = index( $APRSPacket, ':' );    # Split Header from Payload
    $APRSHeader = substr( $APRSPacket, 0, $i );
    $APRSData = substr( $APRSPacket, $i + 1 );
    $i = index( $APRSHeader, ',' );    # Split Source/Dest from DigiPath

    #	$APRSDigi   = substr ($APRSHeader, $i +1);			# Digipath is not used
    ( $APRSSource, $APRSDest ) = ( split( '>', substr( $APRSHeader, 0, $i ) ) );

    # Check type of packet
    $i = substr( $APRSData, 0, 1 );
    if ( $i eq '!' ) { &APRSPosition( $APRSSource, $APRSDest, $APRSData ) }
    ;    # Position without timestamp (no APRS messaging)
    if ( $i eq '$' ) { &APRSPosition( $APRSSource, $APRSDest, $APRSData ) }
    ;    # Raw GPS data
    if ( $i eq "'" ) { &APRSPosition( $APRSSource, $APRSDest, $APRSData ) }
    ;    # Old Mic-E and TM-D700
    if ( $i eq ')' ) { }
    ;    # Item
    if ( $i eq '/' ) { &APRSPosition( $APRSSource, $APRSDest, $APRSData ) }
    ;    # Position with timestamp (no APRS messaging)
    if ( $i eq ':' ) { &APRSMsg( $APRSSource, $APRSDest, $APRSData ) }
    ;    # Message
    if ( $i eq ';' ) { }
    ;    # Object
    if ( $i eq '<' ) { }
    ;    # Station Capabilities
    if ( $i eq '=' ) { &APRSPosition( $APRSSource, $APRSDest, $APRSData ) }
    ;    # Position without timestamp (with APRS messaging)
    if ( $i eq '>' ) { }
    ;    # Status
    if ( $i eq '?' ) { }
    ;    # Query
    if ( $i eq '@' ) { &APRSPosition( $APRSSource, $APRSDest, $APRSData ) }
    ;    # Position with timestamp (with APRS messaging)
    if ( $i eq 'T' ) { }
    ;    # Telemetry data
    if ( $i eq '_' ) { }
    ;    # Weather report
    if ( $i eq '`' ) { &APRSPosition( $APRSSource, $APRSDest, $APRSData ) }
    ;    # Mic-E (not TM-D700)
    if ( $i eq '{' ) { }
    ;    # User defined
    if ( $i eq '}' ) { }
    ;    # Third part
}
