#Category=weather
#  Added wrtv 6 weather
my $f_wrtv6_weather      = "$config_parms{data_dir}/web/wrtv6_weather.txt";
my $f_wrtv6_weather_html = "$config_parms{data_dir}/web/wrtv6_weather.html";

#$f_wrtv6_weather2_html2 = new File_Item($f_wrtv6_weather2_html); # Needed if we use run instead of process_item

$p_wrtv6_weather = new Process_Item(
    "get_url http://www.wrtv.com/weather/index.shtml $f_wrtv6_weather_html");
$v_wrtv6_weather = new Voice_Cmd('[Get,Read,Show] wrtv6 weather');

speak($f_wrtv6_weather)   if said $v_wrtv6_weather eq 'Read';
display($f_wrtv6_weather) if said $v_wrtv6_weather eq 'Show';

if ( said $v_wrtv6_weather eq 'Get' ) {

    # Do this only if we the file has not already been updated today and it is not empty
    if (    0
        and -s $f_wrtv6_weather_html > 10
        and time_date_stamp( 6, $f_wrtv6_weather_html ) eq time_date_stamp(6) )
    {
        print_log "wrtv6_weather news is current";
        display $f_wrtv6_weather;
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving on this day in history from the net ...";

            # Use start instead of run so we can detect when it is done
            start $p_wrtv6_weather;
        }
    }
}

if ( done_now $p_wrtv6_weather) {
    my $html = file_read $f_wrtv6_weather_html;
    my ( $text, $news, $line_num, $start, $stop );

    $text = "The Indy four day weather forecast from WRTV 6 is \n";
    for ( file_read "$f_wrtv6_weather_html" ) {
        $line_num++;
        if (/StormTeam6 Forecast/) {
            $news++;
        }
        if ( $start and not $stop ) {
            if (/^([\w\.\s\?,'":]+)/) {
                $text .= "$1\n";
            }
        }
        if ( (/color=#ffffff>/) and $news ) {
            $start = $line_num;
            $news  = 0;
        }

        if ($start) {
            if (m!</TD></tr></table>!) {
                $stop++;
                $start = 0;
            }
        }
    }
    $text =~ s/ Ch./ Chance/g;
    $text =~ s/ wind / wiend /g;
    $text =~ s/T'Showers/thunder showers/g;
    $text =~ s/Occ./occasional/g;
    $text =~ s/ AM /morning/g;
    $text =~ s/ PM /evening/g;
    $text =~ s/ temps \B/temperatures/g;
    file_write( $f_wrtv6_weather, $text );
    display $f_wrtv6_weather;
}

