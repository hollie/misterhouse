# Category = Traffic

#@ This module gets current traffic conditions from Yahoo
#@ Based on the original get ap news module included with MisterHouse
#@ Modified By Tom Dunk

#@ Add the following to your mh.ini file
#@ traffic_loc = Zip code (or a location such as city state)
#@ traffic_mag = Number of miles range to show
#@ traffic_sev = Minimum severity of accidents and incidents to show (1=least severe, 5=most severe)

use XML::RSS;

#noloop=start
my $rss              = new XML::RSS;
my $f_y_traffic      = "$config_parms{data_dir}/web/yahoo_traffic.txt";
my $f_y_traffic_html = "$config_parms{data_dir}/web/yahoo_traffic_pruned.html";
my $f_y_traffic_rss  = "$config_parms{data_dir}/web/yahoo_traffic.rss";
$p_y_traffic = new Process_Item(
    "get_url http://maps.yahoo.com/traffic.rss?csz=$config_parms{traffic_loc}&$config_parms{traffic_mag}=4&minsev=$config_parms{traffic_sev} $f_y_traffic_rss"
);
$v_y_traffic = new Voice_Cmd('What is the Traffic');
$v_y_traffic->set_info('Responds with traffic report from Yahoo');
$v_get_y_traffic = new Voice_Cmd('[Get,Check,Mail,SMS] Yahoo Traffic');
$v_traffic       = new Voice_Cmd('Tell me the traffic');
tie_event $v_get_y_traffic "get_y_traffic(\$state)";

#noloop=stop

sub get_y_traffic {
    my $response;
    my $state = shift;

    if (&net_connect_check) {
        $response = "Retrieving traffic from Yahoo...";
        start $p_y_traffic;
    }
    else {
        $response =
          "Could not retrieve traffic from Yahoo (network connection is down.)";
    }

    $v_get_y_traffic->respond("app=traffic $response");

}

if ( done_now $p_y_traffic) {
    $rss->parsefile($f_y_traffic_rss);
    my $html = "";
    my $text = "";

    $html = "<ul>";

    # print the title and link of each RSS item

    my $description;
    my $i = 0;

    foreach my $item ( @{ $rss->{'items'} } ) {

        #Get what we need for the straight text version
        $text .= "$item->{'title'}";
        $text .= "$item->{'description'}\n\n";

        $description = $item->{'description'};

        #$description = &html_encode($description);
        # assumes that field is properly encoded to begin with
        $description = &quote_attribute($description);

        #Get and format the html version
        if ( $Save{traffic_y_headline} ne $item->{'title'} ) {
            $Save{traffic_y_headline} = $item->{'title'};
            $i = $i + 1;
        }

        $html .=
            qq|<li><a href="|
          . &recompose_uri( $item->{'link'} )
          . qq|" title=$description>|
          . $item->{'title'}
          . qq|</a></li>|;

    }

    $html .= "</ul>";

    #write the files.
    file_write( $f_y_traffic,      $text );
    file_write( $f_y_traffic_html, $html );

    if ( $v_get_y_traffic->{state} eq 'Mail' ) {
        my $to = $config_parms{traffic_sendto} || "";
        $v_get_y_traffic->respond(
                "connected=0 image=mail Sending Yahoo traffic to "
              . ( ($to) ? $to : $config_parms{net_mail_send_account} )
              . '.' );
        &net_mail_send(
            subject => "Current traffic from Yahoo",
            to      => $to,
            file    => $f_y_traffic_html,
            mime    => 'html_inline'
        );
    }
    elsif ( $v_get_y_traffic->{state} eq 'SMS' ) {

        # *** Use PCS if present!  Move to sub in main mh
        # *** Check return value
        my $to = $config_parms{cell_phone};
        if ($to) {
            $v_get_y_traffic->respond(
                "connected=0 image=mail Sending Yahoo traffic to cell phone.");
            &net_mail_send(
                subject => "Current traffic from Yahoo",
                to      => $to,
                file    => $f_y_traffic
            );
        }
        else {
            $v_get_ap_news->respond(
                "connected=0 app=error Mobile phone email address not found!");
        }
    }

    elsif ( $v_get_y_traffic->{state} ne 'Check' )
    {    # get responds with story count
        $v_get_y_traffic->respond(
            "connected=0 app=traffic Yahoo traffic retrieved $i reports.");
    }
    else {    # check responds with stories
        $v_get_y_traffic->respond("connected=0 app=traffic $text");
    }

}

if ( $state = said $v_y_traffic) {
    $v_y_traffic->respond("app=traffic $f_y_traffic");
}
if ( $state = said $v_traffic) {
    speak $f_y_traffic;
}

# create trigger to download current traffic at four and thirty-four after each hour

if ($Reload) {
    if ( $Run_Members{'internet_dialup'} ) {
        &trigger_set(
            "state_now \$net_connect eq 'connected'",
            "run_voice_cmd 'Get Yahoo traffic'",
            'NoExpire',
            'get Yahoo traffic'
        ) unless &trigger_get('get Yahoo traffic');

    }
    else {
        &trigger_set(
            "time_cron '4,34 * * * *' and net_connect_check",
            "run_voice_cmd 'Get Yahoo traffic'",
            'NoExpire',
            'get Yahoo traffic'
        ) unless &trigger_get('get Yahoo traffic');
    }
}

