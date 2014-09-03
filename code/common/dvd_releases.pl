# Category = Entertainment

#@ This script displays information about new DVD releases from <a href=http://www.videoeta.com/dvd.html>videoeta.com</a>

my $f_get_new_dvds    = "$config_parms{data_dir}/web/new_dvds.html";
my $f_top_dvds        = "$config_parms{data_dir}/web/top_dvds.html";
my $f_this_weeks_dvds = "$config_parms{data_dir}/web/this_weeks_dvds.html";
my @dvd_sections      = (
    'Top DVDs',
    'This Week\'s New DVDs',
    'Last Week\'s New DVDs',
    'Next Week\'s New DVDs'
);
$v_get_new_dvds = new Voice_Cmd '[Get,Check] DVD Info';
$v_get_new_dvds->set_info('Gets DVD information from the Internet');
$v_read_new_dvds = new Voice_Cmd 'Read [' . ( join ',', @dvd_sections ) . ']';
$v_read_new_dvds->set_info('Reads DVD information');

# *** Set authority to anyone for the last one!

$p_get_new_dvds =
  new Process_Item "get_url http://www.videoeta.com/dvd.html $f_get_new_dvds";

if ( my $state = said $v_read_new_dvds) {
    if ( $Save{$state} ) {
        respond "app=movies $state\n\n$Save{$state}";
    }
    else {
        respond "app=movies DVD information is unavailable at the moment.";
    }
}

if ( my $state = said $v_get_new_dvds) {
    unlink $f_get_new_dvds;
    $p_get_new_dvds->start;
    $p_get_new_dvds->{DVDsection} = $state;
    $v_get_new_dvds->respond("app=movies Retrieving DVD releases...");
}

if ( done_now $p_get_new_dvds) {
    for (@dvd_sections) {
        $Save{$_} = '';
    }
    my $section;
    my $this_week_html = '<ol>';
    my $top_dvds_html  = '<ol>';
    for my $html ( file_read $f_get_new_dvds, '' ) {
        if (   $html =~ /(Top DVDs)/
            or $html =~ /(This Week's New DVDs)/
            or $html =~ /(Last Week's New DVDs)/
            or $html =~ /(Next Week's New DVDs)/ )
        {
            $section = $1;
        }
        if ( $section and $html =~ m|href="(.+)">(.+)</a><br>| ) {
            if ( $section eq "This Week's New DVDs" ) {
                $this_week_html .=
                  "<li><a href=\"http://www.videoeta.com$1\">$2</a></li>";
            }
            elsif ( $section eq "Top DVDs" ) {
                $top_dvds_html .=
                  "<li><a href=\"http://www.videoeta.com$1\">$2</a></li>";
            }
            else {
                print $section;
            }
            $Save{$section} .= "$2\n";
        }
    }
    $this_week_html .= '</ol>';
    $top_dvds_html  .= '</ol>';

    file_write( $f_this_weeks_dvds, $this_week_html );
    file_write( $f_top_dvds,        $top_dvds_html );
    if ( $v_get_new_dvds->{state} eq 'Check' ) {
        my $msg;

        for (@dvd_sections) {
            $msg .= "$_: $Save{$_}" if $Save{$_};
        }

        $v_get_new_dvds->respond("app=movies $msg");
    }
    else {
        $v_get_new_dvds->respond("app=movies DVD data retrieved");
    }
}

# Triggers to get data and report new releases

if ($Reload) {
    if ( $Run_Members{'internet_dialup'} ) {
        &trigger_set(
            "state_now \$net_connect eq 'connected'",
            "run_voice_cmd 'Get DVD Info'",
            'NoExpire',
            'get dvd info'
        ) unless &trigger_get('get dvd info');
    }
    else {
        &trigger_set(
            "time_now '4 pm' and time_cron('* * * * 1') and &net_connect_check",
            "run_voice_cmd 'Get DVD Info'",
            'NoExpire',
            'get dvd info'
        ) unless &trigger_get('get dvd info');
    }

    &trigger_set(
        "time_now '5 pm' and time_cron('* * * * 1') and &net_connect_check",
        qq|run_voice_cmd "Read This Week's New DVDs"|,
        'NoExpire',
        'read dvd releases'
    ) unless &trigger_get('read dvd releases');

}
