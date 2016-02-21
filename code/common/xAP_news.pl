
# Category = xAP

#@ This code will monitor the xAP news client from <a href=http://www.mi4.biz>mi4.biz</a>
#@ and store new news stories in a News object.  Set the xAP_news mh.ini parm to control
#@ if you want the news titles spoken, printed, and/or displayed.

$xAP_news = new xAP_Item('news.report');
$News     = new Generic_Item;
$News->set_casesensitive();

if ( state_now $xAP_news) {
    my $station = lc $xAP_news->{'news.feed'}{station};
    $News->{stories}{$station} = 0;    # Track number of new stories
    for my $i ( 1 .. 5 ) {
        my $section = "news.story.$i";
        my $title   = $xAP_news->{$section}{title};
        my $link    = $xAP_news->{$section}{link};
        print "xAP_news: s=$station $section t=$title\n" if $Debug{xap_news};
        next if !$title or $News->{titles}{$title};
        $link = $1
          if $link =~ /base=(http.+)/; # Drop redirect prefix found on some urls
        $News->{titles}{$title}{link}    = $link;
        $News->{titles}{$title}{station} = $station;
        $News->{titles}{$title}{time}    = $Time_Now;
        $News->{stories}{$station}++;
        set $News $title;
    }
}

if ( my $title = state_now $News) {
    my $station = $News->{titles}{$title}{station};
    my $news    = "$station: $title";

    my ( %log, $log );
    $config_parms{xAP_news} =
      'cnn => msg&display, slashdot => speak&display, default => display&print'
      unless $config_parms{xAP_news};
    &main::read_parm_hash( \%log, lc $config_parms{xAP_news} );
    $log = $log{$station};
    $log = $log{default} unless $log;
    print "xAP_news: s=$station c=$News->{stories}{$station} l=$log t=$news\n"
      if $Debug{xap_news};

    # Speak only if we have a few stories (i.e. avoid startup lists of 5 stories)
    speak "News from $news"
      if $log =~ /speak/ and $News->{stories}{$station} < 3;
    print_log $news if $log =~ /print/;
    print_msg $news if $log =~ /msg/;
    display
      text        => "$Time_Date $news\n",
      time        => 0,
      width       => 90,
      height      => 15,
      title       => 'xAP News',
      window_name => 'xAP news',
      append      => 'top',
      font        => 'fixed'
      if $log =~ /display/;
}

# Example data
#  key=news.story.1 : title value=Katharine Hepburn dies
#  key=news.story.3 : link  value=http://www.syntechsoftware.com/redirect.php?base=http://www.cnn.com/2003/US/Midwest/06/29/deck.collapse/index.html
#  key=news.story.3 : desc  value=Double-Click for information on 'Porch collapse kills 12 at Chicag
#  key=news.feed : link  value=http://www.syntechsoftware.com/
#  key=news.feed : count  value=5
#  key=news.feed : station  value=cnn
#  key=news.feed : desc  value=CNN News RSS - More RSS @ http://rss.syntechsoftware.com/
#  key=news.feed : title  value=CNN News
