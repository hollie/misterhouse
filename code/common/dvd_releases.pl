# Category = Entertainment

#@ This script displays information about new DVD releases from <a href=http://www.videoeta.com/dvd.html>videoeta.com</a>

my $f_get_new_dvds = "$config_parms{data_dir}/web/new_dvds.html";
my $f_top_dvds = "$config_parms{data_dir}/web/top_dvds.html";
my $f_this_weeks_dvds = "$config_parms{data_dir}/web/this_weeks_dvds.html";
my @dvd_sections = ('Top DVDs', 'This Week\'s New DVDs', 'Last Week\'s New DVDs', 'Next Week\'s New DVDs');
$v_get_new_dvds = new Voice_Cmd 'Get DVD Info';
$v_get_new_dvds ->set_info('Get DVD information from the Internet');
$v_show_new_dvds = new Voice_Cmd 'Show [' . (join ',', @dvd_sections) . ']';
$v_show_new_dvds ->set_info('Display DVD information');
$v_read_new_dvds = new Voice_Cmd 'Read [' . (join ',', @dvd_sections) . ']';
$v_read_new_dvds ->set_info('Read DVD information');

$p_get_new_dvds = new Process_Item "get_url http://www.videoeta.com/dvd.html $f_get_new_dvds";

if (my $state = said $v_show_new_dvds) {
	respond "$state\n\n$Save{$state}\n";
}

if (my $state = said $v_read_new_dvds) {
	respond "target=speak $state\n\n$Save{$state}\n";
}

if (my $state = said $v_get_new_dvds) {
    unlink $f_get_new_dvds;
    $p_get_new_dvds -> start;
    $p_get_new_dvds -> {DVDsection} = $state;
}

if (done_now $p_get_new_dvds) {
    for (@dvd_sections) {
        $Save{$_} = '';
    }
    my $section;
    my $this_week_html = '<ol>';
    my $top_dvds_html = '<ol>';
    for my $html (file_read $f_get_new_dvds, '') {
        if ($html =~ /(Top DVDs)/ or
            $html =~ /(This Week's New DVDs)/ or
            $html =~ /(Last Week's New DVDs)/ or
            $html =~ /(Next Week's New DVDs)/) {
            $section = $1;
        }
        if ($section and $html =~ m|href="(.+)">(.+)</a><br>|) {
		if ($section eq "This Week's New DVDs") {
			$this_week_html .= "<li><a href=\"http://www.videoeta.com$1\">$2</a></li>";
		}
		elsif ($section eq "Top DVDs") {
			$top_dvds_html .= "<li><a href=\"http://www.videoeta.com$1\">$2</a></li>";
		}
		else {
			print $section;
		}
		$Save{$section} .= "$2\n";
	}
    }
    $this_week_html .= '</ol>';
    $top_dvds_html .= '</ol>';

    file_write ($f_this_weeks_dvds,$this_week_html);
    file_write ($f_top_dvds,$top_dvds_html);
    print_log "DVD data retrieved";
}


#Get the list once per week (should be in Internet_logon?)

run_voice_cmd "Get DVD Info", undef, 'time', 0, undef if time_now '4 pm' and $Day eq 'Mon' and &net_connect_check;

# Display the list once per week.  Respond to email, im, and display (perhaps should be in user code?)
run_voice_cmd "Show This Week's New DVDs", undef, 'time', 0, "email,im,display subject='New DVDs'" if time_now '5 pm' and $Day eq 'Mon' and &net_connect_check;
