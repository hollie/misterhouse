#Category=News

#@ Gets Motivational Quote of the day

my $f_mquote_otd = "$config_parms{data_dir}/web/mquote_otd.txt";
my $f_mquote_otd_html = "$config_parms{data_dir}/web/mquote_otd.html";

$p_mquote_otd = new Process_Item("get_url http://tqpage.com/mqotd.php3 $f_mquote_otd_html");
$v_mquote_otd = new  Voice_Cmd('[Get,Read,Show] Motivational Quote of the day');
$v_mquote_otd ->set_authority('anyone');

respond($f_mquote_otd)   if said $v_mquote_otd eq 'Read';
display($f_mquote_otd) if said $v_mquote_otd eq 'Show';

if (said $v_mquote_otd eq 'Get' and &net_connect_check) {
    print_log "Retrieving on this day in history from the net ...";
    start $p_mquote_otd;
}

if (done_now $p_mquote_otd) {
    my $html = file_read $f_mquote_otd_html;                           
    my $text = "Motivational Quotes of the day: \n\n";

# <dt>Keep your broken arm inside your sleeve.</font></dt><dd><b><font size='-1'>Chinese Proverb</font></b></dd><p> </p>
    for (file_read "$f_mquote_otd_html") {
        while (m!<dt>(.+?)</font.+?<font .+?>(.+?)<!ig) {
            $text .= "$2:\n    $1\n\n";   
        }
    }    

    file_write($f_mquote_otd, $text);
    display $f_mquote_otd;
}

