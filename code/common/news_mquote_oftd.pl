#Category=News

#@ Gets motivational quotes for the day

#noloop=start
my $mquote_otd      = "$config_parms{data_dir}/web/mquote_otd.txt";
my $mquote_otd_html = "$config_parms{data_dir}/web/mquote_otd.html";
my $mquote_otd_html_pruned =
  "$config_parms{data_dir}/web/mquote_otd_pruned.html";

#noloop=stop

$p_mquote_otd =
  new Process_Item("get_url http://tqpage.com/mqotd.php3 $mquote_otd_html");
$v_mquote_otd =
  new Voice_Cmd('[Get,Read,Check] Motivational Quotes of the day');
$v_mquote_otd->set_authority('anyone');

if ( 'Read' eq said $v_mquote_otd) {
    respond("app=motivation $mquote_otd");
}

if ( ( said $v_mquote_otd eq 'Get' or said $v_mquote_otd eq 'Check' )
    and &net_connect_check )
{
    $v_mquote_otd->respond(
        "app=motivation Retrieving motivational quotes from the Internet...");
    start $p_mquote_otd;
}

if ( done_now $p_mquote_otd) {
    my $html;
    $html = file_read $mquote_otd_html;
    my $text        = "Motivational Quotes for Today: \n\n";
    my $html_pruned = '<ol>';

    for ( file_read "$mquote_otd_html" ) {

        while (m!/quote/([^"]*?)">([^<]*?)</a>!ig) {
            unless ( $2 =~ /<img/gi ) {
                $text .= "$2\n\n";
                $html_pruned .=
                  "<li><a href=\"http://www.quotationspage.com/quote/$1\">$2</a></li>";
            }
        }
    }
    $html_pruned .= '</ol>';
    file_write( $mquote_otd,             $text );
    file_write( $mquote_otd_html_pruned, $html_pruned );
    if ( $v_mquote_otd->{state} eq 'Get' ) {
        $v_mquote_otd->respond(
            'app=motivation connected=0 Motivational quotes retrieved.');
    }
    else {
        $v_mquote_otd->respond('app=motivation connected=0 $text');
    }
}

if ($Reload) {
    if ( $Run_Members{'internet_dialup'} ) {
        &trigger_set(
            "state_now \$net_connect eq 'connected'",
            "run_voice_cmd 'Get  Motivational Quotes of the day'",
            'NoExpire',
            'get motivational quotes'
        ) unless &trigger_get('get motivational quotes');
    }
    else {
        &trigger_set(
            "time_cron '30 6 * * *' and net_connect_check",
            "run_voice_cmd 'Get Motivational Quotes of the day'",
            'NoExpire',
            'get motivational quotes'
        ) unless &trigger_get('get motivational quotes');
    }
}
