# Category = News

#@ This module adds functionality to obtain Associated Press
#@ breaking news, then read or display it.


use XML::RSS;

my $text = "";
my $rss = new XML::RSS;
my $f_ap_news = "$config_parms{data_dir}/web/ap_breaking_news.txt";
my $f_ap_news_html = "$config_parms{data_dir}/web/ap_breaking_news_pruned.html";
my $f_ap_news_rss = "$config_parms{data_dir}/web/ap_breaking_news.rss";

$p_ap_news = new Process_Item("get_url http://hosted.ap.org/lineups/TOPHEADS.rss?SITE=NHPOR&SECTION=HOME $f_ap_news_rss");
$v_ap_news = new Voice_Cmd('[Read,Show] AP Breaking News');
$v_get_ap_news = new  Voice_Cmd('Get AP Breaking News');

if (said $v_get_ap_news) {
    if (&net_connect_check) {
      print_log "Retrieving news from the AP...";
      # Use start instead of run so we can detect when it is done
      start $p_ap_news;
    }
}

if (done_now $p_ap_news) {
  print_log "AP news retrieved";
  $rss->parsefile($f_ap_news_rss);
  my $html="";

    $html = "<ul>";

  # print the title and link of each RSS item

  my $description;

  foreach my $item (@{$rss->{'items'}}) {
    #Get what we need for the straight text version
    $text .= "Headline: $item->{'title'}\n";
    $text .= "$item->{'description'}\n\n";

    $description = $item->{'description'};
    $description =~ s/"/&quot;/;
    #Get and format the html version
    $html .= "<li><a href=\"$item->{'link'}\" title=\"$description\">$item->{'title'}</a></li>";

  }

    $html .= "</ul>";

  #write the files.
  file_write($f_ap_news, $text);
  file_write($f_ap_news_html, $html);
}


if ($state = said $v_ap_news) {
        if ($state eq "Read") {
                respond "target=speak " . $f_ap_news;
        }
        else {
                respond $f_ap_news;
        }
}

# create trigger to download breaking news at five after each hour

if ($Reload and $Run_Members{'trigger_code'}) {
    if ($Run_Members{'internet_dialup'}) {
        eval qq(
            &trigger_set("state_now \$net_connect eq 'connected'", "run_voice_cmd 'Get AP Breaking News'", 'NoExpire', 'get AP news')
              unless &trigger_get('get AP news');
        );
    }
    else {
        eval qq(
            &trigger_set("time_cron '5 * * * *' and net_connect_check", "run_voice_cmd 'Get AP Breaking News'", 'NoExpire', 'get AP news')
              unless &trigger_get('get AP news');
        );
    }
}
