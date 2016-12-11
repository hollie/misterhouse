
# read_phone_logs* is from phone_logs.pl code files
my $html_calls;
my @logs       = &read_phone_logs1('phone');
my @calls      = &read_phone_logs2( 300, @logs );
my $pots_time  = 0;
my $voip_time  = 0;
my $other_time = 0;

for my $r (@calls) {
    my ( $time, $num, $name, $line, $type, $dur, $ext, $color, $coloroff );
    $coloroff = "</font>";

    ( $time, $num, $name, $line, $type ) = $r =~
      /date=(.+\d+:\d+:\d+) number=(\S+) +name=(.*?) line=(\S*) type=(\S*)/;
    ( $dur, $ext ) = $r =~ / dur=(\S*) ext=(\S*)/;

    $name = '' unless $name;
    next unless $num;

    #print_log "phoneOUT $r";
    $name =~ s/_/ /g;
    if ( $type eq 'VOIP' ) {
        $color     = "<FONT Color='#008800'>";
        $voip_time = time_add " $voip_time + $dur ";
    }
    if ( $type eq 'POTS' ) {
        $color     = "<FONT Color='#0000cc'>";
        $pots_time = time_add " $pots_time + $dur ";
    }
    if ( $name eq 'NA' ) {
        $color      = "<FONT Color='#ff0000'>";
        $other_time = time_add " $other_time + $dur ";
    }

    #    $color = "<FONT Color='#000000'>" if ( $name ne 'NA' ) ;

    $html_calls .=
      "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>
    <td nowrap>$color$time$coloroff</td>
    <td nowrap>$color$num$coloroff</td>
    <td nowrap>$color$name$coloroff</td>
    <td nowrap>$color$ext$coloroff</td>
    <td nowrap>$color$dur$coloroff</td>
    <td nowrap>$color$line$coloroff</td>
    <td nowrap>$color$type$coloroff</td></tr>";

}

#my $html = "<html><body>\n<base target ='output'>\n" .
my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>\n" . &html_header('Recent Outgoing Calls') . "
<FONT Color='#008800'>VOIP Time $voip_time</font>  <FONT Color='#0000cc'>POTS Time $pots_time</font> <FONT Color='#ff0000'>Other $other_time</font>
<table width=100% cellspacing=2><tbody><font face=COURIER size=2>
 <tr id='resultrow' bgcolor='#9999CC' class='wvtheader'>
<th align='left'>Time</th>
<th align='left'>Number</th>
<th align='left'>Name</th>
<th align='left'>Ext</th>
<th align='left'>Duration</th>
<th align='left'>Line</th>
<th align='left'>Type</th>
$html_calls
</font></tbody></table>
</body>
";

my $htmlfooter .= qq[
<script language="javascript">
<!--
try{
  if (resultrow.length>1) {
    for (x=1;x<resultrow.length;x++) {
      if (x%2==0) {resultrow[x].style.backgroundColor='#DDDDDD';}
    }
  }
}
catch(er){}
// -->
</script>
</html>
];

return &html_page( '', $html . $htmlfooter );
