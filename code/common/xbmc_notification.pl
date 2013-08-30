# Category=Home_Network
#
#@ Sends Notification message to XBMC
#
# The following config parameters should be in mh.private.ini or mh.ini
#
# xbmc_notify_port=<Web port of your XBMC installation (Defaults to 8080 if unset)>
# xbmc_notify_address=192.168.1.50         (IP of XBMC server)
# xbmc_timeout=5000                        (amount of time to display message on screen -- in milliseconds)
# xbmc_title=MisterHouse                   (Title of notification box)
# xbmc_image=http://192.168.1.5/ia5/mh.png (Image to display next to message.. I copied favicon.ico)
#
#
# If notifications are not being received by XBMC, ensure it's listening on 8080.
# Some installs may set it to 80
#
# http://misterhouse.wikispaces.com/XBMC+Notifications
#
#


use LWP::UserAgent;

$v_xbmc_osd = new  Voice_Cmd("Test XBMC Notify");

# noloop=start
# Set the default port to 8080 (XBMC Default) if not specified
$config_parms{xbmc_notify_port} = "8080" unless $config_parms{xbmc_notify_port};

# noloop=stop

#Tell MH to call our routine each time something is spoken
&Speak_pre_add_hook(\&xbmc_yac,1) if $Reload;
$v_xbmc_yac_test   =  new Voice_Cmd('Test XBMC yac connection', undef, 1);
if ($state = said $v_xbmc_yac_test) {
        &xbmc_yac(text=>"This is a test from misterhouse to XBMC");
}


if ($Startup) {
# Notify the on startup / restart
        print_log("System Restarted, Notifying XBMC") if $Debug{xbmc};
        display_xbmcosd("$config_parms{xbmc_title}", "Misterhouse has been restarted", $config_parms{xbmc_timeout}, "$config_parms{xbmc_image}");
}

if (said $v_xbmc_osd) {
# Send a test notification to the configured XBMC instance
        print_log("Sending test notification") if $Debug{xbmc};
        display_xbmcosd("$config_parms{xbmc_title}", "This is a test notification!!", $config_parms{xbmc_timeout}, "$config_parms{xbmc_image}");
}

sub xbmc_yac() {
        my %parms = @_;
        print "XBMC message sent";
        print "----------------";
        display_xbmcosd("$config_parms{xbmc_title}", "$parms{text}", $config_parms{xbmc_timeout}, "$config_parms{xbmc_image}");
        return;
}


sub display_xbmcosd {
        my ($title, $text, $timeOut, $image) = @_;

        unless($config_parms{xbmc_notify_address}){
                print_log("xbmc_notify_address has not been set in mh.ini, Unable to notify XBMC.");
                return;
        }

# Change spaces to HTML space codes
        $title =~ s/ /%20/g;
        $text =~ s/ /%20/g;

        print_log("Sending notification to XBMC at http://".$config_parms{xbmc_notify_address}.":".$config_parms{xbmc_notify_port}."/jsonrpc") if $Debug{xbmc};
# Doesnt support authentication (Yet)
        my $url = 'http://' .$config_parms{xbmc_notify_address}.':'.$config_parms{xbmc_notify_port}.'/jsonrpc?request={"jsonrpc":"2.0","method":"GUI.ShowNotification","params":{"title":"'.$title.'"  , "message":"'.$text.'"  ,  "displaytime":'.$timeOut.'  ,   "image":"'.$image.'"        },"id":1}';

        my $ua = new LWP::UserAgent;
        my $req = new HTTP::Request GET => $url;
        my $res = $ua->request($req);

}
