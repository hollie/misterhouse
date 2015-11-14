# Category = Internet

#@ This script collects and graphs DSL traffic data from a Westell Versalink 327W modem/router used by Verizon.
#@ Once this script is activated, <a href='sub;?graph_versalink_rrd()'>
#@ this graph </a> will show your DSL traffic.

# 02/22/06 created by David Norwood

use HTML::TableExtract;
use RRDs;

my $versalink_host = '192.168.1.1';
my $versalink_url;
my $f_versalink = "$config_parms{data_dir}/web/versalink.html";
$v_get_versalink  = new Voice_Cmd 'Get Versalink info';
$v_read_versalink = new Voice_Cmd 'What is the internet bit rate?';
$p_get_versalink  = new Process_Item;
my ( $versalink_download, $versalink_in, $versalink_upload, $versalink_out );
my $RRD   = "$config_parms{data_dir}/versalink.rrd";
my $debug = 0;

if ($Reload) {
    $versalink_host = $config_parms{'versalink_host'}
      if $config_parms{'versalink_host'};
    $versalink_url = "http://$versalink_host/atmstat.htm";
    set $p_get_versalink "get_url -quiet $versalink_url $f_versalink";
    &create_versalink_rrd($Time) unless -e $RRD;
    $Included_HTML{'Internet'} .=
      qq(<h3>Versalink Throughput<p><img src='sub;?graph_versalink_rrd()'><p>\n\n\n);
}

if (new_minute) {
    unlink $f_versalink;
    $p_get_versalink->start;
}

if ( said $v_read_versalink) {
    my $state = $v_read_versalink->{state};
    my $text;
    $v_read_versalink->respond("app=network $text");
}

my $kbx = ( 8 / 60 ) / 1024;
if ( done_now $p_get_versalink) {
    my $html = file_read $f_versalink;
    return unless $html;
    my $te = new HTML::TableExtract( depth => 3, count => 1 );
    $te->parse($html);

    my @cell = $te->rows;
    $versalink_download =
      $cell[7][0] > $versalink_in ? $cell[7][0] - $versalink_in : 0;
    $versalink_upload =
      $cell[13][0] > $versalink_out ? $cell[13][0] - $versalink_out : 0;
    $versalink_in  = $cell[7][0];
    $versalink_out = $cell[13][0];

    &update_versalink_rrd( $Time, $versalink_in, $versalink_out );
    print_log "Internet download bit rate: "
      . round( $versalink_download * $kbx, 2 )
      . " Kbps  upload: "
      . round( $versalink_upload * $kbx, 2 ) . " Kbps"
      if $debug;
}

=begin 
   my $te = new HTML::TableExtract();
   $te->parse($html);

   foreach my $ts ($te->table_states) {
	print "Table (", join(',', $ts->coords), "):\n";
	my $i = 0;
	foreach my $row ($ts->rows) {
		my $j = 0;
		foreach my $col (@$row) {
      		print "$i,$j $col\n";
			$j++;
		}
		$i++;
	}
   }
=cut

# Create database

sub create_versalink_rrd {
    my $err;
    print "Create RRD database : $RRD\n";

    RRDs::create $RRD,
      '-b', $_[0], '-s', 60,
      "DS:inbytes:COUNTER:300:U:U",
      "DS:outbytes:COUNTER:300:U:U",
      'RRA:AVERAGE:0.5:1:801',    # details for 6 hours (agregate 1 minute)

      'RRA:MIN:0.5:2:801',        # 1 day (agregate 2 minutes)
      'RRA:AVERAGE:0.5:2:801', 'RRA:MAX:0.5:2:801',;
}

# Update database

sub update_versalink_rrd {
    my $err;
    my ( $time, @data ) = @_;

    print "DATA INSERT : time = $time data = @data\n" if $debug;
    RRDs::update $RRD, "$time:" . join ':', @data;    # add current data

    return if $err = RRDs::error and $err =~ /min.*one second step/;
    warn "$err\n" if $err;
}

# Create graph PNG image

sub graph_versalink_rrd {
    my $seconds = shift;
    $seconds = 3600 unless $seconds;
    my $ago = $Time - $seconds;
    my ( $graph, $x, $y ) = RRDs::graph(
        "$config_parms{data_dir}/versalink.png",
        "--start=$ago",
        "--end=$Time",
        "--vertical-label=kb/s",
        "DEF:inbytes=$RRD:inbytes:AVERAGE",
        "CDEF:realinbytes=inbytes,8,*,1000,/",
        "LINE1:realinbytes#FF0000:In traffic",
        "DEF:outbytes=$RRD:outbytes:AVERAGE",
        "CDEF:realoutbytes=outbytes,8,*,1000,/",
        "LINE2:realoutbytes#00FF00:Out traffic",
    );
    return file_read "$config_parms{data_dir}/versalink.png";
}
