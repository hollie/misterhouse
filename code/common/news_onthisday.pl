# Category = News

#@ This module gets and displays a list of events that occurred on the current
#@ day of the year from the New York Times.

# Run this periodically from internet_logon.pl

my $f_onthisday = "$config_parms{data_dir}/web/onthisday.txt";
my $f_onthisday_html  = "$config_parms{data_dir}/web/onthisday.html";
my $f_onthisday_html2 = "$config_parms{data_dir}/web/onthisday_pruned.html";

$p_onthisday = new Process_Item("get_url http://www.nytimes.com/learning/general/onthisday/index.html $f_onthisday_html");
$v_onthisday = new  Voice_Cmd('[Get,Show] on this day');
$v_onthisday ->set_info('Get or display the daily calendar facts');
$v_onthisday ->set_authority('anyone');

#***Fix this, wait for process to end THEN parse and write files
#***Currently a mess, requiring display of news each day

if ((said $v_onthisday eq 'Get')) {

    # Do this only if we the file has not already been updated today and it is not empty
    #if (-s $f_onthisday_html > 10 and
    #    time_date_stamp(6, $f_onthisday_html) eq time_date_stamp(6)) {
    #    print_log "Daily calendar facts are current";
    #}
    #else {
        if (&net_connect_check) {
            print_log "Retrieving daily calendar facts...";
            start $p_onthisday;
        }
    #}
}

if (said $v_onthisday eq 'Show') {
	my $text = file_read $f_onthisday;
        respond $text;
}

if (done_now $p_onthisday) {


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
    $html =~ s|href="archive.html|href="http://www.nytimes.com/learning/general/onthisday/archive.html|gi;




    my $html2 = "<html><body><table>$date\n" . $html;
#   my $text = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($html2));
    my $text = &html_to_text($html2);
	$text =~ s/<[^>]*>//g;
#	$text =~ s/<.*\/>//g;

#    $text =~ s/.+?(on this date in)/$1/is;
    file_write($f_onthisday_html2, $html2);
    file_write($f_onthisday, $text);


}
