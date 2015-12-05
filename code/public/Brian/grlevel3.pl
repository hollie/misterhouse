####################################################
# Dynamic Placefile generation from Findu          #
# For Selected Stations                            #
# Version 1.0                                      #
# By: Brian Klier, N0QVC                           #
# brian@kliernetwork.net, http://kliernetwork.net  #
# You are free to modify and redistribute this     #
# script as long as this box remains on the top of #
# the code.  Feel free to add your own name as     #
# well.                                            #
####################################################

# Category = Vehicles

my ( $ItsRunning, @callretlines, $Temp, $get_url_string, @QVCArray, $StripInfo,
    $QVCArrayBit );
my (
    $ValidReport, $TimeStamp, $GRLatitude, $GRLongitude,
    $GRDirection, $GRSpeed,   $GRTest,     $FinalOutput
);
my ( $ShortCallsign, $ShortCallsignLength, $OtherStuff );

$p_get_track_data   = new Process_Item;
$v_create_placefile = new Voice_Cmd('Create GRLEVEL3 Place File');

if ( time_cron('3,8,13,18,23,28,33,38,43,48,53,58 * * * *') ) {
    run_voice_cmd "Create GRLEVEL3 Place File";
}
if ( $ItsRunning eq '' and said $v_create_placefile) {
    $ItsRunning       = "1";
    $p_get_track_data = new Process_Item;
    open( APRSLOG, ">c:/mh/data/web/grlevel3.txt" );    # Log it
    print APRSLOG "Refresh: 1\n";
    print APRSLOG "Color: 255 255 255\n";
    print APRSLOG
      'IconFile: 1, 16, 16, 8, 8, "http://kliers.net/skywarn/APRS.png"';
    print APRSLOG "\n";
    print APRSLOG 'Font: 1, 11, 1, "Courier New"';
    print APRSLOG "\n";

    #remmed out 2/19/06
    #print APRSLOG 'Font: 2, 8, 1, "Arial"';
    print APRSLOG 'Font: 2, 8, 0, "Arial"';
    print APRSLOG "\n";
    close APRSLOG;

    # Load List of callsigns to retrieve
    open( CALLRET, "$config_parms{code_dir}/grlevel3.lst" );
    @callretlines = <CALLRET>;
    close CALLRET;

    foreach $Temp (@callretlines) {
        chomp $Temp;    # get rid of CR/LF
        $get_url_string =
          "get_url http://www.findu.com/cgi-bin/posit.cgi?call=";
        $get_url_string .= $Temp;
        $get_url_string .= "\&time=1\&comma=1 c:/mh/data/web/";
        $get_url_string .= $Temp;
        $get_url_string .= ".txt";

        add $p_get_track_data $get_url_string;
        start $p_get_track_data;
    }
}

if ( done_now $p_get_track_data) {

    foreach $Temp (@callretlines) {
        $ValidReport = 1;    # assume valid report
        chomp $Temp;         # get rid of CR/LF
        $get_url_string = "c:/mh/data/web/";
        $get_url_string .= $Temp;
        $get_url_string .= ".txt";

        $StripInfo = file_read($get_url_string);
        my $text = &html_to_text($StripInfo);
        $text =~ s/\240/ /g;
        if ( $text =~ /osition/ ) {
            $ValidReport = 0;
        }
        file_write( $get_url_string, $text );

        $StripInfo = file_read($get_url_string);
        open( QVCINFO, $get_url_string );
        @QVCArray = <QVCINFO>;
        close QVCINFO;

        foreach $QVCArrayBit (@QVCArray) {
            ( $TimeStamp, $GRLatitude, $GRLongitude, $GRDirection, $GRSpeed ) =
              ( split( ',', $QVCArrayBit ) )[ 0, 1, 2, 3, 4 ];
        }

        if ( $ValidReport eq '1' ) {
            ( $ShortCallsign, $OtherStuff ) = ( split( '-', $Temp ) )[ 0, 1 ];
            $ShortCallsignLength = ( length($ShortCallsign) );
            $ShortCallsign =
              substr( $ShortCallsign, ( $ShortCallsignLength - 3 ), 3 );

            open( APRSLOG, ">>c:/mh/data/web/grlevel3.txt" );
            print APRSLOG "Object: ";
            print APRSLOG $GRLatitude;
            print APRSLOG ",";
            print APRSLOG $GRLongitude;
            print APRSLOG "\n";
            print APRSLOG "Threshold: 999";
            print APRSLOG "\n";
            print APRSLOG "Icon: 0,0,0,1,181,";
            print APRSLOG '"';
            print APRSLOG uc($Temp);
            print APRSLOG ": Heading ";
            print APRSLOG $GRDirection;
            print APRSLOG " at $GRSpeed";
            print APRSLOG '"';
            print APRSLOG "\n";
            print APRSLOG "Threshold: 150";
            print APRSLOG "\n";
            print APRSLOG "Text: 6, 6, 2, ";
            print APRSLOG '"';

            #print APRSLOG uc($Temp);
            print APRSLOG uc($ShortCallsign);
            print APRSLOG '"';
            print APRSLOG "\n";
            print APRSLOG "End:";
            print APRSLOG "\n";
            close APRSLOG;
        }

    }

    net_ftp(
        file        => 'c:/mh/data/web/grlevel3.txt',
        file_remote => '/public_html/skywarn/grlevel3.txt',
        passive     => '1',
        command     => 'put',
        server      => 'kliers.net',
        user        => 'myusername',
        password    => 'mypassword'
    );
    $ItsRunning = '';
}
