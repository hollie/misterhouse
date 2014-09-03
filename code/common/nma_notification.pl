# Category=Home_Network
#
#@ Sends Notification messages to NMA - Notify My Android

# The following config parameters should be in mh.private.ini or mh.ini
#
# nma_api_key=<api key>                    (API Key from NotifyMyAndroid)

use LWP::UserAgent;

# noloop=start
my $nma_api_key = $config_parms{nma_api_key};

# noloop=stop

#Tell MH to call our routine each time something is spoken
&Speak_pre_add_hook( \&nma_notify, 1 ) if $Reload;

# Notify the on startup / restart
if ($Startup) {
    print_log( "System Restarted, Notifying NMA -- using api key: ",
        $nma_api_key );
    nma_notify_b( "$nma_api_key", "Misterhouse has been restarted" );
}

sub nma_notify() {
    my %parms = @_;
    print "NMA message sent";
    print "----------------";
    nma_notify_b( "$nma_api_key", "$parms{text}" );
    return;
}

sub nma_notify_b {
    my ( $nma_api_key, $text ) = @_;

    print "NMA message sent";

    # syntax to send a message from a browser or curl -- ie: for testing
    # https://www.notifymyandroid.com/publicapi/notify?apikey=<api key>&application=<application name>&event=<event name>&description=<description>&priority=0

    # NMA allows you to print to 3 lines
    # I prefer printing to the main line which is listed as application in the below url.  This works great fot GTV since the event pops up over whatever you are watching
    my $url =
        'https://www.notifymyandroid.com/publicapi/notify?apikey='
      . $nma_api_key
      . '&application='
      . $text
      . '&event=&description=&priority=0';

    # If you prefer the main line to list MisterHouse and have your event appear on the second line, uncomment the following line and comment out the line above this
    #  my $url = 'https://www.notifymyandroid.com/publicapi/notify?apikey='.$nma_api_key.'&application=MisterHouse&event='.$text.'&description=&priority=0';

    # Change spaces to HTML space codes
    $url =~ s/ /%20/g;
    my $ua  = new LWP::UserAgent;
    my $req = new HTTP::Request GET => $url;
    my $res = $ua->request($req);
}
