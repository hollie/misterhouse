#####################################################################
#  NOM		: weather_graph.pl
#  DESCRIPTION 	:
#
# $Date$
# $Revision
#

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
# 26/01/04   1.0   Dominique Benoliel
# - Creation script
# 12/03/04   1.1   Dominique Benoliel
# - Change html tag, alias to rrd use time() function
#####################################################################

#==============================================================================
# Principal script
#==============================================================================
my $typegraph = shift;
$typegraph = "tempout" unless $typegraph;
return &select_weather_graph;

#==============================================================================
# Create html page for the weather graphs
#==============================================================================
sub select_weather_graph {

    my $html = &html_header('Weather Station Graphs');

    $config_parms{weather_graph_format} = "PNG"
      unless $config_parms{weather_graph_format};
    tr/a-z/A-Z/ for $config_parms{weather_graph_format};

    my $rrd_format = $config_parms{weather_graph_format};

    # audrey can't handle PNGs, so force them to be GIFs
    # mh/bin/weather_rrd_update_graphs handles making the GIF copies if
    # weather_convert_png_to_gif is defined in mh.ini

    $rrd_format = 'gif' if $Http{'User-Agent'} eq 'Audrey';
    tr/A-Z/a-z/ for $rrd_format;

    # lookup code for periods (code, description)
    my $tabperiod = [
        [ '6hour',  '6 hours' ],
        [ '12hour', '12 hours' ],
        [ '1day',   '1 day' ],
        [ '2day',   '2 days' ],
        [ '1week',  '1 week' ],
        [ '2week',  '2 week' ],
        [ '1month', '1 month' ],
        [ '2month', '2 months' ],
        [ '6month', '6 months' ],
        [ '1year',  '1 year' ],
        [ '2year',  '2 years' ],
        [ '5year',  '5 years' ]
    ];

    $html = qq|
<HTML><BODY>
<BASE TARGET ="weather output">
$html
|;

    my $rate = 60 * $config_parms{weather_graph_frequency};
    $html .= "<meta http-equiv='refresh' content='" . $rate . ";url='>"
      if $rate;

    my $j = 1;
    unless ( $config_parms{weather_graph_skip} =~ /$typegraph/ ) {
        $html .= qq|
 <CENTER>
 <TABLE WIDTH="591" BORDER="0" CELLPADDING="0" CELLSPACING="0">
 <TR>|;

        # Build anchors for graphs
        my $i = 1;

        for my $periodgraph (@$tabperiod) {
            unless ( $config_parms{weather_graph_period_skip} =~
                /$periodgraph->[0]/ )
            {
                $html .=
                  "\n<TD><IMG src=\"/graphics/graph.gif\" align=\"absbottom\"><B><A href=\"#"
                  . $periodgraph->[0];
                $html .= "\"> " . $periodgraph->[1] . "</A></B></TD>";

                # Max 6 periods by row
                if ( int( $i / 6 ) == $i / 6 ) {
                    $html .= "</TR><TR>";
                }
                $i++;
            }
        }
        $html .= "</TR></TABLE>";

        $html .= "\n</TABLE>\n";

        # Build link for graphs
        for my $periodgraph (@$tabperiod) {
            unless ( $config_parms{weather_graph_period_skip} =~
                /$periodgraph->[0]/ )
            {
                $j = 0;
                $html .= "\n" . qq|<A NAME="$periodgraph->[0]"></A><BR>|;
                $html .= "\n<IMG SRC = ";

                #    $html .= "\'/rrd/weather_" . $typegraph . "_" . $periodgraph->[0] . ".png?" . int(100000*rand) . "'>\n";
                $html .=
                    "\'/rrd/weather_"
                  . $typegraph . "_"
                  . $periodgraph->[0]
                  . ".$rrd_format?"
                  . time()
                  . '\' border=0><BR><BR>';
            }
        }
    }

    # Message if no graph
    if ( $j or ( $config_parms{weather_graph_skip} =~ /$typegraph/ ) ) {
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

    return &html_page( '', $html );
}

