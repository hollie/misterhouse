#Category=News
#  Added Yahoo full coverage

my $f_all_news_html = "$config_parms{data_dir}/web/all_news.html";
my $f_Top_news = "$config_parms{data_dir}/web/Top_news.txt";
my $f_US_news = "$config_parms{data_dir}/web/US_news.txt";
my $f_World_news = "$config_parms{data_dir}/web/World_news.txt";
my $f_Entertainment_news = "$config_parms{data_dir}/web/Entertainment_news.txt";
my $f_Business_news = "$config_parms{data_dir}/web/Business_news.txt";
my $f_Tech_news = "$config_parms{data_dir}/web/Tech_news.txt";
my $f_Science_news = "$config_parms{data_dir}/web/Science_news.txt";
my $f_Health_news = "$config_parms{data_dir}/web/Health_news.txt";
my $f_Sports_news = "$config_parms{data_dir}/web/Sports_news.txt";

$p_all_news = new Process_Item("get_url http://dailynews.yahoo.com/fc $f_all_news_html");

$v_all_news = new  Voice_Cmd('Get the current news');
$v_all_news ->set_authority('anyone');
$v_news     = new  Voice_Cmd('Tell me the [Top,U S,World,Entertainment,Business,Technology,Science,Health,Sports] news');
$v_news     ->set_authority('anyone');

speak($f_Top_news) if said $v_news eq 'Top';
speak($f_US_news) if said $v_news eq 'U S';
speak($f_World_news) if said $v_news eq 'World';
speak($f_Entertainment_news) if said $v_news eq 'Entertainment';
speak($f_Business_news) if said $v_news eq 'Business';
speak($f_Tech_news) if said $v_news eq 'Technology';
speak($f_Science_news) if said $v_news eq 'Science';
speak($f_Health_news) if said $v_news eq 'Health';
speak($f_Sports_news) if said $v_news eq 'Sports';



#display($f_US_news) if said $v_US_news eq 'Show';

if ( said $v_all_news ) {

    # Do this only if we the file has not already been updated today and it is not empty
    if (0 and -s $f_all_news_html > 10 and
        time_date_stamp(6, $f_all_news_html) eq time_date_stamp(6)) {
        print_log "The news is current";
	  speak("The news is current");
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving the current news from the net ...";
            speak("Retrieving the current news, please hold on.");

            # Use start instead of run so we can detect when it is done
            start $p_all_news;
        }        
    }            
}

if (done_now $p_all_news) {
    speak("I have finished retrieving the news.");
    my $html = file_read $f_all_news_html;                           
    my $text;

    $text = "Here is what is making news right now: \n";
    for (file_read "$f_all_news_html") {
   	if(m!href="http://dailynews.yahoo.com/fc/World/\w+\/">([\w\.\s,'":]+)</a>!) {
			$text  .= "$1.\n";
		}
   	if(m!href="http://dailynews.yahoo.com/fc/US/\w+\/">([\w\.\s,'":]+)</a>!) {
			$text  .= "$1.\n";
		}
   	if(m!href="http://dailynews.yahoo.com/fc/Entertainment/\w+\/">([\w\.\s,'":]+)</a>!) {
			$text  .= "$1.\n";
		}
   	if(m!href="http://dailynews.yahoo.com/fc/Business/\w+\/">([\w\.\s,'":]+)</a>!) {
			$text  .= "$1.\n";
		}
   	if(m!href="http://dailynews.yahoo.com/fc/Tech/\w+\/">([\w\.\s,'":]+)</a>!) {
			$text  .= "$1.\n";
		}
   	if(m!href="http://dailynews.yahoo.com/fc/Science/\w+\/">([\w\.\s,'":]+)</a>!) {
			$text  .= "$1.\n";
		}
   	if(m!href="http://dailynews.yahoo.com/fc/Health/\w+\/">([\w\.\s,'":]+)</a>!) {
			$text  .= "$1.\n";
		}
   	if(m!href="http://dailynews.yahoo.com/fc/Sports/\w+\/">([\w\.\s,'":]+)</a>!) {
			$text  .= "$1.\n";
        	}		
      }    
    file_write($f_Top_news, $text);
    speak($f_Top_news);

    $text = "US breaking news items: \n";
    for (file_read "$f_all_news_html") {
   	if(m!href="http://dailynews.yahoo.com/fc/US/\w+\/"><small>([\w\.\s,'":]+)</small>!) {
			$text  .= "$1.\n";
        	}		
      }    
    file_write($f_US_news, $text);

    $text = "World breaking news items: \n";
    for (file_read "$f_all_news_html") {
   	if(m!href="http://dailynews.yahoo.com/fc/World/\w+\/"><small>([\w\.\s,'":]+)</small>!) {
			$text  .= "$1.\n";	
        	}		
      }    
    file_write($f_World_news, $text);

    $text = "Entertainment breaking news items: \n";
    for (file_read "$f_all_news_html") {
   	if(m!href="http://dailynews.yahoo.com/fc/Entertainment/\w+\/"><small>([\w\.\s,'":]+)</small>!) {
			$text  .= "$1.\n";	
        	}		
      }    
    file_write($f_Entertainment_news, $text);

    $text = "Business breaking news items: \n";
    for (file_read "$f_all_news_html") {
   	if(m!href="http://dailynews.yahoo.com/fc/Business/\w+\/"><small>([\w\.\s,'":]+)</small>!) {
			$text  .= "$1.\n";	
        	}		
      }    
    file_write($f_Business_news, $text);

    $text = "Tech breaking news items: \n";
    for (file_read "$f_all_news_html") {
   	if(m!href="http://dailynews.yahoo.com/fc/Tech/\w+\/"><small>([\w\.\s,'":]+)</small>!) {
			$text  .= "$1.\n";	
        	}		
      }    
    file_write($f_Tech_news, $text);

    $text = "Science breaking news items: \n";
    for (file_read "$f_all_news_html") {
   	if(m!href="http://dailynews.yahoo.com/fc/Science/\w+\/"><small>([\w\.\s,'":]+)</small>!) {
			$text  .= "$1.\n";	
        	}		
      }    
    file_write($f_Science_news, $text);

    $text = "Health breaking news items: \n";
    for (file_read "$f_all_news_html") {
   	if(m!href="http://dailynews.yahoo.com/fc/Health/\w+\/"><small>([\w\.\s,'":]+)</small>!) {
			$text  .= "$1.\n";	
        	}		
      }    
    file_write($f_Health_news, $text);

    $text = "Sports breaking news items: \n";
    for (file_read "$f_all_news_html") {
   	if(m!href="http://dailynews.yahoo.com/fc/Sports/\w+\/"><small>([\w\.\s,'":]+)</small>!) {
			$text  .= "$1.\n";	
        	}		
      }    
    file_write($f_Sports_news, $text);

}

