#Category=News
#  Added Motovational Quote of the day
my $f_mquote_otd = "$config_parms{data_dir}/web/mquote_otd.txt";
my $f_mquote_otd_html = "$config_parms{data_dir}/web/mquote_otd.html";

#$f_mquote_otd2_html2 = new File_Item($f_mquote_otd2_html); # Needed if we use run instead of process_item

$p_mquote_otd = new Process_Item("get_url http://www.starlingtech.com/quotes/mqotd.html $f_mquote_otd_html");
$v_mquote_otd = new  Voice_Cmd('[Get,Read,Show] mquote_otd');
$v_mquote_otd ->set_authority('anyone');

speak($f_mquote_otd)   if said $v_mquote_otd eq 'Read';
display($f_mquote_otd) if said $v_mquote_otd eq 'Show';

if (said $v_mquote_otd eq 'Get') {

    # Do this only if we the file has not already been updated today and it is not empty
    if (0 and -s $f_mquote_otd_html > 10 and
        time_date_stamp(6, $f_mquote_otd_html) eq time_date_stamp(6)) {
        print_log "mquote_otd news is current";
        display $f_mquote_otd;
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving on this day in history from the net ...";

            # Use start instead of run so we can detect when it is done
            start $p_mquote_otd;
        }        
    }            
}

if (done_now $p_mquote_otd) {
    my $html = file_read $f_mquote_otd_html;                           
    my ( $text);
    #Improve pronunciation by forcing a long "o"
    $text = "Moatovational Quote of the day: \n";
    for (file_read "$f_mquote_otd_html") {

   		if(m!<DT><B>([\w\.\s,'":]+)</B>!){
			$text  .= "$1\n";	
        	}
		if(/<DD>(.+)/){
			$text  .= "$1\n";	
        	}
      }    

    file_write($f_mquote_otd, $text);
    display $f_mquote_otd;
}

