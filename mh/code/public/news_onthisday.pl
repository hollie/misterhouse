#Category=News
#  Added Local Star news
my $f_onthisday = "$config_parms{data_dir}/web/onthisday.txt";
my $f_onthisday_html = "$config_parms{data_dir}/web/onthisday.html";

#$f_onthisday2_html2 = new File_Item($f_onthisday2_html); # Needed if we use run instead of process_item

$p_onthisday = new Process_Item("get_url http://www.nytimes.com/learning/general/onthisday/index.html $f_onthisday_html");
$v_onthisday = new  Voice_Cmd('[Get,Read,Show] onthisday');

speak($f_onthisday)   if said $v_onthisday eq 'Read';
display($f_onthisday) if said $v_onthisday eq 'Show';

if (said $v_onthisday eq 'Get') {

    # Do this only if we the file has not already been updated today and it is not empty
    if (0 and -s $f_onthisday_html > 10 and
        time_date_stamp(6, $f_onthisday_html) eq time_date_stamp(6)) {
        print_log "onthisday news is current";
        display $f_onthisday;
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving on this day in history from the net ...";

            # Use start instead of run so we can detect when it is done
            start $p_onthisday;
        }        
    }            
}

if (done_now $p_onthisday) {
    my $html = file_read $f_onthisday_html;                           
    my ( $text, $otday, $event, $detag, $count, $otd_year, $otd_date, $otd_string);
    $text = "On this day in history \n";
    for (file_read "$f_onthisday_html") {
		
	if (m!(onthisday[_|/]big)!){
      #if (m!(onthisday[_|/]big\d*\.html)!){
		$otday++;
		$event++;
		}

     if ((m!On(.+)!) and $otday > 1 ){
		$event++;
            $detag  =~ "$1.\n";
		$detag =~ s!</?\w>!!g;
		$detag =~ s/\t//g;
		$text .= $detag;
        }

	elsif (m!<B>Current Birthdays</B>!i){
		$event = 0;
		$count = 8;
   } 

	elsif (/<!-- ONTHISDAY_INDEX_DATA/i){
		$otd_date = "xxx";
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
 
 elsif ((m!<DESCRIPTION>([\w,\-\s]+)!) and $event){
            $text  .= "$1";
		$event = 0;
		$otday = 0;
        }
 
elsif ((m!^([\w\s,\-]+)\.!)and $count < 7){
		$otd_string = "$1\n"; 
		$otd_string =~ s/\s{2,}//;
		$otd_string =~ s!\t!!g;

            if ($count == 6){$otd_year = "";}
		$text  .= $otd_year . $otd_string;
		$count++;
        }

elsif ((m!<B>(\d+)</B>!i) and $count < 7){
	 $otd_year  = "In $1 ";
   }

elsif (m!<B>(1999)</B>!i){
	$text  .= "In 1999 ";
	$count = 6;
   } 

# trap today's date
#	elsif ((m!<B>([\w\s,]+)</B>!i) and ($otd_date eq "xxx")){
#		$otd_date =~ "$1 ";
#		 $text = "On this day in history for $otd_date \n";
#   } 


}
#	$text =~ s/\t//g;
    file_write($f_onthisday, $text);
    display $f_onthisday;
}


