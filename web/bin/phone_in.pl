
# read_phone_logs* is from phone_logs.pl code files
my $html_calls;
my $display_name;
my @logs = &read_phone_logs1('callerid');
my @calls = &read_phone_logs2( 100, @logs );
for my $r (@calls) {
    my ( $time, $num, $name, $line, $type ) =
      $r =~ /date=(.+) number=(.+) name=(.+) line=(.*) type=(.*)/;
    ( $time, $num, $name ) = $r =~ /(.+\d+:\d+:\d+) (\S+) (.+)/ unless $name;
    $display_name = $name;
    $display_name =~ s/_/ /g;    # remove underscores to make it print pretty
    next unless $num;

    #   next unless $line;

    $html_calls .=
      "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";

    #    $html_calls .= "<td nowrap><a href=\"phone_search.pl?search=$num\"><img src='/graphics/ico_magnify.gif' border=0 alt='Show last call from $num'></a>&nbsp;<a href=\"phone_search.pl?search=$num\"><img src='/graphics/ico_magnify.gif' border=0 alt='Show last call from $num'></a></td>";
    $html_calls .=
      "<td nowrap>$time</td><td nowrap><a href=\"phone_search.pl?search=$num\"><img src='/graphics/ico_magnify.gif' border=0 alt='Show last call from $num'></a>&nbsp;$num</td>";
    $html_calls .=
      "<td nowrap><a href=\"callerid.pl?cidnumber=$num&cidname=$name&showlist=0\"><img src='/graphics/ico_plus.gif' border=0 alt='Add $num to phone.callerid.list file'></a>&nbsp;$display_name</td><td nowrap>$line</td>";
    $html_calls .= "</tr>";
}

#my $html = "<html><body>\n<base target ='output'>\n" .
my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>\n" . &html_header('Recent Incoming Calls') . "
<table width=100% cellspacing=2><tbody><font face=COURIER size=2>
<tr id='resultrow' bgcolor='#9999CC' class='wvtheader'>
<th align='left'>Time</th>
<th align='left'>Number</th>
<th align='left'>Name</th>
<th align='left'>Line</th>
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
