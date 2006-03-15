#Category=News

#@ Gets Motivational Quote of the day

my $f_mquote_otd = "$config_parms{data_dir}/web/mquote_otd.txt";
my $f_mquote_otd_html = "$config_parms{data_dir}/web/mquote_otd.html";
my $f_mquote_otd_html_pruned = "$config_parms{data_dir}/web/mquote_otd_pruned.html";

$p_mquote_otd = new Process_Item("get_url http://tqpage.com/mqotd.php3 $f_mquote_otd_html");
$v_mquote_otd = new  Voice_Cmd('[Get,Read,Show] Motivational Quote of the day');
$v_mquote_otd ->set_authority('anyone');

if (my $state = said $v_mquote_otd) {
	if ($state eq 'Read') {
		respond('target=speak ' . $f_mquote_otd);
	}
	elsif ($state eq 'Show') {
		display($f_mquote_otd);
	}
}

if (said $v_mquote_otd eq 'Get' and &net_connect_check) {
    print_log "Retrieving motivational quotes from the Internet...";
    start $p_mquote_otd;
}

if (done_now $p_mquote_otd) {
    my $html;
    $html = file_read $f_mquote_otd_html;
    my $text = "Motivational Quotes of the day: \n\n";
    my $html_pruned = '<ol>';

    for (file_read "$f_mquote_otd_html") {


        while (m!/quote/([^"]*?)">([^<]*?)</a>!ig) {
            unless ($2 =~ /<img/gi) {
               $text .= "$2\n\n";
	       $html_pruned .= "<li><a href=\"http://www.quotationspage.com/quote/$1\">$2</a></li>";
            }
        }
    }
    $html_pruned .= '</ol>';
    file_write($f_mquote_otd, $text);
    file_write($f_mquote_otd_html_pruned, $html_pruned);
    print_log 'Motivational quotes retrieved.';
}
