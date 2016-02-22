# Category = BBallNews

my $f_bballscores_html = "$config_parms{data_dir}/web/bballScores.html";

$p_bballscores = new Process_Item(
    "get_url http://scores.nba.com/games/kings.html $f_bballscores_html");

$v_get_bballscores = new Voice_Cmd('Get basketball scores');
$v_get_bballscores->set_info("Report status of defined objects.");
$v_get_bballscores->set_icon("net");

if ( ( time_cron '15 17-22 * * *' or $state = said $v_get_bballscores)
    and &net_connect_check )
{
    print_log "Retrieving Baskball Scores ...";
    start $p_bballscores;
}

if ( done_now $p_bballscores) {
    print_log "Done retrieving Baskball scores";

}

if ( file_change "$f_bballscores_html" ) {
    my $http = "<HTML>";
    open( BBSCORE, "$f_bballscores_html" )
      or print_log "Can't open bballScores.html";
    while (<BBSCORE>) {
        $http .= $1 if $_ =~ /(.td.*crtBoxT.*CSB.*td.)/i;
    }
    close BBSCORE;
    $http .= "</HTML>";
    my $text = &html_to_text($http);
    $text =~ s/Today.s\s+Game//gi;
    $text =~ s/Final//gi;
    $Save{BBallScores} = $text;

    #print_log "$text";
}

# You can add add it to your customized status line with this:

sub web_status_line {
    my $html;
    $html .=
      qq[&nbsp;<img src='/ia5/images/barometer.gif' border=0>&nbsp;$Save{BX24_Barometer}];
    my $CPU_Temp = sensor_output('temp1');
    if ( $CPU_Temp > 130 ) {
        $CPU_Temp = qq[<FONT color='red'><BLINK>$CPU_Temp</BLINK></FONT>];
    }
    $html .=
      qq[&nbsp;<img src='/ia5/images/temp.gif' border=0>&nbsp;CPU:$CPU_Temp];
    $html .= qq[&nbsp;&nbsp;$Save{BBallScores}];
    return $html;
}

