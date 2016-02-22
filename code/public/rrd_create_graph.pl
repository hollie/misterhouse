# rrd_create_graph.pl
#
# $Date$
# $Revision$
#
# This code generates a graph from the given parameters.  It was cut out of
# rrd_graph_web.pl because of a memory leak in RRDs::graph.  This way this
# code gets called by a system call and the OS handles garbage collection.
#
# Passed in parameters:
# $rrd_name - path to the RRD file
# $rrd - RRD name to be displayed on the graph
# $img_dir - where the image file will be put
# $t - time coverd by the graph (1_Day, 1_Hour, etc)
# $descr - type of data being graphed (ie - Sensor)
# $height, $width - height and width of graph
# $dt - temperature units (used as an axis label)

use RRDs;

my ( $rrd_name, $rrd, $img_dir, $t, $descr, $height, $width, $dt ) = @ARGV;

my $timenow = localtime( time() );
$timenow =~ s/:/\\:/g;   #RRD doesn't like colons, so put leading backslashes in

RRDs::graph "$img_dir/$rrd_name-temp-$t.png",
  "--start",          "-$t",
  "--title",          "$rrd_name $descr $t",
  "--alt-y-grid",     "--alt-autoscale",
  "--height",         "$height",
  "--width",          "$width",
  "--imgformat",      "PNG",
  "--vertical-label", "degrees $dt",
  "DEF:ib=$rrd:temp:AVERAGE",
  "COMMENT:$timenow",
  "LINE1:ib#ff0000";

my $ERROR = RRDs::error;
print "RRDs::fetch ERROR: $ERROR\n" if $ERROR;

