# Category=Home_Network
#
#@ Sends Notification message to XBMC

use LWP::UserAgent;

$v_xbmc_osd = new Voice_Cmd("Test XBMC Notify");

# noloop=start
# Set the default port to 8080 (XBMC Default) if not specified
$config_parms{xbmc_notify_port} = "8080" unless $config_parms{xbmc_notify_port};

# noloop=stop

if ($Startup) {

    # Notify the on startup / restart
    print_log("System Restarted, Notifying XBMC") if $Debug{xbmc};
    display_xbmcosd( "System Restarted", "Misterhouse has been restarted" );
}

if ( said $v_xbmc_osd) {

    # Send a test notification to the configured XBMC instance
    print_log("Sending test notification") if $Debug{xbmc};
    display_xbmcosd( "Test Notification", "This is a test notification!!" );
}

sub display_xbmcosd {
    my ( $title, $text ) = @_;

    unless ( $config_parms{xbmc_notify_address} ) {
        print_log(
            "xbmc_notify_address has not been set in mh.ini, Unable to notify XBMC."
        );
        return;
    }

    # Change spaces to HTML space codes
    $title =~ s/ /%20/g;
    $text =~ s/ /%20/g;

    print_log( "Sending notification to XBMC at http://"
          . $config_parms{xbmc_notify_address} . ":"
          . $config_parms{xbmc_notify_port}
          . "/jsonrpc" )
      if $Debug{xbmc};

    # Doesnt support authentication (Yet)
    my $url =
        'http://'
      . $config_parms{xbmc_notify_address} . ':'
      . $config_parms{xbmc_notify_port}
      . '/jsonrpc?request={"jsonrpc":"2.0","method":"GUI.ShowNotification","params":{"title":"'
      . $title
      . '","message":"'
      . $text
      . '"},"id":1}';

    my $ua  = new LWP::UserAgent;
    my $req = new HTTP::Request GET => $url;
    my $res = $ua->request($req);
}
