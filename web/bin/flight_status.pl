# $Date$
# $Revision$
#
# Flight Status portal screen
#
# by Matthew Williams
#
# This script displays a small form that allows the user to select
# an airline and flight number and then obtains the FlightView
# flight status graphic (a GIF) for that flight.
#
# The URL can be overridden by setting the flight_status_url parameter.
# The URL will be suffixed with the flight code.
# e.g. Air Canada flight 123 will result in AC123 being added to the end of the URL.

my $statusURL      = '';
my $scriptLocation = $HTTP_REQUEST;

if ( $HTTP_ARGV{airline} ne '' and $HTTP_ARGV{airline} ne 'none' ) {
    $statusURL = $config_parms{flight_status_url};
    $statusURL = 'http://Tracker.flightview.com/fvTV/fvcgi.exe?qtype=GIF&ACID='
      unless $statusURL;
    $statusURL .= $HTTP_ARGV{airline};
    $statusURL .= int( $HTTP_ARGV{flight} );
}

my $html = '';

if ( $HTTP_ARGV{airline} eq 'none' ) {
    $html .= '<p><h3>You forgot to select an airline!</h3></p>';
}

if ( $statusURL ne '' ) {
    $html .=
      qq[<p><h3>Airline: $HTTP_ARGV{airline}.  Flight Number: $HTTP_ARGV{flight}.</h3></p>
<p><img src="$statusURL"></p>
<p><a href="$scriptLocation">Request the status of another flight</a></p>
<p><a href="$scriptLocation?airline=$HTTP_ARGV{airline}&flight=$HTTP_ARGV{flight}">Refresh this flight status page</a></p>];

}
else {
    $html .= qq[<form method="post" id="main" name="main">
<p><select name="airline">
<option value="none">Please select an airline ...</option>
<option value="TZ" >ATA Airlines - TZ</option>
<option value="EI" >Aer Lingus - EI</option>

<option value="AM" >Aeromexico - AM</option>
<option value="9A" >Air Atlantic - 9A</option>
<option value="AC" >Air Canada - AC</option>
<option value="CA" >Air China - CA</option>
<option value="AF" >Air France - AF</option>
<option value="IJ" >Air Liberte - IJ</option>
<option value="NZ" >Air New Zealand - NZ</option>
<option value="FL" >Air Tran - FL</option>
<option value="TS" >Air Transat (Canada) - TS</option>

<option value="GB" >Airborne Express - GB</option>
<option value="AS" >Alaska Airlines - AS</option>
<option value="AZ" >Alitalia - AZ</option>
<option value="NH" >All Nippon Airways - NH</option>
<option value="G4" >Allegiant Air - G4</option>
<option value="AQ" >Aloha Airlines - AQ</option>
<option value="HP" >America West Airlines - HP</option>
<option value="AA" >American Airlines - AA</option>
<option value="AN" >Ansett Australia - AN</option>

<option value="AV" >Avianca - AV</option>
<option value="UP" >Bahamasair - UP</option>
<option value="JV" >Bearskin Airlines - JV</option>
<option value="GQ" >Big Sky Airways - GQ</option>
<option value="BU" >Braathens - BU</option>
<option value="BA" >British Airways - BA</option>
<option value="BD" >British Midland - BD</option>
<option value="ED" >CCAir - ED</option>
<option value="C6" >CanJet - C6</option>

<option value="CX" >Cathay Pacific - CX</option>
<option value="MU" >China Eastern Airlines - MU</option>
<option value="CZ" >China Southern Airlines - CZ</option>
<option value="CO" >Continental Airlines - CO</option>
<option value="DL" >Delta Air Lines - DL</option>
<option value="BR" >EVA Airways - BR</option>
<option value="U2" >Easyjet - U2</option>
<option value="LY" >El Al Israel Airlines - LY</option>
<option value="AY" >Finnair - AY</option>

<option value="7F" >First Air - 7F</option>
<option value="RF" >Florida West Airlines - RF</option>
<option value="F9" >Frontier Airlines - F9</option>
<option value="GA" >Garuda - GA</option>
<option value="HQ" >Harmony Airways - HQ</option>
<option value="HA" >Hawaiian Airlines - HA</option>
<option value="IB" >Iberia - IB</option>
<option value="FI" >Icelandair - FI</option>
<option value="IC" >Indian Airlines - IC</option>

<option value="IR" >Iran Air - IR</option>
<option value="JD" >Japan Air System - JD</option>
<option value="JL" >Japan Airlines - JL</option>
<option value="QJ" >Jet Airways - QJ</option>
<option value="B6" >JetBlue Airways - B6</option>
<option value="KL" >KLM Royal Dutch Airlines - KL</option>
<option value="KE" >Korean Air Lines - KE</option>
<option value="WJ" >Labrador Airways LTD - WJ</option>
<option value="LH" >Lufthansa - LH</option>

<option value="MY" >MAXjet - MY</option>
<option value="MH" >Malaysian Airline - MH</option>
<option value="YV" >Mesa Airlines - YV</option>
<option value="MX" >Mexicana - MX</option>
<option value="GL" >Miami Air Intl. - GL</option>
<option value="YX" >Midwest Airlines - YX</option>
<option value="NW" >Northwest Airlines - NW</option>
<option value="OA" >Olympic Airways - OA</option>
<option value="PR" >Philippine Airlines - PR</option>

<option value="PO" >Polar Air - PO</option>
<option value="QF" >Qantas Airways - QF</option>
<option value="SN" >Sabena - SN</option>
<option value="S6" >Salmon Air - S6</option>
<option value="SV" >Saudi Arabian Airlines - SV</option>
<option value="SK" >Scandinavian Airlines (SAS) - SK</option>
<option value="YR" >Scenic Airlines - YR</option>
<option value="S5" >Shuttle America - S5</option>
<option value="SQ" >Singapore Airlines - SQ</option>

<option value="5G" >Skyservice - 5G</option>
<option value="SA" >South African Airways - SA</option>
<option value="WN" >Southwest Airlines - WN</option>
<option value="JK" >Spanair - JK</option>
<option value="NK" >Spirit Airlines - NK</option>
<option value="SY" >Sun Country Airlines - SY</option>
<option value="LX" >Swiss Int'l Airllines - LX</option>
<option value="TG" >Thai Airways - TG</option>
<option value="TK" >Turkish Airlines - TK</option>

<option value="US" >US Airways - US</option>
<option value="U5" >USA3000 - U5</option>
<option value="UA" >United Airlines - UA</option>
<option value="VP" >VASP - VP</option>
<option value="RG" >Varig - RG</option>
<option value="VS" >Virgin Atlantic - VS</option>
<option value="WS" >WestJet Airlines - WS</option>
<option value="MF" >Xiamen Airlines - MF</option>
<option value="Z4" >Zoom Airlines - Z4</option>
</select></p>
<p>Flight Number: <input type="text" id="flight" name="flight">
<input type="submit" value="Ok"></p>
</form>
<hr />
];
    $html .= &insert_keyboard(
        { form => 'main', target => 'flight', numeric_keypad => 'yes' } );
}

return $html;
