# Category = Web

#@ Get URL for Earth Globe every hour once a month.  Used in mh/web/newclock
#@ For use with updated /newclock/index.shtml Audrey page
#@ Use EITHER this code or clock_map.pl (not both!)

## Updated to add voice item and better handling of process_item
## If map images don't exist (ie first time module is activated, download images)

my $URL =
  "http://www.fourmilab.ch/cgi-bin/uncgi/Earth?img=learth.evif&imgsize=150&dynimg=y&opt=-p&lat=&lon=&alt=&tle=&date=0&utc=&jd=";
my $MAPDIR    = "$Pgm_Root/web/newclock/maps";
my $f_get_map = "$config_parms{data_dir}/earth_jpg.data";
my $min_size = 20000;    #minimum size to test if a jpg has been downloaded
$p_get_map = new Process_Item(
    "get_url -quiet \"$URL\" $config_parms{data_dir}/earth_jpg.data");

# Update earth.jpg for each Hour, once a week

$v_get_earth_clock = new Voice_Cmd("Update clock earth display");
if ( ( time_cron '1 * * * *' ) or ( said $v_get_earth_clock) ) {

    if (   ( time_cron '* * * * 0' )
        or ( !( -e "$MAPDIR/$Hour.jpg" ) )
        or ( said $v_get_earth_clock) )
    {

        print_log "Clock_map: Starting Process item to download earth image";
        $p_get_map->set_output("$f_get_map");
        start $p_get_map;

    }
}

if ( done_now $p_get_map) {
    print_log "Clock_map: Uploading earth map for hour $Hour";

    #only copy the jpg if successful
    my $filesize = -s $f_get_map;
    if ( $filesize > $min_size ) {
        copy "$f_get_map", "$MAPDIR/$Hour.jpg";
    }
    else {
        print_log "Clock_map: Bad file size, file not copied";
    }
}
