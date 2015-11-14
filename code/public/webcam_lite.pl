# From Michael Dahms mdahms@carolina.rr.com
#
# He has a webcam site set up at:
#  http://home.carolina.rr.com/blondy/webcam/Sindex.html
#
# I use mh to allow visitors to flash the light on webcam  and type in voice
# messages for the TTS system

# Use with mh/web/public/webcam_lite.html

# Category=WebCam

$webcam_light = new X10_Item('A1');

$v_webcam_light =
  new Voice_Cmd("WebCam light [on,off,-30,-50,-80,+30,+50,+80]");

if ( $state = said $v_webcam_light) {
    set $webcam_light $state;

    my $domain_name =
      &net_domain_name( $Socket_Ports{http}{client_ip_address} );
    logit(
        "$config_parms{data_dir}/logs/webcam.$Year_Month_Now.log",
        "ip=$Socket_Ports{http}{client_ip_address} domain=$domain_name"
    );
    &display( $domain_name, 30, "Light 1 turned $state" );
    my @domain_name = split( '\.', $domain_name );
    $domain_name = $domain_name[-2];
    my $msg = "The webcam light 1 turned $state by $domain_name";
    speak $msg if time_greater_than("5 AM") and time_less_than("11 PM");
}

$webcam_light2 = new X10_Item('A3');

$v_webcam_light2 =
  new Voice_Cmd("WebCam light2 [on,off,-30,-50,-80,+30,+50,+80]");

if ( $state = said $v_webcam_light2) {
    set $webcam_light2 $state;

    my $domain_name =
      &net_domain_name( $Socket_Ports{http}{client_ip_address} );
    logit(
        "$config_parms{data_dir}/logs/webcam.$Year_Month_Now.log",
        "ip=$Socket_Ports{http}{client_ip_address} domain=$domain_name"
    );
    &display( $domain_name, 30, "Light 2 turned $state" );
    my @domain_name = split( '\.', $domain_name );
    $domain_name = $domain_name[-2];
    my $msg = "The webcam light 2 turned $state by $domain_name";
    speak $msg if time_greater_than("5 AM") and time_less_than("11 PM");
}

if ( $Save{web_text1} ) {
    $Save{web_text1} = &html_unescape( $Save{web_text1} );
    my $domain_name =
      &net_domain_name( $Socket_Ports{http}{client_ip_address} );
    logit( "$config_parms{data_dir}/logs/webtext.$Year_Month_Now.log",
        "ip=$Socket_Ports{http}{client_ip_address} $Save{web_nick1} said $Save{web_text1}"
    );
    my $msg = "$Save{web_nick1} Internet Message: $Save{web_text1}";
    &display( $msg, 90, 'webcam text' );
    speak $msg if time_greater_than("5 AM") and time_less_than("11 PM");
    $Save{web_text1} = '';
    $Save{web_nick1} = '';
}

