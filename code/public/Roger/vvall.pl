# Category=APRS

# Roger Bille

use DBI;
my (
    $dbh,      $query_update, $query_insert, $query_select,
    $sth,      @row,          @vv,           $lan,
    $BerStart, $BerStopp,     $myTime
);

# RoadWork_2	Stockholms Län

# my ($text, @data, $data, $wind_direction, $wind_speed, $temp, $dew, $presure, $dag);
my ( $text, $vvLine, $count, $vvTot, $msg );
my ( @vvLage, @vvNamn, @vvTyp, @vvBer, @vvRes, @vvBesk );

#use vars '@vvList';
my ( @vvList, @URLList, $URLStart, @vvLan, @vvLanName, @vv, $vvLine, $vvNbr );

my $HtmlFindFlag = 0;

if ($Reload) {
    open( VV, "$config_parms{code_dir}/vvurl.txt" );    # Open for input
    @vv = <VV>;    # Open array and read in data
    close VV;      # Close the file
    $count = 0;
    foreach $vvLine (@vv) {

        #    	print_log $vvLine;
        if ( $vvLine !~ /^\#/ ) {
            ( $vvLan[$count], $vvLanName[$count], $URLList[$count] ) =
              ( split( ',', $vvLine ) )[ 0, 1, 2 ];    # Split each line
            $vvNbr = $count;

            #			print_log $vvLanName[$count];
            $count++;
        }
    }
}

my $vvURL2 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_2.shtml";
my $vvURL3 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_3.shtml";
my $vvURL4 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_4.shtml";
my $vvURL5 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_5.shtml";
my $vvURL6 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_6.shtml";
my $vvURL7 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_7.shtml";
my $vvURL8 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_8.shtml";
my $vvURL9 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_9.shtml";
my $vvURL10 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_10.shtml";
my $vvURL12 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_12.shtml";
my $vvURL13 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_13.shtml";
my $vvURL14 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_14.shtml";
my $vvURL17 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_17.shtml";
my $vvURL18 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_18.shtml";
my $vvURL19 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_19.shtml";
my $vvURL20 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_20.shtml";
my $vvURL21 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_21.shtml";
my $vvURL22 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_22.shtml";
my $vvURL23 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_23.shtml";
my $vvURL24 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_24.shtml";
my $vvURL25 =
  "http://www.vv.se/triss/trafikinfo/rapporter/RoadWorks/RoadWork_25.shtml";

my $vvFile = "vv";

