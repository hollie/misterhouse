# Category = News

# Run this periodically from internet_logon.pl

my $f_onthisday = "$config_parms{data_dir}/web/onthisday.txt";
my $f_onthisday_html  = "$config_parms{data_dir}/web/onthisday.html";
my $f_onthisday_html2 = "$config_parms{data_dir}/web/onthisday_pruned.html";

$p_onthisday = new Process_Item("get_url http://www.nytimes.com/learning/general/onthisday/index.html $f_onthisday_html");
$v_onthisday = new  Voice_Cmd('[Get,Show] on this day');
$v_onthisday ->set_authority('anyone');

if (said $v_onthisday eq 'Get') {

    # Do this only if we the file has not already been updated today and it is not empty
    if (-s $f_onthisday_html > 10 and
        time_date_stamp(6, $f_onthisday_html) eq time_date_stamp(6)) {
        run_voice_cmd 'Show on this day';
        print_log "onthisday news is current";
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving on this day in history from the net ...";
            start $p_onthisday;
        }        
    }            
}

if (done_now $p_onthisday or said $v_onthisday eq 'Show') {
    my $html = file_read $f_onthisday_html;                           
    $html =~ s/.+(\<tr.+?Today\'s .+)/$1/is;
    my $html2 = "<html><body><table>\n" . $html;
    my $text = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($html2));
    file_write($f_onthisday_html2, $html2);
    file_write($f_onthisday, $text);
    display $text;
}


