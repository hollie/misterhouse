# Category = Entertainment

#@ This script displays information about new DVD releases from <a href=http://www.videoeta.com/dvd.html>videoeta.com</a>

my $f_get_new_dvds = "$config_parms{data_dir}/web/new_dvds.html";
my @dvd_sections = ('Top DVDs', 'This Week\'s New DVDs', 'Last Week\'s New DVDs', 'Next Week\'s New DVDs');
$v_get_new_dvds = new Voice_Cmd 'Get [' . (join ',', @dvd_sections) . ']';

$p_get_new_dvds = new Process_Item
    "get_url http://www.videoeta.com/dvd.html $f_get_new_dvds";

if (my $state = said $v_get_new_dvds) {
    unlink $f_get_new_dvds;
    $p_get_new_dvds -> start;
    $p_get_new_dvds -> {DVDsection} = $state; 
    &respond_wait;  # Tell web browser to wait for respond
}

if (done_now $p_get_new_dvds) {
    for (@dvd_sections) {
        $Save{$_} = '';
    }
    my $section;
    for my $html (file_read $f_get_new_dvds, '') {
        if ($html =~ /(Top DVDs)/ or
            $html =~ /(This Week's New DVDs)/ or
            $html =~ /(Last Week's New DVDs)/ or
            $html =~ /(Next Week's New DVDs)/) {
            $section = $1;
        }
        $Save{$section} .= "$1\n" if $section and $html =~ m|">(.+)</a><br>|;
    }
    $section = $p_get_new_dvds->{DVDsection};
    print_log "dvd data retreived";
    respond "$section\n\n$Save{$section}\n";
}

                                # Get the list once a week.  Respond to email, im, and display
run_voice_cmd "Get This Week's New DVDs", undef, 'time', 0, "email,im,display subject='New DVDs'"
  if time_now '5 pm' and $Day eq 'Mon' and &net_connect_check;

