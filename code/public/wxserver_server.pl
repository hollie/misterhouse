
# Category=Weather
#
# This code implements a simple wxserver server using the weather data
# that misterhouse is tracking.
#
# More info on the protocol and other servers/clients is at
#   http://www.thedrumms.org/~tony/WxServer.html
#
# Enable with this mh.ini parm:  server_wxserver_port=16255

#
#my $WxServerVersionID = 'mh server_wxserver.pl V0.0.1';

$ServerWxServer =
  new Socket_Item( undef, undef, 'server_wxserver', undef, 'tcp', 'raw' );

#                                  Ref             m        b    Units  units
my %WxCommandSet = (
    TCOT => [ 'TempOutdoor',   0.55556, -17.778, 'F',   'C' ],
    TCIT => [ 'TempIndoor',    0.55556, -17.778, 'F',   'C' ],
    TCWS => [ 'WindAvgSpeed',  1.609,   0,       'mph', 'kph' ],
    TCWD => [ 'WindAvgDir',    1,       0,       'deg', 'deg' ],
    TCWC => [ 'WindChill',     0.55556, -17.778, 'F',   'C' ],
    TCGS => [ 'WindGustSpeed', 1.609,   0,       'mph', 'kph' ],
    TCGD => [ 'WindGustDir',   1,       0,       'deg', 'deg' ],
    TCOH => [ 'HumidOutdoor',  1,       0,       '%',   '%' ],
    TCIH => [ 'HumidIndoor',   1,       0,       '%',   '%' ],
    TCDP => [ 'DewOutdoor',    0.55556, -17.778, 'F',   'C' ],
    TCPR => [ 'Barom',         1,       0,       'mb',  'mb' ],
    TCRA => [ 'RainTotal',     25.4,    0,       'in',  'mm' ],
    YHRA => [ 'RainYest',      25.4,    0,       'in',  'mm' ],
    TCRH => [ 'RainRate',      25.4,    0,       'in',  'mm' ]
);

if ( my $data = $ServerWxServer->said ) {
    my $Response;
    if ( substr( $data, 0, 5 ) eq 'TCSVV' ) {
        $Response = 'mh server_wxserver.pl V0.0.1';
    }
    else {
        my $Base;
        my $GroupRef;
        my $Type;
        my @WxGroup;

        $Base = substr( $data, 0, 4 );
        $Type = substr( $data, 4, 1 );
        $GroupRef = $WxCommandSet{$Base};
        @WxGroup = @{$GroupRef} if $GroupRef;

        if (@WxGroup) {
            my $Ref;
            my $m;
            my $b;
            my $Units;
            my $units;
            ( $Ref, $m, $b, $Units, $units ) = @WxGroup;

            if ( $Type eq 'V' || $Type eq 'v' ) {
                $Response = $Weather{$Ref};
                if ( $Type eq 'v' ) {
                    $Response = $Response * $m + $b;
                    $Response = round( $Response, 1 );
                }
            }
            elsif ( $Type eq 'U' ) {
                $Response = $Units;
            }
            elsif ( $Type eq 'u' ) {
                $Response = $units;
            }
        }    # WxGroup ok
    }    # not version request

    # Default to dashes if no corresponding data found
    $Response = "-----" unless $Response;

    $ServerWxServer->set($Response);
    print_log "Response to server query is $Response";
}

