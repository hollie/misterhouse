#Category=News

my $f_drudge_report = "$config_parms{data_dir}/web/drudge_report.txt";
my $f_drudge_report_html = "$config_parms{data_dir}/web/drudge_report.html";

$p_drudge_report = new Process_Item("get_url http://www.drudgereport.com $f_drudge_report_html");
$v_drudge_report = new  Voice_Cmd('[Get,Read,Show] drudge_report');

speak($f_drudge_report)   if said $v_drudge_report eq 'Read';
display($f_drudge_report) if said $v_drudge_report eq 'Show';

if (said $v_drudge_report eq 'Get') {
    if (&net_connect_check) {
        print_log "Drudge Report from the net ...";
        start $p_drudge_report;
    }        
}

                                # Filter the file to just the good/speakable stuff
if (done_now $p_drudge_report) {
    print_log "Druge Report retreived";
	do "$config_parms{code_dir}/news_drudge_report"; 
}

