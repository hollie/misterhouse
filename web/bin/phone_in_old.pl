
# read_phone_logs* is from phone_logs.pl code files
my $html_calls;
my @logs = &read_phone_logs1('callerid');
my @calls = &read_phone_logs2( 100, @logs );
for my $r (@calls) {
    my ( $time, $num, $name ) = $r =~ /(.+\d+:\d+:\d+) (\S+) (.+)/;
    next unless $num;
    $html_calls .=
      "<tr vAlign=center bgColor='#cccccc'><td nowrap>$time</td><td nowrap>$num</td><td nowrap>$name</td></tr>";
}

#my $html_calls;
#open(DATA, "$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log");
#for my $r (reverse <DATA>) {
#    my ($time, $num, $name, $line) = $r =~ /(.+\d+:\d+:\d+) (.+) name=(.+) data=.+ line=(\S+)/;
#    $html_calls .= "<tr vAlign=center bgColor='#cccccc'><td nowrap>$time</td><td nowrap>$num</td>";
#    $html_calls .= "<td nowrap>$name</td><td nowrap>$line</td></tr>";
#}
#close DATA;

#my $html = "<html><body>\n<base target ='output'>\n" .
my $html = "<html><body>\n" . &html_header('Recent Incoming Calls') . "
<table width=100% cellspacing=2><tbody><font face=COURIER size=2>
<tr bgcolor='#999999'>
<th align='middle'>Time</th>
<th align='middle'>Number</th>
<th align='middle'>Name</th>
$html_calls
</font></tbody></table>
</body>
</html>
";

return &html_page( '', $html );
