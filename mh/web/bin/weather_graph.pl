#####################################################################
#  NOM		: weather_graph.pl
#  DESCRIPTION 	: 
=begin comment
#@ Generate html page for weather graphs
#@
#@ mh parameter : weather_graph_period_skip
=cut
#--------------------------------------------------------------------
# 				HISTORY
#--------------------------------------------------------------------
#   DATE   REVISION    AUTHOR	        DESCRIPTION
#--------------------------------------------------------------------
# 26/01/04   1.0   Dominique Benoliel	Creation script
#####################################################################

#==============================================================================
# Principal script
#==============================================================================
my $typegraph = shift;
return &select_weather_graph;

#==============================================================================
# Create html page for the weather graphs
#==============================================================================
sub select_weather_graph {

my $html = &html_header('Weather Station Graphs');

# lookup code for periods (code, description)
my $tabperiod =  [['6hour','6 hours'],['12hour','12 hours'],['1day','1 day'],['2day','2 days'],
	['1week','1 week'],['2week','2 week'],['1month','1 month'],['2month','2 months'],
	['6month','6 months'],['1year','1 year'],['2year','2 years'],['5year','5 years']];

$html = qq|
<HTML><BODY>
<BASE TARGET ="weather output">
$html
|;

my $j=1;
unless ($config_parms{weather_graph_skip} =~ /$typegraph/) {
 $html .= qq|
 <CENTER>
 <TABLE WIDTH="591" BORDER="0" CELLPADDING="0" CELLSPACING="0">
 <TR>|;

 # Build anchors for graphs
 my $i = 1;

 for my $periodgraph (@$tabperiod) {
  unless ($config_parms{weather_graph_period_skip} =~ /$periodgraph->[0]/) {
    $html .= "\n<TD><IMG src=\"/graphics/graph.gif\" align=\"absbottom\"><B><A href=\"#" . $periodgraph->[0];
    $html .= "\"> " . $periodgraph->[1] . "</A></B></TD>";
 
    # Max 6 periods by row
    if (int($i/6) == $i/6) {
	  $html .= "</TR><TR>";
      }
    $i++;
    }
  }
 $html .= "</TR></TABLE>";

 $html .= "\n</TABLE>\n";

 # Build link for graphs
 for my $periodgraph (@$tabperiod) {
  unless ($config_parms{weather_graph_period_skip} =~ /$periodgraph->[0]/) {
     $j=0;
     $html .= "\n" . qq|<A NAME="$periodgraph->[0]"></A><BR>|;
     $html .= "\n<IMG SRC = ";
     $html .= "\'/weather_graph/weather_" . $typegraph . "_" . $periodgraph->[0] . ".png?" . int(100000*rand);
    }
  }
}
# Message if no graph
if ($j or ($config_parms{weather_graph_skip} =~ /$typegraph/)) {
$html .= qq|<center><BR>
<BR><BR><BR><BR><BR><BR><BR>
<TABLE bgcolor="#000000">
  <TBODY>
    <TR>
      <TD align="center" bgcolor="#9999CC" width="300"><FONT size="+4"><B> NO DATA </B></FONT></TD>
    </TR>
  </TBODY>
</TABLE>
<BR><BR><BR><BR><BR><br>
</center>|
  }

$html .= "\n</CENTER></BODY></HTML>\n";

return &html_page('', $html);
}

