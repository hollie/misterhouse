#Category=News
#  Added AP Breaking News
my $f_ap_breaking_news = "$config_parms{data_dir}/web/ap_breaking_news.txt";
my $f_ap_breaking_news_html = "$config_parms{data_dir}/web/ap_breaking_news.html";

#$f_ap_breaking_news2_html2 = new File_Item($f_ap_breaking_news2_html); # Needed if we use run instead of process_item

$p_ap_breaking_news = new Process_Item("get_url http://ap.tbo.com/ap/breaking/index.htm $f_ap_breaking_news_html");
$v_ap_breaking_news = new  Voice_Cmd('[Get,Read,Show] ap_breaking_news');

speak($f_ap_breaking_news)   if said $v_ap_breaking_news eq 'Read';
display($f_ap_breaking_news) if said $v_ap_breaking_news eq 'Show';

if (said $v_ap_breaking_news eq 'Get') {

    # Do this only if we the file has not already been updated today and it is not empty
    if (0 and -s $f_ap_breaking_news_html > 10 and
        time_date_stamp(6, $f_ap_breaking_news_html) eq time_date_stamp(6)) {
        print_log "ap_breaking_news news is current";
        display $f_ap_breaking_news;
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving on this day in history from the net ...";

            # Use start instead of run so we can detect when it is done
            start $p_ap_breaking_news;
        }        
    }            
}

if (done_now $p_ap_breaking_news) {
    my $html = file_read $f_ap_breaking_news_html;                           
    my ( $text, $count);

    $text = "Five Associated Press Breaking news items: \n";
    for (file_read "$f_ap_breaking_news_html") {

   	if((m!href="/ap/breaking/\w+\.html">([\w\.\s,'":]+)</a>!) and $count <5){
			$count++;
			$text  .= "$count $1\n";	
        	}		
      }    

    file_write($f_ap_breaking_news, $text);
    display $f_ap_breaking_news;
}

