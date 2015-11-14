#Category=News
#  Added Local Star news
my $f_star_citystate  = "$config_parms{data_dir}/web/star_citystate.txt";
my $f_star_local_html = "$config_parms{data_dir}/web/star_citystate.html";

#$f_star_local_html2 = new File_Item($f_star_local_html); # Needed if we use run instead of process_item

$p_star_citystate = new Process_Item(
    "get_url http://www.starnews.com/digest/citystate.html $f_star_local_html");
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

    my ( $intro, $text, $i, $report, $news, $sum, $sdate );

    $intro = "The Indy Star local news headlines for ";
    for ( file_read "$f_star_local_html" ) {

        # Must do this only once.
        if (m!Click for the full story</a> from The Indianapolis Star,(.+)!) {
            $sdate = "$1.\n";
        }
        if (/STATE SUMMARIES/) {
            $news = 1;
        }

        if (/(Click for the full story.)|Advertising/) { }

        elsif ( (/(.+)/) and $sum ) {
            $i++;
            $sum = 0;
            $text .= "$i: $1.\n";
        }

        elsif ( (/<b>(\x0A){2}([A-Za-z0-9'\-,\$\s]+)/) and $news < 3 ) {
            $i++;
            $text .= "$i: $1.\n";
        }
        elsif ( (/SUMMARY -->/) and $news < 3 ) {
            $sum++;
        }

        elsif ( (/html">([A-Za-z0-9':,\$\s\-]+)</) and $news < 3 ) {
            $i++;
            $text .= "$i: $1.\n";
        }
        elsif (/(END BANNER AD POSITION)|(-- DATELINE --)/) {
            $news++;
        }
        else { }

    }
    $report = $intro . $sdate . $text;
    file_write( $f_star_citystate, $report );
    display $f_star_citystate;
}

