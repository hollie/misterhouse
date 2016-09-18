# Category = Weather

#@ Monitors specific USGS water levels and emails notification when the level goes up so you know when to kayak.

# Retrieves USGS Whitewater page and sends notification
#
# Rick Steeves
# misterhouse@corwyn.net
# Last Updated:
# 20131224 - USGS adjusted the URL due to a security vulnerability

####################
## to make requests of specific site numbers and email if the water is up
## Uses values from MH.ini to determine where to pull the rivers from
## Mail is sent to mh.ini: net_mail_account_1_address
## Site numbers can be determined from http://waterdata.usgs.gov/nwis/rt
## mh.ini: USGS_RiverMonitor = 02096960 4.7 02085070 2.7 02102500 2.0
## Where the first # is the site number, and the second is the level at which to send notification
## mh.ini: USGS_Rate=    0 = cfs ||  1 = gauge height
## To select whether you want data from rivers by cfs or Gauge height
## mh.ini: USGS_Friends = bob@bob.com,george@george.com
## comma-delimited list of other people to send mail when the water is up
## mh.ini: USGS_Temp = minimum temperature your friends are willing to go kayaking
## mh.ini: weather_use_internet = 1
# Note that this uses the outside temp. If you don't have a weather station set up, you need to be using
# weather_use_internet=1 in mh.private.ini, have internet_weather enabled, and have all of that working
# correctly.
####################

my $USGS_URL;       # The URL to build the request to the USGS
my %USGS_Notify;    # The River level to send notification
my %USGS_Level;     # The current River Level
my %USGS_Name;      # The River Name/Location

my @MH_Rivers = split( / /, $config_parms{USGS_Monitor} )
  ;                 # The River IDs and Notification level

my $f_USGS_list = "$config_parms{data_dir}/web/USGS.txt";
my $f_USGS_html = "$config_parms{data_dir}/web/USGS.html";

# noloop=start

# Build the URL
$USGS_URL = "http://waterdata.usgs.gov/nwis/current?multiple_site_no=";

#Add all of the rivers
for ( my $i = 0; $i <= @MH_Rivers; $i += 2 ) {
    $USGS_URL .= @MH_Rivers[$i] . "%2C";
    $USGS_Notify{"@MH_Rivers[$i]"} = @MH_Rivers[ $i + 1 ];
}

#More of the general URL
$USGS_URL .=
  "&search_site_no_match_type=exact&index_pmcode_STATION_NM=1&index_pmcode_DATETIME=2";

# Add whether CFS or Level
if   ( $config_parms{USGS_Rate} ) { $USGS_URL .= "&index_pmcode_00065=3"; }
else                              { $USGS_URL .= "&index_pmcode_00060=3"; }

# And the last of the URL
$USGS_URL .=
  "&sort_key=site_no&group_key=NONE&sitefile_output_format=html_table&column_name=agency_cd&column_name=site_no&column_name=station_nm&column_name=lat_va&column_name=long_va&column_name=state_cd&column_name=county_cd&column_name=alt_va&column_name=huc_cd&sort_key_2=site_no&html_table_group_key=NONE&format=rdb&rdb_compression=value&list_of_search_criteria=multiple_site_no%2Crealtime_parameter_selection";

# noloop=stop

$p_USGS_list = new Process_Item("get_url $USGS_URL $f_USGS_html");

#############################################

$v_USGS_list = new Voice_Cmd('[Get,Read,Show] water levels');
$v_USGS_list->set_info('This is the USGS Water Level for selected rivers.');

$state = said $v_USGS_list;

