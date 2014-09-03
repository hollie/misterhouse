#Category=News
#  news_onion
# Author: Dan Hoffard
# Gets and reads news from mobile.theonion.com
# Based on news_starnews

my $f_onion_summary = "$config_parms{data_dir}/web/onion_summary.txt";
my $f_onion_html    = "$config_parms{data_dir}/web/onion.html";

#$f_star_local_html2 = new File_Item($f_star_local_html); # Needed if we use run instead of process_item

$p_onion = new Process_Item(
    "get_url http://mobile.theonion.com/nibs.html $f_onion_html");
$v_onion = new Voice_Cmd('[Get,Read,Show] the Onion');

speak($f_onion_summary)   if said $v_onion eq 'Read';
display($f_onion_summary) if said $v_onion eq 'Show';

if ( said $v_onion eq 'Get' or time_cron "50 10 * * *" ) {

    if (&net_connect_check) {
        print_log "Retrieving The Onion News ...";

        # Use start instead of run so we can detect when it is done
        start $p_onion;
    }
}

if ( done_now $p_onion) {

    my ( $summary, $i );
    for ( file_read "$f_onion_html" ) {
        if (/<title>(.+)<\/title>/) {    # title
            $i++;
            $summary .= "$1\;\n";
        }
        elsif (/\*/) {
            $i++;
        }
        elsif (/\&\#151(.+)<\/p>/) {
            $i++;
            $summary .= "$1\;\n ";
        }
        elsif (/\&laquo\;/) {
            $i++;
        }
        elsif (/<b>(.+)<\/b>/) {
            $i++;
            $summary .= "$1\;\n ";
        }

        $summary .= "$1" if /<br>(.+)<\/p>/;
    }

    file_write "$f_onion_summary", $summary;

}

