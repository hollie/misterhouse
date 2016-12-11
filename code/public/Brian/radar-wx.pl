# This program retrieves current condition information from the Airport 10 minutes past each
# hour, and then sends an APRS packet with this information every hour.

# Category=Vehicles

my ( $DownloadedWindDirection, $DownloadedBarometer, $DownloadedWindSpeed,
    $DownloadedWindGust, $DownloadedTemp, $DownloadedHumidity, $tempwxsend );
my ( $DownloadedRainTotal, $DownloadedRainRate );
my ( $DownDay, $DownHour, $DownMinute );

if ( state $enable_transmit eq 'yes' and time_cron('6,15,21,36,45,51 * * * *') )
{
    run_voice_cmd "Send Faribault Airport Weather";
}

$v_send_remotewx = new Voice_Cmd("Send Faribault Airport Weather");

if ( $state = said $v_send_remotewx) {
    if ( substr( $Weather{Wind}, 0, 3 ) eq 'NNE' ) {
        $DownloadedWindDirection = "023";
    }
    elsif ( substr( $Weather{Wind}, 0, 3 ) eq 'ENE' ) {
        $DownloadedWindDirection = "067";
    }
    elsif ( substr( $Weather{Wind}, 0, 3 ) eq 'ESE' ) {
        $DownloadedWindDirection = "112";
    }
    elsif ( substr( $Weather{Wind}, 0, 3 ) eq 'SSE' ) {
        $DownloadedWindDirection = "157";
    }
    elsif ( substr( $Weather{Wind}, 0, 3 ) eq 'SSW' ) {
        $DownloadedWindDirection = "202";
    }
    elsif ( substr( $Weather{Wind}, 0, 3 ) eq 'WSW' ) {
        $DownloadedWindDirection = "257";
    }
    elsif ( substr( $Weather{Wind}, 0, 3 ) eq 'WNW' ) {
        $DownloadedWindDirection = "292";
    }
    elsif ( substr( $Weather{Wind}, 0, 3 ) eq 'NNW' ) {
        $DownloadedWindDirection = "337";
    }
    elsif ( substr( $Weather{Wind}, 0, 2 ) eq 'NE' ) {
        $DownloadedWindDirection = "045";
    }
    elsif ( substr( $Weather{Wind}, 0, 2 ) eq 'SE' ) {
        $DownloadedWindDirection = "135";
    }
    elsif ( substr( $Weather{Wind}, 0, 2 ) eq 'SW' ) {
        $DownloadedWindDirection = "235";
    }
    elsif ( substr( $Weather{Wind}, 0, 2 ) eq 'NW' ) {
        $DownloadedWindDirection = "315";
    }
    elsif ( substr( $Weather{Wind}, 0, 1 ) eq 'N' ) {
        $DownloadedWindDirection = "360";
    }
    elsif ( substr( $Weather{Wind}, 0, 1 ) eq 'E' ) {
        $DownloadedWindDirection = "090";
    }
    elsif ( substr( $Weather{Wind}, 0, 1 ) eq 'S' ) {
        $DownloadedWindDirection = "180";
    }
    elsif ( substr( $Weather{Wind}, 0, 1 ) eq 'W' ) {
        $DownloadedWindDirection = "270";
    }
    else {
        $DownloadedWindDirection = "360";
    }

    #    for ($i = 0; $i != (length($Weather{Wind})); ++$i) {
    #        if (substr($Weather{Wind}, $i, 3) eq 'mph') {
    #           $DownloadedWindSpeed = substr($Weather{Wind}, ($i-2), 2);
    #        }
    #    }

    $DownloadedWindSpeed = $Weather{WindAvgSpeed};
    $DownloadedWindSpeed = round($DownloadedWindSpeed);

    if ( length( abs($DownloadedWindSpeed) ) == 2 ) {
        $DownloadedWindSpeed = "0" . $DownloadedWindSpeed;
    }
    elsif ( length( abs($DownloadedWindSpeed) ) == 1 ) {
        $DownloadedWindSpeed = "00" . $DownloadedWindSpeed;
    }
    else {
        $DownloadedWindSpeed = "000";
    }

    if ( $DownloadedWindSpeed == 0 ) { $DownloadedWindSpeed = "000" }
    $DownloadedWindSpeed = substr( $DownloadedWindSpeed, 0, 3 );

    #    for ($i = 0; $i != (length($Weather{Wind})); ++$i) {
    #        if (substr($Weather{Wind}, $i, 2) eq 'to') {
    #            $DownloadedWindGust = substr($Weather{Wind}, ($i+3), 2);
    #        }
    #    }

    $DownloadedWindGust = $Weather{WindGustSpeed};
    $DownloadedWindGust = round($DownloadedWindGust);

    if ( length( abs($DownloadedWindGust) ) == 2 ) {
        $DownloadedWindGust = "0" . $DownloadedWindGust;
    }
    elsif ( length( abs($DownloadedWindGust) ) == 1 ) {
        $DownloadedWindGust = "00" . $DownloadedWindGust;
    }
    else {
        $DownloadedWindGust = "000";
    }

    if ( $DownloadedWindGust == 0 ) { $DownloadedWindGust = "000" }
    $DownloadedWindGust = substr( $DownloadedWindGust, 0, 3 );

    $DownloadedTemp = $Weather{TempOutdoor};
    $DownloadedTemp = round($DownloadedTemp);

    if ( length($DownloadedTemp) == 2 ) {
        $DownloadedTemp = "0" . $DownloadedTemp;
    }
    elsif ( length($DownloadedTemp) == 1 ) {
        $DownloadedTemp = "00" . $DownloadedTemp;
    }
    else {
        $DownloadedTemp = $DownloadedTemp;
    }

    if ( length($Mday) == 1 ) {
        $DownDay = "0" . $Mday;
    }
    else {
        $DownDay = $Mday;
    }

    if ( length($Hour) == 1 ) {
        $DownHour = "0" . $Hour;
    }
    else {
        $DownHour = $Hour;
    }

    if ( length($Minute) == 1 ) {
        $DownMinute = "0" . $Minute;
    }
    else {
        $DownMinute = $Minute;
    }

    print_log "Rain: $Weather{RainTotal}  ---  Rain Rate: $Weather{RainRate}";
    $DownloadedBarometer = round( ( $Weather{BaromSea} / .03 ) * 10 );
    if ( length($DownloadedBarometer) == 4 ) {
        $DownloadedBarometer = "0" . $DownloadedBarometer;
    }

    $DownloadedHumidity = $Weather{HumidOutdoor};
    $DownloadedHumidity = round($DownloadedHumidity);
    if ( $DownloadedHumidity eq '100' ) { $DownloadedHumidity = "00" }

    $DownloadedRainTotal = $Weather{RainTotal} * 100;
    $DownloadedRainRate  = $Weather{RainRate} * 100;

    if ( length( abs($DownloadedRainTotal) ) == 2 ) {
        $DownloadedRainTotal = "0" . $DownloadedRainTotal;
    }
    elsif ( length( abs($DownloadedRainTotal) ) == 1 ) {
        $DownloadedRainTotal = "00" . $DownloadedRainTotal;
    }
    else {
        $DownloadedRainTotal = "000";
    }

    if ( $DownloadedRainTotal == 0 ) { $DownloadedRainTotal = "000" }

    if ( length( abs($DownloadedRainRate) ) == 2 ) {
        $DownloadedRainRate = "0" . $DownloadedRainRate;
    }
    elsif ( length( abs($DownloadedRainRate) ) == 1 ) {
        $DownloadedRainRate = "00" . $DownloadedRainRate;
    }
    else {
        $DownloadedRainRate = "000";
    }

    if ( $DownloadedRainRate == 0 ) { $DownloadedRainRate = "000" }

    if ( ( $Minute eq '15' ) || ( $Minute eq '45' ) ) {

        #$tempwxsend = "$HamCall>APRSMH,TCPIP*:;FRBLT    *" . $DownDay . $DownHour . $DownMinute . "/4416.83N/09317.13W_" . $DownloadedWindDirection . "/" . $DownloadedWindSpeed . "g" . $DownloadedWindGust . "t" . $DownloadedTemp . "r...p...P...h" . $DownloadedHumidity . "b" . $DownloadedBarometer . "dU2k";
        $tempwxsend =
            "$HamCall>APRSMH,TCPIP*:;FRBLT    *"
          . $DownDay
          . $DownHour
          . $DownMinute
          . "/4416.83N/09317.13W_"
          . $DownloadedWindDirection . "/"
          . $DownloadedWindSpeed . "g"
          . $DownloadedWindGust . "t"
          . $DownloadedTemp . "r"
          . $DownloadedRainRate . "p"
          . $DownloadedRainTotal . "P...h"
          . $DownloadedHumidity . "b"
          . $DownloadedBarometer . "dU2k";
    }
    else {
        $tempwxsend =
            "$HamCall>APRSMH,TCPIP*:;KFBL     *"
          . $DownDay
          . $DownHour
          . $DownMinute
          . "/4419.62N/09318.48W_"
          . $DownloadedWindDirection . "/"
          . $DownloadedWindSpeed . "g"
          . $DownloadedWindGust . "t"
          . $DownloadedTemp
          . "r...p...P...h"
          . $DownloadedHumidity . "b"
          . $DownloadedBarometer . "dU2k";
    }

    print_log $tempwxsend;

    if ( state $enable_transmit eq 'yes' ) { set $tnc_output $tempwxsend }
    set $telnet $tempwxsend if active $telnet;
}
