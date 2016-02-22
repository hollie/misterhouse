#Category=News
#  Added Local Star news
my $f_star_citystate  = "$config_parms{data_dir}/web/star_citystate.txt";
my $f_star_local_html = "$config_parms{data_dir}/web/star_citystate.html";

#$f_star_local_html2 = new File_Item($f_star_local_html); # Needed if we use run instead of process_item

$p_star_citystate = new Process_Item(
    "get_url http://www.starnews.com/news/citystate/index.html $f_star_local_html"
);
$v_star_citystate = new Voice_Cmd('[Get,Read,Show] the Star Local news');

speak($f_star_citystate)   if said $v_star_citystate eq 'Read';
display($f_star_citystate) if said $v_star_citystate eq 'Show';

if ( said $v_star_citystate eq 'Get' ) {

    # Do this only if we the file has not already been updated today and it is not empty
    if (    0
        and -s $f_star_local_html > 10
        and time_date_stamp( 6, $f_star_local_html ) eq time_date_stamp(6) )
    {
        print_log "Star local news is current";
        display $f_star_citystate;
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving Star local news from the net ...";

            # Use start instead of run so we can detect when it is done
            start $p_star_citystate;
        }
    }
}

if ( done_now $p_star_citystate) {
    my $html = file_read $f_star_local_html;
    my ( $text, $report, $i, $headline, $start, $date, $sdate, $intro );
    $intro = "The Indy Star local news headlines";
    for ( file_read "$f_star_local_html" ) {

        if ( (/(.+), 2000/) and ( 1 == 1 ) ) {

            #$date  = " $1\n";
            $sdate++;
        }
        if    (/Indianapolis Star \|/)       { $start++; }
        if    (/From The Indianapolis Star/) { }
        elsif (/^&#/)                        { }
        elsif (/^Chatter.*/)                 { }
        elsif ( (/^([A-Z][A-Za-z0-9':,\$\s\-\.]+)/)
            and $start
            and $sdate < 2
            and $i < 9 )
        {
            $text .= "  $1\n";
        }
        elsif ( (/html">([A-Za-z0-9':,\$\s\-\.]+)</)
            and $sdate < 2
            and $i < 10 )
        {
            $i++;
            $headline++;
            $text .= "$i: $1\n";
        }
        elsif ( (/(^[A-Za-z0-9':,\$\s\-\.]+)/)
            and $headline
            and $sdate < 2
            and $i < 9 )
        {
            $headline = 0;
            $text .= "      $1\n";
        }

    }

    $report = $intro . $date . $text;
    file_write( $f_star_citystate, $report );
    display $f_star_citystate;
}

