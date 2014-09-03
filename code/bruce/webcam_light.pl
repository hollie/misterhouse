# Category=Test

#@ Controls the webcam light

$webcam_light = new X10_Item('B1');

$v_webcam_light =
  new Voice_Cmd("WebCam light [on,off,-30,-50,-80,+30,+50,+80]");
$v_webcam_light->set_info(
    'A light in our kitchen that is controllable by anyone on the internet');

if ( $state = said $v_webcam_light) {
    set $webcam_light $state;

    #   set $webcam_light 'dim';
    #   set $webcam_light 'off';
    #   set $webcam_light 'on';
    #   my $domain_name = &net_domain_name($Socket_Ports{http}{client_ip_address});
    #  my $domain_name = &net_domain_name('24.6.1.184');
    my $msg = "The webcam light was just turned $state";

    #   my $msg = "The webcam light was just turned $state by address $Socket_Ports{http}{client_ip_address}";
    #   $msg .= " from domain $domain_name" if $domain_name;
    speak $msg if time_greater_than("8 AM") and time_less_than("10 PM");
    print_log $msg;
}

if ( $Save{web_text1} ) {

    #    my $msg = "Internet message: " . &html_unescape($Save{web_text1});
    my $msg = "Internet message: " . $Save{web_text1};
    speak $msg;
    &display( $msg, 120, 'webcam text' )
      ;    # Number is how many seconds till autoclose

    #    display $msg;
    $Save{web_text1} = '';
}

# This is called from html.
sub weblight_check {
    my ($request) = @_;
    return "Called from weblight check subroutine.  Request=$request";
}

