# Category=MisterHouse

#@ This code will retrieve and parse the MH download page to
#@ determine if a newer version is available.

=begin comment

 mh_release.pl
 Created by Axel Brown

 This code will retrieve and parse the MH download page to
 determine if a newer version is available.

 Revision History

 Version 0.1		January 04, 2005
 And so it begins...

=cut

my $mhdl_url = "http://www.misterhouse.net/download.html";
my $mhdl_file = "$config_parms{data_dir}/web/mh_download.html";

$p_mhdl_page = new Process_Item("get_url -quiet \"$mhdl_url\" \"$mhdl_file\"");
$v_mhdl_page = new Voice_Cmd("check misterhouse version",0);

# Do this at midnight
if (said $v_mhdl_page or
    ($New_Minute and time_cron('0 0 * * *'))) {

    if (&net_connect_check) {
	print_log "Retrieving MH download page";
	start $p_mhdl_page;
    } else {
	respond "Sorry, you must be online to get version info";
    }
}

if (done_now $p_mhdl_page) {
    my @html = file_head($mhdl_file,16);
    foreach(@html) {
	next unless /^<p>Version (\d+)\.(\d+) released on (.*):/i;
	$Save{mhdl_maj} = $1;
	$Save{mhdl_min} = $2;
	$Save{mhdl_date} = $3;
	last;
    }
}

if ($New_Minute and
    (time_cron '4 16,20 * * * ')) {
    if (defined $Save{mhdl_maj} and defined $Save{mhdl_min}) {
# mh 2.102 R419
#       my ($maj,$min) = split(/\./,$Version);
        my ($maj,$min) = $Version =~ /(\d*)\.(\d*)/;
	if (($Save{mhdl_maj} > $maj) or (($Save{mhdl_maj} == $maj) and ($Save{mhdl_min} > $min))) {
	    speak "A newer version of Mister House was made available for download on " . $Save{mhdl_date}
	}
    }
}
