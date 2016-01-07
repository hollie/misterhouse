# Category = News

#@ This module gets and displays a list of events that occurred on the current
#@ day of the year from the New York Times.

my $f_onthisday       = "$config_parms{data_dir}/web/onthisday.txt";
my $f_onthisday_html  = "$config_parms{data_dir}/web/onthisday.html";
my $f_onthisday_html2 = "$config_parms{data_dir}/web/onthisday_pruned.html";

$p_onthisday = new Process_Item(
    "get_url http://www.nytimes.com/learning/general/onthisday/index.html $f_onthisday_html"
);
$v_onthisday = new Voice_Cmd('[Get,Show,Check] on this day');
$v_onthisday->set_info('Get or display the daily calendar facts');
$v_onthisday->set_authority('anyone');

if ( ( said $v_onthisday eq 'Get' ) or ( said $v_onthisday eq 'Check' ) ) {
    if (&net_connect_check) {
        $v_onthisday->respond("Retrieving daily calendar facts...");
        start $p_onthisday;
    }
    else {
        $v_onthisday->respond(
            "Cannot retrieve daily calendar facts when disconnected from the Internet."
        );
    }
}

if ( said $v_onthisday eq 'Show' ) {
    my $text = file_read $f_onthisday;
    $v_onthisday->respond($text);
}

if ( done_now $p_onthisday) {
    my $html = file_read $f_onthisday_html;

    # Pull out date
    #<B>Monday, December&nbsp;23rd</B>
    my ($date) = $html =~ /<B>(\S+, \S+?&nbsp;\S+?)<\/B>/i;

    # Prune down to main table
    $html =~ s|.+(\<tr.+?Today\'s .+)|$1|is;

    # Change relative lines to absolute
    $html =~ s|href="/|href="http://www.nytimes.com/|gi;
    $html =~ s|href="../|href="http://www.nytimes.com/learning/general/|gi;
    $html =~ s|src="/|src="http://www.nytimes.com/|gi;
    $html =~
      s|href="archive.html|href="http://www.nytimes.com/learning/general/onthisday/archive.html|gi;

    my $html2 = "<html><body><table>$date\n" . $html . "</table></body></html>";

    #   my $text = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($html2));
    my $text = &html_to_text($html2);
    $text =~ s/<[^>]*>//g;

    #	$text =~ s/<.*\/>//g;

    #    $text =~ s/.+?(on this date in)/$1/is;
    file_write( $f_onthisday_html2, $html2 );
    file_write( $f_onthisday,       $text );

    if ( $v_onthisday->{state} eq 'Get' ) {
        $v_onthisday->respond('connected=0 Daily calendar facts retrieved.');
    }
    else {
        $v_onthisday->respond('connected=0 $text');
    }
}

if ($Reload) {
    if ( $Run_Members{'internet_dialup'} ) {
        &trigger_set(
            "state_now \$net_connect eq 'connected'",
            "run_voice_cmd 'Get on this day'",
            'NoExpire',
            'get calendar facts'
        ) unless &trigger_get('get calendar facts');
    }
    else {
        &trigger_set(
            "time_cron '30 6 * * *' and net_connect_check",
            "run_voice_cmd 'Get on this day'",
            'NoExpire',
            'get calendar facts'
        ) unless &trigger_get('get calendar facts');
    }
}
