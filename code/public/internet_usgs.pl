# Category = Entertainment

# Retrieves USGS Whitewater page and sends notification
####################
## to make requests of specific site numbers
## and email if the water is up 
## Uses values from MH.ini to determine where to pull the rivers from
## Mail is sent to mh.ini: net_mail_account_1_address
## Site numbers can be determinwd from http://waterdata.usgs.gov/nwis/rt
## mh.ini: USGS_RiverMonitor = 02096960 4.7 02085070 2.7 02102500 2.0
## Where the first # is the site number, and the second is the level at which to send notification
## mh.ini: USGS_Rate=    0 = cfs ||  1 = gauge height
## To select whether you want data from rivers by cfs or Gauge height
#################### 

my $USGS_URL; 		# The URL to build the request to the USGS
my %USGS_Notify; 	# The River level to send notification
my %USGS_Level;  	# The current River Level
my %USGS_Name;   	# The River Name/Location

my @MH_Rivers = split(/ /,$config_parms{USGS_Monitor}); # The River IDs and Notification level

my $f_USGS_list = "$config_parms{data_dir}/web/USGS.txt";
my $f_USGS_html = "$config_parms{data_dir}/web/USGS.html";

# noloop=start

	# Build the URL
$USGS_URL = "http://waterdata.usgs.gov/nwis/current?multiple_site_no="; 
	#Add all of the rivers
my $i;
for ($i = 0; $i <= (@MH_Rivers/2)+1; $i+=2) {
	$USGS_URL .= @MH_Rivers[$i] . "%0D%0A"; 
	$USGS_Notify{"@MH_Rivers[$i]"} = @MH_Rivers[$i+1];
}
	#More of the general URL
$USGS_URL .= "&search_site_no_match_type=exact&index_pmcode_STATION_NM=1&index_pmcode_DATETIME=2"; 
	# Add whether CFS or Level
if ($config_parms{USGS_Rate}) { 
		$USGS_URL .= "&index_pmcode_00065=3"; 
	} else { $USGS_URL .= "&index_pmcode_00060=3"; 
	}
	# And the last of the URL
$USGS_URL .= "&sort_key=site_no&group_key=NONE&sitefile_output_format=html_table&column_name=agency_cd&column_name=site_no&column_name=station_nm&column_name=lat_va&column_name=long_va&column_name=state_cd&column_name=county_cd&column_name=alt_va&column_name=huc_cd&sort_key_2=site_no&html_table_group_key=NONE&format=rdb&rdb_compression=value&list_of_search_criteria=multiple_site_no%2Crealtime_parameter_selection"; 

# noloop=stop

$p_USGS_list = new Process_Item("get_url $USGS_URL $f_USGS_html");

#############################################

$v_USGS_list  = new Voice_Cmd('[Get,Read,Show] the USGS Site');
$v_USGS_list -> set_info("This is the USGS Water Level"); 
                                # Allow for an open access action
$v_USGS_list2 = new Voice_Cmd('{Display,What is} the USGS list');
$v_USGS_list2-> set_info("This is the USGS List"); 
$v_USGS_list2-> set_authority('anyone');
$v_USGS_list2-> tie_items($v_USGS_list, 1, 'Show');

$state = said $v_USGS_list;
#speak    app => 'USGS', text => $f_USGS_list, display => 0 if $state eq 'Read';
#respond  app => 'USGS', text => $f_USGS_list, time => 300, font => 'Times 25 bold', geometry => '+0+0', width => 72, height => 24
#  if $state eq 'Show' or $state eq 'Read';
speak    text => $f_USGS_list, display => 0 if $state eq 'Read';
respond  text => $f_USGS_list, time => 300, font => 'Times 25 bold', geometry => '+0+0', width => 72, height => 24
  if $state eq 'Show' or $state eq 'Read';

if (said $v_USGS_list eq 'Get') {
                                # Do this only if we the file has not already been updated in the last hour
    if (-s $f_USGS_html > 10 and
        time_date_stamp(3, $f_USGS_html) eq time_date_stamp(3)) {
        print_log "USGS list is current";
        start $p_USGS_list 'do_nothing';  # Fire the process with no-op, so we can still run the parsing code for debug
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving USGS list from the net ...";
                                # Use start instead of run so we can detect when it is done
            start $p_USGS_list;
        }
        else { speak "Sorry, you must be logged onto the net"; }
    }            
    &respond_wait;  # Tell web browser to wait for respond
}

if (done_now $p_USGS_list) {

    my $text = file_read $f_USGS_html;

#To clean up the CGI USGS Site
				# clean up the top explanation
     $text =~ s/#.+#//s;
				#To clean up the table headers
     $text =~ s/^.+?(USGS)/$1/s;

# Split out the values

        my @USGS_RiverList = split(/\n/,$text);
        my $USGS_River = "";
        my @USGS_RiverValues = "";
	my $USGS_Message = "";
     foreach $USGS_River (@USGS_RiverList) {
	@USGS_RiverValues = split("\t", $USGS_River);
	$USGS_Level{"@USGS_RiverValues[1]"} = @USGS_RiverValues[7];
	$USGS_Name{"@USGS_RiverValues[1]"} = @USGS_RiverValues[2];
	if ($USGS_Level{"@USGS_RiverValues[1]"} >= $USGS_Notify{"@USGS_RiverValues[1]"} ) {
		$USGS_Message .= $USGS_Name{"@USGS_RiverValues[1]"} . " is at " . $USGS_Level{"@USGS_RiverValues[1]"} . ".\n";
	}
     }
	# Send mail if the rivers are up.
    if ($USGS_Message) {
    	print_log ("Sending notification that rivers are up!");
    	&net_mail_send(subject => "Wohoo! Rivers are up",
                   text    => $USGS_Message);
    }

    file_write($f_USGS_list, $USGS_Message);

    set $v_USGS_list 'Show';
}

###########################################################

#if (time_cron ('0-59 * * * *')) {print_log("$USGS_URL"); }

# To clean up the non-dynamic primary USGS site.
                                # Delete &nbsb
#    $text =~ s/\240/ /g;
#                                # Delete text preceeding the list
#    $text =~ s/^.+flow\n\w+\/\w+\n+(.+?.)/$1/s;
#                          # Delete data past the last line: 1. xxxxx\n
#    $text =~ s/(^.+)(Data status).+/$1/s;
#				# remove all the "group" lines
#    $text =~ s/Group.*?\n//g;
#				# remove all multiple newlines
#    $text =~ s/\n+/\n/g;
#				# remove all multiple spaces
#    $text =~ s/ +/ /g;
#				# Take out that pesky 1st newline
#    $text =~ s/^\n//;




