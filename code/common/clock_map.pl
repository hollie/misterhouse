# Category = Web

#@ Get URL for Earth Globe every hour once a month.  Used in mh/web/newclock

my $URL =
  "http://www.fourmilab.ch/cgi-bin/uncgi/Earth?img=learth.evif&imgsize=150&dynimg=y&opt=-p&lat=&lon=&alt=&tle=&date=0&utc=&jd=";
my $MAPDIR = "$Pgm_Root/web/clock/maps";

# Update earth.jpg for each Hour, once a month
if ( time_cron '1 * 1 * *' ) {
    my $GET_MAP = new Process_Item "get_url -quiet $URL tmp.jpg";
    $GET_MAP->start;
    print_log "--CLOCK-UPDATE-- Retrieving clock data for Hour $Hour";
    copy "tmp.jpg", "$MAPDIR/$Hour.jpg";
}

if ( time_cron '0 * * * *' ) {

    #print_log " CLOCK: Copy $MAPDIR/$Hour to $MAPDIR/earth.jpg";
    copy "$MAPDIR/$Hour.jpg", "$MAPDIR/earth.jpg";
}
