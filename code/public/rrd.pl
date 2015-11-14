# Misc functions for dealing with RRD files within Misterhouse
#
# Author: Dave Lounsberry, dbl@dittos.yi.org
#
# I have quite a quite a few 1Wire ibutton temperature
# probes throughout the house. I used the Round Robin Database (RRD)
#    http://people.ee.ethz.ch/~oetiker/webtools/rrdtool/
# to record and graph the temperatures.
#

use lib qw( /usr/local/rrdtool-1.0.28/lib/perl ../lib/perl );

sub dump_rrd_file {
    my ( $sensor, $rrd_start, $rrd_end ) = @_;
    $rrd_start = ( time - ( 24 * 60 * 60 ) ) if !$rrd_start;
    $rrd_end = time if !$rrd_end;
    my $oval = 0;

    use RRDs;

    my $rrdfile = $config_parms{rrd_dir} . "/" . $sensor . ".rrd";
    my ( $start, $step, $names, $array ) = RRDs::fetch $rrdfile, "AVERAGE",
      -s $rrd_start, -e $rrd_end;
    my $ERROR = RRDs::error;
    my @readings;

    print_log "RRD FETCH ERROR: $ERROR\n" if $ERROR;
    LINE: foreach my $line (@$array) {
        $start += $step;
        foreach my $val (@$line) {
            next LINE if !$val;

            #			if (($oval - 5) > $val) {
            #				print_log "Bad value -> $val <> $oval\n";
            #				$val = $oval if $oval - 5 > $val;
            #			}
            my ( $Second, $Minute, $Hour, $Mday, $Month, $year_unix, $Wday ) =
              localtime($start);
            push( @readings,
                sprintf "%2.2d/%2.2d/%2.2d %2.2d:%2.2d:%2.2d %3.2f\n",
                $Month + 1, $Mday, $year_unix + 1900,
                $Hour, $Minute, $Second, $val );
            $oval = $val;
        }
    }
    return join '', reverse @readings;
}

sub fetch_rrd_hilo {
    my ( $sensor, $rrd_start, $rrd_end ) = @_;
    $rrd_start = ( time - ( 24 * 60 * 60 ) ) if !$rrd_start;
    $rrd_end = time if !$rrd_end;

    use RRDs;

    my $rrdfile = $config_parms{rrd_dir} . "/" . $sensor . ".rrd";
    my ( $start, $step, $names, $array ) = RRDs::fetch $rrdfile, "AVERAGE",
      -s $rrd_start, -e $rrd_end;
    my $ERROR = RRDs::error;
    print_log "RRD FETCH ERROR: $ERROR\n" if $ERROR;

    my $oval    = 0;
    my $ostart  = 0;
    my $min     = "1000";
    my $max     = "-200";
    my $mintime = 0;
    my $maxtime = 0;
    LINE: foreach my $line (@$array) {
        $start += $step;
        foreach my $val (@$line) {
            next LINE if !$val;
            if ( $max < $val ) {
                $max     = $val;
                $maxtime = $start;
            }
            if ( $min > $val ) {
                $min     = $val;
                $mintime = $start;
            }
            $oval   = $val;
            $ostart = $start;
        }
    }
    return ( $ostart, $oval, $mintime, $min, $maxtime, $max );
}

sub update_rrd {
    my ( $sensor, $temp ) = @_;
    use RRDs;

    my $rrdfile = $config_parms{rrd_dir} . "/" . $sensor . ".rrd";

    # print "Storing $temp in $rrdfile for $sensor\n";

    RRDs::update $rrdfile, time . ":$temp";
    my $ERROR = RRDs::error;
    print_log "RRD UPDATE ERROR: $ERROR\n" if $ERROR;
    return;
}

sub rrd_file_list {
    my ($rrd_dir) = @_;
    opendir( DIR, "$rrd_dir" ) or die "Could not open directory $rrd_dir: $!\n";
    my @members = readdir(DIR);
    my @rrds;
    foreach (@members) {
        if (/.rrd$/) {
            s/.rrd$//g;
            push( @rrds, $_ );
        }
    }
    close(DIR);
    return join ',', @rrds;
}

sub plot_rrd {
    my ($sensor) = @_;

    use Time::Local;
    use Date::Parse;
    use RRDp;

    my $targetdir = "/home/www/html/automation/plots";
    my $curtime   = time;
    my $lastday   = ( $curtime - ( 24 * 60 * 60 ) );
    my $plot_def =
      "DEF:sensor=" . $config_parms{rrd_dir} . "/" . $sensor . ".rrd:temp:LAST";
    my $probes = "
		LINE1:sensor#ff000c:'$sensor'
		GPRINT:sensor:LAST:'Cur\\:%3.2lf%s'
        	GPRINT:sensor:MIN:'Min\\:%3.2lf%s'
        	GPRINT:sensor:MAX:'Max\\:%3.2lf%s'
		GPRINT:sensor:AVERAGE:'Ave\\:%3.2lf%s'
		COMMENT:'\\c'
	";

    my $comment = "
		COMMENT:'\\s'
		COMMENT:'\\s'
		COMMENT:'Graph created on: " . localtime( time() ) . "\\c'
	";

    RRDp::start "/usr/local/bin/rrdtool";

    RRDp::cmd "graph $targetdir/$sensor.png -s $lastday -e $curtime ",
      "--title \"$sensor Temperature Readings for Past 24 Hours\" ",
      "--vertical-label 'Temperature'",
      "-a PNG",
      "-h 400 -w 850",
      "-l 50 -u 80",
      "-y 5:1",
      "-x HOUR:1:HOUR:1:HOUR:2:60:%H:%M",
      "$plot_def",
      "$probes",
      "$comment";
    my $answer = RRDp::read;
    print "$$answer";
    RRDp::end;
    return "<img src=http://dittos.yi.org/automation/plots/$sensor.png>";
}
