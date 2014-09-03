# Category = News

#@ This module adds the ability to obtain news from slashdot.org. It
#@ also automatically gets this information each day.

my $slashdot_news = "$config_parms{data_dir}/web/slashdot_news";
$p_slashdot_news = new Process_Item
  "get_url http://slashdot.org/slashdot.xml $slashdot_news.xml";
$v_slashdot_news =
  new Voice_Cmd '[Get,Show,Display,Read,Parse] the slashdot news';
$v_slashdot_news->set_info(
    'Summarize recent news from the great geek new site slashdot.org');
$v_slashdot_news->set_authority('anyone');

$state = said $v_slashdot_news;
if ( $state eq 'Get' or time_now('6:30 AM') ) {
    print_log "Getting slashdot news";
    start $p_slashdot_news;
}
display "$slashdot_news.txt" if $state eq 'Show' or $state eq 'Display';
speak "$slashdot_news.titles" if $state eq 'Read';

# XML::Parser seems like overkill for this ... just do simle parsing
if ( done_now $p_slashdot_news or $state eq 'Parse' ) {
    my ( $titles, $summary, $i );
    for ( file_read "$slashdot_news.xml" ) {
        if (/<title>(.+)<\/title>/) {
            $i++;
            $titles  .= "$i: $1.\n";
            $summary .= "Title: $1\n";
        }
        $summary .= "$1"            if /<time>(.+)<\/time>/;
        $summary .= " by $1 "       if /<author>(.+)<\/author>/;
        $summary .= " in dept: $1 " if /<department>(.+)<\/department>/;
        $summary .= " ($1 "         if /<topic>(.+)<\/topic>/;
        $summary .= "  $1)\n\n"     if /<comments>(.+)<\/comments>/;
    }
    file_write "$slashdot_news.titles", $titles;
    file_write "$slashdot_news.txt",    $summary;
    display "$slashdot_news.txt";
}
