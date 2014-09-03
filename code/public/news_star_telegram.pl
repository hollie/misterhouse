#Category=News
#  news_star_telegram
# Author: Dan Hoffard
# Gets and reads news from the Fort Worth Star Telegram.
# Based on news_starnews

my $f_telegram_summary = "$config_parms{data_dir}/web/telegram_summary.txt";
my $f_telegram_html    = "$config_parms{data_dir}/web/telegram.html";

$p_telegram = new Process_Item(
    "get_url http://www.dfw.com/mld/dfw/news/local $f_telegram_html");
$v_telegram = new Voice_Cmd('[Get,Read,Show] the local news');

speak($f_telegram_summary)   if said $v_telegram eq 'Read';
display($f_telegram_summary) if said $v_telegram eq 'Show';

if ( said $v_telegram eq 'Get' or time_cron "50 5 * * *" ) {

    if (&net_connect_check) {
        print_log "Retrieving Star Telegram News from the net ...";

        # Use start instead of run so we can detect when it is done
        start $p_telegram;
    }
}

if ( done_now $p_telegram) {

    my ( $summary, $i );
    for ( file_read "$f_telegram_html" ) {
        if (/FORT(.+)BRIEFS/) {
            $i++;
            $summary .= "FORT WORTH AND ARLINGTON BRIEFS\;\n";
        }
        elsif (/digest-headline\">(.+)<\/a>/) {
            $i++;
            $summary .= "$1\;\n";
        }
        elsif (/\&amp\;\">(.+)\/a/) {
            $i++;
            $summary .= "$1\;\n";
        }

        $summary .= "$1" if /<br>(.+)<\/p>/;
    }

    file_write "$f_telegram_summary", $summary;
}

