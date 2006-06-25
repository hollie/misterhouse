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

# noloop=start
my $mhdl_url = "http://www.misterhouse.net/download.html";
my $mhdl_file = "$config_parms{data_dir}/web/mh_download.html";
$p_mhdl_page = new Process_Item("get_url -quiet \"$mhdl_url\" \"$mhdl_file\"");
# noloop=stop

$v_mhdl_page = new Voice_Cmd("Check Misterhouse version");
$v_mhdl_page->set_info("Check if Misterhouse version is current");

$v_version = new Voice_Cmd("What version are you", 0);
$v_version->set_info("Responds with current version information");

sub parse_version {
	my ($maj,$min) = $Version =~ /(\d)\.(\d*)/;
	my ($rev) = $Version =~ /R(\d*)/;
	return ($maj, $min, $rev);
}

sub calc_age {
#Get the time sent in. This is UTC
    my $time = shift;
    #*** This is a hack (same as earthquakes)
    #*** Surely PERL can turn a date string into a time hash!
    my ($qmnth, $qdate, $qyear) = $time =~ m!(\S+)/(\S+)/(\S+)!;

    my $diff = (time - timelocal(0,0,0,$qdate,$qmnth-1,$qyear));

    my $days_ago = int($diff/(60*60*24));
    return 'today' if !$days_ago;
    return 'yesterday' if $days_ago == 1;
    return 'the day before yesterday' if $days_ago == 2;
    return "$days_ago days ago" if $days_ago < 7;
    my $weeks = int($days_ago / 7);
    my $days = $days_ago % 7;
    return "$weeks week" . (($weeks == 1)?'':'s') . ((!$days)?'':(" and $days day" . (($days == 1)?'':'s'))) . " ago";
}

if (said $v_version) {

	my ($maj,$min,$revision) = &parse_version();
	$revision = "unknown" unless $revision;

	if (($Save{mhdl_maj} > $maj) or (($Save{mhdl_maj} == $maj) and ($Save{mhdl_min} > $min))) {
        	respond "app=control I am version $maj.$min (revision $revision) and $Save{mhdl_maj}.$Save{mhdl_min} was released " . &calc_age($Save{mhdl_date}) . '.';
	}
	else {
        	respond "app=control I am version $maj.$min (revision $revision), released " . &calc_age($Save{mhdl_date}) . '.';
	}
}

if (said $v_mhdl_page) {

    my $msg;

    if (&net_connect_check) {
	$msg = 'Checking version...';
	print_log "Retrieving download page";
	start $p_mhdl_page;
    }
    else {
	$msg = "app=control Unable to check version while disconnected from the Internet";
    }

    $v_mhdl_page->respond("app=control $msg");
}


if (done_now $p_mhdl_page) {
    my @html = file_head($mhdl_file,16);
    print_log "Download page retrieved";
    foreach(@html) {
	next unless /^<p>Version (\d+)\.(\d+) released on (.*):/i;
	$Save{mhdl_maj} = $1;
	$Save{mhdl_min} = $2;
	$Save{mhdl_date} = $3;
	last;
    }


   if (defined $Save{mhdl_maj} and defined $Save{mhdl_min}) {
	my ($maj,$min,$revision) = &parse_version();
	$revision = "unknown" unless $revision;
	if (($Save{mhdl_maj} > $maj) or (($Save{mhdl_maj} == $maj) and ($Save{mhdl_min} > $min))) {
	    $v_mhdl_page->respond("important=1 connected=0 app=control I am version $maj.$min (revision $revision) and version $Save{mhdl_maj}.$Save{mhdl_min} was released " . &calc_age($Save{mhdl_date} . '.'));
	}
	else {
		# Voice command is only code to start this process, so check its set_by
		$v_mhdl_page->respond("connected=0 app=control Version $Save{mhdl_maj}.$Save{mhdl_min} is current.");
	}
   }




}

# create trigger to download version info at 6PM (or on dial-up connect)

if ($Reload) {
    if ($Run_Members{'internet_dialup'}) {
        &trigger_set("state_now \$net_connect eq 'connected'", "run_voice_cmd 'Check Misterhouse version'", 'NoExpire', 'get MH version')
          unless &trigger_get('get MH version');
    }
    else {
        &trigger_set("time_cron '0 18 * * *' and net_connect_check", "run_voice_cmd 'Check Misterhouse version'", 'NoExpire', 'get MH version')
          unless &trigger_get('get MH version');
    }
}
