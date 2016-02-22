# Category = News

#@ This module adds functionality to obtain Associated Press
#@ breaking news, then read or display it.

use XML::RSS;

#noloop=start
my $rss            = new XML::RSS;
my $f_ap_news      = "$config_parms{data_dir}/web/ap_breaking_news.txt";
my $f_ap_news_html = "$config_parms{data_dir}/web/ap_breaking_news_pruned.html";
my $f_ap_news_rss  = "$config_parms{data_dir}/web/ap_breaking_news.rss";
$p_ap_news = new Process_Item(
    qq!get_url "http://hosted.ap.org/lineups/TOPHEADS.rss?SITE=NHPOR&SECTION=HOME" $f_ap_news_rss!
);
$v_ap_news = new Voice_Cmd('What is in the News');
$v_ap_news->set_info('Responds with headline stories from the AP');
$v_get_ap_news = new Voice_Cmd('[Get,Check,Mail,SMS] AP breaking news');
tie_event $v_get_ap_news "get_ap_news(\$state)";

#noloop=stop

sub get_ap_news {
    my $response;
    my $state = shift;

    if (&net_connect_check) {
        $response = "Retrieving news from the AP...";
        start $p_ap_news;
    }
    else {
        $response =
          "Could not retrieve news from the AP (network connection is down.)";
    }

    $v_get_ap_news->respond("app=news $response");

}

if ( done_now $p_ap_news) {
    $rss->parsefile($f_ap_news_rss);
    my $html = "";
    my $text = "";

    $html = "<ul>";

    # print the title and link of each RSS item

    my $description;
    my $i = 0;

    foreach my $item ( @{ $rss->{'items'} } ) {

        #Get what we need for the straight text version
        $text .= "Headline: $item->{'title'}\n";
        $text .= "$item->{'description'}\n\n";

        $description = $item->{'description'};

        #$description = &html_encode($description);
        # assumes that field is properly encoded to begin with
        $description = &quote_attribute($description);

        #Get and format the html version
        if ( !$i and $Save{news_ap_headline} ne $item->{'title'} ) {
            $Save{news_ap_headline} = $item->{'title'};
            $i++;
        }

        $html .=
            qq|<li><a href="|
          . &recompose_uri( $item->{'link'} )
          . qq|" title=$description>|
          . $item->{'title'}
          . qq|</a></li>|;

    }

    $html .= "</ul>";

    #write the files.
    file_write( $f_ap_news,      $text );
    file_write( $f_ap_news_html, $html );

    if ( $v_get_ap_news->{state} eq 'Mail' ) {
        my $to = $config_parms{news_sendto} || "";
        $v_get_ap_news->respond( "connected=0 image=mail Sending AP News to "
              . ( ($to) ? $to : $config_parms{net_mail_send_account} )
              . '.' );
        &net_mail_send(
            subject => "Breaking news from the AP",
            to      => $to,
            file    => $f_ap_news_html,
            mime    => 'html_inline'
        );
    }
    elsif ( $v_get_ap_news->{state} eq 'SMS' ) {

        # *** Use PCS if present!  Move to sub in main mh
        # *** Check return value
        my $to = $config_parms{cell_phone};
        if ($to) {
            $v_get_ap_news->respond(
                "connected=0 image=mail Sending AP News to cell phone.");
            &net_mail_send(
                subject => "Breaking news from the AP",
                to      => $to,
                file    => $f_ap_news,
                mime    => 'html_inline'
            );
        }
        else {
            $v_get_ap_news->respond(
                "connected=0 app=error Mobile phone email address not found!");
        }
    }
    elsif ( $v_get_ap_news->{state} ne 'Check' )
    {    # get responds with story count
        $v_get_ap_news->respond(
            "connected=0 app=news AP news retrieved $i stories.");
    }
    else {    # check responds with stories
        $v_get_ap_news->respond("connected=0 app=news $text");
    }

}

if ( $state = said $v_ap_news) {
    $v_ap_news->respond("app=news $f_ap_news");
}

# create trigger to download breaking news at seven and thirty-seven after each hour

if ($Reload) {
    if ( $Run_Members{'internet_dialup'} ) {
        &trigger_set(
            "state_now \$net_connect eq 'connected'",
            "run_voice_cmd 'Get AP Breaking News'",
            'NoExpire',
            'get AP news'
        ) unless &trigger_get('get AP news');

    }
    else {
        &trigger_set(
            "time_cron '7,37 * * * *' and net_connect_check",
            "run_voice_cmd 'Get AP Breaking News'",
            'NoExpire', 'get AP news'
        ) unless &trigger_get('get AP news');
    }
}