#Check to see if there's anything in the file before speaking
#speak    (text => $f_USGS_list, display => 0) if ($state eq 'Read' && file_size $f_USGS_list);
if ( $state eq 'Read' ) {
    if ( file_size $f_USGS_list) { speak text => "app=usgs $f_USGS_list"; }
    else { speak text => 'app=usgs No water anywhere!'; }
}
elsif ( $state eq 'Show' ) {
    if ( file_size $f_USGS_list) {
        respond
          text     => $f_USGS_list,
          time     => 240,
          font     => 'Times 25 bold',
          geometry => '+0+0',
          width    => 36,
          height   => 12;
    }
    else {
        respond
          text     => 'No water anywhere!',
          time     => 240,
          font     => 'Times 25 bold',
          geometry => '+0+0',
          width    => 36,
          height   => 12;
    }
}
elsif ( $state eq 'Get' ) {

    # Do this only if the file has not already been updated in the last hour
    if ( -s $f_USGS_html > 10
        and time_date_stamp( 3, $f_USGS_html ) eq time_date_stamp(3) )
    {
        print_log "USGS list is current";

        # fixed 100219 looks like it spoke, then set things to read, and then read it again.
        #speak text => "app=usgs $f_USGS_list" if file_size $f_USGS_list;
        start $p_USGS_list 'do_nothing'
          ; # Fire the process with no-op, so we can still run the parsing code for debug
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving USGS list from the net ...";

            # Use start instead of run so we can detect when it is done
            start $p_USGS_list;
        }
        else { speak "app=usgs Sorry, you must be logged onto the net"; }
    }
    &respond_wait;    # Tell web browser to wait for respond
}

if ( done_now $p_USGS_list) {
    my $text = file_read $f_USGS_html;

    #To clean up the CGI USGS Site
    # clean up the top explanation
    $text =~ s/#.+#//s;
    print "Text1 = $text\n";

    #To clean up the table headers
    $text =~ s/^.+?(USGS)/$1/s;

    # Split out the values
    my @USGS_RiverList   = split( /\n/, $text );
    my $USGS_River       = "";
    my @USGS_RiverValues = ();
    my $USGS_Message     = "";
    foreach $USGS_River (@USGS_RiverList) {
        @USGS_RiverValues = split( "\t", $USGS_River );
        $USGS_Level{"@USGS_RiverValues[1]"} = @USGS_RiverValues[7];
        $USGS_Name{"@USGS_RiverValues[1]"}  = @USGS_RiverValues[2];
        print "Result: "
          . $USGS_Level{"@USGS_RiverValues[1]"}
          . $USGS_Name{"@USGS_RiverValues[1]"} . "\n";
        if (
            (
                $USGS_Level{"@USGS_RiverValues[1]"} >=
                $USGS_Notify{"@USGS_RiverValues[1]"}
            )
            && $USGS_Level{"@USGS_RiverValues[1]"} ne ""
          )
        {
            $USGS_Message .=
                $USGS_Name{"@USGS_RiverValues[1]"}
              . " is at "
              . $USGS_Level{"@USGS_RiverValues[1]"} . ".\n";
        }
    }

    # Send mail if the rivers are up.
    if ($USGS_Message) {
        print_log("Sending notification that rivers are up!");

        # Notify friends that they need to go if it's warm enough!
        if (   ( $Weather{TempOutdoor} >= $config_parms{USGS_Temp} )
            && ( $config_parms{USGS_Friends} ) )
        {
            print_log("Notifying friends who need to know!");
            &net_mail_send(
                subject => "Woohoo! Rivers are up",
                to      => $config_parms{USGS_Friends},
                text    => $USGS_Message
            );
        }
        else {    # Email me anyway even if it's too cold
            $USGS_Message .=
              "Current temp is " . $Weather{TempOutdoor} . " degrees.\n";
            &net_mail_send(
                subject => "Woohoo! Rivers are up",
                text    => $USGS_Message
            );
        }

        file_write( $f_USGS_list, $USGS_Message );
        set $v_USGS_list 'Read';
    }
}

###########################################################
# Release Notes:
# 11/14/04 v. 1.0 release
# 1.01
# 1.02 added ability to notify others.
# 1.03 updated frequency
# 1.04 cleaned up the file some
# 1.05 fixed so when there's nothing to report it doesn't try to talk.
# 1.06 fixed for correct outside weather.
# 1.07 Fixed logic error in how multiple notifications work
# 1.08 120611 Fixed from changes on the USGS site
