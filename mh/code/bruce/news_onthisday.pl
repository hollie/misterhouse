#Category=News
#  Added Local Star news
my $f_thisday = "$config_parms{data_dir}/web/thisday.txt";
my $f_thisday_html = "$config_parms{data_dir}/web/thisday.html";

#$f_thisday2_html2 = new File_Item($f_thisday2_html); # Needed if we use run instead of process_item

$p_thisday = new Process_Item("get_url http://www.nytimes.com/learning/general/onthisday/index.html $f_thisday_html");
$v_thisday = new  Voice_Cmd('[Get,Read,Show] on this day history');

speak($f_thisday)   if said $v_thisday eq 'Read';
display($f_thisday) if said $v_thisday eq 'Show';

if (said $v_thisday eq 'Get') {

    # Do this only if we the file has not already been updated today and it is not empty
    if (0 and -s $f_thisday_html > 10 and
        time_date_stamp(6, $f_thisday_html) eq time_date_stamp(6)) {
        print_log "thisday news is current";
        display $f_thisday;
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving on this day in history from the net ...";

            # Use start instead of run so we can detect when it is done
            start $p_thisday;
        }        
    }            
}

if (done_now $p_thisday) {
    my $html = file_read $f_thisday_html;                           
    my ( $text, $otday, $event);

    $text = "On this day in history: \n";
    for (file_read "$f_thisday_html") {
		
      if (/(onthisday_big\.html)/){
		$otday++;
		$event++;
		}
     if ((m!On(.+)!) and $otday > 1 ){
		$event++;
            $text  .= "$1.\n";
        }
     elsif ((m!<BIRTH_YEAR><B>(.+)</B></BIRTH_YEAR>!) and $event){
            $text  .= "In $1 ";
        }
  elsif ((m!<FIRST_NAME>(.+)</FIRST_NAME>!) and $event ){
            $text  .= "$1 ";
        }
 elsif ((m!<LAST_NAME>(.+)</LAST_NAME>!) and $event ){
            $text  .= "$1 was born.";
        }
 elsif ((m!<DESCRIPTION>(.+)</DESCRIPTION>!) and $event){
            $text  .= " $1";
		$event = 0;
		$otday = 0;
        }
    } 
	$text =~ s!([a-zA-Z,'\.\-\s]+)<\w\/?>([a-zA-Z,'\.\-\s]+)!$1 $2!;
    file_write($f_thisday, $text);
    display $f_thisday;
}


