#Category=News
my $f_drudge_report      = "$config_parms{data_dir}/web/drudge_report.txt";
my $f_drudge_report_html = "$config_parms{data_dir}/web/drudge_report.html";

$p_drudge_report =
  new Process_Item("get_url http://www.drudgereport.com $f_drudge_report_html");
$v_drudge_report = new Voice_Cmd('[Get,Read,Show] the drudge report');

speak($f_drudge_report)   if said $v_drudge_report eq 'Read';
display($f_drudge_report) if said $v_drudge_report eq 'Show';

if ( said $v_drudge_report eq 'Get' ) {

    # Do this only if we the file has not already been updated today and it is not empty
    if (    0
        and -s $f_drudge_report_html > 10
        and time_date_stamp( 6, $f_drudge_report_html ) eq time_date_stamp(6) )
    {
        print_log "drudge_report news is current";
        display $f_drudge_report;
    }
    else {
        if (&net_connect_check) {

            print_log "Drudge Report from the net ...";

            # Use start instead of run so we can detect when it is done
            start $p_drudge_report;
        }
    }
}

if ( done_now $p_drudge_report) {
    my $text;
    $text = "Top news stories from the Drudge Report: \n";
    for ( file_read "$f_drudge_report_html" ) {
        if (m!<a href="http://www.hosting.com!i) {
        }
        elsif (m!<A HREF="[\w\.\?/\-=:]*">([\w\s\.\-\?',;=]*)\.\.\.[ ]?</A>!i) {
            $text .= "$1.\n";
        }
    }

    file_write( $f_drudge_report, $text );
    display $f_drudge_report;
}

