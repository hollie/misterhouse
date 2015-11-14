# Category = Weather

my $wx_warnings = "$config_parms{data_dir}/web/wx_warnings";
$p_wx_warnings = new Process_Item
  "get_url http://www.weather.gov/alerts/mn.cap $wx_warnings.xml";
$v_wx_warnings =
  new Voice_Cmd '[Get,Show,Display,Read,Parse] the latest NWS Announcements';

$state = said $v_wx_warnings;
if ( $state eq 'Get'
    or time_cron('1,11,21,31,41,51 10,11,12,13,14,15,16,17,18,19,20 * * *') )
{
    print_log "Getting NWS Alerts";
    start $p_wx_warnings;
}
display "$wx_warnings.txt" if $state eq 'Show' or $state eq 'Display';
speak "$wx_warnings.txt" if $state eq 'Read';

if ( done_now $p_wx_warnings or $state eq 'Parse' ) {
    my ( $finalsummarytx, $finalsummary, $summary, $tempcode, $localwarnflag,
        $i );
    $localwarnflag = 0;
    for ( file_read "$wx_warnings.xml" ) {
        $summary = "";
        $summary .= "The national weather service has issued a $1"
          if /<cap:event>(.+)<\/cap:event>/;
        $summary .= " .. " if /<cap:expires>(.+)<\/cap:expires>/;

        #$summary .= " until $1 for Rice County."  if /<cap:expires>(.+)<\/cap:expires>/;
        $summary .= "$1." if /<cap:description>(.+)<\/cap:description>/;
        $tempcode = "$1" if /<cap:geocode>(.+)<\/cap:geocode>/;
        if ( $tempcode eq '027131' ) {
            $localwarnflag = 1;
            $finalsummary .= $summary;
        }
    }
    if ( $localwarnflag == 1 ) {
        speak $finalsummary;
        play( 'file' => 'C:\MH\SOUNDS\MSG.WAV' );
        if ( $finalsummary =~ m/WARNING/i ) {
            play( 'file' => 'C:\MH\SOUNDS\STALLHRN2.WAV' );
        }

        $finalsummarytx = "$HamCall>APRSMH,TCPIP*:BLN9RICE :";

        #$finalsummarytx = ":BLN9RICE :";
        $finalsummarytx .= $finalsummary;
        print_log $finalsummarytx;
        if ( state $enable_transmit eq 'yes' ) {
            set $tnc_output $finalsummarytx;
        }
    }
    file_write "$wx_warnings.txt", $finalsummary;
    display "$wx_warnings.txt";
}
