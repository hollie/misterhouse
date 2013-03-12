# Category=Home_Network
#
#@ Sends Notification message to XBMC

use LWP::UserAgent;

$v_xbmc_osd = new  Voice_Cmd("Test XBMC Notify");

if ($Startup) {
	# Notify the on startup / restart
	display_xbmcosd("System Restarted", "Misterhouse has been restarted");
}

if (said $v_xbmc_osd) {
	# Send a test notification to the configured XBMC instance
	display_xbmcosd("Test Notification", "This is a test notification!!");
}

sub display_xbmcosd {
	my ($title, $text) = @_;

	# Change spaces to HTML space codes
	$title =~ s/ /%20/g;
	$text =~ s/ /%20/g;

	# Doesnt support authentication (Yet)
	my $url = 'http://' .$config_parms{xbmc_notify_address}.':'.$config_parms{xbmc_notify_port}.'/jsonrpc?request={"jsonrpc":"2.0","method":"GUI.ShowNotification","params":{"title":"'.$title.'","message":"'.$text.'"},"id":1}';

	my $ua = new LWP::UserAgent;
	my $req = new HTTP::Request GET => $url;
	my $res = $ua->request($req);

}