my $f_vv_page2  = "$config_parms{data_dir}/web/vv2.txt";
my $f_vv_html2  = "$config_parms{data_dir}/web/vv2.html";
my $f_vv_page3  = "$config_parms{data_dir}/web/vv3.txt";
my $f_vv_html3  = "$config_parms{data_dir}/web/vv3.html";
my $f_vv_page4  = "$config_parms{data_dir}/web/vv4.txt";
my $f_vv_html4  = "$config_parms{data_dir}/web/vv4.html";
my $f_vv_page5  = "$config_parms{data_dir}/web/vv5.txt";
my $f_vv_html5  = "$config_parms{data_dir}/web/vv5.html";
my $f_vv_page6  = "$config_parms{data_dir}/web/vv6.txt";
my $f_vv_html6  = "$config_parms{data_dir}/web/vv6.html";
my $f_vv_page7  = "$config_parms{data_dir}/web/vv7.txt";
my $f_vv_html7  = "$config_parms{data_dir}/web/vv7.html";
my $f_vv_page8  = "$config_parms{data_dir}/web/vv8.txt";
my $f_vv_html8  = "$config_parms{data_dir}/web/vv8.html";
my $f_vv_page9  = "$config_parms{data_dir}/web/vv9.txt";
my $f_vv_html9  = "$config_parms{data_dir}/web/vv9.html";
my $f_vv_page10 = "$config_parms{data_dir}/web/vv10.txt";
my $f_vv_html10 = "$config_parms{data_dir}/web/vv10.html";
my $f_vv_page12 = "$config_parms{data_dir}/web/vv12.txt";
my $f_vv_html12 = "$config_parms{data_dir}/web/vv12.html";
my $f_vv_page13 = "$config_parms{data_dir}/web/vv13.txt";
my $f_vv_html13 = "$config_parms{data_dir}/web/vv13.html";
my $f_vv_page14 = "$config_parms{data_dir}/web/vv14.txt";
my $f_vv_html14 = "$config_parms{data_dir}/web/vv14.html";
my $f_vv_page17 = "$config_parms{data_dir}/web/vv17.txt";
my $f_vv_html17 = "$config_parms{data_dir}/web/vv17.html";
my $f_vv_page18 = "$config_parms{data_dir}/web/vv18.txt";
my $f_vv_html18 = "$config_parms{data_dir}/web/vv18.html";
my $f_vv_page19 = "$config_parms{data_dir}/web/vv19.txt";
my $f_vv_html19 = "$config_parms{data_dir}/web/vv19.html";
my $f_vv_page20 = "$config_parms{data_dir}/web/vv20.txt";
my $f_vv_html20 = "$config_parms{data_dir}/web/vv20.html";
my $f_vv_page21 = "$config_parms{data_dir}/web/vv21.txt";
my $f_vv_html21 = "$config_parms{data_dir}/web/vv21.html";
my $f_vv_page22 = "$config_parms{data_dir}/web/vv22.txt";
my $f_vv_html22 = "$config_parms{data_dir}/web/vv22.html";
my $f_vv_page23 = "$config_parms{data_dir}/web/vv23.txt";
my $f_vv_html23 = "$config_parms{data_dir}/web/vv23.html";
my $f_vv_page24 = "$config_parms{data_dir}/web/vv24.txt";
my $f_vv_html24 = "$config_parms{data_dir}/web/vv24.html";
my $f_vv_page25 = "$config_parms{data_dir}/web/vv25.txt";
my $f_vv_html25 = "$config_parms{data_dir}/web/vv25.html";
$p_vv_page2  = new Process_Item("get_url $vvURL2 $f_vv_html2");
$p_vv_page3  = new Process_Item("get_url $vvURL3 $f_vv_html3");
$p_vv_page4  = new Process_Item("get_url $vvURL4 $f_vv_html4");
$p_vv_page5  = new Process_Item("get_url $vvURL5 $f_vv_html5");
$p_vv_page6  = new Process_Item("get_url $vvURL6 $f_vv_html6");
$p_vv_page7  = new Process_Item("get_url $vvURL7 $f_vv_html7");
$p_vv_page8  = new Process_Item("get_url $vvURL8 $f_vv_html8");
$p_vv_page9  = new Process_Item("get_url $vvURL9 $f_vv_html9");
$p_vv_page10 = new Process_Item("get_url $vvURL10 $f_vv_html10");
$p_vv_page12 = new Process_Item("get_url $vvURL12 $f_vv_html12");
$p_vv_page13 = new Process_Item("get_url $vvURL13 $f_vv_html13");
$p_vv_page14 = new Process_Item("get_url $vvURL14 $f_vv_html14");
$p_vv_page17 = new Process_Item("get_url $vvURL17 $f_vv_html17");
$p_vv_page18 = new Process_Item("get_url $vvURL18 $f_vv_html18");
$p_vv_page19 = new Process_Item("get_url $vvURL19 $f_vv_html19");
$p_vv_page20 = new Process_Item("get_url $vvURL20 $f_vv_html20");
$p_vv_page21 = new Process_Item("get_url $vvURL21 $f_vv_html21");
$p_vv_page22 = new Process_Item("get_url $vvURL22 $f_vv_html22");
$p_vv_page23 = new Process_Item("get_url $vvURL23 $f_vv_html23");
$p_vv_page24 = new Process_Item("get_url $vvURL24 $f_vv_html24");
$p_vv_page25 = new Process_Item("get_url $vvURL25 $f_vv_html25");
$v_vv_page   = new Voice_Cmd('[Get] vv');
$v_vv_page->set_info('Get vv');

if ( said $v_vv_page eq 'Get' or time_cron('23 * * * *') ) {
    start $p_vv_page2;
    start $p_vv_page3;
    start $p_vv_page4;
    start $p_vv_page5;
    start $p_vv_page6;
    start $p_vv_page7;
    start $p_vv_page8;
    start $p_vv_page9;
    start $p_vv_page10;
    start $p_vv_page12;
    start $p_vv_page13;
    start $p_vv_page14;
    start $p_vv_page17;
    start $p_vv_page18;
    start $p_vv_page19;
    start $p_vv_page20;
    start $p_vv_page21;
    start $p_vv_page22;
    start $p_vv_page23;
    start $p_vv_page24;
    start $p_vv_page25;
}

