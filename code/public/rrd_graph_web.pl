# Authority: anyone
# graph.pl
#
# $Date$
# $Revision$
#
# This code generates the iButton temperature graph
#
# put rrd_graph_web.pl, rrd_graph_web.css, and rrd_create_graph.pl in
# /Misterhouse/mh/web/bin
# run http://your-misterhouse:8080/bin/rrd_graph_web.pl
#

use RRDs;

my @rrd = ( "ib_temp2", "ib_kelder" );    # List of iButtons
my @time = ( "1_Day", "1_Week", "1_Month", "3_Month", "1_Year" )
  ;                                       # Graphs when you select 1 iButton
my $rrd_name     = shift @ARGV;
my $img_dir      = "/Misterhouse/mh/web/graphics";
my $color        = $config_parms{html_color_header};
my $refresh_rate = $config_parms{html_status_refresh};
$refresh_rate = 60 unless $config_parms{html_status_refresh};
my $dt     = $config_parms{weather_uom_temp};
my $descr  = "Temperature Sensor";
my $height = "120";
my $width  = "500";
my $debug  = "0";
my ( $html, $error, $rrd, $t );

header();
if ($rrd_name) {
    $rrd = "$config_parms{rrd_dir}/$rrd_name.rrd";
    while ( $t = shift @time ) {
        graph();
    }
}
else {
    $t = "1_Week";
    while ( $rrd_name = shift @rrd ) {
        $rrd = "$config_parms{rrd_dir}/$rrd_name.rrd";
        graph();
    }
}
footer();
return &html_page( '', $html, ' ' );

sub header {
    $html = qq[<html><head><title>MrHouse</title>\n];
    $html .= qq[<meta http-equiv='Refresh' content='$refresh_rate'>\n];
    $html .= qq[<meta http-equiv='Pragma' content='no-cache'>\n];
    $html .= qq[<meta http-equiv='Cache-Control' content='no-cache'>\n];
    $html .=
      qq[<link type='text/css' href='rrd_graph_web.css' rel='stylesheet'>\n];
    $html .= qq[</head>\n];
    $html .= qq[<body><base target ='output'>\n];
    $html .= qq[<table width=100% bgcolor='$color'>\n];
    $html .= qq[<td><center><font size=3 color='black'>\n];
    $html .= qq[<b>House Temperature Statistics</b>\n];
    $html .= qq[</font></center></td>\n];
    $html .= qq[</table>\n];
    $html .= qq[<br>\n];
    $html .= qq[<center>\n];
    $html .= qq[<table border='0'>\n];
}

sub graph {
    my $last  = RRDs::last($rrd);
    my $ERROR = RRDs::error;
    print_log "RRDs::last ERROR: $ERROR\n" if $ERROR;

    my $lasttime = localtime($last);
    my $timenow  = localtime( time() );
    $timenow =~
      s/:/\\:/g;    # RRD doesn't like colons, so put leading backslashes in

    my ( $start, $step, $names, $array ) = RRDs::fetch $rrd, "AVERAGE", "-s",
      "$last-$t", "-e", $last;
    my $ERROR = RRDs::error;
    print_log "RRDs::fetch ERROR: $ERROR\n" if $ERROR;

    my ( $cur, $cur1, $sum );
    my ( @temp, @oTemp );
    foreach my $line (@$array) {
        if ( defined( $$line[0] ) ) {
            push @temp, $$line[0];
            $sum += $cur = $$line[0];
        }
    }
    @oTemp = sort { $b <=> $a } @temp;
    $cur1 = sprintf( "%.1f", $cur );
    my $min = sprintf( "%.1f", $oTemp[ scalar(@temp) - 1 ] );
    my $avg = sprintf( "%.1f", $sum / scalar(@temp) );
    my $max = sprintf( "%.1f", $oTemp[0] );

    # RRDs::graph leaks memory, so use a system call to create the graph.
    system(
        "perl $config_parms{html_dir}/bin/rrd_create_graph.pl $rrd_name $rrd $img_dir $t $descr $height $width $dt"
    );

    $html .= qq[  <tr>\n];
    $html .=
      qq[    <td  rowspan="3"><a href="/bin/graph.pl?$rrd_name" target="_self" >];
    $html .=
      qq[    <img src="/graphics/$rrd_name-temp-$t.png" width="595" height="192" border=0></td>\n];
    $html .= qq[    <td  colspan="3" class="cur">$cur1&deg;$dt1</td>\n];
    $html .= qq[  </tr>\n];
    $html .= qq[  <tr> \n];
    $html .= qq[    <td class="min">$min&deg;$dt</td>\n];
    $html .= qq[    <td class="avg">$avg&deg;$dt</td>\n];
    $html .= qq[    <td class="max">$max&deg;$dt</td>\n];
    $html .= qq[  </tr>\n];
    $html .= qq[  <tr> \n];
    $html .= qq[    <td class="min">min</td>\n];
    $html .= qq[    <td class="avg">avg</td>\n];
    $html .= qq[    <td class="max">max</td>\n];
    $html .= qq[  </tr>\n];
    $html .= qq[  <tr>\n];
    $html .= qq[    <td height="20">];
    $html .= qq[$rrd<br>] if $debug;
    $html .= qq[$cur <- last temperature<br>] if $debug;
    $html .= qq[$lasttime <- time last database update<br>] if $debug;
    $html .= qq[$timenow <- time last page update\n] if $debug;
    $html .= qq[</td>\n];
    $html .= qq[  </tr>\n];
}

sub footer {
    $html .= qq[</table></form></body></html>\n];
}
