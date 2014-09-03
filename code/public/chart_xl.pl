# Category = Other

=begin comment

This script will create a .html page for displaying .csv data in an Excel
chart on a web page, using Mr. House. (It can be adapted for use without
Mr. House.)

The first column is assumed to contain times, in the form h:mm.  The number of
data columns may vary, and need not be defined.

The script can be adapted to display other types of data from a .csv file.

The script will not work unless Excel is installed, and has not been tested on
browsers other than IE6.

The .html page triggers an ActiveX warning when used within Mr. House, but is
believed to be harmless.

Example of source data:
1:24,5.94,17.31,18.63
1:27,5.94,17.25,18.56
1:30,6.00,17.13,18.50

The file containing the source data is expected to be named in the form
tempsyymmdd.csv, eg temps020427.csv

=cut

$v_chart_xl = new Voice_Cmd('Make temperature chart');
$v_chart_xl->set_info('Make an Excel chart of temperature data.');

if ( said $v_chart_xl) {

    my $today = substr( $Year, 2 ) . sprintf( "%02d%02d", $Month, $Mday );

    #  List of variables follows here:
    my $chart_file = "$config_parms{html_dir}/chart_xl.html";
    my $chart_source_file =
      "$Pgm_Path/$config_parms{data_dir}/logs/temps$today.csv";
    my $chart_caption = "18 CLONCURRY STREET TEMPERATURE CHART";
    my $chart_source =
      "Source: </b>I-button temperature data (recorded by Mr. House)";
    my $chart_notes = qq[Note:<br>
   10&deg;C = 50&deg;F<br>
   15&deg;C = 59&deg;F<br>
   20&deg;C = 68&deg;F<br>
   25&deg;C = 77&deg;F<br>];
    my @chart_headers = ( 'Out', 'In', 'Up' );

    print_log('Creating temperature chart script');
    my ( $chart_headers, $chart_collections, $chart_items, $count, $col );
    $chart_source_file =~ s|\/|\\|g;
    $chart_headers = "ac.Cells(1, 1).Value = " . qq["Time"] . "\n";
    foreach my $item (@chart_headers) {
        $count = "0" if $count == 0;
        $col = uc( chr( $count + 66 ) );
        $chart_headers .=
          "ac.Cells(1, " . ( $count + 2 ) . ").Value = " . qq["$item"] . "\n";
        $chart_items .=
            "  ac.Cells(i, "
          . ( $count + 2 )
          . ").Value = Data("
          . ( $count + 1 ) . ")\n";
        $chart_collections .=
          qq[cs0.SeriesCollection($count).SetData c.chDimSeriesNames, 0, "${col}1"\n];
        $chart_collections .=
          qq[cs0.SeriesCollection($count).SetData c.chDimCategories, 0, "A2:A" + Num\n];
        $chart_collections .=
          qq[cs0.SeriesCollection($count).SetData c.chDimValues, 0, "${col}2:$col" + Num\n];
        $count++;
    }

    my $chart_script = qq[
<HTML>
<HEAD>
<!-- META HTTP-EQUIV="REFRESH" CONTENT="600" -->
<TITLE>$chart_caption</TITLE>
</HEAD>
<object id=ChartSpace1 classid=CLSID:0002E500-0000-0000-C000-000000000046 style="width:100%;height:300"></object>
<object id=Spreadsheet1 classid=CLSID:0002E510-0000-0000-C000-000000000046 style="width:40%;height:10000"></object>
<br><small><b>$chart_source</small><p>
$chart_notes

<script language=vbs>
Sub Window_OnLoad()
set ac = Spreadsheet1.ActiveSheet
ac.Cells.Clear
$chart_headers	
i = 2
Rem for h = 0 to Hour(Now)
for h = 0 to 24
for m = 0 to 57 step 3
    ac.Cells(i, 1).Value = "'"+trim(cstr(h))+":"+right(+"00"+trim(cstr(m)),2)
    i = i + 1
next
next
Rem ac.Range("a:a").NumberFormat = "hh:mm"
ac.Range("b:d").NumberFormat = "Fixed"


Const ForReading = 1, ForWriting = 2, ForAppending = 8
Const TristateUseDefault = -2, TristateTrue = -1, TristateFalse = 0
FilePath = "$chart_source_file"
Set fs = CreateObject("Scripting.FileSystemObject")
Set fsfp = fs.GetFile(FilePath)
Set inp = fsfp.OpenAsTextStream(ForReading, TristateFalse)

i = 1
Do While inp.AtEndOfStream <> True
  ThisLine = inp.ReadLine
  data = split(ThisLine, ",")
  
  Rem Skip times when no data is available
  while ac.Cells(i, 1).Value <> Data(0) and i < 502
    i = i + 1
  wend
  if ac.cells(i,1) = "" then ac.cells(i,1) = Data(0)

  \n$chart_items
loop
inp.close

LastNum = i
LastNum = 502
Num = trim(cstr(LastNum))

ChartSpace1.Clear
ChartSpace1.Charts.Add
Set c = ChartSpace1.Constants
ChartSpace1.DataSource = Spreadsheet1
set cs0 = ChartSpace1.Charts(0)
cs0.SeriesCollection.Add
cs0.SeriesCollection.Add
cs0.SeriesCollection.Add

$chart_collections

cs0.HasLegend = True
cs0.Axes(c.chAxisPositionLeft).NumberFormat = "0%"
cs0.Axes(c.chAxisPositionBottom).MajorTickMarks = c.chTickMarkOutside
Rem cs0.Axes(c.chAxisPositionBottom).MajorUnit = 10
Rem cs0.Axes(c.chAxisPositionBottom).TickLabelSpacing = cint(LastNum/12+.55)
Rem cs0.Axes(c.chAxisPositionBottom).TickMarkSpacing = cint(LastNum/48 +.55)
cs0.Axes(c.chAxisPositionBottom).TickLabelSpacing = 40
cs0.Axes(c.chAxisPositionBottom).TickMarkSpacing = 10
cs0.HasTitle = True
cs0.Title.Caption = "$chart_caption"
Rem cs0.Type = c.chChartTypeLineMarkers
cs0.Type = c.chChartTypeLine
ac.Range("1:1").HAlignment = c.ssHAlignRight

End Sub
</script>

</HTML>
];

    file_write( $chart_file, $chart_script );
    print "Chart script completed\n";
    browser $chart_file;

}