if ( done_now $p_vv_page2)  { &update( "AB", $f_vv_html2,  $f_vv_page2 ) }
if ( done_now $p_vv_page3)  { &update( "C",  $f_vv_html3,  $f_vv_page3 ) }
if ( done_now $p_vv_page4)  { &update( "D",  $f_vv_html4,  $f_vv_page4 ) }
if ( done_now $p_vv_page5)  { &update( "E",  $f_vv_html5,  $f_vv_page5 ) }
if ( done_now $p_vv_page6)  { &update( "F",  $f_vv_html6,  $f_vv_page6 ) }
if ( done_now $p_vv_page7)  { &update( "G",  $f_vv_html7,  $f_vv_page7 ) }
if ( done_now $p_vv_page8)  { &update( "H",  $f_vv_html8,  $f_vv_page8 ) }
if ( done_now $p_vv_page9)  { &update( "I",  $f_vv_html9,  $f_vv_page9 ) }
if ( done_now $p_vv_page10) { &update( "K",  $f_vv_html10, $f_vv_page10 ) }
if ( done_now $p_vv_page12) { &update( "LM", $f_vv_html12, $f_vv_page12 ) }
if ( done_now $p_vv_page13) { &update( "N",  $f_vv_html13, $f_vv_page13 ) }
if ( done_now $p_vv_page14) { &update( "O",  $f_vv_html14, $f_vv_page14 ) }
if ( done_now $p_vv_page17) { &update( "S",  $f_vv_html17, $f_vv_page17 ) }
if ( done_now $p_vv_page18) { &update( "T",  $f_vv_html18, $f_vv_page18 ) }
if ( done_now $p_vv_page19) { &update( "U",  $f_vv_html19, $f_vv_page19 ) }
if ( done_now $p_vv_page20) { &update( "W",  $f_vv_html20, $f_vv_page20 ) }
if ( done_now $p_vv_page21) { &update( "X",  $f_vv_html21, $f_vv_page21 ) }
if ( done_now $p_vv_page22) { &update( "Y",  $f_vv_html22, $f_vv_page22 ) }
if ( done_now $p_vv_page23) { &update( "Z",  $f_vv_html23, $f_vv_page23 ) }
if ( done_now $p_vv_page24) { &update( "AC", $f_vv_html24, $f_vv_page24 ) }
if ( done_now $p_vv_page25) { &update( "BD", $f_vv_html25, $f_vv_page25 ) }

sub update {
    my ( $lan, $myhtml, $mypage ) = @_;
    my $html = file_read $myhtml;
    $text = HTML::FormatText->new( leftmargin => 0, rightmargin => 150 )
      ->format( HTML::TreeBuilder->new()->parse($html) );
    $text =~ s/\n//g;
    (@vvList) = split( /-----+/, $text );

    #	if($text =~ /.*Vägarbeten, (.*) LÄN.*/) { $lan = $1 };
    #	print "$lan\n";
    foreach $vvLine (@vvList) {
        if ( $vvLine =~
            /.*Läge: ?(.*)Namn: ?(.*)Typ: ?(.*)Beräknas pågå: ?(.*)Restriktioner: ?(.*)Beskrivning: ?(.*)/
          )
        {
            &process( $lan, $vvLine, $1, $2, $3, $4, $5, $6 );
        }
    }
    file_write( $mypage, $text );
}

sub process {
    my ( $myLan, $myraw, $myLage, $myNamn, $myTyp, $myBer, $myRes, $myBesk ) =
      @_;
    if ( $myraw !~ /Läge:Namn:Typ:/ and $myLage !~ /^Lv/ ) {
        $dbh = DBI->connect('DBI:ODBC:vv');
        $query_select =
          "SELECT raw FROM Roadwork WHERE raw = \'$myLage $myNamn $myTyp\'";
        $sth = $dbh->prepare($query_select)
          or print "Can't prepare $query_select: $dbh->errstr\n";
        $sth->execute() or print "can't execute the query: $sth->errstr\n";

        #		while (@row=$sth->fetchrow_array) { print "==> @row\n" };
        @row = $sth->fetchrow_array;

        #    	print "==> @row\n";
        ( $BerStart, $BerStopp ) = split( /--/, $myBer );
        $myTime = $Year . "-" . $Month . "-" . $Mday . " " . $Time_Now;
        if ( $row[0] eq "" ) {
            $query_insert =
              "INSERT into Roadwork (raw,Lan,Lage,Namn,Typ,Ber,Start,Stopp,Res,Besk,Last,Add) values (\'$myLage $myNamn $myTyp\',\'$myLan\',\'$myLage\',\'$myNamn\',\'$myTyp\',\'$myBer\',\'$BerStart\',\'$BerStopp\',\'$myRes\',\'$myBesk\',\'$myTime\',\'$myTime\')";
            $sth = $dbh->prepare($query_insert)
              or print "Can't prepare $query_insert: $dbh->errstr\n";
            $sth->execute() or print "can't execute the query: $sth->errstr\n";
        }
        else {
            $query_update =
              "UPDATE Roadwork SET Last = \'$myTime\' WHERE raw = \'$myLage $myNamn $myTyp\'";
            $sth = $dbh->prepare($query_update)
              or print "Can't prepare $query_update: $dbh->errstr\n";
            $sth->execute() or print "can't execute the query: $sth->errstr\n";
        }
        $sth->finish();
        $dbh->disconnect();
    }
}
