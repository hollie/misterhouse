
# Called from mh/web/ia5/outside/main.shtml
#  - This code is not used anymore because the wunderground page does not make
#    the .gif of the radar available in the html anymore.

my $set = shift;

my $html;

if ( !$set ) {

    #   print "db1 $config_parms{web_href_weather_local}\n";
    #   print "db2 $config_parms{web_href_weather_local_MHINTERNAL_filename}\n";
    if ( &get_parm_file( \%config_parms, 'web_href_weather_local_image' ) ) {
        $html = '<br>Our local weather.';
    }
    $html .=
      '<br><a href=/bin/set_parm_weather_local.pl?set>Reset the mh.ini parm for this page according to your zip code</a>';
    return html_page '', $html;
}
else {

    return 'Not authorized to make updates' unless $Authorized eq 'admin';

    speak "Getting web data";

    return &html_page( '', "Connect to the internet and try again" )
      unless net_ping 'www.google.com';

    $html = get
      "http://www.wunderground.com/cgi-bin/findweather/getForecast?query=$config_parms{zip_code}";
    my ($id) =
      $html =~ m|<a href="/radar/station.asp\?ID=(.*)">Local Radar</a>|i;

    speak "Weather i d is $id";

    # Update the mh.ini parm if changed
    my $parm1 =
      "http://www.wunderground.com/cgi-bin/findweather/getForecast?query=$config_parms{zip_code}";
    my $parm2 = "http://radar.wunderground.com/data/nids/${id}_0.gif";
    if (   $parm1 ne $config_parms{web_href_weather_local}
        or $parm2 ne $config_parms{web_href_weather_local_image} )
    {
        my %parms = (
            'web_href_weather_local',       $parm1,
            'web_href_weather_local_image', $parm2
        );
        main::write_mh_opts( \%parms );

        #       my $parmfile = $Pgm_Path . "/mh.private.ini";
        #       $parmfile = $ENV{mh_parms} if $ENV{mh_parms};
        #       logit $parmfile, "\n# Added by web page script web/bin/set_parm_weather_local.pl.  Delete to reset via the web page\n$parm1\n", 0;
    }

    $html =
      "<b>Weather page result</b>: <ul><li>Zipcode used:  $config_parms{zip_code}"
      . "<li>ID: $id<li>web_href_weather_local: $parm1<li>web_href_weather_local_image: $parm2</ul>";

    return html_page '', $html;
}

