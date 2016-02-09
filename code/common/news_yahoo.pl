#Category=News

#@ This module adds functionality to obtain various categories of
#@ news from yahoo.com, then read or display it.

#my $f_all_news_html = "$config_parms{data_dir}/web/all_news.html"; # *** Makes more sense
my $f_all_news_html =
  "$Pgm_Root/web/ia5/news/news.html";    # *** Why put this in IA5?
my $f_Top_news = "$config_parms{data_dir}/web/Top_news.txt";

my %news_files;
$news_files{"US"}    = "$config_parms{data_dir}/web/US_news.txt";
$news_files{"World"} = "$config_parms{data_dir}/web/World_news.txt";
$news_files{"Entertainment"} =
  "$config_parms{data_dir}/web/Entertainment_news.txt";
$news_files{"Business"} = "$config_parms{data_dir}/web/Business_news.txt";
$news_files{"Tech"}     = "$config_parms{data_dir}/web/Tech_news.txt";
$news_files{"Science"}  = "$config_parms{data_dir}/web/Science_news.txt";
$news_files{"Health"}   = "$config_parms{data_dir}/web/Health_news.txt";
$news_files{"Sports"}   = "$config_parms{data_dir}/web/Sports_news.txt";

$p_all_news =
  new Process_Item("get_url http://dailynews.yahoo.com/fc $f_all_news_html");
$v_all_news = new Voice_Cmd('Get current news');
$v_all_news->set_authority('anyone');
$v_news = new Voice_Cmd(
    'Tell me the [Top,U S,World,Entertainment,Business,Technology,Science,Health,Sports] news'
);
$v_news->set_authority('anyone');

# Create trigger

if ($Reload) {
    &trigger_set(
        "time_cron('13 6,12,18 * * *')",
        "run_voice_cmd('Get daily news')",
        'NoExpire',
        'get daily news'
    ) unless &trigger_get('get daily news');
}

# Events

if ( said $v_news) {
    my $state = $v_news->{state};
    $v_news->respond($f_Top_news)            if $state eq 'Top';
    $v_news->respond( $news_files{"US"} )    if $state eq 'U S';
    $v_news->respond( $news_files{"World"} ) if $state eq 'World';
    $v_news->respond( $news_files{"Entertainment"} )
      if $state eq 'Entertainment';
    $v_news->respond( $news_files{"Business"} ) if $state eq 'Business';
    $v_news->respond( $news_files{"Tech"} )     if $state eq 'Technology';
    $v_news->respond( $news_files{"Science"} )  if $state eq 'Science';
    $v_news->respond( $news_files{"Health"} )   if $state eq 'Health';
    $v_news->respond( $news_files{"Sports"} )   if $state eq 'Sports';
}

if ( said $v_all_news) {
    if (&net_connect_check) {
        $v_all_news->respond('app=news Retrieving the current news...');

        # Use start instead of run so we can detect when it is done
        start $p_all_news;
    }
    else {
        $v_all_news->respond(
            'Cannot retrieve current news until connected to the Internet.');
    }
}

if ( done_now $p_all_news) {
    my $text;
    $text = "Here is what is making news right now: \n";
    for ( file_read "$f_all_news_html" ) {
        if (
            m!<a href="http://story\.news\.yahoo\.com/fc\?cid=34&tmpl=fc&in=[\w&=]+">([ \w\.,'":\-]+)!
          )
        {
            $text .= "$1.\n";
            $text =~ s! <td width="30%" align=right valign=middle>\n!!g;
        }
    }
    file_write( $f_Top_news, $text );

    if ( $v_all_news->{state} ne 'Check' ) {
        $v_all_news->respond("app=news connected=0 Current news retrieved.");
    }
    else {
        respond("app=news $text");
    }

    open( FN, "<$f_all_news_html" );

    # *** Out of date and not worth saving.  This module is just a page downloader.

    my %news;
    while (<FN>) {
        if (
            m!<a href="http://story\.news\.yahoo\.com/fc\?cid=34&tmpl=fc&in=(\w+)&cat=[=&\w]+">!
          )
        {
            my $cat = $1;
            $text = <FN>;
            $text =~ s! <td width="30%" align="right" valign="middle">\n!!g;
            $text =~ s!</a></td>!.!g;

            #   chomp($text);
            if ($text) { push @{ $news{"$cat"} }, "$text"; }
        }
    }
    close FN;

    foreach ( keys %news ) {
        open( OUT, ">$news_files{$_}" );
        print OUT "@{$news{$_}}";
        close(OUT);
    }
}
