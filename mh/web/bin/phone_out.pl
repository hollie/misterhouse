
# read_phone_logs* is from phone_logs.pl code files
my $html_calls;
my @logs   = &read_phone_logs1('phone');
my @calls  = &read_phone_logs2(100, @logs);

for my $r (@calls) {
    my ($time, $num, $name) = $r =~ /(.+\d+:\d+:\d+) (\S+) (.+)/;
    $name = '' unless $name;
    next unless $num;
    $html_calls .= "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'><td nowrap>$time</td><td nowrap>$num</td><td nowrap>$name</td></tr>";
}


#my $html = "<html><body>\n<base target ='output'>\n" .
my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>\n" .
  &html_header('Recent Outgoing Calls') . "

<table width=100% cellspacing=2><tbody><font face=COURIER size=2>
 <tr id='resultrow' bgcolor='#9999CC' class='wvtheader'>
<th align='left'>Time</th>
<th align='left'>Number</th>
<th align='left'>Name</th>
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

return &html_page('', $html . $htmlfooter);
